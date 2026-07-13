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
    let pre: Int
    let duringPer30: Int
    let needsDuring: Bool
    let risk: String
    let intensity: String
    let met: Double
    let sport: Sport
}

/// Heuristic carb recommendation for a planned session.
func computeCarbPlan(sportId: String, durationMin: Int, iob: Double, recentCarbsG: Int) -> CarbPlan {
    let sport = SPORTS.first { $0.id == sportId } ?? SPORTS[0]
    let met = sport.met
    let intensity = met >= 8 ? "high" : (met >= 5 ? "moderate" : "low")
    let intensityFactor = intensity == "high" ? 0.62 : (intensity == "moderate" ? 0.4 : 0.2)

    var pre = intensityFactor * Double(durationMin) * 0.55
    pre += iob * 7                        // active insulin drives glucose down
    pre -= Double(recentCarbsG) * 0.18    // recent carbs already buffer
    pre = max(0, (pre / 5).rounded() * 5)

    let needsDuring = durationMin > 45 || (durationMin > 30 && intensity != "low")
    let duringPer30 = needsDuring ? max(5, (pre * 0.35 / 5).rounded() * 5) : 0

    var risk = "Low"
    if iob > 1.2 && intensity != "low" { risk = "High" }
    else if iob > 0.5 || intensity == "high" { risk = "Moderate" }

    return CarbPlan(pre: Int(pre), duringPer30: Int(duringPer30), needsDuring: needsDuring,
                    risk: risk, intensity: intensity, met: met, sport: sport)
}
