import SwiftUI

struct SummaryView: View {
    @EnvironmentObject var hk: HealthKitManager

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: Theme.sectionGap) {
                    // Date header
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Today")
                                .font(Theme.Font.title)
                            Text(Date().formatted(.dateTime.weekday(.wide).month().day()))
                                .font(Theme.Font.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                    .padding(.horizontal)

                    // Ring / primary metric card
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                        MetricCard(title: "Steps",
                                   value: String(hk.stepsToday),
                                   unit: "steps",
                                   color: Theme.steps,
                                   icon: "figure.walk")

                        MetricCard(title: "Active Cal",
                                   value: String(Int(hk.caloriesActive)),
                                   unit: "kcal",
                                   color: Theme.calories,
                                   icon: "flame.fill")

                        MetricCard(title: "Heart Rate",
                                   value: String(Int(hk.heartRateLatest)),
                                   unit: "bpm",
                                   color: Theme.heartRate,
                                   icon: "heart.fill")

                        MetricCard(title: "HRV",
                                   value: String(Int(hk.hrvLatest)),
                                   unit: "ms",
                                   color: Theme.hrv,
                                   icon: "waveform.path.ecg")

                        MetricCard(title: "Sleep",
                                   value: String(format: "%.1f", hk.sleepHoursLast),
                                   unit: "hrs",
                                   color: Theme.sleep,
                                   icon: "moon.fill")

                        MetricCard(title: "Mindfulness",
                                   value: String(Int(hk.mindfulMinutes)),
                                   unit: "min",
                                   color: Theme.mindfulness,
                                   icon: "brain.head.profile")
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical)
            }
            .background(Theme.background)
            .navigationTitle("")
            .navigationBarHidden(true)
        }
    }
}

// MARK: – Metric Card
struct MetricCard: View {
    let title: String
    let value: String
    let unit: String
    let color: Color
    let icon: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(color)
                Spacer()
            }
            Text(value)
                .font(Theme.Font.largeNum)
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(unit.uppercased())
                .font(Theme.Font.caption)
                .foregroundStyle(.secondary)
            Text(title)
                .font(Theme.Font.caption)
                .foregroundStyle(.secondary)
        }
        .padding(Theme.cardPadding)
        .background(Theme.card)
        .cornerRadius(Theme.cornerRadius)
    }
}

#Preview {
    SummaryView()
        .environmentObject(HealthKitManager())
}
