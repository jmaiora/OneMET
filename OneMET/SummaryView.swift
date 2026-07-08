import SwiftUI

// SummaryView.swift — OneMET Summary screen
// Ported from the Claude Design handoff (screens.jsx → SummaryScreen).

struct SummaryView: View {
    var accent: Color
    var mmol: Bool = false
    var onOpenGlucose: () -> Void
    var onGoActivity: () -> Void
    var onGoTrends: () -> Void

    var body: some View {
        let st = glucoseStatus(SampleData.current)
        let unit = mmol ? "mmol/L" : "mg/dL"
        let r = SampleData.rings

        ScreenScaffold {
            AppHeader(title: "Summary", date: "Friday, Jun 19", accent: accent)

            // ── Glucose hero ──
            Card(title: "Glucose", icon: "drop", iconColor: Theme.green,
                 right: "Updated 2 min ago", onTap: onOpenGlucose) {
                HStack(alignment: .bottom) {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(fmtGlucose(SampleData.current, mmol: mmol))
                            .font(.system(size: 52, weight: .bold))
                            .foregroundStyle(Theme.ink)
                            .monospacedDigit()
                        Text(unit)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Theme.ink2)
                        TrendArrow(dir: .down, color: st.color)
                    }
                    Spacer()
                    Chip(color: st.color) { Dot(color: st.color); Text(st.label) }
                }
                .padding(.bottom, 6)

                GlucoseChart(height: 158, mmol: mmol, accent: accent)

                Rectangle().fill(Theme.hair).frame(height: 1).padding(.vertical, 12)

                HStack {
                    Text("TIME IN RANGE")
                        .font(.system(size: 12.5, weight: .semibold))
                        .foregroundStyle(Theme.ink2)
                        .tracking(0.2)
                    Spacer()
                    Text("\(SampleData.tir.inRange)%")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Theme.green)
                }
                .padding(.bottom, 8)

                TIRBar()

                HStack(spacing: 14) {
                    TIRLegend(label: "Low", value: SampleData.tir.low, color: Theme.red)
                    TIRLegend(label: "In Range", value: SampleData.tir.inRange, color: Theme.green)
                    TIRLegend(label: "High", value: SampleData.tir.high, color: Theme.amber)
                }
                .padding(.top, 9)
            }

            // ── Insight banner ──
            InsightBanner(accent: accent)

            // ── Activity rings ──
            Card(title: "Activity", icon: "flame", iconColor: Theme.ringMove, onTap: onGoActivity) {
                HStack(spacing: 18) {
                    ActivityRings(size: 118, stroke: 12)
                    VStack(alignment: .leading, spacing: 11) {
                        RingStat(color: Theme.ringMove, label: "Move", value: r.move.value, goal: r.move.goal, unit: "kcal")
                        RingStat(color: Theme.ringExer, label: "Exercise", value: r.exer.value, goal: r.exer.goal, unit: "min")
                        RingStat(color: Theme.ringMet, label: "MET", value: r.met.value, goal: r.met.goal, unit: "MET·min")
                    }
                }
            }

            // ── MET + Heart row ──
            HStack(spacing: 14) {
                Card(title: "MET", icon: "bolt", iconColor: Theme.ringMet, pad: 14) {
                    BigStat(value: "486", unit: "MET·min")
                    Text("Peak 9.1 on your run")
                        .font(.system(size: 11.5)).foregroundStyle(Theme.ink2)
                    MetBars(height: 62, accent: Theme.ringMet).padding(.top, 8)
                }
                Card(title: "Heart", icon: "heart", iconColor: Theme.red, pad: 14) {
                    BigStat(value: "\(SampleData.heart.current)", unit: "BPM")
                    Text("Range \(SampleData.heart.range.low)–\(SampleData.heart.range.high)")
                        .font(.system(size: 11.5)).foregroundStyle(Theme.ink2)
                    HeartChart(height: 62).padding(.top, 8)
                }
            }

            // ── Workouts ──
            Card(title: "Workouts", icon: "run", iconColor: accent, right: "Today", onTap: onGoActivity) {
                VStack(spacing: 0) {
                    ForEach(Array(SampleData.workouts.enumerated()), id: \.element.id) { idx, w in
                        WorkoutRow(w: w, accent: accent, last: idx == SampleData.workouts.count - 1)
                    }
                }
            }

            // ── Nutrition ──
            NutritionCard(accent: accent, onTap: onGoTrends)
        }
    }
}

// MARK: - Insight banner

struct InsightBanner: View {
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
            (Text("Your 4:08 PM run lowered glucose by ")
             + Text("38 mg/dL").fontWeight(.heavy)
             + Text(" over 32 min — consider 15g carbs before similar sessions."))
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
    var accent: Color
    var onTap: () -> Void

    var body: some View {
        let n = SampleData.nutrition
        Card(title: "Carbs & Insulin", icon: "fork", iconColor: Theme.amber, onTap: onTap) {
            HStack(spacing: 24) {
                StatBlock(label: "Carbs", value: "\(n.carbs)", unit: "g")
                StatBlock(label: "Insulin", value: "\(n.insulinUnits)", unit: "U", color: accent)
                StatBlock(label: "Goal", value: "\(n.carbsGoal)", unit: "g")
            }
            .padding(.bottom, 14)

            MealBars(meals: n.meals)
        }
    }
}

#Preview {
    ZStack(alignment: .bottom) {
        Theme.bg.ignoresSafeArea()
        SummaryView(accent: Theme.accent, onOpenGlucose: {}, onGoActivity: {}, onGoTrends: {})
    }
}
