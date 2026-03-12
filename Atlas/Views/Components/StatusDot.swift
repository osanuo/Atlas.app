//
//  StatusDot.swift
//  Atlas
//

import SwiftUI

struct StatusDot: View {
    let color: Color
    var size: CGFloat = 8

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: size, height: size)
            .overlay(
                Circle()
                    .stroke(Color.white, lineWidth: 1.5)
            )
    }
}

// MARK: - Avatar with Status Dot

struct AvatarInitialsView: View {
    let initials: String
    var size: CGFloat = 48
    var statusColor: Color? = nil
    var colorSeed: Int = 0

    private var avatarColor: Color {
        let palette = ["009E85", "5499E8", "9B59B6", "E67E22", "E74C3C", "1ABC9C"]
        return Color(hex: palette[abs(colorSeed) % palette.count])
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            // Circle + centered initials in their own ZStack
            ZStack {
                Circle()
                    .fill(avatarColor.opacity(0.2))
                    .frame(width: size, height: size)
                    .overlay(
                        Circle().stroke(avatarColor.opacity(0.4), lineWidth: 1)
                    )

                Text(initials)
                    .font(.system(size: size * 0.35, weight: .bold))
                    .foregroundStyle(avatarColor)
            }

            // Status dot floats to bottom-trailing
            if let statusColor {
                StatusDot(color: statusColor, size: size * 0.22)
                    .offset(x: 1, y: 1)
            }
        }
    }
}

// MARK: - Stacked Avatars (for trip cards)

struct StackedAvatarsView: View {
    let names: [String]
    var maxVisible: Int = 3
    var size: CGFloat = 28

    private var visibleNames: [String] {
        Array(names.prefix(maxVisible))
    }

    private var overflow: Int {
        max(0, names.count - maxVisible)
    }

    var body: some View {
        HStack(spacing: -(size * 0.3)) {
            ForEach(Array(visibleNames.enumerated()), id: \.offset) { i, name in
                AvatarInitialsView(
                    initials: String(name.prefix(1)),
                    size: size,
                    colorSeed: i
                )
                .zIndex(Double(maxVisible - i))
            }

            if overflow > 0 {
                Circle()
                    .fill(Color.atlasBlack)
                    .frame(width: size, height: size)
                    .overlay(
                        Text("+\(overflow)")
                            .font(.system(size: size * 0.3, weight: .bold))
                            .foregroundStyle(.white)
                    )
            }
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        StatusDot(color: .statusGreen)
        StatusDot(color: .statusYellow)
        StatusDot(color: .statusRed)

        AvatarInitialsView(initials: "SW", size: 48, statusColor: .statusGreen, colorSeed: 0)
        AvatarInitialsView(initials: "JL", size: 48, statusColor: .statusYellow, colorSeed: 1)

        StackedAvatarsView(names: ["Sarah", "James", "Mike", "Lisa"], maxVisible: 3)
    }
    .padding()
    .background(Color.atlasBeige)
}
