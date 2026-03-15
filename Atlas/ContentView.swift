//
//  ContentView.swift
//  Atlas
//

import SwiftUI
import SwiftData
import CloudKit

struct ContentView: View {
    @State private var selectedTab = 0
    @State private var showNewTrip = false
    @State private var showPaywall = false

    @Environment(\.modelContext) private var modelContext
    @Environment(SubscriptionManager.self) private var subscriptionManager

    @Query(filter: #Predicate<Trip> { $0.isShared }) private var sharedTrips: [Trip]
    @Query private var allTrips: [Trip]

    // Free tier: max 2 active (non-completed) trips
    private var activeTripsCount: Int {
        allTrips.filter { $0.statusRaw != "completed" }.count
    }

    private var atFreeLimit: Bool {
        !subscriptionManager.isPro && activeTripsCount >= 2
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $selectedTab) {
                TripsView()
                    .tabItem {
                        Label("Trips", systemImage: selectedTab == 0 ? "airplane.departure" : "airplane")
                    }
                    .tag(0)

                WishlistView()
                    .tabItem {
                        Label("Wishlist", systemImage: selectedTab == 1 ? "heart.text.square.fill" : "heart.text.square")
                    }
                    .tag(1)

                // Placeholder tab for center FAB — empty so no icon appears in tab bar
                Color.atlasBeige
                    .tabItem { }
                    .tag(2)

                MapTabView()
                    .tabItem {
                        Label("Map", systemImage: selectedTab == 3 ? "map.fill" : "map")
                    }
                    .tag(3)

                ProfileView()
                    .tabItem {
                        Label("Profile", systemImage: selectedTab == 4 ? "person.circle.fill" : "person.circle")
                    }
                    .tag(4)
            }
            .tint(Color.atlasTeal)
            .onChange(of: selectedTab) { old, new in
                if new == 2 {
                    selectedTab = old
                    handleNewTrip()
                }
            }

            // Custom floating center + button
            Button {
                handleNewTrip()
            } label: {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: "plus")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 54, height: 54)
                        .background(Color.atlasBlack)
                        .clipShape(Circle())
                        .shadow(color: .black.opacity(0.25), radius: 8, x: 0, y: 4)
                        .overlay(
                            Circle()
                                .stroke(Color.atlasBeige, lineWidth: 4)
                        )

                    // Lock badge when at free tier limit
                    if atFreeLimit {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 16, height: 16)
                            .background(Color.atlasTeal)
                            .clipShape(Circle())
                            .offset(x: 3, y: -3)
                    }
                }
            }
            .offset(y: -26)
        }
        .sheet(isPresented: $showNewTrip) {
            NewTripView()
                .presentationDetents([.large])
                .presentationDragIndicator(.hidden)
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView()
                .environment(subscriptionManager)
                .presentationDetents([.large])
                .presentationDragIndicator(.hidden)
        }
        .onAppear {
            configureTabBar()
        }
        // When the app foregrounds, pull fresh changes for all shared trips.
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            guard !sharedTrips.isEmpty else { return }
            Task {
                for trip in sharedTrips {
                    try? await CloudKitSharingManager.shared.fetchChanges(for: trip, in: modelContext)
                }
            }
        }
    }

    // MARK: - Trip Creation Gate

    private func handleNewTrip() {
        Haptics.medium()
        if atFreeLimit {
            showPaywall = true
        } else {
            showNewTrip = true
        }
    }
}

#Preview {
    ContentView()
        .environment(UserProfile.shared)
        .environment(SubscriptionManager.shared)
        .modelContainer(for: [Trip.self, TripItem.self, CrewMember.self, Expense.self, WishlistDestination.self], inMemory: true)
}
