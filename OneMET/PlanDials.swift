import SwiftUI
import UIKit   // haptics + UIColor for the gauge's colour ramp

// PlanDials.swift — the two circular controls at the top of the Plan tab.
//
// Both are built on the same idea: a track arc, a progress arc, a draggable knob, and a
// big value in the middle. They deliberately share `DialGeometry` so the knob sits on the
// same radius and the sweep starts at the same angle in each, which is what makes them
// read as a pair rather than two unrelated widgets.
//
// Angles here run clockwise from straight up (12 o'clock = 0°), because that's how a dial
// is read. The sweep is a 270° arc opening at the bottom: it starts lower-left, climbs
// over the top and ends lower-right, leaving a gap under the value label.

// MARK: - Shared geometry

private enum DialGeometry {
    /// Start of the sweep, clockwise from 12 o'clock — 225° is lower-left.
    static let startAngle: Double = 225
    static let sweep: Double = 270
    static var endAngle: Double { startAngle + sweep }     // 495° ≡ 135°, lower-right

    static let lineWidth: CGFloat = 14
    static let knobRadius: CGFloat = 11

    /// SwiftUI's `.trim` starts at 3 o'clock, so the arc is drawn from trim 0 and the
    /// whole shape rotated to put trim 0 at `startAngle`.
    static let trimSpan: CGFloat = CGFloat(sweep / 360)
    static let rotation: Double = startAngle - 90

    /// Fraction 0…1 → angle in degrees clockwise from 12 o'clock.
    static func angle(for fraction: Double) -> Double {
        startAngle + fraction * sweep
    }

    /// Knob centre for a fraction, in a square of the given size.
    static func knobPoint(fraction: Double, size: CGFloat) -> CGPoint {
        let r = (size - lineWidth) / 2
        let radians = (angle(for: fraction) - 90) * .pi / 180
        return CGPoint(x: size / 2 + r * cos(radians), y: size / 2 + r * sin(radians))
    }

    /// Inverse of `angle(for:)` — where a touch falls on the sweep, 0…1. Returns nil in
    /// the gap at the bottom, so a thumb resting there doesn't snap the value to an end.
    static func fraction(at point: CGPoint, size: CGFloat) -> Double? {
        let dx = point.x - size / 2
        let dy = point.y - size / 2
        guard dx != 0 || dy != 0 else { return nil }

        // atan2 gives -180…180 from 3 o'clock; convert to 0…360 clockwise from 12.
        var deg = atan2(dy, dx) * 180 / .pi + 90
        if deg < 0 { deg += 360 }

        // The sweep wraps through 0°: 225…360 is the first half, 0…135 the second.
        if deg >= startAngle { return (deg - startAngle) / sweep }
        if deg <= endAngle - 360 { return (deg + 360 - startAngle) / sweep }
        return nil                                          // the gap, 135°…225°
    }
}

// MARK: - Reusable dial shell

/// The visual chrome shared by both dials: a background track, a coloured progress arc,
/// a knob, and whatever the caller wants in the middle.
private struct Dial<Center: View>: View {
    var fraction: Double
    var track: Color
    /// Progress arc fill. A gradient for the gauge, a flat colour for the clock.
    var progress: AnyShapeStyle
    var knobColor: Color
    var size: CGFloat
    var onScrub: (Double) -> Void
    @ViewBuilder var center: () -> Center

    var body: some View {
        ZStack {
            Circle()
                .trim(from: 0, to: DialGeometry.trimSpan)
                .stroke(track, style: StrokeStyle(lineWidth: DialGeometry.lineWidth, lineCap: .round))
                .rotationEffect(.degrees(DialGeometry.rotation))

            Circle()
                .trim(from: 0, to: DialGeometry.trimSpan * CGFloat(fraction))
                .stroke(progress, style: StrokeStyle(lineWidth: DialGeometry.lineWidth, lineCap: .round))
                .rotationEffect(.degrees(DialGeometry.rotation))

            Circle()
                .fill(.white)
                .frame(width: DialGeometry.knobRadius * 2, height: DialGeometry.knobRadius * 2)
                .overlay(Circle().stroke(knobColor, lineWidth: 3))
                .shadow(color: .black.opacity(0.18), radius: 3, x: 0, y: 2)
                .position(DialGeometry.knobPoint(fraction: fraction, size: size))

            center()
        }
        .frame(width: size, height: size)
        .contentShape(Rectangle())
        // A single gesture with no minimum distance, so a plain tap on the arc jumps the
        // value there — the same gesture then keeps tracking if the finger moves.
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { v in
                    if let f = DialGeometry.fraction(at: v.location, size: size) { onScrub(f) }
                }
        )
    }
}

// MARK: - Duration clock

/// Apple-timer-style minute dial. One full sweep covers `range`, snapping to `step`.
struct DurationDial: View {
    @Binding var minutes: Int
    var accent: Color
    var lang: AppLanguage = .en
    var size: CGFloat = 150

    private let range = 10...180
    private let step = 5

    private var fraction: Double {
        Double(minutes - range.lowerBound) / Double(range.upperBound - range.lowerBound)
    }

