//
//  MapTabView.swift
//  Atlas
//
//  Full-screen visited-locations globe. Pro-gated.
//

import SwiftUI
import SwiftData
import MapKit
import CoreLocation

// MARK: - Map Tab View

struct MapTabView: View {
    @Environment(SubscriptionManager.self) private var subscriptionManager
    @Environment(\.modelContext) private var modelContext

    @State private var showAddLocationSheet = false
    @State private var showPaywall = false
    @State private var isSyncing = false
    @State private var editingLocation: VisitedLocation? = nil

    @Query private var visitedLocations: [VisitedLocation]

    @Query(
        filter: #Predicate<Trip> { $0.statusRaw == "completed" },
        sort: \Trip.endDate,
        order: .reverse
    ) private var completedTrips: [Trip]

    var body: some View {
        Group {
            if subscriptionManager.isPro {
                proMapContent
            } else {
                lockedMapContent
            }
        }
        .sheet(isPresented: $showAddLocationSheet) {
            AddVisitedLocationSheet { name, lat, lon, date, country, continent in
                let loc = VisitedLocation(
                    name: name,
                    latitude: lat,
                    longitude: lon,
                    dateVisited: date,
                    source: "manual",
                    country: country,
                    continent: continent
                )
                modelContext.insert(loc)
                Haptics.success()
            }
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView()
                .environment(subscriptionManager)
                .presentationDetents([.large])
                .presentationDragIndicator(.hidden)
        }
        .sheet(item: $editingLocation) { loc in
            EditVisitedLocationSheet(location: loc) {
                modelContext.delete(loc)
                Haptics.medium()
            }
        }
    }

    // MARK: - Pro Map Content

    private var proMapContent: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {

                // MARK: Teal Header
                // The extra black background bridging fills the 40-pt corner-radius
                // cutouts that would otherwise reveal the beige scroll background.
                mapHeader
                    .tealHeader()
                    .background(alignment: .bottom) {
                        Color.atlasBlack.frame(height: 42)
                    }

                // MARK: Globe (black background section)
                ZStack(alignment: .center) {
                    Color.atlasBlack

                    GlobeMapView(locations: visitedLocations)
                        .frame(height: 380)

                    if visitedLocations.isEmpty {
                        VStack(spacing: 10) {
                            Image(systemName: "mappin.slash")
                                .font(.system(size: 24, weight: .light))
                                .foregroundStyle(.white.opacity(0.6))
                            Text("Sync completed trips or tap + to add your first pin")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(.white.opacity(0.6))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 40)
                        }
                        .padding(.vertical, 20)
                        .background(Color.black.opacity(0.45).clipShape(RoundedRectangle(cornerRadius: 14)))
                    }
                }
                .frame(height: 380)

