import SwiftUI

// SummaryView.swift — OneMET Summary screen (live HealthKit data via HealthDataStore).

struct SummaryView: View {
    @EnvironmentObject var store: HealthDataStore
    @EnvironmentObject var profileStore: ProfileStore
    var accent: Color
    var unit: GlucoseUnit = .mgdl
    var lang: AppLanguage = .en
    var onOpenGlucose: () -> Void
    var onGoActivity: () -> Void
    /// Jump to the Plan tab, from the insight banner's call to action.
    var onGoPlan: () -> Void

    /// Half of the vertical budget that decides whether an empty day's call to action
    /// clears the fold; the other half is `ActivityPrompt.diameter`. Tuned together for a
    /// standard-size iPhone — on a 4.7" screen both want a notch less.
    private let chartHeight: CGFloat = 112

    var body: some View {
        let d = store.data
        let st = glucoseStatus(d.current, low: d.targetLow, high: d.targetHigh)
        let r = d.rings
        let today = Date().formatted(.dateTime.weekday(.wide).month(.abbreviated).day()
                                        .locale(lang.locale))

        ScreenScaffold(onRefresh: { await store.refresh() }) {
            AppHeader(title: lang.t("summary.title"), date: today,
                      initials: profileStore.profile.initials, accent: accent)

            // ── Glucose hero ──
            Card(title: lang.t("summary.glucose"), icon: "drop", iconColor: Theme.green,
                 right: store.isLoading ? lang.t("common.updating") : lang.t("common.now"),
                 onTap: onOpenGlucose) {
                HStack(alignment: .bottom) {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(d.hasGlucose ? unit.value(d.current) : "—")
                            .font(.system(size: 52, weight: .bold))
                            .foregroundStyle(Theme.ink)
                            .monospacedDigit()
                        Text(unit.rawValue)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Theme.ink2)
                        if d.hasGlucose { TrendArrow(dir: d.currentTrend, color: st.color) }
                    }
                    Spacer()
                    if d.hasGlucose {
                        Chip(color: st.color) { Dot(color: st.color); Text(st.label(lang)) }
                    }
                }
                .padding(.bottom, 6)

                if let tw = d.todayWorkout, !tw.curve.isEmpty {
                    // A workout was recorded today → show its pre/during/post glucose overlay.
                    // A shade taller than the plain trace: the overlay carries the
                    // pre/during/post bands as well as the curve.
                    WorkoutChart(session: tw, accent: accent, height: chartHeight + 28,
                                 unit: unit, lang: lang,
                                 low: d.targetLow, high: d.targetHigh)
                } else {
                    GlucoseChart(height: chartHeight, unit: unit, lang: lang, accent: accent,
                                 data: d.glucose, currentIdx: d.currentIdx,
                                 runFrom: d.runFrom, runTo: d.runTo,
                                 low: d.targetLow, high: d.targetHigh)
                }

                Rectangle().fill(Theme.hair).frame(height: 1).padding(.vertical, 10)

                HStack {
                    Text(lang.t("summary.timeInRange"))
                        .font(.system(size: 12.5, weight: .semibold))
                        .foregroundStyle(Theme.ink2)
                        .tracking(0.2)
                    Spacer()
                    Text("\(d.tir.inRange)%")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Theme.green)
                }
                .padding(.bottom, 6)

                TIRBar(tir: d.tir)

