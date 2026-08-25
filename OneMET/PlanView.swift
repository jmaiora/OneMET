import SwiftUI

// PlanView.swift — OneMET Plan tab: a prevention-first run guide.
// Favours adjusting insulin beforehand and minimising interventions during the run,
// matched to duration and driven by glucose trend. Illustrative — not medical advice.

struct PlanView: View {
    @EnvironmentObject var store: HealthDataStore
    @EnvironmentObject var profileStore: ProfileStore
    var accent: Color
    var lang: AppLanguage = .en

    @State private var sportIndex = 0
    @State private var duration = 45
    @State private var iob = 1.0
    @State private var difficulty: WorkoutDifficulty = SPORTS[0].difficulty

    var body: some View {
        let d = store.data
        let sport = SPORTS[sportIndex]
        let glucose: Double? = d.hasGlucose ? d.current : nil
        let trend = d.currentTrend
        let gStatus = glucose.map { glucoseStatus($0, low: d.targetLow, high: d.targetHigh) }
        let unit = profileStore.profile.glucoseUnit
        let guide = buildRunGuide(sportId: sport.id, durationMin: duration, iob: iob,
                                  glucoseMgdl: glucose,
                                  trendFalling: trend == .down, trendRising: trend == .up,
                                  deliveryIsPump: profileStore.profile.insulinDelivery.isPump,
                                  difficulty: difficulty, unit: unit, lang: lang)

        ScreenScaffold {
            AppHeader(title: lang.t("plan.title"), date: lang.t("plan.runGuide"),
                      initials: profileStore.profile.initials, accent: accent)

            Card(title: lang.t("plan.sessionDetails"), icon: "calendar", iconColor: accent) {
                SportPicker(sports: SPORTS, index: $sportIndex, accent: accent,
                            durationLabel: "\(duration) \(lang.t("workouts.min"))",
                            difficultyLabel: difficulty.label(lang), lang: lang)
                    .padding(.bottom, 2)
                SelectRow(label: lang.t("plan.plannedDuration"), selection: $duration,
                          options: [15, 30, 45, 60, 75, 90, 120, 150, 180].map {
                              (value: $0, label: "\($0) \(lang.t("workouts.min"))")
                          }, accent: accent)
                HStack {
                    Text(lang.t("plan.difficulty"))
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(Theme.ink)
                    Spacer()
                    Menu {
                        ForEach(WorkoutDifficulty.allCases) { d in
                            Button(d.label(lang)) { difficulty = d }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Text(difficulty.label(lang))
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(accent)
                            AppIconView(name: "chevron", color: Theme.ink3, size: 13)
                        }
                    }
                }
                .padding(.vertical, 11)
                .overlay(Rectangle().fill(Theme.sep).frame(height: 0.5), alignment: .bottom)
            }

            Card(title: lang.t("plan.currentState"), icon: "bolt", iconColor: Theme.amber) {
                HStack {
                    Text(lang.t("plan.currentGlucose"))
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(Theme.ink)
                    Spacer()
                    if let g = glucose, let st = gStatus {
                        HStack(spacing: 5) {
                            Text(unit.value(g)).font(.system(size: 15, weight: .semibold)).foregroundStyle(st.color).monospacedDigit()
                            Text(unit.rawValue).font(.system(size: 13)).foregroundStyle(Theme.ink2)
                            TrendArrow(dir: trend, color: st.color)
                        }
                    } else {
                        Text("—").font(.system(size: 15, weight: .semibold)).foregroundStyle(Theme.ink3)
                    }
                }
                .padding(.vertical, 11)
                .overlay(Rectangle().fill(Theme.sep).frame(height: 0.5), alignment: .bottom)

                SelectRow(label: lang.t("plan.iob"), selection: $iob,
                          options: [0, 0.5, 1.0, 1.5, 2.0, 3.0].map { (value: $0, label: String(format: "%.1f U", $0)) }, accent: accent)
            }

            startBanner(guide)

            duringBanner(guide)

            Card(title: lang.t("plan.goodToKnow")) {
                VStack(alignment: .leading, spacing: 12) {
                    goodLine("checkmark.seal.fill", Theme.green, guide.philosophyText)
                    goodLine("chart.line.uptrend.xyaxis", accent, guide.learnText)
                }
            }

            disclaimer
        }
        .onChange(of: sportIndex) { newIndex in
            difficulty = SPORTS[newIndex].difficulty
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

    private func duringBanner(_ g: RunGuide) -> some View {
        let c = Theme.ringMet
        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                AppIconView(name: "fork", color: .white, size: 16)
                Text(lang.t("plan.during", difficulty.label(lang)))
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)
                Spacer(minLength: 8)
                Text(g.bandDetail.uppercased())
                    .font(.system(size: 10.5, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.85))
                    .tracking(0.2)
                    .multilineTextAlignment(.trailing)
            }
            if g.duringTotalG > 0 {
                HStack(alignment: .top, spacing: 22) {
                    if g.duringStartG > 0 {
                        duringStat(big: "~\(g.duringStartG) g", small: lang.t("plan.atStart"))
                    }
                    if g.duringFeeds > 0 {
                        duringStat(big: "~\(g.duringPerFeedG) g",
                                   small: lang.t("plan.everyMin", String(g.duringIntervalMin)))
                    }
                }
                Text(lang.t("plan.perHourTotal", String(g.duringPerHourG), String(g.duringTotalG)))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.85))
            }
            (Text(g.duringText)
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

#Preview {
    ZStack(alignment: .bottom) {
        Theme.bg.ignoresSafeArea()
        PlanView(accent: Theme.accent)
            .environmentObject(HealthDataStore())
            .environmentObject(ProfileStore())
    }
}
