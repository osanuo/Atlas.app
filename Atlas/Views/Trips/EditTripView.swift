//
//  EditTripView.swift
//  Atlas
//

import SwiftUI
import SwiftData
import CoreLocation

struct EditTripView: View {
    let trip: Trip

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(UserProfile.self) private var userProfile

    @State private var destination: String
    @State private var country: String
    @State private var destinationFlag: String
    @State private var tripName: String
    @State private var notes: String
    @State private var startDate: Date
    @State private var endDate: Date
    @State private var travelerCount: Int
    @State private var budget: String
    @State private var selectedColorHex: String

    @State private var showStartPicker   = false
    @State private var showEndPicker     = false
    @State private var showDeleteConfirm  = false
    @State private var showArchiveConfirm = false
    @State private var showFlagPicker    = false

    @FocusState private var budgetFocused: Bool

    private static let colorPalette = [
        ("FCDA85", "Gold"),
        ("FFFFFF", "White"),
        ("EBCFDA", "Rose"),
        ("5499E8", "Sky")
    ]

    private var dateFormatter: DateFormatter {
        let f = DateFormatter()
        f.dateFormat = "MMM dd"
        return f
    }

    private var isValid: Bool {
        !destination.trimmingCharacters(in: .whitespaces).isEmpty && endDate > startDate
    }

    init(trip: Trip) {
        self.trip = trip
        _destination      = State(initialValue: trip.destination)
        _country          = State(initialValue: trip.country)
        _destinationFlag  = State(initialValue: trip.destinationFlag)
        _tripName         = State(initialValue: trip.name)
        _notes            = State(initialValue: trip.notes)
        _startDate        = State(initialValue: trip.startDate)
        _endDate          = State(initialValue: trip.endDate)
        _travelerCount    = State(initialValue: trip.travelerCount)
        _budget           = State(initialValue: trip.budget.map { String(Int($0)) } ?? "")
        _selectedColorHex = State(initialValue: trip.cardColorHex)
    }

