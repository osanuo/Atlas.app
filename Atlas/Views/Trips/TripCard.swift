//
//  TripCard.swift
//  Atlas
//

import SwiftUI

struct TripCard: View {
    let trip: Trip
    var onTap: (() -> Void)? = nil

    @State private var isPressed = false

    private var textColor: Color {
        // Blue card has white text; others have dark text
        trip.cardColorHex == "5499E8" ? .white : Color.atlasBlack
    }

    private var subTextOpacity: Double {
        trip.cardColorHex == "5499E8" ? 0.75 : 0.55
    }

    var body: some View {
        Button {
            Haptics.medium()
            onTap?()
        } label: {
            VStack(alignment: .leading, spacing: 0) {
                // MARK: Top row: date range (left) + status pill (right)
                HStack {
                    Text(trip.shortDateRangeString)
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundStyle(textColor.opacity(subTextOpacity))

                    Spacer()

                    PillBadge(label: trip.status.label, style: pillStyle)
                }

                Spacer().frame(height: 14)

                // MARK: Destination (flap board)
                FlapBoardView(
                    text: trip.destination.uppercased(),
                    light: trip.cardColorHex != "5499E8",
                    fontSize: 26
                )

                Spacer().frame(height: 14)

                // MARK: Bottom row: stacked avatars (left) + traveler count (right)
                HStack {
                    if !trip.crew.isEmpty {
                        StackedAvatarsView(
                            names: trip.crew.map { $0.name },
                            maxVisible: 3,
                            size: 24
                        )
                    }

                    Spacer()

                    Text("\(trip.travelerCount) Traveler\(trip.travelerCount == 1 ? "" : "s")")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(textColor.opacity(subTextOpacity))
                }

                // MARK: Progress bar (items completed)
                if trip.items.count > 0 {
                    progressBar
                        .padding(.top, 10)
                }
            }
            .padding(16)
            .background(trip.cardColor)
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .shadow(color: .black.opacity(0.05), radius: 6, x: 0, y: 3)
        }
        .buttonStyle(.plain)
        .scaleEffect(isPressed ? 0.97 : 1.0)
        .animation(.easeInOut(duration: 0.12), value: isPressed)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
    }

    private var pillStyle: PillStyle {
        switch trip.cardColorHex {
        case "5499E8": return .white
        default:       return .black
        }
    }

    private var progressBar: some View {
        let total = trip.items.count
        let done  = trip.completedItemsCount
        let ratio = total > 0 ? CGFloat(done) / CGFloat(total) : 0

        return VStack(alignment: .leading, spacing: 4) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(textColor.opacity(0.12))
                        .frame(height: 3)
                    Capsule()
                        .fill(textColor.opacity(0.5))
                        .frame(width: geo.size.width * ratio, height: 3)
                }
            }
            .frame(height: 3)

            Text("\(done)/\(total) items planned")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(textColor.opacity(0.45))
        }
    }
}

// MARK: - Compact past trip row

struct PastTripRow: View {
    let trip: Trip

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(hex: "F5F3F1"))
                Text(trip.destinationFlag)
                    .font(.system(size: 20))
            }
            .frame(width: 42, height: 42)

            VStack(alignment: .leading, spacing: 2) {
                Text(trip.destination.capitalized)
                    .font(.system(size: 14, weight: .bold))
                Text(trip.shortDateRangeString)
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(Color.atlasBlack.opacity(0.45))
            }

            Spacer()

            PillBadge(label: trip.status.label, style: .outline)
        }
        .padding(14)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.04), radius: 4, x: 0, y: 2)
    }
}

#Preview {
    ScrollView {
        VStack(spacing: 16) {
            TripCard(trip: Trip(
                name: "Tokyo Adventure",
                destination: "TOKYO",
                destinationFlag: "🇯🇵",
                startDate: Date(),
                endDate: Date().addingTimeInterval(86400 * 12),
                cardColorHex: "FCDA85",
                status: .planning,
                travelerCount: 5
            ))

            TripCard(trip: Trip(
                name: "Berlin",
                destination: "BERLIN",
                destinationFlag: "🇩🇪",
                startDate: Date(),
                endDate: Date().addingTimeInterval(86400 * 5),
                cardColorHex: "FFFFFF",
                status: .confirmed,
                travelerCount: 2
            ))

            TripCard(trip: Trip(
                name: "Paris",
                destination: "PARIS",
                destinationFlag: "🇫🇷",
                startDate: Date(),
                endDate: Date().addingTimeInterval(86400 * 7),
                cardColorHex: "EBCFDA",
                status: .planning,
                travelerCount: 3
            ))

            TripCard(trip: Trip(
                name: "NYC",
                destination: "NEW YORK",
                destinationFlag: "🇺🇸",
                startDate: Date(),
                endDate: Date().addingTimeInterval(86400 * 4),
                cardColorHex: "5499E8",
                status: .confirmed,
                travelerCount: 2
            ))
        }
        .padding()
    }
    .background(Color.atlasBeige)
}
