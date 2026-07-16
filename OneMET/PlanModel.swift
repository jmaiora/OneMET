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
        return "Prevent, don\u{2019}t treat: ease insulin ahead — a basal cut 60–90 min before or a smaller bolus if you ate recently. Start near 140–180 mg/dL, carry fast carbs."
    } else {
        return "Prevent, don\u{2019}t treat: your lever is a smaller meal bolus if you ate within ~2–3 h. Start near 140–180 mg/dL, carry fast carbs."
    }
}

enum StartStatus { case go, topUp, wait, stop, unknown }

enum WorkoutDifficulty: String, CaseIterable, Identifiable, Hashable {
    case light = "Light"
    case moderate = "Moderate"
    case vigorous = "Vigorous"
    case maximal = "Maximal"
    var id: String { rawValue }

    // Map a sport's inherent difficulty label to a fuelling level — used when the
    // user swipes to a different sport in the Plan tab (still manually overridable).
    init(sportDifficulty: String) {
        switch sportDifficulty.lowercased() {
        case "light":    self = .light
        case "moderate": self = .moderate
        case "vigorous": self = .vigorous
        case "maximal":  self = .maximal
        default:         self = .moderate
        }
    }

    // Riddell/EXTOD carbohydrate fuelling rate during exercise (grams per hour).
    var carbsPerHour: Int {
        switch self {
        case .light:    return 15
        case .moderate: return 30
        case .vigorous: return 45
        case .maximal:  return 60
        }
    }
    // Extra start carbs for harder efforts, added on top of the glucose-based base
    // (see startCarbGrams). Harder sessions drop glucose faster, so pre-fuel a little more.
    var startBumpG: Int {
        switch self {
        case .light:    return 0
        case .moderate: return 5
        case .vigorous: return 5
        case .maximal:  return 10
        }
    }
}

// Carbs to take at the start of a session — a glucose-based base (Riddell-style
// pre-exercise bands) plus a small bump for harder efforts. Returns 0 when glucose is
// already high (> 180), regardless of intensity. No live reading → assume in-range.
func startCarbGrams(glucoseMgdl: Double?, difficulty: WorkoutDifficulty) -> Int {
    let base: Int
    if let g = glucoseMgdl, g > 0 {
        if g < 90 { base = 20 }
        else if g < 126 { base = 15 }
        else if g <= 180 { base = 10 }
        else { base = 0 }
    } else {
        base = 10
    }
    guard base > 0 else { return 0 }
    return base + difficulty.startBumpG
}

struct RunGuide {
    let band: String                 // Easy / Moderate / Long
    let bandDetail: String
    let status: StartStatus
    let startTitle: String
    let startReason: String
    let beforeText: String           // insulin-first strategy (no doses)
    let duringText: String           // carb guidance matched to the band
    let duringHeadline: String?      // e.g. "~45 g/h" (nil when no fuelling)
    let duringPerHourG: Int          // Riddell fuelling rate (g/h)
    let duringStartG: Int            // recommended carbs at the start
    let duringPerFeedG: Int          // carbs per 45-min feed
    let duringFeeds: Int             // number of feeds across the session
    let duringTotalG: Int            // total carbs across the session (start + feeds)
    let duringIntervalMin: Int       // feed interval (minutes)
    let philosophyText: String       // accept 140–200, avoid hypo > perfect
    let learnText: String            // log & experiment
    let deliveryIsPump: Bool
    let usedGlucose: Double?
}

func buildRunGuide(sportId: String, durationMin: Int, iob: Double, recentCarbsG: Int,
                   glucoseMgdl: Double?, trendFalling: Bool, trendRising: Bool,
                   deliveryIsPump: Bool, difficulty: WorkoutDifficulty) -> RunGuide {
    // ── 2. Match advice to run duration ──
    let band: String, bandDetail: String
    if durationMin < 45 { band = "Easy"; bandDetail = "Under 45 min · aim to finish without eating" }
    else if durationMin <= 90 { band = "Moderate"; bandDetail = "45–90 min · fuel as needed" }
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

    // During — Riddell/EXTOD carbohydrate fuelling, driven by the selected difficulty.
    // No cap: the feeding rate scales with effort and longer sessions get more feeds.
    // A recommended intake at the start, then refuels every 45 min.
    let feedIntervalMin = 45
    let duringPerHourG = difficulty.carbsPerHour
    let duringStartG = startCarbGrams(glucoseMgdl: glucoseMgdl, difficulty: difficulty)
    let perFeedG = Int((Double(duringPerHourG) * Double(feedIntervalMin) / 60.0).rounded())
    let duringFeeds = duringPerHourG > 0 ? max(0, (durationMin - 1) / feedIntervalMin) : 0
    let duringTotalG = duringStartG + perFeedG * duringFeeds

    let during: String
    var duringHeadline: String? = nil
    if duringTotalG == 0 {
        during = "Short and easy enough to finish without eating. Carry ~15 g of fast carbs and use them only if you fall toward your target or your CGM arrow shows a rapid drop."
    } else {
        duringHeadline = "~\(duringPerHourG) g/h"
        during = "Fuel to the Riddell/EXTOD rate for \(difficulty.rawValue.lowercased()) effort — carbs taken with insulin adjusted rather than skipped. No cap: longer sessions simply add more feeds."
    }

    // ── 4 & 5. Accept imperfect glucose; learn progressively ──
    let philosophy = "Most runners feel best around 140–200 mg/dL during exercise. Avoiding lows matters more than perfect numbers — chasing 100–140 usually means repeated gels and rebound highs."
    let learn = "Learn your own response: note your start glucose, insulin on board, any carbs, and your end glucose. After 3–5 similar runs you'll usually settle on a repeatable strategy."

    return RunGuide(band: band, bandDetail: bandDetail, status: status, startTitle: title,
                    startReason: reason, beforeText: before, duringText: during,
                    duringHeadline: duringHeadline, duringPerHourG: duringPerHourG, duringStartG: duringStartG,
                    duringPerFeedG: perFeedG, duringFeeds: duringFeeds,
                    duringTotalG: duringTotalG, duringIntervalMin: feedIntervalMin,
                    philosophyText: philosophy, learnText: learn,
                    deliveryIsPump: deliveryIsPump, usedGlucose: glucoseMgdl)
}
