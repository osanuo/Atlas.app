//
//  CrewMember.swift
//  Atlas
//
//  Created by Dawid Piotrowski on 11/03/2026.
//

import SwiftUI
import SwiftData

// MARK: - Crew Status

enum CrewStatus: String, CaseIterable, Codable {
    case confirmed = "confirmed"
    case pending   = "pending"
    case declined  = "declined"

    var label: String { rawValue.capitalized }

    var cardColorHex: String {
        switch self {
        case .confirmed: return "FFFFFF"
        case .pending:   return "FCDA85"
        case .declined:  return "EBCFDA"
        }
    }

    var cardColor: Color { Color(hex: cardColorHex) }

    var dotColor: Color {
        switch self {
        case .confirmed: return Color.statusGreen
        case .pending:   return Color.statusYellow
        case .declined:  return Color.statusRed
        }
    }

    var pillStyle: PillStyle { .black }
}

// MARK: - CrewMember Model

@Model
final class CrewMember {
    var id: UUID = UUID()
    var name: String = ""
    var statusRaw: String = CrewStatus.pending.rawValue
    var flightInfo: String = ""
    var conflictNote: String = ""
    var avatarSeed: Int = 0
    var invitedAt: Date = Date()

    var trip: Trip?

    init(
        name: String,
        status: CrewStatus = .pending,
        flightInfo: String = "",
        conflictNote: String = "",
        trip: Trip? = nil
    ) {
        self.id            = UUID()
        self.name          = name
        self.statusRaw     = status.rawValue
        self.flightInfo    = flightInfo
        self.conflictNote  = conflictNote
        self.avatarSeed    = Int.random(in: 1...50)
        self.invitedAt     = Date()
        self.trip          = trip
    }

    // MARK: Computed

    var status: CrewStatus {
        get { CrewStatus(rawValue: statusRaw) ?? .pending }
        set { statusRaw = newValue.rawValue }
    }

    var initials: String {
        let parts = name.split(separator: " ")
        let first = parts.first?.prefix(1) ?? ""
        let last  = parts.dropFirst().first?.prefix(1) ?? ""
        return (first + last).uppercased()
    }

    var subtitleText: String {
        switch status {
        case .confirmed: return flightInfo.isEmpty ? "Confirmed" : "Flight #\(flightInfo)"
        case .pending:   return "Invite Sent"
        case .declined:  return conflictNote.isEmpty ? "Declined" : "Conflict: \(conflictNote)"
        }
    }
}
