import SwiftUI

// PlanView.swift — OneMET Plan tab: the inputs for a prevention-first session guide.
//
// This screen only collects: which sport, how long, how hard, and where your glucose is
// right now. The conclusions drawn from those — whether to start, what to eat during, the
// caveats — live in CarbPlanView behind the Calculate button, so the numbers arrive as a
// deliberate act rather than shifting under you while you drag a dial.
//
// Illustrative guidance, NOT medical advice.

struct PlanView: View {
    @EnvironmentObject var store: HealthDataStore
    @EnvironmentObject var profileStore: ProfileStore
    var accent: Color
    var lang: AppLanguage = .en

    @State private var sportIndex = 0
    @State private var duration = 45
    @State private var iob = 1.0
    /// Intensity is a continuous MET value now; the Riddell band is derived from it.
    @State private var met: Double = SPORTS[0].met
    @State private var showCarbs = false

    private let anim = Animation.easeInOut(duration: 0.25)

    private var difficulty: WorkoutDifficulty { WorkoutDifficulty(met: met) }

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

        ZStack {
            ScreenScaffold {
                AppHeader(title: lang.t("plan.title"), date: lang.t("plan.runGuide"),
                          initials: profileStore.profile.initials, accent: accent)

                // The deck sits directly on the page, NOT inside a Card. Card clips to its
                // rounded rect, which chopped the thrown card off at the container edge
                // instead of letting it fly clear, and cut the fan off on the right.
                SportPicker(sports: SPORTS, index: $sportIndex, accent: accent,
                            durationLabel: "\(duration) \(lang.t("workouts.min"))",
                            difficultyLabel: difficulty.label(lang), lang: lang)

                // Two dials sharing a row: minutes on the left, effort on the right. Sized
                // from the available width so they stay a matched pair on any device.
                Card(title: lang.t("plan.sessionDetails"), icon: "calendar", iconColor: accent) {
                    GeometryReader { geo in
                        let dial = min(158, (geo.size.width - 18) / 2)
                        HStack(spacing: 18) {
                            DurationDial(minutes: $duration, accent: accent, lang: lang, size: dial)
                                .frame(maxWidth: .infinity)
                            IntensityDial(met: $met, lang: lang, size: dial)
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .frame(height: 196)
                }

                Card(title: lang.t("plan.currentState"), icon: "bolt", iconColor: Theme.amber) {
                    HStack {
                        Text(lang.t("plan.currentGlucose"))
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(Theme.ink)
                        Spacer()
                        if let g = glucose, let st = gStatus {
                            HStack(spacing: 5) {
                                Text(unit.value(g))
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(st.color)
                                    .monospacedDigit()
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
                              options: [0, 0.5, 1.0, 1.5, 2.0, 3.0].map {
                                  (value: $0, label: String(format: "%.1f U", $0))
                              }, accent: accent)
                }

                Button { withAnimation(anim) { showCarbs = true } } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "fork.knife").font(.system(size: 16, weight: .semibold))
                        Text(lang.t("plan.calculate"))
                            .font(.system(size: 17, weight: .semibold))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
                    .background(accent)
                    .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
                    .shadow(color: accent.opacity(0.3), radius: 10, x: 0, y: 6)
                }
                .buttonStyle(.plain)
                .padding(.top, 2)
            }

            if showCarbs {
                CarbPlanView(guide: guide, sport: sport, durationMin: duration, met: met,
                             accent: accent, unit: unit, lang: lang) {
                    withAnimation(anim) { showCarbs = false }
                }
                .background(Theme.bg.ignoresSafeArea())
                .transition(.move(edge: .trailing))
                .zIndex(2)
            }
        }
        // Picking a sport parks the gauge at that sport's typical intensity; you're free
        // to drag away from it afterwards.
        .onChange(of: sportIndex) { newIndex in
            withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                met = SPORTS[newIndex].met
            }
        }
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
