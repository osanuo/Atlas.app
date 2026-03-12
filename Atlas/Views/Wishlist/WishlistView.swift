//
//  WishlistView.swift
//  Atlas
//

import SwiftUI
import SwiftData
import PhotosUI

// MARK: - Wishlist View

struct WishlistView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \WishlistDestination.dateAdded, order: .reverse)
    private var destinations: [WishlistDestination]

    @State private var showAddDestination = false
    @State private var planningDestination: WishlistDestination? = nil
    @State private var searchText = ""

    private var filtered: [WishlistDestination] {
        if searchText.isEmpty { return destinations }
        return destinations.filter {
            $0.city.localizedCaseInsensitiveContains(searchText) ||
            $0.country.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {

                // Teal header
                wishlistHeader
                    .tealHeader()

                // Content
                VStack(spacing: 20) {
                    if filtered.isEmpty {
                        emptyState
                    } else {
                        ForEach(filtered) { destination in
                            WishlistCard(
                                destination: destination,
                                onPlanTrip: { planningDestination = destination },
                                onMarkVisited: {
                                    withAnimation {
                                        destination.isVisited.toggle()
                                        Haptics.light()
                                    }
                                },
                                onDelete: {
                                    withAnimation {
                                        modelContext.delete(destination)
                                        Haptics.light()
                                    }
                                }
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
        .scrollDismissesKeyboard(.interactively)
        .overlay(alignment: .bottomTrailing) {
            Button {
                showAddDestination = true
                Haptics.medium()
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 56, height: 56)
                    .background(Color.atlasBlack)
                    .clipShape(Circle())
                    .shadow(color: .black.opacity(0.25), radius: 8, x: 0, y: 4)
            }
            .padding(.trailing, 24)
            .padding(.bottom, 100)
        }
        .sheet(isPresented: $showAddDestination) {
            AddWishlistDestinationView()
                .presentationDetents([.large])
                .presentationDragIndicator(.hidden)
        }
        .sheet(item: $planningDestination) { destination in
            NewTripView(initialDestination: destination.city)
                .presentationDetents([.large])
                .presentationDragIndicator(.hidden)
        }
    }

    // MARK: - Header

    private var wishlistHeader: some View {
        VStack(spacing: 0) {
            Spacer().frame(height: 60)

            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Wishlist")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundStyle(.white)
                    Text("Dream. Plan. Explore.")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.white.opacity(0.65))
                }

                Spacer()

                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.black.opacity(0.1))
                        .frame(width: 52, height: 52)
                    Image(systemName: "heart.text.square")
                        .font(.system(size: 24))
                        .foregroundStyle(.white)
                }
            }

            Spacer().frame(height: 20)

            // Search bar
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Color.atlasBlack.opacity(0.4))
                TextField("Search destinations...", text: $searchText)
                    .font(.system(size: 13, weight: .medium, design: .monospaced))
                    .foregroundStyle(Color.atlasBlack)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(Color.white.opacity(0.9))
            .clipShape(RoundedRectangle(cornerRadius: 16))

            // Stats row
            if !destinations.isEmpty {
                Spacer().frame(height: 14)
                HStack(spacing: 16) {
                    Label("\(destinations.count) saved", systemImage: "bookmark.fill")
                    Spacer()
                    Label("\(destinations.filter { $0.isVisited }.count) visited", systemImage: "checkmark.seal.fill")
                }
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.white.opacity(0.7))
            }

            Spacer().frame(height: 24)
        }
        .padding(.horizontal, 20)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 20) {
            Spacer().frame(height: 20)

            ZStack {
                Circle()
                    .fill(Color.atlasTeal.opacity(0.08))
                    .frame(width: 100, height: 100)
                Image(systemName: "heart.text.square")
                    .font(.system(size: 44, weight: .ultraLight))
                    .foregroundStyle(Color.atlasTeal.opacity(0.4))
            }

            VStack(spacing: 8) {
                Text("Your wishlist is empty")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(Color.atlasBlack)
                Text("Tap + to add dream destinations\nand plan your next adventure.")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.atlasBlack.opacity(0.45))
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
            }

            Spacer().frame(height: 20)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Wishlist Card

