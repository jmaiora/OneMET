import SwiftUI

// GlucoseDetailView.swift — glucose detail overlay (live data via HealthDataStore).

struct GlucoseDetailView: View {
    @EnvironmentObject var store: HealthDataStore
    var accent: Color
    var mmol: Bool = false
    var onBack: () -> Void

    var body: some View {
        let d = store.data
        let st = glucoseStatus(d.current)
        let trendWord = d.currentTrend == .down ? "falling" : d.currentTrend == .up ? "rising" : "steady"
        let unit = mmol ? "mmol/L" : "mg/dL"

        ScreenScaffold {
            Button(action: onBack) {
                HStack(spacing: 6) {
                    Image(systemName: "chevron.left").font(.system(size: 17, weight: .semibold))
                    Text("Summary").font(.system(size: 17))
                }
                .foregroundStyle(accent)
            }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .leading, spacing: 2) {
                Text(Date().formatted(.dateTime.weekday(.wide).month(.abbreviated).day()).uppercased())
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.ink2)
                    .tracking(0.2)
                Text("Glucose")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundStyle(Theme.ink)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Big reading + chart
            Card {
                HStack(alignment: .bottom) {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(d.hasGlucose ? fmtGlucose(d.current, mmol: mmol) : "—")
                            .font(.system(size: 52, weight: .bold))
                            .foregroundStyle(Theme.ink)
                            .monospacedDigit()
                        Text(unit)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Theme.ink2)
                    }
                    Spacer()
                    if d.hasGlucose {
                        Chip(color: st.color) { Dot(color: st.color); Text("\(st.label) · \(trendWord)") }
                    }
                }
                .padding(.bottom, 8)

                GlucoseChart(height: 184, mmol: mmol, accent: accent,
                             data: d.glucose, currentIdx: d.currentIdx,
                             runFrom: d.runFrom, runTo: d.runTo)
            }

            // Today stats
            Card(title: "Today") {
                LazyVGrid(columns: [GridItem(.flexible(), alignment: .leading),
                                    GridItem(.flexible(), alignment: .leading)], spacing: 18) {
                    StatBlock(label: "Average", value: fmtGlucose(d.avg, mmol: mmol), unit: unit)
                    StatBlock(label: "Time in Range", value: "\(d.tir.inRange)", unit: "%", color: Theme.green)
                    StatBlock(label: "Lowest", value: fmtGlucose(d.lowestToday, mmol: mmol), color: Theme.red)
                    StatBlock(label: "Highest", value: fmtGlucose(d.highestToday, mmol: mmol), color: Theme.amber)
                    StatBlock(label: "Std. Dev", value: mmol ? String(format: "%.1f", d.sdToday / 18) : "\(Int(d.sdToday))")
                    StatBlock(label: "GMI", value: d.avg > 0 ? String(format: "%.1f", HealthMath.gmi(meanMgdl: d.avg)) : "—", unit: "%")
                }

                Rectangle().fill(Theme.hair).frame(height: 1).padding(.vertical, 14)

                Text("RANGE DISTRIBUTION")
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundStyle(Theme.ink2)
                    .tracking(0.2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.bottom, 8)

                TIRBar(height: 16, tir: d.tir)

                HStack(spacing: 14) {
                    TIRLegend(label: "Low", value: d.tir.low, color: Theme.red)
                    TIRLegend(label: "In Range", value: d.tir.inRange, color: Theme.green)
                    TIRLegend(label: "High", value: d.tir.high, color: Theme.amber)
                }
                .padding(.top, 9)
            }

            if !d.events.isEmpty {
                EventsCard(events: d.events, accent: accent)
            }
        }
    }
}

// MARK: - Events card

struct EventsCard: View {
    var events: [DayEvent]
    var accent: Color

    var body: some View {
        Card(title: "Events", icon: "bolt", iconColor: accent) {
            VStack(spacing: 0) {
                ForEach(Array(events.enumerated()), id: \.element.id) { i, e in
                    VStack(spacing: 0) {
                        HStack(spacing: 12) {
                            Circle().fill(e.color).frame(width: 8, height: 8)
                            Text(e.time)
                                .font(.system(size: 13))
                                .foregroundStyle(Theme.ink2)
                                .frame(width: 64, alignment: .leading)
                                .monospacedDigit()
                            Text(e.text)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(Theme.ink)
                            Spacer(minLength: 0)
                        }
                        .padding(.vertical, 9)

                        if i != events.count - 1 {
                            Rectangle().fill(Theme.sep).frame(height: 0.5)
                        }
                    }
                }
            }
        }
    }
}

#Preview {
    ZStack {
        Theme.bg.ignoresSafeArea()
        GlucoseDetailView(accent: Theme.accent, onBack: {})
            .environmentObject(HealthDataStore())
    }
}
