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
    /// Intensity is a continuous MET value now; the intensity band is derived from it.
    @State private var met: Double = SPORTS[0].met
    @State private var showCarbs = false
    /// Per-plan intake settings, reset from the Profile default (interval) and the standard
    /// cap each time the fuel plan opens.
    @State private var planInterval = carbFeedIntervalMin
    @State private var planCap = defaultIntakeCapG
    /// Height of the tab's content area, measured rather than assumed.
    @State private var availableHeight: CGFloat = 800
    /// Rendered heights of everything on the screen that isn't the deck itself. Measured,
    /// not estimated: every guessed constant was a few points off and the errors added up
    /// to visible dead space under the button.
    @State private var headerHeight: CGFloat = 70
    @State private var deckDots: CGFloat = -1        // picker height minus the deck (the page dots)
    @State private var belowHeight: CGFloat = 400    // dials, Current State, button

    private let anim = Animation.easeInOut(duration: 0.25)

    private var difficulty: WorkoutDifficulty { WorkoutDifficulty(met: met) }

    /// 124pt dial + 8 spacing + its label underneath, which grows with the iOS text size.
    private var dialRow: CGFloat { 132 + 18 * Theme.textScale }

    /// The deck absorbs whatever vertical room the fixed rows leave over, so "Get my fuel
    /// plan" lands just above the tab bar instead of floating mid-screen with dead space
    /// under it. Hard-coding a height can only be right on one device; this is right on
    /// all of them, and degrades to a sensible range at the extremes.
    @State private var deckHeight: CGFloat = 200

    /// Everything that isn't the deck: the scaffold's top padding, the tab-bar clearance,
    /// the two row gaps either side of the deck, and the measured rows.
    private func fitDeck() {
        guard deckDots >= 0 else { return }
        // Below the button: the floating tab bar (6 + 7 + 22 icon + 2 + ~16 label + 7 + 6,
        // plus its 8pt bottom inset ≈ 74, scaled with the label) and a 12pt gap above it.
        // The scaffold pads 110 under its content so the page can scroll clear of the bar,
        // but fitting against that left ~35pt of dead space above the tab bar.
        let tabBarClearance = 58 + 16 * Theme.textScale + 12
        let fixed = 8 + headerHeight + 12 + deckDots + 12 + belowHeight + tabBarClearance
        // Floor keeps the cards usable on an SE (which then scrolls); the ceiling stops
        // them turning into posters on a Pro Max.
        let fitted = min(320, max(206, (availableHeight - fixed).rounded(.down)))
        if abs(fitted - deckHeight) >= 1 { deckHeight = fitted }
    }

    var body: some View {
        let d = store.data
        let sport = SPORTS[sportIndex]
        let glucose: Double? = d.hasGlucose ? d.current : nil
        // Five-level arrow (EASD/ISPAD definition) — the tables key on it.
        let arrow: GlucoseArrow? = d.hasGlucose ? d.currentArrow : nil
        let gStatus = glucose.map { glucoseStatus($0, low: d.targetLow, high: d.targetHigh) }
        let profile = profileStore.profile
        let unit = profile.glucoseUnit
        let guide = buildRunGuide(sportId: sport.id, durationMin: duration, iob: iob,
                                  glucoseMgdl: glucose, arrow: arrow,
                                  difficulty: difficulty,
                                  feedIntervalMin: planInterval,
                                  intakeCapG: planCap,
                                  kind: sport.kind,
                                  group: d.risk.group,                        // EASD Fig. 2
                                  weightKg: profile.weightKg ?? store.healthMassKg,
                                  unit: unit, lang: lang)

        // Sizes on this screen are chosen so the Calculate button lands above the fold on
        // a standard phone rather than a scroll down. That's why the spacing is tighter
        // than the other tabs, the deck is shorter than its natural height, and the dial
        // card carries no title — each dial already labels itself.
        ZStack {
            ScreenScaffold(spacing: 12) {
                AppHeader(title: lang.t("plan.title"), date: lang.t("plan.exerciseGuide"),
                          initials: profileStore.profile.initials, accent: accent)
                    .readHeight { headerHeight = $0; fitDeck() }

                // The deck sits directly on the page, NOT inside a Card. Card clips to its
                // rounded rect, which chopped the thrown card off at the container edge
                // instead of letting it fly clear, and cut the fan off on the right.
                SportPicker(sports: SPORTS, index: $sportIndex, accent: accent,
                            durationLabel: "\(duration) \(lang.t("workouts.min"))",
                            difficultyLabel: difficulty.label(lang), lang: lang,
                            height: deckHeight)
                    // Subtract the deck height this render used, captured now: reading the
                    // state inside the callback could see a newer value than was laid out.
                    .readHeight { [renderedDeck = deckHeight] h in
                        deckDots = max(0, h - renderedDeck); fitDeck()
                    }

                // Grouped only so its height can be measured; same 12pt gaps as the page.
                VStack(spacing: 12) {
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
                        .frame(height: dialRow)
                    }

                    // Trimmed 12pt (pad 14 -> 10, glucose row 8 -> 6) and handed to the deck.
                    Card(title: lang.t("plan.currentState"), icon: "bolt", iconColor: Theme.amber, pad: 10) {
                        HStack {
                            Text(lang.t("plan.currentGlucose"))
                                .font(.app(size: 15, weight: .medium))
                                .foregroundStyle(Theme.ink)
                            Spacer()
                            if let g = glucose, let st = gStatus {
                                HStack(spacing: 5) {
                                    Text(unit.value(g))
                                        .font(.app(size: 15, weight: .semibold))
                                        .foregroundStyle(st.color)
                                        .monospacedDigit()
                                    Text(unit.rawValue).font(.app(size: 14.5)).foregroundStyle(Theme.ink2)
                                    Image(systemName: (arrow ?? .flat).symbol)
                                        .font(.app(size: 14, weight: .bold))
                                        .foregroundStyle(st.color)
                                }
                            } else {
                                Text("—").font(.app(size: 15, weight: .semibold)).foregroundStyle(Theme.ink3)
                            }
                        }
                        .padding(.vertical, 6)
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
                        Button {
                            planInterval = nearestOption(profile.carbIntervalMin, in: carbFeedIntervalOptions)
                            planCap = defaultIntakeCapG
                            withAnimation(anim) { showCarbs = true }
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "fork.knife").font(.app(size: 16, weight: .semibold))
                                Text(lang.t("plan.calculate"))
                                    .font(.app(size: 17, weight: .semibold))
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
                .readHeight { belowHeight = $0; fitDeck() }
            }

            if showCarbs && profileStore.profile.fuellingModelApplies {
                CarbPlanView(guide: guide, sport: sport, durationMin: duration, met: met,
                             accent: accent, unit: unit, lang: lang,
                             intervalMin: $planInterval, capG: $planCap) {
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
                    .onAppear { availableHeight = geo.size.height; fitDeck() }
                    .onChange(of: geo.size.height) { availableHeight = $0; fitDeck() }
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
                    .font(.app(size: 17))
                    .foregroundStyle(accent)
                Text(lang.t("plan.scopeTitle"))
                    .font(.app(size: 16, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Text(lang.t(noDiabetes ? "plan.scopeNoDiabetes" : "plan.scopeNoInsulin"))
                .font(Theme.noteFont)
                .lineSpacing(Theme.noteLineSpacing)
                .foregroundStyle(Theme.ink2)
                .fixedSize(horizontal: false, vertical: true)
            // Only actionable when it's the insulin answer that ruled the plan out.
            if !noDiabetes {
                Text(lang.t("plan.scopeChange"))
                    .font(Theme.fineFont)
                    .foregroundStyle(Theme.ink3)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Text(lang.t("plan.scopeRest"))
                .font(Theme.fineFont)
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
