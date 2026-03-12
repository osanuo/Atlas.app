//
//  PillBadge.swift
//  Atlas
//

import SwiftUI

// MARK: - Pill Badge Component

struct PillBadge: View {
    let label: String
    var style: PillStyle = .outline

    private var bgColor: Color {
        switch style {
        case .black:   return Color.atlasBlack
        case .outline: return .clear
        case .teal:    return Color.atlasTeal
        case .white:   return Color.white
        }
    }

    private var fgColor: Color {
        switch style {
        case .black:   return .white
        case .outline: return Color.atlasBlack
        case .teal:    return .white
        case .white:   return Color.atlasBlack
        }
    }

    private var borderColor: Color {
        switch style {
        case .outline: return Color.atlasBlack
        case .white:   return Color.atlasBlack.opacity(0.1)
        default:       return .clear
        }
    }

    var body: some View {
        Text(label)
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(fgColor)
            .textCase(.uppercase)
            .kerning(0.5)
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
            .background(bgColor)
            .clipShape(Capsule())
            .overlay(Capsule().stroke(borderColor, lineWidth: 1))
    }
}

#Preview {
    HStack(spacing: 12) {
        PillBadge(label: "Planning", style: .black)
        PillBadge(label: "Confirmed", style: .outline)
        PillBadge(label: "Active", style: .teal)
        PillBadge(label: "Completed", style: .outline)
    }
    .padding()
    .background(Color.atlasBeige)
}
