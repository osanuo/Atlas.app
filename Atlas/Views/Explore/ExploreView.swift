//
//  ExploreView.swift
//  Atlas
//

import SwiftUI
import SwiftData

// MARK: - Destination Model

private struct Destination: Identifiable {
    let id = UUID()
    let city: String
    let country: String
    let price: Int
    let bestSeason: String
    let imageURL: String
}

// MARK: - Explore View

struct ExploreView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var wishlist: [WishlistDestination]

    @State private var searchText = ""

    private let allDestinations: [Destination] = [
        Destination(city: "SHIBUYA",    country: "Japan",       price: 1240, bestSeason: "Oct–Nov", imageURL: "https://images.unsplash.com/photo-1542051841857-5f90071e7989?auto=format&fit=crop&q=80&w=800"),
        Destination(city: "PARIS",      country: "France",      price: 980,  bestSeason: "Apr–Jun", imageURL: "https://images.unsplash.com/photo-1502602898657-3e91760cbb34?auto=format&fit=crop&q=80&w=800"),
        Destination(city: "REYKJAVIK",  country: "Iceland",     price: 1100, bestSeason: "Sep–Mar", imageURL: "https://images.unsplash.com/photo-1518709268805-4e9042af9f23?auto=format&fit=crop&q=80&w=800"),
        Destination(city: "BALI",       country: "Indonesia",   price: 860,  bestSeason: "May–Sep", imageURL: "https://images.unsplash.com/photo-1537996194471-e657df975ab4?auto=format&fit=crop&q=80&w=800"),
        Destination(city: "NEW YORK",   country: "USA",         price: 1350, bestSeason: "Sep–Nov", imageURL: "https://images.unsplash.com/photo-1496442226666-8d4d0e62e6e9?auto=format&fit=crop&q=80&w=800"),
        Destination(city: "KYOTO",      country: "Japan",       price: 1100, bestSeason: "Mar–May", imageURL: "https://images.unsplash.com/photo-1493976040374-85c8e12f0c0e?auto=format&fit=crop&q=80&w=800"),
        Destination(city: "SANTORINI",  country: "Greece",      price: 1450, bestSeason: "Jun–Sep", imageURL: "https://images.unsplash.com/photo-1570077188670-e3a8d69ac5ff?auto=format&fit=crop&q=80&w=800"),
        Destination(city: "MARRAKECH",  country: "Morocco",     price: 720,  bestSeason: "Mar–May", imageURL: "https://images.unsplash.com/photo-1539020140153-e479b8c22e70?auto=format&fit=crop&q=80&w=800"),
        Destination(city: "BANGKOK",    country: "Thailand",    price: 780,  bestSeason: "Nov–Feb", imageURL: "https://images.unsplash.com/photo-1508009603885-50cf7c579365?auto=format&fit=crop&q=80&w=800"),
        Destination(city: "LISBON",     country: "Portugal",    price: 890,  bestSeason: "Apr–Jun", imageURL: "https://images.unsplash.com/photo-1555881400-74d7acaacd8b?auto=format&fit=crop&q=80&w=800"),
        Destination(city: "CAPE TOWN",  country: "South Africa",price: 1050, bestSeason: "Nov–Feb", imageURL: "https://images.unsplash.com/photo-1580060839134-75a5edca2e99?auto=format&fit=crop&q=80&w=800"),
        Destination(city: "DUBAI",      country: "UAE",         price: 1300, bestSeason: "Nov–Mar", imageURL: "https://images.unsplash.com/photo-1512453979798-5ea266f8880c?auto=format&fit=crop&q=80&w=800"),
    ]

    private var filtered: [Destination] {
        if searchText.isEmpty { return allDestinations }
        return allDestinations.filter {
            $0.city.localizedCaseInsensitiveContains(searchText) ||
            $0.country.localizedCaseInsensitiveContains(searchText)
        }
    }

    // MARK: - Wishlist Helpers

    private func isFavorited(_ destination: Destination) -> Bool {
        wishlist.contains { $0.city.uppercased() == destination.city.uppercased() }
    }

    private func toggleFavorite(_ destination: Destination) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.65)) {
            if let existing = wishlist.first(where: { $0.city.uppercased() == destination.city.uppercased() }) {
                modelContext.delete(existing)
            } else {
                let wish = WishlistDestination(
                    city: destination.city,
                    country: destination.country,
                    notes: "Best season: \(destination.bestSeason)",
                    imageURL: destination.imageURL
                )
                modelContext.insert(wish)
            }
        }
        Haptics.light()
    }

    // MARK: - Body

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                // MARK: Teal Header
                exploreHeader
                    .tealHeader()

                // MARK: Cards
                VStack(spacing: 20) {
                    if filtered.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 36))
                                .foregroundStyle(Color.atlasBlack.opacity(0.2))
                            Text("No destinations match \u{201C}\(searchText)\u{201D}")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(Color.atlasBlack.opacity(0.4))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 60)
                    } else {
                        ForEach(filtered) { dest in
                            ExploreCard(
                                destination: dest,
                                isFavorited: isFavorited(dest),
                                onToggle: { toggleFavorite(dest) }
                            )
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 24)
                .padding(.bottom, 100)
                .background(Color.atlasBeige)
            }
        }
        .background(Color.atlasBeige.ignoresSafeArea())
        .ignoresSafeArea(edges: .top)
    }

    // MARK: - Header

    private var exploreHeader: some View {
        VStack(spacing: 0) {
            Spacer().frame(height: 60)

            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Explore")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundStyle(.white)

                    Text("Discover your next landing.")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.white.opacity(0.65))
                }

                Spacer()

                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.black.opacity(0.1))
                        .frame(width: 52, height: 52)
                    Image(systemName: "globe.western.hemisphere")
                        .font(.system(size: 26))
                        .foregroundStyle(.white)
                }
            }

            Spacer().frame(height: 20)

            // Search bar
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Color.atlasBlack.opacity(0.4))

                TextField("Where to next?", text: $searchText)
                    .font(.system(size: 13, weight: .medium, design: .monospaced))
                    .foregroundStyle(Color.atlasBlack)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(Color.white.opacity(0.9))
            .clipShape(RoundedRectangle(cornerRadius: 16))

            Spacer().frame(height: 24)
        }
        .padding(.horizontal, 20)
    }
}

