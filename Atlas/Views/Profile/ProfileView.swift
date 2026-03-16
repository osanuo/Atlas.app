//
//  ProfileView.swift
//  Atlas
//

import SwiftUI
import SwiftData
import PhotosUI

struct ProfileView: View {
    @Environment(UserProfile.self) private var userProfile
    @Environment(\.modelContext) private var modelContext
    @Environment(SubscriptionManager.self) private var subscriptionManager

    @State private var selectedPhoto: PhotosPickerItem? = nil
    @State private var showPaywall = false
    @State private var travelLogExpanded = false
    @State private var isEditingName = false
    @State private var nameInput = ""
    @FocusState private var nameFocused: Bool

    @Query(
        filter: #Predicate<Trip> { $0.statusRaw == "completed" },
        sort: \Trip.endDate,
        order: .reverse
    ) private var completedTrips: [Trip]

    @Query private var allTrips: [Trip]
    @Query private var visitedLocations: [VisitedLocation]

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                // MARK: Teal Header
                headerSection
                    .tealHeader()

                // Content below header
                VStack(spacing: 0) {
                    Spacer().frame(height: 24)

                    // MARK: Stats Grid
                    statsGrid
                        .padding(.horizontal, 20)

                    // MARK: Pro Upgrade Banner (non-Pro only)
                    if !subscriptionManager.isPro {
                        proUpgradeBanner
                            .padding(.horizontal, 20)
                    }

                    Spacer().frame(height: 32)

                    // MARK: Currency Picker
                    currencySection
                        .padding(.horizontal, 20)

                    Spacer().frame(height: 32)

                    // MARK: Travel Log
                    travelLogSection
                        .padding(.horizontal, 20)

                    // MARK: Sign Out
                    Button {
                        userProfile.signOut()
                        Haptics.medium()
                    } label: {
                        Text("Sign Out Session")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(Color.red.opacity(0.6))
                            .textCase(.uppercase)
                            .kerning(1.5)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 24)
                    }
                    .padding(.top, 8)

                    // MARK: Debug Panel (DEBUG builds only)
                    #if DEBUG
                    debugPanel
                        .padding(.horizontal, 20)
                        .padding(.bottom, 24)
                    #endif