    var body: some View {
        VStack(spacing: 8) {
            Dial(fraction: fraction,
                 track: Theme.ink3.opacity(0.22),
                 progress: AnyShapeStyle(accent),
                 knobColor: accent,
                 size: size,
                 onScrub: scrub) {
                VStack(spacing: 0) {
                    Text("\(minutes)")
                        .font(.system(size: 40, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.ink)
                        .monospacedDigit()
                    Text(lang.t("workouts.min"))
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Theme.ink2)
                }
            }

            Text(lang.t("plan.plannedDuration").uppercased())
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Theme.ink2)
                .tracking(0.3)
        }
    }

    private func scrub(_ f: Double) {
        let span = Double(range.upperBound - range.lowerBound)
        let raw = Double(range.lowerBound) + f * span
        let snapped = (raw / Double(step)).rounded() * Double(step)
        let clamped = min(Double(range.upperBound), max(Double(range.lowerBound), snapped))
        let new = Int(clamped)
        if new != minutes {
            minutes = new
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }
    }
}

// MARK: - Intensity gauge

/// Effort dial: green through amber to dark red, with the MET value in the middle. MET is
/// the app's own currency (the ring, the workout stats), so exposing it directly here
/// means the number you dial is the number you'll see afterwards.
struct IntensityDial: View {
    @Binding var met: Double
    var lang: AppLanguage = .en
    var size: CGFloat = 150

    /// 1 MET is sitting still; 14 is about as hard as a recreational session gets.
    static let range: ClosedRange<Double> = 1...14

    private var fraction: Double {
        (met - Self.range.lowerBound) / (Self.range.upperBound - Self.range.lowerBound)
    }

    /// Green → dark red across the sweep. Sampled rather than used as an AngularGradient
    /// directly for the knob, so the knob always matches the arc under it.
    static func color(forFraction f: Double) -> Color {
        let stops: [(Double, Color)] = [
            (0.00, Color(hex: "1F8A5B")),   // green — easy
            (0.35, Color(hex: "8CBF3F")),   // yellow-green
            (0.55, Color(hex: "F5A02A")),   // amber — moderate
            (0.78, Color(hex: "E0553A")),   // red — vigorous
            (1.00, Color(hex: "8E1B1B")),   // dark red — maximal
        ]
        let x = min(1, max(0, f))
        for i in 1..<stops.count where x <= stops[i].0 {
            let (x0, c0) = stops[i - 1]
            let (x1, c1) = stops[i]
            return c0.blended(to: c1, amount: (x - x0) / max(0.0001, x1 - x0))
        }
        return stops.last!.1
    }

    /// Spans the same 0…270° the arc is trimmed to. It's defined in the shape's own
    /// unrotated space, so the rotationEffect that positions the arc carries the gradient
    /// with it and green always sits at the start of the sweep.
    private var gradient: AngularGradient {
        AngularGradient(
            gradient: Gradient(colors: stride(from: 0.0, through: 1.0, by: 0.05)
                .map { Self.color(forFraction: $0) }),
            center: .center,
            startAngle: .degrees(0),
            endAngle: .degrees(DialGeometry.sweep))
    }

    var body: some View {
        let tint = Self.color(forFraction: fraction)

        VStack(spacing: 8) {
            Dial(fraction: fraction,
                 track: Theme.ink3.opacity(0.22),
                 progress: AnyShapeStyle(gradient),
                 knobColor: tint,
                 size: size,
                 onScrub: scrub) {
                VStack(spacing: 0) {
                    Text(fmtNum((met * 10).rounded() / 10))
                        .font(.system(size: 40, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.ink)
                        .monospacedDigit()
                    Text("MET")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Theme.ink2)
                }
            }

            Text(WorkoutDifficulty(met: met).label(lang).uppercased())
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(tint)
                .tracking(0.3)
        }
    }

    private func scrub(_ f: Double) {
        let span = Self.range.upperBound - Self.range.lowerBound
        let raw = Self.range.lowerBound + f * span
        let snapped = (raw * 10).rounded() / 10          // 0.1 MET steps
        if abs(snapped - met) >= 0.05 {
            // Haptic on band changes only — one per 0.1 MET would buzz continuously.
            if WorkoutDifficulty(met: snapped) != WorkoutDifficulty(met: met) {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            }
            met = snapped
        }
    }
}

// MARK: - Colour blending

extension Color {
    /// Linear blend in sRGB. Good enough for a gauge ramp and avoids pulling in a
    /// colour-space dependency for five stops.
    func blended(to other: Color, amount: Double) -> Color {
        let t = min(1, max(0, amount))
        let a = UIColor(self), b = UIColor(other)
        var ar: CGFloat = 0, ag: CGFloat = 0, ab: CGFloat = 0, aa: CGFloat = 0
        var br: CGFloat = 0, bg: CGFloat = 0, bb: CGFloat = 0, ba: CGFloat = 0
        a.getRed(&ar, green: &ag, blue: &ab, alpha: &aa)
        b.getRed(&br, green: &bg, blue: &bb, alpha: &ba)
        return Color(.sRGB,
                     red: Double(ar + (br - ar) * t),
                     green: Double(ag + (bg - ag) * t),
                     blue: Double(ab + (bb - ab) * t),
                     opacity: Double(aa + (ba - aa) * t))
    }
}
