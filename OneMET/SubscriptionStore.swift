import Foundation
import StoreKit

// SubscriptionStore.swift — OneMET Pro, the auto-renewable subscription behind the fuel
// plan and the carbohydrate advice in workout insights. Summary, the workout history and
// its curves, and browsing the sport cards stay free.
//
// StoreKit 2 only: Apple signs every transaction and StoreKit checks the signature on the
// device, so there is no OneMET server to ask whether someone is subscribed. The product
// ids below must match the subscriptions created in App Store Connect (Monetization ▸
// Subscriptions, one group holding both). The 7-day free trial is an introductory offer
// configured there, not here — the paywall only reads it back.

enum ProProduct {
    static let yearly  = "com.jmaiora.onemet.pro.yearly"
    static let monthly = "com.jmaiora.onemet.pro.monthly"
    /// Display order on the paywall: yearly first, as the default choice.
    static let all = [yearly, monthly]
}

@MainActor
final class SubscriptionStore: ObservableObject {
    /// Off ships the app with everything open — for a build that has to go out before the
    /// subscriptions exist in App Store Connect, when the paywall could only say
    /// "not available" and would lock testers out of the fuel plan.
    static let paywallEnabled = true

    @Published private(set) var products: [Product] = []
    @Published private(set) var isPro = !SubscriptionStore.paywallEnabled
    @Published private(set) var activeProductId: String?
    @Published private(set) var expirationDate: Date?
    @Published private(set) var willRenew = true
    /// Whether this Apple Account can still take the free trial — once per subscription
    /// group, so someone who already had it sees the plain price instead.
    @Published private(set) var trialEligible = false
    @Published private(set) var loading = false
    @Published private(set) var purchasing = false
    @Published var paywallShown = false
    /// Localization key of the last purchase/restore outcome worth telling the person.
    @Published var noticeKey: String?

    /// What the person was reaching for when the paywall opened — opening the fuel plan,
    /// say. Runs once they're subscribed, so buying lands them where they meant to go.
    private var onUnlock: (() -> Void)?
    private var updates: Task<Void, Never>?

    init() {
        guard Self.paywallEnabled else { return }
        // Renewals, refunds, Ask to Buy approvals and purchases made on another device all
        // arrive here, not as the result of a purchase() call.
        updates = Task { [weak self] in
            for await result in Transaction.updates {
                if case .verified(let transaction) = result { await transaction.finish() }
                await self?.refreshEntitlements()
            }
        }
        Task {
            await loadProducts()
            await refreshEntitlements()
        }
    }

    // MARK: Gate

    /// Runs `action` straight away for subscribers; otherwise opens the paywall and runs it
    /// after a successful purchase or restore.
    func requirePro(_ action: @escaping () -> Void) {
        if isPro { action(); return }
        onUnlock = action
        noticeKey = nil
        paywallShown = true
        // Ask again whenever a plan is missing, so a product made live in App Store Connect
        // after launch shows up without restarting the app.
        if products.count < ProProduct.all.count { Task { await loadProducts() } }
    }

    /// The sheet went away without a purchase: forget what it was going to unlock.
    func paywallDismissed() {
        onUnlock = nil
        noticeKey = nil
    }

    private func unlock() {
        let action = onUnlock
        onUnlock = nil
        paywallShown = false
        // Let the sheet start sliding away before the action pushes the next screen.
        if let action {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { action() }
        }
    }

    // MARK: StoreKit

    func loadProducts() async {
        loading = true
        defer { loading = false }
        let loaded = (try? await Product.products(for: ProProduct.all)) ?? []
        products = loaded.sorted {
            (ProProduct.all.firstIndex(of: $0.id) ?? 0) < (ProProduct.all.firstIndex(of: $1.id) ?? 0)
        }
        if let sub = products.first?.subscription {
            trialEligible = await sub.isEligibleForIntroOffer
        }
    }

    func refreshEntitlements() async {
        // currentEntitlements already leaves out expired and refunded subscriptions, and
        // keeps one that's in a billing grace period.
        var active: Transaction?
        for await result in Transaction.currentEntitlements {
            guard case .verified(let t) = result, ProProduct.all.contains(t.productID),
                  t.revocationDate == nil else { continue }
            if (t.expirationDate ?? .distantFuture) > (active?.expirationDate ?? .distantPast) {
                active = t
            }
        }
        isPro = active != nil
        activeProductId = active?.productID
        expirationDate = active?.expirationDate
        willRenew = true
        if let id = active?.productID,
           let sub = products.first(where: { $0.id == id })?.subscription,
           let statuses = try? await sub.status, let status = statuses.first,
           case .verified(let info) = status.renewalInfo {
            willRenew = info.willAutoRenew
        }
        if let sub = products.first?.subscription {
            trialEligible = await sub.isEligibleForIntroOffer
        }
        // A subscription that arrives while the paywall is up — Ask to Buy approved, or
        // bought on another device — finishes the job the paywall was opened for.
        if isPro && paywallShown { unlock() }
    }

    func purchase(_ product: Product) async {
        purchasing = true
        noticeKey = nil
        defer { purchasing = false }
        do {
            switch try await product.purchase() {
            case .success(.verified(let transaction)):
                await transaction.finish()
                await refreshEntitlements()
            case .success(.unverified):
                noticeKey = "pro.failed"
            case .pending:
                // Ask to Buy or a bank check: Transaction.updates delivers it later.
                noticeKey = "pro.pending"
            case .userCancelled:
                break
            @unknown default:
                break
            }
        } catch {
            noticeKey = "pro.failed"
        }
    }

    func restore() async {
        noticeKey = nil
        do {
            try await AppStore.sync()
        } catch {
            // Cancelling the Apple Account prompt isn't worth a message.
            if let e = error as? StoreKitError, case .userCancelled = e { return }
        }
        let wasShown = paywallShown
        await refreshEntitlements()
        noticeKey = isPro ? (wasShown ? nil : "pro.restored") : "pro.nothingToRestore"
    }
}