                // MARK: Legend
                // frame(maxHeight: .infinity) ensures the beige background
                // fills all remaining space even when the list is short.
                VStack(alignment: .leading, spacing: 20) {
                    if !visitedLocations.isEmpty {
                        legendSection
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 24)
                .padding(.bottom, 100)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .background(Color.atlasBeige)
            }
        }
        .background(Color.atlasBeige.ignoresSafeArea())
        .ignoresSafeArea(edges: .top)
    }

    // MARK: - Header

    private var mapHeader: some View {
        VStack(spacing: 0) {
            Spacer().frame(height: 60)

            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Travel Map")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundStyle(.white)
                    Text(visitedLocations.isEmpty
                         ? "Start pinning your world."
                         : "\(visitedLocations.count) location\(visitedLocations.count == 1 ? "" : "s") pinned")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.white.opacity(0.65))
                }

                Spacer()

                HStack(spacing: 10) {
                    // Sync completed trips
                    if !completedTrips.isEmpty {
                        Button {
                            syncTripsToGlobe()
                        } label: {
                            HStack(spacing: 4) {
                                if isSyncing {
                                    ProgressView()
                                        .scaleEffect(0.75)
                                        .tint(.white)
                                } else {
                                    Image(systemName: "arrow.clockwise")
                                        .font(.system(size: 12, weight: .semibold))
                                }
                                Text(isSyncing ? "Syncing…" : "Sync Trips")
                                    .font(.system(size: 12, weight: .semibold))
                            }
                            .foregroundStyle(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color.white.opacity(0.2))
                            .clipShape(Capsule())
                        }
                        .disabled(isSyncing)
                    }

                    // Add manual pin
                    Button {
                        showAddLocationSheet = true
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 34, height: 34)
                            .background(Color.white.opacity(0.2))
                            .clipShape(Circle())
                    }
                }
            }
            .padding(.bottom, 24)
        }
        .padding(.horizontal, 20)
    }

    // MARK: - Legend

    private var legendSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Where I've Been")
                .atlasLabel()
                .padding(.leading, 4)

            // Group: continent → country → [city]
            let grouped = groupedLocations()
            ForEach(grouped, id: \.continent) { continentGroup in
                VStack(alignment: .leading, spacing: 10) {
                    // Continent header
                    HStack(spacing: 8) {
                        Text(continentGroup.continent)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 5)
                            .background(Color.atlasBlack)
                            .clipShape(Capsule())

                        Text("\(continentGroup.totalCount) location\(continentGroup.totalCount == 1 ? "" : "s")")
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                            .foregroundStyle(Color.atlasBlack.opacity(0.4))
                    }

                    // Countries inside continent
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(continentGroup.countries, id: \.country) { countryGroup in
                            HStack(alignment: .top, spacing: 0) {
                                // Vertical connector line
                                VStack(spacing: 0) {
                                    Rectangle()
                                        .fill(Color.atlasTeal.opacity(0.35))
                                        .frame(width: 2)
                                }
                                .frame(width: 2)
                                .padding(.leading, 12)

                                VStack(alignment: .leading, spacing: 4) {
                                    // Country row
                                    HStack(spacing: 6) {
                                        Circle()
                                            .fill(Color.atlasTeal)
                                            .frame(width: 8, height: 8)
                                            .padding(.leading, -5)

                                        Text(countryGroup.country)
                                            .font(.system(size: 13, weight: .semibold))
                                            .foregroundStyle(Color.atlasBlack)

                                        Text("(\(countryGroup.locations.count))")
                                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                                            .foregroundStyle(Color.atlasBlack.opacity(0.4))
                                    }

                                    // Individual tappable location rows
                                    VStack(alignment: .leading, spacing: 2) {
                                        ForEach(countryGroup.locations, id: \.id) { loc in
                                            Button {
                                                editingLocation = loc
                                            } label: {
                                                HStack(spacing: 6) {
                                                    Text(loc.name)
                                                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                                                        .foregroundStyle(Color.atlasBlack.opacity(0.55))
                                                    Spacer()
                                                    Image(systemName: "pencil")
                                                        .font(.system(size: 10, weight: .medium))
                                                        .foregroundStyle(Color.atlasTeal.opacity(0.6))
                                                }
                                                .padding(.vertical, 4)
                                                .padding(.horizontal, 8)
                                                .background(Color.atlasBlack.opacity(0.03))
                                                .clipShape(RoundedRectangle(cornerRadius: 6))
                                            }
                                            .buttonStyle(.plain)
                                        }
                                    }
                                    .padding(.leading, 8)
                                }
                                .padding(.leading, 12)
                                .padding(.vertical, 6)
                            }
                        }
                    }
                }
                .padding(16)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .shadow(color: .black.opacity(0.04), radius: 4, x: 0, y: 2)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.black.opacity(0.05), lineWidth: 1)
                )
            }
        }
    }

    // MARK: - Legend Data

    private struct ContinentGroup {
        let continent: String
        let countries: [CountryGroup]
        var totalCount: Int { countries.reduce(0) { $0 + $1.locations.count } }
    }

    private struct CountryGroup {
        let country: String
        let locations: [VisitedLocation]
    }

    private func groupedLocations() -> [ContinentGroup] {
        var continentMap: [String: [String: [VisitedLocation]]] = [:]

        for loc in visitedLocations {
            let cont    = loc.continent.isEmpty ? "Other" : loc.continent
            let country = loc.country.isEmpty   ? "Unknown" : loc.country
            continentMap[cont, default: [:]][country, default: []].append(loc)
        }

        let continentOrder = ["Europe", "Asia", "Americas", "Africa", "Oceania", "Other"]

        return continentOrder.compactMap { cont -> ContinentGroup? in
            guard let countries = continentMap[cont] else { return nil }
            let countryGroups = countries
                .sorted { $0.key < $1.key }
                .map { CountryGroup(country: $0.key, locations: $0.value.sorted { $0.name < $1.name }) }
            return ContinentGroup(continent: cont, countries: countryGroups)
        }
    }

    // MARK: - Locked (Non-Pro) Content

    private var lockedMapContent: some View {
        ZStack {
            GlobeMapView(locations: [])
                .allowsHitTesting(false)
                .blur(radius: 14)
                .overlay(Color.atlasBlack.opacity(0.55))
                .ignoresSafeArea()

            ProLockOverlay(label: "Travel Map is a Pro feature") {
                showPaywall = true
            }
        }
    }

    // MARK: - Sync Completed Trips → Globe

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
                let query = [trip.destination.capitalized, trip.country]
                    .filter { !$0.isEmpty }
                    .joined(separator: ", ")

                if let (coord, placemark) = await geocodeWithPlacemark(query) {
                    let country   = placemark.country ?? ""
                    let isoCode   = placemark.isoCountryCode ?? ""
                    let continent = continentFor(isoCode: isoCode)
                    await MainActor.run {
                        let loc = VisitedLocation(
                            name: trip.destination.capitalized,
                            latitude: coord.latitude,
                            longitude: coord.longitude,
                            dateVisited: trip.endDate,
                            source: "trip",
                            country: country,
                            continent: continent
                        )
                        modelContext.insert(loc)
                    }
                }
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

    private func geocodeWithPlacemark(_ address: String) async -> (CLLocationCoordinate2D, CLPlacemark)? {
        await withCheckedContinuation { continuation in
            CLGeocoder().geocodeAddressString(address) { placemarks, _ in
                if let pm = placemarks?.first, let coord = pm.location?.coordinate {
                    continuation.resume(returning: (coord, pm))
                } else {
                    continuation.resume(returning: nil)
                }
            }
        }
    }
}

