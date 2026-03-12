//
//  TripMapView.swift
//  Atlas
//

import SwiftUI
import MapKit

// MARK: - Mapped Item

private struct MappedItem: Identifiable {
    let id: UUID
    let coordinate: CLLocationCoordinate2D
    let item: TripItem
    let mapItem: MKMapItem          // stored so openInMaps() needs no re-geocode
}

// MARK: - Trip Map View

struct TripMapView: View {
    let trip: Trip

    @State private var mappedItems: [MappedItem] = []
    @State private var isGeocoding = false
    @State private var selectedItemID: UUID? = nil
    @State private var cameraPosition: MapCameraPosition = .automatic

    private var selectedItem: TripItem? {
        guard let id = selectedItemID else { return nil }
        return mappedItems.first(where: { $0.id == id })?.item
    }

    private var unmappedItems: [TripItem] {
        let mappedIDs = Set(mappedItems.map { $0.item.id })
        return trip.items.filter { $0.locationAddress.isEmpty && !mappedIDs.contains($0.id) }
    }

    // MARK: Body

    var body: some View {
        VStack(spacing: 16) {
            if isGeocoding && mappedItems.isEmpty {
                geocodingLoadingState
            } else if mappedItems.isEmpty && !isGeocoding {
                mapEmptyState
            } else {
                mapContent
            }
        }
        .task { await geocodeAllItems() }
    }

    // MARK: - Map Content

    @ViewBuilder
    private var mapContent: some View {
        Map(position: $cameraPosition) {
            ForEach(mappedItems) { mapped in
                Annotation(
                    mapped.item.title,
                    coordinate: mapped.coordinate,
                    anchor: .bottom
                ) {
                    pinView(item: mapped.item, isSelected: selectedItemID == mapped.id)
                        .onTapGesture {
                            withAnimation(.spring(response: 0.3)) {
                                selectedItemID = selectedItemID == mapped.id ? nil : mapped.id
                            }
                            Haptics.light()
                        }
                }
            }
        }
        .mapStyle(.standard(elevation: .flat, pointsOfInterest: .including([
            .restaurant, .hotel, .museum, .airport
        ])))
        .frame(height: 340)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
        .overlay(alignment: .topTrailing) {
            recenterButton.padding(12)
        }

        if let item = selectedItem {
            selectedItemCard(item)
                .transition(.asymmetric(
                    insertion: .move(edge: .bottom).combined(with: .opacity),
                    removal: .opacity
                ))
        }

        if !unmappedItems.isEmpty {
            noLocationSection
        }

        Spacer().frame(height: 60)
    }

    // MARK: - Pin View

