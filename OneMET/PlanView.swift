import SwiftUI

// PlanView.swift — OneMET Plan tab: pre-workout carb planner (v2).

struct PlanView: View {
    var accent: Color

    @State private var sportId = "run"
    @State private var duration = 45
    @State private var iob = 1.0
    @State private var recentCarbs = 30

    var body: some View {
        let plan = computeCarbPlan(sportId: sportId, durationMin: duration, iob: iob, recentCarbsG: recentCarbs)
        let riskColor: Color = plan.risk == "High" ? Theme.red : (plan.risk == "Moderate" ? Theme.amber : Theme.green)

        ScreenScaffold {
            AppHeader(title: "Plan", date: "Workout Planner", accent: accent)

            Card(title: "Session Details", icon: "calendar", iconColor: accent) {
                SelectRow(label: "Sport", selection: $sportId,
                          options: SPORTS.map { (value: $0.id, label: $0.name) }, accent: accent)
                SelectRow(label: "Planned Duration", selection: $duration,
                          options: [15, 30, 45, 60, 90].map { (value: $0, label: "\($0) min") }, accent: accent)
            }

            Card(title: "Current State", icon: "bolt", iconColor: Theme.amber) {
                SelectRow(label: "Insulin on Board", selection: $iob,
                          options: [0, 0.5, 1.0, 1.5, 2.0, 3.0].map { (value: $0, label: String(format: "%.1f U", $0)) }, accent: accent)
                SelectRow(label: "Carbs, Last 2h", selection: $recentCarbs,
                          options: [0, 15, 30, 45, 60, 90].map { (value: $0, label: "\($0) g") }, accent: accent)
            }

            // Carb recommendation banner
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

            Card(title: "Hypo Risk") {
                HStack(spacing: 10) {
                    Circle().fill(riskColor).frame(width: 10, height: 10)
                    Text(plan.risk)
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(riskColor)
                    Text("· \(plan.intensity) intensity · \(fmtNum(plan.met)) MET")
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.ink2)
                }
            }
        }
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
        if plan.pre == 0 {
            return "Low hypo risk for this \(plan.sport.name.lowercased()) session — no pre-carbs needed given current IOB and recent intake."
        }
        let during = plan.needsDuring ? ", then \(plan.duringPer30)g every 30 min during the session" : ""
        return "Eat \(plan.pre)g of fast carbs 15–20 min before your \(plan.sport.name.lowercased())\(during). Based on \(fmtNum(plan.met)) MET intensity, \(String(format: "%.1f", iob))U IOB, and \(recentCarbs)g eaten in the last 2h."
    }
}

#Preview {
    ZStack(alignment: .bottom) {
        Theme.bg.ignoresSafeArea()
        PlanView(accent: Theme.accent)
    }
}
