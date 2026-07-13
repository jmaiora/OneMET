import Foundation

// PlanModel.swift — sport catalog + carb-planning heuristic (Plan tab).
// Ported from the v2 design handoff (data.jsx: SPORTS, computeCarbPlan).

struct Sport: Identifiable, Hashable {
    let id: String
    let name: String
    let met: Double
    let icon: String
    let difficulty: String
    let color: String       // hex
    let desc: String
}

let SPORTS: [Sport] = [
    Sport(id: "walk", name: "Walk", met: 3.2, icon: "shoe", difficulty: "Light", color: "#1F8A5B",
          desc: "An easy walk. Low hypo risk, gentle on glucose across the session."),
    Sport(id: "run", name: "Outdoor Run", met: 9.1, icon: "run", difficulty: "Vigorous", color: "#E0556E",
          desc: "A steady outdoor run. Expect a fast glucose drop — fuel up beforehand."),
    Sport(id: "cycling", name: "Cycling", met: 7.0, icon: "bolt", difficulty: "Moderate", color: "#E8833A",
          desc: "Sustained cycling effort. Plan a top-up if you ride past 45 minutes."),
    Sport(id: "swim", name: "Swimming", met: 8.0, icon: "drop", difficulty: "Vigorous", color: "#1FB8C9",
          desc: "Full-body swim session. Glucose can dip fast — carb up beforehand."),
    Sport(id: "strength", name: "Strength", met: 5.0, icon: "flame", difficulty: "Moderate", color: "#8E72E8",
          desc: "Resistance training. Effects on glucose are slower and can extend post-session."),
    Sport(id: "hiit", name: "HIIT", met: 10.0, icon: "activity", difficulty: "Vigorous", color: "#D6484B",
          desc: "High-intensity intervals. Sharp swings possible — monitor closely.")
]

struct CarbPlan {
    let pre: Int                 // grams before starting
    let duringPer30: Int         // grams per 30 min during the session
    let duringPerHour: Int       // grams per hour during the session
    let needsDuring: Bool
    let risk: String             // Low / Moderate / High (hypoglycaemia risk)
    let intensity: String        // low / moderate / high
    let ratePerKgHr: Double      // during-session carb rate used (g/kg/h)
    let met: Double
    let sport: Sport
    let startNote: String        // glucose-based starting guidance
    let usedGlucose: Double?     // mg/dL used (nil = no live reading)
    let usedWeightKg: Double
    let weightIsDefault: Bool
}

/// Carbohydrate estimate grounded in the 2017 international consensus on exercise
/// management in type 1 diabetes (Riddell et al., Lancet Diabetes Endocrinol 2017).
/// The published guidance gives *ranges*; the exact coefficients below are transparent
/// choices within those ranges. This is an illustrative estimate, NOT medical advice.
func computeCarbPlan(sportId: String, durationMin: Int, iob: Double, recentCarbsG: Int,
                     glucoseMgdl: Double?, trendFalling: Bool, trendRising: Bool,
                     weightKg: Double?) -> CarbPlan {
    let sport = SPORTS.first { $0.id == sportId } ?? SPORTS[0]
    let met = sport.met
    let intensity = met >= 8 ? "high" : (met >= 5 ? "moderate" : "low")

    let weight = weightKg ?? 70
    let weightIsDefault = (weightKg == nil)

    // ── Pre-session carbs from starting glucose (consensus aerobic start targets, mg/dL) ──
    var startCarbs = 0.0
    var note = ""
    if let g = glucoseMgdl, g > 0 {
        switch g {
        case ..<90:      startCarbs = 15; note = "Glucose \(Int(g)) mg/dL is below the 90 mg/dL start threshold — take ~15 g and recheck before starting."
        case 90..<126:   startCarbs = 10; note = "Glucose \(Int(g)) mg/dL is in the 90–125 band — ~10 g is advised before aerobic exercise."
        case 126..<181:  startCarbs = 0;  note = "Glucose \(Int(g)) mg/dL is in the ideal 126–180 mg/dL start range."
        case 181..<271:  startCarbs = 0;  note = "Glucose \(Int(g)) mg/dL is above target — no pre-carbs; follow your plan for a light correction if needed."
        default:         startCarbs = 0;  note = "Glucose \(Int(g)) mg/dL is high — check ketones before exercising; intense exercise can raise it further."
        }
        if trendFalling && g < 180 { startCarbs += 10; note += " It's falling, so ~10 g extra is included." }
        else if trendRising && startCarbs > 0 { startCarbs = max(0, startCarbs - 5) }
    } else {
        note = "No live glucose reading — check your CGM / Nightscout before starting."
    }

    // ── Insulin-on-board buffer (consensus: high circulating insulin → larger pre-snack) ──
    let iobBuffer = min(30, max(0, iob) * 10)        // ~10 g per unit of active insulin, capped at 30 g
    let recentCover = Double(recentCarbsG) * 0.15    // recent carbs already provide some cover

    var pre = startCarbs + iobBuffer - recentCover
    pre = max(0, (pre / 5).rounded() * 5)

    // ── During-session carbs: g/kg/h by intensity (consensus ~0.3–1.0 g/kg/h) ──
    let rate = intensity == "high" ? 0.9 : (intensity == "moderate" ? 0.6 : 0.3)
    let perHour = rate * weight
    let needsDuring = durationMin > 45 || (durationMin > 30 && intensity != "low")
    let per30 = needsDuring ? max(5, (perHour / 2 / 5).rounded() * 5) : 0

    // ── Hypoglycaemia risk ──
    var risk = "Low"
    if let g = glucoseMgdl, g > 0 {
        if g < 90 || (iob > 1.2 && intensity != "low") || (trendFalling && g < 126) { risk = "High" }
        else if g < 126 || iob > 0.5 || intensity == "high" || trendFalling { risk = "Moderate" }
    } else {
        if iob > 1.2 || intensity == "high" { risk = "High" }
        else if iob > 0.5 { risk = "Moderate" }
    }

    return CarbPlan(pre: Int(pre), duringPer30: Int(per30), duringPerHour: Int(perHour.rounded()),
                    needsDuring: needsDuring, risk: risk, intensity: intensity, ratePerKgHr: rate,
                    met: met, sport: sport, startNote: note, usedGlucose: glucoseMgdl,
                    usedWeightKg: weight, weightIsDefault: weightIsDefault)
}
