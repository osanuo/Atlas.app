//
//  TripDetailView.swift
//  Atlas
//

import SwiftUI
import SwiftData
import MapKit

struct TripDetailView: View {
    let trip: Trip
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(UserProfile.self) private var userProfile

    @State private var selectedCategory: ItemCategory = .restaurants
    @State private var selectedTab: TripTab = .collections
    @State private var showAddItem = false
    @State private var showEditTrip = false

    // Booking stat helpers
    private var confirmedFlights: Bool {
        trip.items.contains { $0.category == .transportation && $0.bookingStatus == .confirmed }
    }
    private var confirmedStay: Bool {
        trip.items.contains { $0.category == .accommodation && $0.bookingStatus == .confirmed }
    }

    // Share summary text
    private var shareSummary: String {
        var lines = ["\(trip.destination) — \(trip.dateRangeString)"]
        lines.append("\(trip.durationDays) days · \(trip.travelerCount) traveler\(trip.travelerCount == 1 ? "" : "s")")
        if let budget = trip.budget { lines.append("Budget: \(budget.asCurrency(userProfile.currencySymbol))") }
        lines.append("Items planned: \(trip.items.count)")
        return lines.joined(separator: "\n")
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                // MARK: Teal Header
                detailHeader
                    .tealHeader()

                // MARK: Stats Row
                statsRow
                    .padding(.horizontal, 20)
                    .padding(.top, 20)

                // MARK: Tab Bar
                tabBar
                    .padding(.top, 20)

                // MARK: Tab Content
                tabContent
                    .padding(.top, 12)
                    .padding(.bottom, 100)
            }
        }
        .background(Color.atlasBeige.ignoresSafeArea())
        .ignoresSafeArea(edges: .top)
        .navigationBarBackButtonHidden(true)
        .overlay(alignment: .topLeading) {
            backButton
                .padding(.top, 56)
                .padding(.leading, 20)
        }
        .overlay(alignment: .topTrailing) {
            HStack(spacing: 10) {
                // Share
                ShareLink(item: shareSummary) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 36, height: 36)
                        .background(Color.white.opacity(0.2))
                        .clipShape(Circle())
                }
                // Edit / ⋯
                Button {
                    showEditTrip = true
                    Haptics.light()
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 36, height: 36)
                        .background(Color.white.opacity(0.2))
                        .clipShape(Circle())
                }
            }
            .padding(.top, 56)
            .padding(.trailing, 20)
        }
        .overlay(alignment: .bottomTrailing) {
            if selectedTab == .collections {
                fabAddButton
                    .padding(.trailing, 24)
                    .padding(.bottom, 110)
            }
        }
        .sheet(isPresented: $showAddItem) {
            AddItemView(trip: trip, defaultCategory: selectedCategory)
        }
        .sheet(isPresented: $showEditTrip) {
            EditTripView(trip: trip)
        }
    }

    // MARK: - Header

    private var detailHeader: some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer().frame(height: 100)

            // Destination (large flap board)
            FlapBoardView(
                text: trip.destination.uppercased(),
                fontSize: 36
            )

            Spacer().frame(height: 10)

            // Date range
            Text(trip.dateRangeString)
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundStyle(.white.opacity(0.75))

            Spacer().frame(height: 16)

            // Crew glass pill
            if !trip.crew.isEmpty {
                crewPill
            }

            Spacer().frame(height: 28)
        }
        .padding(.horizontal, 20)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var crewPill: some View {
        HStack(spacing: 8) {
            StackedAvatarsView(
                names: trip.crew.map { $0.name },
                maxVisible: 3,
                size: 24
            )
            Text("\(trip.crew.count) Travelers")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .glassCard(cornerRadius: 20)
    }

    // MARK: - Stats Row

    private var statsRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                // Budget card (black)
                if let budget = trip.budget {
                    StatBubble(label: "Budget", value: budget.asCurrency(userProfile.currencySymbol), dark: true)
                }

                // Status card
                StatBubble(label: "Status", value: trip.status.label, dark: false)

                // Duration card
                StatBubble(label: "Duration", value: "\(trip.durationDays) days", dark: false)

                // Items card
                StatBubble(label: "Planned", value: "\(trip.items.count) items", dark: false)

                // Flights confirmed (teal)
                if confirmedFlights {
                    StatBubble(label: "Flights", value: "Booked ✓", dark: false, teal: true)
                }

                // Stay confirmed (teal)
                if confirmedStay {
                    StatBubble(label: "Stay", value: "Booked ✓", dark: false, teal: true)
                }
            }
            .padding(.horizontal, 20)
        }
    }

    // MARK: - Tab Bar (Collections | Itinerary | Budget | Map)

    private var tabBar: some View {
        HStack(spacing: 0) {
            ForEach(TripTab.allCases, id: \.self) { tab in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { selectedTab = tab }
                    Haptics.light()
                } label: {
                    VStack(spacing: 6) {
                        Text(tab.label)
                            .font(.system(size: 13, weight: selectedTab == tab ? .bold : .medium))
                            .foregroundStyle(selectedTab == tab ? Color.atlasTeal : Color.atlasBlack.opacity(0.5))
                        Rectangle()
                            .fill(selectedTab == tab ? Color.atlasTeal : Color.clear)
                            .frame(height: 2)
                            .clipShape(Capsule())
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, 2)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 20)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color.atlasBlack.opacity(0.08))
                .frame(height: 1)
        }
    }

    // MARK: - Tab Content

    @ViewBuilder
    private var tabContent: some View {
        switch selectedTab {
        case .collections:
            VStack(spacing: 12) {
                categoryTabs
                CategoryListView(trip: trip, category: selectedCategory)
                    .padding(.horizontal, 20)
            }
        case .itinerary:
            ItineraryView(trip: trip)
                .padding(.horizontal, 20)
        case .budget:
            BudgetView(trip: trip)
                .padding(.horizontal, 20)
        case .map:
            TripMapView(trip: trip)
                .padding(.horizontal, 20)
        }
    }

    // MARK: - Category Tabs (Collections sub-navigation)

    private var categoryTabs: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(ItemCategory.allCases, id: \.rawValue) { category in
                    CategoryTab(
                        category: category,
                        count: trip.items.filter { $0.category == category }.count,
                        isSelected: selectedCategory == category
                    ) {
                        withAnimation(.easeInOut(duration: 0.2)) { selectedCategory = category }
                        Haptics.light()
                    }
                }
            }
            .padding(.horizontal, 20)
        }
    }

    // MARK: - Back Button

    private var backButton: some View {
        Button {
            dismiss()
            Haptics.light()
        } label: {
            Image(systemName: "chevron.left")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 36, height: 36)
                .background(Color.white.opacity(0.2))
                .clipShape(Circle())
        }
    }

    // MARK: - FAB Add Button

    private var fabAddButton: some View {
        Button {
            showAddItem = true
            Haptics.medium()
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 52, height: 52)
                .background(Color.atlasBlack)
                .clipShape(Circle())
                .shadow(color: .black.opacity(0.25), radius: 8, x: 0, y: 4)
        }
    }
}