private struct WishlistCard: View {
    let destination: WishlistDestination
    let onPlanTrip: () -> Void
    let onMarkVisited: () -> Void
    let onDelete: () -> Void

    var body: some View {
        ZStack(alignment: .topTrailing) {
            // Background image or gradient placeholder
            Group {
                if let data = destination.imageData, let uiImage = UIImage(data: data) {
                    // Local photo from device
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                } else if destination.imageURL.isEmpty {
                    destinationPlaceholder
                } else {
                    AsyncImage(url: URL(string: destination.imageURL)) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFill()
                        case .failure:
                            destinationPlaceholder
                        case .empty:
                            ZStack {
                                Color.atlasBlack.opacity(0.08)
                                ProgressView().tint(Color.atlasBlack.opacity(0.3))
                            }
                        @unknown default:
                            destinationPlaceholder
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, minHeight: 260, maxHeight: 260)
            .clipped()

            // Bottom overlay
            VStack(spacing: 0) {
                Spacer()
                bottomOverlay
            }
            .frame(maxWidth: .infinity, minHeight: 260, maxHeight: 260)

            // Visited badge / heart
            visitedBadge
                .padding([.top, .trailing], 14)
        }
        .frame(maxWidth: .infinity, minHeight: 260, maxHeight: 260)
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .shadow(color: .black.opacity(0.1), radius: 16, x: 0, y: 8)
        .contextMenu {
            Button(action: onPlanTrip) {
                Label("Start Planning", systemImage: "airplane.departure")
            }
            Button(action: onMarkVisited) {
                Label(destination.isVisited ? "Mark as Not Visited" : "Mark as Visited",
                      systemImage: destination.isVisited ? "xmark.circle" : "checkmark.seal")
            }
            Divider()
            Button(role: .destructive, action: onDelete) {
                Label("Remove from Wishlist", systemImage: "trash")
            }
        }
    }

    private var destinationPlaceholder: some View {
        ZStack {
            LinearGradient(
                colors: [Color.atlasTeal.opacity(0.6), Color.atlasBlack.opacity(0.8)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Image(systemName: "globe.desk")
                .font(.system(size: 52, weight: .ultraLight))
                .foregroundStyle(.white.opacity(0.2))
        }
    }

    private var visitedBadge: some View {
        Group {
            if destination.isVisited {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 12))
                    Text("VISITED")
                        .font(.system(size: 10, weight: .bold))
                        .kerning(1)
                }
                .foregroundStyle(Color.atlasTeal)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(.ultraThinMaterial)
                .clipShape(Capsule())
            } else {
                Button(action: onMarkVisited) {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(Color.red)
                        .frame(width: 40, height: 40)
                        .background(.ultraThinMaterial)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Color.white.opacity(0.3), lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var bottomOverlay: some View {
        HStack(alignment: .bottom, spacing: 12) {
            // Left column: city tiles + country/notes — always anchored to leading edge
            VStack(alignment: .leading, spacing: 6) {
                FlapBoardView(text: destination.city, fontSize: 22)

                HStack(spacing: 6) {
                    Text(destination.country)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white.opacity(0.7))
                        .textCase(.uppercase)
                        .kerning(1.5)
                        .lineLimit(1)

                    if !destination.notes.isEmpty {
                        Text("·")
                            .font(.system(size: 11))
                            .foregroundStyle(.white.opacity(0.4))
                        Text(destination.notes)
                            .font(.system(size: 11))
                            .foregroundStyle(.white.opacity(0.6))
                            .lineLimit(1)
                    }
                }
            }
            // Takes all remaining space after the button; FlapBoard is always at the left
            .frame(maxWidth: .infinity, alignment: .leading)

            // Right column: Plan Trip button — fixed intrinsic size, never compressed
            if !destination.isVisited {
                Button(action: onPlanTrip) {
                    HStack(spacing: 6) {
                        Text("Plan Trip")
                            .font(.system(size: 12, weight: .bold))
                        Image(systemName: "arrow.right")
                            .font(.system(size: 11, weight: .bold))
                    }
                    .foregroundStyle(Color.atlasBlack)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Color.white)
                    .clipShape(Capsule())
                    .shadow(color: .black.opacity(0.15), radius: 4, x: 0, y: 2)
                }
                .buttonStyle(.plain)
                .fixedSize()  // Button always renders at its natural width
            }
        }
        .padding(18)
        .background(
            LinearGradient(
                colors: [.clear, Color.black.opacity(0.75)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }
}

// MARK: - Add Wishlist Destination View

struct AddWishlistDestinationView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var city = ""
    @State private var country = ""
    @State private var notes = ""
    @State private var selectedPhoto: PhotosPickerItem? = nil
    @State private var selectedImageData: Data? = nil
    @State private var previewImage: Image? = nil

    private var isValid: Bool {
        !city.trimmingCharacters(in: .whitespaces).isEmpty &&
        !country.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        VStack(spacing: 0) {
            // Teal header
            ZStack {
                Color.atlasTeal
                HStack {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 32, height: 32)
                            .background(Color.white.opacity(0.2))
                            .clipShape(Circle())
                    }
                    Spacer()
                    Text("Add Destination")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(.white)
                    Spacer()
                    Color.clear.frame(width: 32, height: 32)
                }
                .padding(.horizontal, 20)
            }
            .frame(height: 56)

            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    Spacer().frame(height: 8)

                    // City (dark tile)
                    VStack(spacing: 8) {
                        Text("City / Destination")
                            .atlasLabel()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.leading, 4)

                        ZStack {
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color(hex: "222222"))
                                .shadow(color: .black.opacity(0.2), radius: 6, x: 0, y: 3)
                            VStack(spacing: 0) {
                                Color.clear.frame(height: 26)
                                Rectangle()
                                    .fill(Color.black.opacity(0.5))
                                    .frame(height: 1)
                                Color.clear.frame(height: 26)
                            }
                            TextField("", text: $city)
                                .font(.system(size: 22, weight: .semibold, design: .monospaced))
                                .foregroundStyle(Color.white)
                                .multilineTextAlignment(.center)
                                .textInputAutocapitalization(.characters)
                                .autocorrectionDisabled()
                                .padding(.horizontal, 20)
                                .placeholder(when: city.isEmpty) {
                                    Text("CITY NAME")
                                        .font(.system(size: 22, weight: .semibold, design: .monospaced))
                                        .foregroundStyle(Color.white.opacity(0.3))
                                }
                        }
                        .frame(height: 70)
                    }

                    // Country
                    VStack(spacing: 8) {
                        Text("Country")
                            .atlasLabel()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.leading, 4)

                        TextField("", text: $country, prompt:
                            Text("e.g. Japan").foregroundStyle(Color.atlasBlack.opacity(0.35))
                        )
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(Color.atlasBlack)
                        .padding(16)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .shadow(color: .black.opacity(0.04), radius: 4, x: 0, y: 2)
                    }

                    // Notes
                    VStack(spacing: 8) {
                        Text("Why I want to go (Optional)")
                            .atlasLabel()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.leading, 4)

                        TextField("", text: $notes, prompt:
                            Text("e.g. Cherry blossoms in spring...").foregroundStyle(Color.atlasBlack.opacity(0.35)),
                            axis: .vertical
                        )
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(Color.atlasBlack)
                        .lineLimit(3, reservesSpace: true)
                        .padding(16)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .shadow(color: .black.opacity(0.04), radius: 4, x: 0, y: 2)
                    }

