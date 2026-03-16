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
import UIKit

enum DebugSeedService {

    // MARK: - Public API

    static func seed(in context: ModelContext) {
        clearAll(in: context)

        let cal = Calendar.current
        let now = Date()

        func days(_ n: Int) -> Date { cal.date(byAdding: .day, value: n, to: now)! }
        func hrs(_ h: Int, on base: Date) -> Date {
            var c = cal.dateComponents([.year, .month, .day], from: base)
            c.hour = h; c.minute = 0
            return cal.date(from: c) ?? base
        }

        // ══════════════════════════════════════════════════════════════════════
        // TRIP 1 — Tokyo Adventure  (ACTIVE — mid-trip right now)
        // ══════════════════════════════════════════════════════════════════════
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

        // — Items with itinerary assignments —
        struct TItem {
            var title: String; var cat: ItemCategory; var addr: String
            var price: Double?; var priority: ItemPriority; var booking: BookingStatus
            var done: Bool; var day: Int?; var hour: Int?; var url: String = ""
        }
        let tokyoItems: [TItem] = [
            TItem(title: "ANA Flight NH203",        cat: .transportation,  addr: "Tokyo Narita Airport NRT",           price: 850, priority: .mustDo,     booking: .confirmed, done: true,  day: -3,  hour: 8),
            TItem(title: "Shinjuku Granbell Hotel",  cat: .accommodation,   addr: "2-14-5 Kabukicho, Shinjuku, Tokyo",  price: 120, priority: .mustDo,     booking: .confirmed, done: true,  day: -3,  hour: 15),
            TItem(title: "Senso-ji Temple",          cat: .places,          addr: "2-3-1 Asakusa, Taito, Tokyo",        price: nil, priority: .mustDo,     booking: .notBooked, done: true,  day: -2,  hour: 9),
            TItem(title: "Sukiyabashi Jiro",         cat: .restaurants,     addr: "4-2-15 Ginza, Chuo, Tokyo",          price: 350, priority: .mustDo,     booking: .confirmed, done: true,  day: -2,  hour: 13),
            TItem(title: "TeamLab Planets",          cat: .paidActivities,  addr: "6-1-16 Toyosu, Koto, Tokyo",         price: 38,  priority: .mustDo,     booking: .confirmed, done: true,  day: -1,  hour: 10),
            TItem(title: "Shibuya Crossing",         cat: .places,          addr: "Shibuya, Tokyo",                     price: nil, priority: .niceToHave, booking: .notBooked, done: true,  day: -1,  hour: 18),
            TItem(title: "Ichiran Ramen",            cat: .restaurants,     addr: "Harajuku, Shibuya, Tokyo",            price: 15,  priority: .niceToHave, booking: .notBooked, done: false, day: 0,   hour: 12),
            TItem(title: "Akihabara Electric Town",  cat: .freeActivities,  addr: "Akihabara, Chiyoda, Tokyo",          price: nil, priority: .niceToHave, booking: .notBooked, done: false, day: 0,   hour: 14),
            TItem(title: "Tokyo Skytree",            cat: .paidActivities,  addr: "1-1-2 Oshiage, Sumida, Tokyo",       price: 21,  priority: .niceToHave, booking: .notBooked, done: false, day: 1,   hour: 17),
            TItem(title: "Harajuku Takeshita Street",cat: .places,          addr: "Takeshita St, Harajuku, Tokyo",       price: nil, priority: .backup,     booking: .notBooked, done: false, day: 2,   hour: 10),
            TItem(title: "Tsukiji Outer Market",     cat: .freeActivities,  addr: "4-16-2 Tsukiji, Chuo, Tokyo",        price: nil, priority: .mustDo,     booking: .notBooked, done: false, day: 3,   hour: 7),
            TItem(title: "Meiji Shrine",             cat: .freeActivities,  addr: "1-1 Yoyogi Kamizono-cho, Tokyo",     price: nil, priority: .mustDo,     booking: .notBooked, done: false, day: 4,   hour: 9),
        ]
        for t in tokyoItems {
            let item = TripItem(
                title: t.title, category: t.cat, notes: "",
                url: t.url, locationAddress: t.addr, price: t.price,
                priority: t.priority, bookingStatus: t.booking, trip: tokyo
            )
            item.isCompleted = t.done
            if let d = t.day {
                let base = days(d)
                item.dayAssigned = cal.startOfDay(for: base)
                item.timeAssigned = hrs(t.hour ?? 9, on: base)
            }
            context.insert(item)
        }

        // — Crew —
        let tokyoCrew: [(String, CrewStatus, String)] = [
            ("Emma Wilson", .confirmed, "NH203"),
            ("Jake Kim",    .confirmed, "NH203"),
            ("Sofia Reyes", .confirmed, "NH205"),
        ]
        for (name, status, flight) in tokyoCrew {
            context.insert(CrewMember(name: name, status: status, flightInfo: flight, trip: tokyo))
        }

        // — Expenses ($1,500 of $2,400) —
        let tokyoExp: [(Double, String, ItemCategory, Int)] = [
            (850, "ANA flights x3",         .transportation,  -4),
            (360, "Sukiyabashi Jiro dinner", .restaurants,     -2),
            (38,  "TeamLab ticket",          .paidActivities,  -2),
            (45,  "Metro day passes",        .transportation,  -3),
            (23,  "Ichiran ramen x3",        .restaurants,     -1),
            (87,  "Akihabara gadgets",       .places,          -1),
            (97,  "Hotel night 1",           .accommodation,   -3),
        ]
        for (amt, note, cat, d) in tokyoExp {
            context.insert(Expense(amount: amt, note: note, category: cat, date: days(d), trip: tokyo))
        }

        // ══════════════════════════════════════════════════════════════════════
        // TRIP 2 — Paris Getaway  (PLANNING — in 4 weeks)
        // ══════════════════════════════════════════════════════════════════════
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

        let parisItems: [(String, ItemCategory, String, Double?, BookingStatus, ItemPriority)] = [
            ("Eurostar from London",    .transportation, "Paris Gare du Nord",               220, .confirmed, .mustDo),
            ("Hôtel du Petit Moulin",  .accommodation,  "29-31 Rue de Poitou, Paris",        185, .confirmed, .mustDo),
            ("Eiffel Tower Summit",    .paidActivities, "Champ de Mars, Paris",              30,  .pending,   .mustDo),
            ("Louvre Museum",          .paidActivities, "Rue de Rivoli, Paris",              22,  .notBooked, .mustDo),
            ("Le Comptoir du Relais",  .restaurants,    "9 Carrefour de l'Odéon, Paris",    nil, .notBooked, .mustDo),
            ("Café de Flore",          .restaurants,    "172 Blvd Saint-Germain, Paris",    nil, .notBooked, .niceToHave),
            ("Montmartre Walk",        .freeActivities, "Montmartre, Paris",                 nil, .notBooked, .niceToHave),
            ("Seine River Cruise",     .paidActivities, "Port de la Bourdonnais, Paris",    17,  .notBooked, .niceToHave),
            ("Musée d'Orsay",         .paidActivities, "1 Rue de la Légion d'Honneur",     16,  .notBooked, .niceToHave),
            ("Marais Falafel Street",  .restaurants,    "Rue des Rosiers, Paris",            nil, .notBooked, .backup),
        ]
        for (title, cat, addr, price, booking, priority) in parisItems {
            context.insert(TripItem(
                title: title, category: cat, notes: "",
                url: "", locationAddress: addr, price: price,
                priority: priority, bookingStatus: booking, trip: paris
            ))
        }
        context.insert(CrewMember(name: "Alex Chen",    status: .confirmed, flightInfo: "Eurostar", trip: paris))
        context.insert(CrewMember(name: "Mia Kowalski", status: .pending,   flightInfo: "",          trip: paris))

        // — Early expenses (deposit paid) —
        context.insert(Expense(amount: 220, note: "Eurostar tickets x2",  category: .transportation, date: days(-5), trip: paris))
        context.insert(Expense(amount: 370, note: "Hotel deposit 2 nights", category: .accommodation, date: days(-3), trip: paris))

        // ══════════════════════════════════════════════════════════════════════
        // TRIP 3 — Marbella Summer  (PLANNING — 8 weeks out)
        // ══════════════════════════════════════════════════════════════════════
        let marbella = Trip(
            name: "Marbella Summer",
            destination: "MARBELLA",
            destinationFlag: "🇪🇸",
            startDate: days(54),
            endDate: days(61),
            cardColorHex: "FFB347",
            status: .planning,
            budget: 2200,
            travelerCount: 4
        )
        context.insert(marbella)

        let marbellaItems: [(String, ItemCategory, String, Double?, BookingStatus)] = [
            ("Ryanair FR2048",           .transportation, "Málaga Airport AGP",                 210, .confirmed),
            ("Villa Marbella Old Town",  .accommodation,  "Calle Ancha, Marbella",              340, .confirmed),
            ("Nikki Beach Club",         .paidActivities, "Bulevar Príncipe Alfonso, Marbella", 80,  .pending),
            ("Nobu Marbella",            .restaurants,    "Bulevar Príncipe Alfonso, Marbella", nil, .notBooked),
            ("Gibraltar Day Trip",       .freeActivities, "Gibraltar",                           nil, .notBooked),
            ("Marbella Old Town Walk",   .freeActivities, "Casco Antiguo, Marbella",             nil, .notBooked),
            ("El Chiringuito Beach Bar", .restaurants,    "Playa de la Fontanilla, Marbella",    nil, .notBooked),
        ]
        for (title, cat, addr, price, booking) in marbellaItems {
            context.insert(TripItem(
                title: title, category: cat, notes: "",
                url: "", locationAddress: addr, price: price,
                priority: .niceToHave, bookingStatus: booking, trip: marbella
            ))
        }
        context.insert(CrewMember(name: "Lucas Ferreira", status: .confirmed, flightInfo: "FR2048", trip: marbella))
        context.insert(CrewMember(name: "Sara Müller",    status: .confirmed, flightInfo: "FR2048", trip: marbella))
        context.insert(CrewMember(name: "Tom Nowak",      status: .pending,   flightInfo: "",        trip: marbella))

        // ══════════════════════════════════════════════════════════════════════
        // TRIP 4 — Kyoto Sakura Season  (CONFIRMED — 3 months out)
        // ══════════════════════════════════════════════════════════════════════
        let kyoto = Trip(
            name: "Kyoto Sakura Season",
            destination: "KYOTO",
            destinationFlag: "🇯🇵",
            startDate: days(82),
            endDate: days(89),
            cardColorHex: "C3B1E1",
            status: .confirmed,
            budget: 1600,
            travelerCount: 2
        )
        context.insert(kyoto)

        let kyotoItems: [(String, ItemCategory, String, Double?, BookingStatus, ItemPriority)] = [
            ("JAL Flight JL717",         .transportation, "Kansai International Airport",        720, .confirmed, .mustDo),
            ("Ryokan Tawaraya",          .accommodation,  "Nakagyo-ku, Kyoto",                   280, .confirmed, .mustDo),
            ("Fushimi Inari Shrine",     .freeActivities, "68 Fukakusa Yabunouchi-cho, Kyoto",  nil, .notBooked,  .mustDo),
            ("Arashiyama Bamboo Grove",  .freeActivities, "Sagatenryuji Susukinobaba-cho, Kyoto",nil,.notBooked,  .mustDo),
            ("Nishiki Market",           .freeActivities, "Nishiki Market, Nakagyo, Kyoto",      nil, .notBooked, .mustDo),
            ("Kaiseki at Kikunoi",       .restaurants,    "459 Shimokawara-cho, Higashiyama",    180, .pending,   .mustDo),
            ("Kinkaku-ji (Golden Pavilion)",.freeActivities,"1 Kinkakujicho, Kita, Kyoto",       nil, .notBooked, .niceToHave),
            ("Matcha Ceremony",          .paidActivities, "Gion, Kyoto",                          35, .notBooked,  .niceToHave),
        ]
        for (title, cat, addr, price, booking, priority) in kyotoItems {
            context.insert(TripItem(
                title: title, category: cat, notes: "",
                url: "", locationAddress: addr, price: price,
                priority: priority, bookingStatus: booking, trip: kyoto
            ))
        }
        context.insert(CrewMember(name: "Yuki Tanaka", status: .confirmed, flightInfo: "JL717", trip: kyoto))

        // ══════════════════════════════════════════════════════════════════════
        // TRIP 5 — Amsterdam City Break  (COMPLETED — 5 weeks ago)
        // ══════════════════════════════════════════════════════════════════════
        let amsterdam = Trip(
            name: "Amsterdam City Break",
            destination: "AMSTERDAM",
            destinationFlag: "🇳🇱",
            startDate: days(-38),
            endDate: days(-34),
            cardColorHex: "FADADD",
            status: .completed,
            budget: 900,
            travelerCount: 2
        )
        context.insert(amsterdam)

        let amsterdamItems: [(String, ItemCategory, Bool)] = [
            ("EasyJet flight",           .transportation,  true),
            ("Canal House Boutique",     .accommodation,   true),
            ("Rijksmuseum",              .paidActivities,  true),
            ("Anne Frank House",         .paidActivities,  true),
            ("Vondelpark Picnic",        .freeActivities,  true),
            ("Stroopwafel at the Dam",   .restaurants,     true),
            ("Heineken Experience",      .paidActivities,  true),
        ]
        for (title, cat, done) in amsterdamItems {
            let item = TripItem(title: title, category: cat, trip: amsterdam)
            item.isCompleted = done
            context.insert(item)
        }
        let amsterdamExp: [(Double, String, ItemCategory, Int)] = [
            (148, "EasyJet x2",           .transportation, -38),
            (340, "Canal House 4 nights", .accommodation,  -38),
            (38,  "Rijksmuseum tickets",  .paidActivities, -37),
            (22,  "Anne Frank tickets",   .paidActivities, -36),
            (19,  "Heineken Experience",  .paidActivities, -35),
            (67,  "Restaurants & bars",   .restaurants,    -36),
            (44,  "Tram/bike rental",     .transportation, -37),
            (55,  "Souvenirs",            .places,         -34),
        ]
        for (amt, note, cat, d) in amsterdamExp {
            context.insert(Expense(amount: amt, note: note, category: cat, date: days(d), trip: amsterdam))
        }

        // ══════════════════════════════════════════════════════════════════════
        // TRIP 6 — Berlin Techno Weekend  (COMPLETED — 2 months ago)
        // ══════════════════════════════════════════════════════════════════════
        let berlin = Trip(
            name: "Berlin Techno Weekend",
            destination: "BERLIN",
            destinationFlag: "🇩🇪",
            startDate: days(-62),
            endDate: days(-57),
            cardColorHex: "C8E6C9",
            status: .completed,
            budget: 600,
            travelerCount: 1
        )
        context.insert(berlin)

        let berlinItems: [(String, ItemCategory, Bool)] = [
            ("Ryanair FR1234",           .transportation, true),
            ("Hostel Berlin Mitte",      .accommodation,  true),
            ("Berghain",                 .paidActivities, true),
            ("Curry 36 Currywurst",      .restaurants,    true),
            ("East Side Gallery",        .freeActivities, true),
            ("Museum Island",            .freeActivities, true),
        ]
        for (title, cat, done) in berlinItems {
            let item = TripItem(title: title, category: cat, trip: berlin)
            item.isCompleted = done
            context.insert(item)
        }
        let berlinExp: [(Double, String, ItemCategory, Int)] = [
            (89,  "Ryanair flight",      .transportation, -62),
            (185, "Hostel 5 nights",     .accommodation,  -62),
            (22,  "Berghain entry",      .paidActivities, -60),
            (47,  "Dinner + beers",      .restaurants,    -60),
            (55,  "Transit card",        .transportation, -62),
            (124, "Shopping Mitte",      .places,         -59),
            (171, "Misc / taxis",        .transportation, -57),
        ]
        for (amt, note, cat, d) in berlinExp {
            context.insert(Expense(amount: amt, note: note, category: cat, date: days(d), trip: berlin))
        }

        // ══════════════════════════════════════════════════════════════════════
        // VISITED LOCATIONS (Map pins — 8 cities, 6 countries, 3 continents)
        // ══════════════════════════════════════════════════════════════════════
        let pins: [(String, Double, Double, String, String, Int)] = [
            // (name, lat, lon, country, continent, daysAgo)
            ("Tokyo, Japan",      35.6762,  139.6503, "Japan",       "Asia",    3),
            ("Kyoto, Japan",      35.0116,  135.7681, "Japan",       "Asia",    60),
            ("Paris, France",     48.8566,    2.3522, "France",      "Europe",  180),
            ("Amsterdam",         52.3676,    4.9041, "Netherlands", "Europe",  37),
            ("Berlin, Germany",   52.5200,   13.4050, "Germany",     "Europe",  60),
            ("Barcelona, Spain",  41.3851,    2.1734, "Spain",       "Europe",  200),
            ("Rome, Italy",       41.9028,   12.4964, "Italy",       "Europe",  320),
            ("New York, USA",     40.7128,  -74.0060, "USA",         "North America", 410),
        ]
        for (name, lat, lon, country, continent, daysAgo) in pins {
            let pin = VisitedLocation(
                name: name,
                latitude: lat,
                longitude: lon,
                dateVisited: days(-daysAgo),
                country: country,
                continent: continent
            )
            context.insert(pin)
        }

        // ══════════════════════════════════════════════════════════════════════
        // WISHLIST  — images loaded from bundled assets (no network required)
        // ══════════════════════════════════════════════════════════════════════
        func imgData(_ assetName: String) -> Data? {
            UIImage(named: assetName)?.jpegData(compressionQuality: 0.85)
        }

        let wishlist: [(String, String, String, String, Bool)] = [
            ("SANTORINI",    "Greece",    "Blue domes, sunsets, Aegean vibes",           "seed_santorini",  false),
            ("REYKJAVIK",    "Iceland",   "Northern lights & midnight sun adventures",   "seed_reykjavik",  false),
            ("MALDIVES",     "Maldives",  "Overwater bungalows, turquoise reefs",        "seed_maldives",   false),
            ("BANFF",        "Canada",    "Rocky Mountains, Moraine Lake, glaciers",     "seed_banff",      false),
            ("BALI",         "Indonesia", "Rice terraces, temples, surf & sunsets",      "seed_bali",       false),
            ("AMALFI COAST", "Italy",     "Cliffside villages, lemon groves, turquoise sea", "seed_amalfi", false),
            ("MARRAKECH",    "Morocco",   "Souks, riads, sahara at the doorstep",        "seed_marrakech",  false),
            ("SHIBUYA",      "Japan",     "Neon lights, street fashion, electric energy","seed_shibuya",    true),
        ]
        for (city, country, notes, assetName, visited) in wishlist {
            let dest = WishlistDestination(
                city: city, country: country,
                notes: notes, imageData: imgData(assetName)
            )
            dest.isVisited = visited
            context.insert(dest)
        }

        try? context.save()
    }

    // MARK: - Clear All

    static func clearAll(in context: ModelContext) {
        try? context.delete(model: VisitedLocation.self)
        try? context.delete(model: WishlistDestination.self)
        try? context.delete(model: Expense.self)
        try? context.delete(model: TripItem.self)
        try? context.delete(model: CrewMember.self)
        try? context.delete(model: Trip.self)
        try? context.save()
    }
}

#endif
