//
//  AtlasWidget.swift
//  AtlasWidget
//
//  Departure countdown widget. Reads trip data from shared App Group UserDefaults.
//
//  SETUP REQUIRED in Xcode:
//  1. Add an "App Extension" target: Widget Extension → name "AtlasWidget"
//  2. Add App Group "group.com.osanuo.Atlas" to both Atlas and AtlasWidget targets
//  3. Add this file to the AtlasWidget target
//

import WidgetKit
import SwiftUI

// MARK: - Timeline Entry

struct AtlasWidgetEntry: TimelineEntry {
    let date: Date
    let tripName: String
    let destination: String
    let flag: String
    let daysUntil: Int
    let isPro: Bool
}

// MARK: - Timeline Provider

struct AtlasWidgetProvider: TimelineProvider {

    func placeholder(in context: Context) -> AtlasWidgetEntry {
        AtlasWidgetEntry(date: Date(), tripName: "Tokyo Adventure", destination: "TOKYO", flag: "🇯🇵", daysUntil: 14, isPro: true)
    }

    func getSnapshot(in context: Context, completion: @escaping (AtlasWidgetEntry) -> Void) {
        completion(makeEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<AtlasWidgetEntry>) -> Void) {
        let entry = makeEntry()
        // Refresh daily
        let nextUpdate = Calendar.current.startOfDay(for: Date()).addingTimeInterval(86400)
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }

    // MARK: - Read shared UserDefaults

    private func makeEntry() -> AtlasWidgetEntry {
        let shared = UserDefaults(suiteName: "group.com.osanuo.Atlas")
        let destination = shared?.string(forKey: "widget_destination") ?? ""
        let flag        = shared?.string(forKey: "widget_flag") ?? "✈️"
        let tripName    = shared?.string(forKey: "widget_tripName") ?? ""
        let startDate   = shared?.object(forKey: "widget_startDate") as? Date
        let isPro       = shared?.bool(forKey: "atlas_isPro") ?? false

        let daysUntil: Int = {
            guard let start = startDate else { return 0 }
            let days = Calendar.current.dateComponents([.day], from: Date(), to: start).day ?? 0
            return max(0, days)
        }()

        return AtlasWidgetEntry(
            date: Date(),
            tripName: tripName,
            destination: destination.isEmpty ? "No upcoming trips" : destination,
            flag: flag,
            daysUntil: daysUntil,
            isPro: isPro
        )
    }
}

// MARK: - Small Widget View

struct AtlasWidgetSmallView: View {
    let entry: AtlasWidgetEntry

    var body: some View {
        if !entry.isPro {
            proLockedView
        } else if entry.destination == "No upcoming trips" {
            emptyView
        } else {
            countdownView
        }
    }

    private var countdownView: some View {
        ZStack {
            Color.black
            VStack(spacing: 6) {
                Text(entry.flag)
                    .font(.system(size: 32))
                Text("\(entry.daysUntil)")
                    .font(.system(size: 36, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white)
                Text(entry.daysUntil == 1 ? "DAY TO GO" : "DAYS TO GO")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.5))
                    .kerning(1.5)
                Text(entry.destination.prefix(12).uppercased())
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .foregroundStyle(Color(red: 0.25, green: 0.75, blue: 0.72))
                    .lineLimit(1)
            }
        }
    }

    private var emptyView: some View {
        ZStack {
            Color.black
            VStack(spacing: 6) {
                Text("✈️").font(.system(size: 28))
                Text("No trips\nplanned yet")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.5))
                    .multilineTextAlignment(.center)
            }
        }
    }

    private var proLockedView: some View {
        ZStack {
            Color.black
            VStack(spacing: 8) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(.white.opacity(0.3))
                Text("Atlas Pro")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.4))
            }
        }
    }
}

// MARK: - Medium Widget View

struct AtlasWidgetMediumView: View {
    let entry: AtlasWidgetEntry

    var body: some View {
        if !entry.isPro {
            mediumProLockedView
        } else {
            mediumCountdownView
        }
    }

    private var mediumCountdownView: some View {
        ZStack {
            Color.black
            HStack(spacing: 20) {
                Text(entry.flag)
                    .font(.system(size: 48))

                VStack(alignment: .leading, spacing: 4) {
                    Text(entry.destination.prefix(16).uppercased())
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white)
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text("\(entry.daysUntil)")
                            .font(.system(size: 40, weight: .bold, design: .monospaced))
                            .foregroundStyle(.white)
                        Text(entry.daysUntil == 1 ? "day to go" : "days to go")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.white.opacity(0.5))
                    }
                    if !entry.tripName.isEmpty {
                        Text(entry.tripName)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(Color(red: 0.25, green: 0.75, blue: 0.72))
                            .lineLimit(1)
                    }
                }
                Spacer()
            }
            .padding(.horizontal, 20)
        }
    }

    private var mediumProLockedView: some View {
        ZStack {
            Color.black
            HStack(spacing: 12) {
                Image(systemName: "airplane.circle.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(Color(red: 0.25, green: 0.75, blue: 0.72))
                VStack(alignment: .leading, spacing: 4) {
                    Text("Atlas Widget")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                    Text("Upgrade to Atlas Pro to see your departure countdown")
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.45))
                }
            }
            .padding(.horizontal, 20)
        }
    }
}

// MARK: - Widget Configuration

struct AtlasWidget: Widget {
    let kind: String = "AtlasWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: AtlasWidgetProvider()) { entry in
            Group {
                if #available(iOS 17, *) {
                    AtlasWidgetSmallView(entry: entry)
                        .containerBackground(.black, for: .widget)
                } else {
                    AtlasWidgetSmallView(entry: entry)
                }
            }
        }
        .configurationDisplayName("Atlas")
        .description("Departure countdown for your next trip.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// MARK: - Widget Bundle

@main
struct AtlasWidgetBundle: WidgetBundle {
    var body: some Widget {
        AtlasWidget()
    }
}
