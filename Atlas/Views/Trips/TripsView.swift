//
//  TripsView.swift
//  Atlas
//

import SwiftUI
import SwiftData

struct TripsView: View {
    @Query(sort: \Trip.startDate) private var trips: [Trip]
    @Environment(\.modelContext) private var modelContext
    @State private var selectedTrip: Trip?
    @State private var tripToDelete: Trip? = nil

    private var activeTrip: Trip? {
        trips.first { $0.status == .active }
    }

    private var upcomingTrips: [Trip] {
        trips.filter { $0.status == .planning || $0.status == .confirmed }
            .sorted { $0.startDate < $1.startDate }
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    // MARK: Teal Header
                    headerSection
                        .tealHeader()

                    // MARK: Content
                    VStack(alignment: .leading, spacing: 24) {
                        Spacer().frame(height: 24)

                        // Active trip banner
                        if let active = activeTrip {
                            activeTripSection(active)
                                .padding(.horizontal, 20)
                        }

                        // Upcoming trips
                        if !upcomingTrips.isEmpty {
                            upcomingSection
                                .padding(.horizontal, 20)
                        }

                        // Empty state
                        if activeTrip == nil && upcomingTrips.isEmpty {
                            emptyState
                                .padding(.horizontal, 20)
                        }

                        Spacer().frame(height: 100)
                    }
                    .background(Color.atlasBeige)
                }
            }
            .background(Color.atlasBeige.ignoresSafeArea())
            .ignoresSafeArea(edges: .top)
            .navigationDestination(item: $selectedTrip) { trip in
                TripDetailView(trip: trip)
            }
            .onChange(of: trips) { _, _ in writeWidgetData() }
            .onAppear { writeWidgetData() }
        }
        .alert("Delete Trip", isPresented: Binding(
            get: { tripToDelete != nil },
            set: { if !$0 { tripToDelete = nil } }
        )) {
            Button("Delete", role: .destructive) {
                if let trip = tripToDelete { modelContext.delete(trip); tripToDelete = nil }
            }
            Button("Cancel", role: .cancel) { tripToDelete = nil }
        } message: {
            if let trip = tripToDelete {
                Text("\"\(trip.name)\" and all its items will be permanently removed.")
            }
        }
    }

    // MARK: - Widget Data

    private func writeWidgetData() {
        let shared = UserDefaults(suiteName: "group.com.osanuo.Atlas")
        // Find next upcoming trip (active or planning/confirmed with future start date)
        let nextTrip = (activeTrip ?? upcomingTrips.first)
        shared?.set(nextTrip?.destination ?? "", forKey: "widget_destination")
        shared?.set(nextTrip?.destinationFlag ?? "✈️", forKey: "widget_flag")
        shared?.set(nextTrip?.startDate, forKey: "widget_startDate")
        shared?.set(nextTrip?.name ?? "", forKey: "widget_tripName")
        shared?.set(nextTrip?.id.uuidString ?? "", forKey: "widget_tripID")
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer().frame(height: 60)

            Text("My Trips")
                .font(.system(size: 34, weight: .bold))
                .foregroundStyle(.white)

            Spacer().frame(height: 6)

            Text("Plan. Collaborate. Explore.\nYour next adventure awaits.")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.white.opacity(0.75))
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: 200, alignment: .leading)

            Spacer().frame(height: 28)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
        .overlay(alignment: .topTrailing) {
            DotMatrixView(columns: 7, rows: 4, opacity: 0.1)
                .padding(.top, 40)
                .padding(.trailing, 16)
        }
    }

    // MARK: - Active Trip

    private func activeTripSection(_ trip: Trip) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Active Trip", systemImage: "location.fill")
                .atlasLabel()
                .foregroundStyle(Color.atlasTeal)

            TripCard(trip: trip) {
                selectedTrip = trip
            }
            .contextMenu {
                Button("Archive Trip") {
                    withAnimation { trip.status = .completed }
                    Haptics.medium()
                }
                Button("Delete Trip", role: .destructive) {
                    tripToDelete = trip
                }
            }
        }
    }

    // MARK: - Upcoming

    private var upcomingSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Upcoming Departures")
                .atlasLabel()

            LazyVStack(spacing: 12) {
                ForEach(Array(upcomingTrips.enumerated()), id: \.element.id) { index, trip in
                    TripCard(trip: trip) {
                        selectedTrip = trip
                    }
                    .contextMenu {
                        Button("Archive Trip") {
                            withAnimation { trip.status = .completed }
                            Haptics.medium()
                        }
                        Button("Delete Trip", role: .destructive) {
                            tripToDelete = trip
                        }
                    }
                }
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 20) {
            Spacer().frame(height: 40)

            Image(systemName: "map")
                .font(.system(size: 56, weight: .light))
                .foregroundStyle(Color.atlasBlack.opacity(0.15))

            VStack(spacing: 8) {
                Text("No trips yet")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(Color.atlasBlack.opacity(0.6))

                Text("Tap + to start planning your next adventure")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.atlasBlack.opacity(0.4))
                    .multilineTextAlignment(.center)
            }
        }
    }
}


#Preview {
    TripsView()
        .environment(UserProfile.shared)
        .environment(SubscriptionManager.shared)
        .modelContainer(for: [Trip.self, TripItem.self, CrewMember.self, Expense.self, WishlistDestination.self, VisitedLocation.self], inMemory: true)
}
