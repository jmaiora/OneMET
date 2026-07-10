import SwiftUI

// Charts.swift — SVG-style data-viz primitives for OneMET
// Ported from the Claude Design handoff (charts.jsx). Rendered with Canvas + Path.

/// Smooth path through points using a Catmull-Rom -> bezier conversion.
func smoothPath(_ pts: [CGPoint]) -> Path {
    var path = Path()
    guard pts.count >= 2 else { return path }
    path.move(to: pts[0])
    for i in 0..<(pts.count - 1) {
        let p0 = i > 0 ? pts[i - 1] : pts[i]
        let p1 = pts[i]
        let p2 = pts[i + 1]
        let p3 = (i + 2 < pts.count) ? pts[i + 2] : p2
        let c1 = CGPoint(x: p1.x + (p2.x - p0.x) / 6, y: p1.y + (p2.y - p0.y) / 6)
        let c2 = CGPoint(x: p2.x - (p3.x - p1.x) / 6, y: p2.y - (p3.y - p1.y) / 6)
        path.addCurve(to: p2, control1: c1, control2: c2)
    }
    return path
}

// MARK: - Activity rings

struct ActivityRings: View {
    var size: CGFloat = 132
    var stroke: CGFloat = 13
    var gap: CGFloat = 4
    var fractions: [Double] = [SampleData.rings.move.frac,
                               SampleData.rings.exer.frac,
                               SampleData.rings.met.frac]

    private let colors: [Color] = [Theme.ringMove, Theme.ringExer, Theme.ringMet]

