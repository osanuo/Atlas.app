//
//  TripItem.swift
//  Atlas
//

import SwiftUI
import SwiftData

// MARK: - Item Category

enum ItemCategory: String, CaseIterable, Codable {
    case restaurants      = "restaurants"
    case places           = "places"
    case paidActivities   = "paidActivities"
    case freeActivities   = "freeActivities"
    case accommodation    = "accommodation"
    case transportation   = "transportation"

    var label: String {
        switch self {
        case .restaurants:    return "Restaurants"
        case .places:         return "Places"
        case .paidActivities: return "Activities"
        case .freeActivities: return "Free"
        case .accommodation:  return "Stay"
        case .transportation: return "Transport"
        }
    }

    var icon: String {
        switch self {
        case .restaurants:    return "fork.knife"
        case .places:         return "mappin.and.ellipse"
        case .paidActivities: return "ticket"
        case .freeActivities: return "leaf"
        case .accommodation:  return "bed.double"
        case .transportation: return "airplane"
        }
    }

    var accentHex: String {
        switch self {
        case .restaurants:    return "FF6B6B"
        case .places:         return "FFB84D"
        case .paidActivities: return "4ECDC4"
        case .freeActivities: return "95E1D3"
        case .accommodation:  return "9B59B6"
        case .transportation: return "5499E8"
        }
    }

    var accentColor: Color { Color(hex: accentHex) }

    /// Only transportation + accommodation show booking status
    var supportsBooking: Bool {
        self == .transportation || self == .accommodation
    }
}

// MARK: - Item Priority

enum ItemPriority: String, CaseIterable, Codable {
    case mustDo     = "mustDo"
    case niceToHave = "niceToHave"
    case backup     = "backup"

    var label: String {
        switch self {
        case .mustDo:     return "Must Do"
        case .niceToHave: return "Nice to Have"
        case .backup:     return "Backup"
        }
    }

    var icon: String {
        switch self {
        case .mustDo:     return "star.fill"
        case .niceToHave: return "hand.thumbsup"
        case .backup:     return "arrow.counterclockwise"
        }
    }

    var accentColor: Color {
        switch self {
        case .mustDo:     return Color.atlasTeal
        case .niceToHave: return Color.atlasBlack.opacity(0.6)
        case .backup:     return Color(hex: "FFB84D")
        }
    }
}

// MARK: - Booking Status

enum BookingStatus: String, CaseIterable, Codable {
    case notBooked  = "notBooked"
    case pending    = "pending"
    case confirmed  = "confirmed"
    case cancelled  = "cancelled"

    var label: String {
        switch self {
        case .notBooked:  return "Not Booked"
        case .pending:    return "Pending"
        case .confirmed:  return "Confirmed"
        case .cancelled:  return "Cancelled"
        }
    }

    var shortLabel: String {
        switch self {
        case .notBooked:  return "—"
        case .pending:    return "Pending"
        case .confirmed:  return "Booked"
        case .cancelled:  return "Cancelled"
        }
    }

    var color: Color {
        switch self {
        case .notBooked:  return Color.atlasBlack.opacity(0.3)
        case .pending:    return Color(hex: "FFB84D")
        case .confirmed:  return Color.atlasTeal
        case .cancelled:  return Color.red.opacity(0.7)
        }
    }

    var pillStyle: PillStyle {
        switch self {
        case .confirmed:  return .teal
        case .pending:    return .black
        default:          return .outline
        }
    }
}

// MARK: - TripItem Model

@Model
final class TripItem {
    var id: UUID = UUID()
    var title: String = ""
    var categoryRaw: String = ItemCategory.restaurants.rawValue
    var notes: String = ""
    var url: String = ""
    var locationAddress: String = ""          // NEW: physical address
    var price: Double? = nil
    var priorityRaw: String = ItemPriority.niceToHave.rawValue
    var bookingStatusRaw: String = BookingStatus.notBooked.rawValue  // NEW: booking status
    var isCompleted: Bool = false
    var dayAssigned: Date? = nil
    var timeAssigned: Date? = nil
    var createdAt: Date = Date()
    var addedByUserID: String = ""        // CKRecord creator user record ID
    var addedByName: String = ""          // display name at creation time

    var trip: Trip?

    init(
        title: String,
        category: ItemCategory = .restaurants,
        notes: String = "",
        url: String = "",
        locationAddress: String = "",
        price: Double? = nil,
        priority: ItemPriority = .niceToHave,
        bookingStatus: BookingStatus = .notBooked,
        trip: Trip? = nil
    ) {
        self.id               = UUID()
        self.title            = title
        self.categoryRaw      = category.rawValue
        self.notes            = notes
        self.url              = url
        self.locationAddress  = locationAddress
        self.price            = price
        self.priorityRaw      = priority.rawValue
        self.bookingStatusRaw = bookingStatus.rawValue
        self.trip             = trip
        self.createdAt        = Date()
    }

    // MARK: Computed

    var category: ItemCategory {
        get { ItemCategory(rawValue: categoryRaw) ?? .restaurants }
        set { categoryRaw = newValue.rawValue }
    }

    var priority: ItemPriority {
        get { ItemPriority(rawValue: priorityRaw) ?? .niceToHave }
        set { priorityRaw = newValue.rawValue }
    }

    var bookingStatus: BookingStatus {
        get { BookingStatus(rawValue: bookingStatusRaw) ?? .notBooked }
        set { bookingStatusRaw = newValue.rawValue }
    }

    func formattedPrice(symbol: String = "$") -> String? {
        guard let price else { return nil }
        return price.asCurrency(symbol)
    }

    /// Human-readable scheduled time description
    var scheduledLabel: String? {
        guard let day = dayAssigned else { return nil }
        let df = DateFormatter()
        df.dateFormat = "EEE, MMM d"
        var label = df.string(from: day)
        if let time = timeAssigned {
            let tf = DateFormatter()
            tf.dateStyle = .none
            tf.timeStyle = .short
            label += " at \(tf.string(from: time))"
        }
        return label
    }
}
