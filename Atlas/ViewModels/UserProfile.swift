//
//  UserProfile.swift
//  Atlas
//
//  Created by Dawid Piotrowski on 11/03/2026.
//

import SwiftUI
import Observation
import CloudKit
import SwiftData
import CoreLocation

@Observable
final class UserProfile {
    static let shared = UserProfile()

    var displayName: String {
        didSet { UserDefaults.standard.set(displayName, forKey: "atlas_displayName") }
    }

    var totalTrips: Int {
        didSet { UserDefaults.standard.set(totalTrips, forKey: "atlas_totalTrips") }
    }

    var totalCountries: Int {
        didSet { UserDefaults.standard.set(totalCountries, forKey: "atlas_totalCountries") }
    }

    /// Stored in kilometres; converted for display based on device locale.
    var totalKm: Int {
        didSet { UserDefaults.standard.set(totalKm, forKey: "atlas_totalKm") }
    }

    var entryId: String {
        didSet { UserDefaults.standard.set(entryId, forKey: "atlas_entryId") }
    }

    var hasOnboarded: Bool {
        didSet { UserDefaults.standard.set(hasOnboarded, forKey: "atlas_hasOnboarded") }
    }

    /// CKRecord.ID string of the current iCloud user — used for `addedByUserID` attribution.
    /// Fetched once on first launch and cached to UserDefaults.
    var iCloudUserRecordID: String? {
        didSet { UserDefaults.standard.set(iCloudUserRecordID, forKey: "atlas_icloudUserRecordID") }
    }

    var currencyCode: String {
        didSet { UserDefaults.standard.set(currencyCode, forKey: "atlas_currencyCode") }
    }

    var currency: AppCurrency {
        AppCurrency.all.first { $0.code == currencyCode } ?? .usd
    }

    var currencySymbol: String { currency.symbol }

    /// Cached avatar image data — persisted to Documents/atlas_avatar.jpg
    var avatarImageData: Data? {
        didSet {
            if let data = avatarImageData {
                try? data.write(to: UserProfile.avatarFileURL, options: .atomic)
            } else {
                try? FileManager.default.removeItem(at: UserProfile.avatarFileURL)
            }
        }
    }

    private static var avatarFileURL: URL {
        FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("atlas_avatar.jpg")
    }

    private init() {
        let d = UserDefaults.standard
        self.displayName    = d.string(forKey: "atlas_displayName") ?? "Traveler"
        self.totalTrips     = d.integer(forKey: "atlas_totalTrips")
        self.totalCountries = d.integer(forKey: "atlas_totalCountries")
        // Migrate legacy "atlas_totalMiles" value on first launch if present.
        if d.object(forKey: "atlas_totalKm") == nil, d.integer(forKey: "atlas_totalMiles") > 0 {
            self.totalKm = Int(Double(d.integer(forKey: "atlas_totalMiles")) * 1.60934)
        } else {
            self.totalKm = d.integer(forKey: "atlas_totalKm")
        }
        self.hasOnboarded         = d.bool(forKey: "atlas_hasOnboarded")
        self.currencyCode         = d.string(forKey: "atlas_currencyCode") ?? "USD"
        self.iCloudUserRecordID   = d.string(forKey: "atlas_icloudUserRecordID")
        self.avatarImageData      = try? Data(contentsOf: UserProfile.avatarFileURL)

        let savedId = d.string(forKey: "atlas_entryId")
        if let savedId {
            self.entryId = savedId
        } else {
            let newId = String(format: "#%05d", Int.random(in: 10000...99999))
            self.entryId = newId
            d.set(newId, forKey: "atlas_entryId")
        }
    }

    func signOut() {
        hasOnboarded = false
        displayName  = "Traveler"
        avatarImageData = nil
    }

    // MARK: - Avatar Photo

