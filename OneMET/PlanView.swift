import SwiftUI

// PlanView.swift — OneMET Plan tab: a prevention-first run guide.
// Favours adjusting insulin beforehand and minimising interventions during the run,
// matched to duration and driven by glucose trend. Illustrative — not medical advice.

struct PlanView: View {
    @EnvironmentObject var store: HealthDataStore
    @EnvironmentObject var profileStore: ProfileStore
    var accent: Color

    @State private var sportIndex = 0
    @State private var duration = 45
    @State private var iob = 1.0
    @State private var recentCarbs = 30

    var body: some View {
        let d = store.data
        let sport = SPORTS[sportIndex]
        let glucose: Double? = d.hasGlucose ? d.current : nil
        let trend = d.currentTrend
        let gStatus = glucose.map { glucoseStatus($0, low: d.targetLow, high: d.targetHigh) }
        let guide = buildRunGuide(sportId: sport.id, durationMin: duration, iob: iob,
                                  recentCarbsG: recentCarbs, glucoseMgdl: glucose,
                                  trendFalling: trend == .down, trendRising: trend == .up,
                                  deliveryIsPump: profileStore.profile.insulinDelivery.isPump)

        ScreenScaffold {
            AppHeader(title: "Plan", date: "Run Guide", accent: accent)

            Card(title: "Session Details", icon: "calendar", iconColor: accent) {
                SportPicker(sports: SPORTS, index: $sportIndex, accent: accent, durationLabel: "\(duration) min")
                    .padding(.bottom, 2)
                SelectRow(label: "Planned Duration", selection: $duration,
                          options: [15, 30, 45, 60, 75, 90, 120].map { (value: $0, label: "\($0) min") }, accent: accent)
            }

            Card(title: "Current State", icon: "bolt", iconColor: Theme.amber) {
                HStack {
                    Text("Current Glucose")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(Theme.ink)
                    Spacer()
                    if let g = glucose, let st = gStatus {
                        HStack(spacing: 5) {
                            Text("\(Int(g))").font(.system(size: 15, weight: .semibold)).foregroundStyle(st.color).monospacedDigit()
                            Text("mg/dL").font(.system(size: 13)).foregroundStyle(Theme.ink2)
                            TrendArrow(dir: trend, color: st.color)
                        }
                    } else {
                        Text("—").font(.system(size: 15, weight: .semibold)).foregroundStyle(Theme.ink3)
                    }
                }
                .padding(.vertical, 11)
                .overlay(Rectangle().fill(Theme.sep).frame(height: 0.5), alignment: .bottom)

                SelectRow(label: "Insulin Delivery",
                          selection: Binding(get: { profileStore.profile.insulinDelivery },
                                             set: { profileStore.profile.insulinDelivery = $0 }),
                          options: InsulinDelivery.allCases.map { (value: $0, label: $0.rawValue) }, accent: accent)
                SelectRow(label: "Insulin on Board", selection: $iob,
                          options: [0, 0.5, 1.0, 1.5, 2.0, 3.0].map { (value: $0, label: String(format: "%.1f U", $0)) }, accent: accent)
                SelectRow(label: "Carbs, Last 2h", selection: $recentCarbs,
                          options: [0, 15, 30, 45, 60, 90].map { (value: $0, label: "\($0) g") }, accent: accent)
            }

            startBanner(guide)

            infoCard(icon: "bolt", color: accent, title: "Before you run", text: guide.beforeText)

            infoCard(icon: "fork", color: Theme.ringMet, title: "During · \(guide.band) run",
                     text: guide.duringText, headline: guide.duringHeadline, subtitle: guide.bandDetail)

            Card(title: "Good to know") {
                VStack(alignment: .leading, spacing: 12) {
                    goodLine("checkmark.seal.fill", Theme.green, guide.philosophyText)
                    goodLine("chart.line.uptrend.xyaxis", accent, guide.learnText)
                }
            }

            disclaimer
            sources
        }
    }

    // MARK: - Start decision banner

    private func startBanner(_ g: RunGuide) -> some View {
        let s = statusStyle(g.status)
        return VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 8) {
                Image(systemName: s.icon).font(.system(size: 18, weight: .bold)).foregroundStyle(.white)
                Text(g.startTitle)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.white)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Text(g.startReason)
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

    // MARK: - Guidance cards

    private func infoCard(icon: String, color: Color, title: String, text: String,
                          headline: String? = nil, subtitle: String? = nil) -> some View {
        Card(title: title, icon: icon, iconColor: color) {
            VStack(alignment: .leading, spacing: 8) {
                if let subtitle {
                    Text(subtitle.uppercased())
                        .font(.system(size: 11.5, weight: .semibold))
                        .foregroundStyle(Theme.ink2)
                        .tracking(0.2)
                }
                if let headline {
                    Text(headline)
                        .font(.system(size: 26, weight: .bold))
                        .foregroundStyle(Theme.ink)
                }
                Text(text)
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.ink)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func goodLine(_ systemIcon: String, _ color: Color, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 9) {
            Image(systemName: systemIcon).font(.system(size: 15)).foregroundStyle(color).frame(width: 20)
            Text(text)
                .font(.system(size: 13.5))
                .foregroundStyle(Theme.ink)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Disclaimer + sources

    private var disclaimer: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 13))
                .foregroundStyle(Theme.amber)
            Text("Illustrative guidance, not medical advice. Insulin changes and carbohydrate decisions should be agreed with your clinician.")
                .font(.system(size: 12.5, weight: .medium))
                .foregroundStyle(Theme.ink2)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.amber.opacity(0.10))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var sources: some View {
        Text("Approach: a prevention-first, real-world interpretation of the 2017 Lancet consensus on exercise in type 1 diabetes (Riddell et al.) and EXTOD, oriented to recreational running.")
            .font(.system(size: 11.5))
            .foregroundStyle(Theme.ink3)
            .lineSpacing(2)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 4)
    }
}

#Preview {
    ZStack(alignment: .bottom) {
        Theme.bg.ignoresSafeArea()
        PlanView(accent: Theme.accent)
            .environmentObject(HealthDataStore())
            .environmentObject(ProfileStore())
    }
}
