import SwiftUI

// SummaryView.swift — OneMET Summary screen (live HealthKit data via HealthDataStore).

struct SummaryView: View {
    @EnvironmentObject var store: HealthDataStore
    var accent: Color
    var mmol: Bool = false
    var onOpenGlucose: () -> Void
    var onGoActivity: () -> Void

    var body: some View {
        let d = store.data
        let st = glucoseStatus(d.current, low: d.targetLow, high: d.targetHigh)
        let unit = mmol ? "mmol/L" : "mg/dL"
        let r = d.rings

        ScreenScaffold {
            AppHeader(title: "Summary", date: Date().formatted(.dateTime.weekday(.wide).month(.abbreviated).day()), accent: accent)

            // ── Glucose hero ──
            Card(title: "Glucose", icon: "drop", iconColor: Theme.green,
                 right: store.isLoading ? "Updating…" : "Now", onTap: onOpenGlucose) {
                HStack(alignment: .bottom) {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(d.hasGlucose ? fmtGlucose(d.current, mmol: mmol) : "—")
                            .font(.system(size: 52, weight: .bold))
                            .foregroundStyle(Theme.ink)
                            .monospacedDigit()
                        Text(unit)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Theme.ink2)
                        if d.hasGlucose { TrendArrow(dir: d.currentTrend, color: st.color) }
                    }
                    Spacer()
                    if d.hasGlucose {
                        Chip(color: st.color) { Dot(color: st.color); Text(st.label) }
                    }
                }
                .padding(.bottom, 6)

                if let tw = d.todayWorkout, !tw.curve.isEmpty {
                    // A workout was recorded today → show its pre/during/post glucose overlay.
                    WorkoutChart(session: tw, accent: accent, height: 158)
                } else {
                    GlucoseChart(height: 158, mmol: mmol, accent: accent,
                                 data: d.glucose, currentIdx: d.currentIdx,
                                 runFrom: d.runFrom, runTo: d.runTo,
                                 low: d.targetLow, high: d.targetHigh)
                }

                Rectangle().fill(Theme.hair).frame(height: 1).padding(.vertical, 12)

                HStack {
                    Text("TIME IN RANGE")
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
                    TIRLegend(label: "Low", value: d.tir.low, color: Theme.red)
                    TIRLegend(label: "In Range", value: d.tir.inRange, color: Theme.green)
                    TIRLegend(label: "High", value: d.tir.high, color: Theme.amber)
                }
                .padding(.top, 9)
            }

            // ── Insight banner ──
            InsightBanner(text: d.insight, accent: accent)

            // ── Activity rings ──
            Card(title: "Activity", icon: "flame", iconColor: Theme.ringMove, onTap: onGoActivity) {
                HStack(spacing: 18) {
                    ActivityRings(size: 118, stroke: 12,
                                  fractions: [r.move.frac, r.exer.frac, r.met.frac])
                    VStack(alignment: .leading, spacing: 11) {
                        RingStat(color: Theme.ringMove, label: "Move", value: r.move.value, goal: r.move.goal, unit: "kcal")
                        RingStat(color: Theme.ringExer, label: "Exercise", value: r.exer.value, goal: r.exer.goal, unit: "min")
                        RingStat(color: Theme.ringMet, label: "MET", value: r.met.value, goal: r.met.goal, unit: "MET·min")
                    }
                }
            }

            // ── MET·min trend (full width) ──
            Card(title: "MET·min", icon: "bolt", iconColor: Theme.ringMet, right: "Last 7 days") {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(fmtNum(d.metToday))
                        .font(.system(size: 30, weight: .bold))
                        .foregroundStyle(Theme.ink)
                        .monospacedDigit()
                    Text("MET·min today")
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
    var text: String
    var accent: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 7) {
                AppIconView(name: "bolt", color: .white, size: 15)
                Text("ACTIVITY INSIGHT")
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
    var onTap: () -> Void

    var body: some View {
        Card(title: "Carbs & Insulin", icon: "fork", iconColor: Theme.amber, onTap: onTap) {
            HStack(spacing: 24) {
                StatBlock(label: "Carbs", value: "\(nutrition.carbs)", unit: "g")
                StatBlock(label: "Insulin", value: "\(nutrition.insulinUnits)", unit: "U", color: accent)
                StatBlock(label: "Goal", value: "\(nutrition.carbsGoal)", unit: "g")
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
    }
}
