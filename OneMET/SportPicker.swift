import SwiftUI

// SportPicker.swift — swipeable stacked sport cards for the Plan tab.
// Ported from the v2 design handoff (cards.jsx: SportCards).

struct SportPicker: View {
    let sports: [Sport]
    @Binding var index: Int
    var accent: Color
    var durationLabel: String

    @State private var drag: CGFloat = 0

    private var n: Int { max(sports.count, 1) }

    var body: some View {
        VStack(spacing: 14) {
            ZStack {
                // back-to-front: one peek card behind, the front card on top
                ForEach([1, 0], id: \.self) { offset in
                    cardView(offset: offset)
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
                            withAnimation(.spring(response: 0.34, dampingFraction: 0.85)) { index = i }
                        }
                }
            }
        }
    }

    @ViewBuilder
    private func cardView(offset: Int) -> some View {
        let s = sports[(index + offset) % n]
        let sc = Color(hex: s.color)
        let depth = CGFloat(offset)
        let tx = CGFloat(offset) * 10 + (offset == 0 ? drag : 0)
        let ty = depth * 8
        let scale = 1 - depth * 0.05
        let rot = offset == 0 ? Double(drag / 40) : Double(offset) * 2.5

        let styled = card(s, color: sc, dim: offset != 0)
            .scaleEffect(scale)
            .rotationEffect(.degrees(rot))
            .offset(x: tx, y: ty)
            .shadow(color: offset == 0 ? sc.opacity(0.27) : .clear, radius: 15, x: 0, y: 14)
            .zIndex(offset == 0 ? 2 : 1)

        if offset == 0 {
            styled.gesture(
                DragGesture()
                    .onChanged { drag = $0.translation.width }
                    .onEnded { value in
                        let w = value.translation.width
                        withAnimation(.spring(response: 0.34, dampingFraction: 0.85)) {
                            if abs(w) > 60 { index = (index + (w < 0 ? 1 : -1) + n) % n }
                            drag = 0
                        }
                    }
            )
        } else {
            styled
        }
    }

    private func card(_ s: Sport, color sc: Color, dim: Bool) -> some View {
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
        .overlay(dim ? Color.black.opacity(0.14) : Color.clear)
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
        SportPicker(sports: SPORTS, index: .constant(1), accent: Theme.accent, durationLabel: "45 min")
            .padding()
    }
}
