//
//  Theme.swift
//  Atlas
//
//  Created by Dawid Piotrowski on 11/03/2026.
//

import SwiftUI

// MARK: - Pill Style (defined here so Models can reference it)

enum PillStyle {
    case black
    case outline
    case teal
    case white
}

// MARK: - Color Extensions

extension Color {
    // Brand palette (from UI design)
    static let atlasTeal    = Color(hex: "009E85")
    static let atlasBlue    = Color(hex: "5499E8")
    static let atlasPink    = Color(hex: "EBCFDA")
    static let atlasYellow  = Color(hex: "FCDA85")
    static let atlasBeige   = Color(hex: "D6D2CB")
    static let atlasBlack   = Color(hex: "1A1A1A")

    // Card background palette (cycles through trips)
    static let cardPalette: [Color] = [
        Color(hex: "FCDA85"),   // yellow
        Color.white,             // white
        Color(hex: "EBCFDA"),   // pink
        Color(hex: "5499E8"),   // blue
    ]

    // Semantic
    static let statusGreen  = Color(hex: "22C55E")
    static let statusYellow = Color(hex: "FCDA85")
    static let statusRed    = Color(hex: "EF4444")

    // Adaptive background
    static var atlasBackground: Color {
        Color(UIColor { tc in
            tc.userInterfaceStyle == .dark
                ? UIColor(hex: "1A1A1A")
                : UIColor(hex: "D6D2CB")
        })
    }

    static var atlasSurface: Color {
        Color(UIColor { tc in
            tc.userInterfaceStyle == .dark
                ? UIColor(hex: "2C2C2C")
                : UIColor(hex: "FFFFFF")
        })
    }

    static var atlasTextPrimary: Color {
        Color(UIColor { tc in
            tc.userInterfaceStyle == .dark
                ? UIColor(hex: "FFFFFF")
                : UIColor(hex: "1A1A1A")
        })
    }

    static var atlasTextSecondary: Color {
        Color(UIColor { tc in
            tc.userInterfaceStyle == .dark
                ? UIColor(hex: "A0A0A0")
                : UIColor(hex: "666666")
        })
    }

    init(hex: String) {
        self.init(UIColor(hex: hex))
    }
}

extension UIColor {
    convenience init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:  (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:  (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:  (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default: (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            red: CGFloat(r) / 255,
            green: CGFloat(g) / 255,
            blue: CGFloat(b) / 255,
            alpha: CGFloat(a) / 255
        )
    }
}

// MARK: - Typography Modifiers

struct AtlasLabelModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.system(size: 10, weight: .bold))
            .foregroundStyle(Color.atlasBlack.opacity(0.6))
            .textCase(.uppercase)
            .kerning(2.0)
    }
}

struct AtlasMonoModifier: ViewModifier {
    var size: CGFloat = 14
    func body(content: Content) -> some View {
        content
            .font(.system(size: size, weight: .medium, design: .monospaced))
            .foregroundStyle(Color.atlasBlack.opacity(0.5))
            .textCase(.uppercase)
    }
}

extension View {
    func atlasLabel() -> some View {
        modifier(AtlasLabelModifier())
    }

    func atlasMono(size: CGFloat = 14) -> some View {
        modifier(AtlasMonoModifier(size: size))
    }
}

// MARK: - Teal Header Modifier

struct TealHeaderModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(Color.atlasTeal)
            .clipShape(
                .rect(
                    topLeadingRadius: 0,
                    bottomLeadingRadius: 40,
                    bottomTrailingRadius: 40,
                    topTrailingRadius: 0
                )
            )
    }
}

extension View {
    func tealHeader() -> some View {
        modifier(TealHeaderModifier())
    }
}

// MARK: - Glass Card Modifier

struct GlassCardModifier: ViewModifier {
    var cornerRadius: CGFloat = 20

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .stroke(Color.white.opacity(0.3), lineWidth: 0.5)
                    )
            )
    }
}

