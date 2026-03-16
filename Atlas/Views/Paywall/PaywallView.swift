//
//  PaywallView.swift
//  Atlas
//

import SwiftUI
import StoreKit

// MARK: - Paywall View

struct PaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(SubscriptionManager.self) private var subscriptionManager

    var body: some View {
        VStack(spacing: 0) {

            // MARK: Header
            ZStack(alignment: .topLeading) {
                LinearGradient(
                    colors: [Color.atlasBlack, Color.atlasBlack.opacity(0.88)],
                    startPoint: .top, endPoint: .bottom
                )
                .ignoresSafeArea(edges: .top)
                .frame(height: 220)

                VStack(spacing: 12) {
                    Spacer().frame(height: 52)

                    Image(systemName: "airplane.circle.fill")
                        .font(.system(size: 52, weight: .light))
                        .foregroundStyle(Color.atlasTeal)

                    VStack(spacing: 4) {
                        Text("ATLAS PRO")
                            .font(.system(size: 28, weight: .bold, design: .monospaced))
                            .foregroundStyle(.white)
                            .kerning(4)
                        Text("Plan without limits")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.white.opacity(0.55))
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.bottom, 20)

                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.7))
                        .frame(width: 30, height: 30)
                        .background(Color.white.opacity(0.12))
                        .clipShape(Circle())
                }
                .padding(.top, 56)
                .padding(.leading, 20)
            }

            ScrollView(showsIndicators: false) {
                VStack(spacing: 28) {
                    Spacer().frame(height: 8)

                    // MARK: Feature List
                    featuresSection

                    // MARK: Purchase Buttons
                    purchaseSection

                    // MARK: Restore
                    Button {
                        Task { await subscriptionManager.restorePurchases() }
                    } label: {
                        Text("Restore Purchases")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Color.atlasBlack.opacity(0.35))
                    }
                    .buttonStyle(.plain)

                    // MARK: Legal links
                    HStack(spacing: 6) {
                        Link("Terms of Use",
                             destination: URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(Color.atlasTeal.opacity(0.8))

                        Text("·")
                            .font(.system(size: 11))
                            .foregroundStyle(Color.atlasBlack.opacity(0.25))

                        // Privacy Policy placeholder — replace URL when ready
                        Text("Privacy Policy")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(Color.atlasBlack.opacity(0.25))
                    }

                    // Legal note
                    Text("Subscription auto-renews unless cancelled at least 24 hours before the end of the current period. Manage or cancel anytime in App Store settings.")
                        .font(.system(size: 10))
                        .foregroundStyle(Color.atlasBlack.opacity(0.25))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 40)
                }
                .padding(.horizontal, 20)
            }
        }
        .background(Color.atlasBeige.ignoresSafeArea())
    }

    // MARK: - Features

    private var featuresSection: some View {
        VStack(spacing: 0) {
            ForEach(ProFeature.all) { feature in
                ProFeatureRow(feature: feature)
                if feature.id != ProFeature.all.last?.id {
                    Divider()
                        .padding(.leading, 52)
                }
            }
        }
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .shadow(color: .black.opacity(0.04), radius: 6, x: 0, y: 3)
    }

    // MARK: - Purchase Buttons

    private var purchaseSection: some View {
        VStack(spacing: 12) {

            // ── Annual — primary / highlighted ───────────────────────────────
            if let annual = subscriptionManager.annualProduct {
                Button {
                    Task { await subscriptionManager.purchase(annual) }
                } label: {
                    VStack(spacing: 0) {
                        // Top row: plan name + savings badge
                        HStack(alignment: .center, spacing: 8) {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack(spacing: 8) {
                                    Text("Annual")
                                        .font(.system(size: 17, weight: .bold))
                                        .foregroundStyle(.white)

                                    if let saved = subscriptionManager.annualSavingsDollars {
                                        Text("SAVE \(saved)")
                                            .font(.system(size: 10, weight: .bold))
                                            .foregroundStyle(Color.atlasBlack)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 3)
                                            .background(Color.atlasTeal)
                                            .clipShape(Capsule())
                                    }
                                }

                                // Price line + trial note
                                if subscriptionManager.annualHasTrial {
                                    Text("\(subscriptionManager.annualTrialLabel) free trial · then \(annual.displayPrice)/year")
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundStyle(.white.opacity(0.6))
                                } else {
                                    Text(annual.displayPrice + " / year")
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundStyle(.white.opacity(0.6))
                                }
                            }

                            Spacer()

                            if subscriptionManager.isLoading {
                                ProgressView().tint(.white)
                            } else {
                                Text(subscriptionManager.annualHasTrial ? "Try Free" : "Subscribe")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundStyle(Color.atlasBlack)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 9)
                                    .background(Color.atlasTeal)
                                    .clipShape(Capsule())
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 18)

                        // Trial call-out strip at the bottom of the card
                        if subscriptionManager.annualHasTrial {
                            Divider()
                                .background(Color.white.opacity(0.1))

                            HStack(spacing: 6) {
                                Image(systemName: "gift.fill")
                                    .font(.system(size: 11))
                                    .foregroundStyle(Color.atlasTeal)
                                Text("Start your \(subscriptionManager.annualTrialLabel) free trial — cancel anytime")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundStyle(.white.opacity(0.55))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                        }
                    }
                    .background(Color.atlasBlack)
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                }
                .buttonStyle(ScaleButtonStyle())
                .disabled(subscriptionManager.isLoading)
            }

            // ── Monthly — secondary ───────────────────────────────────────────
            if let monthly = subscriptionManager.monthlyProduct {
                Button {
                    Task { await subscriptionManager.purchase(monthly) }
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Monthly")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundStyle(Color.atlasBlack)
                            Text(monthly.displayPrice + " / month · no trial")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(Color.atlasBlack.opacity(0.45))
                        }
                        Spacer()
                        if subscriptionManager.isLoading {
                            ProgressView().tint(Color.atlasTeal)
                        } else {
                            Text("Subscribe")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(Color.atlasBlack)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 9)
                                .background(Color.atlasBlack.opacity(0.07))
                                .clipShape(Capsule())
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 18)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18)
                            .stroke(Color.atlasBlack.opacity(0.07), lineWidth: 1)
                    )
                }
                .buttonStyle(ScaleButtonStyle())
                .disabled(subscriptionManager.isLoading)
            }

            // ── Loading skeleton ──────────────────────────────────────────────
            if subscriptionManager.products.isEmpty {
                VStack(spacing: 12) {
                    ProgressView().tint(Color.atlasTeal)
                    Text("Loading prices…")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.atlasBlack.opacity(0.4))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 32)
            }

            // ── Purchase error ────────────────────────────────────────────────
            if let err = subscriptionManager.purchaseError {
                Text(err)
                    .font(.system(size: 12))
                    .foregroundStyle(Color.red.opacity(0.7))
                    .multilineTextAlignment(.center)
            }
        }
    }
}

