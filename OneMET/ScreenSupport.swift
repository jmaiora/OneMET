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
    @ViewBuilder var content: () -> Content

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: spacing) { content() }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 110)   // clear the floating tab bar
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
                .font(.system(size: 12, weight: .semibold))
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
            .font(.system(size: 14, weight: .bold))
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
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(color)
                Text(fmtNum(value))
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(Theme.ink)
                    .monospacedDigit()
                Text("/ \(fmtNum(goal)) \(unit)")
                    .font(.system(size: 11.5, weight: .medium))
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
                .font(.system(size: 11.5, weight: .medium))
                .foregroundStyle(Theme.ink2)
        }
    }
}

// MARK: - Workout row

struct WorkoutRow: View {
    var w: Workout
    var accent: Color
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
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Theme.ink)
                    Text("\(w.time) · \(w.dist) · \(w.dur)")
                        .font(.system(size: 12.5))
                        .foregroundStyle(Theme.ink2)
                }
                Spacer(minLength: 8)

                VStack(alignment: .trailing, spacing: 3) {
                    Chip("\(w.glucoseDelta > 0 ? "+" : "")\(w.glucoseDelta) mg/dL", color: dropColor)
                    Text("\(fmtNum(w.avgMet)) MET avg")
                        .font(.system(size: 11))
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
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(Theme.ink2)
                            .lineLimit(1)
                        Text("\(m.carbs)g")
                            .font(.system(size: 10))
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
                .font(.system(size: 12.5, weight: .semibold))
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
                .font(.system(size: 15))
                .foregroundStyle(Theme.ink)
            Spacer(minLength: 8)
            if let detail {
                Text(detail)
                    .font(.system(size: 14))
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
