import SwiftUI

// SportPicker.swift — swipeable stacked sport cards for the Plan tab.
//
// A swipe has two phases. First the card you dragged is thrown clear off whichever edge
// you pushed it toward, while the deck behind steps forward one slot, so the incoming
// card is already sitting in the front position by the time the index changes. Then the
// thrown card loops back in from the same edge, shrinking as it goes, and tucks in
// underneath the deck — the way a dealt card goes to the bottom of the pile.
//
// The stack is addressed by *position* (0 = front, 1 = behind, 2 = deeper) rather than by
// index offset, and the direction of travel decides which sports fill those positions —
// that's what makes forward and backward swipes behave identically instead of one of them
// working and the other snapping back.

struct SportPicker: View {
    let sports: [Sport]
    @Binding var index: Int
    var accent: Color
    var durationLabel: String
    var difficultyLabel: String
    var lang: AppLanguage = .en

    @State private var drag: CGFloat = 0
    @State private var flinging = false

    // The card looping back to the bottom of the deck, if one is in flight.
    @State private var returningIndex: Int? = nil
    @State private var returningFromRight = false
    /// 1 = still off-screen where the fling left it, 0 = tucked in at the back.
    @State private var returnProgress: CGFloat = 0
    /// Guards the cleanup timer so a second swipe can't cancel the newer card's return.
    @State private var returnToken = 0

    private var n: Int { max(sports.count, 1) }

    /// Distance the front card travels before it counts as gone. Comfortably wider than
    /// any iPhone, so the card is fully off-screen (plus rotation) at the end.
    private let flingDistance: CGFloat = 520
    private let flingDuration = 0.22
    private let returnDuration = 0.34
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
                if let ri = returningIndex { returningCard(sportIndex: ri) }
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
            // No fade on the way out: the thrown card is handed straight over to
            // returningCard(), which has to pick it up at exactly this appearance.
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

    /// One slot deeper than the deepest card actually in the deck — where a thrown card
    /// comes to rest, just underneath the pile.
    private var backDepth: CGFloat { CGFloat(positions.count) }

    /// The thrown card looping back to the bottom of the deck. It picks up exactly where
    /// the fling left off (off-screen, full size, same tilt) and shrinks into the back,
    /// fading out over the last sliver of travel so its removal is never visible.
    @ViewBuilder
    private func returningCard(sportIndex: Int) -> some View {
        let s = sports[sportIndex]
        let sc = Color(hex: s.color)
        let t = returnProgress
        let depth = backDepth * (1 - t)
        let edgeX = returningFromRight ? flingDistance : -flingDistance
        // Matches the tilt the fling ended on: flingDistance / 40.
        let tilt = Double(t) * Double(edgeX / 40)

        card(s, color: sc, dimAmount: Double(min(1, depth / max(1, backDepth))),
             difficultyText: s.difficulty.label(lang))
            .scaleEffect(1 - depth * 0.05)
            .rotationEffect(.degrees(tilt))
            .offset(x: depth * 10 + t * edgeX, y: depth * 8)
            .opacity(min(1, Double(t) * 10))
            // Starts at the same 0.27 the thrown card had, so the shadow doesn't blink out
            // at the handoff, and thins as the card settles behind the deck.
            .shadow(color: sc.opacity(0.27 * Double(t)), radius: 15, x: 0, y: 14)
            .zIndex(0)
            .allowsHitTesting(false)
    }

    /// Phase one: throw the front card off the edge it was dragged toward while the deck
    /// steps forward underneath it. The re-index at the end is deliberately un-animated —
    /// the next card has already slid into the front position, so it's invisible.
    /// Phase two: hand the thrown card to `returningCard` to loop back to the bottom.
    private func fling(toward width: CGFloat) {
        flinging = true
        let step = width < 0 ? 1 : -1          // matches `direction` for this drag
        let fromRight = width > 0
        let outgoing = index
        returnToken += 1
        let token = returnToken

        withAnimation(.easeOut(duration: flingDuration)) {
            drag = fromRight ? flingDistance : -flingDistance
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + flingDuration) {
            // Nothing moves on this frame: the returning card is placed exactly where the
            // thrown card already is, and the deck is re-indexed under the incoming card.
            var t = Transaction()
            t.disablesAnimations = true
            withTransaction(t) {
                returningIndex = outgoing
                returningFromRight = fromRight
                returnProgress = 1
                index = (index + step + n) % n
                drag = 0
            }
            // Unlock the gesture straight away — the loop-back is decorative, so a quick
            // second swipe shouldn't have to wait for it.
            flinging = false

            // Next runloop tick, otherwise SwiftUI coalesces the 1 with the animation to 0
            // and the card simply appears at the back instead of travelling there.
            DispatchQueue.main.async {
                withAnimation(.easeInOut(duration: returnDuration)) { returnProgress = 0 }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + returnDuration + 0.05) {
                // Only clear if no newer swipe has claimed the slot in the meantime.
                guard token == returnToken else { return }
                var t2 = Transaction()
                t2.disablesAnimations = true
                withTransaction(t2) { returningIndex = nil }
            }
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
