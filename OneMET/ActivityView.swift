import SwiftUI
import Charts

struct ActivityView: View {
    @EnvironmentObject var hk: HealthKitManager

    private let days = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: Theme.sectionGap) {

                    // Steps bar chart
                    SectionCard(title: "Steps – Last 7 Days") {
                        Chart {
                            ForEach(Array(hk.weeklySteps.enumerated()), id: \.offset) { idx, val in
                                BarMark(
                                    x: .value("Day", days[idx % 7]),
                                    y: .value("Steps", val)
                                )
                                .foregroundStyle(Theme.steps.gradient)
                                .cornerRadius(6)
                            }
                        }
                        .frame(height: 180)
                        .chartYAxis {
                            AxisMarks(position: .leading)
                        }
                    }

                    // Calories bar chart
                    SectionCard(title: "Active Calories – Last 7 Days") {
                        Chart {
                            ForEach(Array(hk.weeklyCalories.enumerated()), id: \.offset) { idx, val in
                                BarMark(
                                    x: .value("Day", days[idx % 7]),
                                    y: .value("kcal", val)
                                )
                                .foregroundStyle(Theme.calories.gradient)
                                .cornerRadius(6)
                            }
                        }
                        .frame(height: 180)
                    }

                    // Today summary
                    SectionCard(title: "Today at a Glance") {
                        HStack(spacing: 0) {
                            GlanceStat(label: "Steps",
                                       value: "\(hk.stepsToday)",
                                       color: Theme.steps)
                            Divider().frame(height: 48)
                            GlanceStat(label: "Cal",
                                       value: "\(Int(hk.caloriesActive))",
                                       color: Theme.calories)
                            Divider().frame(height: 48)
                            GlanceStat(label: "HR",
                                       value: "\(Int(hk.heartRateLatest)) bpm",
                                       color: Theme.heartRate)
                        }
                    }
                }
                .padding(.vertical)
            }
            .background(Theme.background)
            .navigationTitle("Activity")
            .navigationBarTitleDisplayMode(.large)
        }
    }
}

// MARK: – Helpers
struct SectionCard<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(Theme.Font.headline)
                .padding(.horizontal)
            content
                .padding(.horizontal)
        }
        .padding(.vertical)
        .background(Theme.card)
        .cornerRadius(Theme.cornerRadius)
        .padding(.horizontal)
    }
}

struct GlanceStat: View {
    let label: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(Theme.Font.headline)
                .foregroundStyle(color)
            Text(label)
                .font(Theme.Font.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    ActivityView()
        .environmentObject(HealthKitManager())
}