                    Spacer().frame(height: 100)
                }
                .background(Color.atlasBeige)
            }
        }
        .background(Color.atlasBeige.ignoresSafeArea())
        .ignoresSafeArea(edges: .top)
        .onAppear {
            userProfile.syncStats(from: allTrips, mapPins: visitedLocations, isPro: subscriptionManager.isPro)
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView()
                .environment(subscriptionManager)
                .presentationDetents([.large])
                .presentationDragIndicator(.hidden)
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 0) {
            Spacer().frame(height: 60)

            // Avatar — tap to pick a photo
            PhotosPicker(
                selection: $selectedPhoto,
                matching: .images,
                photoLibrary: .shared()
            ) {
                ZStack(alignment: .bottomTrailing) {
                    // Outer white ring + shadow
                    ZStack {
                        Circle()
                            .fill(Color.white)
                            .frame(width: 98, height: 98)
                            .shadow(color: .black.opacity(0.2), radius: 12, x: 0, y: 6)

                        if let data = userProfile.avatarImageData,
                           let uiImage = UIImage(data: data) {
                            // User's chosen photo
                            Image(uiImage: uiImage)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 88, height: 88)
                                .clipShape(Circle())
                        } else {
                            // Fallback: colored initials
                            AvatarInitialsView(
                                initials: userProfile.initials,
                                size: 88,
                                colorSeed: userProfile.displayName.hashValue
                            )
                        }
                    }

                    // Camera badge
                    ZStack {
                        Circle()
                            .fill(Color.atlasBlack)
                            .frame(width: 28, height: 28)
                            .shadow(color: .black.opacity(0.25), radius: 4, x: 0, y: 2)
                        Image(systemName: "camera.fill")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                    .offset(x: 3, y: 3)
                }
            }
            .buttonStyle(.plain)
            .onChange(of: selectedPhoto) { _, newItem in
                Task {
                    if let newItem,
                       let data = try? await newItem.loadTransferable(type: Data.self),
                       let uiImage = UIImage(data: data) {
                        userProfile.setAvatar(from: uiImage)
                    }
                }
            }

            Spacer().frame(height: 12)

            if isEditingName {
                HStack(spacing: 8) {
                    TextField("Your name", text: $nameInput)
                        .font(.system(size: 26, weight: .bold))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .focused($nameFocused)
                        .onSubmit { commitName() }
                    Button { commitName() } label: {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 24))
                            .foregroundStyle(.white)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 32)
            } else {
                Button {
                    nameInput = userProfile.displayName
                    isEditingName = true
                    nameFocused = true
                    Haptics.light()
                } label: {
                    HStack(spacing: 6) {
                        Text(userProfile.displayName)
                            .font(.system(size: 28, weight: .bold))
                            .foregroundStyle(.white)
                        Image(systemName: "pencil")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.6))
                    }
                }
                .buttonStyle(.plain)
            }

            Text("GLOBAL ENTRY ID: \(userProfile.entryId)")
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundStyle(.white.opacity(0.75))
                .kerning(1)
                .padding(.top, 4)

            Spacer().frame(height: 36)
        }
        .padding(.horizontal, 20)
    }

    // MARK: - Stats Grid

    private var statsGrid: some View {
        HStack(spacing: 10) {
            StatCard(label: "Trips", value: userProfile.tripsDisplay)
            StatCard(label: "Countries", value: userProfile.countriesDisplay)
            StatCard(label: userProfile.distanceLabel, value: userProfile.distanceDisplay)
        }
    }

    // MARK: - Pro Upgrade Banner

    private var proUpgradeBanner: some View {
        VStack(spacing: 0) {

            // ── Top: icon + headline ──────────────────────────────────────────
            HStack(alignment: .center, spacing: 16) {
                ZStack {
                    Circle()
                        .fill(Color.atlasTeal.opacity(0.18))
                        .frame(width: 54, height: 54)
                    Image(systemName: "sparkles")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(Color.atlasTeal)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("ATLAS PRO")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(Color.atlasTeal)
                        .kerning(1.5)
                    Text("Plan Without Limits")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(.white)
                    Text("Unlimited trips, Travel Map, Web Clips & more")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white.opacity(0.5))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 16)

            // ── Separator ────────────────────────────────────────────────────
            Rectangle()
                .fill(Color.white.opacity(0.08))
                .frame(height: 1)
                .padding(.horizontal, 4)

            // ── Feature chips ─────────────────────────────────────────────────
            HStack(spacing: 6) {
                featureChip(icon: "infinity",        label: "Unlimited")
                featureChip(icon: "map",             label: "Travel Map")
                featureChip(icon: "link",            label: "Web Clips")
                featureChip(icon: "chart.bar",       label: "Budget")
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)

            // ── CTA button ────────────────────────────────────────────────────
            Button {
                showPaywall = true
                Haptics.medium()
            } label: {
                HStack(spacing: 8) {
                    Text("Unlock Atlas Pro")
                        .font(.system(size: 15, weight: .bold))
                        .kerning(0.3)
                    Image(systemName: "arrow.right")
                        .font(.system(size: 13, weight: .bold))
                }
                .foregroundStyle(Color.atlasBlack)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(Color.atlasTeal)
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .buttonStyle(ScaleButtonStyle())
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
        }
        .background(Color.atlasBlack)
        .clipShape(RoundedRectangle(cornerRadius: 22))
        .shadow(color: Color.atlasBlack.opacity(0.18), radius: 14, x: 0, y: 6)
        .padding(.top, 8)
    }

    private func commitName() {
        let trimmed = nameInput.trimmingCharacters(in: .whitespaces)
        if !trimmed.isEmpty {
            userProfile.displayName = trimmed
        }
        isEditingName = false
        nameFocused = false
        Haptics.success()
    }

    private func featureChip(icon: String, label: String) -> some View {
        VStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.atlasTeal)
            Text(label)
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(.white.opacity(0.45))
                .kerning(0.3)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
        )
    }

    // MARK: - Currency Picker

    private var currencySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Currency")
                .atlasLabel()
                .padding(.leading, 4)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(AppCurrency.all) { currency in
                        let isSelected = userProfile.currencyCode == currency.code
                        Button {
                            userProfile.currencyCode = currency.code
                            Haptics.light()
                        } label: {
                            VStack(spacing: 3) {
                                Text(currency.symbol)
                                    .font(.system(size: 17, weight: .bold, design: .monospaced))
                                Text(currency.code)
                                    .font(.system(size: 9, weight: .bold))
                                    .kerning(0.5)
                            }
                            .foregroundStyle(isSelected ? .white : Color.atlasBlack)
                            .frame(width: 56, height: 52)
                            .background(isSelected ? Color.atlasBlack : Color.white)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(Color.black.opacity(isSelected ? 0 : 0.06), lineWidth: 1)
                            )
                        }
                        .buttonStyle(ScaleButtonStyle())
                    }
                }
                .padding(.horizontal, 4)
                .padding(.vertical, 4)
            }
        }
    }

    // MARK: - Travel Log

    private var travelLogSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Travel Log")
                .atlasLabel()
                .padding(.leading, 4)

            if completedTrips.isEmpty {
                emptyTravelLog
            } else {
                let visible = travelLogExpanded ? completedTrips : Array(completedTrips.prefix(3))
                ForEach(visible) { trip in
                    TravelLogRow(trip: trip)
                }
                if completedTrips.count > 3 {
                    Button {
                        withAnimation(.easeInOut(duration: 0.25)) { travelLogExpanded.toggle() }
                    } label: {
                        HStack(spacing: 6) {
                            Text(travelLogExpanded ? "Show less" : "Show all \(completedTrips.count) trips")
                                .font(.system(size: 13, weight: .medium))
                            Image(systemName: travelLogExpanded ? "chevron.up" : "chevron.down")
                                .font(.system(size: 11, weight: .semibold))
                        }
                        .foregroundStyle(Color.atlasTeal)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                    }
                }
            }
        }
    }

    private var emptyTravelLog: some View {
        HStack {
            Spacer()
            VStack(spacing: 8) {
                Image(systemName: "globe")
                    .font(.system(size: 32))
                    .foregroundStyle(Color.atlasBlack.opacity(0.2))
                Text("No completed trips yet")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.atlasBlack.opacity(0.4))
            }
            .padding(.vertical, 32)
            Spacer()
        }
    }

    // MARK: - Debug Panel

    #if DEBUG
    private var debugPanel: some View {
        VStack(alignment: .leading, spacing: 14) {

            // Section header
            HStack(spacing: 8) {
                Image(systemName: "hammer.fill")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Color.orange)
                Text("DEVELOPER")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Color.orange)
                    .kerning(1.5)
                Spacer()
                Text("DEBUG BUILD")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundStyle(Color.orange.opacity(0.6))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.orange.opacity(0.1))
                    .clipShape(Capsule())
            }

            // Data summary row
            HStack(spacing: 8) {
                debugStatChip(value: "\(allTrips.count)", label: "trips")
                debugStatChip(value: "\(allTrips.flatMap { $0.items }.count)", label: "items")
                debugStatChip(value: "\(allTrips.flatMap { $0.expenses }.count)", label: "expenses")
                debugStatChip(value: "\(allTrips.flatMap { $0.crew }.count)", label: "crew")
            }

            // Buttons
            HStack(spacing: 10) {
                // Seed
                Button {
                    DebugSeedService.seed(in: modelContext)
                    userProfile.syncStats(from: allTrips, mapPins: visitedLocations, isPro: subscriptionManager.isPro)
                    Haptics.success()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "wand.and.stars")
                            .font(.system(size: 13, weight: .semibold))
                        Text("Seed Data")
                            .font(.system(size: 13, weight: .bold))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.orange)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(ScaleButtonStyle())

                // Clear
                Button {
                    DebugSeedService.clearAll(in: modelContext)
                    userProfile.syncStats(from: allTrips, mapPins: visitedLocations, isPro: subscriptionManager.isPro)
                    Haptics.medium()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "trash")
                            .font(.system(size: 13, weight: .semibold))
                        Text("Clear All")
                            .font(.system(size: 13, weight: .bold))
                    }
                    .foregroundStyle(Color.red.opacity(0.8))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.red.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.red.opacity(0.2), lineWidth: 1)
                    )
                }
                .buttonStyle(ScaleButtonStyle())
            }

            // Pro toggle
            Button {
                subscriptionManager.toggleDevPro()
                Haptics.light()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: subscriptionManager.isPro ? "star.fill" : "star")
                        .font(.system(size: 13, weight: .semibold))
                    Text(subscriptionManager.isPro ? "Pro: ON (tap to disable)" : "Pro: OFF (tap to enable)")
                        .font(.system(size: 13, weight: .bold))
                }
                .foregroundStyle(subscriptionManager.isPro ? Color.atlasBlack : Color.orange.opacity(0.8))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(subscriptionManager.isPro ? Color.atlasTeal.opacity(0.15) : Color.orange.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(subscriptionManager.isPro ? Color.atlasTeal.opacity(0.3) : Color.orange.opacity(0.2), lineWidth: 1)
                )
            }
            .buttonStyle(ScaleButtonStyle())

            // What gets seeded
            VStack(alignment: .leading, spacing: 6) {
                Text("Seed inserts:")
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .foregroundStyle(Color.atlasBlack.opacity(0.35))
                Group {
                    debugSeedLine("🇯🇵 Tokyo Adventure — active, $2,400, 3 crew, 12 items w/ itinerary")
                    debugSeedLine("🇫🇷 Paris Getaway — planning, $1,800, 2 crew, 10 items + deposits")
                    debugSeedLine("🇪🇸 Marbella Summer — planning, $2,200, 3 crew, 7 items")
                    debugSeedLine("🇯🇵 Kyoto Sakura — confirmed, $1,600, 1 crew, 8 items")
                    debugSeedLine("🇳🇱 Amsterdam — completed, $900, 7 items + expenses")
                    debugSeedLine("🇩🇪 Berlin Techno — completed, $600 (over!), 6 items + expenses")
                    debugSeedLine("🗺️  8 map pins — 6 countries across 3 continents")
                    debugSeedLine("❤️  8 wishlist destinations (1 already visited)")
                }
            }
            .padding(12)
            .background(Color.atlasBlack.opacity(0.03))
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .padding(16)
        .background(Color.orange.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(Color.orange.opacity(0.2), lineWidth: 1)
        )
    }

    private func debugStatChip(value: String, label: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 16, weight: .bold, design: .monospaced))
                .foregroundStyle(Color.atlasBlack)
            Text(label)
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(Color.atlasBlack.opacity(0.4))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func debugSeedLine(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 10, design: .monospaced))
            .foregroundStyle(Color.atlasBlack.opacity(0.5))
            .frame(maxWidth: .infinity, alignment: .leading)
    }
    #endif
}

