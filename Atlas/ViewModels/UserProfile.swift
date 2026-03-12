//
//  UserProfile.swift
//  Atlas
//
//  Created by Dawid Piotrowski on 11/03/2026.
//

import SwiftUI
import Observation

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

    var totalMiles: Int {
        didSet { UserDefaults.standard.set(totalMiles, forKey: "atlas_totalMiles") }
    }

    var entryId: String {
        didSet { UserDefaults.standard.set(entryId, forKey: "atlas_entryId") }
    }

    var hasOnboarded: Bool {
        didSet { UserDefaults.standard.set(hasOnboarded, forKey: "atlas_hasOnboarded") }
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
        self.totalMiles     = d.integer(forKey: "atlas_totalMiles")
        self.hasOnboarded   = d.bool(forKey: "atlas_hasOnboarded")
        self.currencyCode   = d.string(forKey: "atlas_currencyCode") ?? "USD"
        self.avatarImageData = try? Data(contentsOf: UserProfile.avatarFileURL)

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

    var milesDisplay: String {
        if totalMiles >= 1000 {
            return "\(totalMiles / 1000)K"
        }
        return String(totalMiles)
    }

    // MARK: - Update from trips

    func syncStats(from trips: [Trip]) {
        let completed = trips.filter { $0.status == .completed }
        totalTrips = completed.count

        // Count unique destinations (simple approximation)
        let destinations = Set(completed.map { $0.destination.lowercased() })
        totalCountries = max(destinations.count, totalCountries)
    }
}
