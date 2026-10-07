import SwiftUI
import StoreKit

// PaywallView.swift — the OneMET Pro sheet, opened from "Get my fuel plan" and from a
// locked workout insight.
//
// A custom screen rather than StoreKit's SubscriptionStoreView, which needs iOS 17. It
// carries what App Review checks for auto-renewable subscriptions (Guideline 3.1.2): what
// the subscription includes, each plan's length and price, what happens when the free
// trial ends, a Restore button, and links to the Terms of Use and the Privacy Policy.
// Prices, the trial length and its eligibility all come from StoreKit, so they're always
// in the person's own currency and match what App Store Connect is set to.

struct PaywallView: View {
    @ObservedObject var subs: SubscriptionStore
    var accent: Color
    var lang: AppLanguage

    @State private var selectedId = ProProduct.yearly

    /// Apple's standard licence agreement — what applies when no custom EULA is set.
    private let termsURL = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!
    private var privacyURL: URL {
        URL(string: lang == .es ? "https://sites.google.com/view/jmaiora/privacidad"
                                : "https://sites.google.com/view/jmaiora/privacy")!
    }

    private var selected: Product? {
        subs.products.first { $0.id == selectedId } ?? subs.products.first
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Theme.bg.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 18) {
                    header
                    benefits
                    plans
                    purchaseButton
                    if let key = subs.noticeKey {
                        Text(lang.t(key))
                            .font(Theme.fineFont.weight(.medium))
                            .foregroundStyle(key == "pro.pending" ? Theme.ink2 : Theme.red)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    footer
                }
                .padding(.horizontal, 20)
                .padding(.top, 40)
                .padding(.bottom, 28)
            }