    var body: some View {
        VStack(spacing: 0) {
            // MARK: Teal Header
            headerBar

            // MARK: Form
            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    Spacer().frame(height: 8)

                    // Destination input
                    destinationField

                    // Country
                    countryField

                    // Trip name
                    nameField

                    // Notes
                    notesField

                    // Date pickers
                    dateRow

                    // Traveler counter
                    travelerSection

                    // Budget
                    budgetField

                    // Card color picker
                    colorPickerSection

                    // Status picker
                    statusSection

                    Spacer().frame(height: 8)

                    // Save button
                    saveButton

                    // Danger zone
                    dangerZone

                    Spacer().frame(height: 40)
                }
                .padding(.horizontal, 20)
            }
        }
        .background(Color.atlasBeige.ignoresSafeArea())
        .sheet(isPresented: $showStartPicker) {
            DatePickerSheet(title: "Departure", date: $startDate)
        }
        .sheet(isPresented: $showEndPicker) {
            DatePickerSheet(title: "Return", date: $endDate)
        }
        .sheet(isPresented: $showFlagPicker) {
            FlagPickerSheet(selectedFlag: $destinationFlag)
        }
        .onChange(of: country) { _, newCountry in
            if let detected = flagEmoji(fromCountryName: newCountry) {
                destinationFlag = detected
            }
        }
        .alert("Delete Trip", isPresented: $showDeleteConfirm) {
            Button("Delete", role: .destructive) { deleteTrip() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("\"\(trip.name)\" and all its items will be permanently removed. This cannot be undone.")
        }
        .alert("Archive Trip", isPresented: $showArchiveConfirm) {
            Button("Archive") { archiveTrip() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("\"\(trip.name)\" will be moved to Past Trips.")
        }
    }

    // MARK: - Header Bar

    private var headerBar: some View {
        ZStack {
            Color.atlasTeal

            HStack {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 32, height: 32)
                        .background(Color.white.opacity(0.2))
                        .clipShape(Circle())
                }

                Spacer()

                Text("Edit Trip")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.white)

                Spacer()

                Color.clear.frame(width: 32, height: 32)
            }
            .padding(.horizontal, 20)
        }
        .frame(height: 56)
    }

    // MARK: - Destination Field

    private var destinationField: some View {
        VStack(spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(hex: "222222"))
                    .shadow(color: .black.opacity(0.2), radius: 6, x: 0, y: 3)

                VStack(spacing: 0) {
                    Color.clear.frame(height: 34)
                    Rectangle()
                        .fill(Color.black.opacity(0.5))
                        .frame(height: 1)
                    Color.clear.frame(height: 34)
                }

                TextField("", text: $destination)
                    .font(.system(size: 22, weight: .semibold, design: .monospaced))
                    .foregroundStyle(Color.white)
                    .multilineTextAlignment(.center)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                    .placeholder(when: destination.isEmpty) {
                        Text("DESTINATION")
                            .font(.system(size: 22, weight: .semibold, design: .monospaced))
                            .foregroundStyle(Color.white.opacity(0.3))
                    }
            }
            .frame(height: 70)

            Text("DESTINATION CODE")
                .atlasLabel()
                .frame(maxWidth: .infinity)
        }
    }

    // MARK: - Country + Flag Field

    private var countryField: some View {
        VStack(spacing: 8) {
            Text("Country & Flag")
                .atlasLabel()
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, 4)

            HStack(spacing: 10) {
                // Flag button
                Button { showFlagPicker = true } label: {
                    Text(destinationFlag)
                        .font(.system(size: 28))
                        .frame(width: 52, height: 52)
                        .background(Color.white.opacity(0.7))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .shadow(color: .black.opacity(0.06), radius: 4, x: 0, y: 2)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(Color.black.opacity(0.06), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)

                TextField("", text: $country, prompt:
                    Text("e.g. Japan").foregroundStyle(Color.atlasBlack.opacity(0.35))
                )
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Color.atlasBlack)
                .autocorrectionDisabled()
                .padding(16)
                .background(Color.white.opacity(0.7))
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
        }
    }

    // MARK: - Trip Name Field

    private var nameField: some View {
        VStack(spacing: 8) {
            Text("Trip Name")
                .atlasLabel()
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, 4)

            HStack {
                Image(systemName: "tag")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.atlasBlack.opacity(0.4))
                TextField("e.g. Tokyo Adventure", text: $tripName)
                    .font(.system(size: 15, weight: .medium))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(Color.white.opacity(0.7))
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
    }

    // MARK: - Notes Field

    private var notesField: some View {
        VStack(spacing: 8) {
            Text("Notes (Optional)")
                .atlasLabel()
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, 4)

            HStack(alignment: .top) {
                Image(systemName: "note.text")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.atlasBlack.opacity(0.4))
                    .padding(.top, 2)
                TextField("Trip notes, reminders, packing ideas…", text: $notes, axis: .vertical)
                    .font(.system(size: 15, weight: .medium))
                    .lineLimit(3...6)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(Color.white.opacity(0.7))
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
    }

    // MARK: - Date Row

    private var dateRow: some View {
        HStack(spacing: 12) {
            dateTile(label: "Departure", date: startDate) { showStartPicker = true }
            dateTile(label: "Return",    date: endDate)   { showEndPicker   = true }
        }
    }

    private func dateTile(label: String, date: Date, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(hex: "222222"))

                VStack(spacing: 0) {
                    Color.clear.frame(height: 26)
                    Rectangle()
                        .fill(Color.black.opacity(0.5))
                        .frame(height: 1)
                    Color.clear.frame(height: 26)
                }

                VStack(spacing: 6) {
                    Text(label.uppercased())
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundStyle(Color.white.opacity(0.4))
                        .kerning(1)
                    Text(dateFormatter.string(from: date).uppercased())
                        .font(.system(size: 18, weight: .semibold, design: .monospaced))
                        .foregroundStyle(Color.white)
                }
            }
            .frame(height: 70)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Traveler Counter

    private var travelerSection: some View {
        VStack(spacing: 8) {
            Text("Traveler Manifest")
                .atlasLabel()
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, 4)

            HStack(spacing: 0) {
                Button {
                    if travelerCount > 1 { travelerCount -= 1; Haptics.light() }
                } label: {
                    Image(systemName: "minus")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(Color.atlasBlack)
                        .frame(width: 52, height: 52)
                        .background(Color.white)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)

                Spacer()

                VStack(spacing: 2) {
                    Text(String(format: "%02d", travelerCount))
                        .font(.system(size: 28, weight: .bold, design: .monospaced))
                        .foregroundStyle(Color.atlasBlack)
                    Text("PERSONNEL")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundStyle(Color.atlasBlack.opacity(0.4))
                        .kerning(1.5)
                }

                Spacer()

                Button {
                    travelerCount += 1; Haptics.light()
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(Color.white)
                        .frame(width: 52, height: 52)
                        .background(Color.atlasBlack)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
            .background(Color.white.opacity(0.6))
            .clipShape(RoundedRectangle(cornerRadius: 20))
        }
    }

    // MARK: - Budget Field

    private var budgetField: some View {
        VStack(spacing: 8) {
            Text("Budget (Optional)")
                .atlasLabel()
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, 4)

            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(hex: "222222"))
                    .shadow(color: .black.opacity(0.2), radius: 6, x: 0, y: 3)

                // Center divider line (matches date tiles)
                VStack(spacing: 0) {
                    Color.clear.frame(height: 26)
                    Rectangle()
                        .fill(Color.black.opacity(0.5))
                        .frame(height: 1)
                    Color.clear.frame(height: 26)
                }

                HStack(spacing: 4) {
                    Text(userProfile.currencySymbol)
                        .font(.system(size: 22, weight: .semibold, design: .monospaced))
                        .foregroundStyle(Color.white.opacity(0.45))
                    TextField("0", text: $budget)
                        .font(.system(size: 22, weight: .semibold, design: .monospaced))
                        .foregroundStyle(Color.white)
                        .keyboardType(.numberPad)
                        .focused($budgetFocused)
                        .tint(Color.atlasTeal)
                        .toolbar {
                            ToolbarItemGroup(placement: .keyboard) {
                                Spacer()
                                Button("Done") {
                                    budgetFocused = false
                                }
                                .fontWeight(.semibold)
                                .foregroundStyle(Color.atlasTeal)
                            }
                        }
                }
                .padding(.horizontal, 20)
            }
            .frame(height: 70)
        }
    }

    // MARK: - Color Picker

    private var colorPickerSection: some View {
        VStack(spacing: 8) {
            Text("Card Color")
                .atlasLabel()
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, 4)

            HStack(spacing: 12) {
                ForEach(Self.colorPalette, id: \.0) { (hex, name) in
                    Button {
                        selectedColorHex = hex
                        Haptics.light()
                    } label: {
                        ZStack {
                            Circle()
                                .fill(Color(hex: hex))
                                .frame(width: 44, height: 44)
                                .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                                .overlay(
                                    Circle()
                                        .stroke(Color.atlasBlack.opacity(0.15), lineWidth: 1)
                                )
                            if selectedColorHex == hex {
                                Circle()
                                    .stroke(Color.atlasBlack, lineWidth: 2.5)
                                    .frame(width: 44, height: 44)
                                Image(systemName: "checkmark")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundStyle(hex == "FFFFFF" ? Color.atlasBlack : Color.white)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
            .background(Color.white.opacity(0.7))
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }

    // MARK: - Status Picker

    private var statusSection: some View {
        VStack(spacing: 8) {
            Text("Trip Status")
                .atlasLabel()
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, 4)

            HStack(spacing: 8) {
                ForEach(TripStatus.allCases, id: \.rawValue) { s in
                    Button {
                        trip.status = s
                        if s == .completed {
                            Task { await autoCreateVisitedLocation() }
                        }
                        Haptics.light()
                    } label: {
                        Text(s.label)
                            .font(.system(size: 12, weight: .semibold))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(trip.status == s ? Color.atlasBlack : Color.white.opacity(0.7))
                            .foregroundStyle(trip.status == s ? Color.white : Color.atlasBlack)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - Save Button

    private var saveButton: some View {
        Button {
            saveChanges()
        } label: {
            HStack(spacing: 10) {
                Text("SAVE CHANGES")
                    .font(.system(size: 14, weight: .bold))
                    .kerning(1)
                Image(systemName: "checkmark")
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
    }

    // MARK: - Danger Zone

    private var dangerZone: some View {
        VStack(spacing: 12) {
            Text("Danger Zone")
                .atlasLabel()
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, 4)

            // Archive button
            Button {
                showArchiveConfirm = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "archivebox")
                        .font(.system(size: 14, weight: .medium))
                    Text("Archive Trip")
                        .font(.system(size: 14, weight: .semibold))
                }
                .foregroundStyle(Color.atlasBlack.opacity(0.7))
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .background(Color.atlasBlack.opacity(0.06))
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
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "trash")
                        .font(.system(size: 14, weight: .medium))
                    Text("Delete Trip")
                        .font(.system(size: 14, weight: .semibold))
                }
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

    // MARK: - Actions

    private func saveChanges() {
        guard isValid else { return }
        let dest = destination.trimmingCharacters(in: .whitespaces).uppercased()
        trip.destination     = dest
        trip.country         = country.trimmingCharacters(in: .whitespaces)
        trip.destinationFlag = destinationFlag
        trip.name            = tripName.trimmingCharacters(in: .whitespaces).isEmpty ? dest.capitalized : tripName.trimmingCharacters(in: .whitespaces)
        trip.notes           = notes
        trip.startDate       = startDate
        trip.endDate         = endDate
        trip.travelerCount   = travelerCount
        trip.budget          = Double(budget.replacingOccurrences(of: ",", with: "."))
        trip.cardColorHex    = selectedColorHex
        Haptics.success()
        dismiss()
    }

    private func archiveTrip() {
        trip.status = .completed
        Task { await autoCreateVisitedLocation() }
        Haptics.success()
        dismiss()
    }

    /// Geocodes the trip destination and inserts a VisitedLocation if one doesn't exist yet.
    private func autoCreateVisitedLocation() async {
        let query = [trip.destination.capitalized, trip.country]
            .filter { !$0.isEmpty }
            .joined(separator: ", ")

        guard let coord = await geocodeOnce(query) else { return }

        await MainActor.run {
            // Avoid duplicates
            let loc = VisitedLocation(
                name: trip.destination.capitalized,
                latitude: coord.latitude,
                longitude: coord.longitude,
                dateVisited: trip.endDate,
                source: "trip"
            )
            modelContext.insert(loc)
        }
    }

    private func geocodeOnce(_ address: String) async -> CLLocationCoordinate2D? {
        await withCheckedContinuation { continuation in
            CLGeocoder().geocodeAddressString(address) { placemarks, _ in
                continuation.resume(returning: placemarks?.first?.location?.coordinate)
            }
        }
    }

    private func deleteTrip() {
        modelContext.delete(trip)
        Haptics.success()
        dismiss()
    }
}

#Preview {
    EditTripView(trip: Trip(
        name: "Tokyo Adventure",
        destination: "TOKYO",
        destinationFlag: "🇯🇵",
        startDate: Date(),
        endDate: Date().addingTimeInterval(86400 * 12),
        cardColorHex: "FCDA85",
        status: .planning,
        travelerCount: 3
    ))
    .modelContainer(for: Trip.self, inMemory: true)
}
