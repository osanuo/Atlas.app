//
//  OnboardingView.swift
//  Atlas
//

import SwiftUI
import AuthenticationServices

struct OnboardingView: View {
    var onComplete: () -> Void

    @State private var page = 0

    var body: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $page) {
                HeroPage(onNext: { withAnimation { page = 1 } })
                    .tag(0)
                FeaturesPage(onNext: { withAnimation { page = 2 } })
                    .tag(1)
                SignInPage(onComplete: onComplete)
                    .tag(2)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .ignoresSafeArea()

            // Page dots
            PageDotsView(current: page, total: 3)
                .padding(.bottom, 44)
        }
        .ignoresSafeArea()
    }
}

// MARK: - Page Dots

private struct PageDotsView: View {
    let current: Int
    let total: Int

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<total, id: \.self) { i in
                Capsule()
                    .fill(current == i ? Color.white : Color.white.opacity(0.35))
                    .frame(width: current == i ? 20 : 6, height: 6)
                    .animation(.spring(response: 0.35), value: current)
            }
        }
    }
}

// MARK: - Page 1: Hero

private struct HeroPage: View {
    var onNext: () -> Void
    @State private var appeared = false

    var body: some View {
        ZStack {
            // Teal gradient background
            LinearGradient(
                colors: [Color.atlasTeal, Color.atlasTeal.opacity(0.75)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            // Dot matrix watermark (top-right)
            VStack {
                HStack {
                    Spacer()
                    DotMatrixView(columns: 9, rows: 5, opacity: 0.12)
                        .padding(.top, 60)
                        .padding(.trailing, 20)
                }
                Spacer()
            }

            VStack(spacing: 0) {
                Spacer()

                // Airplane icon
                Image(systemName: "airplane")
                    .font(.system(size: 72, weight: .ultraLight))
                    .foregroundStyle(.white.opacity(0.9))
                    .scaleEffect(appeared ? 1.0 : 0.6)
                    .opacity(appeared ? 1.0 : 0)
                    .animation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.1), value: appeared)

                Spacer().frame(height: 32)

                // Atlas wordmark
                Text("ATLAS")
                    .font(.system(size: 52, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white)
                    .kerning(10)
                    .offset(y: appeared ? 0 : 20)
                    .opacity(appeared ? 1.0 : 0)
                    .animation(.easeOut(duration: 0.5).delay(0.25), value: appeared)

                Spacer().frame(height: 16)

                Text("Your World. Your Journey.\nYour Plan.")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.white.opacity(0.75))
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .offset(y: appeared ? 0 : 20)
                    .opacity(appeared ? 1.0 : 0)
                    .animation(.easeOut(duration: 0.5).delay(0.4), value: appeared)

                Spacer()

                // CTA button
                Button(action: onNext) {
                    HStack(spacing: 10) {
                        Text("START PLANNING")
                            .font(.system(size: 14, weight: .bold))
                            .kerning(1)
                        Image(systemName: "arrow.right")
                            .font(.system(size: 14, weight: .bold))
                    }
                    .foregroundStyle(Color.atlasTeal)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                }
                .buttonStyle(ScaleButtonStyle())
                .padding(.horizontal, 32)
                .offset(y: appeared ? 0 : 24)
                .opacity(appeared ? 1.0 : 0)
                .animation(.easeOut(duration: 0.5).delay(0.55), value: appeared)

                Spacer().frame(height: 100)
            }
        }
        .onAppear { appeared = true }
    }
}

// MARK: - Page 2: Features

private struct FeaturesPage: View {
    var onNext: () -> Void
    @State private var appeared = false

    private let features: [(icon: String, color: String, title: String, description: String)] = [
        ("fork.knife",     "FF6B6B", "Trip Collections",      "Restaurants, stays, activities — every detail organized by category."),
        ("calendar",       "4ECDC4", "Day-by-Day Itinerary",  "Morning, afternoon, evening — schedule your adventure hour by hour."),
        ("person.2.fill",  "9B59B6", "Crew Manifest",         "Invite travel companions and track everyone's status in one place."),
        ("globe",          "FFB84D", "Explore Destinations",  "Discover handpicked destinations and spark your next big trip.")
    ]

