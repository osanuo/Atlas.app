//
//  CloudKitSharingManager.swift
//  Atlas
//
//  Manages CloudKit CKShare lifecycle for collaborative trip planning.
//  Architecture: SwiftData is local cache; CloudKit shared database is source of truth
//  for shared trips.
//

import CloudKit
import SwiftData
import SwiftUI
import Observation

// MARK: - Sync State

enum CloudKitSyncState: Equatable {
    case idle
    case syncing
    case upToDate
    case error(String)
}

// MARK: - CloudKit Errors

enum CloudKitSharingError: LocalizedError {
    case containerNotConfigured
    case recordNotFound
    case shareCreationFailed(Error)
    case syncFailed(Error)
    case acceptanceFailed(Error)

    var errorDescription: String? {
        switch self {
        case .containerNotConfigured:   return "iCloud is not configured. Please sign in to iCloud in Settings."
        case .recordNotFound:           return "Could not find the trip in iCloud."
        case .shareCreationFailed(let e): return "Failed to create share link: \(e.localizedDescription)"
        case .syncFailed(let e):        return "Sync failed: \(e.localizedDescription)"
        case .acceptanceFailed(let e):  return "Could not accept invitation: \(e.localizedDescription)"
        }
    }
}

// MARK: - CloudKit Record Type Names

private enum CKRecordType {
    static let sharedTrip     = "SharedTrip"
    static let sharedTripItem = "SharedTripItem"
}

// MARK: - CloudKit Sharing Manager

@Observable
final class CloudKitSharingManager {

    static let shared = CloudKitSharingManager()

    var syncState: CloudKitSyncState = .idle
    var lastError: CloudKitSharingError?

    // Pending share acceptances: tripID → callback with accepted Trip
    var pendingShareAcceptance: CKShare.Metadata?

    private let container: CKContainer = {
        // Uses the container identifier from entitlements
        let bundleID = Bundle.main.bundleIdentifier ?? "com.atlas"
        return CKContainer(identifier: "iCloud.\(bundleID)")
    }()

    private init() {}

    // MARK: - Container / Account check

    /// Returns true if iCloud account is available
    func isICloudAvailable() async -> Bool {
        do {
            let status = try await container.accountStatus()
            return status == .available
        } catch {
            return false
        }
    }

    // MARK: - Create Share