// MARK: - Trip Tab

enum TripTab: CaseIterable {
    case collections, itinerary, budget, map
    var label: String {
        switch self {
        case .collections: return "Collections"
        case .itinerary:   return "Itinerary"
        case .budget:      return "Budget"
        case .map:         return "Map"
        }
    }
}

// MARK: - Stat Bubble

private struct StatBubble: View {
    let label: String
    let value: String
    var dark: Bool = false
    var teal: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(dark ? .white.opacity(0.6) : teal ? Color.atlasTeal.opacity(0.8) : Color.atlasBlack.opacity(0.5))
                .textCase(.uppercase)
                .kerning(0.5)
            Text(value)
                .font(.system(size: 16, weight: .bold, design: dark ? .monospaced : .default))
                .foregroundStyle(dark ? .white : teal ? Color.atlasTeal : Color.atlasBlack)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(dark ? Color.atlasBlack : teal ? Color.atlasTeal.opacity(0.1) : Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.06), radius: 4, x: 0, y: 2)
        .overlay(
            teal ? RoundedRectangle(cornerRadius: 14).stroke(Color.atlasTeal.opacity(0.3), lineWidth: 1) : nil
        )
    }
}

// MARK: - Category Tab

private struct CategoryTab: View {
    let category: ItemCategory
    let count: Int
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: category.icon)
                    .font(.system(size: 12))
                Text(category.label)
                    .font(.system(size: 12, weight: .semibold))
                if count > 0 {
                    Text("\(count)")
                        .font(.system(size: 10, weight: .bold))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(isSelected ? Color.white.opacity(0.25) : category.accentColor.opacity(0.2))
                        .clipShape(Capsule())
                }
            }
            .foregroundStyle(isSelected ? .white : Color.atlasBlack)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(isSelected ? category.accentColor : Color.white)
            .clipShape(Capsule())
            .shadow(color: .black.opacity(0.04), radius: 3, x: 0, y: 2)
        }
        .buttonStyle(.plain)
    }
}


#Preview {
    NavigationStack {
        TripDetailView(trip: Trip(
            name: "Tokyo Adventure",
            destination: "TOKYO",
            destinationFlag: "🇯🇵",
            startDate: Date(),
            endDate: Date().addingTimeInterval(86400 * 12),
            cardColorHex: "FCDA85",
            status: .planning,
            budget: 2400,
            travelerCount: 5
        ))
    }
    .modelContainer(for: [Trip.self, TripItem.self, CrewMember.self, Expense.self], inMemory: true)
}
