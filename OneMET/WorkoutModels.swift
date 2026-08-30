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

func weekLabel(_ weeksAgo: Int, lang: AppLanguage = .en) -> String {
    switch weeksAgo {
    case 0:  return lang.t("workouts.thisWeek")
    case 1:  return lang.t("workouts.lastWeek")
    default: return lang.t("workouts.weeksAgo", String(weeksAgo))
    }
}

/// Above this glucose (mg/dL) a fall isn't a hypo risk, so no pre-session carbs are
/// suggested however large the drop was — dropping 60 points and landing at 190 needs
/// no fuelling, only a smaller drop that actually approaches the low threshold does.
let carbAdviceCeilingMgdl: Double = 120

/// Where the carbohydrate could actually have gone, mirroring the prospective model so
/// the two halves of the app can't contradict each other:
///
///   * nothing *before* a session that started above `preCarbCeilingMgdl` — the Plan tab
///     gives zero starting carbs there and would not have sent you out fuelled;
///   * nothing *during* a session no longer than one feed interval, since it never earns
///     a mid-session feed.
///
/// When neither window exists — a short session that began high and still fell — the only
/// honest advice left is to carry fast carbs and use them on the way down.
func carbTimingKey(startMgdl: Double?, durMin: Int) -> String {
    let canPreFuel = (startMgdl ?? 0) <= preCarbCeilingMgdl
    let canFeed = durMin > carbFeedIntervalMin
    switch (canPreFuel, canFeed) {
    case (true, false):  return "timing.before"
    case (false, true):  return "timing.during"
    case (true, true):   return "timing.both"
    case (false, false): return "timing.carry"
    }
}

/// Insight copy for a session. `startMgdl` is the reading at the start and `nadirMgdl` the
/// lowest from there through the hour after — the first decides *where* carbohydrate
/// belongs, the second whether any is warranted at all. Pass nil when there's no CGM data.
func workoutInsight(name: String, durMin: Int, delta: Int,
                    startMgdl: Double?, nadirMgdl: Double?,
                    unit: GlucoseUnit, lang: AppLanguage = .en) -> String {
    let sport = name.lowercased()
    let size = unit.amount(Double(abs(delta)))
    let mins = String(durMin)

    if delta <= -12 {
        // The size of the fall says nothing on its own — where it landed does.
        if let nadir = nadirMgdl, nadir > carbAdviceCeilingMgdl {
            return lang.t("insight.dropNoCarbs", sport, size, mins, unit.amount(nadir))
        }
        if delta <= -25 {
            let carbs = String(Int((Double(abs(delta)) * 0.4).rounded()))
            let floor = nadirMgdl.map { unit.amount($0) } ?? lang.t("insight.dropUnknownNadir")
            return lang.t("insight.dropCarbs", sport, size, mins, floor, carbs,
                          lang.t(carbTimingKey(startMgdl: startMgdl, durMin: durMin)))
        }
        return lang.t("insight.dropModerate", size)
    }
    if delta >= 25 {
        return lang.t("insight.riseBig", sport, size, mins)
    }
    if delta >= 12 {
        return lang.t("insight.riseSmall", size)
    }
    return lang.t("insight.steady", unit.deltaAmount(Double(delta)))
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
