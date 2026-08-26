import SwiftUI

// SportPicker.swift — swipeable stacked sport cards for the Plan tab.
//
// Modelled on a physical pile of cards: the top card follows your finger in *both* axes
// and tilts as it goes, the pile underneath stays put, and a flick sends the card off in
// whatever direction you threw it. Only once it's clear of the screen does the pile step
// forward, and the thrown card loops back in to tuck underneath at the bottom.
//
// Positions, not indices. The stack is addressed by *position* (0 = front, 1 = behind,
// 2 = deeper) and the direction of travel decides which sports fill those positions, so
// forward and backward swipes run identical code.

struct SportPicker: View {
    let sports: [Sport]
    @Binding var index: Int
    var accent: Color
    var durationLabel: String
    var difficultyLabel: String
    var lang: AppLanguage = .en

    /// Live finger offset for the top card, in both axes.
    @State private var drag: CGSize = .zero
    /// True once this gesture has been claimed by the card rather than the page scroll.
    @State private var claimed = false
    @State private var flinging = false
    /// 0 while you drag (the pile holds still), 1 once the thrown card is clear — this is
    /// what steps the pile forward, so the reveal happens after the throw, not during it.
    @State private var flingProgress: CGFloat = 0
    /// Frozen while a throw is in flight so the cards can't swap content mid-air.
    @State private var lockedDirection: Int? = nil

    // The card looping back to the bottom of the pile, if one is in flight.
    @State private var returningIndex: Int? = nil
    @State private var returnVector: CGSize = .zero
    /// 1 = still out where the throw left it, 0 = tucked in at the back.
    @State private var returnProgress: CGFloat = 0
    /// Guards the cleanup timer so a second throw can't cancel the newer card's return.
    @State private var returnToken = 0

    private var n: Int { max(sports.count, 1) }

    /// How far a thrown card travels along its exit vector. Comfortably past any edge.
    private let flingDistance: CGFloat = 620
    private let flingDuration = 0.26
    private let returnDuration = 0.34
    /// Drag this far (or flick harder than the predicted threshold) to commit.
    private let commitDistance: CGFloat = 60
    private let maxTilt: Double = 18

    // Fan geometry: each card behind sits further right, a little *higher*, smaller and
    // rotated — the way a held hand of cards splays.
    private let fanX: CGFloat = 14
    private let fanY: CGFloat = -7
    private let fanScale: CGFloat = 0.04
    private let fanTilt: Double = 3.5

    /// +1 advances to the next sport, -1 goes back. At rest it's +1, so the resting peek
    /// card is the next one along.
    private var direction: Int { lockedDirection ?? (drag.width > 0 ? -1 : 1) }

    /// A card tilts in proportion to how far sideways it's been pulled, like a real card
    /// pivoting against the pile.
    private func tilt(_ d: CGSize) -> Double {
        max(-maxTilt, min(maxTilt, Double(d.width) / 18))
    }

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

        // Held still while you drag; steps forward only as the thrown card clears, so
        // position 1 lands exactly where position 0 was when the index changes.
        let depth = max(0, CGFloat(p) - flingProgress)

        let styled = card(s, color: sc, dimAmount: Double(min(1, depth)),
                          difficultyText: front ? difficultyLabel : s.difficulty.label(lang))
            .scaleEffect(1 - depth * fanScale)
            .rotationEffect(.degrees(front ? tilt(drag) : Double(depth) * fanTilt))
            .offset(x: depth * fanX + (front ? drag.width : 0),
                    y: depth * fanY + (front ? drag.height : 0))
            // No fade on the way out: the thrown card is handed straight to
            // returningCard(), which has to pick it up at exactly this appearance.
            .shadow(color: depth < 0.5 ? sc.opacity(0.27 * (1 - Double(depth) * 2)) : .clear,
                    radius: 15, x: 0, y: 14)
            .zIndex(Double(10 - p))

