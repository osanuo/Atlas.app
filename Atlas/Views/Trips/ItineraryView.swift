//
//  ItineraryView.swift
//  Atlas
//

import SwiftUI

// MARK: - Time Slot

enum TimeSlot: String, CaseIterable, Identifiable, Hashable {
    case morning   = "morning"
    case afternoon = "afternoon"
    case evening   = "evening"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .morning:   return "Morning"
        case .afternoon: return "Afternoon"
        case .evening:   return "Evening"
        }
    }

    var icon: String {
        switch self {
        case .morning:   return "sunrise.fill"
        case .afternoon: return "sun.max.fill"
        case .evening:   return "moon.stars.fill"
        }
    }

    var iconColor: Color {
        switch self {
        case .morning:   return Color(hex: "FFB84D")
        case .afternoon: return Color(hex: "FF6B6B")
        case .evening:   return Color(hex: "5499E8")
        }
    }

    var timeRange: String {
        switch self {
        case .morning:   return "6 AM – 12 PM"
        case .afternoon: return "12 PM – 6 PM"
        case .evening:   return "6 PM – Midnight"
        }
    }

    var defaultHour: Int {
        switch self {
        case .morning:   return 9
        case .afternoon: return 14
        case .evening:   return 19
        }
    }

    func contains(hour: Int) -> Bool {
        switch self {
        case .morning:   return hour >= 6  && hour < 12
        case .afternoon: return hour >= 12 && hour < 18
        case .evening:   return hour >= 18 || hour < 6
        }
    }
}

// MARK: - Itinerary View

struct ItineraryView: View {
    let trip: Trip

    @State private var currentDayIndex: Int = 0
    @State private var addingToSlot: TimeSlot? = nil

    // Generate trip days array
    private var tripDays: [Date] {
        let cal = Calendar.current
        var days: [Date] = []
        var date = cal.startOfDay(for: trip.startDate)
        let end  = cal.startOfDay(for: trip.endDate)
        while date <= end {
            days.append(date)
            guard let next = cal.date(byAdding: .day, value: 1, to: date) else { break }
            date = next
        }
        return days
    }

    private var currentDay: Date {
        guard !tripDays.isEmpty else { return Date() }
        return tripDays[min(currentDayIndex, tripDays.count - 1)]
    }

    private var dayLabel: String {
        let f = DateFormatter()
        f.dateFormat = "EEEE, MMM d"
        return f.string(from: currentDay)
    }

    private var totalDays: Int { max(1, tripDays.count) }

    private func items(for slot: TimeSlot) -> [TripItem] {
        trip.items
            .filter { item in
                guard let day = item.dayAssigned else { return false }
                guard Calendar.current.isDate(day, inSameDayAs: currentDay) else { return false }
                if let time = item.timeAssigned {
                    return slot.contains(hour: Calendar.current.component(.hour, from: time))
                }
                return slot == .morning  // unscheduled defaults to morning slot
            }
            .sorted {
                ($0.timeAssigned ?? .distantPast) < ($1.timeAssigned ?? .distantPast)
            }
    }

    var body: some View {
        VStack(spacing: 16) {
            // Day navigator
            dayNavigator

            // Slot sections
            ForEach(TimeSlot.allCases) { slot in
                itinerarySection(slot: slot)
            }
        }
        .sheet(item: $addingToSlot) { slot in
            ItineraryItemPickerView(trip: trip, day: currentDay, slot: slot)
        }
    }

    // MARK: - Day Navigator

    private var dayNavigator: some View {
        HStack(spacing: 16) {
            Button {
                if currentDayIndex > 0 { currentDayIndex -= 1; Haptics.light() }
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(currentDayIndex > 0 ? Color.atlasBlack : Color.atlasBlack.opacity(0.2))
                    .frame(width: 36, height: 36)
                    .background(Color.white)
                    .clipShape(Circle())
                    .shadow(color: .black.opacity(0.06), radius: 3, x: 0, y: 2)
            }
            .buttonStyle(.plain)
            .disabled(currentDayIndex == 0)

            VStack(spacing: 2) {
                Text(dayLabel)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Color.atlasBlack)
                Text("Day \(currentDayIndex + 1) of \(totalDays)")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(Color.atlasBlack.opacity(0.4))
            }
            .frame(maxWidth: .infinity)

            Button {
                if currentDayIndex < tripDays.count - 1 { currentDayIndex += 1; Haptics.light() }
            } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(currentDayIndex < tripDays.count - 1 ? Color.atlasBlack : Color.atlasBlack.opacity(0.2))
                    .frame(width: 36, height: 36)
                    .background(Color.white)
                    .clipShape(Circle())
                    .shadow(color: .black.opacity(0.06), radius: 3, x: 0, y: 2)
            }
            .buttonStyle(.plain)
            .disabled(currentDayIndex >= tripDays.count - 1)
        }
        .padding(.vertical, 4)
    }

    // MARK: - Itinerary Section

    private func itinerarySection(slot: TimeSlot) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            // Section header
            HStack(spacing: 6) {
                Image(systemName: slot.icon)
                    .font(.system(size: 12))
                    .foregroundStyle(slot.iconColor)
                Text(slot.label)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Color.atlasBlack)
                Text("·  \(slot.timeRange)")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color.atlasBlack.opacity(0.4))
                Spacer()
            }

            // Items
            let slotItems = items(for: slot)
            if slotItems.isEmpty {
                emptySlotHint(slot: slot)
            } else {
                VStack(spacing: 6) {
                    ForEach(slotItems) { item in
                        ItineraryItemCard(item: item, onRemove: {
                            removeFromDay(item)
                        })
                    }
                }
            }

            // Add button
            addToSlotButton(slot: slot)
        }
        .padding(14)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.04), radius: 4, x: 0, y: 2)
    }

    private func emptySlotHint(slot: TimeSlot) -> some View {
        Text("Nothing planned for \(slot.label.lowercased()) yet")
            .font(.system(size: 12))
            .foregroundStyle(Color.atlasBlack.opacity(0.3))
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.vertical, 8)
    }

    private func addToSlotButton(slot: TimeSlot) -> some View {
        Button {
            addingToSlot = slot
            Haptics.light()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "plus")
                    .font(.system(size: 12, weight: .bold))
                Text("Add to \(slot.label)")
                    .font(.system(size: 12, weight: .semibold))
            }
            .foregroundStyle(Color.atlasBlack.opacity(0.5))
            .frame(maxWidth: .infinity)
            .frame(height: 36)
            .background(Color.clear)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
                    .foregroundStyle(Color.atlasBlack.opacity(0.2))
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Helpers

    private func removeFromDay(_ item: TripItem) {
        item.dayAssigned  = nil
        item.timeAssigned = nil
        Haptics.light()
    }
}

