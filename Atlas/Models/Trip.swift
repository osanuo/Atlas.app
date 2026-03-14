//
//  Trip.swift
//  Atlas
//
//  Created by Dawid Piotrowski on 11/03/2026.
//

import SwiftUI
import SwiftData

// MARK: - Trip Status

enum TripStatus: String, CaseIterable, Codable {
    case planning   = "planning"
    case confirmed  = "confirmed"
    case active     = "active"
    case completed  = "completed"

    var label: String { rawValue.capitalized }

    var pillStyle: PillStyle {
        switch self {
        case .planning:  return .black
        case .confirmed: return .outline
        case .active:    return .black
        case .completed: return .outline
        }
    }

    var color: Color {
        switch self {
        case .planning:  return Color.atlasBlack
        case .confirmed: return Color.atlasTeal
        case .active:    return Color.atlasTeal
        case .completed: return Color.atlasBlack.opacity(0.5)
        }
    }
}

// MARK: - Trip Model

@Model
final class Trip {
    var id: UUID = UUID()
    var name: String = ""
    var destination: String = ""
    var country: String = ""
    var destinationFlag: String = "✈️"
    var startDate: Date = Date()
    var endDate: Date = Date().addingTimeInterval(86400 * 7)
    var cardColorHex: String = "FCDA85"
    var statusRaw: String = TripStatus.planning.rawValue
    var budget: Double? = nil
    var travelerCount: Int = 1
    var notes: String = ""
    var createdAt: Date = Date()

    // MARK: Collaboration
    var isShared: Bool = false
    var cloudKitZoneName: String? = nil   // "atlas-shared-{uuid}", nil = not shared
    var shareURL: String? = nil           // cached CKShare URL for re-sharing

    @Relationship(deleteRule: .cascade, inverse: \TripItem.trip)
    private var _items: [TripItem]? = nil
    var items: [TripItem] {
        get { _items ?? [] }
        set { _items = newValue }
    }

    @Relationship(deleteRule: .cascade, inverse: \CrewMember.trip)
    private var _crew: [CrewMember]? = nil
    var crew: [CrewMember] {
        get { _crew ?? [] }
        set { _crew = newValue }
    }

    @Relationship(deleteRule: .cascade, inverse: \Expense.trip)
    private var _expenses: [Expense]? = nil
    var expenses: [Expense] {
        get { _expenses ?? [] }
        set { _expenses = newValue }
    }

    init(
        name: String,
        destination: String,
        country: String = "",
        destinationFlag: String = "✈️",
        startDate: Date = Date(),
        endDate: Date = Date().addingTimeInterval(86400 * 7),
        cardColorHex: String = "FCDA85",
        status: TripStatus = .planning,
        budget: Double? = nil,
        travelerCount: Int = 1
    ) {
        self.id             = UUID()
        self.name           = name
        self.destination    = destination
        self.country        = country
        self.destinationFlag = destinationFlag
        self.startDate      = startDate
        self.endDate        = endDate
        self.cardColorHex   = cardColorHex
        self.statusRaw      = status.rawValue
        self.budget         = budget
        self.travelerCount  = travelerCount
        self.createdAt      = Date()
    }

    // MARK: Computed

    var status: TripStatus {
        get { TripStatus(rawValue: statusRaw) ?? .planning }
        set { statusRaw = newValue.rawValue }
    }

    var cardColor: Color {
        Color(hex: cardColorHex)
    }

    var durationDays: Int {
        max(1, Calendar.current.dateComponents([.day], from: startDate, to: endDate).day ?? 1)
    }

    var dateRangeString: String {
        let f = DateFormatter()
        f.dateFormat = "MMM dd"
        let start = f.string(from: startDate).uppercased()
        f.dateFormat = "dd, yyyy"
        let end = f.string(from: endDate).uppercased()
        return "\(start) — \(end)"
    }

    var shortDateRangeString: String {
        let f = DateFormatter()
        f.dateFormat = "MMM dd"
        return "\(f.string(from: startDate).uppercased()) – \(f.string(from: endDate).uppercased())"
    }

    var daysUntilDeparture: Int {
        let days = Calendar.current.dateComponents([.day], from: Date(), to: startDate).day ?? 0
        return max(0, days)
    }

    var completedItemsCount: Int {
        items.filter { $0.isCompleted }.count
    }

    var confirmedCrewCount: Int {
        crew.filter { $0.status == .confirmed }.count
    }

    // Card color palette index (cycles deterministically)
    static let cardColorPalette = ["FCDA85", "FFFFFF", "EBCFDA", "5499E8"]

    static func cardColorHex(for index: Int) -> String {
        cardColorPalette[index % cardColorPalette.count]
    }
}

// MARK: - Sample Data

extension Trip {
    static var samples: [Trip] {
        [
            Trip(
                name: "Tokyo Adventure",
                destination: "TOKYO",
                destinationFlag: "🇯🇵",
                startDate: Calendar.current.date(byAdding: .month, value: 1, to: Date())!,
                endDate: Calendar.current.date(byAdding: .month, value: 1, to: Date())!.addingTimeInterval(86400 * 12),
                cardColorHex: Trip.cardColorPalette[0],
                status: .planning,
                travelerCount: 5
            ),
            Trip(
                name: "Berlin Weekend",
                destination: "BERLIN",
                destinationFlag: "🇩🇪",
                startDate: Calendar.current.date(byAdding: .month, value: 2, to: Date())!,
                endDate: Calendar.current.date(byAdding: .month, value: 2, to: Date())!.addingTimeInterval(86400 * 5),
                cardColorHex: Trip.cardColorPalette[1],
                status: .confirmed,
                travelerCount: 2
            ),
        ]
    }
}
