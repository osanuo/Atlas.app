//
//  AtlasApp.swift
//  Atlas
//
//  Created by Dawid Piotrowski on 11/03/2026.
//

import SwiftUI
import SwiftData

@main
struct AtlasApp: App {

    @State private var container: ModelContainer?
    // Tracks hasOnboarded reactively (UserProfile is @Observable)
    @State private var profile = UserProfile.shared

    var body: some Scene {
        WindowGroup {
            Group {
                if let container {
                    if profile.hasOnboarded {
                        ContentView()
                            .environment(profile)
                            .modelContainer(container)
                            .transition(.opacity)
                    } else {
                        OnboardingView {
                            profile.hasOnboarded = true
                        }
                        .transition(.opacity)
                    }
                } else {
                    LaunchView()
                        .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.45), value: container != nil)
            .animation(.easeInOut(duration: 0.6), value: profile.hasOnboarded)
            .task(priority: .userInitiated) {
                guard container == nil else { return }
                container = await Task.detached(priority: .userInitiated) {
                    AtlasApp.makeContainer()
                }.value
            }
        }
    }

    nonisolated private static func makeContainer() -> ModelContainer {
        let schema = Schema([Trip.self, TripItem.self, CrewMember.self, Expense.self, WishlistDestination.self, VisitedLocation.self])

        // Try CloudKit-backed container first
        if let c = try? ModelContainer(
            for: schema,
            configurations: [ModelConfiguration(schema: schema, cloudKitDatabase: .automatic)]
        ) { return c }

        // Fallback 1: local-only storage
        let localConfig = ModelConfiguration(schema: schema, cloudKitDatabase: .none)
        if let c = try? ModelContainer(for: schema, configurations: [localConfig]) { return c }

        // Fallback 2: destroy corrupted store and recreate
        destroyDefaultStore()
        if let c = try? ModelContainer(for: schema, configurations: [localConfig]) { return c }

        fatalError("Cannot create ModelContainer — aborting.")
    }

    nonisolated private static func destroyDefaultStore() {
        guard let appSupport = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask).first else { return }
        let base = appSupport.appendingPathComponent("default.store")
        for url in [
            base,
            base.appendingPathExtension("wal"),
            base.appendingPathExtension("shm")
        ] {
            try? FileManager.default.removeItem(at: url)
        }
    }
}

// MARK: - Launch Screen

struct LaunchView: View {
    var body: some View {
        ZStack {
            Color.atlasTeal.ignoresSafeArea()
            VStack(spacing: 16) {
                Image(systemName: "airplane")
                    .font(.system(size: 48, weight: .bold))
                    .foregroundStyle(.white)
                Text("ATLAS")
                    .font(.system(size: 32, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white)
                    .kerning(8)
            }
        }
    }
}