    /// Resizes and compresses a picked image before storing.
    func setAvatar(from image: UIImage) {
        let targetSize = CGSize(width: 400, height: 400)
        let renderer = UIGraphicsImageRenderer(size: targetSize)
        let cropped = renderer.image { _ in
            let scale = max(targetSize.width / image.size.width,
                            targetSize.height / image.size.height)
            let scaled = CGSize(width: image.size.width * scale,
                                height: image.size.height * scale)
            let origin = CGPoint(x: (targetSize.width  - scaled.width)  / 2,
                                 y: (targetSize.height - scaled.height) / 2)
            image.draw(in: CGRect(origin: origin, size: scaled))
        }
        avatarImageData = cropped.jpegData(compressionQuality: 0.82)
    }

    // MARK: - Initials

    var initials: String {
        let parts = displayName.split(separator: " ")
        let first = parts.first?.prefix(1) ?? ""
        let last  = parts.dropFirst().first?.prefix(1) ?? ""
        return (first + last).uppercased()
    }

    // MARK: - Formatted Stats

    var tripsDisplay: String {
        String(format: "%02d", totalTrips)
    }

    var countriesDisplay: String {
        String(format: "%02d", totalCountries)
    }

    /// "km" for metric locales, "Miles" for US/UK.
    var distanceLabel: String {
        Locale.current.usesMetricSystem ? "km" : "Miles"
    }

    var distanceDisplay: String {
        let value = Locale.current.usesMetricSystem
            ? totalKm
            : Int((Double(totalKm) * 0.621371).rounded())
        if value >= 1_000_000 { return "\(value / 1_000_000)M" }
        if value >= 1000      { return "\(value / 1000)K" }
        return String(value)
    }

    // MARK: - iCloud User Identity

    /// Fetches the CKRecord user ID from CloudKit and caches it.
    /// Safe to call multiple times — no-ops if already known.
    func fetchCloudKitUserRecordIDIfNeeded() {
        guard iCloudUserRecordID == nil else { return }
        Task {
            do {
                let id = try await CKContainer.default().userRecordID()
                await MainActor.run {
                    self.iCloudUserRecordID = id.recordName
                }
            } catch {
                // Not signed into iCloud — leave nil, attribution will use displayName only
            }
        }
    }

    // MARK: - Update from trips + map pins

    func syncStats(from trips: [Trip], mapPins: [VisitedLocation] = [], isPro: Bool = false) {
        let completed = trips.filter { $0.status == .completed }
        totalTrips = completed.count

        // ── Countries ─────────────────────────────────────────────────────────
        // Use the stored country field; fall back to destination name for old entries.
        var countries = Set(
            completed.map { trip -> String in
                let c = trip.country.trimmingCharacters(in: .whitespaces)
                return c.isEmpty ? trip.destination.lowercased() : c.lowercased()
            }.filter { !$0.isEmpty }
        )
        if isPro {
            for pin in mapPins {
                let c = pin.country.trimmingCharacters(in: .whitespaces)
                if !c.isEmpty { countries.insert(c.lowercased()) }
            }
        }
        totalCountries = countries.count

        // ── Distance ──────────────────────────────────────────────────────────
        // Sort dated pins chronologically and sum great-circle distances between
        // consecutive locations — this approximates the user's total air travel path.
        // Undated pins are excluded because their temporal order is unknown.
        let datedPins = mapPins
            .filter { $0.dateVisited != nil }
            .sorted { $0.dateVisited! < $1.dateVisited! }

        var totalMeters = 0.0
        guard datedPins.count >= 2 else { totalKm = 0; return }
        for i in 1..<datedPins.count {
            let from = CLLocation(latitude: datedPins[i - 1].latitude,
                                  longitude: datedPins[i - 1].longitude)
            let to   = CLLocation(latitude: datedPins[i].latitude,
                                  longitude: datedPins[i].longitude)
            totalMeters += from.distance(from: to)
        }
        totalKm = Int((totalMeters / 1000).rounded())
    }
}
