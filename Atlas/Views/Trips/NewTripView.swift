//
//  NewTripView.swift
//  Atlas
//

import SwiftUI
import SwiftData

struct NewTripView: View {
    var initialDestination: String? = nil

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(UserProfile.self) private var userProfile

    @Query private var allTrips: [Trip]

    @State private var destination = ""
    @State private var country = ""
    @State private var startDate   = Date()
    @State private var endDate     = Date().addingTimeInterval(86400 * 7)
    @State private var travelerCount = 1
    @State private var budget: String = ""
    @State private var isSubmitting = false

    @State private var showStartPicker = false
    @State private var showEndPicker   = false

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
        .onAppear {
            if let pre = initialDestination, !pre.isEmpty {
                destination = pre.uppercased()
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

    // MARK: - Country Field

    private var countryField: some View {
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
            .autocorrectionDisabled()
            .padding(16)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .shadow(color: .black.opacity(0.04), radius: 4, x: 0, y: 2)
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
            startDate: startDate,
            endDate: endDate,
            cardColorHex: Trip.cardColorHex(for: colorIndex),
            status: .planning,
            budget: Double(budget),
            travelerCount: travelerCount
        )

        modelContext.insert(trip)
        Haptics.success()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            dismiss()
        }
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
        .modelContainer(for: Trip.self, inMemory: true)
}
