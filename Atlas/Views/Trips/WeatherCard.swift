//
//  WeatherCard.swift
//  Atlas
//
//  Horizontal day-tile scroll showing the weather forecast for a trip's dates.
//  Pro feature — shows locked state for free users.
//

import SwiftUI
import CoreLocation

// MARK: - Weather Card

struct WeatherCard: View {
    let trip: Trip
    @Environment(SubscriptionManager.self) private var subscriptionManager

    @State private var forecast: [WeatherDay] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var showPaywall = false
    @State private var useFahrenheit = false

    // Only show weather for non-completed trips within reasonable range
    private var shouldShowWeather: Bool {
        trip.statusRaw != "completed" &&
        trip.endDate >= Date().addingTimeInterval(-86400 * 3)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            headerRow

            if subscriptionManager.isPro {
                proContent
            } else {
                lockedContent
            }
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView()
                .environment(subscriptionManager)
                .presentationDetents([.large])
                .presentationDragIndicator(.hidden)
        }
    }

    // MARK: - Header

    private var headerRow: some View {
        HStack {
            Text("WEATHER")
                .atlasLabel()
            Spacer()
            if subscriptionManager.isPro && !forecast.isEmpty {
                Toggle(isOn: $useFahrenheit) {
                    Text("°F")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Color.atlasBlack.opacity(0.5))
                }
                .toggleStyle(.button)
                .tint(Color.atlasTeal)
                .controlSize(.mini)
            }
            if !subscriptionManager.isPro {
                ProBadge()
            }
        }
    }

    // MARK: - Pro Content

    @ViewBuilder
    private var proContent: some View {
        if !shouldShowWeather {
            pastTripNote
        } else if isLoading {
            loadingTiles
        } else if let err = errorMessage {
            errorView(err)
        } else if forecast.isEmpty {
            noDataView
        } else {
            forecastScroll
        }
    }

    private var forecastScroll: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(forecast) { day in
                    WeatherDayTile(day: day, useFahrenheit: useFahrenheit)
                }
            }
            .padding(.horizontal, 2)
            .padding(.vertical, 2)
        }
        .task { await loadForecast() }
    }

    private var loadingTiles: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(0..<5, id: \.self) { _ in
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color.atlasBlack.opacity(0.06))
                        .frame(width: 70, height: 100)
                        .shimmer()
                }
            }
            .padding(.horizontal, 2)
            .padding(.vertical, 2)
        }
        .task { await loadForecast() }
    }

    private func errorView(_ msg: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "wifi.exclamationmark")
                .font(.system(size: 18))
                .foregroundStyle(Color.atlasBlack.opacity(0.25))
            Text("Weather unavailable")
                .font(.system(size: 13))
                .foregroundStyle(Color.atlasBlack.opacity(0.4))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 8)
    }

    private var noDataView: some View {
        Text("No forecast data available for these dates.")
            .font(.system(size: 12))
            .foregroundStyle(Color.atlasBlack.opacity(0.4))
    }

    private var pastTripNote: some View {
        Text("Weather forecast available for upcoming trips.")
            .font(.system(size: 12))
            .foregroundStyle(Color.atlasBlack.opacity(0.4))
    }

    // MARK: - Locked Content

    private var lockedContent: some View {
        Button { showPaywall = true } label: {
            HStack(spacing: 12) {
                Image(systemName: "cloud.sun.fill")
                    .font(.system(size: 28, weight: .light))
                    .foregroundStyle(Color.atlasBlack.opacity(0.2))

                VStack(alignment: .leading, spacing: 3) {
                    Text("10-day forecast for your trip")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.atlasBlack.opacity(0.5))
                    Text("Upgrade to Atlas Pro to unlock")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.atlasTeal.opacity(0.8))
                }

                Spacer()

                Image(systemName: "lock.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.atlasBlack.opacity(0.2))
            }
            .padding(16)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .shadow(color: .black.opacity(0.04), radius: 4, x: 0, y: 2)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Fetch

    private func loadForecast() async {
        guard shouldShowWeather, isLoading else { return }

        let query = [trip.destination.capitalized, trip.country].filter { !$0.isEmpty }.joined(separator: ", ")

        do {
            let coord = try await geocode(query)
            let days  = try await WeatherService.shared.fetchForecast(
                lat:       coord.latitude,
                lon:       coord.longitude,
                startDate: trip.startDate,
                endDate:   trip.endDate
            )
            await MainActor.run {
                forecast  = days
                isLoading = false
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                isLoading    = false
            }
        }
    }

    private func geocode(_ address: String) async throws -> CLLocationCoordinate2D {
        try await withCheckedThrowingContinuation { cont in
            CLGeocoder().geocodeAddressString(address) { marks, err in
                if let coord = marks?.first?.location?.coordinate {
                    cont.resume(returning: coord)
                } else {
                    cont.resume(throwing: err ?? URLError(.badURL))
                }
            }
        }
    }
}

// MARK: - Day Tile

private struct WeatherDayTile: View {
    let day: WeatherDay
    let useFahrenheit: Bool

    private var dayLabel: String {
        let f = DateFormatter()
        f.dateFormat = "EEE"
        return f.string(from: day.date)
    }

    private var dateLabel: String {
        let f = DateFormatter()
        f.dateFormat = "d MMM"
        return f.string(from: day.date)
    }

    var body: some View {
        VStack(spacing: 8) {
            Text(dayLabel.uppercased())
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundStyle(Color.atlasBlack.opacity(0.4))
                .kerning(0.5)

            Image(systemName: day.symbolName)
                .font(.system(size: 22, weight: .light))
                .foregroundStyle(symbolColor(for: day.weatherCode))
                .frame(height: 28)

            VStack(spacing: 2) {
                Text("\(Int(day.maxTemp(fahrenheit: useFahrenheit)))°")
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundStyle(Color.atlasBlack)
                Text("\(Int(day.minTemp(fahrenheit: useFahrenheit)))°")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(Color.atlasBlack.opacity(0.4))
            }
        }
        .frame(width: 66)
        .padding(.vertical, 12)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
    }

    private func symbolColor(for code: Int) -> Color {
        switch code {
        case 0, 1:      return .orange
        case 2:         return .yellow
        case 3:         return Color.atlasBlack.opacity(0.4)
        case 61...82:   return Color.blue.opacity(0.7)
        case 71...77:   return Color.cyan.opacity(0.7)
        case 85, 86:    return Color.cyan.opacity(0.6)
        case 95...99:   return Color.purple.opacity(0.7)
        default:        return Color.atlasBlack.opacity(0.3)
        }
    }
}

// MARK: - Shimmer Modifier

private extension View {
    func shimmer() -> some View {
        self.opacity(0.5)
    }
}
