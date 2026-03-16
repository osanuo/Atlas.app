//
//  ItemDetailView.swift
//  Atlas
//

import SwiftUI
import SwiftData

struct ItemDetailView: View {
    let item: TripItem

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.openURL) private var openURL
    @Environment(UserProfile.self) private var userProfile

    @State private var showEdit = false
    @State private var showDeleteConfirm = false

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    // MARK: Hero Banner
                    heroBanner

                    // MARK: Content
                    VStack(alignment: .leading, spacing: 0) {
                        titleSection
                            .padding(.horizontal, 20)
                            .padding(.top, 20)

                        if !item.notes.isEmpty {
                            notesSection
                                .padding(.horizontal, 20)
                                .padding(.top, 20)
                        }

                        if !item.url.isEmpty {
                            websiteCard
                                .padding(.horizontal, 20)
                                .padding(.top, 12)
                        }

                        if !item.locationAddress.isEmpty {
                            locationCard
                                .padding(.horizontal, 20)
                                .padding(.top, 12)
                        }

                        if let scheduled = item.scheduledLabel {
                            scheduledSection(label: scheduled)
                                .padding(.horizontal, 20)
                                .padding(.top, 20)
                        }

                        actionButtons
                            .padding(.horizontal, 20)
                            .padding(.top, 28)
                            .padding(.bottom, 40)
                    }
                }
            }
            .background(Color.atlasBeige.ignoresSafeArea())
            .ignoresSafeArea(edges: .top)
            .navigationBarBackButtonHidden(true)
            .overlay(alignment: .topLeading) {
                closeButton
                    .padding(.top, 56)
                    .padding(.leading, 16)
            }
        }
        .sheet(isPresented: $showEdit) {
            AddItemView(trip: item.trip, defaultCategory: item.category, editItem: item)
        }
        .alert("Delete Item", isPresented: $showDeleteConfirm) {
            Button("Delete", role: .destructive) {
                deleteItem()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("\"\(item.title)\" will be permanently removed from this trip.")
        }
    }

    // MARK: - Hero Banner

    private var heroBanner: some View {
        ZStack(alignment: .bottomLeading) {
            // Category color gradient background
            LinearGradient(
                colors: [
                    item.category.accentColor.opacity(0.8),
                    item.category.accentColor.opacity(0.4)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .frame(height: 220)

            // Large category icon watermark
            Image(systemName: item.category.icon)
                .font(.system(size: 110, weight: .ultraLight))
                .foregroundStyle(.white.opacity(0.2))
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(.trailing, 24)
                .padding(.bottom, 20)

            // Booking badge (top-right corner if applicable)
            if item.category.supportsBooking && item.bookingStatus != .notBooked {
                VStack {
                    HStack {
                        Spacer()
                        PillBadge(label: item.bookingStatus.shortLabel, style: item.bookingStatus.pillStyle)
                            .padding(.top, 70)
                            .padding(.trailing, 16)
                    }
                    Spacer()
                }
            }
        }
        .frame(height: 220)
        .clipped()
    }

    // MARK: - Title Section

    private var titleSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Title
            Text(item.title)
                .font(.system(size: 26, weight: .bold))
                .foregroundStyle(Color.atlasBlack)

            // Badges row: category + priority
            HStack(spacing: 8) {
                // Category badge (colored)
                HStack(spacing: 5) {
                    Image(systemName: item.category.icon)
                        .font(.system(size: 11, weight: .semibold))
                    Text(item.category.label)
                        .font(.system(size: 11, weight: .semibold))
                }
                .foregroundStyle(item.category.accentColor)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(item.category.accentColor.opacity(0.12))
                .clipShape(Capsule())

                // Priority badge
                HStack(spacing: 5) {
                    Image(systemName: item.priority.icon)
                        .font(.system(size: 11))
                    Text(item.priority.label)
                        .font(.system(size: 11, weight: .semibold))
                }
                .foregroundStyle(item.priority.accentColor)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(item.priority.accentColor.opacity(0.1))
                .clipShape(Capsule())

                if let price = item.formattedPrice(symbol: userProfile.currencySymbol) {
                    Text(price)
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundStyle(Color.atlasBlack)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.atlasBlack.opacity(0.06))
                        .clipShape(Capsule())
                }
            }
        }
    }

    // MARK: - Notes Section

    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Notes", systemImage: "note.text")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color.atlasBlack.opacity(0.45))
                .textCase(.uppercase)
                .kerning(0.5)

            Text(item.notes)
                .font(.system(size: 15))
                .foregroundStyle(Color.atlasBlack)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Website Card

    private var websiteCard: some View {
        Button {
            if let url = URL(string: item.url.hasPrefix("http") ? item.url : "https://\(item.url)") {
                openURL(url)
                Haptics.light()
            }
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.atlasBlack.opacity(0.06))
                        .frame(width: 40, height: 40)
                    Image(systemName: "link")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(Color.atlasBlack.opacity(0.6))
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Website")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Color.atlasBlack.opacity(0.45))
                        .textCase(.uppercase)
                        .kerning(0.5)
                    Text(item.url)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Color.atlasTeal)
                        .lineLimit(1)
                }

                Spacer()

                Image(systemName: "arrow.up.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.atlasBlack.opacity(0.3))
            }
            .padding(14)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .shadow(color: .black.opacity(0.04), radius: 4, x: 0, y: 2)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Location Card

    private var locationCard: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(hex: "FFB84D").opacity(0.15))
                    .frame(width: 40, height: 40)
                Image(systemName: "mappin.and.ellipse")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(Color(hex: "FFB84D"))
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("Location")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.atlasBlack.opacity(0.45))
                    .textCase(.uppercase)
                    .kerning(0.5)
                Text(item.locationAddress)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color.atlasBlack)
                    .lineLimit(2)
            }

            Spacer()
        }
        .padding(14)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.04), radius: 4, x: 0, y: 2)
    }

    // MARK: - Scheduled Section

    private func scheduledSection(label: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Scheduled", systemImage: "calendar")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color.atlasBlack.opacity(0.45))
                .textCase(.uppercase)
                .kerning(0.5)

            Text(label)
                .font(.system(size: 14, weight: .semibold, design: .monospaced))
                .foregroundStyle(Color.atlasTeal)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.atlasTeal.opacity(0.1))
                .clipShape(Capsule())
        }
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        HStack(spacing: 10) {
            // Edit button
            Button {
                showEdit = true
                Haptics.light()
            } label: {
                Label("Edit", systemImage: "pencil")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.atlasBlack)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(Color.atlasBlack.opacity(0.15), lineWidth: 1.5)
                    )
            }
            .buttonStyle(.plain)

            // Delete button
            Button {
                showDeleteConfirm = true
                Haptics.medium()
            } label: {
                Label("Delete", systemImage: "trash")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.red.opacity(0.8))
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(Color.red.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(Color.red.opacity(0.2), lineWidth: 1.5)
                    )
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Close Button

    private var closeButton: some View {
        Button {
            dismiss()
            Haptics.light()
        } label: {
            Image(systemName: "xmark")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 34, height: 34)
                .background(Color.black.opacity(0.35))
                .clipShape(Circle())
        }
    }

    // MARK: - Delete

    private func deleteItem() {
        if let trip = item.trip,
           let idx = trip.items.firstIndex(where: { $0.id == item.id }) {
            trip.items.remove(at: idx)
        }
        modelContext.delete(item)
        Haptics.success()
        dismiss()
    }
}

#Preview {
    let item = TripItem(
        title: "Ramen Ichiran",
        category: .restaurants,
        notes: "Best tonkotsu ramen in Tokyo. Solo dining booths. Open 24/7.",
        url: "https://ichiran.com",
        locationAddress: "1-22-7 Jinnan, Shibuya, Tokyo",
        price: 18,
        priority: .mustDo
    )
    ItemDetailView(item: item)
        .modelContainer(for: [Trip.self, TripItem.self, CrewMember.self, Expense.self, WishlistDestination.self, VisitedLocation.self], inMemory: true)
}