        if front {
            styled.gesture(
                DragGesture(minimumDistance: 6)
                    .onChanged { v in
                        guard !flinging else { return }
                        if !claimed {
                            // The first decisive movement settles who owns this gesture. A
                            // mostly-vertical start belongs to the page scroll; anything
                            // else is the card's, and from then on it tracks freely in 2D.
                            guard abs(v.translation.width) > abs(v.translation.height) else { return }
                            claimed = true
                        }
                        drag = v.translation
                    }
                    .onEnded { v in
                        defer { claimed = false }
                        guard !flinging, claimed else { return }
                        let t = v.translation
                        let pred = v.predictedEndTranslation
                        if hypot(t.width, t.height) > commitDistance || hypot(pred.width, pred.height) > 220 {
                            fling(translation: t, predicted: pred)
                        } else {
                            withAnimation(.spring(response: 0.34, dampingFraction: 0.85)) { drag = .zero }
                        }
                    }
            )
        } else {
            styled
        }
    }

    /// One slot deeper than the deepest card in the pile — where a thrown card settles.
    private var backDepth: CGFloat { CGFloat(positions.count) }

    /// The thrown card looping back to the bottom of the pile. It picks up exactly where
    /// the throw left off (same offset, tilt and scale) and shrinks into the back, fading
    /// out over the last sliver of travel so its removal is never visible.
    @ViewBuilder
    private func returningCard(sportIndex: Int) -> some View {
        let s = sports[sportIndex]
        let sc = Color(hex: s.color)
        let t = returnProgress
        let depth = backDepth * (1 - t)

        card(s, color: sc, dimAmount: Double(min(1, depth / max(1, backDepth))),
             difficultyText: s.difficulty.label(lang))
            .scaleEffect(1 - depth * fanScale)
            .rotationEffect(.degrees(Double(t) * tilt(returnVector) + Double(depth) * fanTilt))
            .offset(x: depth * fanX + t * returnVector.width,
                    y: depth * fanY + t * returnVector.height)
            .opacity(min(1, Double(t) * 10))
            // Starts at the same 0.27 the thrown card had, so the shadow doesn't blink out
            // at the handoff, and thins as the card settles behind the pile.
            .shadow(color: sc.opacity(0.27 * Double(t)), radius: 15, x: 0, y: 14)
            .zIndex(0)
            .allowsHitTesting(false)
    }

    /// Where a thrown card exits: the direction of the flick (falling back to the raw
    /// drag for a slow release), normalised out to `flingDistance`.
    private func exitVector(_ t: CGSize, _ pred: CGSize) -> CGSize {
        let v = hypot(pred.width, pred.height) > hypot(t.width, t.height) ? pred : t
        let len = max(1, hypot(v.width, v.height))
        return CGSize(width: v.width / len * flingDistance,
                      height: v.height / len * flingDistance)
    }

    /// Phase one: throw the card along the flick, and step the pile forward behind it.
    /// The re-index at the end is un-animated — the next card is already in the front
    /// position by then, so it's invisible.
    /// Phase two: hand the thrown card to `returningCard` to loop back to the bottom.
    private func fling(translation: CGSize, predicted: CGSize) {
        flinging = true
        let step = direction               // whichever way the deck was already showing
        lockedDirection = step             // freeze it so cards can't swap content in flight
        let exit = exitVector(translation, predicted)
        let outgoing = index
        returnToken += 1
        let token = returnToken

        withAnimation(.easeOut(duration: flingDuration)) {
            drag = exit
            flingProgress = 1
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + flingDuration) {
            // Nothing moves on this frame: the returning card is placed exactly where the
            // thrown card already is, and the pile is re-indexed under the incoming card.
            var tx = Transaction()
            tx.disablesAnimations = true
            withTransaction(tx) {
                returningIndex = outgoing
                returnVector = exit
                returnProgress = 1
                index = (index + step + n) % n
                drag = .zero
                flingProgress = 0
                lockedDirection = nil
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
                var tx2 = Transaction()
                tx2.disablesAnimations = true
                withTransaction(tx2) { returningIndex = nil }
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