                HStack(spacing: 14) {
                    TIRLegend(label: lang.t("summary.low"), value: d.tir.low, color: Theme.red)
                    TIRLegend(label: lang.t("summary.inRange"), value: d.tir.inRange, color: Theme.green)
                    TIRLegend(label: lang.t("summary.high"), value: d.tir.high, color: Theme.amber)
                }
                .padding(.top, 7)
            }

            // ── Insight banner, or the prompt that replaces it on an empty day. ──
            // Empty snapshot insight = no workout today. With nothing to report there is
            // no insight to dress up, so the blue box stops wrapping the whole thing and
            // wraps only the way into the Plan tab — the one action worth taking on an
            // otherwise empty Summary. Once there is a session to talk about, the banner
            // returns and its call to action goes back to being a quiet second helping.
            if d.insight.isEmpty {
                ActivityPrompt(title: lang.t("summary.activityInsight"),
                               text: lang.t("summary.noWorkoutYet"),
                               actionTitle: lang.t("summary.chooseActivity"),
                               actionSubtitle: lang.t("summary.chooseActivitySub"),
                               accent: accent,
                               action: onGoPlan)
            } else {
                InsightBanner(title: lang.t("summary.activityInsight"),
                              text: d.insight,
                              accent: accent,
                              actionTitle: lang.t("summary.planAnother"),
                              actionSubtitle: lang.t("summary.planAnotherSub"),
                              action: onGoPlan)
            }

            // ── Before workout (generic prep summary; full guide lives in Plan) ──
            Card(title: lang.t("summary.beforeWorkout"), icon: "bolt", iconColor: accent) {
                VStack(alignment: .leading, spacing: 10) {
                    Text(beforeWorkoutSummary(deliveryIsPump: profileStore.profile.insulinDelivery.isPump,
                                              unit: unit, lang: lang))
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(Theme.ink)
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(lang.t("summary.beforeNote"))
                        .font(.system(size: 11.5, weight: .medium))
                        .foregroundStyle(Theme.ink3)
                        .lineSpacing(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            // ── Activity rings ──
            Card(title: lang.t("summary.activity"), icon: "flame", iconColor: Theme.ringMove, onTap: onGoActivity) {
                HStack(spacing: 18) {
                    ActivityRings(size: 118, stroke: 12,
                                  fractions: [r.move.frac, r.exer.frac, r.met.frac])
                    VStack(alignment: .leading, spacing: 11) {
                        RingStat(color: Theme.ringMove, label: lang.t("summary.move"), value: r.move.value, goal: r.move.goal, unit: "kcal")
                        RingStat(color: Theme.ringExer, label: lang.t("summary.exercise"), value: r.exer.value, goal: r.exer.goal, unit: lang.t("workouts.min"))
                        RingStat(color: Theme.ringMet, label: lang.t("summary.met"), value: r.met.value, goal: r.met.goal, unit: "MET·min")
                    }
                }
            }

            // ── MET·min trend (full width) ──
            Card(title: lang.t("summary.metMin"), icon: "bolt", iconColor: Theme.ringMet,
                 right: lang.t("summary.last7")) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(fmtNum(d.metToday))
                        .font(.system(size: 30, weight: .bold))
                        .foregroundStyle(Theme.ink)
                        .monospacedDigit()
                    Text(lang.t("summary.metToday"))
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Theme.ink2)
                }
                .padding(.bottom, 8)

                MetMinTrendBars(data: Array(d.metMinTrend.suffix(7)), accent: Theme.ringMet, height: 150)
            }
        }
    }
}

// MARK: - Empty-day activity prompt

/// The empty-state counterpart to `InsightBanner`: same two lines of copy, but unboxed
/// and in ordinary ink, sitting straight on the page. Everything blue is spent on one
/// ringed disc below them, which is the only thing worth tapping on a day with nothing
/// recorded in it. The label keeps its bolt so the block still reads as the activity slot.
struct ActivityPrompt: View {
    var title: String
    var text: String
    var actionTitle: String
    var actionSubtitle: String
    var accent: Color
    var action: () -> Void