// MARK: - Globe UIViewRepresentable

struct GlobeMapView: UIViewRepresentable {
    let locations: [VisitedLocation]

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.preferredConfiguration = MKHybridMapConfiguration(elevationStyle: .realistic)
        mapView.isScrollEnabled   = true
        mapView.isZoomEnabled     = true
        mapView.isRotateEnabled   = true
        mapView.isPitchEnabled    = false
        mapView.showsCompass      = false
        mapView.showsUserLocation = false
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

// MARK: - Visited Location Annotation

final class VisitedLocationAnnotation: NSObject, MKAnnotation {
    let locationID: UUID
    @objc dynamic var coordinate: CLLocationCoordinate2D
    var title: String?

    init(location: VisitedLocation) {
        self.locationID = location.id
        self.coordinate = location.coordinate
        self.title      = location.name
    }
}

// MARK: - Add Visited Location Sheet

struct AddVisitedLocationSheet: View {
    /// name, lat, lon, date, country, continent
    let onAdd: (String, Double, Double, Date?, String, String) -> Void

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

            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    Spacer().frame(height: 8)

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
                            HStack {
                                DatePicker(
                                    "",
                                    selection: $dateVisited,
                                    in: ...Date(),
                                    displayedComponents: .date
                                )
                                .datePickerStyle(.compact)
                                .tint(Color.atlasTeal)
                                .labelsHidden()
                                // Force light-mode so the compact button text is always
                                // dark on this white card regardless of system appearance.
                                .environment(\.colorScheme, .light)
                                Spacer()
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(Color.white)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .shadow(color: .black.opacity(0.04), radius: 4, x: 0, y: 2)
                        }
                    }

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

        isSearching  = true
        errorMessage = nil

        CLGeocoder().geocodeAddressString(query) { placemarks, _ in
            DispatchQueue.main.async {
                isSearching = false
                if let pm = placemarks?.first, let coord = pm.location?.coordinate {
                    let parts = [pm.locality, pm.administrativeArea, pm.country]
                        .compactMap { $0 }
                    let displayName = parts.isEmpty ? query : parts.prefix(2).joined(separator: ", ")
                    let country     = pm.country ?? ""
                    let isoCode     = pm.isoCountryCode ?? ""
                    let continent   = continentFor(isoCode: isoCode)
                    let date        = includeDate ? dateVisited : nil
                    onAdd(displayName, coord.latitude, coord.longitude, date, country, continent)
                    dismiss()
                } else {
                    errorMessage = "Location not found. Try a more specific name."
                }
            }
        }
    }
}

