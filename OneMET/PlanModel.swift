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

// Generic "before workout" strategy — the insulin-first principle. Depends only on
// the user's insulin-delivery method (a Profile setting), not on any live session
// input, so it can be shown as a standalone summary on the Summary tab.
func beforeWorkoutSummary(deliveryIsPump: Bool) -> String {
    if deliveryIsPump {
        return "Prevent rather than treat: ease insulin ahead of time — a pump basal cut 60–90 min before, or a smaller bolus if you ate recently. Aim to start around 140–180 mg/dL and carry fast carbs for safety."
    } else {
        return "Prevent rather than treat: your main lever is a smaller meal bolus if you're running within ~2–3 h of eating. Aim to start around 140–180 mg/dL and carry fast carbs for safety."
    }
}

enum StartStatus { case go, topUp, wait, stop, unknown }

struct RunGuide {
    let band: String                 // Easy / Moderate / Long
    let bandDetail: String
    let status: StartStatus
    let startTitle: String
    let startReason: String
    let beforeText: String           // insulin-first strategy (no doses)
    let duringText: String           // carb guidance matched to the band
    let duringHeadline: String?      // e.g. "45 g every 45 min" (nil when no feeding)
    let duringPerFeedG: Int          // carbs per feed (0 = finish without eating)
    let duringFeeds: Int             // number of feeds across the session
    let duringTotalG: Int            // total carbs across the session
    let duringIntervalMin: Int       // feed interval (minutes)
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
    let before = beforeWorkoutSummary(deliveryIsPump: deliveryIsPump)

    // During — Riddell-style fuelling, computed per feed and capped for the hardest runs.
    // Rate scales with intensity/duration; the toughest sessions are held to 45 g every
    // 45 min (~60 g/h) — the top of the Riddell/EXTOD consensus range.
    let feedIntervalMin = 45
    let perFeedG: Int
    switch band {
    case "Easy":      perFeedG = 0
    case "Moderate":  perFeedG = highIntensity ? 30 : 20
    default:          perFeedG = highIntensity ? 45 : 30   // Long: hardest cap 45 g / 45 min
    }
    let duringFeeds = perFeedG > 0 ? max(0, (durationMin - 1) / feedIntervalMin) : 0
    let duringTotalG = perFeedG * duringFeeds
    let gPerHour = feedIntervalMin > 0 ? perFeedG * 60 / feedIntervalMin : 0

    let during: String
    var duringHeadline: String? = nil
    if perFeedG == 0 || duringFeeds == 0 {
        during = "Aim to finish without eating. Carry ~15 g of fast carbs and take them only if you fall toward your target or your CGM arrow shows a rapid drop."
    } else if band == "Moderate" {
        duringHeadline = "\(perFeedG) g every \(feedIntervalMin) min"
        during = "A Riddell-style top-up: about \(perFeedG) g at the \(feedIntervalMin)-min mark (~\(duringTotalG) g total) if you're trending down. Easing insulin beforehand beats repeated gels."
    } else {
        duringHeadline = "\(perFeedG) g every \(feedIntervalMin) min"
        let capNote = highIntensity
            ? "For the hardest sessions this is capped at 45 g every 45 min (~60 g/h) — the top of the Riddell/EXTOD consensus range — enough to fuel performance without GI upset."
            : "That works out to ~\(gPerHour) g/h, within the Riddell/EXTOD consensus range."
        during = "Fuel for performance: \(perFeedG) g every \(feedIntervalMin) min — about \(duringTotalG) g across \(duringFeeds) feeds, taken with insulin adjusted. \(capNote)"
    }

    // ── 4 & 5. Accept imperfect glucose; learn progressively ──
    let philosophy = "Most runners feel best around 140–200 mg/dL during exercise. Avoiding lows matters more than perfect numbers — chasing 100–140 usually means repeated gels and rebound highs."
    let learn = "Learn your own response: note your start glucose, insulin on board, any carbs, and your end glucose. After 3–5 similar runs you'll usually settle on a repeatable strategy."

    return RunGuide(band: band, bandDetail: bandDetail, status: status, startTitle: title,
                    startReason: reason, beforeText: before, duringText: during,
                    duringHeadline: duringHeadline, duringPerFeedG: perFeedG, duringFeeds: duringFeeds,
                    duringTotalG: duringTotalG, duringIntervalMin: feedIntervalMin,
                    philosophyText: philosophy, learnText: learn,
                    deliveryIsPump: deliveryIsPump, usedGlucose: glucoseMgdl)
}