// MARK: - Pro Feature Model

struct ProFeature: Identifiable {
    let id: String
    let icon: String
    let title: String
    let subtitle: String

    static let all: [ProFeature] = [
        .init(id: "trips",   icon: "airplane.circle.fill",  title: "Unlimited Trips",         subtitle: "Free tier is limited to 2 active trips"),
        .init(id: "share",   icon: "person.2.circle.fill",  title: "Collaborative Sharing",   subtitle: "Invite friends to plan & edit trips together"),
        .init(id: "map",     icon: "map.circle.fill",       title: "Travel Map",              subtitle: "Interactive globe showing all your visited places"),
        .init(id: "weather", icon: "cloud.sun.circle.fill", title: "Weather Forecast",        subtitle: "10-day forecast for your trip dates"),
        .init(id: "receipt", icon: "camera.circle.fill",    title: "Receipt Photos",          subtitle: "Attach photos to expenses for easy tracking"),
        .init(id: "split",   icon: "equal.circle.fill",     title: "Expense Splitting",       subtitle: "Split costs evenly across your crew"),
        .init(id: "pdf",     icon: "doc.circle.fill",       title: "PDF Export",              subtitle: "Export a printable day-by-day itinerary"),
        .init(id: "widget",  icon: "rectangle.stack.badge.plus", title: "Countdown Widget",   subtitle: "\"X days to Tokyo\" on your Home Screen"),
        .init(id: "clip",    icon: "safari",                title: "Web Clip to Atlas",       subtitle: "Save restaurants & hotels from Safari instantly"),
    ]
}

// MARK: - Pro Feature Row

private struct ProFeatureRow: View {
    let feature: ProFeature

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: feature.icon)
                .font(.system(size: 26, weight: .light))
                .foregroundStyle(Color.atlasTeal)
                .frame(width: 36)

            VStack(alignment: .leading, spacing: 2) {
                Text(feature.title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.atlasBlack)
                Text(feature.subtitle)
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(Color.atlasBlack.opacity(0.45))
            }

            Spacer()

            Image(systemName: "checkmark")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.atlasTeal)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
    }
}

// MARK: - Pro Badge

/// Small inline badge to show on locked UI elements
struct ProBadge: View {
    var body: some View {
        Text("PRO")
            .font(.system(size: 9, weight: .bold, design: .monospaced))
            .foregroundStyle(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(Color.atlasBlack)
            .clipShape(Capsule())
    }
}

// MARK: - Pro Lock Overlay

/// Full-area lock overlay for blurred Pro-gated sections
struct ProLockOverlay: View {
    let label: String
    let action: () -> Void

    var body: some View {
        ZStack {
            Color.atlasBeige.opacity(0.85)
                .background(.ultraThinMaterial)

            VStack(spacing: 12) {
                Image(systemName: "lock.circle.fill")
                    .font(.system(size: 40, weight: .light))
                    .foregroundStyle(Color.atlasBlack.opacity(0.3))

                Text(label)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.atlasBlack.opacity(0.6))
                    .multilineTextAlignment(.center)

                Button(action: action) {
                    Text("Unlock with Pro")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(Color.atlasBlack)
                        .clipShape(Capsule())
                }
                .buttonStyle(ScaleButtonStyle())
            }
            .padding(20)
        }
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }
}