// MARK: - Explore Card

private struct ExploreCard: View {
    let destination: Destination
    let isFavorited: Bool
    let onToggle: () -> Void

    var body: some View {
        ZStack(alignment: .topTrailing) {
            // Full-bleed image
            AsyncImage(url: URL(string: destination.imageURL)) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                        .frame(height: 280)
                        .clipped()
                case .failure:
                    imagePlaceholder
                case .empty:
                    ZStack {
                        Color.atlasBlack.opacity(0.08)
                        ProgressView()
                            .tint(Color.atlasBlack.opacity(0.3))
                    }
                    .frame(height: 280)
                @unknown default:
                    imagePlaceholder
                }
            }
            .frame(height: 280)

            // Bottom gradient + content overlay
            VStack(spacing: 0) {
                Spacer()
                bottomOverlay
            }
            .frame(height: 280)

            // Price badge — top-right
            Text("~$\(destination.price.formatted())")
                .font(.system(size: 14, weight: .heavy, design: .monospaced))
                .foregroundStyle(Color.atlasBlack)
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .shadow(color: .black.opacity(0.15), radius: 6, x: 0, y: 3)
                .padding([.top, .trailing], 16)
        }
        .frame(height: 280)
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .shadow(color: .black.opacity(0.1), radius: 16, x: 0, y: 8)
    }

    private var imagePlaceholder: some View {
        ZStack {
            Color.atlasBlack.opacity(0.12)
            Image(systemName: "photo")
                .font(.system(size: 32))
                .foregroundStyle(Color.atlasBlack.opacity(0.2))
        }
        .frame(height: 280)
    }

    private var bottomOverlay: some View {
        HStack(alignment: .bottom) {
            // Destination name + season pill
            VStack(alignment: .leading, spacing: 8) {
                FlapBoardView(text: destination.city, fontSize: 22)

                HStack(spacing: 8) {
                    PillBadge(label: "Best: \(destination.bestSeason)", style: .white)

                    Text(destination.country)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white.opacity(0.6))
                        .textCase(.uppercase)
                        .kerning(1.5)
                }
            }

            Spacer()

            // Heart button — saves to Wishlist
            Button(action: onToggle) {
                Image(systemName: isFavorited ? "heart.fill" : "heart")
                    .font(.system(size: 18))
                    .foregroundStyle(isFavorited ? Color.red : Color.white)
                    .frame(width: 44, height: 44)
                    .background(.ultraThinMaterial)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color.white.opacity(0.3), lineWidth: 1))
            }
            .buttonStyle(.plain)
        }
        .padding(20)
        .background(
            LinearGradient(
                colors: [.clear, Color.black.opacity(0.7)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }
}

#Preview {
    ExploreView()
        .modelContainer(for: [WishlistDestination.self], inMemory: true)
}
