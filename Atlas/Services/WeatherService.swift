//
//  WeatherService.swift
//  Atlas
//
//  Fetches trip weather forecasts from Open-Meteo (free, no API key required).
//  API docs: https://open-meteo.com/en/docs
//

import Foundation
import CoreLocation

// MARK: - Weather Day

struct WeatherDay: Identifiable {
    let id = UUID()
    let date: Date
    let maxTempC: Double
    let minTempC: Double
    let weatherCode: Int

    // WMO Weather Interpretation Code → SF Symbol name
    var symbolName: String {
        switch weatherCode {
        case 0:            return "sun.max.fill"
        case 1:            return "sun.max.fill"
        case 2:            return "cloud.sun.fill"
        case 3:            return "cloud.fill"
        case 45, 48:       return "cloud.fog.fill"
        case 51, 53, 55:   return "cloud.drizzle.fill"
        case 61, 63, 65:   return "cloud.rain.fill"
        case 71, 73, 75:   return "cloud.snow.fill"
        case 77:           return "cloud.snow.fill"
        case 80, 81, 82:   return "cloud.heavyrain.fill"
        case 85, 86:       return "cloud.snow.fill"
        case 95:           return "cloud.bolt.fill"
        case 96, 99:       return "cloud.bolt.rain.fill"
        default:           return "cloud.fill"
        }
    }

    // Brief description
    var description: String {
        switch weatherCode {
        case 0, 1:         return "Sunny"
        case 2:            return "Partly Cloudy"
        case 3:            return "Overcast"
        case 45, 48:       return "Foggy"
        case 51...55:      return "Drizzle"
        case 61...65:      return "Rain"
        case 71...77:      return "Snow"
        case 80...82:      return "Showers"
        case 85, 86:       return "Snow Showers"
        case 95:           return "Thunderstorm"
        case 96, 99:       return "Hail Storm"
        default:           return "Unknown"
        }
    }

    func maxTemp(fahrenheit: Bool) -> Double {
        fahrenheit ? (maxTempC * 9/5) + 32 : maxTempC
    }

    func minTemp(fahrenheit: Bool) -> Double {
        fahrenheit ? (minTempC * 9/5) + 32 : minTempC
    }
}

// MARK: - Weather Service

@MainActor
final class WeatherService {

    static let shared = WeatherService()
    private init() {}

    private var cache: [String: (days: [WeatherDay], fetched: Date)] = [:]
    private let cacheTTL: TimeInterval = 30 * 60  // 30 minutes

    // MARK: - Fetch Forecast

    func fetchForecast(
        lat: Double,
        lon: Double,
        startDate: Date,
        endDate: Date
    ) async throws -> [WeatherDay] {

        let startStr = dateString(from: startDate)
        let endStr   = dateString(from: endDate)
        let latR     = roundedToTwoPlaces(lat)
        let lonR     = roundedToTwoPlaces(lon)
        let cacheKey = "\(latR),\(lonR),\(startStr),\(endStr)"

        if let cached = cache[cacheKey], Date().timeIntervalSince(cached.fetched) < cacheTTL {
            return cached.days
        }

        // Clamp: Open-Meteo only forecasts up to 16 days ahead and requires start <= end
        let now = Date()
        let clampedStart = max(startDate, now.addingTimeInterval(-86400 * 7))
        let clampedEnd   = min(endDate, now.addingTimeInterval(86400 * 15))
        guard clampedStart <= clampedEnd else { return [] }

        let clampedStartStr = dateString(from: clampedStart)
        let clampedEndStr   = dateString(from: clampedEnd)

        var components = URLComponents(string: "https://api.open-meteo.com/v1/forecast")!
        components.queryItems = [
            .init(name: "latitude",    value: "\(lat)"),
            .init(name: "longitude",   value: "\(lon)"),
            .init(name: "daily",       value: "temperature_2m_max,temperature_2m_min,weathercode"),
            .init(name: "timezone",    value: "auto"),
            .init(name: "start_date",  value: clampedStartStr),
            .init(name: "end_date",    value: clampedEndStr),
        ]

        let (data, _) = try await URLSession.shared.data(from: components.url!)
        let response  = try JSONDecoder().decode(OpenMeteoResponse.self, from: data)
        let days      = parseDays(from: response)

        cache[cacheKey] = (days, Date())
        return days
    }

    // MARK: - Parse

    private func parseDays(from response: OpenMeteoResponse) -> [WeatherDay] {
        let dates  = response.daily.time
        let maxT   = response.daily.temperature2mMax
        let minT   = response.daily.temperature2mMin
        let codes  = response.daily.weathercode

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone(secondsFromGMT: 0)

        return zip(dates.indices, dates).compactMap { idx, dateStr -> WeatherDay? in
            guard let date = formatter.date(from: dateStr),
                  idx < maxT.count, idx < minT.count, idx < codes.count
            else { return nil }
            return WeatherDay(
                date: date,
                maxTempC: maxT[idx] ?? 0,
                minTempC: minT[idx] ?? 0,
                weatherCode: codes[idx] ?? 0
            )
        }
    }

    // MARK: - Helpers (inlined to avoid actor-isolation issues with extensions)

    private func dateString(from date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = TimeZone(secondsFromGMT: 0)
        return f.string(from: date)
    }

    private func roundedToTwoPlaces(_ value: Double) -> Double {
        let factor = 100.0
        return (value * factor).rounded() / factor
    }
}

// MARK: - API Response Models

private struct OpenMeteoResponse: Decodable {
    let daily: DailyData

    struct DailyData: Decodable {
        let time:               [String]
        let temperature2mMax:   [Double?]
        let temperature2mMin:   [Double?]
        let weathercode:        [Int?]

        enum CodingKeys: String, CodingKey {
            case time
            case temperature2mMax = "temperature_2m_max"
            case temperature2mMin = "temperature_2m_min"
            case weathercode
        }
    }
}