// MARK: - Stat Card

private struct StatCard: View {
    let label: String
    let value: String

    var body: some View {
        VStack(spacing: 8) {
            Text(label)
                .atlasLabel()

            FlapBoardView(text: value, light: true, fontSize: 20)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.04), radius: 4, x: 0, y: 2)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.black.opacity(0.05), lineWidth: 1)
        )
    }
}

// MARK: - Travel Log Row

private struct TravelLogRow: View {
    let trip: Trip

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(hex: "F5F3F1"))
                Text(trip.destinationFlag)
                    .font(.system(size: 24))
            }
            .frame(width: 48, height: 48)

            VStack(alignment: .leading, spacing: 3) {
                Text(trip.destination.capitalized)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Color.atlasBlack)

                Text(trip.shortDateRangeString)
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(Color.atlasBlack.opacity(0.45))
            }

            Spacer()

            PillBadge(label: "Completed", style: .outline)
        }
        .padding(14)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.04), radius: 4, x: 0, y: 2)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.black.opacity(0.05), lineWidth: 1)
        )
    }
}

// Globe map, AddVisitedLocationSheet, GlobeMapView and VisitedLocationAnnotation
// have been moved to Views/Map/MapTabView.swift

#Preview {
    ProfileView()
        .environment(UserProfile.shared)
        .environment(SubscriptionManager.shared)
        .modelContainer(for: [Trip.self, TripItem.self, CrewMember.self, Expense.self, WishlistDestination.self, VisitedLocation.self], inMemory: true)
}
