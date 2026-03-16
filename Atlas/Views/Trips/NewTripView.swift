//
//  NewTripView.swift
//  Atlas
//

import SwiftUI
import SwiftData

struct NewTripView: View {
    var initialDestination: String? = nil
    var onTripCreated: (() -> Void)? = nil

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(UserProfile.self) private var userProfile

    @Query private var allTrips: [Trip]

    @State private var destination = ""
    @State private var country = ""
    @State private var destinationFlag = "✈️"
    @State private var startDate   = Date()
    @State private var endDate     = Date().addingTimeInterval(86400 * 7)
    @State private var travelerCount = 1
    @State private var budget: String = ""
    @State private var isSubmitting = false

    @State private var showStartPicker = false
    @State private var showEndPicker   = false
    @State private var showFlagPicker  = false

    @FocusState private var budgetFocused: Bool

    private var dateFormatter: DateFormatter {
        let f = DateFormatter()
        f.dateFormat = "MMM dd"
        return f
    }

    private var isValid: Bool {
        !destination.trimmingCharacters(in: .whitespaces).isEmpty && endDate > startDate
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

                    // Date pickers
                    dateRow

                    // Traveler counter
                    travelerSection

                    // Budget (optional)
                    budgetField

                    Spacer().frame(height: 8)

                    // Submit button
                    submitButton

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
        .onAppear {
            if let pre = initialDestination, !pre.isEmpty {
                destination = pre.uppercased()
            }
        }
        .onChange(of: country) { _, newCountry in
            // Auto-detect flag emoji from country name
            if let detected = flagEmoji(fromCountryName: newCountry), destinationFlag == "✈️" {
                destinationFlag = detected
            }
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

                Text("New Trip")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.white)

                Spacer()

                // Spacer for symmetry
                Color.clear.frame(width: 32, height: 32)
            }
            .padding(.horizontal, 20)
        }
        .frame(height: 56)
        .padding(.top, 0)
    }

    // MARK: - Destination Field

    private var destinationField: some View {
        VStack(spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(hex: "222222"))
                    .shadow(color: .black.opacity(0.2), radius: 6, x: 0, y: 3)

                VStack(spacing: 0) {
                    // Center horizontal divider
                    Color.clear
                        .frame(height: 34)
                    Rectangle()
                        .fill(Color.black.opacity(0.5))
                        .frame(height: 1)
                    Color.clear
                        .frame(height: 34)
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

            Text("TAP TO ADJUST COORDINATES")
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
                // Flag button — tap to override auto-detected emoji
                Button { showFlagPicker = true } label: {
                    Text(destinationFlag)
                        .font(.system(size: 28))
                        .frame(width: 52, height: 52)
                        .background(Color.white)
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
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .shadow(color: .black.opacity(0.04), radius: 4, x: 0, y: 2)
            }
        }
    }

    // MARK: - Date Row

    private var dateRow: some View {
        HStack(spacing: 12) {
            dateTile(label: "Departure", date: startDate) {
                showStartPicker = true
            }
            dateTile(label: "Return", date: endDate) {
                showEndPicker = true
            }
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
                // Minus button
                Button {
                    if travelerCount > 1 {
                        travelerCount -= 1
                        Haptics.light()
                    }
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

                // Count display
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

                // Plus button
                Button {
                    travelerCount += 1
                    Haptics.light()
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

    // MARK: - Submit Button

    private var submitButton: some View {
        Button {
            createTrip()
        } label: {
            HStack(spacing: 10) {
                Text("INITIATE SEQUENCE")
                    .font(.system(size: 14, weight: .bold))
                    .kerning(1)
                Image(systemName: "airplane.departure")
                    .font(.system(size: 16, weight: .bold))
            }
            .foregroundStyle(isValid ? .white : Color.white.opacity(0.4))
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(isValid ? Color.atlasBlack : Color.atlasBlack.opacity(0.3))
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(ScaleButtonStyle())
        .disabled(!isValid || isSubmitting)
    }

    // MARK: - Actions

    private func createTrip() {
        guard isValid else { return }
        isSubmitting = true

        let colorIndex = allTrips.count
        let trip = Trip(
            name: destination.trimmingCharacters(in: .whitespaces).capitalized,
            destination: destination.trimmingCharacters(in: .whitespaces).uppercased(),
            country: country.trimmingCharacters(in: .whitespaces),
            destinationFlag: destinationFlag,
            startDate: startDate,
            endDate: endDate,
            cardColorHex: Trip.cardColorHex(for: colorIndex),
            status: .planning,
            budget: Double(budget),
            travelerCount: travelerCount
        )

        modelContext.insert(trip)
        onTripCreated?()
        Haptics.success()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            dismiss()
        }
    }
}

// MARK: - Flag Helpers

/// Converts a country name to a flag emoji using Locale + Unicode regional indicators.
func flagEmoji(fromCountryName name: String) -> String? {
    let trimmed = name.trimmingCharacters(in: .whitespaces)
    guard trimmed.count >= 2 else { return nil }
    for code in NSLocale.isoCountryCodes {
        guard let localised = Locale.current.localizedString(forRegionCode: code) else { continue }
        if localised.localizedCaseInsensitiveContains(trimmed) ||
           trimmed.localizedCaseInsensitiveContains(localised) {
            return flagEmojiFromISO(code)
        }
    }
    return nil
}

func flagEmojiFromISO(_ isoCode: String) -> String {
    let base: UInt32 = 127397 // offset to regional indicator symbol letters
    var emoji = ""
    for scalar in isoCode.uppercased().unicodeScalars {
        if let s = Unicode.Scalar(base + scalar.value) {
            emoji.append(Character(s))
        }
    }
    return emoji
}

// MARK: - Flag Picker Sheet

struct FlagPickerSheet: View {
    @Binding var selectedFlag: String
    @Environment(\.dismiss) private var dismiss
    @State private var customEmoji = ""
    @FocusState private var emojiFieldFocused: Bool

    // Common destination flags for quick selection
    private let commonFlags: [(String, String)] = [
        ("🇯🇵", "Japan"), ("🇫🇷", "France"), ("🇮🇹", "Italy"), ("🇪🇸", "Spain"),
        ("🇬🇧", "UK"), ("🇩🇪", "Germany"), ("🇺🇸", "USA"), ("🇵🇹", "Portugal"),
        ("🇬🇷", "Greece"), ("🇳🇱", "Netherlands"), ("🇧🇪", "Belgium"), ("🇨🇭", "Switzerland"),
        ("🇦🇹", "Austria"), ("🇸🇪", "Sweden"), ("🇳🇴", "Norway"), ("🇩🇰", "Denmark"),
        ("🇵🇱", "Poland"), ("🇨🇿", "Czechia"), ("🇭🇺", "Hungary"), ("🇹🇷", "Türkiye"),
        ("🇹🇭", "Thailand"), ("🇻🇳", "Vietnam"), ("🇮🇩", "Indonesia"), ("🇸🇬", "Singapore"),
        ("🇰🇷", "South Korea"), ("🇨🇳", "China"), ("🇮🇳", "India"), ("🇦🇪", "UAE"),
        ("🇲🇦", "Morocco"), ("🇿🇦", "South Africa"), ("🇪🇬", "Egypt"), ("🇰🇪", "Kenya"),
        ("🇧🇷", "Brazil"), ("🇦🇷", "Argentina"), ("🇲🇽", "Mexico"), ("🇨🇦", "Canada"),
        ("🇦🇺", "Australia"), ("🇳🇿", "New Zealand"), ("🇮🇸", "Iceland"), ("🇲🇻", "Maldives"),
        ("🇨🇺", "Cuba"), ("🇯🇲", "Jamaica"), ("🇵🇪", "Peru"), ("🇨🇱", "Chile"),
    ]

    var body: some View {
        VStack(spacing: 0) {
            // Header
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
                    Text("Choose Flag")
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

                    // Custom emoji input
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Custom Flag Emoji")
                            .atlasLabel()
                            .padding(.leading, 4)

                        HStack(spacing: 12) {
                            Text(customEmoji.isEmpty ? selectedFlag : customEmoji)
                                .font(.system(size: 32))
                                .frame(width: 52, height: 52)
                                .background(Color.white)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .shadow(color: .black.opacity(0.06), radius: 4, x: 0, y: 2)

                            TextField("Type any emoji", text: $customEmoji)
                                .font(.system(size: 18))
                                .focused($emojiFieldFocused)
                                .padding(14)
                                .background(Color.white)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .shadow(color: .black.opacity(0.04), radius: 4, x: 0, y: 2)

                            Button {
                                let trimmed = customEmoji.trimmingCharacters(in: .whitespaces)
                                if !trimmed.isEmpty { selectedFlag = trimmed }
                                dismiss()
                            } label: {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundStyle(.white)
                                    .frame(width: 46, height: 46)
                                    .background(Color.atlasBlack)
                                    .clipShape(Circle())
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    // Quick pick grid
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Common Destinations")
                            .atlasLabel()
                            .padding(.leading, 4)

                        LazyVGrid(columns: Array(repeating: .init(.flexible()), count: 6), spacing: 10) {
                            ForEach(commonFlags, id: \.0) { (flag, country) in
                                Button {
                                    selectedFlag = flag
                                    dismiss()
                                } label: {
                                    VStack(spacing: 4) {
                                        Text(flag)
                                            .font(.system(size: 26))
                                        Text(country.prefix(6).uppercased())
                                            .font(.system(size: 7, weight: .semibold, design: .monospaced))
                                            .foregroundStyle(Color.atlasBlack.opacity(0.4))
                                            .lineLimit(1)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 8)
                                    .background(selectedFlag == flag ? Color.atlasTeal.opacity(0.1) : Color.white)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(selectedFlag == flag ? Color.atlasTeal.opacity(0.4) : Color.clear, lineWidth: 1.5)
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    Spacer().frame(height: 40)
                }
                .padding(.horizontal, 20)
            }
        }
        .background(Color.atlasBeige.ignoresSafeArea())
        .onAppear { emojiFieldFocused = false }
    }
}

// MARK: - Scale Button Style

struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.easeInOut(duration: 0.12), value: configuration.isPressed)
    }
}

// MARK: - Placeholder extension

extension View {
    func placeholder<Content: View>(
        when shouldShow: Bool,
        @ViewBuilder placeholder: () -> Content
    ) -> some View {
        ZStack(alignment: .center) {
            placeholder().opacity(shouldShow ? 1 : 0)
            self
        }
    }
}

// MARK: - Date Picker Sheet

struct DatePickerSheet: View {
    let title: String
    @Binding var date: Date
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            DatePicker(
                title,
                selection: $date,
                displayedComponents: .date
            )
            .datePickerStyle(.graphical)
            .tint(Color.atlasTeal)
            .padding()
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.atlasTeal)
                }
            }
        }
        .presentationDetents([.medium])
    }
}

#Preview {
    NewTripView()
        .modelContainer(for: [Trip.self, TripItem.self, CrewMember.self, Expense.self, WishlistDestination.self, VisitedLocation.self], inMemory: true)
}
