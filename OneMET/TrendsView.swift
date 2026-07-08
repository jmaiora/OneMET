import SwiftUI

// TrendsView.swift — OneMET Trends screen
// Ported from the Claude Design handoff (screens.jsx → TrendsScreen).

struct TrendsView: View {
    var accent: Color
    var mmol: Bool = false

    var body: some View {
        ScreenScaffold {
            AppHeader(title: "Trends", date: "Last 14 Days", accent: accent)

            // Time in range trend
            Card(title: "Time in Range", icon: "drop", iconColor: Theme.green, right: "14-day") {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("82%")
                        .font(.system(size: 34, weight: .bold))
                        .foregroundStyle(Theme.green)
                        .monospacedDigit()
                    Text("↑ 8% vs prior")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Theme.green)
                }
                .padding(.bottom, 4)

                TrendBars(height: 150, accent: accent)
            }

            // Activity vs range correlation
            Card(title: "Activity vs. Range", icon: "bolt", iconColor: accent) {
                Text("Days with more MET minutes track with more time in range.")
                    .font(.system(size: 13.5))
                    .foregroundStyle(Theme.ink)
                    .lineSpacing(2)
                    .padding(.bottom, 10)
                    .fixedSize(horizontal: false, vertical: true)

                CorrScatter(height: 168, accent: accent)

                HStack(spacing: 9) {
                    AppIconView(name: "activity", color: accent, size: 18)
                    (Text("+0.7%").fontWeight(.bold).foregroundColor(accent)
                     + Text(" time in range for every extra 50 MET·min.").foregroundColor(Theme.ink))
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
                    StatBlock(label: "Avg Glucose", value: fmtGlucose(SampleData.avg, mmol: mmol), unit: mmol ? "mmol/L" : "mg/dL")
                    StatBlock(label: "GMI / A1C", value: "6.4", unit: "%", color: Theme.green)
                    StatBlock(label: "Avg MET·min", value: "412")
                    StatBlock(label: "Low Events", value: "3", color: Theme.red)
                    StatBlock(label: "Avg Steps", value: "9,140", color: Theme.teal)
                    StatBlock(label: "Workouts", value: "9", color: accent)
                }
            }
        }
    }
}

#Preview {
    ZStack { Theme.bg.ignoresSafeArea(); TrendsView(accent: Theme.accent) }
}
