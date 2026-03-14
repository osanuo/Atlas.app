//
//  ContentView.swift
//  Atlas
//
//  Created by Dawid Piotrowski on 11/03/2026.
//

import SwiftUI
import SwiftData
import CloudKit

struct ContentView: View {
    @State private var selectedTab = 0
    @State private var showNewTrip = false

    @Environment(\.modelContext) private var modelContext
    @Query(filter: #Predicate<Trip> { $0.isShared }) private var sharedTrips: [Trip]

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

                CrewView()
                    .tabItem {
                        Label("Crew", systemImage: selectedTab == 3 ? "person.2.fill" : "person.2")
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
                    showNewTrip = true
                    Haptics.medium()
                }
            }

            // Custom floating center + button
            Button {
                showNewTrip = true
                Haptics.medium()
            } label: {
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
            }
            .offset(y: -26)
        }
        .sheet(isPresented: $showNewTrip) {
            NewTripView()
                .presentationDetents([.large])
                .presentationDragIndicator(.hidden)
        }
        .onAppear {
            configureTabBar()
        }
        // When the app foregrounds, pull fresh changes for all shared trips.
        // This covers: silent push received while in background + manual foreground.
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            guard !sharedTrips.isEmpty else { return }
            Task {
                for trip in sharedTrips {
                    try? await CloudKitSharingManager.shared.fetchChanges(for: trip, in: modelContext)
                }
            }
        }
    }
}

#Preview {
    ContentView()
        .environment(UserProfile.shared)
        .modelContainer(for: [Trip.self, TripItem.self, CrewMember.self, Expense.self, WishlistDestination.self], inMemory: true)
}
