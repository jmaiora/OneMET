import SwiftUI

// WorkoutDetailView.swift — single-session detail overlay (v2).

struct WorkoutDetailView: View {
    var session: WorkoutSession
    var accent: Color
    var onBack: () -> Void

    var body: some View {
        let w = session
        let dropColor = w.glucoseDelta < 0 ? Theme.green : Theme.amber

        ScreenScaffold {
            Button(action: onBack) {
                HStack(spacing: 6) {
                    Image(systemName: "chevron.left").font(.system(size: 17, weight: .semibold))
                    Text("Workouts").font(.system(size: 17))
                }
                .foregroundStyle(accent)
            }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity, alignment: .leading)

            // Title + sport icon
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(w.day) · \(w.time)".uppercased())
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Theme.ink2)
                        .tracking(0.2)
                    Text(w.name)
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(Theme.ink)
                }
                Spacer()
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous).fill(accent.opacity(0.09))
                    AppIconView(name: w.icon, color: accent, size: 24)
                }
                .frame(width: 44, height: 44)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Stats + curve
            Card {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), alignment: .leading), count: 3), spacing: 14) {
                    StatBlock(label: "Duration", value: "\(w.durMin)", unit: "min")
                    StatBlock(label: "Distance", value: w.dist)
                    StatBlock(label: "Calories", value: "\(w.kcal)", unit: "kcal")
                    StatBlock(label: "Avg MET", value: fmtNum(w.avgMet))
                    StatBlock(label: "Avg HR", value: "\(w.hr)", unit: "bpm", color: Theme.red)
                    StatBlock(label: "Glucose Δ", value: "\(w.glucoseDelta > 0 ? "+" : "")\(w.glucoseDelta)", unit: "mg/dL", color: dropColor)
                }
                .padding(.bottom, 14)

                if !w.curve.isEmpty {
                    WorkoutChart(session: w, accent: accent, height: 168)
                } else {
                    Text("No CGM data around this session.")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.ink2)
                }
            }

            // Activity Insight — fixed blue per the design
            InsightBanner(text: w.insight, accent: Color(hex: "2A6FDB"))
        }
    }
}

#Preview {
    ZStack {
        Theme.bg.ignoresSafeArea()
        WorkoutDetailView(session: SampleData.workoutHistory[0].sessions[0], accent: Theme.accent, onBack: {})
    }
}
