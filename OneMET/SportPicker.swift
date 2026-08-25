import SwiftUI

// SportPicker.swift — swipeable stacked sport cards for the Plan tab.
//
// The card you drag is thrown clear off whichever edge you dragged toward, and the deck
// behind it steps forward one slot as it goes, so the incoming card is already sitting in
// the front position by the time the index changes. The stack is addressed by *position*
// (0 = front, 1 = behind, 2 = deeper) rather than by index offset, and the direction of
// travel decides which sports fill those positions — that's what makes forward and
// backward swipes behave identically instead of one of them working and the other
// snapping back.

struct SportPicker: View {
    let sports: [Sport]
    @Binding var index: Int
    var accent: Color
    var durationLabel: String
    var difficultyLabel: String
    var lang: AppLanguage = .en

    @State private var drag: CGFloat = 0
    @State private var flinging = false

    private var n: Int { max(sports.count, 1) }

    /// Distance the front card travels before it counts as gone. Comfortably wider than
    /// any iPhone, so the card is fully off-screen (plus rotation) at the end.
    private let flingDistance: CGFloat = 520
    private let flingDuration = 0.24
    /// Drag past this (or flick harder than the predicted threshold) to commit.
    private let commitDistance: CGFloat = 60

    /// 0 → 1 as the front card travels toward the edge. Drives every card's motion, so
    /// the outgoing card and the deck behind it stay locked together.
    private var progress: CGFloat { min(1, abs(drag) / flingDistance) }

    /// Which way the deck is moving: +1 advances to the next sport (drag left), -1 goes
    /// back to the previous one (drag right). At rest this is +1, so the resting peek
    /// card is the next sport, as before.
    private var direction: Int { drag > 0 ? -1 : 1 }

    var body: some View {
        VStack(spacing: 14) {
            ZStack {
                // Rendered deepest-first; zIndex pins the order regardless.
                ForEach(positions.reversed(), id: \.self) { pos in
                    cardView(position: pos)
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

    /// Stack positions to draw, front-first. With fewer sports the deeper slots would
    /// just repeat the same card, so they're dropped.
    private var positions: [Int] {
        n >= 3 ? [0, 1, 2] : (n == 2 ? [0, 1] : [0])
    }

    /// The sport occupying a stack position for the current direction of travel.
    private func sport(atPosition p: Int) -> Sport {
        let rel = p * direction
        return sports[((index + rel) % n + n) % n]
    }

    @ViewBuilder
    private func cardView(position p: Int) -> some View {
        let s = sport(atPosition: p)
        let sc = Color(hex: s.color)
        let front = p == 0

        // Every card steps forward by `progress`, so position 1 lands exactly where
        // position 0 was at the moment the index changes — no jump when the deck reshuffles.
        let depth = max(0, CGFloat(p) - progress)

        let styled = card(s, color: sc, dimAmount: Double(min(1, depth)),
                          difficultyText: front ? difficultyLabel : s.difficulty.label(lang))
            .scaleEffect(1 - depth * 0.05)
            .rotationEffect(.degrees(front ? Double(drag / 40) : Double(depth) * 2.5))
            .offset(x: depth * 10 + (front ? drag : 0), y: depth * 8)
            .opacity(front ? 1 - Double(progress) * 0.6 : 1)
            .shadow(color: depth < 0.5 ? sc.opacity(0.27 * (1 - Double(depth) * 2)) : .clear,
                    radius: 15, x: 0, y: 14)
            .zIndex(Double(10 - p))

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
                            fling(toward: w)
                        } else {
                            withAnimation(.spring(response: 0.34, dampingFraction: 0.85)) { drag = 0 }
                        }
                    }
            )
        } else {
            styled
        }
    }

    /// Throw the front card off the edge it was dragged toward, then reshuffle the deck
    /// underneath it. The reshuffle is deliberately un-animated: by that point the next
    /// card has already slid into the front position, so re-indexing is invisible.
    private func fling(toward width: CGFloat) {
        flinging = true
        let step = width < 0 ? 1 : -1          // matches `direction` for this drag
        withAnimation(.easeOut(duration: flingDuration)) {
            drag = width < 0 ? -flingDistance : flingDistance
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + flingDuration) {
            var t = Transaction()
            t.disablesAnimations = true
            withTransaction(t) {
                index = (index + step + n) % n
                drag = 0
            }
            flinging = false
        }
    }

    private func card(_ s: Sport, color sc: Color, dimAmount: Double, difficultyText: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top) {
                HStack(spacing: 18) {
                    cardStat(lang.t("plan.time"), durationLabel)
                    cardStat(lang.t("plan.difficultyShort"), difficultyText)
                }
                Spacer()
                AppIconView(name: s.icon, color: .white, size: 26, weight: .bold)
            }
            Spacer(minLength: 12)
            Text(s.name(lang))
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(.white)
                .padding(.bottom, 8)
            Text(s.desc(lang))
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
        SportPicker(sports: SPORTS, index: .constant(1), accent: Theme.accent,
                    durationLabel: "45 min", difficultyLabel: "Moderate")
            .padding()
    }
}
