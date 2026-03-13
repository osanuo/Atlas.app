//
//  ProfileView.swift
//  Atlas
//

import SwiftUI
import SwiftData
import PhotosUI
import MapKit
import CoreLocation

struct ProfileView: View {
    @Environment(UserProfile.self) private var userProfile
    @Environment(\.modelContext) private var modelContext

    @State private var selectedPhoto: PhotosPickerItem? = nil
    @State private var showAddLocationSheet = false
    @State private var isSyncing = false
    @Query private var visitedLocations: [VisitedLocation]

    @Query(
        filter: #Predicate<Trip> { $0.statusRaw == "completed" },
        sort: \Trip.endDate,
        order: .reverse
    ) private var completedTrips: [Trip]

    @Query private var allTrips: [Trip]

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

                    Spacer().frame(height: 32)

                    // MARK: Currency Picker
                    currencySection
                        .padding(.horizontal, 20)

                    Spacer().frame(height: 32)

                    // MARK: Globe Map
                    globeSection
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
        .sheet(isPresented: $showAddLocationSheet) {
            AddVisitedLocationSheet { name, lat, lon, date in
                let loc = VisitedLocation(
                    name: name,
                    latitude: lat,
                    longitude: lon,
                    dateVisited: date,
                    source: "manual"
                )
                modelContext.insert(loc)
                Haptics.success()
            }
        }
        .onAppear {
            userProfile.syncStats(from: allTrips)
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

            Text(userProfile.displayName)
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(.white)

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
            StatCard(label: "Miles", value: userProfile.milesDisplay)
        }
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

    // MARK: - Globe / Visited Locations

