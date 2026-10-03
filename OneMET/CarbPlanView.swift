import SwiftUI

// CarbPlanView.swift — the answer screen for the Plan tab.
//
// Everything here is a conclusion drawn from what you set on the Plan tab: whether to
// start, what to eat during, and the caveats. Splitting it off keeps the planning tab to
// inputs only, and means the numbers arrive as a deliberate act rather than shifting
// under you while you drag a dial.
//
// Illustrative guidance, NOT medical advice.

struct CarbPlanView: View {
    var guide: RunGuide
    var sport: Sport
    var durationMin: Int
    var met: Double
    var accent: Color
    var unit: GlucoseUnit = .mgdl
    var lang: AppLanguage = .en
    /// Re-plans with a new feed interval (minutes); PlanView rebuilds `guide` from it.
    var onUpdateInterval: (Int) -> Void = { _ in }
    var onBack: () -> Void

    /// Slider position, in minutes. Only applied to the plan when Update is tapped, so the
    /// timeline doesn't reshuffle under your finger while you drag.
    @State private var intervalDraft: Double = Double(carbFeedIntervalMin)

    private var difficulty: WorkoutDifficulty { WorkoutDifficulty(met: met) }

    var body: some View {
        ScreenScaffold {
            BackBar(title: lang.t("plan.title"), accent: accent, action: onBack)

            VStack(alignment: .leading, spacing: 2) {
                // Restates the session this plan is for, so the numbers can't be read
                // against the wrong assumptions once you've scrolled away from the dials.
                Text(lang.t("plan.forSession", sport.name(lang), String(durationMin),
                            fmtNum((met * 10).rounded() / 10)).uppercased())
                    .font(.app(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.ink2)
                    .tracking(0.2)
                    .fixedSize(horizontal: false, vertical: true)
                Text(lang.t("plan.carbPlan"))
                    .font(.app(size: 32, weight: .bold))
                    .foregroundStyle(Theme.ink)
                    // The Spanish title runs to two lines; let it, rather than truncate.
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            startBanner

            duringBanner

            if let after = guide.afterText {
                afterCard(after)
            }

            // Only meaningful when there's an hourly rate to split into feeds.
            if guide.duringPerHourG > 0 {
                intervalCard
            }

            // Two headlines, both bold beside their icon — the reasoning behind each is in
            // Settings ▸ Help & FAQ.
            Card(title: lang.t("plan.goodToKnow")) {
                VStack(alignment: .leading, spacing: 14) {
                    goodEntry("checkmark.seal.fill", Theme.green,
                              lang.t("philosophy.short", unit.range(140, 200)), nil)
                    goodEntry("chart.line.uptrend.xyaxis", accent,
                              lang.t("learn.short"), nil)
                }
            }

            disclaimer
        }
        .onAppear { intervalDraft = Double(guide.duringIntervalMin) }
    }

    // MARK: - After (interval / resistance)

    private func afterCard(_ text: String) -> some View {
        Card(title: lang.t("plan.after"), icon: "chart", iconColor: Theme.amber, pad: 14) {
            VStack(alignment: .leading, spacing: 12) {
                Text(text)
                    .font(Theme.noteFont)
                    .lineSpacing(Theme.noteLineSpacing)
                    .foregroundStyle(Theme.ink)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(alignment: .top, spacing: 9) {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.app(size: 15, weight: .semibold))
                        .foregroundStyle(accent)
                        .frame(width: 20)
                    Text(lang.t("after.mixedTip"))
                        .font(Theme.noteFont.weight(.semibold))
                        .lineSpacing(Theme.noteLineSpacing)
                        .foregroundStyle(Theme.ink)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    // MARK: - Feed interval

    private var intervalCard: some View {
        let draft = Int(intervalDraft)
        let changed = draft != guide.duringIntervalMin
        return Card(title: lang.t("plan.interval"), icon: "clock", iconColor: Theme.ringMet, pad: 14) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(lang.t("plan.intervalEvery", String(draft)))
                        .font(.app(size: 17, weight: .semibold))
                        .foregroundStyle(Theme.ink)
                        .monospacedDigit()
                    Spacer()
                }
                Slider(value: $intervalDraft,
                       in: Double(carbFeedIntervalRange.lowerBound)...Double(carbFeedIntervalRange.upperBound),
                       step: 5) {
                    Text(lang.t("plan.interval"))
                } minimumValueLabel: {
                    Text("\(carbFeedIntervalRange.lowerBound) min")
                        .font(.app(size: 13.5, weight: .medium)).foregroundStyle(Theme.ink2)
                } maximumValueLabel: {
                    Text("\(carbFeedIntervalRange.upperBound) min")
                        .font(.app(size: 13.5, weight: .medium)).foregroundStyle(Theme.ink2)
                }
                .tint(Theme.ringMet)

                Button { onUpdateInterval(draft) } label: {
                    Text(lang.t("plan.update"))
                        .font(.app(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(changed ? accent : Theme.ink3.opacity(0.5))
                        .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
                }
                .buttonStyle(.plain)
                .disabled(!changed)
            }
        }
    }

    // MARK: - Start decision banner

    private var startBanner: some View {
        let s = statusStyle(guide.status)
        return VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 8) {
                Image(systemName: s.icon).font(.app(size: 18, weight: .bold)).foregroundStyle(.white)
                Text(guide.startTitle)
                    .font(.app(size: 18, weight: .bold))
                    .foregroundStyle(.white)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Text(guide.startReason)
                .font(.app(size: 15, weight: .medium))
                .foregroundStyle(.white.opacity(0.95))
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(s.color)
        .clipShape(RoundedRectangle(cornerRadius: Theme.radius, style: .continuous))
        .shadow(color: s.color.opacity(0.28), radius: 9, x: 0, y: 6)
    }

    private func statusStyle(_ status: StartStatus) -> (color: Color, icon: String) {
        switch status {
        case .go:      return (Theme.green, "checkmark.circle.fill")
        case .topUp:   return (Theme.amber, "plus.circle.fill")
        case .wait:    return (Theme.amber, "exclamationmark.circle.fill")
        case .stop:    return (Theme.red, "xmark.octagon.fill")
        case .unknown: return (Color(hex: "8E8E93"), "questionmark.circle.fill")
        }
    }

    // MARK: - During

    private var duringBanner: some View {
        let c = Theme.ringMet
        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                AppIconView(name: "fork", color: .white, size: 16)
                Text(lang.t("plan.during", difficulty.label(lang)))
                    .font(.app(size: 16, weight: .bold))
                    .foregroundStyle(.white)
                Spacer(minLength: 8)
                Text(guide.bandDetail.uppercased())
                    .font(.app(size: 13.5, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.85))
                    .tracking(0.2)
                    .multilineTextAlignment(.trailing)
            }
            if guide.duringPerHourG > 0 && guide.duringTotalG > 0 {
                // One row per intake at its elapsed time, closed by the finish line with the
                // session total — the schedule reads top to bottom as the run unfolds.
                let stops = timelineStops
                VStack(spacing: 0) {
                    ForEach(Array(stops.enumerated()), id: \.offset) { i, stop in
                        timelineRow(stop, first: i == 0, last: i == stops.count - 1)
                    }
                }
                // Only the source is kept here; the reasoning lives in Help & FAQ.
                (Text(guide.duringText)
                    + Text("1").font(.app(size: 11.5, weight: .bold)).baselineOffset(6))
                    .font(Theme.fineFont.weight(.medium))
                    .foregroundStyle(.white.opacity(0.85))
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                // Nothing to schedule: the advice is to carry carbs, not to eat them.
                Text(guide.duringText)
                    .font(Theme.noteFont.weight(.medium))
                    .lineSpacing(Theme.noteLineSpacing)
                    .foregroundStyle(.white.opacity(0.95))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(c)
        .clipShape(RoundedRectangle(cornerRadius: Theme.radius, style: .continuous))
        .shadow(color: c.opacity(0.28), radius: 9, x: 0, y: 6)
    }

    // MARK: - During timeline

    private struct TimelineStop {
        let minute: Int
        let label: String
        let grams: Int?          // nil: a marker with nothing to take (start without carbs)
        let isFinish: Bool
    }

    /// Start (with its carbs, if any), the scheduled intakes, then the finish.
    private var timelineStops: [TimelineStop] {
        var stops = [TimelineStop(minute: 0, label: lang.t("plan.tlStart"),
                                  grams: guide.duringStartG > 0 ? guide.duringStartG : nil,
                                  isFinish: false)]
        for feed in guide.duringSchedule {
            stops.append(TimelineStop(minute: feed.minute, label: lang.t("plan.tlRefuel"),
                                      grams: feed.grams, isFinish: false))
        }
        stops.append(TimelineStop(minute: durationMin, label: lang.t("plan.tlFinish"),
                                  grams: nil, isFinish: true))
        return stops
    }

    private func timelineRow(_ stop: TimelineStop, first: Bool, last: Bool) -> some View {
        HStack(spacing: 12) {
            Text(clock(stop.minute))
                .font(.app(size: 15, weight: .semibold))
                .monospacedDigit()
                .foregroundStyle(.white.opacity(0.85))
                .frame(width: 46 * Theme.textScale, alignment: .trailing)

            // Rail: line segments above and below the dot join up across rows, since the
            // rows stack with no spacing.
            VStack(spacing: 0) {
                Rectangle().fill(.white.opacity(first ? 0 : 0.45)).frame(width: 2)
                Circle()
                    .fill(stop.isFinish ? Color.clear : Color.white)
                    .overlay(Circle().stroke(.white, lineWidth: 2.5))
                    .frame(width: 13, height: 13)
                Rectangle().fill(.white.opacity(last ? 0 : 0.45)).frame(width: 2)
            }
            .frame(width: 14)

            Text(stop.label.uppercased())
                .font(.app(size: 13.5, weight: .semibold))
                .tracking(0.3)
                .foregroundStyle(.white.opacity(0.85))

            Spacer(minLength: 8)

            if stop.isFinish {
                Text(lang.t("plan.perHourTotal", String(guide.duringPerHourG), String(guide.duringTotalG)))
                    .font(.app(size: 14.5, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.9))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            } else if let g = stop.grams {
                Text("~\(g) g")
                    .font(.app(size: 24, weight: .heavy))
                    .foregroundStyle(.white)
                    .monospacedDigit()
            }
        }
        .frame(height: 46 * Theme.textScale)
    }

    /// Elapsed time as h:mm — "0:45", "1:30".
    private func clock(_ minutes: Int) -> String {
        "\(minutes / 60):" + String(format: "%02d", minutes % 60)
    }

    /// A Good-to-know row: heading beside the icon, with an optional line underneath for
    /// the points that have a longer explanation waiting in Help & FAQ.
    private func goodEntry(_ systemIcon: String, _ color: Color,
                           _ title: String, _ text: String?) -> some View {
        HStack(alignment: .top, spacing: 9) {
            Image(systemName: systemIcon).font(.app(size: 15)).foregroundStyle(color).frame(width: 20)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(Theme.noteFont.weight(.semibold))
                    .foregroundStyle(Theme.ink)
                if let text {
                    Text(text)
                        .font(Theme.noteFont)
                        .lineSpacing(Theme.noteLineSpacing)
                        .foregroundStyle(Theme.ink2)
                }
            }
            .lineSpacing(2)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - Disclaimer + sources

    private var disclaimer: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.app(size: 14.5))
                    .foregroundStyle(Theme.amber)
                Text(lang.t("plan.disclaimer"))
                    .font(Theme.noteFont.weight(.medium))
                    .lineSpacing(Theme.noteLineSpacing)
                    .foregroundStyle(Theme.ink2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            (Text("1").font(.app(size: 11.5, weight: .bold)).baselineOffset(5)
                + Text(lang.t("plan.sources")))
                .font(Theme.fineFont)
                .foregroundStyle(Theme.ink2)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.amber.opacity(0.10))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}
