import SwiftUI

// CarbPlanView.swift — the answer screen for the Plan tab.
//
// Everything here is a conclusion drawn from what you set on the Plan tab: whether to
// start, what to eat during, and the caveats. Splitting it off keeps the planning tab to
// inputs only, and means the numbers arrive as a deliberate act rather than shifting
// under you while you drag a dial.
//
// Illustrative guidance, NOT medical advice.

struct CarbPlanView: View {
    var guide: RunGuide
    var sport: Sport
    var durationMin: Int
    var met: Double
    var accent: Color
    var unit: GlucoseUnit = .mgdl
    var lang: AppLanguage = .en
    var onBack: () -> Void

    private var difficulty: WorkoutDifficulty { WorkoutDifficulty(met: met) }

    var body: some View {
        ScreenScaffold {
            BackBar(title: lang.t("plan.title"), accent: accent, action: onBack)

            VStack(alignment: .leading, spacing: 2) {
                // Restates the session this plan is for, so the numbers can't be read
                // against the wrong assumptions once you've scrolled away from the dials.
                Text(lang.t("plan.forSession", sport.name(lang), String(durationMin),
                            fmtNum((met * 10).rounded() / 10)).uppercased())
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundStyle(Theme.ink2)
                    .tracking(0.2)
                    .fixedSize(horizontal: false, vertical: true)
                Text(lang.t("plan.carbPlan"))
                    .font(.system(size: 32, weight: .bold))
                    .foregroundStyle(Theme.ink)
                    // The Spanish title runs to two lines; let it, rather than truncate.
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            startBanner

            duringBanner

            // Two headlines, both bold beside their icon — the reasoning behind each is in
            // Settings ▸ Help & FAQ.
            Card(title: lang.t("plan.goodToKnow")) {
                VStack(alignment: .leading, spacing: 14) {
                    goodEntry("checkmark.seal.fill", Theme.green,
                              lang.t("philosophy.short", unit.range(140, 200)), nil)
                    goodEntry("chart.line.uptrend.xyaxis", accent,
                              lang.t("learn.short"), nil)
                }
            }

            disclaimer
        }
    }

    // MARK: - Start decision banner

    private var startBanner: some View {
        let s = statusStyle(guide.status)
        return VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 8) {
                Image(systemName: s.icon).font(.system(size: 18, weight: .bold)).foregroundStyle(.white)
                Text(guide.startTitle)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.white)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Text(guide.startReason)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.white.opacity(0.95))
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(s.color)
        .clipShape(RoundedRectangle(cornerRadius: Theme.radius, style: .continuous))
        .shadow(color: s.color.opacity(0.28), radius: 9, x: 0, y: 6)
    }

    private func statusStyle(_ status: StartStatus) -> (color: Color, icon: String) {
        switch status {
        case .go:      return (Theme.green, "checkmark.circle.fill")
        case .topUp:   return (Theme.amber, "plus.circle.fill")
        case .wait:    return (Theme.amber, "exclamationmark.circle.fill")
        case .stop:    return (Theme.red, "xmark.octagon.fill")
        case .unknown: return (Color(hex: "8E8E93"), "questionmark.circle.fill")
        }
    }

    // MARK: - During

    private var duringBanner: some View {
        let c = Theme.ringMet
        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                AppIconView(name: "fork", color: .white, size: 16)
                Text(lang.t("plan.during", difficulty.label(lang)))
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)
                Spacer(minLength: 8)
                Text(guide.bandDetail.uppercased())
                    .font(.system(size: 10.5, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.85))
                    .tracking(0.2)
                    .multilineTextAlignment(.trailing)
            }
            if guide.duringTotalG > 0 {
                HStack(alignment: .top, spacing: 22) {
                    if guide.duringStartG > 0 {
                        duringStat(big: "~\(guide.duringStartG) g", small: lang.t("plan.atStart"))
                    }
                    if guide.duringFeeds > 0 {
                        duringStat(big: "~\(guide.duringPerFeedG) g",
                                   small: lang.t("plan.everyMin", String(guide.duringIntervalMin)))
                    }
                }
                Text(lang.t("plan.perHourTotal", String(guide.duringPerHourG), String(guide.duringTotalG)))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.85))
            }
            (Text(guide.duringText)
                + Text("1").font(.system(size: 9, weight: .bold)).baselineOffset(6))
                .font(.system(size: 13.5, weight: .medium))
                .foregroundStyle(.white.opacity(0.95))
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(c)
        .clipShape(RoundedRectangle(cornerRadius: Theme.radius, style: .continuous))
        .shadow(color: c.opacity(0.28), radius: 9, x: 0, y: 6)
    }

    private func duringStat(big: String, small: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(big)
                .font(.system(size: 27, weight: .heavy))
                .foregroundStyle(.white)
            Text(small)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.white.opacity(0.8))
                .tracking(0.3)
        }
    }

    /// A Good-to-know row: heading beside the icon, with an optional line underneath for
    /// the points that have a longer explanation waiting in Help & FAQ.
    private func goodEntry(_ systemIcon: String, _ color: Color,
                           _ title: String, _ text: String?) -> some View {
        HStack(alignment: .top, spacing: 9) {
            Image(systemName: systemIcon).font(.system(size: 15)).foregroundStyle(color).frame(width: 20)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 13.5, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                if let text {
                    Text(text)
                        .font(.system(size: 13.5))
                        .foregroundStyle(Theme.ink2)
                }
            }
            .lineSpacing(2)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - Disclaimer + sources

    private var disclaimer: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.amber)
                Text(lang.t("plan.disclaimer"))
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundStyle(Theme.ink2)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            (Text("1").font(.system(size: 9, weight: .bold)).baselineOffset(4)
                + Text(lang.t("plan.sources")))
                .font(.system(size: 11.5))
                .foregroundStyle(Theme.ink2)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.amber.opacity(0.10))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}
