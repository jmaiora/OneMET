import SwiftUI
import Charts

struct TrendsView: View {
    @EnvironmentObject var hk: HealthKitManager

    private let days = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: Theme.sectionGap) {

                    // Heart Rate trend (line chart)
                    SectionCard(title: "Heart Rate – 7 Day Average") {
                        Chart {
                            ForEach(Array(hk.weeklyHR.enumerated()), id: \.offset) { idx, val in
                                LineMark(
                                    x: .value("Day", days[idx % 7]),
                                    y: .value("BPM", val)
                                )
                                .foregroundStyle(Theme.heartRate)
                                .interpolationMethod(.catmullRom)

                                AreaMark(
                                    x: .value("Day", days[idx % 7]),
                                    y: .value("BPM", val)
                                )
                                .foregroundStyle(Theme.heartRate.opacity(0.15))
                                .interpolationMethod(.catmullRom)

                                PointMark(
                                    x: .value("Day", days[idx % 7]),
                                    y: .value("BPM", val)
                                )
                                .foregroundStyle(Theme.heartRate)
                            }
                        }
                        .frame(height: 200)
                        .chartYScale(domain: .automatic(includesZero: false))
                    }

                    // Steps trend (line chart)
                    SectionCard(title: "Steps Trend") {
                        Chart {
                            ForEach(Array(hk.weeklySteps.enumerated()), id: \.offset) { idx, val in
                                LineMark(
                                    x: .value("Day", days[idx % 7]),
                                    y: .value("Steps", val)
                                )
                                .foregroundStyle(Theme.steps)
                                .interpolationMethod(.catmullRom)

                                AreaMark(
                                    x: .value("Day", days[idx % 7]),
                                    y: .value("Steps", val)
                                )
                                .foregroundStyle(Theme.steps.opacity(0.15))
                                .interpolationMethod(.catmullRom)
                            }
                        }
                        .frame(height: 180)
                    }

                    // Insight cards
                    VStack(spacing: 12) {
                        InsightRow(icon: "moon.fill",
                                   color: Theme.sleep,
                                   label: "Last Night's Sleep",
                                   value: String(format: "%.1f hrs", hk.sleepHoursLast))

                        InsightRow(icon: "waveform.path.ecg",
                                   color: Theme.hrv,
                                   label: "Latest HRV",
                                   value: "\(Int(hk.hrvLatest)) ms")

                        InsightRow(icon: "brain.head.profile",
                                   color: Theme.mindfulness,
                                   label: "Mindful Minutes Today",
                                   value: "\(Int(hk.mindfulMinutes)) min")
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical)
            }
            .background(Theme.background)
            .navigationTitle("Trends")
            .navigationBarTitleDisplayMode(.large)
        }
    }
}

struct InsightRow: View {
    let icon: String
    let color: Color
    let label: String
    let value: String

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)
                .frame(width: 36)
            Text(label)
                .font(Theme.Font.body)
                .foregroundStyle(.primary)
            Spacer()
            Text(value)
                .font(Theme.Font.headline)
                .foregroundStyle(color)
        }
        .padding(Theme.cardPadding)
        .background(Theme.card)
        .cornerRadius(Theme.cornerRadius)
    }
}

#Preview {
    TrendsView()
        .environmentObject(HealthKitManager())
}
