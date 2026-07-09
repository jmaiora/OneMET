import Foundation

// WorkoutModels.swift — richer workout model for the Workouts history + detail (v2).

struct WorkoutSession: Identifiable {
    let id: String
    let name: String
    let sportId: String
    let icon: String
    let day: String        // "Fri, Jun 19"
    let time: String       // "4:08 PM"
    let dur: String        // "32 min"
    let durMin: Int
    let dist: String       // "5.2 km" or "—"
    let kcal: Int
    let avgMet: Double
    let hr: Int
    let glucoseDelta: Int
    let curve: [Double]    // pre → during → post glucose (5-min cadence)
    let activityStart: Int // index in curve where the session begins
    let activityEnd: Int
    let insight: String
}

struct WorkoutWeek: Identifiable {
    let id = UUID()
    let label: String
    let sessions: [WorkoutSession]
}

func weekLabel(_ weeksAgo: Int) -> String {
    switch weeksAgo {
    case 0: return "This Week"
    case 1: return "Last Week"
    default: return "\(weeksAgo) Weeks Ago"
    }
}

/// Insight copy for a session, based on the glucose delta (ported from data.jsx).
func workoutInsight(name: String, durMin: Int, delta: Int) -> String {
    let d = abs(delta)
    if delta < -25 {
        return "This \(name.lowercased()) lowered glucose by \(d) mg/dL over \(durMin) min — consider \(Int((Double(d) * 0.4).rounded()))g carbs before similar sessions."
    } else if delta < -12 {
        return "Moderate drop of \(d) mg/dL during this session — a small snack beforehand can help keep you in range."
    } else {
        return "Glucose stayed steady, dropping only \(d) mg/dL — low risk activity at this intensity."
    }
}

/// Synthesize a pre/during/post glucose curve (used for mock/preview data).
func buildWorkoutCurve(baseline: Double, durMin: Int, delta: Int,
                       preMin: Int = 30, postMin: Int = 60) -> (curve: [Double], activityStart: Int, activityEnd: Int) {
    var pts: [Double] = []
    func seg(_ n: Int, _ a: Double, _ b: Double, noise: Double = 3) {
        for i in 0..<n {
            let t = Double(i) / Double(max(1, n - 1))
            let s = t * t * (3 - 2 * t)
            pts.append((a + (b - a) * s + sin(Double(i) * 1.3) * noise).rounded())
        }
    }
    let preN = preMin / 5, durN = max(2, durMin / 5), postN = postMin / 5
    let low = baseline + Double(delta)
    seg(preN, baseline - 4, baseline)
    seg(durN, baseline, low)
    seg(postN, low, low + abs(Double(delta)) * 0.55)
    return (pts, preN, preN + durN)
}
