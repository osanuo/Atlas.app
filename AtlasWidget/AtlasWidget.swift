//
//  AtlasWidget.swift
//  AtlasWidget
//
//  Created by Dawid Piotrowski on 15/03/2026.
//

import WidgetKit
import SwiftUI

struct WidgetEntry: TimelineEntry {
    let date: Date
    let tripName: String
    let flag: String
    let daysUntil: Int
    let isPro: Bool
    let tripID: String   // UUID string for deep link
}

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> WidgetEntry {
        WidgetEntry(date: Date(), tripName: "Tokyo", flag: "🇯🇵", daysUntil: 12, isPro: true, tripID: "")
    }

    func getSnapshot(in context: Context, completion: @escaping (WidgetEntry) -> Void) {
        completion(entry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<WidgetEntry>) -> Void) {
        let current = entry()
        // Refresh once per hour
        let nextUpdate = Calendar.current.date(byAdding: .hour, value: 1, to: Date()) ?? Date()
        let timeline = Timeline(entries: [current], policy: .after(nextUpdate))
        completion(timeline)
    }

    private func entry() -> WidgetEntry {
        let shared = UserDefaults(suiteName: "group.com.osanuo.Atlas")
        let tripName = shared?.string(forKey: "widget_tripName") ?? ""
        let flag = shared?.string(forKey: "widget_flag") ?? "✈️"
        let startDate = shared?.object(forKey: "widget_startDate") as? Date
        let isPro = shared?.bool(forKey: "atlas_isPro") ?? false
        let tripID = shared?.string(forKey: "widget_tripID") ?? ""

        let daysUntil: Int
        if let start = startDate {
            let days = Calendar.current.dateComponents(
                [.day],
                from: Calendar.current.startOfDay(for: Date()),
                to: Calendar.current.startOfDay(for: start)
            ).day ?? 0
            daysUntil = max(0, days)
        } else {
            daysUntil = 0
        }

        return WidgetEntry(date: Date(), tripName: tripName, flag: flag, daysUntil: daysUntil, isPro: isPro, tripID: tripID)
    }
}

// MARK: - Small Widget View

struct SmallWidgetView: View {
    let entry: WidgetEntry

    var body: some View {
        if entry.isPro && !entry.tripName.isEmpty {
            VStack(spacing: 4) {
                Text(entry.flag)
                    .font(.system(size: 36))
                Text("\(entry.daysUntil)")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                Text(entry.daysUntil == 1 ? "day to go" : "days to go")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .widgetURL(deepLinkURL(for: entry.tripID))
        } else if !entry.isPro {
            proLockedView
                .widgetURL(URL(string: "atlas://paywall"))
        } else {
            noTripView
        }
    }

    private var proLockedView: some View {
        VStack(spacing: 6) {
            Image(systemName: "lock.fill")
                .font(.title2)
                .foregroundStyle(.secondary)
            Text("Atlas Pro")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var noTripView: some View {
        VStack(spacing: 6) {
            Text("✈️")
                .font(.system(size: 30))
            Text("No trip\nplanned")
                .font(.caption2)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Medium Widget View

struct MediumWidgetView: View {
    let entry: WidgetEntry

    var body: some View {
        if entry.isPro && !entry.tripName.isEmpty {
            HStack(spacing: 16) {
                Text(entry.flag)
                    .font(.system(size: 48))

                VStack(alignment: .leading, spacing: 4) {
                    Text(entry.tripName)
                        .font(.headline)
                        .lineLimit(1)
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text("\(entry.daysUntil)")
                            .font(.system(size: 36, weight: .bold, design: .rounded))
                        Text(entry.daysUntil == 1 ? "day to go" : "days to go")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
            }
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .widgetURL(deepLinkURL(for: entry.tripID))
        } else if !entry.isPro {
            HStack(spacing: 12) {
                Image(systemName: "lock.fill")
                    .font(.title)
                    .foregroundStyle(.secondary)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Atlas Pro")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    Text("Upgrade to see your countdown")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                Spacer()
            }
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .widgetURL(URL(string: "atlas://paywall"))
        } else {
            HStack(spacing: 12) {
                Text("✈️")
                    .font(.system(size: 40))
                Text("No upcoming trips planned")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

// MARK: - Entry View

struct AtlasWidgetEntryView: View {
    @Environment(\.widgetFamily) var family
    var entry: Provider.Entry

    var body: some View {
        switch family {
        case .systemSmall:
            SmallWidgetView(entry: entry)
        case .systemMedium:
            MediumWidgetView(entry: entry)
        default:
            SmallWidgetView(entry: entry)
        }
    }
}

// MARK: - Widget Bundle

@main
struct AtlasWidgetBundle: WidgetBundle {
    var body: some Widget {
        AtlasWidget()
    }
}

// MARK: - Widget

struct AtlasWidget: Widget {
    let kind: String = "AtlasWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            AtlasWidgetEntryView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Trip Countdown")
        .description("See how many days until your next trip.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// MARK: - Deep Link Helper

private func deepLinkURL(for tripID: String) -> URL? {
    guard !tripID.isEmpty else { return URL(string: "atlas://trips") }
    return URL(string: "atlas://trip/\(tripID)")
}

// MARK: - Preview

#Preview(as: .systemSmall) {
    AtlasWidget()
} timeline: {
    WidgetEntry(date: .now, tripName: "Tokyo", flag: "🇯🇵", daysUntil: 12, isPro: true, tripID: "")
    WidgetEntry(date: .now, tripName: "", flag: "✈️", daysUntil: 0, isPro: false, tripID: "")
}