extension View {
    func glassCard(cornerRadius: CGFloat = 20) -> some View {
        modifier(GlassCardModifier(cornerRadius: cornerRadius))
    }
}

// MARK: - Dot Matrix Pattern

struct DotMatrixView: View {
    var columns: Int = 6
    var rows: Int = 3
    var dotSize: CGFloat = 3
    var spacing: CGFloat = 8
    var opacity: Double = 0.15

    var body: some View {
        VStack(spacing: spacing) {
            ForEach(0..<rows, id: \.self) { _ in
                HStack(spacing: spacing) {
                    ForEach(0..<columns, id: \.self) { _ in
                        Circle()
                            .fill(Color.white.opacity(opacity))
                            .frame(width: dotSize, height: dotSize)
                    }
                }
            }
        }
    }
}

// MARK: - Haptics

struct Haptics {
    static func light() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
    static func medium() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }
    static func success() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
    static func error() {
        UINotificationFeedbackGenerator().notificationOccurred(.error)
    }
}

// MARK: - Currency

struct AppCurrency: Identifiable, Equatable {
    let code: String    // "USD"
    let symbol: String  // "$"
    let name: String    // "US Dollar"
    var id: String { code }

    static let all: [AppCurrency] = [
        AppCurrency(code: "USD", symbol: "$",  name: "US Dollar"),
        AppCurrency(code: "EUR", symbol: "€",  name: "Euro"),
        AppCurrency(code: "GBP", symbol: "£",  name: "British Pound"),
        AppCurrency(code: "JPY", symbol: "¥",  name: "Japanese Yen"),
        AppCurrency(code: "CHF", symbol: "Fr", name: "Swiss Franc"),
        AppCurrency(code: "CAD", symbol: "C$", name: "Can Dollar"),
        AppCurrency(code: "AUD", symbol: "A$", name: "Aus Dollar"),
        AppCurrency(code: "PLN", symbol: "zł", name: "Złoty"),
        AppCurrency(code: "NOK", symbol: "kr", name: "Nor Krone"),
        AppCurrency(code: "SEK", symbol: "kr", name: "Swe Krona"),
        AppCurrency(code: "DKK", symbol: "kr", name: "Den Krone"),
        AppCurrency(code: "CZK", symbol: "Kč", name: "Koruna"),
    ]

    static var usd: AppCurrency { all[0] }
}

extension Double {
    /// Format as currency with no decimal places: "$1,200" style.
    func asCurrency(_ symbol: String) -> String {
        String(format: "\(symbol)%.0f", self)
    }
    /// Format as currency with two decimal places: "$12.50" style.
    func asCurrencyPrecise(_ symbol: String) -> String {
        String(format: "\(symbol)%.2f", self)
    }
}

// MARK: - Safe Array Subscript

extension Array {
    subscript(safe index: Int) -> Element? {
        guard index >= 0 && index < count else { return nil }
        return self[index]
    }
}

// MARK: - Tab Bar Configuration

func configureTabBar() {
    let appearance = UITabBarAppearance()
    appearance.configureWithTransparentBackground()
    appearance.backgroundEffect = UIBlurEffect(style: .systemUltraThinMaterial)
    appearance.shadowColor = UIColor.black.withAlphaComponent(0.05)

    let normal   = UIColor(hex: "999999")
    let selected = UIColor(hex: "009E85")

    let normalAttrs:   [NSAttributedString.Key: Any] = [.foregroundColor: normal]
    let selectedAttrs: [NSAttributedString.Key: Any] = [.foregroundColor: selected]

    for layout in [
        appearance.stackedLayoutAppearance,
        appearance.inlineLayoutAppearance,
        appearance.compactInlineLayoutAppearance
    ] {
        layout.normal.iconColor            = normal
        layout.normal.titleTextAttributes  = normalAttrs
        layout.selected.iconColor           = selected
        layout.selected.titleTextAttributes = selectedAttrs
    }

    UITabBar.appearance().standardAppearance   = appearance
    UITabBar.appearance().scrollEdgeAppearance = appearance
}
