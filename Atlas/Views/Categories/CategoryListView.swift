//
//  CategoryListView.swift
//  Atlas
//

import SwiftUI
import SwiftData

struct CategoryListView: View {
    let trip: Trip
    let category: ItemCategory

    @Environment(\.modelContext) private var modelContext
    @State private var showAddItem = false

    private var items: [TripItem] {
        trip.items
            .filter { $0.category == category }
            .sorted { !$0.isCompleted && $1.isCompleted }
    }

    var body: some View {
        VStack(spacing: 0) {
            if items.isEmpty {
                emptyState
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(items) { item in
                        TripItemRow(item: item, showAttribution: trip.isShared)
                    }
                }
            }
        }
        .sheet(isPresented: $showAddItem) {
            AddItemView(trip: trip, defaultCategory: category)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: category.icon)
                .font(.system(size: 36))
                .foregroundStyle(category.accentColor.opacity(0.4))
            Text("No \(category.label.lowercased()) yet")
                .font(.system(size: 15))
                .foregroundStyle(Color.atlasBlack.opacity(0.4))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 48)
    }
}

// MARK: - Trip Item Row

struct TripItemRow: View {
    let item: TripItem
    var showAttribution: Bool = false
    @Environment(\.modelContext) private var modelContext
    @Environment(UserProfile.self) private var userProfile
    @State private var showDetail = false

    var body: some View {
        Button {
            showDetail = true
            Haptics.light()
        } label: {
            HStack(spacing: 14) {
                // Leading checkbox — completion toggle
                Button {
                    withAnimation(.spring(response: 0.3)) {
                        item.isCompleted.toggle()
                        Haptics.light()
                    }
                } label: {
                    Image(systemName: item.isCompleted ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 22))
                        .foregroundStyle(item.isCompleted ? Color.statusGreen : Color.atlasBlack.opacity(0.25))
                }
                .buttonStyle(.plain)

                // Category accent bar
                Rectangle()
                    .fill(item.category.accentColor)
                    .frame(width: 3, height: 36)
                    .clipShape(Capsule())

                // Content
                VStack(alignment: .leading, spacing: 3) {
                    Text(item.title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(item.isCompleted ? Color.atlasBlack.opacity(0.4) : Color.atlasBlack)
                        .strikethrough(item.isCompleted)

                    if !item.notes.isEmpty {
                        Text(item.notes)
                            .font(.system(size: 12))
                            .foregroundStyle(Color.atlasBlack.opacity(0.45))
                            .lineLimit(1)
                    }
                    if showAttribution && !item.addedByName.isEmpty {
                        Text("by \(item.addedByName)")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.atlasTeal.opacity(0.75))
                            .clipShape(Capsule())
                    }
                }

                Spacer()

                // Price badge
                if let price = item.formattedPrice(symbol: userProfile.currencySymbol) {
                    Text(price)
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .foregroundStyle(Color.atlasBlack.opacity(0.6))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.atlasBlack.opacity(0.06))
                        .clipShape(Capsule())
                }

                // Chevron hint
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.atlasBlack.opacity(0.2))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .shadow(color: .black.opacity(0.04), radius: 4, x: 0, y: 2)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Color.black.opacity(0.04), lineWidth: 1)
            )
            .opacity(item.isCompleted ? 0.7 : 1.0)
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showDetail) {
            ItemDetailView(item: item)
        }
    }
}
