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
    static let articleFont = Font.system(size: 17)
    static let articleLineSpacing: CGFloat = 4

    /// Guidance and notes in place: disclaimers, scope explanations, the sentence under
    /// a control that tells you what it will do.
    static let noteFont = Font.system(size: 15.5)
    static let noteLineSpacing: CGFloat = 3

    /// Small print that is genuinely ancillary — citations, source lines. Still a long
    /// way above the 11.5 pt it replaced.
    static let fineFont = Font.system(size: 14)
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
