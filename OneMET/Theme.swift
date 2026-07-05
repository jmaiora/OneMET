import SwiftUI

enum Theme {
    // MARK: – Brand colours
    static let accent      = Color("AccentColor")
    static let background  = Color(.systemGroupedBackground)
    static let card        = Color(.secondarySystemGroupedBackground)
    static let separator   = Color(.separator)

    // Semantic
    static let heartRate   = Color.red
    static let steps       = Color.green
    static let calories    = Color.orange
    static let sleep       = Color.indigo
    static let mindfulness = Color.teal
    static let hrv         = Color.purple

    // MARK: – Typography
    enum Font {
        static let title     = SwiftUI.Font.system(.title,     design: .rounded, weight: .bold)
        static let headline  = SwiftUI.Font.system(.headline,  design: .rounded, weight: .semibold)
        static let body      = SwiftUI.Font.system(.body,      design: .rounded)
        static let caption   = SwiftUI.Font.system(.caption,   design: .rounded)
        static let largeNum  = SwiftUI.Font.system(size: 42,   weight: .bold, design: .rounded)
    }

    // MARK: – Spacing / radius
    static let cornerRadius: CGFloat = 16
    static let cardPadding:  CGFloat = 16
    static let sectionGap:   CGFloat = 24
}
