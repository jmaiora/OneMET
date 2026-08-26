import Foundation

// PlanModel.swift — sport catalog + carb-planning heuristic (Plan tab).
// Ported from the v2 design handoff (data.jsx: SPORTS, computeCarbPlan).

/// A sport catalogue entry. Name and description are looked up from `id` at display
/// time rather than stored, so switching language re-renders them with no state to sync.
struct Sport: Identifiable, Hashable {
    let id: String
    let met: Double
    let icon: String
    let difficulty: WorkoutDifficulty
    let color: String       // hex

    func name(_ lang: AppLanguage) -> String { lang.t("sport.\(id)") }
    func desc(_ lang: AppLanguage) -> String { lang.t("sport.\(id).desc") }
}

let SPORTS: [Sport] = [
    Sport(id: "walk",     met: 3.2,  icon: "shoe",     difficulty: .light,    color: "#1F8A5B"),
    Sport(id: "run",      met: 9.1,  icon: "run",      difficulty: .vigorous, color: "#E0556E"),
    Sport(id: "cycling",  met: 7.0,  icon: "bike",     difficulty: .moderate, color: "#E8833A"),
    Sport(id: "swim",     met: 8.0,  icon: "drop",     difficulty: .vigorous, color: "#1FB8C9"),
    Sport(id: "strength", met: 5.0,  icon: "flame",    difficulty: .moderate, color: "#8E72E8"),
    Sport(id: "hiit",     met: 10.0, icon: "activity", difficulty: .vigorous, color: "#D6484B")
]

// Prevention-first exercise guide. Rather than "eat X g every 20 min", it favours
// adjusting insulin beforehand and minimising interventions during the run — matched
// to run duration and driven by glucose trend, not fixed numbers. Grounded in the 2017
// Lancet consensus (Riddell et al.) and EXTOD, but oriented to recreational practice.
// Illustrative guidance, NOT medical advice.

// Generic "before workout" strategy — the insulin-first principle. Depends only on
// the user's insulin-delivery method (a Profile setting), not on any live session
// input, so it can be shown as a standalone summary on the Summary tab.
func beforeWorkoutSummary(deliveryIsPump: Bool, unit: GlucoseUnit = .mgdl,
                          lang: AppLanguage = .en) -> String {
    lang.t(deliveryIsPump ? "before.pump" : "before.mdi", unit.range(140, 180))
}

enum StartStatus { case go, topUp, wait, stop, unknown }

enum WorkoutDifficulty: String, CaseIterable, Identifiable, Hashable {
    // Raw values are stable ids, never shown; use label(_:) for display.
    case light, moderate, vigorous, maximal
    var id: String { rawValue }

    func label(_ lang: AppLanguage) -> String { lang.t("difficulty.\(rawValue)") }

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
    // The long-form "accept 140–200" and "learn your own response" copy used to live here.
    // It now belongs to Settings ▸ Help & FAQ, which looks the strings up directly, and
    // the Plan tab shows only the one-line version — so the guide no longer carries it.
    let deliveryIsPump: Bool
    let usedGlucose: Double?
}

