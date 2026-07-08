import SwiftUI

// ActivityView.swift — OneMET Activity screen (live data via HealthDataStore).

struct ActivityView: View {
    @EnvironmentObject var store: HealthDataStore
    var accent: Color

    var body: some View {
        let d = store.data
        let r = d.rings
        let stepsPct = d.stepsGoal > 0 ? Int((Double(d.steps) / Double(d.stepsGoal) * 100).rounded()) : 0

        ScreenScaffold {
            AppHeader(title: "Activity", date: Date().formatted(.dateTime.weekday(.wide).month(.abbreviated).day()), accent: accent)

            // Rings hero
            Card(pad: 20) {
                HStack {
                    Spacer()
                    ActivityRings(size: 172, stroke: 17,
                                  fractions: [r.move.frac, r.exer.frac, r.met.frac])
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
                    StatBlock(label: "Steps", value: d.steps.formatted(), color: Theme.teal)
                    StatBlock(label: "Distance", value: String(format: "%.1f", d.distanceKm), unit: "km")
                    StatBlock(label: "Flights", value: "\(d.flights)")
                }
                ProgressBar(value: Double(d.steps), goal: Double(d.stepsGoal), color: Theme.teal)
                    .padding(.top, 12)
                Text("\(stepsPct)% of \(d.stepsGoal.formatted()) goal")
                    .font(.system(size: 11.5))
                    .foregroundStyle(Theme.ink2)
                    .padding(.top, 6)
            }

            // Exercise intensity (MET)
            Card(title: "Exercise Intensity", icon: "bolt", iconColor: Theme.ringMet, right: "Today") {
                BigStat(value: d.metPeak > 0 ? fmtNum(d.metPeak) : "—", unit: "MET", size: 34).padding(.bottom, 4)
                if !d.workouts.isEmpty {
                    WorkoutMetBars(workouts: d.workouts, height: 120, showLabels: true)
                    Text("Average MET per workout, from Apple Watch. Moderate 3–6, vigorous 6+; ~1 MET at rest.")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.ink2)
                        .padding(.top, 6)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    Text("No workouts today. Intensity (MET) is read from your logged workouts.")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.ink2)
                        .padding(.top, 4)
                }
            }

            // Workouts
            if !d.workouts.isEmpty {
                Card(title: "Workouts", icon: "run", iconColor: accent) {
                    VStack(spacing: 0) {
                        ForEach(Array(d.workouts.enumerated()), id: \.element.id) { i, w in
                            WorkoutRow(w: w, accent: accent, last: i == d.workouts.count - 1)
                        }
                    }
                }
            }
        }
    }
}

#Preview {
    ZStack { Theme.bg.ignoresSafeArea(); ActivityView(accent: Theme.accent).environmentObject(HealthDataStore()) }
}