    var body: some View {
        ZStack {
            ForEach(0..<3, id: \.self) { i in
                let inset = stroke / 2 + CGFloat(i) * (stroke + gap)
                let frac = CGFloat(min(fractions[i], 1))
                Circle()
                    .inset(by: inset)
                    .stroke(colors[i].opacity(0.18), style: StrokeStyle(lineWidth: stroke))
                Circle()
                    .inset(by: inset)
                    .trim(from: 0, to: frac)
                    .stroke(colors[i], style: StrokeStyle(lineWidth: stroke, lineCap: .round))
                    .rotationEffect(.degrees(-90))
            }
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Glucose chart (hero)

struct GlucoseChart: View {
    var height: CGFloat = 168
    var mmol: Bool = false
    var accent: Color
    var showRun: Bool = true
    var from: Int = 0
    var to: Int = 288
    var markCurrent: Bool = true
    var data: [Double] = SampleData.glucose
    var currentIdx: Int = SampleData.currentIdx
    var runFrom: Int? = 192
    var runTo: Int? = 216
    var low: Double = Theme.targetLow
    var high: Double = Theme.targetHigh

    var body: some View {
        Canvas { ctx, size in
            let upper = min(to, data.count)
            let lower = min(from, upper)
            let series = Array(data[lower..<upper])
            let n = series.count
            guard n > 1 else { return }

            let w = size.width, h = size.height
            let padT: CGFloat = 10, padB: CGFloat = 22, padL: CGFloat = 0, padR: CGFloat = 30
            let gMin: CGFloat = 40, gMax: CGFloat = 240

            func X(_ i: Int) -> CGFloat { padL + CGFloat(i) / CGFloat(n - 1) * (w - padL - padR) }
            func Y(_ v: CGFloat) -> CGFloat { padT + (1 - (v - gMin) / (gMax - gMin)) * (h - padT - padB) }

            let pts = series.enumerated().map { CGPoint(x: X($0.offset), y: Y(CGFloat($0.element))) }
            let yLow = Y(CGFloat(low)), yHigh = Y(CGFloat(high))

            // target band + dashed thresholds
            ctx.fill(Path(CGRect(x: padL, y: yHigh, width: w - padL - padR, height: yLow - yHigh)),
                     with: .color(Theme.green.opacity(0.09)))
            for yy in [yHigh, yLow] {
                var l = Path(); l.move(to: CGPoint(x: padL, y: yy)); l.addLine(to: CGPoint(x: w - padR, y: yy))
                ctx.stroke(l, with: .color(Theme.green.opacity(0.35)), style: StrokeStyle(lineWidth: 1, dash: [2, 3]))
            }
            let highLabel = mmol ? String(format: "%.1f", high / 18) : "\(Int(high))"
            let lowLabel = mmol ? String(format: "%.1f", low / 18) : "\(Int(low))"
            ctx.draw(Text(highLabel).font(.system(size: 10)).foregroundColor(Theme.ink3),
                     at: CGPoint(x: w - padR + 4, y: yHigh), anchor: .leading)
            ctx.draw(Text(lowLabel).font(.system(size: 10)).foregroundColor(Theme.ink3),
                     at: CGPoint(x: w - padR + 4, y: yLow), anchor: .leading)

            // run highlight
            let rs = max(0, (runFrom ?? -1) - lower), re = min(n - 1, (runTo ?? -2) - lower)
            if showRun && runFrom != nil && runTo != nil && re > rs {
                ctx.fill(Path(CGRect(x: X(rs), y: padT, width: X(re) - X(rs), height: h - padT - padB)),
                         with: .color(accent.opacity(0.06)))
                ctx.draw(Text("RUN").font(.system(size: 9.5, weight: .semibold)).foregroundColor(accent),
                         at: CGPoint(x: (X(rs) + X(re)) / 2, y: padT + 7), anchor: .center)
            }

            // area fill + line
            var area = smoothPath(pts)
            area.addLine(to: CGPoint(x: X(n - 1), y: h - padB))
            area.addLine(to: CGPoint(x: X(0), y: h - padB))
            area.closeSubpath()
            ctx.fill(area, with: .linearGradient(
                Gradient(colors: [accent.opacity(0.18), accent.opacity(0)]),
                startPoint: CGPoint(x: w / 2, y: padT),
                endPoint: CGPoint(x: w / 2, y: h - padB)))
            ctx.stroke(smoothPath(pts), with: .color(accent),
                       style: StrokeStyle(lineWidth: 2.4, lineCap: .round, lineJoin: .round))

            // current marker
            let curRel = currentIdx - lower
            if markCurrent && curRel >= 0 && curRel < n {
                let cp = CGPoint(x: X(curRel), y: Y(CGFloat(series[curRel])))
                ctx.fill(Path(ellipseIn: CGRect(x: cp.x - 6.5, y: cp.y - 6.5, width: 13, height: 13)), with: .color(.white))
                ctx.fill(Path(ellipseIn: CGRect(x: cp.x - 4.5, y: cp.y - 4.5, width: 9, height: 9)), with: .color(accent))
            }

            // hour labels
            var hLab = 0
            while hLab <= 24 {
                let idx = hLab * 12 - lower
                if idx >= -2 && idx <= n + 2 {
                    let lab = hLab == 0 ? "12A" : hLab == 12 ? "12P" : hLab < 12 ? "\(hLab)A" : "\(hLab - 12)P"
                    let xx = X(max(0, min(n - 1, idx)))
                    ctx.draw(Text(lab).font(.system(size: 10)).foregroundColor(Theme.ink3),
                             at: CGPoint(x: xx, y: h - 5), anchor: .center)
                }
                hLab += 6
            }
        }
        .frame(height: height)
    }
}

// MARK: - MET bars

struct MetBars: View {
    var height: CGFloat = 96
    var accent: Color
    var data: [Double] = SampleData.metByHour

    var body: some View {
        Canvas { ctx, size in
            let w = size.width, h = size.height
            let padB: CGFloat = 16, padT: CGFloat = 6
            let maxV = max(data.max() ?? 1, 1)
            let n = data.count
            let slot = w / CGFloat(n)
            let bw = slot * 0.5

            for (i, v) in data.enumerated() {
                let bh = CGFloat(v / maxV) * (h - padT - padB)
                let cx = CGFloat(i) * slot + slot / 2
                let barH = max(bh, v > 0 ? 2 : 0)
                guard barH > 0 else { continue }
                let rect = CGRect(x: cx - bw / 2, y: h - padB - barH, width: bw, height: barH)
                let op = v >= maxV * 0.8 ? 1.0 : 0.42
                ctx.fill(Path(roundedRect: rect, cornerRadius: bw / 2.5), with: .color(accent.opacity(op)))
            }
            for i in [0, 3, 6, 9, 11] {
                let hr = i * 2
                let lab = hr == 0 ? "12A" : hr == 12 ? "12P" : hr < 12 ? "\(hr)A" : "\(hr - 12)P"
                ctx.draw(Text(lab).font(.system(size: 9.5)).foregroundColor(Theme.ink3),
                         at: CGPoint(x: CGFloat(i) * slot + slot / 2, y: h - 3), anchor: .center)
            }
        }
        .frame(height: height)
    }
}

// MARK: - Heart rate chart

struct HeartChart: View {
    var height: CGFloat = 92
    var series: [Double] = SampleData.heart.series

    var body: some View {
        Canvas { ctx, size in
            let s = series
            let w = size.width, h = size.height
            let padT: CGFloat = 8, padB: CGFloat = 6
            let minV: CGFloat = 45, maxV: CGFloat = 165
            let n = s.count
            guard n > 1 else { return }
            func X(_ i: Int) -> CGFloat { CGFloat(i) / CGFloat(n - 1) * w }
            func Y(_ v: CGFloat) -> CGFloat { padT + (1 - (v - minV) / (maxV - minV)) * (h - padT - padB) }
            let pts = s.enumerated().map { CGPoint(x: X($0.offset), y: Y(CGFloat($0.element))) }
            ctx.stroke(smoothPath(pts), with: .color(Theme.red),
                       style: StrokeStyle(lineWidth: 2.2, lineCap: .round, lineJoin: .round))
            for p in pts {
                ctx.fill(Path(ellipseIn: CGRect(x: p.x - 2.4, y: p.y - 2.4, width: 4.8, height: 4.8)),
                         with: .color(Theme.red))
            }
        }
        .frame(height: height)
    }
}

// MARK: - Sparkline

struct Sparkline: View {
    let data: [Double]
    var color: Color
    var height: CGFloat = 36
    var width: CGFloat = 90

    var body: some View {
        Canvas { ctx, size in
            guard data.count > 1 else { return }
            let minV = data.min() ?? 0, maxV = data.max() ?? 1
            let span = (maxV - minV) == 0 ? 1 : (maxV - minV)
            func X(_ i: Int) -> CGFloat { CGFloat(i) / CGFloat(data.count - 1) * size.width }
            func Y(_ v: Double) -> CGFloat { 3 + CGFloat(1 - (v - minV) / span) * (size.height - 6) }
            let pts = data.enumerated().map { CGPoint(x: X($0.offset), y: Y($0.element)) }
            ctx.stroke(smoothPath(pts), with: .color(color),
                       style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
        }
        .frame(width: width, height: height)
    }
}

// MARK: - Time-in-range stacked bar

struct TIRBar: View {
    var height: CGFloat = 14
    var tir: TimeInRange = SampleData.tir

    var body: some View {
        let segs: [(v: Int, c: Color)] = [
            (tir.low, Theme.red), (tir.inRange, Theme.green), (tir.high, Theme.amber)
        ]
        GeometryReader { geo in
            HStack(spacing: 2) {
                ForEach(0..<segs.count, id: \.self) { i in
                    if segs[i].v > 0 {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(segs[i].c)
                            .frame(width: max(0, geo.size.width * CGFloat(segs[i].v) / 100 - 2))
                    }
                }
            }
        }
        .frame(height: height)
        .clipShape(RoundedRectangle(cornerRadius: height / 2))
    }
}

// MARK: - 14-day TIR trend bars

struct TrendBars: View {
    var height: CGFloat = 150
    var accent: Color
    var data: [Double] = SampleData.tirTrend

    var body: some View {
        Canvas { ctx, size in
            let w = size.width, h = size.height
            guard !data.isEmpty else { return }
            let padB: CGFloat = 18, padT: CGFloat = 6
            let n = data.count
            let slot = w / CGFloat(n)
            let bw = slot * 0.56
            func Y(_ v: Double) -> CGFloat { padT + CGFloat(1 - v / 100) * (h - padT - padB) }

            var goal = Path()
            goal.move(to: CGPoint(x: 0, y: Y(70))); goal.addLine(to: CGPoint(x: w, y: Y(70)))
            ctx.stroke(goal, with: .color(Theme.green.opacity(0.4)), style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
            ctx.draw(Text("70% goal").font(.system(size: 9.5, weight: .semibold)).foregroundColor(Theme.green),
                     at: CGPoint(x: 2, y: Y(70) - 4), anchor: .bottomLeading)

            for (i, v) in data.enumerated() {
                let bh = CGFloat(v / 100) * (h - padT - padB)
                let cx = CGFloat(i) * slot + slot / 2
                let rect = CGRect(x: cx - bw / 2, y: h - padB - bh, width: bw, height: bh)
                let color = v >= 70 ? Theme.green : accent
                let op = v >= 70 ? 0.9 : 0.5
                ctx.fill(Path(roundedRect: rect, cornerRadius: 3), with: .color(color.opacity(op)))
            }
            for i in [0, 6, 13] {
                let lab = i == 13 ? "Today" : "\(14 - i)d"
                ctx.draw(Text(lab).font(.system(size: 9.5)).foregroundColor(Theme.ink3),
                         at: CGPoint(x: CGFloat(i) * slot + slot / 2, y: h - 4), anchor: .center)
            }
        }
        .frame(height: height)
    }
}

// MARK: - Correlation scatter

struct CorrScatter: View {
    var height: CGFloat = 168
    var accent: Color
    var data: [CorrPoint] = SampleData.corr

    var body: some View {
        Canvas { ctx, size in
            let w = size.width, h = size.height
            guard !data.isEmpty else { return }
            let padL: CGFloat = 28, padB: CGFloat = 24, padT: CGFloat = 8, padR: CGFloat = 8
            let xMin: CGFloat = 1, xMax: CGFloat = 11, yMin: CGFloat = 55, yMax: CGFloat = 95
            func X(_ v: Double) -> CGFloat { padL + (CGFloat(v) - xMin) / (xMax - xMin) * (w - padL - padR) }
            func Y(_ v: Double) -> CGFloat { padT + (1 - (CGFloat(v) - yMin) / (yMax - yMin)) * (h - padT - padB) }

            for g in [60.0, 70, 80, 90] {
                var line = Path()
                line.move(to: CGPoint(x: padL, y: Y(g))); line.addLine(to: CGPoint(x: w - padR, y: Y(g)))
                ctx.stroke(line, with: .color(Theme.hair), style: StrokeStyle(lineWidth: 1))
                ctx.draw(Text("\(Int(g))%").font(.system(size: 9.5)).foregroundColor(Theme.ink3),
                         at: CGPoint(x: 2, y: Y(g)), anchor: .leading)
            }
            // intensity reference lines (moderate 3, vigorous 6)
            for mv in [3.0, 6.0] {
                var vline = Path(); vline.move(to: CGPoint(x: X(mv), y: padT)); vline.addLine(to: CGPoint(x: X(mv), y: h - padB))
                ctx.stroke(vline, with: .color(Theme.hair), style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
                ctx.draw(Text("\(Int(mv))").font(.system(size: 9)).foregroundColor(Theme.ink3),
                         at: CGPoint(x: X(mv), y: h - padB + 9), anchor: .center)
            }
            let sorted = data.sorted { $0.met < $1.met }
            let trendPts = sorted.map { CGPoint(x: X($0.met), y: Y($0.tirPct)) }
            ctx.stroke(smoothPath(trendPts), with: .color(accent.opacity(0.35)),
                       style: StrokeStyle(lineWidth: 2, dash: [4, 3]))
            for d in data {
                ctx.fill(Path(ellipseIn: CGRect(x: X(d.met) - 4.5, y: Y(d.tirPct) - 4.5, width: 9, height: 9)),
                         with: .color(accent.opacity(0.85)))
            }
            ctx.draw(Text("Avg workout MET →").font(.system(size: 9.5)).foregroundColor(Theme.ink3),
                     at: CGPoint(x: (padL + w - padR) / 2, y: h - 4), anchor: .center)
        }
        .frame(height: height)
    }
}

// MARK: - Workout MET intensity bars (from Apple's per-workout METs)

struct WorkoutMetBars: View {
    var workouts: [Workout]
    var height: CGFloat = 104
    var showLabels: Bool = true

    var body: some View {
        Canvas { ctx, size in
            guard !workouts.isEmpty else { return }
            let w = size.width, h = size.height
            let padT: CGFloat = 14, padB: CGFloat = showLabels ? 24 : 8
            let maxMet = max(12, (workouts.map { $0.avgMet }.max() ?? 12))
            let n = workouts.count
            let slot = w / CGFloat(n)
            let bw = min(slot * 0.5, 44)
            func Y(_ v: Double) -> CGFloat { padT + CGFloat(1 - v / maxMet) * (h - padT - padB) }

            // reference lines: moderate (3) and vigorous (6) MET
            for (ref, lab) in [(3.0, "moderate"), (6.0, "vigorous")] {
                var line = Path()
                line.move(to: CGPoint(x: 0, y: Y(ref))); line.addLine(to: CGPoint(x: w, y: Y(ref)))
                ctx.stroke(line, with: .color(Theme.ink3.opacity(0.45)), style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
                if showLabels {
                    ctx.draw(Text("\(Int(ref)) · \(lab)").font(.system(size: 9)).foregroundColor(Theme.ink3),
                             at: CGPoint(x: 2, y: Y(ref) - 6), anchor: .bottomLeading)
                }
            }

            for (i, wo) in workouts.enumerated() {
                let met = wo.avgMet
                let bh = CGFloat(met / maxMet) * (h - padT - padB)
                let cx = CGFloat(i) * slot + slot / 2
                let color: Color = met >= 6 ? Theme.amber : (met >= 3 ? Theme.green : Theme.ink3)
                let rect = CGRect(x: cx - bw / 2, y: h - padB - max(bh, 2), width: bw, height: max(bh, 2))
                ctx.fill(Path(roundedRect: rect, cornerRadius: 4), with: .color(color))
                ctx.draw(Text(fmtNum(met)).font(.system(size: 10, weight: .semibold)).foregroundColor(Theme.ink),
                         at: CGPoint(x: cx, y: h - padB - bh - 3), anchor: .bottom)
                if showLabels {
                    let short = wo.name.split(separator: " ").first.map(String.init) ?? wo.name
                    ctx.draw(Text(short).font(.system(size: 9.5)).foregroundColor(Theme.ink2),
                             at: CGPoint(x: cx, y: h - 4), anchor: .center)
                }
            }
        }
        .frame(height: height)
    }
}

// MARK: - Single-workout glucose overlay (pre → during → post)

struct WorkoutChart: View {
    var session: WorkoutSession
    var accent: Color
    var height: CGFloat = 168

    var body: some View {
        Canvas { ctx, size in
            let data = session.curve
            let n = data.count
            guard n > 1 else { return }
            let w = size.width, h = size.height
            let padT: CGFloat = 10, padB: CGFloat = 22, padL: CGFloat = 0, padR: CGFloat = 30
            let gMin: CGFloat = 40, gMax: CGFloat = 240

            func X(_ i: Int) -> CGFloat { padL + CGFloat(i) / CGFloat(n - 1) * (w - padL - padR) }
            func Y(_ v: CGFloat) -> CGFloat { padT + (1 - (v - gMin) / (gMax - gMin)) * (h - padT - padB) }

            let pts = data.enumerated().map { CGPoint(x: X($0.offset), y: Y(CGFloat($0.element))) }
            let yLow = Y(70), yHigh = Y(180)

            // target band + thresholds
            ctx.fill(Path(CGRect(x: padL, y: yHigh, width: w - padL - padR, height: yLow - yHigh)),
                     with: .color(Theme.green.opacity(0.09)))
            for yy in [yHigh, yLow] {
                var l = Path(); l.move(to: CGPoint(x: padL, y: yy)); l.addLine(to: CGPoint(x: w - padR, y: yy))
                ctx.stroke(l, with: .color(Theme.green.opacity(0.35)), style: StrokeStyle(lineWidth: 1, dash: [2, 3]))
            }
            ctx.draw(Text("180").font(.system(size: 10)).foregroundColor(Theme.ink3), at: CGPoint(x: w - padR + 4, y: yHigh), anchor: .leading)
            ctx.draw(Text("70").font(.system(size: 10)).foregroundColor(Theme.ink3), at: CGPoint(x: w - padR + 4, y: yLow), anchor: .leading)

            // activity window
            let rs = X(session.activityStart), re = X(session.activityEnd)
            if re > rs {
                ctx.fill(Path(CGRect(x: rs, y: padT, width: re - rs, height: h - padT - padB)), with: .color(accent.opacity(0.06)))
                ctx.draw(Text(session.name.uppercased()).font(.system(size: 9.5, weight: .semibold)).foregroundColor(accent),
                         at: CGPoint(x: (rs + re) / 2, y: padT + 7), anchor: .center)
            }

            // area + line
            var area = smoothPath(pts)
            area.addLine(to: CGPoint(x: X(n - 1), y: h - padB))
            area.addLine(to: CGPoint(x: X(0), y: h - padB))
            area.closeSubpath()
            ctx.fill(area, with: .linearGradient(Gradient(colors: [accent.opacity(0.18), accent.opacity(0)]),
                                                 startPoint: CGPoint(x: w / 2, y: padT), endPoint: CGPoint(x: w / 2, y: h - padB)))
            ctx.stroke(smoothPath(pts), with: .color(accent), style: StrokeStyle(lineWidth: 2.4, lineCap: .round, lineJoin: .round))

            // phase labels
            ctx.draw(Text("Before").font(.system(size: 10)).foregroundColor(Theme.ink3), at: CGPoint(x: 2, y: h - 5), anchor: .leading)
            ctx.draw(Text("Activity").font(.system(size: 10)).foregroundColor(Theme.ink3), at: CGPoint(x: (rs + re) / 2, y: h - 5), anchor: .center)
            ctx.draw(Text("After").font(.system(size: 10)).foregroundColor(Theme.ink3), at: CGPoint(x: w - padR, y: h - 5), anchor: .trailing)
        }
        .frame(height: height)
    }
}

// MARK: - Daily MET·min trend (full width)

struct MetMinTrendBars: View {
    var data: [Double]
    var accent: Color
    var height: CGFloat = 130

    var body: some View {
        Canvas { ctx, size in
            guard !data.isEmpty else { return }
            let w = size.width, h = size.height
            let padB: CGFloat = 18, padT: CGFloat = 6
            let maxV = max(data.max() ?? 1, 1)
            let n = data.count
            let slot = w / CGFloat(n)
            let bw = slot * 0.56

            for (i, v) in data.enumerated() {
                let bh = CGFloat(v / maxV) * (h - padT - padB)
                let cx = CGFloat(i) * slot + slot / 2
                let isToday = i == n - 1
                let barH = max(bh, v > 0 ? 2 : 0)
                guard barH > 0 else { continue }
                let rect = CGRect(x: cx - bw / 2, y: h - padB - barH, width: bw, height: barH)
                ctx.fill(Path(roundedRect: rect, cornerRadius: 3), with: .color(accent.opacity(isToday ? 1.0 : 0.45)))
            }

            let labels: [(Int, String)] = [(0, "\(n)d"), (n / 2, "\(n - n / 2)d"), (n - 1, "Today")]
            for (i, lab) in labels where i >= 0 && i < n {
                ctx.draw(Text(lab).font(.system(size: 9.5)).foregroundColor(Theme.ink3),
                         at: CGPoint(x: CGFloat(i) * slot + slot / 2, y: h - 4), anchor: .center)
            }
        }
        .frame(height: height)
    }
}
