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
    /// Height of the tab's content area, measured rather than assumed.
    @State private var availableHeight: CGFloat = 800

    private let anim = Animation.easeInOut(duration: 0.25)

    private var difficulty: WorkoutDifficulty { WorkoutDifficulty(met: met) }

    /// The deck absorbs whatever vertical room the fixed rows leave over, so "Get my fuel
    /// plan" lands just above the tab bar instead of floating mid-screen with dead space
    /// under it. Hard-coding a height can only be right on one device; this is right on
    /// all of them, and degrades to a sensible range at the extremes.
    private var deckHeight: CGFloat {
        // Everything on this screen that isn't the deck, including the scaffold's own
        // padding and the clearance it leaves for the floating tab bar.
        let header: CGFloat = 70
        let dialsCard: CGFloat = 174        // 150 dial row + 12 padding top and bottom
        let currentState: CGFloat = 123
        let button: CGFloat = 45
        let deckDots: CGFloat = 16          // page dots plus the deck's internal spacing
        let scaffold: CGFloat = 12 * 4 + 8 + 110    // row gaps + top pad + tab-bar clearance

        let leftOver = availableHeight
            - (header + dialsCard + currentState + button + deckDots + scaffold)
        return min(236, max(150, leftOver))
    }

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

        // Sizes on this screen are chosen so the Calculate button lands above the fold on
        // a standard phone rather than a scroll down. That's why the spacing is tighter
        // than the other tabs, the deck is shorter than its natural height, and the dial
        // card carries no title — each dial already labels itself.
        ZStack {
            ScreenScaffold(spacing: 12) {
                AppHeader(title: lang.t("plan.title"), date: lang.t("plan.exerciseGuide"),
                          initials: profileStore.profile.initials, accent: accent)

                // The deck sits directly on the page, NOT inside a Card. Card clips to its
                // rounded rect, which chopped the thrown card off at the container edge
                // instead of letting it fly clear, and cut the fan off on the right.
                SportPicker(sports: SPORTS, index: $sportIndex, accent: accent,
                            durationLabel: "\(duration) \(lang.t("workouts.min"))",
                            difficultyLabel: difficulty.label(lang), lang: lang,
                            height: deckHeight)

                // Two dials sharing a row: minutes on the left, effort on the right. Sized
                // from the available width so they stay a matched pair on any device.
                Card(pad: 12) {
                    GeometryReader { geo in
                        let dial = min(124, (geo.size.width - 16) / 2)
                        HStack(spacing: 16) {
                            DurationDial(minutes: $duration, accent: accent, lang: lang, size: dial)
                                .frame(maxWidth: .infinity)
                            IntensityDial(met: $met, lang: lang, size: dial)
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .frame(height: 150)
                }

                Card(title: lang.t("plan.currentState"), icon: "bolt", iconColor: Theme.amber, pad: 14) {
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
                    .padding(.vertical, 8)
                    .overlay(Rectangle().fill(Theme.sep).frame(height: 0.5), alignment: .bottom)

                    SelectRow(label: lang.t("plan.iob"), selection: $iob,
                              options: [0, 0.5, 1.0, 1.5, 2.0, 3.0].map {
                                  (value: $0, label: String(format: "%.1f U", $0))
                              }, accent: accent)
                }

                // The carbohydrate model was derived for type 1 diabetes on insulin. For
                // everyone else the honest answer is an explanation, not a number — see
                // UserProfile.fuellingModelApplies.
                if profileStore.profile.fuellingModelApplies {
                    Button { withAnimation(anim) { showCarbs = true } } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "fork.knife").font(.system(size: 16, weight: .semibold))
                            Text(lang.t("plan.calculate"))
                                .font(.system(size: 17, weight: .semibold))
                                .minimumScaleFactor(0.85)
                                .lineLimit(1)
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(accent)
                        .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
                        .shadow(color: accent.opacity(0.3), radius: 10, x: 0, y: 6)
                    }
                    .buttonStyle(.plain)
                } else {
                    outOfScopeCard
                }
            }

            if showCarbs && profileStore.profile.fuellingModelApplies {
                CarbPlanView(guide: guide, sport: sport, durationMin: duration, met: met,
                             accent: accent, unit: unit, lang: lang) {
                    withAnimation(anim) { showCarbs = false }
                }
                .background(Theme.bg.ignoresSafeArea())
                .transition(.move(edge: .trailing))
                .zIndex(2)
            }
        }
        .background(
            GeometryReader { geo in
                Color.clear
                    .onAppear { availableHeight = geo.size.height }
                    .onChange(of: geo.size.height) { availableHeight = $0 }
            }
        )
        // Picking a sport parks the gauge at that sport's typical intensity; you're free
        // to drag away from it afterwards.
        .onChange(of: sportIndex) { newIndex in
            withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                met = SPORTS[newIndex].met
            }
        }
    }

    /// Shown in place of the fuel-plan button when the model doesn't apply. The reason
    /// differs — no diabetes at all, versus diabetes managed without insulin — and so
    /// does what the person can do about it, so the two are worded separately.
    private var outOfScopeCard: some View {
        let p = profileStore.profile
        let noDiabetes = p.diabetesType == .nonDiabetic
        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 9) {
                Image(systemName: "info.circle.fill")
                    .font(.system(size: 17))
                    .foregroundStyle(accent)
                Text(lang.t("plan.scopeTitle"))
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Text(lang.t(noDiabetes ? "plan.scopeNoDiabetes" : "plan.scopeNoInsulin"))
                .font(.system(size: 13.5))
                .foregroundStyle(Theme.ink2)
                .lineSpacing(2.5)
                .fixedSize(horizontal: false, vertical: true)
            // Only actionable when it's the insulin answer that ruled the plan out.
            if !noDiabetes {
                Text(lang.t("plan.scopeChange"))
                    .font(.system(size: 12.5))
                    .foregroundStyle(Theme.ink3)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Text(lang.t("plan.scopeRest"))
                .font(.system(size: 12.5))
                .foregroundStyle(Theme.ink3)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.card)
        .clipShape(RoundedRectangle(cornerRadius: Theme.radius, style: .continuous))
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