    var body: some View {
        ZStack {
            Color.atlasBeige.ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                ZStack(alignment: .topTrailing) {
                    Color.atlasTeal.ignoresSafeArea(edges: .top)

                    VStack(alignment: .leading, spacing: 0) {
                        Spacer().frame(height: 70)
                        Text("What's\nInside")
                            .font(.system(size: 36, weight: .bold))
                            .foregroundStyle(.white)
                            .lineSpacing(2)
                        Spacer().frame(height: 28)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 28)

                    DotMatrixView(columns: 6, rows: 3, opacity: 0.1)
                        .padding(.top, 50)
                        .padding(.trailing, 16)
                }
                .frame(height: 180)

                // Feature list
                VStack(spacing: 0) {
                    Spacer().frame(height: 24)

                    VStack(spacing: 14) {
                        ForEach(Array(features.enumerated()), id: \.offset) { i, feature in
                            FeatureRow(feature: feature)
                                .offset(x: appeared ? 0 : 40)
                                .opacity(appeared ? 1.0 : 0)
                                .animation(
                                    .spring(response: 0.5, dampingFraction: 0.8)
                                    .delay(Double(i) * 0.1),
                                    value: appeared
                                )
                        }
                    }
                    .padding(.horizontal, 24)

                    Spacer()

                    // Next button
                    Button(action: onNext) {
                        HStack(spacing: 10) {
                            Text("CONTINUE")
                                .font(.system(size: 14, weight: .bold))
                                .kerning(1)
                            Image(systemName: "arrow.right")
                                .font(.system(size: 14, weight: .bold))
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(Color.atlasBlack)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                    .buttonStyle(ScaleButtonStyle())
                    .padding(.horizontal, 24)
                    .opacity(appeared ? 1.0 : 0)
                    .animation(.easeOut(duration: 0.4).delay(0.5), value: appeared)

                    Spacer().frame(height: 100)
                }
                .background(Color.atlasBeige)
            }
        }
        .onAppear { appeared = true }
    }
}

private struct FeatureRow: View {
    let feature: (icon: String, color: String, title: String, description: String)

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color(hex: feature.color).opacity(0.15))
                    .frame(width: 52, height: 52)
                Image(systemName: feature.icon)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(Color(hex: feature.color))
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(feature.title)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Color.atlasBlack)
                Text(feature.description)
                    .font(.system(size: 12))
                    .foregroundStyle(Color.atlasBlack.opacity(0.5))
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()
        }
        .padding(14)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
}

// MARK: - Page 3: Sign In

private struct SignInPage: View {
    var onComplete: () -> Void
    @State private var appeared = false
    @State private var nameInput = ""
    @FocusState private var nameFocused: Bool

