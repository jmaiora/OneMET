import SwiftUI

// ScreenSupport.swift — shared screen-level helpers
// Ported from the Claude Design handoff (screens.jsx).

/// Number formatter: whole numbers without decimals, else one decimal.
func fmtNum(_ v: Double) -> String {
    v == v.rounded() ? String(Int(v)) : String(format: "%.1f", v)
}

// MARK: - Scroll scaffold

struct ScreenScaffold<Content: View>: View {
    var spacing: CGFloat = 14
    var onRefresh: (() async -> Void)? = nil
    @ViewBuilder var content: () -> Content

    var body: some View {
        let scroll = ScrollView(showsIndicators: false) {
            VStack(spacing: spacing) { content() }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 110)   // clear the floating tab bar
        }
        if let onRefresh {
            scroll.refreshable { await onRefresh() }
        } else {
            scroll
        }
    }
}

// MARK: - Big stat (headline number + unit)

struct BigStat: View {
    var value: String
    var unit: String
    var size: CGFloat = 30

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 3) {
            Text(value)
                .font(.system(size: size, weight: .bold))
                .foregroundStyle(Theme.ink)
                .monospacedDigit()
            Text(unit)
                .font(.app(size: 13.5, weight: .semibold))
                .foregroundStyle(Theme.ink2)
        }
    }
}

// MARK: - Trend arrow

struct TrendArrow: View {
    enum Dir { case up, down, flat }
    var dir: Dir
    var color: Color

    var body: some View {
        Image(systemName: "arrow.right")
            .font(.app(size: 14, weight: .bold))
            .foregroundStyle(color)
            .rotationEffect(.degrees(dir == .up ? -45 : dir == .down ? 45 : 0))
    }
}

// MARK: - Progress bar

struct ProgressBar: View {
    var value: Double
    var goal: Double
    var color: Color

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(color.opacity(0.14))
                Capsule().fill(color)
                    .frame(width: geo.size.width * CGFloat(goal > 0 ? min(1, value / goal) : 0))
            }
        }
        .frame(height: 4)
    }
}

// MARK: - Ring stat row

struct RingStat: View {
    var color: Color
    var label: String
    var value: Double
    var goal: Double
    var unit: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(label)
                    .font(.app(size: 14.5, weight: .semibold))
                    .foregroundStyle(color)
                Text(fmtNum(value))
                    .font(.app(size: 18, weight: .bold))
                    .foregroundStyle(Theme.ink)
                    .monospacedDigit()
                Text("/ \(fmtNum(goal)) \(unit)")
                    .font(.app(size: 13, weight: .medium))
                    .foregroundStyle(Theme.ink2)
            }
            ProgressBar(value: value, goal: goal, color: color)
        }
    }
}

// MARK: - Time-in-range legend item

struct TIRLegend: View {
    var label: String
    var value: Int
    var color: Color

    var body: some View {
        HStack(spacing: 5) {
            Circle().fill(color).frame(width: 7, height: 7)
            Text("\(label) \(value)%")
                .font(.app(size: 13, weight: .medium))
                .foregroundStyle(Theme.ink2)
        }
    }
}

// MARK: - Workout row

struct WorkoutRow: View {
    var w: Workout
    var accent: Color
    var unit: GlucoseUnit = .mgdl
    var lang: AppLanguage = .en
    var last: Bool

    var body: some View {
        let dropColor = w.glucoseDelta < 0 ? Theme.green : Theme.amber
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous).fill(accent.opacity(0.09))
                    AppIconView(name: "run", color: accent, size: 20)
                }
                .frame(width: 38, height: 38)

                VStack(alignment: .leading, spacing: 2) {
                    Text(w.name)
                        .font(.app(size: 15, weight: .semibold))
                        .foregroundStyle(Theme.ink)
                    Text("\(w.time) · \(w.dist) · \(w.dur)")
                        .font(.app(size: 14))
                        .foregroundStyle(Theme.ink2)
                }
                Spacer(minLength: 8)

                VStack(alignment: .trailing, spacing: 3) {
                    Chip(unit.deltaAmount(Double(w.glucoseDelta)), color: dropColor)
                    Text(lang.t("workouts.metAvg", fmtNum(w.avgMet)))
                        .font(.app(size: 12.5))
                        .foregroundStyle(Theme.ink3)
                        .monospacedDigit()
                }
            }
            .padding(.vertical, 10)

            if !last {
                Rectangle().fill(Theme.sep).frame(height: 0.5)
            }
        }
    }
}

