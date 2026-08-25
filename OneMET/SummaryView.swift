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
                    WorkoutChart(session: tw, accent: accent, height: 158, unit: unit, lang: lang,
                                 low: d.targetLow, high: d.targetHigh)
                } else {
                    GlucoseChart(height: 158, unit: unit, lang: lang, accent: accent,
                                 data: d.glucose, currentIdx: d.currentIdx,
                                 runFrom: d.runFrom, runTo: d.runTo,
                                 low: d.targetLow, high: d.targetHigh)
                }

                Rectangle().fill(Theme.hair).frame(height: 1).padding(.vertical, 12)

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
                .padding(.bottom, 8)

                TIRBar(tir: d.tir)

                HStack(spacing: 14) {
                    TIRLegend(label: lang.t("summary.low"), value: d.tir.low, color: Theme.red)
                    TIRLegend(label: lang.t("summary.inRange"), value: d.tir.inRange, color: Theme.green)
                    TIRLegend(label: lang.t("summary.high"), value: d.tir.high, color: Theme.amber)
                }
                .padding(.top, 9)
            }

            // ── Insight banner. Empty snapshot insight = no workout today. ──
            InsightBanner(title: lang.t("summary.activityInsight"),
                          text: d.insight.isEmpty ? lang.t("summary.noWorkoutYet") : d.insight,
                          accent: accent)

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

// MARK: - Insight banner

struct InsightBanner: View {
    var title: String
    var text: String
    var accent: Color

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
        SummaryView(accent: Theme.accent, onOpenGlucose: {}, onGoActivity: {})
            .environmentObject(HealthDataStore())
            .environmentObject(ProfileStore())
    }
}