    /// Creates a CloudKit zone + SharedTrip record + CKShare for the given trip.
    /// Returns a URL that can be shared with collaborators via ShareLink / AirDrop.
    @MainActor
    func createShare(for trip: Trip) async throws -> URL {
        guard await isICloudAvailable() else {
            throw CloudKitSharingError.containerNotConfigured
        }

        syncState = .syncing

        do {
            let zoneName = "atlas-shared-\(trip.id.uuidString)"
            let zoneID   = CKRecordZone.ID(zoneName: zoneName, ownerName: CKCurrentUserDefaultName)
            let zone     = CKRecordZone(zoneID: zoneID)

            // Create zone
            let _ = try await container.privateCloudDatabase.save(zone)

            // Create SharedTrip record
            let tripRecordID = CKRecord.ID(recordName: trip.id.uuidString, zoneID: zoneID)
            let tripRecord   = CKRecord(recordType: CKRecordType.sharedTrip, recordID: tripRecordID)
            tripRecord["tripID"]           = trip.id.uuidString
            tripRecord["name"]             = trip.name
            tripRecord["destination"]      = trip.destination
            tripRecord["startDate"]        = trip.startDate
            tripRecord["endDate"]          = trip.endDate
            tripRecord["ownerDisplayName"] = UserProfile.shared.displayName

            // Create CKShare
            let share = CKShare(rootRecord: tripRecord)
            share.publicPermission = .none  // invite-only
            share[CKShare.SystemFieldKey.title]    = "Trip to \(trip.destination)" as CKRecordValue
            share[CKShare.SystemFieldKey.shareType] = "com.atlas.trip" as CKRecordValue

            // Save both the record and the share atomically
            let modifyOp = CKModifyRecordsOperation(
                recordsToSave: [tripRecord, share],
                recordIDsToDelete: nil
            )
            modifyOp.savePolicy = .changedKeys
            modifyOp.isAtomic   = true

            try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
                modifyOp.modifyRecordsResultBlock = { result in
                    switch result {
                    case .success:     cont.resume()
                    case .failure(let e): cont.resume(throwing: e)
                    }
                }
                container.privateCloudDatabase.add(modifyOp)
            }

            guard let shareURL = share.url else {
                throw CloudKitSharingError.shareCreationFailed(
                    NSError(domain: "CloudKitSharingManager", code: -1,
                            userInfo: [NSLocalizedDescriptionKey: "Share URL was nil after save"])
                )
            }

            // Persist to local Trip model
            trip.isShared        = true
            trip.cloudKitZoneName = zoneName
            trip.shareURL        = shareURL.absoluteString

            // Upload existing items
            for item in trip.items {
                try await syncItem(item, in: trip)
            }

            // Subscribe to changes
            try? await setupSubscription(for: trip)

            syncState = .upToDate
            return shareURL

        } catch let e as CloudKitSharingError {
            syncState = .error(e.localizedDescription)
            throw e
        } catch {
            let wrappedError = CloudKitSharingError.shareCreationFailed(error)
            syncState = .error(error.localizedDescription)
            throw wrappedError
        }
    }

    // MARK: - Sync Single Item (push to CloudKit)

    /// Writes a TripItem as a CKRecord into the trip's shared zone.
    /// Call this after inserting a new item into the SwiftData context.
    @MainActor
    func syncItem(_ item: TripItem, in trip: Trip) async throws {
        guard trip.isShared, let zoneName = trip.cloudKitZoneName else { return }

        let zoneID     = CKRecordZone.ID(zoneName: zoneName, ownerName: CKCurrentUserDefaultName)
        let recordID   = CKRecord.ID(recordName: item.id.uuidString, zoneID: zoneID)
        let record     = CKRecord(recordType: CKRecordType.sharedTripItem, recordID: recordID)

        let tripRecordID = CKRecord.ID(recordName: trip.id.uuidString, zoneID: zoneID)
        record["tripRef"]      = CKRecord.Reference(recordID: tripRecordID, action: .deleteSelf)
        record["localItemID"]  = item.id.uuidString
        record["title"]        = item.title
        record["categoryRaw"]  = item.categoryRaw
        record["notes"]        = item.notes
        record["priorityRaw"]  = item.priorityRaw
        record["price"]        = item.price
        record["dayAssigned"]  = item.dayAssigned
        record["timeAssigned"] = item.timeAssigned
        record["isCompleted"]  = item.isCompleted ? 1 : 0
        record["addedByName"]  = item.addedByName

        do {
            // Try shared database first (collaborator), then private (owner)
            let db = try await resolveDatabase(for: trip)
            let _ = try await db.save(record)
        } catch {
            throw CloudKitSharingError.syncFailed(error)
        }
    }

    // MARK: - Delete Item from CloudKit

    /// Removes the CloudKit record for a deleted TripItem.
    @MainActor
    func deleteItem(_ item: TripItem, in trip: Trip) async throws {
        guard trip.isShared, let zoneName = trip.cloudKitZoneName else { return }

        let zoneID   = CKRecordZone.ID(zoneName: zoneName, ownerName: CKCurrentUserDefaultName)
        let recordID = CKRecord.ID(recordName: item.id.uuidString, zoneID: zoneID)

        do {
            let db = try await resolveDatabase(for: trip)
            try await db.deleteRecord(withID: recordID)
        } catch {
            // Non-fatal: record may already be gone
        }
    }

    // MARK: - Fetch Changes (pull from CloudKit)

    /// Fetches all new/changed SharedTripItem records since the last change token.
    /// Merges them into local SwiftData via the provided model context.
    @MainActor
    func fetchChanges(for trip: Trip, in context: ModelContext) async throws {
        guard trip.isShared, let zoneName = trip.cloudKitZoneName else { return }

        syncState = .syncing

        let zoneID = CKRecordZone.ID(zoneName: zoneName, ownerName: CKCurrentUserDefaultName)

        // Change token key per trip zone
        let tokenKey = "ck_changetoken_\(trip.id.uuidString)"
        let tokenData = UserDefaults.standard.data(forKey: tokenKey)
        let previousToken: CKServerChangeToken? = tokenData.flatMap {
            try? NSKeyedUnarchiver.unarchivedObject(ofClass: CKServerChangeToken.self, from: $0)
        }

        do {
            let db = try await resolveDatabase(for: trip)

            var newToken: CKServerChangeToken?
            var changedRecords: [CKRecord] = []
            var deletedIDs: [CKRecord.ID] = []

            let fetchOp = CKFetchRecordZoneChangesOperation(
                recordZoneIDs: [zoneID],
                configurationsByRecordZoneID: [
                    zoneID: CKFetchRecordZoneChangesOperation.ZoneConfiguration(
                        previousServerChangeToken: previousToken
                    )
                ]
            )

            fetchOp.recordWasChangedBlock = { _, result in
                if case .success(let record) = result { changedRecords.append(record) }
            }
            fetchOp.recordWithIDWasDeletedBlock = { id, _ in deletedIDs.append(id) }
            fetchOp.recordZoneChangeTokensUpdatedBlock = { _, token, _ in newToken = token }
            fetchOp.recordZoneFetchResultBlock = { _, result in
                if case .success(let (token, _, _)) = result { newToken = token }
            }

            try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
                fetchOp.fetchRecordZoneChangesResultBlock = { result in
                    switch result {
                    case .success: cont.resume()
                    case .failure(let e): cont.resume(throwing: e)
                    }
                }
                db.add(fetchOp)
            }

            // Merge changes into SwiftData
            for record in changedRecords where record.recordType == CKRecordType.sharedTripItem {
                mergeItemRecord(record, into: trip, context: context)
            }

            // Remove deleted items from local store
            for deletedID in deletedIDs {
                if let item = trip.items.first(where: { $0.id.uuidString == deletedID.recordName }) {
                    context.delete(item)
                }
            }

            // Persist new change token
            if let newToken {
                let data = try? NSKeyedArchiver.archivedData(withRootObject: newToken, requiringSecureCoding: true)
                UserDefaults.standard.set(data, forKey: tokenKey)
            }

            syncState = .upToDate

        } catch {
            syncState = .error(error.localizedDescription)
            throw CloudKitSharingError.syncFailed(error)
        }
    }

    // MARK: - Accept Share Invitation

    /// Called from the AppDelegate when the user taps a CKShare invitation URL.
    /// Accepts the share and creates a local SwiftData Trip mirror.
    @MainActor
    func acceptShare(metadata: CKShare.Metadata, in context: ModelContext) async throws -> Trip {
        syncState = .syncing

        do {
            // Accept the share
            try await container.accept(metadata)

            // Fetch the root SharedTrip record from the shared database
            let sharedDB = container.sharedCloudDatabase
            let rootRecord = try await sharedDB.record(for: metadata.rootRecordID)

            // Build local Trip from record
            let trip = buildTrip(from: rootRecord)
            trip.isShared = true
            trip.cloudKitZoneName = rootRecord.recordID.zoneID.zoneName

            // Persist share URL
            if let shareURL = metadata.share.url {
                trip.shareURL = shareURL.absoluteString
            }

            context.insert(trip)

            // Fetch initial items
            let query = CKQuery(
                recordType: CKRecordType.sharedTripItem,
                predicate: NSPredicate(
                    format: "tripRef == %@",
                    CKRecord.Reference(recordID: rootRecord.recordID, action: .none)
                )
            )
            let (results, _) = try await sharedDB.records(matching: query,
                                                           inZoneWith: rootRecord.recordID.zoneID)
            for (_, result) in results {
                if case .success(let record) = result {
                    mergeItemRecord(record, into: trip, context: context)
                }
            }

            // Subscribe to future changes
            try? await setupSubscription(for: trip)

            syncState = .upToDate
            return trip

        } catch {
            syncState = .error(error.localizedDescription)
            throw CloudKitSharingError.acceptanceFailed(error)
        }
    }

    // MARK: - Setup Push Subscription

    /// Creates a CKRecordZoneSubscription so this device receives silent pushes when records change.
    func setupSubscription(for trip: Trip) async throws {
        guard trip.isShared, let zoneName = trip.cloudKitZoneName else { return }

        let zoneID = CKRecordZone.ID(zoneName: zoneName, ownerName: CKCurrentUserDefaultName)
        let subscriptionID = "atlas-zone-\(trip.id.uuidString)"
        let subscription = CKRecordZoneSubscription(zoneID: zoneID, subscriptionID: subscriptionID)

        let notificationInfo = CKSubscription.NotificationInfo()
        notificationInfo.shouldSendContentAvailable = true  // silent push
        subscription.notificationInfo = notificationInfo

        do {
            let db = try await resolveDatabase(for: trip)
            let _ = try await db.save(subscription)
        } catch CKError.serverRejectedRequest {
            // Subscription may already exist — safe to ignore
        } catch {
            // Non-fatal: app will still sync on foreground
        }
    }

    // MARK: - Stop Sharing (Owner)

    /// Removes the CKShare and deletes the shared zone. Only the trip owner can do this.
    @MainActor
    func stopSharing(_ trip: Trip) async throws {
        guard trip.isShared, let zoneName = trip.cloudKitZoneName else { return }

        let zoneID = CKRecordZone.ID(zoneName: zoneName, ownerName: CKCurrentUserDefaultName)

        // Fetch and delete the share first
        do {
            let shareRecordID = CKRecord.ID(recordName: "cloudkit.share:\(trip.id.uuidString)", zoneID: zoneID)
            try? await container.privateCloudDatabase.deleteRecord(withID: shareRecordID)
        }

        // Delete the entire zone (cascades to all records)
        do {
            try await container.privateCloudDatabase.deleteRecordZone(withID: zoneID)
        } catch {
            // Zone may already be gone
        }

        // Remove change token
        UserDefaults.standard.removeObject(forKey: "ck_changetoken_\(trip.id.uuidString)")

        // Clear sharing state on trip
        trip.isShared         = false
        trip.cloudKitZoneName = nil
        trip.shareURL         = nil

        syncState = .idle
    }

    // MARK: - Fetch Share Participants

    /// Returns the CKShare participants for a shared trip (for display in ShareTripView).
    func fetchParticipants(for trip: Trip) async throws -> [CKShare.Participant] {
        guard trip.isShared, let zoneName = trip.cloudKitZoneName else { return [] }

        let zoneID     = CKRecordZone.ID(zoneName: zoneName, ownerName: CKCurrentUserDefaultName)
        let tripRecord = CKRecord.ID(recordName: trip.id.uuidString, zoneID: zoneID)

        do {
            // Fetch the share record
            let shareID  = CKRecord.ID(recordName: "cloudkit.share:\(trip.id.uuidString)", zoneID: zoneID)
            let record   = try await container.privateCloudDatabase.record(for: shareID)
            guard let share = record as? CKShare else { return [] }
            return share.participants
        } catch {
            // Try fetching root record — share is colocated
            if let rootRecord = try? await container.privateCloudDatabase.record(for: tripRecord),
               let fetchedShare = rootRecord as? CKShare {
                return fetchedShare.participants
            }
            return []
        }
    }

    // MARK: - Helpers

    /// Resolves whether to use private or shared database based on whether
    /// this device is the trip owner or a collaborator.
    private func resolveDatabase(for trip: Trip) async throws -> CKDatabase {
        // If the trip was created locally it lives in private DB;
        // if it came in via acceptShare it lives in shared DB.
        // We store a flag to distinguish these in cloudKitZoneName prefix.
        guard let zoneName = trip.cloudKitZoneName else {
            return container.privateCloudDatabase
        }
        // Collaborators get a zone name that starts with "atlas-shared-" too,
        // but their zone lives in the shared database. We detect this by checking
        // if the zone exists in the private DB first.
        do {
            let zoneID = CKRecordZone.ID(zoneName: zoneName, ownerName: CKCurrentUserDefaultName)
            let _ = try await container.privateCloudDatabase.recordZone(for: zoneID)
            return container.privateCloudDatabase
        } catch {
            return container.sharedCloudDatabase
        }
    }

    /// Merges a CloudKit SharedTripItem record into local SwiftData.
    private func mergeItemRecord(_ record: CKRecord, into trip: Trip, context: ModelContext) {
        guard let localID = record["localItemID"] as? String,
              let uuid    = UUID(uuidString: localID) else { return }

        // Check if item already exists locally
        if let existing = trip.items.first(where: { $0.id == uuid }) {
            // Update existing
            if let title = record["title"] as? String { existing.title = title }
            if let cat   = record["categoryRaw"] as? String { existing.categoryRaw = cat }
            if let notes = record["notes"] as? String { existing.notes = notes }
            if let pri   = record["priorityRaw"] as? String { existing.priorityRaw = pri }
            existing.price        = record["price"] as? Double
            existing.dayAssigned  = record["dayAssigned"] as? Date
            existing.timeAssigned = record["timeAssigned"] as? Date
            if let done = record["isCompleted"] as? Int { existing.isCompleted = done == 1 }
            if let who  = record["addedByName"] as? String, !who.isEmpty { existing.addedByName = who }
        } else {
            // Create new item from remote record
            let item = TripItem(
                title:        (record["title"] as? String) ?? "Untitled",
                category:     ItemCategory(rawValue: (record["categoryRaw"] as? String) ?? "") ?? .places,
                notes:        (record["notes"]       as? String) ?? "",
                priority:     ItemPriority(rawValue: (record["priorityRaw"] as? String) ?? "") ?? .niceToHave,
                trip:         trip
            )
            item.id           = uuid
            item.price        = record["price"] as? Double
            item.dayAssigned  = record["dayAssigned"] as? Date
            item.timeAssigned = record["timeAssigned"] as? Date
            item.isCompleted  = (record["isCompleted"] as? Int) == 1
            item.addedByName  = (record["addedByName"] as? String) ?? ""
            item.addedByUserID = record.creatorUserRecordID?.recordName ?? ""
            context.insert(item)
            trip.items.append(item)
        }
    }

    /// Builds a local Trip from a SharedTrip CKRecord.
    private func buildTrip(from record: CKRecord) -> Trip {
        let trip = Trip(
            name:        (record["name"]        as? String) ?? "Shared Trip",
            destination: (record["destination"] as? String) ?? "Unknown"
        )
        if let uuid = UUID(uuidString: record.recordID.recordName) {
            trip.id = uuid
        }
        if let start = record["startDate"] as? Date { trip.startDate = start }
        if let end   = record["endDate"]   as? Date { trip.endDate   = end }
        return trip
    }
}
