import SwiftUI

// WorkoutsView.swift — OneMET Workouts tab (rings + history by week). v2.

struct WorkoutsView: View {
    @EnvironmentObject var store: HealthDataStore
    var accent: Color
    var onOpenWorkout: (WorkoutSession) -> Void

    @State private var visibleWeeks = 2

    var body: some View {
        let d = store.data
        let r = d.rings
        let weeks = Array(d.workoutHistory.prefix(visibleWeeks))
        let total = d.workoutHistory.reduce(0) { $0 + $1.sessions.count }
        let shown = weeks.reduce(0) { $0 + $1.sessions.count }

        ScreenScaffold(onRefresh: { await store.refresh() }) {
            AppHeader(title: "Workouts", date: "History", accent: accent)

            // Rings hero
            Card(pad: 20) {
                HStack {
                    Spacer()
                    ActivityRings(size: 140, stroke: 14, fractions: [r.move.frac, r.exer.frac, r.met.frac])
                    Spacer()
                }
                .padding(.bottom, 16)
                VStack(alignment: .leading, spacing: 12) {
                    RingStat(color: Theme.ringMove, label: "Move", value: r.move.value, goal: r.move.goal, unit: "kcal")
                    RingStat(color: Theme.ringExer, label: "Exercise", value: r.exer.value, goal: r.exer.goal, unit: "min")
                    RingStat(color: Theme.ringMet, label: "MET", value: r.met.value, goal: r.met.goal, unit: "MET·min")
                }
            }

            if d.workoutHistory.isEmpty {
                Card {
                    Text("No workouts logged yet. Sessions from Apple Health will appear here.")
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.ink2)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }

            ForEach(weeks) { wk in
                Card(title: wk.label, icon: "run", iconColor: accent,
                     right: "\(wk.sessions.count) workout\(wk.sessions.count == 1 ? "" : "s")") {
                    VStack(spacing: 0) {
                        ForEach(Array(wk.sessions.enumerated()), id: \.element.id) { i, s in
                            HistoryRow(session: s, accent: accent, last: i == wk.sessions.count - 1) {
                                onOpenWorkout(s)
                            }
                        }
                    }
                }
            }

            if shown < total {
                Button { visibleWeeks += 2 } label: {
                    Text("Load Past Weeks")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(accent)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

struct HistoryRow: View {
    var session: WorkoutSession
    var accent: Color
    var last: Bool
    var onTap: () -> Void

    var body: some View {
        let dropColor = session.glucoseDelta < 0 ? Theme.green : Theme.amber
        Button(action: onTap) {
            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10, style: .continuous).fill(accent.opacity(0.09))
                        AppIconView(name: session.icon, color: accent, size: 20)
                    }
                    .frame(width: 38, height: 38)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(session.name)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Theme.ink)
                        Text("\(session.day) · \(session.time) · \(session.dur)")
                            .font(.system(size: 12.5))
                            .foregroundStyle(Theme.ink2)
                            .lineLimit(1)
                    }
                    Spacer(minLength: 8)

                    VStack(alignment: .trailing, spacing: 3) {
                        Chip("\(session.glucoseDelta > 0 ? "+" : "")\(session.glucoseDelta) mg/dL", color: dropColor)
                        Text("\(fmtNum(session.avgMet)) MET avg")
                            .font(.system(size: 11))
                            .foregroundStyle(Theme.ink3)
                            .monospacedDigit()
                    }
                    AppIconView(name: "chevron", color: Theme.ink3, size: 14)
                }
                .padding(.vertical, 10)

                if !last { Rectangle().fill(Theme.sep).frame(height: 0.5) }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    ZStack(alignment: .bottom) {
        Theme.bg.ignoresSafeArea()
        WorkoutsView(accent: Theme.accent, onOpenWorkout: { _ in })
            .environmentObject(HealthDataStore())
    }
}
