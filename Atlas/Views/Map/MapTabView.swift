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

    @Query private var visitedLocations: [VisitedLocation]

    @Query(
        filter: #Predicate<Trip> { $0.statusRaw == "completed" },
        sort: \Trip.endDate,
        order: .reverse
    ) private var completedTrips: [Trip]

    var body: some View {
        ZStack {
            Color.atlasBeige.ignoresSafeArea()

            if subscriptionManager.isPro {
                proMapContent
            } else {
                lockedMapContent
            }
        }
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
        .sheet(isPresented: $showPaywall) {
            PaywallView()
                .environment(subscriptionManager)
                .presentationDetents([.large])
                .presentationDragIndicator(.hidden)
        }
    }

    // MARK: - Pro Map Content

    private var proMapContent: some View {
        VStack(spacing: 0) {
            // Navigation-bar area
            ZStack {
                Color.atlasBlack.ignoresSafeArea(edges: .top)
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("TRAVEL MAP")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.45))
                            .kerning(2)
                        Text("\(visitedLocations.count) location\(visitedLocations.count == 1 ? "" : "s") pinned")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.white)
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
                                        ProgressView().scaleEffect(0.75).tint(Color.atlasTeal)
                                    } else {
                                        Image(systemName: "arrow.clockwise")
                                            .font(.system(size: 12, weight: .semibold))
                                    }
                                    Text(isSyncing ? "Syncing" : "Sync Trips")
                                        .font(.system(size: 12, weight: .semibold))
                                }
                                .foregroundStyle(Color.atlasTeal)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(Color.atlasTeal.opacity(0.12))
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
                                .background(Color.white.opacity(0.15))
                                .clipShape(Circle())
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
            }
            .frame(height: 90)

            // Full-height globe
            GlobeMapView(locations: visitedLocations)
                .ignoresSafeArea(edges: .bottom)

            // Empty state overlay (shown on top of map)
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
                .padding(.bottom, 120)
            }
        }
    }

    // MARK: - Locked (Non-Pro) Content

    private var lockedMapContent: some View {
        VStack(spacing: 0) {
            // Blurred globe preview
            ZStack {
                // Static globe tint as backdrop (actual map blurred)
                GlobeMapView(locations: [])
                    .allowsHitTesting(false)
                    .blur(radius: 14)
                    .overlay(Color.atlasBlack.opacity(0.55))

                ProLockOverlay(label: "Travel Map is a Pro feature") {
                    showPaywall = true
                }
            }
            .ignoresSafeArea(edges: .bottom)
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
}

// MARK: - Globe UIViewRepresentable
// SwiftUI Map hard-caps zoom-out at ~8 000 km (continents only).
// MKMapView lets us raise maxCenterCoordinateDistance to show the full globe.

struct GlobeMapView: UIViewRepresentable {
    let locations: [VisitedLocation]

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()

        // MKHybridMapConfiguration is required for globe/space rendering.
        mapView.preferredConfiguration = MKHybridMapConfiguration(elevationStyle: .realistic)

        mapView.isScrollEnabled   = true
        mapView.isZoomEnabled     = true
        mapView.isRotateEnabled   = true
        mapView.isPitchEnabled    = false
        mapView.showsCompass      = true
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
                    let parts = [pm.locality, pm.administrativeArea, pm.country].compactMap { $0 }
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
