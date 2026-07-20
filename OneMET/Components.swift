import SwiftUI

// Components.swift — OneMET UI shell components
// Ported from the Claude Design handoff (cards.jsx).

// MARK: - Icon

/// Maps the handoff's icon names to SF Symbols.
enum AppIcon {
    static func systemName(_ name: String) -> String {
        switch name {
        case "drop":     return "drop.fill"
        case "heart":    return "heart.fill"
        case "flame":    return "flame.fill"
        case "run":      return "figure.run"
        case "shoe":     return "shoeprints.fill"
        case "fork":     return "fork.knife"
        case "bolt":     return "bolt.fill"
        case "activity": return "waveform.path.ecg"
        case "chevron":  return "chevron.right"
        case "person":   return "person.fill"
        case "house":    return "house.fill"
        case "chart":    return "chart.bar.fill"
        case "calendar": return "calendar"
        default:         return "circle"
        }
    }
}

struct AppIconView: View {
    let name: String
    var color: Color = Theme.ink
    var size: CGFloat = 17
    var weight: Font.Weight = .semibold

    var body: some View {
        Image(systemName: AppIcon.systemName(name))
            .font(.system(size: size, weight: weight))
            .foregroundStyle(color)
    }
}

// MARK: - Card

struct Card<Content: View>: View {
    var title: String? = nil
    var icon: String? = nil
    var iconColor: Color? = nil
    var right: String? = nil
    var pad: CGFloat = 16
    var onTap: (() -> Void)? = nil
    @ViewBuilder var content: () -> Content

    private var body0: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let title {
                CardHeader(title: title, icon: icon, iconColor: iconColor,
                           right: right, clickable: onTap != nil)
                    .padding(.bottom, 12)
            }
            content()
        }
        .padding(pad)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.card)
        .clipShape(RoundedRectangle(cornerRadius: Theme.radius, style: .continuous))
        .shadow(color: .black.opacity(0.04),  radius: 1, x: 0, y: 1)
        .shadow(color: .black.opacity(0.035), radius: 8, x: 0, y: 6)
    }

    var body: some View {
        if let onTap {
            Button(action: onTap) { body0 }
                .buttonStyle(.plain)
        } else {
            body0
        }
    }
}

struct CardHeader: View {
    let title: String
    var icon: String? = nil
    var iconColor: Color? = nil
    var right: String? = nil
    var clickable: Bool = false

    var body: some View {
        HStack(spacing: 4) {
            HStack(spacing: 6) {
                if let icon {
                    AppIconView(name: icon, color: iconColor ?? Theme.ink, size: 15)
                }
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(iconColor ?? Theme.ink)
                    .tracking(-0.2)
            }
            Spacer(minLength: 8)
            if let right {
                Text(right)
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.ink2)
                    .monospacedDigit()
            }
            if clickable {
                AppIconView(name: "chevron", color: Theme.ink3, size: 15)
            }
        }
    }
}

// MARK: - Header

struct AppHeader: View {
    let title: String
    let date: String
    var initials: String = "?"
    var accent: Color = Theme.accent

    var body: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 2) {
                Text(date.uppercased())
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.ink2)
                    .tracking(0.2)
                Text(title)
                    .font(.system(size: 32, weight: .bold))
                    .foregroundStyle(Theme.ink)
                    .tracking(0.36)
            }
            Spacer()
            Text(initials)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 36, height: 36)
                .background(accent)
                .clipShape(Circle())
                .shadow(color: .black.opacity(0.12), radius: 3, x: 0, y: 2)
        }
        .padding(.horizontal, 16)
        .padding(.top, 4)
        .padding(.bottom, 8)
    }
}

// MARK: - StatBlock

struct StatBlock: View {
    let label: String
    let value: String
    var unit: String? = nil
    var color: Color? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label.uppercased())
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Theme.ink2)
                .tracking(0.2)
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(value)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(color ?? Theme.ink)
                    .monospacedDigit()
                if let unit {
                    Text(unit)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Theme.ink2)
                }
            }
        }
    }
}

// MARK: - Chip

struct Chip<Content: View>: View {
    var color: Color = Theme.green
    @ViewBuilder var content: () -> Content

    var body: some View {
        HStack(spacing: 4) { content() }
            .font(.system(size: 12.5, weight: .semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 9)
            .padding(.vertical, 3)
            .background(color.opacity(0.12))
            .clipShape(Capsule())
    }
}

extension Chip where Content == Text {
    /// Convenience for a plain text chip.
    init(_ text: String, color: Color = Theme.green) {
        self.color = color
        self.content = { Text(text) }
    }
}

/// Small filled dot used inside chips / legends.
struct Dot: View {
    var color: Color
    var size: CGFloat = 6
    var body: some View {
        Circle().fill(color).frame(width: size, height: size)
    }
}

// MARK: - TabBar

enum AppTab: String, CaseIterable {
    case summary, plan, workouts, profile

    var label: String {
        switch self {
        case .summary:  return "Summary"
        case .workouts: return "Workouts"
        case .plan:     return "Plan"
        case .profile:  return "Profile"
        }
    }
    var icon: String {
        switch self {
        case .summary:  return "house"
        case .workouts: return "run"
        case .plan:     return "calendar"
        case .profile:  return "person"
        }
    }
}

struct TabBar: View {
    @Binding var active: AppTab
    var accent: Color = Theme.accent

    var body: some View {
        HStack(alignment: .top) {
            ForEach(AppTab.allCases, id: \.self) { tab in
                let on = tab == active
                VStack(spacing: 3) {
                    AppIconView(name: tab.icon,
                                color: on ? accent : Theme.ink3,
                                size: 24,
                                weight: on ? .bold : .regular)
                    Text(tab.label)
                        .font(.system(size: 10.5, weight: on ? .bold : .medium))
                        .foregroundStyle(on ? accent : Theme.ink2)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 2)
                .contentShape(Rectangle())
                .onTapGesture { active = tab }
            }
        }
        .padding(.top, 9)
        .padding(.bottom, 22)
        .background(.ultraThinMaterial)
        .overlay(
            Rectangle()
                .fill(Theme.sep)
                .frame(height: 0.5),
            alignment: .top
        )
    }
}

// MARK: - Select row (menu-backed, for the Plan tab)

struct SelectRow<T: Hashable>: View {
    let label: String
    @Binding var selection: T
    let options: [(value: T, label: String)]
    var accent: Color = Theme.accent

    private var currentLabel: String {
        options.first { $0.value == selection }?.label ?? ""
    }

    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Theme.ink)
            Spacer()
            Menu {
                Picker(label, selection: $selection) {
                    ForEach(options.indices, id: \.self) { i in
                        Text(options[i].label).tag(options[i].value)
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Text(currentLabel)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(accent)
                    AppIconView(name: "chevron", color: Theme.ink3, size: 13)
                }
            }
        }
        .padding(.vertical, 11)
        .overlay(Rectangle().fill(Theme.sep).frame(height: 0.5), alignment: .bottom)
    }
}