                    // Cover photo picker (optional)
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Cover Photo (Optional)")
                            .atlasLabel()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.leading, 4)

                        PhotosPicker(
                            selection: $selectedPhoto,
                            matching: .images,
                            photoLibrary: .shared()
                        ) {
                            HStack(spacing: 14) {
                                // Thumbnail preview or placeholder
                                Group {
                                    if let image = previewImage {
                                        image
                                            .resizable()
                                            .scaledToFill()
                                            .frame(width: 56, height: 56)
                                            .clipShape(RoundedRectangle(cornerRadius: 10))
                                    } else {
                                        RoundedRectangle(cornerRadius: 10)
                                            .fill(Color.atlasBlack.opacity(0.07))
                                            .frame(width: 56, height: 56)
                                            .overlay(
                                                Image(systemName: "photo.badge.plus")
                                                    .font(.system(size: 20))
                                                    .foregroundStyle(Color.atlasBlack.opacity(0.3))
                                            )
                                    }
                                }

                                VStack(alignment: .leading, spacing: 3) {
                                    Text(selectedImageData != nil ? "Photo selected" : "Choose from library")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundStyle(Color.atlasBlack)
                                    Text("Tap to browse your photos")
                                        .font(.system(size: 12))
                                        .foregroundStyle(Color.atlasBlack.opacity(0.4))
                                }

                                Spacer()

                                if selectedImageData != nil {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 20))
                                        .foregroundStyle(Color.atlasTeal)
                                } else {
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundStyle(Color.atlasBlack.opacity(0.25))
                                }
                            }
                            .padding(14)
                            .background(Color.white)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .shadow(color: .black.opacity(0.04), radius: 4, x: 0, y: 2)
                        }
                        .buttonStyle(.plain)
                        .onChange(of: selectedPhoto) { _, newItem in
                            Task {
                                if let newItem,
                                   let data = try? await newItem.loadTransferable(type: Data.self),
                                   let uiImage = UIImage(data: data) {
                                    selectedImageData = data
                                    previewImage = Image(uiImage: uiImage)
                                } else {
                                    selectedImageData = nil
                                    previewImage = nil
                                }
                            }
                        }

                        // Remove button — only visible after selection
                        if selectedImageData != nil {
                            Button {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    selectedPhoto = nil
                                    selectedImageData = nil
                                    previewImage = nil
                                }
                            } label: {
                                HStack(spacing: 5) {
                                    Image(systemName: "xmark")
                                        .font(.system(size: 9, weight: .bold))
                                    Text("Remove photo")
                                        .font(.system(size: 12, weight: .medium))
                                }
                                .foregroundStyle(Color.atlasBlack.opacity(0.4))
                            }
                            .buttonStyle(.plain)
                            .padding(.leading, 4)
                            .transition(.opacity)
                        }
                    }

                    // Save button
                    Button { saveDestination() } label: {
                        HStack(spacing: 10) {
                            Text("ADD TO WISHLIST")
                                .font(.system(size: 14, weight: .bold))
                                .kerning(1)
                            Image(systemName: "heart.fill")
                                .font(.system(size: 14, weight: .bold))
                        }
                        .foregroundStyle(isValid ? .white : Color.white.opacity(0.4))
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(isValid ? Color.atlasBlack : Color.atlasBlack.opacity(0.3))
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                    .buttonStyle(ScaleButtonStyle())
                    .disabled(!isValid)

                    Spacer().frame(height: 40)
                }
                .padding(.horizontal, 20)
            }
        }
        .background(Color.atlasBeige.ignoresSafeArea())
    }

    private func saveDestination() {
        guard isValid else { return }
        let destination = WishlistDestination(
            city: city.trimmingCharacters(in: .whitespaces),
            country: country.trimmingCharacters(in: .whitespaces),
            notes: notes.trimmingCharacters(in: .whitespaces),
            imageData: selectedImageData
        )
        modelContext.insert(destination)
        Haptics.success()
        dismiss()
    }
}

#Preview {
    WishlistView()
        .modelContainer(for: WishlistDestination.self, inMemory: true)
}
