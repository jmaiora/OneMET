import SwiftUI

// SportPicker.swift — swipeable stacked sport cards for the Plan tab.
//
// The card you drag is thrown clear off the edge and the card behind rises into its
// place as it goes; the index only changes once the front card is out of sight, so
// nothing ever appears to morph into a different sport or snap back.

struct SportPicker: View {
    let sports: [Sport]
    @Binding var index: Int
    var accent: Color
    var durationLabel: String
    var difficultyLabel: String

    @State private var drag: CGFloat = 0
    @State private var flinging = false

    private var n: Int { max(sports.count, 1) }

    /// Distance the front card travels before it counts as gone. Comfortably wider than
    /// any iPhone, so the card is fully off-screen (plus rotation) at the end.
    private let flingDistance: CGFloat = 520
    private let flingDuration = 0.24
    /// Drag past this (or flick harder than the predicted threshold) to commit.
    private let commitDistance: CGFloat = 60

    /// 0 → 1 as the front card travels toward the edge. Drives every other card's motion,
    /// so the stack and the outgoing card stay locked together.
    private var progress: CGFloat { min(1, abs(drag) / flingDistance) }

    /// Rightward drag means "go back to the previous sport".
    private var goingForward: Bool { drag < 0 }

    var body: some View {
        VStack(spacing: 14) {
            ZStack {
                // Rendered back-to-front. -1 is the previous card, parked off-screen left,
                // which only comes into play on a backward swipe.
                ForEach(slots, id: \.self) { rel in
                    cardView(rel: rel)
                }
            }
            .frame(height: 236)

            // page dots
            HStack(spacing: 6) {
                ForEach(sports.indices, id: \.self) { i in
                    Capsule()
                        .fill(i == index ? Color(hex: sports[i].color) : Theme.ink3)
                        .frame(width: i == index ? 16 : 6, height: 6)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            guard !flinging else { return }
                            withAnimation(.spring(response: 0.34, dampingFraction: 0.85)) { index = i }
                        }
                }
            }
        }
    }

    /// Relative positions to render, back to front. With fewer than three sports the
    /// deeper slots would just repeat the same card, so they're dropped.
    private var slots: [Int] {
        n >= 3 ? [2, 1, -1, 0] : (n == 2 ? [1, -1, 0] : [0])
    }

    private func sport(at rel: Int) -> Sport {
        sports[((index + rel) % n + n) % n]
    }

    /// Where a card sits for the current drag. depth 0 is the front slot; each step back
    /// is smaller, lower and nudged right. Deliberately a plain function — @ViewBuilder
    /// can't contain ordinary control flow, it tries to read each branch as a view.
    private func layout(rel: Int) -> (depth: CGFloat, extraX: CGFloat, alpha: Double) {
        if rel == 0 {
            return (0, drag, 1 - Double(progress) * 0.6)     // fades as it leaves
        }
        if rel == -1 {
            // Slides in from off-screen left, but only on a backward swipe. Kept at zero
            // opacity while parked so it can never show at the screen edge on a wide layout.
            let x = goingForward ? -flingDistance : -flingDistance + progress * flingDistance
            return (0, x, goingForward ? 0 : Double(progress))
        }
        // Stacked behind; advances one slot as the front card exits forwards.
        return (max(0, CGFloat(rel) - (goingForward ? progress : 0)), 0, 1)
    }

    @ViewBuilder
    private func cardView(rel: Int) -> some View {
        let s = sport(at: rel)
        let sc = Color(hex: s.color)
        let front = rel == 0
        let l = layout(rel: rel)
        let depth = l.depth, extraX = l.extraX, alpha = l.alpha

        let styled = card(s, color: sc, dimAmount: Double(min(1, depth)),
                          difficultyText: front ? difficultyLabel : s.difficulty)
            .scaleEffect(1 - depth * 0.05)
            .rotationEffect(.degrees(front ? Double(drag / 40) : Double(depth) * 2.5))
            .offset(x: depth * 10 + extraX, y: depth * 8)
            .opacity(alpha)
            .shadow(color: depth < 0.5 ? sc.opacity(0.27 * (1 - Double(depth) * 2)) : .clear,
                    radius: 15, x: 0, y: 14)
            .zIndex(front ? 10 : (rel == -1 ? 9 : Double(8 - rel)))

        if front {
            styled.gesture(
                DragGesture(minimumDistance: 8)
                    .onChanged { v in
                        guard !flinging else { return }
                        // Ignore mostly-vertical drags so the page can still scroll.
                        guard abs(v.translation.width) > abs(v.translation.height) else { return }
                        drag = v.translation.width
                    }
                    .onEnded { v in
                        guard !flinging, drag != 0 else { return }
                        let w = v.translation.width
                        let flick = v.predictedEndTranslation.width
                        if abs(w) > commitDistance || abs(flick) > 180 {
                            fling(forward: (abs(flick) > abs(w) ? flick : w) < 0)
                        } else {
                            withAnimation(.spring(response: 0.34, dampingFraction: 0.85)) { drag = 0 }
                        }
                    }
            )
        } else {
            styled
        }
    }

    /// Throw the front card off the edge, then swap the deck underneath it. The swap is
    /// deliberately un-animated: by that point the incoming card has already slid into
    /// the front position, so re-indexing is invisible.
    private func fling(forward: Bool) {
        flinging = true
        withAnimation(.easeOut(duration: flingDuration)) {
            drag = forward ? -flingDistance : flingDistance
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + flingDuration) {
            var t = Transaction()
            t.disablesAnimations = true
            withTransaction(t) {
                index = (index + (forward ? 1 : -1) + n) % n
                drag = 0
            }
            flinging = false
        }
    }

    private func card(_ s: Sport, color sc: Color, dimAmount: Double, difficultyText: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top) {
                HStack(spacing: 18) {
                    cardStat("Time", durationLabel)
                    cardStat("Difficulty", difficultyText)
                }
                Spacer()
                AppIconView(name: s.icon, color: .white, size: 26, weight: .bold)
            }
            Spacer(minLength: 12)
            Text(s.name)
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(.white)
                .padding(.bottom, 8)
            Text(s.desc)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.white.opacity(0.92))
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(sc)
        .overlay(Color.black.opacity(0.14 * dimAmount))
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private func cardStat(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label.uppercased())
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.white.opacity(0.75))
                .tracking(0.3)
            Text(value)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(.white)
        }
    }
}

#Preview {
    ZStack {
        Theme.bg.ignoresSafeArea()
        SportPicker(sports: SPORTS, index: .constant(1), accent: Theme.accent, durationLabel: "45 min", difficultyLabel: "Moderate")
            .padding()
    }
}