func buildRunGuide(sportId: String, durationMin: Int, iob: Double,
                   glucoseMgdl: Double?, trendFalling: Bool, trendRising: Bool,
                   deliveryIsPump: Bool, difficulty: WorkoutDifficulty,
                   unit: GlucoseUnit = .mgdl, lang: AppLanguage = .en) -> RunGuide {
    // ── 2. Match advice to run duration ──
    let bandKey = durationMin < 45 ? "easy" : (durationMin <= 90 ? "moderate" : "long")
    let band = lang.t("band.\(bandKey)")
    let bandDetail = lang.t("band.\(bandKey).detail")

    // Insulin-on-board uplift: carbs stay as-is at ≤ 1 U, then rise a little above 1 U —
    // a small, bounded nudge (capped ~+25%) toward the Riddell/EXTOD high-IOB end, not a
    // raw proportional scale.
    let iobFactor = 1 + min(0.25, max(0, iob - 1) * 0.15)

    // Carbs to take before starting — the same value the During card shows "at start",
    // so the banner's top-up amount always matches the During section.
    let duringStartG = Int((Double(startCarbGrams(glucoseMgdl: glucoseMgdl, difficulty: difficulty)) * iobFactor).rounded())

    // ── 3. Start decision from glucose + trend; top-up grams = the During "at start" ──
    var status: StartStatus = .unknown
    var title = lang.t("start.unknown.title")
    var reason = lang.t("start.unknown.reason")
    if let g = glucoseMgdl, g > 0 {
        let gi = unit.value(g)              // bare number, for mid-sentence use
        let gAmount = unit.amount(g)        // number + unit, for sentence openings
        let grams = String(duringStartG)
        let highIOB = iob > 1.2
        if g < 70 {
            status = .stop
            title = lang.t("start.stop.title")
            reason = lang.t("start.stop.reason", gAmount)
        } else if g < 90 {
            status = .wait
            title = lang.t("start.wait.title", grams)
            reason = lang.t("start.wait.reason", gAmount, grams)
        } else if g < 126 {
            status = .topUp
            if trendFalling {
                title = lang.t("start.topUpFirst.title", grams)
                reason = lang.t("start.lowFalling.reason", gi, grams)
            } else {
                title = lang.t("start.lowThenGo.title", grams)
                reason = lang.t("start.lowThenGo.reason", gi, grams)
            }
        } else if g <= 180 {
            if trendFalling {
                status = .topUp
                title = lang.t("start.topUpFirst.title", grams)
                reason = lang.t("start.midFalling.reason", gi, grams)
            } else if highIOB {
                status = .topUp
                title = lang.t("start.highIob.title", grams)
                reason = lang.t("start.highIob.reason", gi, String(format: "%.1f", iob), grams)
            } else {
                status = .go
                title = lang.t("start.go.title")
                reason = lang.t("start.go.reason", gAmount)
            }
        } else if g <= 250 {
            status = .go
            title = lang.t("start.go.title")
            reason = lang.t("start.goHigh.reason", gi)
        } else {
            status = .wait
            title = lang.t("start.ketones.title")
            reason = lang.t("start.ketones.reason", gi)
        }
    }

    // ── 1. Prevent rather than treat (insulin-first; strategy only, no doses) ──
    let before = beforeWorkoutSummary(deliveryIsPump: deliveryIsPump, unit: unit, lang: lang)

    // During — Riddell/EXTOD carbohydrate fuelling, driven by the selected difficulty.
    // No cap: the feeding rate scales with effort and longer sessions get more feeds.
    // A recommended intake at the start, then refuels every 45 min.
    let feedIntervalMin = 45
    let duringPerHourG = Int((Double(difficulty.carbsPerHour) * iobFactor).rounded())
    let perFeedG = Int((Double(duringPerHourG) * Double(feedIntervalMin) / 60.0).rounded())
    let duringFeeds = duringPerHourG > 0 ? max(0, (durationMin - 1) / feedIntervalMin) : 0
    let duringTotalG = duringStartG + perFeedG * duringFeeds

    let during: String
    var duringHeadline: String? = nil
    if duringTotalG == 0 {
        during = lang.t("during.none")
    } else {
        duringHeadline = "~\(duringPerHourG) g/h"
        during = lang.t("during.some")
    }

    return RunGuide(band: band, bandDetail: bandDetail, status: status, startTitle: title,
                    startReason: reason, beforeText: before, duringText: during,
                    duringHeadline: duringHeadline, duringPerHourG: duringPerHourG, duringStartG: duringStartG,
                    duringPerFeedG: perFeedG, duringFeeds: duringFeeds,
                    duringTotalG: duringTotalG, duringIntervalMin: feedIntervalMin,
                    deliveryIsPump: deliveryIsPump, usedGlucose: glucoseMgdl)
}
