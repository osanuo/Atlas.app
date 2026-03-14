//
//  ExploreView.swift
//  Atlas
//

import SwiftUI

// MARK: - Destination Model

private struct Destination: Identifiable {
    let id = UUID()
    let city: String
    let country: String
    let price: Int
    let bestSeason: String
    let imageURL: String
    var isFavorited: Bool = false
}

// MARK: - Explore View

struct ExploreView: View {
    @State private var searchText = ""
    @State private var destinations: [Destination] = [
        Destination(
            city: "SHIBUYA",
            country: "Japan",
            price: 1240,
            bestSeason: "Oct-Nov",
            imageURL: "https://images.unsplash.com/photo-1542051841857-5f90071e7989?auto=format&fit=crop&q=80&w=800"
        ),
        Destination(
            city: "PARIS",
            country: "France",
            price: 980,
            bestSeason: "Apr-Jun",
            imageURL: "https://images.unsplash.com/photo-1502602898657-3e91760cbb34?auto=format&fit=crop&q=80&w=800"
        ),
        Destination(
            city: "REYKJAVIK",
            country: "Iceland",
            price: 1100,
            bestSeason: "Sep-Mar",
            imageURL: "https://images.unsplash.com/photo-1518709268805-4e9042af9f23?auto=format&fit=crop&q=80&w=800"
        ),
    ]

    /// Indices into `destinations` that match the current search text.
    /// Using indices (not a filtered copy) preserves the `@Binding` needed by ExploreCard.
    private var filteredIndices: [Int] {
        if searchText.isEmpty { return Array(destinations.indices) }
        return destinations.indices.filter {
            destinations[$0].city.localizedCaseInsensitiveContains(searchText) ||
            destinations[$0].country.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                // MARK: Teal Header
                exploreHeader
                    .tealHeader()

                // MARK: Cards
                VStack(spacing: 20) {
                    if filteredIndices.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 36))
                                .foregroundStyle(Color.atlasBlack.opacity(0.2))
                            Text("No destinations match "\(searchText)"")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(Color.atlasBlack.opacity(0.4))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 60)
                    } else {
                        ForEach(filteredIndices, id: \.self) { i in
                            ExploreCard(destination: $destinations[i])
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
    @Binding var destination: Destination

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
                case .failure(_):
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
            Text("$\(destination.price.formatted())")
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

            // Heart button (frosted glass)
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.65)) {
                    destination.isFavorited.toggle()
                    Haptics.light()
                }
            } label: {
                Image(systemName: destination.isFavorited ? "heart.fill" : "heart")
                    .font(.system(size: 18))
                    .foregroundStyle(destination.isFavorited ? Color.red : Color.white)
                    .frame(width: 44, height: 44)
                    .background(.ultraThinMaterial)
                    .clipShape(Circle())
                    .overlay(
                        Circle().stroke(Color.white.opacity(0.3), lineWidth: 1)
                    )
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
}
