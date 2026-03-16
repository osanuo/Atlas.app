//
//  SubscriptionManager.swift
//  Atlas
//

import Foundation
import StoreKit
import Observation

// MARK: - Subscription Manager

@Observable
final class SubscriptionManager {

    static let shared = SubscriptionManager()

    // MARK: - Product IDs

    static let monthlyID = "atlas.pro.monthly"
    static let annualID  = "atlas.pro.annual"

    // MARK: - State

    private(set) var products: [Product] = []
    private(set) var isPro: Bool
    private(set) var activeProductID: String?
    var purchaseError: String?
    var isLoading = false

    private var transactionListener: Task<Void, Never>?

    // MARK: - Init

    private init() {
        // Restore cached state instantly (before async finishes) so UI is correct on cold launch
        let cached = UserDefaults.standard.bool(forKey: "atlas_isPro")
        let devOverride = UserDefaults.standard.bool(forKey: "atlas_devProOverride")
        isPro = cached || devOverride

        transactionListener = listenForTransactions()
        Task { await loadProducts() }
        Task { await refreshEntitlements() }
    }

    deinit { transactionListener?.cancel() }

    // MARK: - Products

    func loadProducts() async {
        do {
            let fetched = try await Product.products(for: [Self.monthlyID, Self.annualID])
            await MainActor.run {
                products = fetched.sorted { $0.price < $1.price }
            }
        } catch {
            print("[SubscriptionManager] loadProducts failed: \(error)")
        }
    }

    // MARK: - Purchase

    func purchase(_ product: Product) async {
        await MainActor.run { isLoading = true; purchaseError = nil }
        defer { Task { await MainActor.run { isLoading = false } } }

        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)
                await transaction.finish()
                await refreshEntitlements()
            case .userCancelled:
                break
            case .pending:
                break
            @unknown default:
                break
            }
        } catch {
            await MainActor.run {
                purchaseError = error.localizedDescription
            }
        }
    }

    // MARK: - Restore

    func restorePurchases() async {
        await MainActor.run { isLoading = true }
        defer { Task { await MainActor.run { isLoading = false } } }
        try? await AppStore.sync()
        await refreshEntitlements()
    }

    // MARK: - Entitlements

    @MainActor
    func refreshEntitlements() async {
        var hasPro = UserDefaults.standard.bool(forKey: "atlas_devProOverride")
        var foundProductID: String? = nil

        if !hasPro {
            for await result in Transaction.currentEntitlements {
                if case .verified(let tx) = result,
                   (tx.productID == Self.monthlyID || tx.productID == Self.annualID),
                   tx.revocationDate == nil {
                    hasPro = true
                    foundProductID = tx.productID
                    break
                }
            }
        }

        isPro = hasPro
        activeProductID = foundProductID
        UserDefaults.standard.set(hasPro, forKey: "atlas_isPro")

        // Write to shared UserDefaults so Widget can read Pro status
        let shared = UserDefaults(suiteName: "group.com.osanuo.Atlas")
        shared?.set(hasPro, forKey: "atlas_isPro")
    }

    // MARK: - Transaction Listener

    private func listenForTransactions() -> Task<Void, Never> {
        Task.detached(priority: .background) { [weak self] in
            for await result in Transaction.updates {
                guard let self else { return }
                if case .verified(let tx) = result {
                    await tx.finish()
                    await self.refreshEntitlements()
                }
            }
        }
    }

    // MARK: - Verification

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified: throw SubscriptionError.failedVerification
        case .verified(let value): return value
        }
    }

    // MARK: - Convenience

    var monthlyProduct: Product? { products.first(where: { $0.id == Self.monthlyID }) }
    var annualProduct:  Product? { products.first(where: { $0.id == Self.annualID }) }

    /// Formatted dollar amount saved by choosing annual over 12× monthly (e.g. "$34.89")
    var annualSavingsDollars: String? {
        guard let m = monthlyProduct, let a = annualProduct, m.price > 0 else { return nil }
        let annualEquivalent = m.price * 12
        guard annualEquivalent > a.price else { return nil }
        let savings = annualEquivalent - a.price
        return savings.formatted(m.priceFormatStyle)
    }

    /// True when the annual product has a free-trial introductory offer configured in App Store Connect.
    var annualHasTrial: Bool {
        annualProduct?.subscription?.introductoryOffer?.paymentMode == .freeTrial
    }

    /// Human-readable trial duration string, e.g. "7-day" (derived from the StoreKit offer period).
    var annualTrialLabel: String {
        guard
            let offer = annualProduct?.subscription?.introductoryOffer,
            offer.paymentMode == .freeTrial
        else { return "7-day" }
        let value = offer.period.value
        switch offer.period.unit {
        case .day:   return "\(value)-day"
        case .week:  return "\(value)-week"
        case .month: return "\(value)-month"
        default:     return "\(value)-day"
        }
    }

    // MARK: - Dev Toggle (DEBUG only)

#if DEBUG
    func toggleDevPro() {
        let current = UserDefaults.standard.bool(forKey: "atlas_devProOverride")
        UserDefaults.standard.set(!current, forKey: "atlas_devProOverride")
        isPro = !current
    }
#endif
}

// MARK: - Error

enum SubscriptionError: Error {
    case failedVerification
}
