import SwiftUI

// Color(hex:) helper
extension Color {
    init(hex: String) {
        let h = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var v: UInt64 = 0; Scanner(string: h).scanHexInt64(&v)
        let r, g, b, a: UInt64
        switch h.count {
        case 8: (r, g, b, a) = (v >> 24 & 0xFF, v >> 16 & 0xFF, v >> 8 & 0xFF, v & 0xFF)
        default: (r, g, b, a) = (v >> 16 & 0xFF, v >> 8 & 0xFF, v & 0xFF, 255)
        }
        self.init(.sRGB, red: Double(r)/255, green: Double(g)/255, blue: Double(b)/255, opacity: Double(a)/255)
    }
}

// OneMET design tokens (from Claude Design handoff: data.jsx)
enum Theme {
    static let bg    = Color(hex: "EFEFF4")
    static let card  = Color.white
    static let ink   = Color(hex: "1C1C1E")
    static let ink2  = Color(red: 60/255, green: 60/255, blue: 67/255).opacity(0.60)
    static let ink3  = Color(red: 60/255, green: 60/255, blue: 67/255).opacity(0.32)
    static let sep   = Color(red: 60/255, green: 60/255, blue: 67/255).opacity(0.13)
    static let hair  = Color(red: 60/255, green: 60/255, blue: 67/255).opacity(0.07)

    static let green = Color(hex: "30B85C")   // in-range
    static let amber = Color(hex: "F5A02A")   // high
    static let red   = Color(hex: "FF3B30")   // low / heart

    static let ringMove = Color(hex: "FF5A4D")
    static let ringExer = Color(hex: "5BD15B")
    static let ringMet  = Color(hex: "2A8FE0")
    static let teal     = Color(hex: "1FB8C9")
    static let violet   = Color(hex: "8E72E8")

    static let accent = Color(hex: "2A6FDB")

    static let radius: CGFloat = 20
    static let targetLow:  Double = 70
    static let targetHigh: Double = 180

    // MARK: Prose type scale
    //
    // Anything the user is meant to *read* — guidance, recommendations, disclaimers,
    // the Help articles — uses these rather than the small sizes that suit metadata and
    // chart labels. They track the system's own body text (iOS body is 17 pt), because
    // health advice set at 11–12 pt is advice that doesn't get read. Captions, chips,
    // axis labels and list metadata are deliberately NOT covered here and stay small.

    /// Long-form explanation: Help & FAQ articles, and anything of that length.
    static var articleFont: Font { .app(size: 18) }
    static let articleLineSpacing: CGFloat = 5

    /// Guidance and notes in place: disclaimers, scope explanations, the sentence under
    /// a control that tells you what it will do. At iOS body size, because this is the
    /// text that actually carries the advice.
    static var noteFont: Font { .app(size: 17) }
    static let noteLineSpacing: CGFloat = 4

    /// Small print that is genuinely ancillary — citations, source lines, the second line
    /// of a button. Still well above the 11.5 pt it replaced.
    static var fineFont: Font { .app(size: 15) }

    // MARK: Dynamic Type
    //
    // Every size in the app is written at the iOS default text size ("Large", body 17 pt)
    // and multiplied by `textScale`, which RootView keeps in step with the text-size
    // slider in iOS Settings. Clamped at both ends: below 0.88 the chart and chip labels
    // stop being legible, and above 1.35 (≈ the largest non-accessibility size) the fixed
    // geometry — dials, rings, the activity disc, chart gutters — starts to overflow.

    /// Current multiplier over the design sizes. Set only by RootView.
    static var textScale: CGFloat = 1

    /// Maps the system text size to `textScale`, using iOS's own body sizes over 17 pt.
    static func setTextScale(_ size: DynamicTypeSize) {
        let body: CGFloat
        switch size {
        case .xSmall:   body = 14
        case .small:    body = 15
        case .medium:   body = 16
        case .large:    body = 17
        case .xLarge:   body = 19
        case .xxLarge:  body = 21
        case .xxxLarge: body = 23
        default:        body = 23   // accessibility sizes: held at the cap
        }
        textScale = min(max(body / 17, 0.88), 1.35)
    }

    /// Display numbers (≥ 28 pt: the hero glucose, dial readouts) live inside fixed-size
    /// shapes, so they stay at their design size; everything smaller follows the setting.
    static func scaled(_ size: CGFloat) -> CGFloat {
        size >= 28 ? size : (size * textScale).rounded(toPlaces: 1)
    }
}

extension Font {
    /// The app's font: `.system(size:weight:design:)` that follows the iOS text size.
    /// Use this instead of `.system(size:)` so new text scales like the rest.
    static func app(size: CGFloat, weight: Font.Weight = .regular,
                    design: Font.Design = .default) -> Font {
        .system(size: Theme.scaled(size), weight: weight, design: design)
    }
}

private extension CGFloat {
    func rounded(toPlaces p: Int) -> CGFloat {
        let m = pow(10, CGFloat(p))
        return (self * m).rounded() / m
    }
}

func glucoseColor(_ v: Double) -> Color {
    if v < Theme.targetLow  { return Theme.red }
    if v > Theme.targetHigh { return Theme.amber }
    return Theme.green
}
func glucoseStatusLabel(_ v: Double) -> String {
    if v < Theme.targetLow  { return "Low" }
    if v > Theme.targetHigh { return "High" }
    return "In Range"
}