// MARK: - Itinerary Item Card

private struct ItineraryItemCard: View {
    let item: TripItem
    var onRemove: () -> Void
    @Environment(UserProfile.self) private var userProfile

    private var timeLabel: String? {
        guard let time = item.timeAssigned else { return nil }
        let f = DateFormatter()
        f.timeStyle = .short
        f.dateStyle = .none
        return f.string(from: time)
    }

    var body: some View {
        HStack(spacing: 10) {
            // Category color bar
            Rectangle()
                .fill(item.category.accentColor)
                .frame(width: 3)
                .clipShape(Capsule())

            // Content
            VStack(alignment: .leading, spacing: 2) {
                if let t = timeLabel {
                    Text(t)
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundStyle(Color.atlasBlack.opacity(0.4))
                }
                Text(item.title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(item.isCompleted ? Color.atlasBlack.opacity(0.4) : Color.atlasBlack)
                    .strikethrough(item.isCompleted)
            }

            Spacer()

            // Price
            if let price = item.formattedPrice(symbol: userProfile.currencySymbol) {
                Text(price)
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundStyle(Color.atlasBlack.opacity(0.5))
            }

            // Completion toggle
            Button {
                withAnimation(.spring(response: 0.3)) { item.isCompleted.toggle() }
                Haptics.light()
            } label: {
                Image(systemName: item.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20))
                    .foregroundStyle(item.isCompleted ? Color.statusGreen : Color.atlasBlack.opacity(0.2))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color.atlasBeige.opacity(0.6))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .contextMenu {
            Button("Remove from Day", role: .destructive) { onRemove() }
        }
    }
}

// MARK: - Item Picker Sheet

struct ItineraryItemPickerView: View {
    let trip: Trip
    let day: Date
    let slot: TimeSlot

    @Environment(\.dismiss) private var dismiss
    @Environment(UserProfile.self) private var userProfile

    private var unscheduled: [TripItem] {
        trip.items.filter { $0.dayAssigned == nil }
    }

    private var dayLabel: String {
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        return f.string(from: day)
    }

    var body: some View {
        NavigationStack {
            Group {
                if unscheduled.isEmpty {
                    VStack(spacing: 16) {
                        Spacer()
                        Image(systemName: "tray")
                            .font(.system(size: 44, weight: .light))
                            .foregroundStyle(Color.atlasBlack.opacity(0.2))
                        Text("No unscheduled items")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(Color.atlasBlack.opacity(0.5))
                        Text("Add items in Collections first, then schedule them here.")
                            .font(.system(size: 13))
                            .foregroundStyle(Color.atlasBlack.opacity(0.35))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                        Spacer()
                    }
                } else {
                    List(unscheduled) { item in
                        Button {
                            assign(item: item)
                        } label: {
                            HStack(spacing: 12) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(item.category.accentColor.opacity(0.15))
                                        .frame(width: 36, height: 36)
                                    Image(systemName: item.category.icon)
                                        .font(.system(size: 14))
                                        .foregroundStyle(item.category.accentColor)
                                }

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.title)
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundStyle(Color.atlasBlack)
                                    Text(item.category.label)
                                        .font(.system(size: 11))
                                        .foregroundStyle(Color.atlasBlack.opacity(0.4))
                                }

                                Spacer()

                                if let price = item.formattedPrice(symbol: userProfile.currencySymbol) {
                                    Text(price)
                                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                                        .foregroundStyle(Color.atlasBlack.opacity(0.5))
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Add to \(slot.label) · \(dayLabel)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func assign(item: TripItem) {
        // Set day
        item.dayAssigned = Calendar.current.startOfDay(for: day)
        // Set time within slot
        var components = Calendar.current.dateComponents([.year, .month, .day], from: day)
        components.hour   = slot.defaultHour
        components.minute = 0
        item.timeAssigned = Calendar.current.date(from: components)
        Haptics.success()
        dismiss()
    }
}
