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

            // MET minutes
            Card(title: "MET Minutes", icon: "bolt", iconColor: Theme.ringMet, right: "Today") {
                BigStat(value: fmtNum(d.metToday), unit: "MET·min", size: 34).padding(.bottom, 4)
                MetBars(height: 104, accent: Theme.ringMet, data: d.metByHour)
                Text(d.metPeak > 0
                     ? "Most activity \(d.peakBucketLabel). 1 MET ≈ resting; peaked at \(fmtNum(d.metPeak)) MET today."
                     : "1 MET ≈ resting energy. MET·min accumulates as you move through the day.")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.ink2)
                    .padding(.top, 6)
                    .fixedSize(horizontal: false, vertical: true)
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
