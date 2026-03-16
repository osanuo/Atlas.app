//
//  AtlasApp.swift
//  Atlas
//
//  Created by Dawid Piotrowski on 11/03/2026.
//

import SwiftUI
import SwiftData
import CloudKit

// MARK: - App Delegate (needed for CKShare acceptance callback)

final class AtlasAppDelegate: NSObject, UIApplicationDelegate {

    func application(
        _ application: UIApplication,
        userDidAcceptCloudKitShareWith metadata: CKShare.Metadata
    ) {
        // Store metadata so the active scene can process it with a ModelContext
        CloudKitSharingManager.shared.pendingShareAcceptance = metadata
    }

    func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable: Any],
        fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        // CloudKit delivers silent pushes for zone changes — trigger a sync
        guard CKNotification(fromRemoteNotificationDictionary: userInfo) != nil else {
            completionHandler(.noData)
            return
        }
        // The actual fetch happens when the app foregrounds via .onReceive(NotificationCenter…)
        // We just acknowledge the push here.
        completionHandler(.newData)
    }
}

@main
struct AtlasApp: App {

    @UIApplicationDelegateAdaptor(AtlasAppDelegate.self) private var appDelegate

    @State private var container: ModelContainer?
    // Tracks hasOnboarded reactively (UserProfile is @Observable)
    @State private var profile = UserProfile.shared
    @State private var subscriptionManager = SubscriptionManager.shared

    var body: some Scene {
        WindowGroup {
            Group {
                if let container {
                    if profile.hasOnboarded {
                        ContentView()
                            .environment(profile)
                            .environment(subscriptionManager)
                            .modelContainer(container)
                            .transition(.opacity)
                            .onAppear {
                                profile.fetchCloudKitUserRecordIDIfNeeded()
                                Task { await AtlasApp.processPendingShareItems(in: container) }
                            }
                            // Process pending CKShare acceptance when ModelContext is available
                            .task(id: CloudKitSharingManager.shared.pendingShareAcceptance) {
                                guard let metadata = CloudKitSharingManager.shared.pendingShareAcceptance else { return }
                                CloudKitSharingManager.shared.pendingShareAcceptance = nil
                                let ctx = ModelContext(container)
                                _ = try? await CloudKitSharingManager.shared.acceptShare(metadata: metadata, in: ctx)
                            }
                            // Process share extension queue when returning to foreground
                            .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
                                Task { await AtlasApp.processPendingShareItems(in: container) }
                            }
                    } else {
                        OnboardingView {
                            profile.hasOnboarded = true
                        }
                        .transition(.opacity)
                    }
                } else {
                    LaunchView()
                        .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.45), value: container != nil)
            .animation(.easeInOut(duration: 0.6), value: profile.hasOnboarded)
            .task(priority: .userInitiated) {
                guard container == nil else { return }
                container = await Task.detached(priority: .userInitiated) {
                    AtlasApp.makeContainer()
                }.value
            }
        }
    }

    nonisolated private static func makeContainer() -> ModelContainer {
        let schema = Schema([Trip.self, TripItem.self, CrewMember.self, Expense.self, WishlistDestination.self, VisitedLocation.self])

        // Try CloudKit-backed container first
        if let c = try? ModelContainer(
            for: schema,
            configurations: [ModelConfiguration(schema: schema, cloudKitDatabase: .automatic)]
        ) { return c }

        // Fallback 1: local-only storage
        let localConfig = ModelConfiguration(schema: schema, cloudKitDatabase: .none)
        if let c = try? ModelContainer(for: schema, configurations: [localConfig]) { return c }

        // Fallback 2: destroy corrupted store and recreate
        destroyDefaultStore()
        if let c = try? ModelContainer(for: schema, configurations: [localConfig]) { return c }

        fatalError("Cannot create ModelContainer — aborting.")
    }

    // MARK: - Share Extension Queue Processing

    /// Reads any items saved by AtlasShareExtension into the shared UserDefaults queue,
    /// inserts them into SwiftData, then clears the queue.
    /// Mirrors `PendingShareItem` in ShareExtensionViewController.swift — keep in sync.
    private static func processPendingShareItems(in container: ModelContainer) async {
        let shared = UserDefaults(suiteName: "group.com.osanuo.Atlas")
        guard
            let data  = shared?.data(forKey: "atlas_pendingShareItems"),
            let items = try? JSONDecoder().decode([PendingShareItem].self, from: data),
            !items.isEmpty
        else { return }

        // Clear the queue first to prevent double-processing if the app is killed mid-insert
        shared?.removeObject(forKey: "atlas_pendingShareItems")

        let ctx = ModelContext(container)

        for item in items {
            if item.destination == "wishlist" {
                // Free-tier path: save as a Wishlist destination
                let dest = WishlistDestination(
                    city: item.title,
                    country: "",
                    notes: item.urlString,
                    imageURL: item.urlString
                )
                ctx.insert(dest)

            } else if (item.destination == "trip" || item.destination == "collection"),
                      let tripIDString = item.tripID {
                // Pro path: clip directly into a specific trip
                // ("collection" kept for backward-compat with older extension builds)
                let descriptor = FetchDescriptor<Trip>()
                let allTrips   = (try? ctx.fetch(descriptor)) ?? []
                if let trip = allTrips.first(where: { $0.id.uuidString == tripIDString }) {
                    let category = item.categoryRaw.flatMap { ItemCategory(rawValue: $0) } ?? .places
                    let tripItem = TripItem(
                        title:    item.title,
                        category: category,
                        notes:    "",
                        url:      item.urlString,
                        trip:     trip
                    )
                    tripItem.locationAddress = item.address ?? ""
                    ctx.insert(tripItem)
                }
            }
        }

        try? ctx.save()
    }

    /// Writes a lightweight list of planning/active trips to the shared App Group
    /// so the Share Extension can display them without accessing SwiftData.
    /// Call whenever the trip list changes (ContentView onChange) or on foreground.
    static func syncTripsToSharedDefaults(_ trips: [Trip]) {
        let relevant = trips.filter { $0.statusRaw == "planning" || $0.statusRaw == "active" }
        let shared   = relevant.map {
            SharedTrip(
                id:          $0.id.uuidString,
                name:        $0.name,
                destination: $0.destination,
                emoji:       $0.destinationFlag,
                status:      $0.statusRaw
            )
        }
        guard let encoded = try? JSONEncoder().encode(shared) else { return }
        UserDefaults(suiteName: "group.com.osanuo.Atlas")?.set(encoded, forKey: "atlas_sharedTrips")
    }

    nonisolated private static func destroyDefaultStore() {
        guard let appSupport = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask).first else { return }
        let base = appSupport.appendingPathComponent("default.store")
        for url in [
            base,
            base.appendingPathExtension("wal"),
            base.appendingPathExtension("shm")
        ] {
            try? FileManager.default.removeItem(at: url)
        }
    }
}

