//
//  FlapBoardView.swift
//  Atlas
//
//  The signature airport departures board animation component.
//

import SwiftUI

// MARK: - Single Character Tile

struct FlapCharView: View {
    let char: Character
    var light: Bool = false
    var fontSize: CGFloat = 18
    var isFlipping: Bool = false

    private var bgColor: Color {
        light ? Color(hex: "F0F0F0") : Color(hex: "222222")
    }
    private var textColor: Color {
        light ? Color(hex: "222222") : Color(hex: "EEEEEE")
    }
    private var dividerColor: Color {
        light ? Color.black.opacity(0.12) : Color.black.opacity(0.55)
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 4)
                .fill(bgColor)
            // Horizontal center divider (the classic split-flap look)
            Rectangle()
                .fill(dividerColor)
                .frame(height: 1)
            Text(String(char))
                .font(.system(size: fontSize, weight: .medium, design: .monospaced))
                .foregroundStyle(textColor)
        }
        .frame(width: fontSize * 1.1, height: fontSize * 1.55)
        .shadow(color: .black.opacity(0.18), radius: 1, x: 0, y: 1)
        .rotation3DEffect(
            .degrees(isFlipping ? -90 : 0),
            axis: (x: 1, y: 0, z: 0),
            perspective: 0.6
        )
    }
}

// MARK: - Flap Board (full string)

struct FlapBoardView: View {
    let text: String
    var light: Bool = false
    var fontSize: CGFloat = 18
    var spacing: CGFloat = 1

    @State private var displayedChars: [Character] = []
    @State private var flipping: [Bool] = []

    var body: some View {
        HStack(spacing: spacing) {
            ForEach(Array(displayedChars.enumerated()), id: \.offset) { index, char in
                FlapCharView(
                    char: char,
                    light: light,
                    fontSize: fontSize,
                    isFlipping: flipping[safe: index] ?? false
                )
            }
        }
        .onAppear {
            initDisplay()
            animateIn()
        }
        .onChange(of: text) { _, newValue in
            animateTo(newValue)
        }
    }

    private func initDisplay() {
        displayedChars = Array(text)
        flipping = Array(repeating: false, count: text.count)
    }

    private func animateIn() {
        // Stagger each character flipping in from blank
        for i in displayedChars.indices {
            let delay = Double(i) * 0.06
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                guard i < flipping.count else { return }
                withAnimation(.easeInOut(duration: 0.25)) {
                    flipping[i] = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                    guard i < flipping.count else { return }
                    withAnimation(.easeInOut(duration: 0.2)) {
                        flipping[i] = false
                    }
                }
            }
        }
    }

    private func animateTo(_ newText: String) {
        let newChars = Array(newText)
        // Resize arrays
        displayedChars = newChars
        flipping = Array(repeating: false, count: newChars.count)
        animateIn()
    }
}

// MARK: - Previews

#Preview("Dark tiles") {
    ZStack {
        Color(hex: "FCDA85")
        FlapBoardView(text: "TOKYO", fontSize: 28)
            .padding()
    }
}

#Preview("Light tiles") {
    ZStack {
        Color.atlasTeal
        VStack(spacing: 12) {
            FlapBoardView(text: "42", light: true, fontSize: 24)
            FlapBoardView(text: "18", light: true, fontSize: 24)
            FlapBoardView(text: "32K", light: true, fontSize: 24)
        }
        .padding()
    }
}
