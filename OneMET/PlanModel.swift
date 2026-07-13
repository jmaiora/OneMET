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

// Prevention-first exercise guide. Rather than "eat X g every 20 min", it favours
// adjusting insulin beforehand and minimising interventions during the run — matched
// to run duration and driven by glucose trend, not fixed numbers. Grounded in the 2017
// Lancet consensus (Riddell et al.) and EXTOD, but oriented to recreational practice.
// Illustrative guidance, NOT medical advice.

enum StartStatus { case go, topUp, wait, stop, unknown }

struct RunGuide {
    let band: String                 // Easy / Moderate / Long
    let bandDetail: String
    let status: StartStatus
    let startTitle: String
    let startReason: String
    let beforeText: String           // insulin-first strategy (no doses)
    let duringText: String           // carb guidance matched to the band
    let duringHeadline: String?      // e.g. "~30–60 g/h" (long runs only)
    let philosophyText: String       // accept 140–200, avoid hypo > perfect
    let learnText: String            // log & experiment
    let deliveryIsPump: Bool
    let usedGlucose: Double?
}

func buildRunGuide(sportId: String, durationMin: Int, iob: Double, recentCarbsG: Int,
                   glucoseMgdl: Double?, trendFalling: Bool, trendRising: Bool,
                   deliveryIsPump: Bool) -> RunGuide {
    let sport = SPORTS.first { $0.id == sportId } ?? SPORTS[0]
    let highIntensity = sport.met >= 8

    // ── 2. Match advice to run duration ──
    let band: String, bandDetail: String
    if durationMin < 45 { band = "Easy"; bandDetail = "Under 45 min · aim to finish without eating" }
    else if durationMin <= 90 { band = "Moderate"; bandDetail = "45–90 min · one top-up at most" }
    else { band = "Long"; bandDetail = "Over 90 min · fuel for performance" }

    // ── 3. Start decision from glucose + trend (not fixed numbers) ──
    var status: StartStatus = .unknown
    var title = "Check your glucose first"
    var reason = "No live CGM / Nightscout reading — head out only when you can see your glucose and trend."
    if let g = glucoseMgdl, g > 0 {
        let gi = Int(g.rounded())
        let highIOB = iob > 1.2
        if g < 70 {
            status = .stop; title = "Treat first — don't start"
            reason = "You're low (\(gi) mg/dL). Treat, and wait until you've recovered before heading out."
        } else if g < 90 {
            status = .wait; title = "Top up ~15 g and wait"
            reason = "\(gi) mg/dL is below the safe start zone — take ~15 g and re-check before you go."
        } else if g < 126 {
            if trendFalling {
                status = .topUp; title = "Top up ~10–15 g first"
                reason = "\(gi) and falling — a little carb now heads off an early drop."
            } else if recentCarbsG >= 30 {
                status = .go; title = "Likely OK to start"
                reason = "\(gi) with ~\(recentCarbsG) g eaten recently — those carbs should lift you. Start and watch your trend."
            } else {
                status = .topUp; title = "Small top-up, then go"
                reason = "\(gi) is on the low side — ~10 g, or start and watch your trend closely."
            }
        } else if g <= 180 {
            if trendFalling {
                status = .topUp; title = "Top up ~10 g first"
                reason = "\(gi) but drifting down — a small carb steadies the start."
            } else if highIOB {
                status = .topUp; title = "Consider ~10 g — insulin on board"
                reason = "\(gi) is fine, but \(String(format: "%.1f", iob)) U on board will keep pulling you down."
            } else {
                status = .go; title = "Good to start"
                reason = "\(gi) mg/dL is right in the sweet spot — head out."
            }
        } else if g <= 250 {
            status = .go; title = "Good to start"
            reason = "\(gi) is a little high; easy exercise usually brings it down. No carbs needed."
        } else {
            status = .wait; title = "Check ketones first"
            reason = "\(gi) is high — if it's unexpected, check ketones and don't run if they're raised. Otherwise start gently."
        }
    }

    // ── 1. Prevent rather than treat (insulin-first; strategy only, no doses) ──
    let before: String
    if deliveryIsPump {
        before = "Prevent rather than treat. The most reliable lever is easing insulin ahead of time — a pump basal reduction 60–90 min before, or a smaller bolus if you ate recently. The amount is personal; set it with your clinician. Aim to start around 140–180 mg/dL and carry fast carbs for safety, not as a plan."
    } else {
        before = "Prevent rather than treat. On injections the main lever is a smaller meal bolus if you're running within ~2–3 h of eating (basal is hard to change mid-day). The amount is personal; set it with your clinician. Aim to start around 140–180 mg/dL and carry fast carbs for safety, not as a plan."
    }

    // During — matched to the band
    let during: String
    var duringHeadline: String? = nil
    switch band {
    case "Easy":
        during = "Aim to finish without eating. Carry fast-acting carbs and take 10–15 g only if you fall toward your target or your CGM arrow shows a rapid drop."
    case "Moderate":
        during = "Plan for one top-up at most: ~10–20 g around 30–45 min, and only if you're trending down. Easing insulin beforehand beats repeated gels."
    default:
        duringHeadline = highIntensity ? "~60–90 g/h" : "~30–60 g/h"
        during = "Now carbohydrate is performance fuel, not just hypo cover: aim \(highIntensity ? "60–90" : "30–60") g/h, spread through the run with insulin adjusted. This is where the EXTOD / consensus feeding rates genuinely apply."
    }

    // ── 4 & 5. Accept imperfect glucose; learn progressively ──
    let philosophy = "Most runners feel best around 140–200 mg/dL during exercise. Avoiding lows matters more than perfect numbers — chasing 100–140 usually means repeated gels and rebound highs."
    let learn = "Learn your own response: note your start glucose, insulin on board, any carbs, and your end glucose. After 3–5 similar runs you'll usually settle on a repeatable strategy."

    return RunGuide(band: band, bandDetail: bandDetail, status: status, startTitle: title,
                    startReason: reason, beforeText: before, duringText: during,
                    duringHeadline: duringHeadline, philosophyText: philosophy, learnText: learn,
                    deliveryIsPump: deliveryIsPump, usedGlucose: glucoseMgdl)
}
