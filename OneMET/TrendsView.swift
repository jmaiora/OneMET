import SwiftUI

// TrendsView.swift — OneMET Trends screen (live 14-day data via HealthDataStore).

struct TrendsView: View {
    @EnvironmentObject var store: HealthDataStore
    var accent: Color
    var mmol: Bool = false

    var body: some View {
        let d = store.data
        let up = d.tirDeltaVsPrior >= 0

        ScreenScaffold {
            AppHeader(title: "Trends", date: "Last 14 Days", accent: accent)

            // Time in range trend
            Card(title: "Time in Range", icon: "drop", iconColor: Theme.green, right: "14-day") {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("\(d.avgTir14)%")
                        .font(.system(size: 34, weight: .bold))
                        .foregroundStyle(Theme.green)
                        .monospacedDigit()
                    Text("\(up ? "↑" : "↓") \(abs(d.tirDeltaVsPrior))% vs prior")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(up ? Theme.green : Theme.red)
                }
                .padding(.bottom, 4)

                TrendBars(height: 150, accent: accent, data: d.tirTrend)
            }

            // Activity vs range correlation
            Card(title: "Activity vs. Range", icon: "bolt", iconColor: accent) {
                Text("Days with higher-intensity exercise track with more time in range.")
                    .font(.system(size: 13.5))
                    .foregroundStyle(Theme.ink)
                    .lineSpacing(2)
                    .padding(.bottom, 10)
                    .fixedSize(horizontal: false, vertical: true)

                CorrScatter(height: 168, accent: accent, data: d.corr)

                HStack(spacing: 9) {
                    AppIconView(name: "activity", color: accent, size: 18)
                    (Text("Higher-intensity days").fontWeight(.bold).foregroundColor(accent)
                     + Text(" tend to show more time in range.").foregroundColor(Theme.ink))
                        .font(.system(size: 13, weight: .medium))
                        .lineSpacing(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(accent.opacity(0.07))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .padding(.top, 12)
            }

            // 14-day summary
            Card(title: "14-Day Summary") {
                LazyVGrid(columns: [GridItem(.flexible(), alignment: .leading),
                                    GridItem(.flexible(), alignment: .leading)], spacing: 18) {
                    StatBlock(label: "Avg Glucose", value: d.avgGlucose14 > 0 ? fmtGlucose(d.avgGlucose14, mmol: mmol) : "—", unit: mmol ? "mmol/L" : "mg/dL")
                    StatBlock(label: "GMI / A1C", value: d.gmi > 0 ? String(format: "%.1f", d.gmi) : "—", unit: "%", color: Theme.green)
                    StatBlock(label: "Avg MET·min", value: "\(d.avgMet14)")
                    StatBlock(label: "Low Events", value: "\(d.lowEvents14)", color: Theme.red)
                    StatBlock(label: "Avg Steps", value: d.avgSteps14.formatted(), color: Theme.teal)
                    StatBlock(label: "Workouts", value: "\(d.workoutCount14)", color: accent)
                }
            }
        }
    }
}

#Preview {
    ZStack { Theme.bg.ignoresSafeArea(); TrendsView(accent: Theme.accent).environmentObject(HealthDataStore()) }
}
