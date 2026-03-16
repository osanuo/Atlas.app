//
//  CrewView.swift
//  Atlas
//

import SwiftUI
import SwiftData

struct CrewView: View {
    @Query private var allTrips: [Trip]
    @Environment(\.modelContext) private var modelContext

    @State private var showInvite = false
    @State private var selectedTrip: Trip?

    private var allCrew: [CrewMember] {
        allTrips.flatMap { $0.crew }
    }

    private var confirmedCount: Int {
        allCrew.filter { $0.status == .confirmed }.count
    }

    private var activeCount: Int {
        allCrew.filter { $0.status != .declined }.count
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                // MARK: Teal Header
                headerSection
                    .tealHeader()

                // MARK: Content
                VStack(spacing: 16) {
                    Spacer().frame(height: 24)

                    // Trip filter (if multiple trips)
                    if allTrips.count > 1 {
                        tripFilterScroll
                            .padding(.horizontal, 20)
                    }

                    // Invite card
                    inviteCard
                        .padding(.horizontal, 20)

                    // Crew list
                    crewList
                        .padding(.horizontal, 20)
                        .padding(.bottom, 100)
                }
                .background(Color.atlasBeige)
            }
        }
        .background(Color.atlasBeige.ignoresSafeArea())
        .ignoresSafeArea(edges: .top)
        .sheet(isPresented: $showInvite) {
            InviteCrewView(trips: allTrips)
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer().frame(height: 60)

            // Left-aligned title (matches HTML h1 text-4xl)
            Text("Crew Manifest")
                .font(.system(size: 30, weight: .bold))
                .foregroundStyle(.white)
                .padding(.bottom, 8)

            // Inline stats: label above value, divider between
            HStack(alignment: .bottom, spacing: 0) {
                metricBlock(label: "Total", value: String(format: "%02d", allCrew.count))

                Rectangle()
                    .fill(Color.black.opacity(0.1))
                    .frame(width: 1, height: 32)
                    .padding(.horizontal, 16)

                metricBlock(label: "Active", value: String(format: "%02d", activeCount))
            }

            Spacer().frame(height: 28)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
        .overlay(alignment: .topTrailing) {
            DotMatrixView(columns: 5, rows: 3, opacity: 0.1)
                .padding(.top, 50)
                .padding(.trailing, 20)
        }
    }

    private func metricBlock(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.white.opacity(0.6))
                .textCase(.uppercase)
                .kerning(1)
            Text(value)
                .font(.system(size: 20, weight: .bold, design: .monospaced))
                .foregroundStyle(.white)
        }
    }

    // MARK: - Trip Filter

    private var tripFilterScroll: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                FilterChip(label: "All", isActive: selectedTrip == nil) {
                    withAnimation { selectedTrip = nil }
                }
                ForEach(allTrips) { trip in
                    FilterChip(label: trip.destination, isActive: selectedTrip?.id == trip.id) {
                        withAnimation { selectedTrip = trip }
                    }
                }
            }
        }
    }

    // MARK: - Invite Card

    private var inviteCard: some View {
        Button {
            showInvite = true
            Haptics.medium()
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(Color.atlasBlack)
                        .frame(width: 40, height: 40)
                    Image(systemName: "plus")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.white)
                }

                Text("Invite New Traveler")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.atlasBlack)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.atlasBlack.opacity(0.4))
            }
            .padding(16)
            .background(Color.white.opacity(0.6))
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
                    .foregroundStyle(Color.atlasBlack.opacity(0.2))
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Crew List

    private var filteredCrew: [CrewMember] {
        if let trip = selectedTrip {
            return trip.crew
        }
        return allCrew
    }

    @ViewBuilder
    private var crewList: some View {
        if filteredCrew.isEmpty {
            emptyCrewState
        } else {
            LazyVStack(spacing: 10) {
                ForEach(filteredCrew) { member in
                    CrewMemberCard(member: member)
                }
            }
        }
    }

    private var emptyCrewState: some View {
        VStack(spacing: 12) {
            Image(systemName: "person.2.slash")
                .font(.system(size: 40))
                .foregroundStyle(Color.atlasBlack.opacity(0.2))
            Text("No crew members yet")
                .font(.system(size: 15))
                .foregroundStyle(Color.atlasBlack.opacity(0.4))
            Text("Invite people to join your trip")
                .font(.system(size: 13))
                .foregroundStyle(Color.atlasBlack.opacity(0.3))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }
}

// MARK: - Filter Chip

struct FilterChip: View {
    let label: String
    let isActive: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(isActive ? Color.white : Color.atlasBlack)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(isActive ? Color.atlasBlack : Color.white.opacity(0.7))
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Invite Sheet

struct InviteCrewView: View {
    let trips: [Trip]
    /// When set, the member is auto-assigned here and the trip picker is hidden.
    var preassignedTrip: Trip? = nil

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var name = ""
    @State private var selectedTrip: Trip?
    @State private var flightInfo = ""
    @State private var status: CrewStatus = .pending

    var body: some View {
        NavigationStack {
            Form {
                Section("Crew Member") {
                    TextField("Full Name", text: $name)
                }

                // Show trip picker only when not pre-assigned to a specific trip
                if preassignedTrip == nil && !trips.isEmpty {
                    Section("Assign to Trip") {
                        Picker("Trip", selection: $selectedTrip) {
                            Text("None").tag(Optional<Trip>.none)
                            ForEach(trips) { trip in
                                Text(trip.destination).tag(Optional(trip))
                            }
                        }
                    }
                }

                if let trip = preassignedTrip {
                    Section("Trip") {
                        Label(trip.destination, systemImage: "airplane")
                            .foregroundStyle(Color.atlasTeal)
                    }
                }

                Section("Details") {
                    TextField("Flight Info (optional)", text: $flightInfo)
                    Picker("Status", selection: $status) {
                        ForEach(CrewStatus.allCases, id: \.rawValue) { s in
                            Text(s.label).tag(s)
                        }
                    }
                }
            }
            .navigationTitle("Invite Traveler")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        addMember()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    private func addMember() {
        let targetTrip = preassignedTrip ?? selectedTrip ?? trips.first
        let member = CrewMember(
            name: name.trimmingCharacters(in: .whitespaces),
            status: status,
            flightInfo: flightInfo,
            trip: targetTrip
        )
        modelContext.insert(member)
        if let trip = targetTrip {
            trip.crew.append(member)
        }
        Haptics.success()
        dismiss()
    }
}

#Preview {
    CrewView()
        .modelContainer(for: [Trip.self, TripItem.self, CrewMember.self, Expense.self, WishlistDestination.self, VisitedLocation.self], inMemory: true)
}
