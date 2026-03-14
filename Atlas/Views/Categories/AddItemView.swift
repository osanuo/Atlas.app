//
//  AddItemView.swift
//  Atlas
//

import SwiftUI
import SwiftData
import CloudKit

struct AddItemView: View {
    let trip: Trip?
    var defaultCategory: ItemCategory = .restaurants
    var editItem: TripItem? = nil

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(UserProfile.self) private var userProfile

    @State private var title = ""
    @State private var selectedCategory: ItemCategory
    @State private var notes = ""
    @State private var url = ""
    @State private var locationAddress = ""
    @State private var priceText = ""
    @State private var priority: ItemPriority = .niceToHave
    @State private var bookingStatus: BookingStatus = .notBooked

    init(trip: Trip?, defaultCategory: ItemCategory = .restaurants, editItem: TripItem? = nil) {
        self.trip = trip
        self.defaultCategory = defaultCategory
        self.editItem = editItem
        _selectedCategory = State(initialValue: editItem?.category ?? defaultCategory)
    }

    var isEditing: Bool { editItem != nil }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Item Name", text: $title)
                        .font(.system(size: 16, weight: .semibold))
                }

                Section("Category") {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(ItemCategory.allCases, id: \.rawValue) { cat in
                                CategoryChip(
                                    category: cat,
                                    isSelected: selectedCategory == cat
                                ) {
                                    selectedCategory = cat
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                }

                Section("Details") {
                    TextField("Notes", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                    TextField("Website / Link", text: $url)
                        .keyboardType(.URL)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                    TextField("Address / Location", text: $locationAddress)
                        .autocorrectionDisabled()
                    HStack {
                        Text(userProfile.currencySymbol)
                            .foregroundStyle(Color.secondary)
                        TextField("Price (optional)", text: $priceText)
                            .keyboardType(.decimalPad)
                    }
                }

                Section("Priority") {
                    Picker("Priority", selection: $priority) {
                        ForEach(ItemPriority.allCases, id: \.rawValue) { p in
                            Text(p.label).tag(p)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                if selectedCategory.supportsBooking {
                    Section("Booking Status") {
                        Picker("Status", selection: $bookingStatus) {
                            ForEach(BookingStatus.allCases, id: \.rawValue) { s in
                                Label(s.label, systemImage: bookingIcon(s))
                                    .tag(s)
                            }
                        }
                        .pickerStyle(.menu)
                    }
                }
            }
            .navigationTitle(isEditing ? "Edit Item" : "Add Item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isEditing ? "Save" : "Add") {
                        saveItem()
                    }
                    .fontWeight(.semibold)
                    .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear {
                if let item = editItem {
                    title           = item.title
                    notes           = item.notes
                    url             = item.url
                    locationAddress = item.locationAddress
                    priority        = item.priority
                    bookingStatus   = item.bookingStatus
                    if let p = item.price { priceText = String(p) }
                }
            }
        }
    }

    private func saveItem() {
        let cleanTitle = title.trimmingCharacters(in: .whitespaces)
        guard !cleanTitle.isEmpty else { return }

        let price = Double(priceText.replacingOccurrences(of: ",", with: "."))

        if let item = editItem {
            // Update existing
            item.title           = cleanTitle
            item.category        = selectedCategory
            item.notes           = notes
            item.url             = url
            item.locationAddress = locationAddress
            item.price           = price
            item.priority        = priority
            item.bookingStatus   = bookingStatus
            // Sync edit to CloudKit if trip is shared
            if let trip, trip.isShared {
                Task { try? await CloudKitSharingManager.shared.syncItem(item, in: trip) }
            }
        } else {
            // Create new
            let newItem = TripItem(
                title: cleanTitle,
                category: selectedCategory,
                notes: notes,
                url: url,
                locationAddress: locationAddress,
                price: price,
                priority: priority,
                bookingStatus: bookingStatus,
                trip: trip
            )
            // Set attribution for shared trips
            if let trip, trip.isShared {
                newItem.addedByName   = userProfile.displayName
                newItem.addedByUserID = userProfile.iCloudUserRecordID ?? ""
            }
            modelContext.insert(newItem)
            if let trip {
                trip.items.append(newItem)
                // Sync new item to CloudKit if trip is shared
                if trip.isShared {
                    Task { try? await CloudKitSharingManager.shared.syncItem(newItem, in: trip) }
                }
            }
        }

        Haptics.success()
        dismiss()
    }

    private func bookingIcon(_ status: BookingStatus) -> String {
        switch status {
        case .notBooked:  return "circle.dashed"
        case .pending:    return "clock"
        case .confirmed:  return "checkmark.seal.fill"
        case .cancelled:  return "xmark.circle"
        }
    }
}

// MARK: - Category Chip

private struct CategoryChip: View {
    let category: ItemCategory
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: category.icon)
                    .font(.system(size: 12))
                Text(category.label)
                    .font(.system(size: 12, weight: .semibold))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(isSelected ? category.accentColor : Color.atlasBlack.opacity(0.06))
            .foregroundStyle(isSelected ? .white : Color.atlasBlack)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    AddItemView(trip: nil, defaultCategory: .restaurants)
}
