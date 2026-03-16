//
//  ShareExtensionViewController.swift
//  AtlasShareExtension
//
//  Redesigned: clip any web page directly into a specific planning/active trip,
//  with category selection. Falling back to Wishlist is always available.
//

import UIKit
import SwiftUI
import UniformTypeIdentifiers

// MARK: - Shared Models (keep in sync with AtlasApp.swift)

struct PendingShareItem: Codable {
    let id: String
    let title: String
    let urlString: String
    let destination: String   // "trip" | "wishlist"
    let tripID: String?
    let categoryRaw: String?
    let dateAdded: Date
    var address: String?      // pre-filled from schema.org; nil = not found

    // Custom decoder so older queue items (without `address`) still parse fine
    init(from decoder: Decoder) throws {
        let c       = try decoder.container(keyedBy: CodingKeys.self)
        id          = try c.decode(String.self, forKey: .id)
        title       = try c.decode(String.self, forKey: .title)
        urlString   = try c.decode(String.self, forKey: .urlString)
        destination = try c.decode(String.self, forKey: .destination)
        tripID      = try c.decodeIfPresent(String.self, forKey: .tripID)
        categoryRaw = try c.decodeIfPresent(String.self, forKey: .categoryRaw)
        dateAdded   = try c.decode(Date.self, forKey: .dateAdded)
        address     = try c.decodeIfPresent(String.self, forKey: .address)
    }

    init(id: String, title: String, urlString: String, destination: String,
         tripID: String?, categoryRaw: String?, dateAdded: Date, address: String? = nil) {
        self.id          = id
        self.title       = title
        self.urlString   = urlString
        self.destination = destination
        self.tripID      = tripID
        self.categoryRaw = categoryRaw
        self.dateAdded   = dateAdded
        self.address     = address
    }
}

struct SharedTrip: Codable {
    let id: String
    let name: String
    let destination: String
    let emoji: String
    let status: String        // "planning" | "active" | "completed"
}

// MARK: - Root View Controller

final class ShareExtensionViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        extractItem { [weak self] title, urlString in
            DispatchQueue.main.async {
                guard let self else { return }
                let hosted = UIHostingController(
                    rootView: ShareExtensionView(
                        initialTitle: title,
                        urlString: urlString
                    ) { item in
                        self.save(item: item)
                        self.extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
                    } onCancel: {
                        self.extensionContext?.cancelRequest(withError: NSError(domain: "AtlasCancel", code: 0))
                    }
                )
                hosted.view.frame = self.view.bounds
                hosted.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
                self.addChild(hosted)
                self.view.addSubview(hosted.view)
                hosted.didMove(toParent: self)
            }
        }
    }

    private func extractItem(completion: @escaping (String, String) -> Void) {
        guard let items = extensionContext?.inputItems as? [NSExtensionItem] else {
            completion("", ""); return
        }
        for item in items {
            for attachment in (item.attachments ?? []) {
                if attachment.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
                    attachment.loadItem(forTypeIdentifier: UTType.url.identifier) { data, _ in
                        let urlString = (data as? URL)?.absoluteString ?? ""
                        let title = item.attributedContentText?.string
                               ?? item.attributedTitle?.string
                               ?? ""
                        completion(title, urlString)
                    }
                    return
                }
            }
        }
        completion("", "")
    }

    private func save(item: PendingShareItem) {
        let shared = UserDefaults(suiteName: "group.com.osanuo.Atlas")
        var queue: [PendingShareItem] = []
        if let data = shared?.data(forKey: "atlas_pendingShareItems"),
           let decoded = try? JSONDecoder().decode([PendingShareItem].self, from: data) {
            queue = decoded
        }
        queue.append(item)
        if let encoded = try? JSONEncoder().encode(queue) {
            shared?.set(encoded, forKey: "atlas_pendingShareItems")
        }
    }
}

// MARK: - Share Extension SwiftUI View

struct ShareExtensionView: View {

    let initialTitle: String
    let urlString: String
    let onSave: (PendingShareItem) -> Void
    let onCancel: () -> Void

    @State private var title: String
    @State private var selectedTripID: String? = nil
    @State private var selectedCategory: String
    @State private var saveMode: SaveMode
    @State private var isPro: Bool
    @State private var sharedTrips: [SharedTrip] = []
    @State private var locationAddress: String = ""
    @State private var isFetchingAddress: Bool = false

    enum SaveMode: CaseIterable, Hashable { case trip, wishlist }