// MARK: - Shared Models (mirror AtlasShareExtension/ShareExtensionViewController.swift)
// Keep both definitions in sync whenever fields are added or renamed.

struct PendingShareItem: Codable {
    let id: String
    let title: String
    let urlString: String
    let destination: String   // "trip" | "wishlist"  (legacy: "collection")
    let tripID: String?
    let categoryRaw: String?
    let dateAdded: Date
    var address: String?      // pre-filled from schema.org; nil = not found

    // Custom decoder for backward-compat (old items lack `address` key)
    init(from decoder: Decoder) throws {
        let c       = try decoder.container(keyedBy: CodingKeys.self)
        id          = try c.decode(String.self, forKey: .id)
        title       = try c.decode(String.self, forKey: .title)
        urlString   = try c.decode(String.self, forKey: .urlString)
        destination = try c.decode(String.self, forKey: .destination)
        tripID      = try c.decodeIfPresent(String.self, forKey: .tripID)
        categoryRaw = try c.decodeIfPresent(String.self, forKey: .categoryRaw)
        dateAdded   = try c.decode(Date.self, forKey: .dateAdded)
        address     = try c.decodeIfPresent(String.self, forKey: .address)
    }
}

/// Lightweight trip descriptor serialised into the App Group so the share
/// extension (which cannot access SwiftData) can display the user's trips.
struct SharedTrip: Codable {
    let id: String
    let name: String
    let destination: String
    let emoji: String
    let status: String            // "planning" | "active" | "completed"
}

// MARK: - Launch Screen

struct LaunchView: View {
    var body: some View {
        ZStack {
            Color.atlasTeal.ignoresSafeArea()
            VStack(spacing: 24) {
                // App icon from dedicated imageset (works on device + Simulator)
                Image("AtlasAppIcon")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 96, height: 96)
                    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                    .shadow(color: .black.opacity(0.22), radius: 14, x: 0, y: 6)

                // Flapboard "ATLAS" with staggered flip-in animation
                FlapBoardView(text: "ATLAS", fontSize: 30, spacing: 4)
            }
        }
    }
}
