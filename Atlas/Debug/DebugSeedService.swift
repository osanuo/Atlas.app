//
//  DebugSeedService.swift
//  Atlas
//
//  Inserts rich sample data so every screen has something to show.
//  Wrapped in #if DEBUG — stripped from Release builds automatically.
//

#if DEBUG

import SwiftData
import Foundation

enum DebugSeedService {

    // MARK: - Public API

    static func seed(in context: ModelContext) {
        clearAll(in: context)

        let calendar = Calendar.current
        let now = Date()

        func days(_ n: Int) -> Date {
            calendar.date(byAdding: .day, value: n, to: now)!
        }

        // ── TRIP 1 ── Tokyo (ACTIVE — currently on the trip) ─────────────────
        let tokyo = Trip(
            name: "Tokyo Adventure",
            destination: "TOKYO",
            destinationFlag: "🇯🇵",
            startDate: days(-3),
            endDate: days(9),
            cardColorHex: "FCDA85",
            status: .active,
            budget: 2400,
            travelerCount: 3
        )
        context.insert(tokyo)

        // Items
        let tokyoItems: [(String, ItemCategory, String, Double?, ItemPriority, BookingStatus, Bool)] = [
            ("ANA Flight NH203",       .transportation,  "Tokyo Narita Airport NRT",            850, .mustDo,     .confirmed, true),
            ("Shinjuku Granbell Hotel",.accommodation,   "2-14-5 Kabukicho, Shinjuku, Tokyo",   120, .mustDo,     .confirmed, true),
            ("Sukiyabashi Jiro",       .restaurants,     "4-2-15 Ginza, Chuo, Tokyo",           350, .mustDo,     .confirmed, true),
            ("Senso-ji Temple",        .places,          "2-3-1 Asakusa, Taito, Tokyo",         nil, .mustDo,     .notBooked, false),
            ("Shibuya Crossing",       .places,          "Shibuya, Tokyo",                      nil, .niceToHave, .notBooked, true),
            ("TeamLab Borderless",     .paidActivities,  "1-3-8 Azabudai, Minato, Tokyo",       38,  .mustDo,     .confirmed, true),
            ("Ichiran Ramen",          .restaurants,     "Harajuku, Shibuya, Tokyo",             15,  .niceToHave, .notBooked, true),
            ("Akihabara Electric Town",.freeActivities,  "Akihabara, Chiyoda, Tokyo",           nil, .niceToHave, .notBooked, false),
            ("Tokyo Skytree",          .paidActivities,  "1-1-2 Oshiage, Sumida, Tokyo",        21,  .niceToHave, .notBooked, false),
            ("Harajuku Takeshita St.", .places,          "Takeshita Street, Harajuku, Tokyo",   nil, .backup,     .notBooked, false),
        ]
        for (title, cat, addr, price, priority, booking, done) in tokyoItems {
            let item = TripItem(
                title: title, category: cat, notes: "",
                url: "", locationAddress: addr, price: price,
                priority: priority, bookingStatus: booking, trip: tokyo
            )
            item.isCompleted = done
            context.insert(item)
        }

        // Crew
        let tokyoCrew: [(String, CrewStatus, String)] = [
            ("Emma Wilson", .confirmed, "NH203"),
            ("Jake Kim",    .confirmed, "NH203"),
            ("Sofia Reyes", .pending,   ""),
        ]
        for (name, status, flight) in tokyoCrew {
            let m = CrewMember(name: name, status: status, flightInfo: flight, trip: tokyo)
            context.insert(m)
        }

        // Expenses — $1,157 spent of $2,400 budget
        let tokyoExpenses: [(Double, String, ItemCategory, Int)] = [
            (850,  "ANA flights (3 seats)",   .transportation,  -4),
            (360,  "Sukiyabashi Jiro",        .restaurants,     -2),
            (38,   "TeamLab ticket",          .paidActivities,  -2),
            (23,   "Ichiran ramen x3",        .restaurants,     -1),
            (45,   "Day 1 metro passes",      .transportation,  -3),
            (87,   "Akihabara gadgets",       .places,          -1),
            (97,   "Hotel night 1-2",         .accommodation,   -3),
        ]
        for (amount, note, cat, dayOffset) in tokyoExpenses {
            let e = Expense(amount: amount, note: note, category: cat,
                            date: days(dayOffset), trip: tokyo)
            context.insert(e)
        }

        // ── TRIP 2 ── Paris (PLANNING — next month) ───────────────────────────
        let paris = Trip(
            name: "Paris Getaway",
            destination: "PARIS",
            destinationFlag: "🇫🇷",
            startDate: days(28),
            endDate: days(33),
            cardColorHex: "EBCFDA",
            status: .planning,
            budget: 1800,
            travelerCount: 2
        )
        context.insert(paris)

        let parisItems: [(String, ItemCategory, String, Double?, BookingStatus)] = [
            ("Eurostar from London",   .transportation, "Paris Gare du Nord",                    220, .confirmed),
            ("Hotel Le Marais",        .accommodation,  "15 Rue du Temple, Paris",               160, .confirmed),
            ("Eiffel Tower Summit",    .paidActivities, "Champ de Mars, Paris",                   30, .pending),
            ("Le Comptoir du Relais",  .restaurants,    "9 Carrefour de l'Odeon, Paris",         nil, .notBooked),
            ("Louvre Museum",          .paidActivities, "Rue de Rivoli, Paris",                   22, .notBooked),
            ("Montmartre Walk",        .freeActivities, "Montmartre, Paris",                      nil, .notBooked),
            ("Seine River Cruise",     .paidActivities, "Port de la Bourdonnais, Paris",          17, .notBooked),
            ("Cafe de Flore",          .restaurants,    "172 Blvd Saint-Germain, Paris",         nil, .notBooked),
        ]
        for (title, cat, addr, price, booking) in parisItems {
            let item = TripItem(
                title: title, category: cat, notes: "",
                url: "", locationAddress: addr, price: price,
                priority: .niceToHave, bookingStatus: booking, trip: paris
            )
            context.insert(item)
        }

        let m1 = CrewMember(name: "Alex Chen", status: .confirmed, flightInfo: "Eurostar", trip: paris)
        context.insert(m1)

        // ── TRIP 3 ── Berlin (COMPLETED — 2 months ago) ──────────────────────
        let berlin = Trip(
            name: "Berlin Techno Weekend",
            destination: "BERLIN",
            destinationFlag: "🇩🇪",
            startDate: days(-62),
            endDate: days(-57),
            cardColorHex: "FFFFFF",
            status: .completed,
            budget: 600,
            travelerCount: 1
        )
        context.insert(berlin)

        let berlinItems: [(String, ItemCategory, Bool)] = [
            ("Ryanair FR1234",          .transportation,  true),
            ("Hostel Berlin Mitte",     .accommodation,   true),
            ("Berghain",                .paidActivities,  true),
            ("Currywurst at Curry 36",  .restaurants,     true),
            ("East Side Gallery",       .freeActivities,  true),
        ]
        for (title, cat, done) in berlinItems {
            let item = TripItem(title: title, category: cat, trip: berlin)
            item.isCompleted = done
            context.insert(item)
        }

        // Expenses — $693 vs $600 budget (slightly over)
        let berlinExpenses: [(Double, String, ItemCategory, Int)] = [
            (89,  "Ryanair flight",       .transportation,  -62),
            (185, "Hostel 5 nights",      .accommodation,   -62),
            (22,  "Berghain entry",       .paidActivities,  -60),
            (47,  "Dinner + beers",       .restaurants,     -60),
            (55,  "Transit card",         .transportation,  -62),
            (124, "Shopping at Mitte",    .places,          -59),
            (171, "Misc / taxi",          .transportation,  -57),
        ]
        for (amount, note, cat, dayOffset) in berlinExpenses {
            let e = Expense(amount: amount, note: note, category: cat,
                            date: days(dayOffset), trip: berlin)
            context.insert(e)
        }

        // ── TRIP 4 ── Kyoto (CONFIRMED — 3 months away) ──────────────────────
        let kyoto = Trip(
            name: "Kyoto Sakura Season",
            destination: "KYOTO",
            destinationFlag: "🇯🇵",
            startDate: days(82),
            endDate: days(89),
            cardColorHex: "5499E8",
            status: .confirmed,
            budget: 1600,
            travelerCount: 2
        )
        context.insert(kyoto)

        let kyotoItems: [(String, ItemCategory, String, BookingStatus)] = [
            ("JAL Flight JL717",         .transportation, "Kansai International Airport", .confirmed),
            ("Ryokan Tawaraya",          .accommodation,  "Nakagyo-ku, Kyoto",           .confirmed),
            ("Fushimi Inari Shrine",     .freeActivities, "68 Fukakusa Yabunouchi, Kyoto",.notBooked),
            ("Nishiki Market",           .freeActivities, "Nishiki Market, Nakagyo, Kyoto",.notBooked),
            ("Arashiyama Bamboo Grove",  .freeActivities, "Sagatenryuji, Ukyo, Kyoto",   .notBooked),
            ("Kaiseki dinner",           .restaurants,    "Gion, Kyoto",                 .pending),
        ]
        for (title, cat, addr, booking) in kyotoItems {
            let item = TripItem(
                title: title, category: cat, notes: "",
                url: "", locationAddress: addr, price: nil,
                priority: .mustDo, bookingStatus: booking, trip: kyoto
            )
            context.insert(item)
        }

        // ── WISHLIST DESTINATIONS ─────────────────────────────────────────────
        let wishlist: [(String, String, String, String, Bool)] = [
            ("KYOTO",     "Japan",        "Cherry blossoms, temples, tea ceremony",
             "https://images.unsplash.com/photo-1493976040374-85c8e12f0c0e?auto=format&fit=crop&q=80&w=800", false),
            ("SANTORINI", "Greece",       "Blue domes, sunsets, Aegean vibes",
             "https://images.unsplash.com/photo-1570077188670-e3a8d69ac5ff?auto=format&fit=crop&q=80&w=800", false),
            ("REYKJAVIK", "Iceland",      "Northern lights & midnight sun",
             "https://images.unsplash.com/photo-1518709268805-4e9042af9f23?auto=format&fit=crop&q=80&w=800", false),
            ("MALDIVES",  "Maldives",     "Overwater bungalows, coral reefs",
             "https://images.unsplash.com/photo-1573843981267-be1999ff37cd?auto=format&fit=crop&q=80&w=800", false),
            ("BANFF",     "Canada",       "Rocky Mountains, turquoise lakes",
             "https://images.unsplash.com/photo-1501854140801-50d01698950b?auto=format&fit=crop&q=80&w=800", false),
            ("SHIBUYA",   "Japan",        "Neon lights, street fashion, energy",
             "https://images.unsplash.com/photo-1542051841857-5f90071e7989?auto=format&fit=crop&q=80&w=800", true),
        ]
        for (city, country, notes, imageURL, visited) in wishlist {
            let dest = WishlistDestination(city: city, country: country,
                                           notes: notes, imageURL: imageURL)
            dest.isVisited = visited
            context.insert(dest)
        }

        try? context.save()
    }

    // MARK: - Clear All

    static func clearAll(in context: ModelContext) {
        try? context.delete(model: WishlistDestination.self)
        try? context.delete(model: Expense.self)
        try? context.delete(model: TripItem.self)
        try? context.delete(model: CrewMember.self)
        try? context.delete(model: Trip.self)
        try? context.save()
    }
}

#endif