    // App colour palette (hardcoded — extension can't import main target)
    private static let teal  = Color(red: 0.24, green: 0.75, blue: 0.73)
    private static let dark  = Color(red: 0.08, green: 0.08, blue: 0.08)
    private static let beige = Color(red: 0.961, green: 0.949, blue: 0.918)

    // Category options matching TripItem.ItemCategory
    private let categories: [(label: String, icon: String, raw: String)] = [
        ("Dining",      "fork.knife",     "restaurants"),
        ("Places",      "mappin",         "places"),
        ("Activities",  "ticket",         "paidActivities"),
        ("Free",        "figure.walk",    "freeActivities"),
        ("Stay",        "bed.double",     "accommodation"),
        ("Transport",   "car",            "transportation"),
    ]

    private var relevantTrips: [SharedTrip] {
        sharedTrips.filter { $0.status == "planning" || $0.status == "active" }
    }

    private var canSave: Bool {
        let t = title.trimmingCharacters(in: .whitespaces)
        guard !t.isEmpty || !urlString.isEmpty else { return false }
        if saveMode == .trip { return selectedTripID != nil }
        return true
    }

    init(initialTitle: String, urlString: String,
         onSave: @escaping (PendingShareItem) -> Void,
         onCancel: @escaping () -> Void) {
        self.initialTitle = initialTitle
        self.urlString    = urlString
        self.onSave       = onSave
        self.onCancel     = onCancel
        _title            = State(initialValue: initialTitle)
        let pro           = UserDefaults(suiteName: "group.com.osanuo.Atlas")?.bool(forKey: "atlas_isPro") ?? false
        _isPro            = State(initialValue: pro)
        _saveMode         = State(initialValue: pro ? .trip : .wishlist)
        // Auto-detect category from page title + URL before first render
        _selectedCategory = State(initialValue: Self.detectCategory(title: initialTitle, urlString: urlString))
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    titleSection
                    if !urlString.isEmpty { urlSection }
                    addressSection
                    if isPro {
                        modeToggle
                        if saveMode == .trip {
                            tripSection
                            if selectedTripID != nil {
                                categorySection
                            }
                        }
                    } else {
                        wishlistNote
                        proGateBanner
                    }
                    Spacer().frame(height: 10)
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
            }
            .background(Self.beige)
            bottomBar
        }
        .background(Self.beige.ignoresSafeArea())
        .onAppear { loadTrips() }
        .task { await fetchPageMetadata() }
    }

    // MARK: - Sub-views

    private var header: some View {
        ZStack {
            Self.teal
            Text("Clip to Atlas")
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(.white)
        }
        .frame(height: 52)
    }

    private var titleSection: some View {
        fieldCard(label: "TITLE") {
            TextField("Page title", text: $title)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Self.dark)
        }
    }

    private var urlSection: some View {
        fieldCard(label: "URL") {
            Text(urlString)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
    }

    private var addressSection: some View {
        fieldCard(label: "LOCATION") {
            if isFetchingAddress {
                HStack(spacing: 8) {
                    ProgressView()
                        .scaleEffect(0.75)
                        .tint(Self.teal)
                    Text("Finding address…")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }
            } else {
                TextField("Address / Location (optional)", text: $locationAddress)
                    .font(.system(size: 13))
                    .foregroundStyle(Self.dark)
            }
        }
    }

    private var modeToggle: some View {
        HStack(spacing: 0) {
            ForEach(SaveMode.allCases, id: \.self) { mode in
                let selected = saveMode == mode
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { saveMode = mode }
                } label: {
                    Text(mode == .trip ? "Save to Trip" : "Wishlist")
                        .font(.system(size: 14, weight: selected ? .bold : .regular))
                        .foregroundStyle(selected ? .white : Self.teal)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(selected ? Self.teal : Color.clear)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(Self.teal.opacity(0.15))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    @ViewBuilder
    private var tripSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionLabel("SELECT TRIP")
            if relevantTrips.isEmpty {
                HStack(spacing: 12) {
                    Image(systemName: "airplane.departure")
                        .font(.system(size: 22))
                        .foregroundStyle(Self.teal.opacity(0.5))
                    VStack(alignment: .leading, spacing: 3) {
                        Text("No active trips")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Self.dark)
                        Text("Open Atlas and create a trip first")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .padding(16)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 14))
            } else {
                VStack(spacing: 8) {
                    ForEach(relevantTrips, id: \.id) { trip in
                        tripCard(trip)
                    }
                }
            }
        }
    }

    private func tripCard(_ trip: SharedTrip) -> some View {
        let isSelected = selectedTripID == trip.id
        return Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                selectedTripID = isSelected ? nil : trip.id
            }
        } label: {
            HStack(spacing: 12) {
                // Emoji badge
                Text(trip.emoji.isEmpty ? "✈️" : trip.emoji)
                    .font(.system(size: 20))
                    .frame(width: 42, height: 42)
                    .background((isSelected ? Color.white.opacity(0.25) : Self.teal.opacity(0.1)))
                    .clipShape(Circle())

                // Name + destination
                VStack(alignment: .leading, spacing: 2) {
                    Text(trip.name)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(isSelected ? .white : Self.dark)
                    Text(trip.destination)
                        .font(.system(size: 12))
                        .foregroundStyle(isSelected ? .white.opacity(0.7) : .secondary)
                }

                Spacer()

                // Status pill
                Text(trip.status == "active" ? "Active" : "Planning")
                    .font(.system(size: 10, weight: .semibold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(
                        isSelected
                            ? Color.white.opacity(0.2)
                            : (trip.status == "active"
                                ? Color.green.opacity(0.15)
                                : Color.orange.opacity(0.12))
                    )
                    .foregroundStyle(
                        isSelected
                            ? .white
                            : (trip.status == "active" ? Color.green : Color.orange)
                    )
                    .clipShape(Capsule())

                // Check indicator
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20))
                    .foregroundStyle(isSelected ? .white : Color.gray.opacity(0.35))
            }
            .padding(14)
            .background(isSelected ? Self.teal : Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .shadow(
                color: isSelected ? Self.teal.opacity(0.35) : .black.opacity(0.04),
                radius: isSelected ? 10 : 4, x: 0, y: isSelected ? 4 : 2
            )
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var categorySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionLabel("CATEGORY")
            LazyVGrid(
                columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())],
                spacing: 8
            ) {
                ForEach(categories, id: \.raw) { cat in
                    let isSelected = selectedCategory == cat.raw
                    Button {
                        withAnimation(.easeInOut(duration: 0.15)) { selectedCategory = cat.raw }
                    } label: {
                        VStack(spacing: 5) {
                            Image(systemName: cat.icon)
                                .font(.system(size: 16, weight: .medium))
                                .foregroundStyle(isSelected ? .white : Self.teal)
                            Text(cat.label)
                                .font(.system(size: 11, weight: isSelected ? .semibold : .regular))
                                .foregroundStyle(isSelected ? .white : Self.dark)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(isSelected ? Self.teal : Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .shadow(
                            color: isSelected ? Self.teal.opacity(0.3) : .black.opacity(0.04),
                            radius: isSelected ? 6 : 3, x: 0, y: 2
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var wishlistNote: some View {
        HStack(spacing: 10) {
            Image(systemName: "bookmark.fill")
                .font(.system(size: 14))
                .foregroundStyle(Self.teal)
            Text("This will be saved to your Wishlist")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Self.dark)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Self.teal.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var proGateBanner: some View {
        VStack(spacing: 12) {
            Image(systemName: "sparkles")
                .font(.system(size: 26))
                .foregroundStyle(Self.teal)
            Text("Clip to Trips with Atlas Pro")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(Self.dark)
            Text("With Pro you can clip any web page directly into your trip planning list — restaurants, hotels, activities and more.")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var bottomBar: some View {
        HStack(spacing: 12) {
            Button("Cancel", action: onCancel)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Self.teal)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(Self.teal.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 14))

            Button { commitSave() } label: {
                Text(saveMode == .trip ? "Clip to Trip" : "Save to Wishlist")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(canSave ? .white : Color.white.opacity(0.5))
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(canSave ? Self.teal : Self.teal.opacity(0.35))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .disabled(!canSave)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(Self.beige)
    }

    // MARK: - Helpers

    private func fieldCard<Content: View>(label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            sectionLabel(label)
            content()
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .shadow(color: .black.opacity(0.04), radius: 4, x: 0, y: 2)
        }
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .semibold))
            .kerning(0.8)
            .foregroundStyle(Color.secondary)
    }

    private func loadTrips() {
        guard
            let data = UserDefaults(suiteName: "group.com.osanuo.Atlas")?.data(forKey: "atlas_sharedTrips"),
            let decoded = try? JSONDecoder().decode([SharedTrip].self, from: data)
        else { return }
        sharedTrips = decoded
        // Pre-select first relevant trip
        selectedTripID = relevantTrips.first?.id
    }

    private func commitSave() {
        let trimmed = title.trimmingCharacters(in: .whitespaces)
        let addr    = locationAddress.trimmingCharacters(in: .whitespaces)
        let item = PendingShareItem(
            id:          UUID().uuidString,
            title:       trimmed.isEmpty ? urlString : trimmed,
            urlString:   urlString,
            destination: saveMode == .trip ? "trip" : "wishlist",
            tripID:      saveMode == .trip ? selectedTripID : nil,
            categoryRaw: saveMode == .trip ? selectedCategory : nil,
            dateAdded:   Date(),
            address:     addr.isEmpty ? nil : addr
        )
        onSave(item)
    }

    // MARK: - Category Auto-Detection

    /// Infers a category raw value from page title + URL without any network call.
    private static func detectCategory(title: String, urlString: String) -> String {
        let combined = (title + " " + urlString).lowercased()

        let restaurantTerms = ["restaurant", "café", "cafe", "bistro", "brasserie",
                               "eatery", "dining", "cuisine", "gastronomic",
                               "gastronomique", "trattoria", "osteria", "pizzeria",
                               "sushi", "ramen", "tapas", "boulangerie", "patisserie",
                               "grill", "tavern", "bisto"]
        let hotelTerms      = ["hotel", "hostel", "resort", "lodge",
                               "accommodation", "suites", "auberge", "airbnb"]
        let activityTerms   = ["museum", "musée", "gallery", "galerie",
                               "tour ", "ticket", "concert", "exhibition",
                               "show ", "theatre", "theater", "attraction",
                               "experience", "activity"]

        if restaurantTerms.contains(where: { combined.contains($0) }) { return "restaurants" }
        if hotelTerms.contains(where: { combined.contains($0) })      { return "accommodation" }
        if activityTerms.contains(where: { combined.contains($0) })   { return "paidActivities" }
        return "places"
    }

    // MARK: - Schema.org Address Fetch

    /// Fetches the shared page and extracts a physical address from JSON-LD markup.
    private func fetchPageMetadata() async {
        guard !urlString.isEmpty, let url = URL(string: urlString) else { return }
        await MainActor.run { isFetchingAddress = true }
        defer { Task { @MainActor in isFetchingAddress = false } }

        var request = URLRequest(url: url, timeoutInterval: 7)
        request.setValue(
            "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15",
            forHTTPHeaderField: "User-Agent"
        )

        guard let (data, _) = try? await URLSession.shared.data(for: request),
              let html = String(data: data, encoding: .utf8)
                      ?? String(data: data, encoding: .isoLatin1)
        else { return }

        if let address = extractSchemaOrgAddress(from: html) {
            await MainActor.run { locationAddress = address }
        }
    }

    private func extractSchemaOrgAddress(from html: String) -> String? {
        let pattern = #"<script[^>]+type\s*=\s*["']application/ld\+json["'][^>]*>([\s\S]*?)</script>"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else { return nil }

        let ns      = html as NSString
        let matches = regex.matches(in: html, range: NSRange(location: 0, length: ns.length))

        for match in matches {
            guard match.numberOfRanges > 1 else { continue }
            let r = match.range(at: 1)
            guard r.location != NSNotFound else { continue }
            let jsonStr = ns.substring(with: r)

            guard let jsonData = jsonStr.data(using: .utf8),
                  let obj = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any]
            else { continue }

            // Accept any local-business / place type
            let typeStr = obj["@type"] as? String ?? ""
            let typeArr = (obj["@type"] as? [String]) ?? (typeStr.isEmpty ? [] : [typeStr])
            let placeTypes = ["restaurant", "localbusiness", "foodestablishment",
                              "hotel", "lodgingbusiness", "touristattraction",
                              "museum", "bar", "cafe", "bakery"]
            let isPlace = typeArr.contains(where: { t in
                placeTypes.contains(where: { t.lowercased().contains($0) })
            })
            guard isPlace else { continue }

            if let address = formatAddress(from: obj["address"]) {
                return address
            }
        }
        return nil
    }

    private func formatAddress(from raw: Any?) -> String? {
        guard let raw else { return nil }
        if let str = raw as? String, !str.isEmpty { return str }
        if let dict = raw as? [String: Any] {
            let street   = dict["streetAddress"]   as? String ?? ""
            let locality = dict["addressLocality"]  as? String ?? ""
            let postal   = dict["postalCode"]        as? String ?? ""
            let country  = dict["addressCountry"]    as? String ?? ""
            let parts = [street, postal.isEmpty ? locality : "\(postal) \(locality)", country]
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
            let result = parts.joined(separator: ", ")
            return result.isEmpty ? nil : result
        }
        return nil
    }
}