// MARK: - Meal distribution bars (proportional to carbs)

struct MealBars: View {
    var meals: [Meal]

    var body: some View {
        let total = CGFloat(max(meals.reduce(0) { $0 + $1.carbs }, 1))
        GeometryReader { geo in
            let gap: CGFloat = 4
            let avail = geo.size.width - gap * CGFloat(max(meals.count - 1, 0))
            HStack(alignment: .bottom, spacing: gap) {
                ForEach(Array(meals.enumerated()), id: \.element.id) { i, m in
                    VStack(spacing: 3) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Theme.amber.opacity(0.55 + Double(i) * 0.12))
                            .frame(height: 8)
                        Text(m.name)
                            .font(.app(size: 11.5, weight: .semibold))
                            .foregroundStyle(Theme.ink2)
                            .lineLimit(1)
                        Text("\(m.carbs)g")
                            .font(.app(size: 11.5))
                            .foregroundStyle(Theme.ink3)
                            .monospacedDigit()
                    }
                    .frame(width: avail * CGFloat(m.carbs) / total)
                }
            }
        }
        .frame(height: 46)
    }
}

// MARK: - iOS-style grouped list

struct IOSList<Content: View>: View {
    var header: String
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(header.uppercased())
                .font(.app(size: 14, weight: .semibold))
                .foregroundStyle(Theme.ink2)
                .tracking(0.2)
                .padding(.horizontal, 4)
            VStack(spacing: 0) { content() }
                .background(Theme.card)
                .clipShape(RoundedRectangle(cornerRadius: Theme.radius, style: .continuous))
        }
    }
}

struct IOSListRow: View {
    var title: String
    var detail: String? = nil
    var dot: Color
    var isLast: Bool = false
    var action: (() -> Void)? = nil

    private var rowContent: some View {
        HStack(spacing: 12) {
            Circle().fill(dot).frame(width: 10, height: 10)
            Text(title)
                .font(.app(size: 15))
                .foregroundStyle(Theme.ink)
            Spacer(minLength: 8)
            if let detail {
                Text(detail)
                    .font(.app(size: 14))
                    .foregroundStyle(Theme.ink2)
                    .multilineTextAlignment(.trailing)
            }
            if action != nil {
                AppIconView(name: "chevron", color: Theme.ink3, size: 14)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }

    var body: some View {
        VStack(spacing: 0) {
            if let action {
                Button(action: action) { rowContent }.buttonStyle(.plain)
            } else {
                rowContent
            }
            if !isLast {
                Rectangle().fill(Theme.sep).frame(height: 0.5).padding(.leading, 36)
            }
        }
    }
}

// MARK: - Height reader

extension View {
    /// Reports this view's rendered height on appear and whenever it changes. For layouts
    /// that have to size one element from what the others actually take up.
    func readHeight(_ onChange: @escaping (CGFloat) -> Void) -> some View {
        background(
            GeometryReader { geo in
                Color.clear
                    .onAppear { onChange(geo.size.height) }
                    .onChange(of: geo.size.height) { onChange($0) }
            }
        )
    }
}

// MARK: - Option slider

/// A slider that snaps to a short list of values (e.g. 30 / 45 / 60 min), with the values
/// written under their stops and the chosen one in bold.
struct OptionSlider: View {
    let options: [Int]
    @Binding var value: Int
    var tint: Color = Theme.accent
    var format: (Int) -> String = { "\($0)" }

    var body: some View {
        let index = Binding<Double>(
            get: { Double(options.firstIndex(of: nearestOption(value, in: options)) ?? 0) },
            set: { value = options[max(0, min(options.count - 1, Int($0.rounded())))] }
        )
        VStack(spacing: 2) {
            Slider(value: index, in: 0...Double(max(1, options.count - 1)), step: 1)
                .tint(tint)
            HStack(spacing: 0) {
                ForEach(Array(options.enumerated()), id: \.offset) { i, o in
                    Text(format(o))
                        .font(.app(size: 13, weight: o == value ? .bold : .medium))
                        .foregroundStyle(o == value ? Theme.ink : Theme.ink3)
                        .monospacedDigit()
                    if i < options.count - 1 { Spacer(minLength: 0) }
                }
            }
        }
    }
}