    var body: some View {
        ZStack {
            // Dark gradient
            LinearGradient(
                colors: [Color(hex: "1A1A2E"), Color(hex: "16213E")],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            // Teal dot matrix watermark
            VStack {
                Spacer()
                HStack {
                    DotMatrixView(columns: 8, rows: 4, opacity: 0.06)
                        .padding(.leading, 20)
                        .padding(.bottom, 80)
                    Spacer()
                }
            }

            VStack(spacing: 0) {
                Spacer()

                // Icon
                ZStack {
                    Circle()
                        .fill(Color.atlasTeal.opacity(0.15))
                        .frame(width: 80, height: 80)
                    Image(systemName: "globe.americas.fill")
                        .font(.system(size: 36, weight: .regular))
                        .foregroundStyle(Color.atlasTeal)
                }
                .scaleEffect(appeared ? 1.0 : 0.5)
                .opacity(appeared ? 1.0 : 0)
                .animation(.spring(response: 0.5, dampingFraction: 0.7).delay(0.1), value: appeared)

                Spacer().frame(height: 28)

                // Title
                VStack(spacing: 10) {
                    Text("Join the")
                        .font(.system(size: 38, weight: .bold))
                        .foregroundStyle(.white)
                    Text("Expedition.")
                        .font(.system(size: 38, weight: .bold))
                        .foregroundStyle(Color.atlasTeal)
                }
                .offset(y: appeared ? 0 : 20)
                .opacity(appeared ? 1.0 : 0)
                .animation(.easeOut(duration: 0.5).delay(0.25), value: appeared)

                Spacer().frame(height: 12)

                Text("Sign in to sync trips across devices\nand enable real-time collaboration.")
                    .font(.system(size: 14))
                    .foregroundStyle(.white.opacity(0.5))
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .offset(y: appeared ? 0 : 20)
                    .opacity(appeared ? 1.0 : 0)
                    .animation(.easeOut(duration: 0.5).delay(0.35), value: appeared)

                Spacer().frame(height: 28)

                // Name field — attribution works even without SIWA
                VStack(alignment: .leading, spacing: 6) {
                    Text("YOUR NAME")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white.opacity(0.35))
                        .kerning(1.5)
                        .padding(.leading, 4)

                    TextField("", text: $nameInput, prompt:
                        Text("e.g. Alex Chen").foregroundStyle(Color.white.opacity(0.25))
                    )
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.white)
                    .focused($nameFocused)
                    .submitLabel(.done)
                    .onSubmit { nameFocused = false }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .background(Color.white.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(nameFocused ? Color.atlasTeal.opacity(0.6) : Color.white.opacity(0.12), lineWidth: 1)
                    )
                }
                .padding(.horizontal, 32)
                .offset(y: appeared ? 0 : 20)
                .opacity(appeared ? 1.0 : 0)
                .animation(.easeOut(duration: 0.45).delay(0.42), value: appeared)

                Spacer().frame(height: 20)

                // SIWA button
                SignInWithAppleButton(.signIn) { request in
                    request.requestedScopes = [.fullName, .email]
                } onCompletion: { result in
                    handleSignIn(result: result)
                }
                .signInWithAppleButtonStyle(.white)
                .frame(height: 56)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .padding(.horizontal, 32)
                .offset(y: appeared ? 0 : 24)
                .opacity(appeared ? 1.0 : 0)
                .animation(.easeOut(duration: 0.45).delay(0.5), value: appeared)

                Spacer().frame(height: 16)

                // Skip button
                Button {
                    commitName()
                    onComplete()
                } label: {
                    Text("Continue without signing in")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.white.opacity(0.4))
                        .underline()
                }
                .buttonStyle(.plain)
                .offset(y: appeared ? 0 : 24)
                .opacity(appeared ? 1.0 : 0)
                .animation(.easeOut(duration: 0.45).delay(0.6), value: appeared)

                Spacer().frame(height: 100)
            }
        }
        .onAppear {
            appeared = true
            let existing = UserProfile.shared.displayName
            if existing != "Traveler" { nameInput = existing }
        }
        .onTapGesture { nameFocused = false }
    }

    private func commitName() {
        let trimmed = nameInput.trimmingCharacters(in: .whitespaces)
        if !trimmed.isEmpty {
            UserProfile.shared.displayName = trimmed
        }
    }

    private func handleSignIn(result: Result<ASAuthorization, Error>) {
        commitName()
        switch result {
        case .success(let auth):
            if let credential = auth.credential as? ASAuthorizationAppleIDCredential {
                let given  = credential.fullName?.givenName  ?? ""
                let family = credential.fullName?.familyName ?? ""
                let name   = [given, family].filter { !$0.isEmpty }.joined(separator: " ")
                // Apple-provided name takes precedence (only returned on first SIWA login)
                if !name.isEmpty {
                    UserProfile.shared.displayName = name
                }
            }
            onComplete()
        case .failure:
            // SIWA capability not configured in dev build — skip gracefully
            onComplete()
        }
    }
}

#Preview {
    OnboardingView(onComplete: {})
}