// MARK: - Edit Visited Location Sheet

struct EditVisitedLocationSheet: View {
    let location: VisitedLocation
    let onDelete: () -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var nameText: String
    @State private var dateVisited: Date
    @State private var includeDate: Bool
    @State private var showDeleteConfirm = false

    @FocusState private var nameFocused: Bool

    init(location: VisitedLocation, onDelete: @escaping () -> Void) {
        self.location = location
        self.onDelete = onDelete
        _nameText    = State(initialValue: location.name)
        _dateVisited = State(initialValue: location.dateVisited ?? Date())
        _includeDate = State(initialValue: location.dateVisited != nil)
    }

    private var hasChanges: Bool {
        let nameTrimmed = nameText.trimmingCharacters(in: .whitespaces)
        let nameDiffers = nameTrimmed != location.name && !nameTrimmed.isEmpty
        let dateDiffers = includeDate
            ? location.dateVisited.map { !Calendar.current.isDate($0, inSameDayAs: dateVisited) } ?? true
            : location.dateVisited != nil
        return nameDiffers || dateDiffers
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
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
                    Text("Edit Location")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(.white)
                    Spacer()
                    Color.clear.frame(width: 32, height: 32)
                }
                .padding(.horizontal, 20)
            }
            .frame(height: 56)

            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    Spacer().frame(height: 8)

                    // Name field
                    VStack(spacing: 8) {
                        Text("Location Name")
                            .atlasLabel()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.leading, 4)

                        TextField(
                            "",
                            text: $nameText,
                            prompt: Text("e.g. Tokyo, Japan")
                                .foregroundStyle(Color.atlasBlack.opacity(0.35))
                        )
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(Color.atlasBlack)
                        .autocorrectionDisabled()
                        .focused($nameFocused)
                        .submitLabel(.done)
                        .onSubmit { nameFocused = false }
                        .padding(16)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .shadow(color: .black.opacity(0.04), radius: 4, x: 0, y: 2)
                    }

                    // Date visited
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
                            HStack {
                                DatePicker(
                                    "",
                                    selection: $dateVisited,
                                    in: ...Date(),
                                    displayedComponents: .date
                                )
                                .datePickerStyle(.compact)
                                .tint(Color.atlasTeal)
                                .labelsHidden()
                                .environment(\.colorScheme, .light)
                                Spacer()
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(Color.white)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .shadow(color: .black.opacity(0.04), radius: 4, x: 0, y: 2)
                        }
                    }

                    // Save button
                    Button { save() } label: {
                        Text("SAVE CHANGES")
                            .font(.system(size: 14, weight: .bold))
                            .kerning(1)
                            .foregroundStyle(hasChanges ? .white : Color.white.opacity(0.4))
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .background(hasChanges ? Color.atlasBlack : Color.atlasBlack.opacity(0.3))
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .buttonStyle(ScaleButtonStyle())
                    .disabled(!hasChanges)

                    // Remove pin button
                    Button {
                        showDeleteConfirm = true
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "mappin.slash")
                                .font(.system(size: 13, weight: .semibold))
                            Text("Remove Pin")
                                .font(.system(size: 14, weight: .semibold))
                        }
                        .foregroundStyle(Color.red.opacity(0.7))
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(Color.red.opacity(0.06))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(Color.red.opacity(0.15), lineWidth: 1)
                        )
                    }
                    .buttonStyle(ScaleButtonStyle())
                    .confirmationDialog(
                        "Remove \"\(location.name)\" from your map?",
                        isPresented: $showDeleteConfirm,
                        titleVisibility: .visible
                    ) {
                        Button("Remove Pin", role: .destructive) {
                            onDelete()
                            dismiss()
                        }
                        Button("Cancel", role: .cancel) {}
                    }

                    Spacer().frame(height: 16)
                }
                .padding(.horizontal, 20)
            }
        }
        .background(Color.atlasBeige.ignoresSafeArea())
        .presentationDetents([.medium])
        .onTapGesture { nameFocused = false }
    }

    private func save() {
        let trimmed = nameText.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        location.name        = trimmed
        location.dateVisited = includeDate ? dateVisited : nil
        Haptics.success()
        dismiss()
    }
}