    private var globeSection: some View {
        VStack(alignment: .leading, spacing: 12) {

            // Header row
            HStack(alignment: .center) {
                Text("Visited Locations")
                    .atlasLabel()
                    .padding(.leading, 4)

                Spacer()

                // Sync from completed trips button
                if !completedTrips.isEmpty {
                    Button {
                        syncTripsToGlobe()
                    } label: {
                        HStack(spacing: 4) {
                            if isSyncing {
                                ProgressView()
                                    .scaleEffect(0.7)
                                    .tint(Color.atlasTeal)
                            } else {
                                Image(systemName: "arrow.clockwise")
                                    .font(.system(size: 11, weight: .semibold))
                            }
                            Text(isSyncing ? "Syncing…" : "Sync Trips")
                                .font(.system(size: 11, weight: .semibold))
                        }
                        .foregroundStyle(Color.atlasTeal)
                    }
                    .buttonStyle(.plain)
                    .disabled(isSyncing)
                }

                // Add manual pin button
                Button {
                    showAddLocationSheet = true
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 28, height: 28)
                        .background(Color.atlasBlack)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .padding(.leading, 8)
            }

            // Globe map — UIViewRepresentable so we can unlock full globe zoom
            GlobeMapView(locations: visitedLocations)
                .frame(height: 320)
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .shadow(color: .black.opacity(0.18), radius: 14, x: 0, y: 5)

            // Pin count caption
            HStack(spacing: 5) {
                if visitedLocations.isEmpty {
                    Image(systemName: "mappin")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Color.atlasBlack.opacity(0.3))
                    Text("Sync trips or add a location to drop your first pin")
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundStyle(Color.atlasBlack.opacity(0.4))
                } else {
                    Image(systemName: "mappin.fill")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Color.atlasTeal)
                    Text("\(visitedLocations.count) location\(visitedLocations.count == 1 ? "" : "s") pinned")
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .foregroundStyle(Color.atlasBlack.opacity(0.5))
                }
            }
            .frame(maxWidth: .infinity, alignment: .center)
        }
    }

    // MARK: - Sync Trips → Globe

    private func syncTripsToGlobe() {
        let existingTripNames = Set(
            visitedLocations
                .filter { $0.source == "trip" }
                .map { $0.name.lowercased() }
        )

        let toSync = completedTrips.filter {
            !existingTripNames.contains($0.destination.lowercased())
        }

        guard !toSync.isEmpty else { return }

        isSyncing = true

        Task {
            for trip in toSync {
                let queryParts = [trip.destination.capitalized, trip.country]
                    .filter { !$0.isEmpty }
                let query = queryParts.joined(separator: ", ")

                if let coord = await geocodeAsync(query) {
                    await MainActor.run {
                        let loc = VisitedLocation(
                            name: trip.destination.capitalized,
                            latitude: coord.latitude,
                            longitude: coord.longitude,
                            dateVisited: trip.endDate,
                            source: "trip"
                        )
                        modelContext.insert(loc)
                    }
                }
                // Brief pause to respect CLGeocoder rate limits
                try? await Task.sleep(for: .milliseconds(400))
            }

            await MainActor.run {
                isSyncing = false
                Haptics.success()
            }
        }
    }

    private func geocodeAsync(_ address: String) async -> CLLocationCoordinate2D? {
        await withCheckedContinuation { continuation in
            CLGeocoder().geocodeAddressString(address) { placemarks, _ in
                continuation.resume(returning: placemarks?.first?.location?.coordinate)
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
                ForEach(completedTrips) { trip in
                    TravelLogRow(trip: trip)
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
                    userProfile.syncStats(from: allTrips)
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
                    userProfile.syncStats(from: allTrips)
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

            // What gets seeded
            VStack(alignment: .leading, spacing: 6) {
                Text("Seed inserts:")
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .foregroundStyle(Color.atlasBlack.opacity(0.35))
                Group {
                    debugSeedLine("🇯🇵 Tokyo Adventure — active, $2,400 budget, 3 crew, 10 items + expenses")
                    debugSeedLine("🇫🇷 Paris Getaway — planning, $1,800 budget, 1 crew, 8 items")
                    debugSeedLine("🇩🇪 Berlin Techno — completed, $600 budget (over!), 5 items + expenses")
                    debugSeedLine("🇯🇵 Kyoto Sakura — confirmed, $1,600 budget, 2 crew, 6 items with addresses")
                    debugSeedLine("❤️  6 wishlist destinations (1 already visited)")
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

// MARK: - Add Visited Location Sheet

// MARK: - Globe UIViewRepresentable
// SwiftUI Map hard-caps zoom-out at ~8 000 km (continents only).
// MKMapView lets us raise maxCenterCoordinateDistance to show the full globe.

private struct GlobeMapView: UIViewRepresentable {
    let locations: [VisitedLocation]

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()

        // MKHybridMapConfiguration is required for globe/space rendering.
        // .standard tiles render flat even at extreme altitude.
        mapView.preferredConfiguration = MKHybridMapConfiguration(elevationStyle: .realistic)

        mapView.isScrollEnabled   = true
        mapView.isZoomEnabled     = true
        mapView.isRotateEnabled   = true
        mapView.isPitchEnabled    = false
        mapView.showsCompass      = true
        mapView.showsUserLocation = false

        // Remove the zoom-out ceiling entirely so the globe/space view is reachable
        mapView.cameraZoomRange = MKMapView.CameraZoomRange(
            minCenterCoordinateDistance: 500,
            maxCenterCoordinateDistance: CLLocationDistanceMax
        )

        let camera = MKMapCamera(
            lookingAtCenter: CLLocationCoordinate2D(latitude: 25, longitude: 10),
            fromDistance: 20_000_000,
            pitch: 0,
            heading: 0
        )
        mapView.setCamera(camera, animated: false)
        mapView.delegate = context.coordinator
        return mapView
    }

    func updateUIView(_ mapView: MKMapView, context: Context) {
        let existing    = mapView.annotations.compactMap { $0 as? VisitedLocationAnnotation }
        let existingIDs = Set(existing.map(\.locationID))
        let newIDs      = Set(locations.map(\.id))

        mapView.removeAnnotations(existing.filter { !newIDs.contains($0.locationID) })
        for loc in locations where !existingIDs.contains(loc.id) {
            mapView.addAnnotation(VisitedLocationAnnotation(location: loc))
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    class Coordinator: NSObject, MKMapViewDelegate {
        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            guard annotation is VisitedLocationAnnotation else { return nil }
            let id   = "GlobePin"
            let view = (mapView.dequeueReusableAnnotationView(withIdentifier: id) as? MKMarkerAnnotationView)
                ?? MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: id)
            view.annotation         = annotation
            view.markerTintColor    = UIColor(Color.atlasTeal)
            view.glyphImage         = nil
            view.titleVisibility    = .hidden
            view.subtitleVisibility = .hidden
            return view
        }
    }
}

private final class VisitedLocationAnnotation: NSObject, MKAnnotation {
    let locationID: UUID
    @objc dynamic var coordinate: CLLocationCoordinate2D
    var title: String?

    init(location: VisitedLocation) {
        self.locationID = location.id
        self.coordinate = location.coordinate
        self.title      = location.name
    }
}

// MARK: -

struct AddVisitedLocationSheet: View {
    let onAdd: (String, Double, Double, Date?) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var locationText  = ""
    @State private var dateVisited   = Date()
    @State private var includeDate   = true
    @State private var isSearching   = false
    @State private var errorMessage: String? = nil

    @FocusState private var locationFocused: Bool

    private var canSubmit: Bool {
        !locationText.trimmingCharacters(in: .whitespaces).isEmpty && !isSearching
    }

    var body: some View {
        VStack(spacing: 0) {

            // MARK: Teal Header
            ZStack {
                Color.atlasTeal
                HStack {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 32, height: 32)
                            .background(Color.white.opacity(0.2))
                            .clipShape(Circle())
                    }
                    Spacer()
                    Text("Add Location")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(.white)
                    Spacer()
                    Color.clear.frame(width: 32, height: 32)
                }
                .padding(.horizontal, 20)
            }
            .frame(height: 56)

            // MARK: Form
            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    Spacer().frame(height: 8)

                    // Location name field
                    VStack(spacing: 8) {
                        Text("Location Name")
                            .atlasLabel()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.leading, 4)

                        TextField(
                            "",
                            text: $locationText,
                            prompt: Text("e.g. Tokyo, Japan")
                                .foregroundStyle(Color.atlasBlack.opacity(0.35))
                        )
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(Color.atlasBlack)
                        .autocorrectionDisabled()
                        .focused($locationFocused)
                        .submitLabel(.search)
                        .onSubmit { addLocation() }
                        .padding(16)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .shadow(color: .black.opacity(0.04), radius: 4, x: 0, y: 2)
                    }

                    // Date visited (optional)
                    VStack(spacing: 8) {
                        HStack {
                            Text("Date Visited")
                                .atlasLabel()
                                .padding(.leading, 4)
                            Spacer()
                            Toggle("", isOn: $includeDate)
                                .tint(Color.atlasTeal)
                                .labelsHidden()
                        }

                        if includeDate {
                            DatePicker(
                                "",
                                selection: $dateVisited,
                                in: ...Date(),
                                displayedComponents: .date
                            )
                            .datePickerStyle(.compact)
                            .tint(Color.atlasTeal)
                            .labelsHidden()
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(Color.white)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .shadow(color: .black.opacity(0.04), radius: 4, x: 0, y: 2)
                        }
                    }

                    // Error feedback
                    if let err = errorMessage {
                        HStack(spacing: 6) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 12))
                                .foregroundStyle(.red.opacity(0.8))
                            Text(err)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(.red.opacity(0.8))
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.leading, 4)
                    }

                    // Submit button
                    Button { addLocation() } label: {
                        HStack(spacing: 10) {
                            if isSearching {
                                ProgressView().tint(.white)
                                Text("Finding…")
                                    .font(.system(size: 14, weight: .bold))
                            } else {
                                Text("ADD PIN")
                                    .font(.system(size: 14, weight: .bold))
                                    .kerning(1)
                                Image(systemName: "mappin.and.ellipse")
                                    .font(.system(size: 16, weight: .bold))
                            }
                        }
                        .foregroundStyle(canSubmit ? .white : Color.white.opacity(0.4))
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(canSubmit ? Color.atlasBlack : Color.atlasBlack.opacity(0.3))
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                    .buttonStyle(ScaleButtonStyle())
                    .disabled(!canSubmit)

                    Spacer().frame(height: 16)
                }
                .padding(.horizontal, 20)
            }
        }
        .background(Color.atlasBeige.ignoresSafeArea())
        .presentationDetents([.medium])
    }

    private func addLocation() {
        locationFocused = false
        let query = locationText.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return }

        isSearching   = true
        errorMessage  = nil

        CLGeocoder().geocodeAddressString(query) { placemarks, _ in
            DispatchQueue.main.async {
                isSearching = false
                if let pm = placemarks?.first, let coord = pm.location?.coordinate {
                    // Build a friendly display name from the placemark
                    let parts = [pm.locality, pm.administrativeArea, pm.country]
                        .compactMap { $0 }
                    let displayName = parts.isEmpty ? query : parts.prefix(2).joined(separator: ", ")
                    let date = includeDate ? dateVisited : nil
                    onAdd(displayName, coord.latitude, coord.longitude, date)
                    dismiss()
                } else {
                    errorMessage = "Location not found. Try a more specific name."
                }
            }
        }
    }
}

#Preview {
    ProfileView()
        .environment(UserProfile.shared)
        .modelContainer(for: [Trip.self, TripItem.self, CrewMember.self, Expense.self, WishlistDestination.self, VisitedLocation.self], inMemory: true)
}