    private func pinView(item: TripItem, isSelected: Bool) -> some View {
        ZStack {
            Circle()
                .fill(Color.black.opacity(0.15))
                .frame(width: isSelected ? 46 : 36, height: isSelected ? 46 : 36)
                .offset(y: isSelected ? 3 : 2)

            ZStack {
                Circle()
                    .fill(item.category.accentColor)
                    .frame(width: isSelected ? 42 : 32, height: isSelected ? 42 : 32)
                Image(systemName: item.category.icon)
                    .font(.system(size: isSelected ? 16 : 13, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .overlay(Circle().stroke(Color.white, lineWidth: isSelected ? 3 : 2))
        }
        .animation(.spring(response: 0.3), value: isSelected)
    }

    // MARK: - Recenter Button

    private var recenterButton: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.5)) { cameraPosition = .automatic }
        } label: {
            Image(systemName: "location.circle.fill")
                .font(.system(size: 22))
                .foregroundStyle(Color.atlasTeal)
                .frame(width: 40, height: 40)
                .background(.ultraThinMaterial)
                .clipShape(Circle())
                .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
        }
    }

    // MARK: - Selected Item Card

    private func selectedItemCard(_ item: TripItem) -> some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(item.category.accentColor.opacity(0.15))
                    .frame(width: 44, height: 44)
                Image(systemName: item.category.icon)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(item.category.accentColor)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(item.title)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Color.atlasBlack)
                    .lineLimit(1)
                HStack(spacing: 6) {
                    Text(item.category.label)
                        .font(.system(size: 11))
                        .foregroundStyle(item.category.accentColor)
                    if !item.locationAddress.isEmpty {
                        Text("·")
                            .foregroundStyle(Color.atlasBlack.opacity(0.3))
                        Text(item.locationAddress)
                            .font(.system(size: 11))
                            .foregroundStyle(Color.atlasBlack.opacity(0.45))
                            .lineLimit(1)
                    }
                }
            }

            Spacer()

            Button { openInMaps(item: item) } label: {
                Image(systemName: "map.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.atlasTeal)
                    .frame(width: 36, height: 36)
                    .background(Color.atlasTeal.opacity(0.1))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(14)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 4)
    }

    // MARK: - No Location Section

    private var noLocationSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("NO LOCATION SET")
                .atlasLabel()

            VStack(spacing: 0) {
                ForEach(unmappedItems) { item in
                    HStack(spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(item.category.accentColor.opacity(0.12))
                                .frame(width: 32, height: 32)
                            Image(systemName: item.category.icon)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(item.category.accentColor)
                        }
                        Text(item.title)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(Color.atlasBlack)
                            .lineLimit(1)
                        Spacer()
                        Text(item.category.label)
                            .font(.system(size: 11))
                            .foregroundStyle(Color.atlasBlack.opacity(0.35))
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)

                    if item.id != unmappedItems.last?.id {
                        Divider().padding(.leading, 58)
                    }
                }
            }
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .shadow(color: .black.opacity(0.04), radius: 4, x: 0, y: 2)
        }
    }

    // MARK: - Empty / Loading States

    private var mapEmptyState: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color.atlasTeal.opacity(0.08))
                    .frame(width: 80, height: 80)
                Image(systemName: "map")
                    .font(.system(size: 34, weight: .ultraLight))
                    .foregroundStyle(Color.atlasTeal.opacity(0.45))
            }
            VStack(spacing: 6) {
                Text("No locations yet")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.atlasBlack)
                Text("Add addresses to your items to see\nthem plotted on the map.")
                    .font(.system(size: 13))
                    .foregroundStyle(Color.atlasBlack.opacity(0.4))
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    private var geocodingLoadingState: some View {
        VStack(spacing: 14) {
            ProgressView()
                .tint(Color.atlasTeal)
                .scaleEffect(1.2)
            Text("Mapping locations...")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Color.atlasBlack.opacity(0.5))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }

    // MARK: - Geocoding

    private func geocodeAllItems() async {
        let itemsWithAddress = trip.items.filter { !$0.locationAddress.isEmpty }
        guard !itemsWithAddress.isEmpty else { return }

        isGeocoding = true
        var results: [MappedItem] = []

        for item in itemsWithAddress {
            try? await Task.sleep(nanoseconds: 250_000_000) // 250ms — respect rate limits

            do {
                let (coord, mkItem) = try await geocode(address: item.locationAddress, name: item.title)
                results.append(MappedItem(id: item.id, coordinate: coord, item: item, mapItem: mkItem))
            } catch {
                continue // skip items that fail to geocode
            }
        }

        await MainActor.run {
            withAnimation { mappedItems = results }
            isGeocoding = false
            if !results.isEmpty {
                cameraPosition = .region(regionFitting(results.map { $0.coordinate }))
            }
        }
    }

    /// Returns a coordinate + ready-to-use MKMapItem for the given address string.
    private func geocode(address: String, name: String) async throws -> (CLLocationCoordinate2D, MKMapItem) {
        let geocoder = CLGeocoder()
        let placemarks = try await geocoder.geocodeAddressString(address)
        guard let location = placemarks.first?.location else {
            throw CocoaError(.coderInvalidValue)
        }
        let placemark = MKPlacemark(coordinate: location.coordinate)
        let mkItem = MKMapItem(placemark: placemark)
        mkItem.name = name
        return (location.coordinate, mkItem)
    }

    // MARK: - Region Fitting

    private func regionFitting(_ coords: [CLLocationCoordinate2D]) -> MKCoordinateRegion {
        guard !coords.isEmpty else {
            return MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 35, longitude: 105),
                span: MKCoordinateSpan(latitudeDelta: 60, longitudeDelta: 60)
            )
        }
        let minLat = coords.map(\.latitude).min()!
        let maxLat = coords.map(\.latitude).max()!
        let minLon = coords.map(\.longitude).min()!
        let maxLon = coords.map(\.longitude).max()!
        return MKCoordinateRegion(
            center: CLLocationCoordinate2D(
                latitude:  (minLat + maxLat) / 2,
                longitude: (minLon + maxLon) / 2
            ),
            span: MKCoordinateSpan(
                latitudeDelta:  max((maxLat - minLat) * 1.5, 0.02),
                longitudeDelta: max((maxLon - minLon) * 1.5, 0.02)
            )
        )
    }

    // MARK: - Open in Maps

    private func openInMaps(item: TripItem) {
        guard let mapped = mappedItems.first(where: { $0.item.id == item.id }) else { return }
        mapped.mapItem.openInMaps()
    }
}
