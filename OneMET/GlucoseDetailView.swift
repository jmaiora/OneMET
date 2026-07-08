import SwiftUI

// GlucoseDetailView.swift — glucose detail overlay
// Ported from the Claude Design handoff (screens.jsx → GlucoseDetail).

struct GlucoseDetailView: View {
    var accent: Color
    var mmol: Bool = false
    var onBack: () -> Void

    var body: some View {
        let st = glucoseStatus(SampleData.current)

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
                Text("FRIDAY, JUN 19")
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
                        Text(fmtGlucose(SampleData.current, mmol: mmol))
                            .font(.system(size: 52, weight: .bold))
                            .foregroundStyle(Theme.ink)
                            .monospacedDigit()
                        Text(mmol ? "mmol/L" : "mg/dL")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Theme.ink2)
                    }
                    Spacer()
                    Chip(color: st.color) { Dot(color: st.color); Text("\(st.label) · falling") }
                }
                .padding(.bottom, 8)

                GlucoseChart(height: 184, mmol: mmol, accent: accent)
            }

            // Today stats
            Card(title: "Today") {
                LazyVGrid(columns: [GridItem(.flexible(), alignment: .leading),
                                    GridItem(.flexible(), alignment: .leading)], spacing: 18) {
                    StatBlock(label: "Average", value: fmtGlucose(SampleData.avg, mmol: mmol), unit: mmol ? "mmol/L" : "mg/dL")
                    StatBlock(label: "Time in Range", value: "\(SampleData.tir.inRange)", unit: "%", color: Theme.green)
                    StatBlock(label: "Lowest", value: fmtGlucose(68, mmol: mmol), color: Theme.red)
                    StatBlock(label: "Highest", value: fmtGlucose(191, mmol: mmol), color: Theme.amber)
                    StatBlock(label: "Std. Dev", value: mmol ? "1.8" : "32")
                    StatBlock(label: "GMI", value: "6.4", unit: "%")
                }

                Rectangle().fill(Theme.hair).frame(height: 1).padding(.vertical, 14)

                Text("RANGE DISTRIBUTION")
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundStyle(Theme.ink2)
                    .tracking(0.2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.bottom, 8)

                TIRBar(height: 16)

                HStack(spacing: 14) {
                    TIRLegend(label: "Low", value: SampleData.tir.low, color: Theme.red)
                    TIRLegend(label: "In Range", value: SampleData.tir.inRange, color: Theme.green)
                    TIRLegend(label: "High", value: SampleData.tir.high, color: Theme.amber)
                }
                .padding(.top, 9)
            }

            EventsCard(accent: accent)
        }
    }
}

// MARK: - Events card

struct EventsCard: View {
    var accent: Color

    private struct Ev: Identifiable {
        let id = UUID()
        let t: String
        let d: String
        let c: Color
    }
    private let events: [Ev] = [
        Ev(t: "7:30 AM",  d: "Breakfast · 62g carbs", c: Theme.amber),
        Ev(t: "8:12 AM",  d: "Walk · −9 mg/dL",       c: Theme.green),
        Ev(t: "12:15 PM", d: "Lunch · 48g carbs",     c: Theme.amber),
        Ev(t: "4:08 PM",  d: "Run · −38 mg/dL",       c: Theme.green),
        Ev(t: "5:55 PM",  d: "Snack · 22g (low treatment)", c: Theme.red)
    ]

    var body: some View {
        Card(title: "Events", icon: "bolt", iconColor: accent) {
            VStack(spacing: 0) {
                ForEach(Array(events.enumerated()), id: \.element.id) { i, e in
                    VStack(spacing: 0) {
                        HStack(spacing: 12) {
                            Circle().fill(e.c).frame(width: 8, height: 8)
                            Text(e.t)
                                .font(.system(size: 13))
                                .foregroundStyle(Theme.ink2)
                                .frame(width: 64, alignment: .leading)
                                .monospacedDigit()
                            Text(e.d)
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
    }
}
