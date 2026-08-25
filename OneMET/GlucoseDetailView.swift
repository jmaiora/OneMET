import SwiftUI

// GlucoseDetailView.swift — glucose detail overlay (live data via HealthDataStore).

struct GlucoseDetailView: View {
    @EnvironmentObject var store: HealthDataStore
    var accent: Color
    var unit: GlucoseUnit = .mgdl
    var lang: AppLanguage = .en
    var onBack: () -> Void

    var body: some View {
        let d = store.data
        let st = glucoseStatus(d.current, low: d.targetLow, high: d.targetHigh)
        let trendKey = d.currentTrend == .down ? "glucose.falling"
                     : d.currentTrend == .up ? "glucose.rising" : "glucose.steady"
        let trendWord = lang.t(trendKey)

        ScreenScaffold {
            Button(action: onBack) {
                HStack(spacing: 6) {
                    Image(systemName: "chevron.left").font(.system(size: 17, weight: .semibold))
                    Text(lang.t("summary.title")).font(.system(size: 17))
                }
                .foregroundStyle(accent)
            }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .leading, spacing: 2) {
                Text(Date().formatted(.dateTime.weekday(.wide).month(.abbreviated).day()
                                         .locale(lang.locale)).uppercased())
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.ink2)
                    .tracking(0.2)
                Text(lang.t("summary.glucose"))
                    .font(.system(size: 32, weight: .bold))
                    .foregroundStyle(Theme.ink)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Big reading + chart
            Card {
                HStack(alignment: .bottom) {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(d.hasGlucose ? unit.value(d.current) : "—")
                            .font(.system(size: 52, weight: .bold))
                            .foregroundStyle(Theme.ink)
                            .monospacedDigit()
                        Text(unit.rawValue)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Theme.ink2)
                    }
                    Spacer()
                    if d.hasGlucose {
                        Chip(color: st.color) { Dot(color: st.color); Text("\(st.label(lang)) · \(trendWord)") }
                    }
                }
                .padding(.bottom, 8)

                GlucoseChart(height: 184, unit: unit, lang: lang, accent: accent,
                             data: d.glucose, currentIdx: d.currentIdx,
                             runFrom: d.runFrom, runTo: d.runTo,
                             low: d.targetLow, high: d.targetHigh)
            }

            // Today stats
            Card(title: lang.t("glucoseDetail.today")) {
                LazyVGrid(columns: [GridItem(.flexible(), alignment: .leading),
                                    GridItem(.flexible(), alignment: .leading)], spacing: 18) {
                    StatBlock(label: lang.t("glucoseDetail.average"), value: unit.value(d.avg), unit: unit.rawValue)
                    StatBlock(label: lang.t("glucoseDetail.timeInRange"), value: "\(d.tir.inRange)", unit: "%", color: Theme.green)
                    StatBlock(label: lang.t("glucoseDetail.lowest"), value: unit.value(d.lowestToday), color: Theme.red)
                    StatBlock(label: lang.t("glucoseDetail.highest"), value: unit.value(d.highestToday), color: Theme.amber)
                    StatBlock(label: lang.t("glucoseDetail.stdDev"), value: unit.value(d.sdToday))
                    StatBlock(label: lang.t("glucoseDetail.gmi"), value: d.avg > 0 ? String(format: "%.1f", HealthMath.gmi(meanMgdl: d.avg)) : "—", unit: "%")
                }

                Rectangle().fill(Theme.hair).frame(height: 1).padding(.vertical, 14)

                Text(lang.t("glucoseDetail.distribution"))
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundStyle(Theme.ink2)
                    .tracking(0.2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.bottom, 8)

                TIRBar(height: 16, tir: d.tir)

                HStack(spacing: 14) {
                    TIRLegend(label: lang.t("summary.low"), value: d.tir.low, color: Theme.red)
                    TIRLegend(label: lang.t("summary.inRange"), value: d.tir.inRange, color: Theme.green)
                    TIRLegend(label: lang.t("summary.high"), value: d.tir.high, color: Theme.amber)
                }
                .padding(.top, 9)
            }

            if !d.events.isEmpty {
                EventsCard(events: d.events, accent: accent, lang: lang)
            }
        }
    }
}

// MARK: - Events card

struct EventsCard: View {
    var events: [DayEvent]
    var accent: Color
    var lang: AppLanguage = .en

    var body: some View {
        Card(title: lang.t("glucoseDetail.events"), icon: "bolt", iconColor: accent) {
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
