import SwiftUI

// PlanView.swift — OneMET Plan tab: pre-workout carb planner.
// Estimate grounded in the 2017 consensus on exercise in T1D (Riddell et al.).
// Illustrative only — not medical advice.

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
        let plan = computeCarbPlan(sportId: sport.id, durationMin: duration, iob: iob,
                                   recentCarbsG: recentCarbs, glucoseMgdl: glucose,
                                   trendFalling: trend == .down, trendRising: trend == .up,
                                   weightKg: profileStore.profile.weightKg)
        let riskColor: Color = plan.risk == "High" ? Theme.red : (plan.risk == "Moderate" ? Theme.amber : Theme.green)
        let gStatus = glucose.map { glucoseStatus($0, low: d.targetLow, high: d.targetHigh) }

        ScreenScaffold {
            AppHeader(title: "Plan", date: "Workout Planner", accent: accent)

            Card(title: "Session Details", icon: "calendar", iconColor: accent) {
                SportPicker(sports: SPORTS, index: $sportIndex, accent: accent, durationLabel: "\(duration) min")
                    .padding(.bottom, 2)
                SelectRow(label: "Planned Duration", selection: $duration,
                          options: [15, 30, 45, 60, 90].map { (value: $0, label: "\($0) min") }, accent: accent)
            }

            Card(title: "Current State", icon: "bolt", iconColor: Theme.amber) {
                // Live glucose (read-only, from the store / Nightscout)
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

                SelectRow(label: "Insulin on Board", selection: $iob,
                          options: [0, 0.5, 1.0, 1.5, 2.0, 3.0].map { (value: $0, label: String(format: "%.1f U", $0)) }, accent: accent)
                SelectRow(label: "Carbs, Last 2h", selection: $recentCarbs,
                          options: [0, 15, 30, 45, 60, 90].map { (value: $0, label: "\($0) g") }, accent: accent)
            }

            carbBanner(plan)

            Card(title: "Hypo Risk") {
                HStack(spacing: 10) {
                    Circle().fill(riskColor).frame(width: 10, height: 10)
                    Text(plan.risk).font(.system(size: 17, weight: .bold)).foregroundStyle(riskColor)
                    Text("· \(sport.difficulty) · \(fmtNum(plan.met)) MET")
                        .font(.system(size: 13)).foregroundStyle(Theme.ink2)
                }
            }

            howCalculated(plan)

            disclaimer
        }
    }

    // MARK: - Carb recommendation banner

    private func carbBanner(_ plan: CarbPlan) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 7) {
                AppIconView(name: "fork", color: .white, size: 16)
                Text("CARB RECOMMENDATION")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.white.opacity(0.92))
                    .tracking(0.2)
            }
            .padding(.bottom, 10)

            HStack(spacing: 20) {
                carbStat("Before", plan.pre)
                if plan.needsDuring { carbStat("Every 30 min", plan.duringPer30) }
            }
            .padding(.bottom, 12)

            Text(recommendationText(plan))
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.white)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(accent)
        .clipShape(RoundedRectangle(cornerRadius: Theme.radius, style: .continuous))
        .shadow(color: accent.opacity(0.25), radius: 9, x: 0, y: 6)
    }

    private func carbStat(_ label: String, _ grams: Int) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label.uppercased())
                .font(.system(size: 11.5, weight: .semibold))
                .foregroundStyle(.white.opacity(0.8))
                .tracking(0.2)
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text("\(grams)").font(.system(size: 30, weight: .bold)).foregroundStyle(.white)
                Text("g").font(.system(size: 15, weight: .semibold)).foregroundStyle(.white)
            }
        }
    }

    private func recommendationText(_ plan: CarbPlan) -> String {
        var parts: [String] = []
        if !plan.startNote.isEmpty { parts.append(plan.startNote) }
        if plan.pre > 0 {
            parts.append("Aim for ~\(plan.pre) g of fast carbs 15–20 min before your \(plan.sport.name.lowercased()).")
        } else if plan.usedGlucose != nil {
            parts.append("No pre-carbs needed right now for this \(plan.sport.name.lowercased()) session.")
        }
        if plan.needsDuring {
            parts.append("During: ~\(plan.duringPer30) g every 30 min (≈\(plan.duringPerHour) g/h at \(fmtNum(plan.ratePerKgHr)) g/kg/h).")
        }
        return parts.joined(separator: " ")
    }

    // MARK: - Transparency

    private func howCalculated(_ plan: CarbPlan) -> some View {
        Card(title: "How this is calculated") {
            VStack(alignment: .leading, spacing: 10) {
                calcLine("Framework", "2017 international consensus on exercise in type 1 diabetes (Riddell et al., Lancet Diabetes & Endocrinology). Published ranges; coefficients shown here are transparent choices within them.")
                calcLine("Pre-carbs", "Start-glucose targets — <90 → ~15 g + recheck · 90–125 → ~10 g · 126–180 → ideal start · adjusted for trend and insulin on board.")
                calcLine("During-session", "\(fmtNum(plan.ratePerKgHr)) g/kg/h for \(plan.intensity) intensity × \(fmtNum(plan.usedWeightKg)) kg body weight\(plan.weightIsDefault ? " (default — set your weight in Profile)" : "").")
                calcLine("Inputs used", "Glucose \(plan.usedGlucose.map { "\(Int($0)) mg/dL" } ?? "—") · IOB \(String(format: "%.1f", iob)) U · recent carbs \(recentCarbs) g.")
            }
        }
    }

    private func calcLine(_ key: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(key.uppercased())
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Theme.ink2)
                .tracking(0.2)
            Text(value)
                .font(.system(size: 13))
                .foregroundStyle(Theme.ink)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Disclaimer

    private var disclaimer: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 13))
                .foregroundStyle(Theme.amber)
            Text("Illustrative estimate, not medical advice. Confirm all carbohydrate and insulin decisions with your clinician.")
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
}

#Preview {
    ZStack(alignment: .bottom) {
        Theme.bg.ignoresSafeArea()
        PlanView(accent: Theme.accent)
            .environmentObject(HealthDataStore())
            .environmentObject(ProfileStore())
    }
}
