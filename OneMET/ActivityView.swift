import SwiftUI

// ActivityView.swift — OneMET Activity screen
// Ported from the Claude Design handoff (screens.jsx → ActivityScreen).

struct ActivityView: View {
    var accent: Color

    var body: some View {
        let r = SampleData.rings

        ScreenScaffold {
            AppHeader(title: "Activity", date: "Friday, Jun 19", accent: accent)

            // Rings hero
            Card(pad: 20) {
                HStack {
                    Spacer()
                    ActivityRings(size: 172, stroke: 17)
                    Spacer()
                }
                .padding(.bottom, 16)

                VStack(alignment: .leading, spacing: 14) {
                    RingStat(color: Theme.ringMove, label: "Move", value: r.move.value, goal: r.move.goal, unit: "kcal")
                    RingStat(color: Theme.ringExer, label: "Exercise", value: r.exer.value, goal: r.exer.goal, unit: "min")
                    RingStat(color: Theme.ringMet, label: "MET", value: r.met.value, goal: r.met.goal, unit: "MET·min")
                }
            }

            // Steps & distance
            Card(title: "Steps & Distance", icon: "shoe", iconColor: Theme.teal) {
                HStack(spacing: 24) {
                    StatBlock(label: "Steps", value: SampleData.steps.formatted(), color: Theme.teal)
                    StatBlock(label: "Distance", value: "6.6", unit: "km")
                    StatBlock(label: "Flights", value: "11")
                }
                ProgressBar(value: Double(SampleData.steps), goal: Double(SampleData.stepsGoal), color: Theme.teal)
                    .padding(.top, 12)
                Text("\(Int((Double(SampleData.steps) / Double(SampleData.stepsGoal) * 100).rounded()))% of \(SampleData.stepsGoal.formatted()) goal")
                    .font(.system(size: 11.5))
                    .foregroundStyle(Theme.ink2)
                    .padding(.top, 6)
            }

            // MET minutes
            Card(title: "MET Minutes", icon: "bolt", iconColor: Theme.ringMet, right: "Today") {
                BigStat(value: "486", unit: "MET·min", size: 34).padding(.bottom, 4)
                MetBars(height: 104, accent: Theme.ringMet)
                Text("Most activity 4–6 PM. 1 MET ≈ resting; running today peaked at 9.1 MET.")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.ink2)
                    .padding(.top, 6)
                    .fixedSize(horizontal: false, vertical: true)
            }

            // Workouts
            Card(title: "Workouts", icon: "run", iconColor: accent) {
                VStack(spacing: 0) {
                    ForEach(Array(SampleData.workouts.enumerated()), id: \.element.id) { i, w in
                        WorkoutRow(w: w, accent: accent, last: i == SampleData.workouts.count - 1)
                    }
                }
            }
        }
    }
}

#Preview {
    ZStack { Theme.bg.ignoresSafeArea(); ActivityView(accent: Theme.accent) }
}