    /// Paired with `SummaryView.chartHeight`: between them they decide whether the disc
    /// clears the fold. Raising one means lowering the other.
    private let diameter: CGFloat = 170

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 7) {
                AppIconView(name: "bolt", color: accent, size: 15)
                Text(title)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Theme.ink2)
                    .tracking(0.2)
            }

            Text(text)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Theme.ink)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)

            // A disc rather than a bar: round, centred and unattached to any card, so
            // it reads as a target to hit rather than a row to read. The open ring around
            // it borrows the activity rings' language without pretending to show progress
            // — there is none to show on a day with no session in it.
            HStack {
                Spacer(minLength: 0)
                Button(action: action) {
                    ZStack {
                        Circle()
                            .stroke(accent.opacity(0.16), lineWidth: 9)
                            .frame(width: diameter + 18, height: diameter + 18)

                        Circle()
                            .fill(accent)
                            .frame(width: diameter, height: diameter)
                            .shadow(color: accent.opacity(0.32), radius: 14, x: 0, y: 8)

                        VStack(spacing: 4) {
                            Image(systemName: "figure.run")
                                .font(.system(size: 26, weight: .semibold))
                            Text(actionTitle)
                                .font(.system(size: 24, weight: .heavy))
                                .lineLimit(1)
                                // "Get active" and "¡Actívate!" differ enough in width
                                // that a fixed size would clip one of them.
                                .minimumScaleFactor(0.55)
                            Text(actionSubtitle)
                                .font(.system(size: 12, weight: .medium))
                                .opacity(0.9)
                                .multilineTextAlignment(.center)
                                .lineLimit(2)
                        }
                        .foregroundStyle(.white)
                        // Keeps the copy off the curve.
                        .frame(width: diameter * 0.72)
                    }
                    // Sized to the ring, not the row, so the tap area is the disc itself.
                    .frame(width: diameter + 18, height: diameter + 18)
                    .contentShape(Circle())
                }
                .buttonStyle(.plain)
                Spacer(minLength: 0)
            }
            .padding(.top, 6)
        }
        // The unboxed lines would otherwise sit flush to the scaffold's own margin, a
        // shade further out than the boxed cards above and below them.
        .padding(.horizontal, 4)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Insight banner

struct InsightBanner: View {
    var title: String
    var text: String
    var accent: Color
    /// Optional call to action under the text: a full-width button carrying a bold line to
    /// prompt with and a quieter one saying what tapping it actually does. All three
    /// default to nil, so the banner can still be used as a plain read-only strip.
    var actionTitle: String? = nil
    var actionSubtitle: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 7) {
                AppIconView(name: "bolt", color: .white, size: 15)
                Text(title)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.white.opacity(0.92))
                    .tracking(0.2)
            }
            Text(text)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.white)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)

            // Reversed out of the accent background — white fill, accent label — and run
            // full width, so it reads as the thing to do on this screen rather than as
            // more of the banner's own text.
            if let actionTitle, let action {
                Button(action: action) {
                    HStack(spacing: 10) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(actionTitle)
                                .font(.system(size: 18, weight: .bold))
                            if let actionSubtitle {
                                Text(actionSubtitle)
                                    .font(.system(size: 12.5, weight: .medium))
                                    .opacity(0.72)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        .multilineTextAlignment(.leading)
                        Spacer(minLength: 8)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .bold))
                            .opacity(0.6)
                    }
                    .foregroundStyle(accent)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 13)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(.plain)
                .padding(.top, 9)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(accent)
        .clipShape(RoundedRectangle(cornerRadius: Theme.radius, style: .continuous))
        .shadow(color: accent.opacity(0.25), radius: 9, x: 0, y: 6)
    }
}

// MARK: - Nutrition card

struct NutritionCard: View {
    var nutrition: Nutrition
    var accent: Color
    var lang: AppLanguage = .en
    var onTap: () -> Void

    var body: some View {
        Card(title: lang.t("summary.carbsInsulin"), icon: "fork", iconColor: Theme.amber, onTap: onTap) {
            HStack(spacing: 24) {
                StatBlock(label: lang.t("summary.carbs"), value: "\(nutrition.carbs)", unit: "g")
                StatBlock(label: lang.t("summary.insulin"), value: "\(nutrition.insulinUnits)", unit: "U", color: accent)
                StatBlock(label: lang.t("summary.goal"), value: "\(nutrition.carbsGoal)", unit: "g")
            }
            .padding(.bottom, 14)

            if !nutrition.meals.isEmpty {
                MealBars(meals: nutrition.meals)
            }
        }
    }
}

#Preview {
    ZStack(alignment: .bottom) {
        Theme.bg.ignoresSafeArea()
        SummaryView(accent: Theme.accent, onOpenGlucose: {}, onGoActivity: {}, onGoPlan: {})
            .environmentObject(HealthDataStore())
            .environmentObject(ProfileStore())
    }
}