            Button { subs.paywallShown = false } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.app(size: 28))
                    .foregroundStyle(Theme.ink3)
            }
            .accessibilityLabel(lang.t("pro.close"))
            .padding(14)
        }
        .preferredColorScheme(.light)
    }

    // MARK: Sections

    private var header: some View {
        VStack(spacing: 10) {
            Image(systemName: "fork.knife")
                .font(.app(size: 30, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 72, height: 72)
                .background(accent)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .shadow(color: accent.opacity(0.3), radius: 10, x: 0, y: 6)
            Text(lang.t("pro.title"))
                .font(.app(size: 30, weight: .bold))
                .foregroundStyle(Theme.ink)
            Text(lang.t("pro.subtitle"))
                .font(Theme.noteFont)
                .foregroundStyle(Theme.ink2)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var benefits: some View {
        Card(pad: 16) {
            VStack(alignment: .leading, spacing: 14) {
                benefit("fork.knife", lang.t("pro.benefit.plan"))
                benefit("waveform.path.ecg", lang.t("pro.benefit.insight"))
                benefit("person.crop.circle.badge.checkmark", lang.t("pro.benefit.personal"))
                Text(lang.t("pro.free"))
                    .font(Theme.fineFont)
                    .foregroundStyle(Theme.ink2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func benefit(_ symbol: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: symbol)
                .font(.app(size: 17, weight: .semibold))
                .foregroundStyle(accent)
                .frame(width: 26)
            Text(text)
                .font(.app(size: 16, weight: .medium))
                .foregroundStyle(Theme.ink)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    @ViewBuilder
    private var plans: some View {
        if subs.products.isEmpty {
            VStack(spacing: 10) {
                if subs.loading {
                    ProgressView()
                } else {
                    Text(lang.t("pro.unavailable"))
                        .font(Theme.fineFont)
                        .foregroundStyle(Theme.ink2)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                    Button(lang.t("pro.retry")) { Task { await subs.loadProducts() } }
                        .font(.app(size: 16, weight: .semibold))
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
        } else {
            VStack(spacing: 10) {
                ForEach(subs.products, id: \.id) { planRow($0) }
            }
        }
    }

    private func planRow(_ product: Product) -> some View {
        let isSelected = product.id == selected?.id
        return Button { selectedId = product.id } label: {
            HStack(spacing: 12) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.app(size: 22))
                    .foregroundStyle(isSelected ? accent : Theme.ink3)
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 8) {
                        Text(lang.t(isYearly(product) ? "pro.yearly" : "pro.monthly"))
                            .font(.app(size: 17, weight: .bold))
                            .foregroundStyle(Theme.ink)
                        if let save = savingsText(product) {
                            Text(save)
                                .font(.app(size: 12.5, weight: .bold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Theme.green, in: Capsule())
                        }
                    }
                    Text(priceLine(product))
                        .font(.app(size: 15, weight: .medium))
                        .foregroundStyle(Theme.ink2)
                        .fixedSize(horizontal: false, vertical: true)
                    if let perMonth = perMonthLine(product) {
                        Text(perMonth)
                            .font(.app(size: 13.5))
                            .foregroundStyle(Theme.ink2)
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(14)
            .background(Theme.card)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(isSelected ? accent : Theme.sep, lineWidth: isSelected ? 2 : 1)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var purchaseButton: some View {
        Button {
            if let p = selected { Task { await subs.purchase(p) } }
        } label: {
            ZStack {
                if subs.purchasing {
                    ProgressView().tint(.white)
                } else {
                    Text(buttonTitle)
                        .font(.app(size: 17, weight: .bold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                }
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background(accent)
            .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
            .shadow(color: accent.opacity(0.3), radius: 10, x: 0, y: 6)
        }
        .buttonStyle(.plain)
        .disabled(selected == nil || subs.purchasing)
        .opacity(selected == nil ? 0.5 : 1)
    }

    private var footer: some View {
        VStack(spacing: 12) {
            Text(lang.t("pro.legal"))
                .font(.app(size: 13))
                .foregroundStyle(Theme.ink2)
                .multilineTextAlignment(.center)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 6) {
                Button(lang.t("pro.restore")) { Task { await subs.restore() } }
                Text("·").foregroundStyle(Theme.ink3)
                Link(lang.t("pro.terms"), destination: termsURL)
                Text("·").foregroundStyle(Theme.ink3)
                Link(lang.t("pro.privacy"), destination: privacyURL)
            }
            .font(.app(size: 13.5, weight: .semibold))
            .lineLimit(1)
            .minimumScaleFactor(0.75)
            Text(lang.t("pro.notMedical"))
                .font(.app(size: 13))
                .foregroundStyle(Theme.ink3)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: Wording from StoreKit

    private func isYearly(_ p: Product) -> Bool {
        p.subscription?.subscriptionPeriod.unit == .year
    }

    /// The introductory free trial, if this account can still take it.
    private func freeTrial(_ p: Product) -> Product.SubscriptionOffer? {
        guard subs.trialEligible, let offer = p.subscription?.introductoryOffer,
              offer.paymentMode == .freeTrial else { return nil }
        return offer
    }

    private func priceLine(_ p: Product) -> String {
        let price = lang.t(isYearly(p) ? "pro.perYear" : "pro.perMonth", p.displayPrice)
        guard let trial = freeTrial(p) else { return price }
        return lang.t("pro.trialThen", periodText(trial.period), price)
    }

    private func perMonthLine(_ p: Product) -> String? {
        guard isYearly(p) else { return nil }
        return lang.t("pro.yearlyPerMonth", (p.price / 12).formatted(p.priceFormatStyle))
    }

    private func savingsText(_ p: Product) -> String? {
        guard isYearly(p),
              let monthly = subs.products.first(where: { !isYearly($0) }), monthly.price > 0 else { return nil }
        let ratio = NSDecimalNumber(decimal: p.price / (monthly.price * 12)).doubleValue
        let pct = Int(((1 - ratio) * 100).rounded())
        return pct >= 5 ? lang.t("pro.save", String(pct)) : nil
    }

    private var buttonTitle: String {
        if let p = selected, let trial = freeTrial(p) {
            return lang.t("pro.tryFree", periodText(trial.period))
        }
        return lang.t("pro.subscribe")
    }

    /// A 1-week trial reads as "7 days", the way it's promoted.
    private func periodText(_ period: Product.SubscriptionPeriod) -> String {
        switch period.unit {
        case .day:   return lang.t("pro.nDays", String(period.value))
        case .week:  return lang.t("pro.nDays", String(period.value * 7))
        case .month: return period.value == 1 ? lang.t("pro.oneMonth") : lang.t("pro.nMonths", String(period.value))
        case .year:  return lang.t("pro.oneYear")
        @unknown default: return ""
        }
    }
}
