import SwiftUI

// SampleData.swift — mock health data for OneMET
// Ported from the Claude Design handoff (data.jsx). Colors/thresholds live in Theme.swift.

// MARK: - Models

struct RingMetric {
    let value: Double
    let goal: Double
    let unit: String
    var frac: Double { goal > 0 ? value / goal : 0 }
}

struct TimeInRange {
    let low: Int
    let inRange: Int
    let high: Int
}

struct HeartInfo {
    let current: Int
    let resting: Int
    let range: (low: Int, high: Int)
    let series: [Double]
}

struct Workout: Identifiable {
    let id = UUID()
    let name: String
    let time: String
    let dur: String
    let dist: String
    let kcal: Int
    let avgMet: Double
    let hr: Int
    let glucoseDelta: Int
}

struct Meal: Identifiable {
    let id = UUID()
    let name: String
    let carbs: Int
    let time: String
}

struct Nutrition {
    let carbs: Int
    let carbsGoal: Int
    let insulinUnits: Int
    let meals: [Meal]
}

struct CorrPoint: Identifiable {
    let id = UUID()
    let met: Double      // average workout MET intensity for the day
    let tirPct: Double
}

// MARK: - Glucose status helpers

struct GlucoseStatus {
    let label: String
    let color: Color
}

/// Full status (label + color) for a reading, against a target range (defaults to standard 70–180).
func glucoseStatus(_ mgdl: Double,
                   low: Double = Theme.targetLow,
                   high: Double = Theme.targetHigh) -> GlucoseStatus {
    if mgdl < low  { return GlucoseStatus(label: "Low",  color: Theme.red) }
    if mgdl > high { return GlucoseStatus(label: "High", color: Theme.amber) }
    return GlucoseStatus(label: "In Range", color: Theme.green)
}

/// Format a mg/dL value, optionally converting to mmol/L.
func fmtGlucose(_ mgdl: Double, mmol: Bool = false) -> String {
    mmol ? String(format: "%.1f", mgdl / 18) : String(Int(mgdl.rounded()))
}

// MARK: - Day-long glucose curve

/// Build a realistic Type-1 glucose curve across the day (mg/dL), 5-min cadence -> 288 pts.
private func buildGlucose() -> [Double] {
    var pts: [Double] = []
    func seg(_ from: Int, _ to: Int, _ a: Double, _ b: Double, noise: Double = 4) {
        let n = to - from
        for i in 0..<n {
            let t = Double(i) / Double(n)
            let s = t * t * (3 - 2 * t)                       // smoothstep
            let v = a + (b - a) * s + (sin(Double(i) * 1.7) + cos(Double(i) * 0.9)) * noise * 0.5
            pts.append(v.rounded())
        }
    }
    seg(0, 36, 118, 104)     // 0–3h  overnight settle
    seg(36, 72, 104, 96)     // 3–6h  dawn dip
    seg(72, 84, 96, 132)     // 6–7h  dawn rise
    seg(84, 108, 132, 191)   // 7–9h  breakfast spike
    seg(108, 144, 191, 124)  // 9–12h correction
    seg(144, 168, 124, 168)  // 12–14h lunch
    seg(168, 192, 168, 138)  // 14–16h settle
    seg(192, 204, 138, 96)   // 16–17h run begins, drop
    seg(204, 216, 96, 68)    // 17–18h run low
    seg(216, 240, 68, 122)   // 18–20h carb recovery
    seg(240, 264, 122, 174)  // 20–22h dinner spike
    seg(264, 288, 174, 120)  // 22–24h settle
    return pts
}

private func computeTIR(_ arr: [Double]) -> TimeInRange {
    var low = 0, inr = 0, high = 0
    for v in arr {
        if v < Theme.targetLow       { low += 1 }
        else if v > Theme.targetHigh { high += 1 }
        else                         { inr += 1 }
    }
    let n = Double(arr.count)
    return TimeInRange(
        low:     Int((Double(low) / n * 100).rounded()),
        inRange: Int((Double(inr) / n * 100).rounded()),
        high:    Int((Double(high) / n * 100).rounded())
    )
}

// MARK: - Sample dataset

enum SampleData {
    static let glucose: [Double] = buildGlucose()
    static let currentIdx = 210                       // ~17:30, recovering after the run dip
    static var current: Double { glucose[currentIdx] }
    static let currentTrend: Double = -2              // mg/dL per 5 min -> falling slowly

    static var avg: Double { (glucose.reduce(0, +) / Double(glucose.count)).rounded() }
    static var tir: TimeInRange { computeTIR(glucose) }

    static let rings = (
        move: RingMetric(value: 540, goal: 620, unit: "KCAL"),
        exer: RingMetric(value: 42,  goal: 45,  unit: "MIN"),
        met:  RingMetric(value: 486, goal: 500, unit: "MET·MIN")
    )

    static let steps = 8432
    static let stepsGoal = 10000

    // MET-min accumulated per 2h bucket (12 buckets)
    static let metByHour: [Double] = [0, 0, 0, 12, 64, 28, 18, 30, 196, 84, 38, 16]

    static let heart = HeartInfo(
        current: 64, resting: 58, range: (52, 158),
        series: [58, 57, 56, 58, 72, 88, 76, 70, 74, 150, 96, 74]
    )

    static let workouts: [Workout] = [
        Workout(name: "Outdoor Run", time: "4:08 PM", dur: "32 min", dist: "5.2 km",
                kcal: 348, avgMet: 9.1, hr: 152, glucoseDelta: -38),
        Workout(name: "Walk", time: "8:12 AM", dur: "18 min", dist: "1.4 km",
                kcal: 72, avgMet: 3.2, hr: 104, glucoseDelta: -9)
    ]

    static let nutrition = Nutrition(
        carbs: 168, carbsGoal: 200, insulinUnits: 24,
        meals: [
            Meal(name: "Breakfast", carbs: 62, time: "7:30 AM"),
            Meal(name: "Lunch",     carbs: 48, time: "12:15 PM"),
            Meal(name: "Snack",     carbs: 22, time: "5:55 PM"),
            Meal(name: "Dinner",    carbs: 36, time: "8:00 PM")
        ]
    )

    // 14-day time-in-range trend (% in range)
    static let tirTrend: [Double] = [71, 68, 74, 80, 77, 82, 79, 73, 85, 88, 81, 84, 90, 86]

    // Glucose vs activity correlation scatter (avg workout MET intensity, TIR %)
    static let corr: [CorrPoint] = [
        (2.6, 64), (3.4, 70), (4.1, 72), (5.0, 78), (5.8, 80),
        (6.7, 83), (7.5, 86), (8.4, 88), (3.0, 68), (5.3, 76)
    ].map { CorrPoint(met: $0.0, tirPct: $0.1) }
}
