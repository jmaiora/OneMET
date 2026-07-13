import SwiftUI

// SportPicker.swift — 3D swipeable sport card deck for the Plan tab.
// Ported from cards.jsx (SportCards), enhanced so the swiped top card
// visibly rotates and sinks to the bottom of the stack.

struct SportPicker: View {
    let sports: [Sport]
    @Binding var index: Int
    var accent: Color
    var durationLabel: String

    @State private var drag: CGFloat = 0

    private var n: Int { max(sports.count, 1) }
    private let maxDepth = 3          // number of distinct depth steps shown

    var body: some View {
        VStack(spacing: 14) {
            ZStack {
                // Render the whole deck; each card's slot is its distance from the front.
                ForEach(sports.indices, id: \.self) { i in
                    cardView(sport: sports[i], slot: (i - index + n) % n)
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
                            withAnimation(.spring(response: 0.5, dampingFraction: 0.78)) { index = i }
                        }
                }
            }
        }
    }

    @ViewBuilder
    private func cardView(sport s: Sport, slot: Int) -> some View {
        let isFront = slot == 0
        let d = CGFloat(min(slot, maxDepth))          // capped depth for transforms
        let dragX = isFront ? drag : 0

        let sc = Color(hex: s.color)
        let scale = 1 - d * 0.06
        let yOff = d * 14
        let xOff = dragX + d * 6                       // slight fan for depth
        let dim = slot == 0 ? 0.0 : min(0.30, 0.10 + d * 0.07)
        let yAngle = isFront ? Double(dragX / 14) : 0  // tilt toward the drag (perspective)
        let xAngle = Double(d) * 7                     // deeper cards recline back
        let visible = slot <= maxDepth

        let styled = card(s, color: sc, dim: dim)
            .scaleEffect(scale)
            .rotation3DEffect(.degrees(xAngle), axis: (x: 1, y: 0, z: 0), anchor: .top, perspective: 0.6)
            .rotation3DEffect(.degrees(yAngle), axis: (x: 0, y: 1, z: 0), perspective: 0.7)
            .offset(x: xOff, y: yOff)
            .shadow(color: isFront ? sc.opacity(0.35) : .black.opacity(0.06),
                    radius: isFront ? 18 : 6, x: 0, y: isFront ? 14 : 5)
            .opacity(visible ? 1 : 0)
            .zIndex(Double(n - slot))

        if isFront {
            styled.gesture(
                DragGesture()
                    .onChanged { drag = $0.translation.width }
                    .onEnded { value in
                        if abs(value.translation.width) > 70 {
                            // top card swoops off in the drag direction and cycles to the bottom
                            withAnimation(.spring(response: 0.52, dampingFraction: 0.72)) {
                                index = (index + 1) % n
                                drag = 0
                            }
                        } else {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { drag = 0 }
                        }
                    }
            )
        } else {
            styled
        }
    }

    private func card(_ s: Sport, color sc: Color, dim: Double) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top) {
                HStack(spacing: 18) {
                    cardStat("Time", durationLabel)
                    cardStat("Difficulty", s.difficulty)
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
        .overlay(Color.black.opacity(dim))
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
        SportPicker(sports: SPORTS, index: .constant(0), accent: Theme.accent, durationLabel: "45 min")
            .padding()
    }
}
