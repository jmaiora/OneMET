import Foundation

// PlanModel.swift — sport catalog + carb-planning heuristic (Plan tab).
// Ported from the v2 design handoff (data.jsx: SPORTS, computeCarbPlan).

/// A sport catalogue entry. Name and description are looked up from `id` at display
/// time rather than stored, so switching language re-renders them with no state to sync.
struct Sport: Identifiable, Hashable {
    let id: String
    /// Typical intensity, and the value the Plan tab's gauge starts at when you pick it.
    let met: Double
    let icon: String
    let color: String       // hex

    /// Derived from MET rather than stored, so a sport can't claim a band its own
    /// intensity contradicts — the old table had a 9.1 MET run labelled "moderate".
    var difficulty: WorkoutDifficulty { WorkoutDifficulty(met: met) }

    /// What kind of effort it is, which decides how glucose behaves — independent of MET.
    var kind: ExerciseKind { ExerciseKind(sportId: id) }

    func name(_ lang: AppLanguage) -> String { lang.t("sport.\(id)") }
    func desc(_ lang: AppLanguage) -> String { lang.t("sport.\(id).desc") }
}

let SPORTS: [Sport] = [
    Sport(id: "walk",     met: 3.2,  icon: "shoe",     color: "#1F8A5B"),
    Sport(id: "run",      met: 9.1,  icon: "run",      color: "#E0556E"),
    Sport(id: "cycling",  met: 7.0,  icon: "bike",     color: "#E8833A"),
    Sport(id: "swim",     met: 8.0,  icon: "drop",     color: "#1FB8C9"),
    Sport(id: "strength", met: 5.0,  icon: "flame",    color: "#8E72E8"),
    Sport(id: "hiit",     met: 10.0, icon: "activity", color: "#D6484B")
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

/// Aerobic work lowers glucose steadily; interval and resistance work lower it far less
/// and can raise it, through catecholamines and other counter-regulatory hormones
/// (Riddell 2017). In the real-world T1DEXI study the mean change during a session was
/// −18 mg/dL aerobic, −14 interval and −9 resistance. So the MET-band fuelling rates —
/// written for continuous aerobic exercise — don't apply to the last two.
enum ExerciseKind {
    case aerobic, interval, resistance

    /// Keyed on the stable sport / workout id, so the Plan tab and HealthKit workouts
    /// classify the same activity the same way.
    init(sportId: String) {
        switch sportId {
        case "strength": self = .resistance
        case "hiit":     self = .interval
        default:         self = .aerobic
        }
    }

    var isAnaerobic: Bool { self != .aerobic }
}

enum WorkoutDifficulty: String, CaseIterable, Identifiable, Hashable {
    // Raw values are stable ids, never shown; use label(_:) for display.
    case light, moderate, vigorous, maximal
    var id: String { rawValue }

    func label(_ lang: AppLanguage) -> String { lang.t("difficulty.\(rawValue)") }

    /// Band for a MET value, on the usual ACSM cut-points (light under 3, moderate to 6,
    /// vigorous to 10) with "maximal" reserved for the sprint/anaerobic end, which is the
    /// only place Riddell's 60 g/h rate belongs.
    init(met: Double) {
        switch met {
        case ..<3:    self = .light
        case ..<6:    self = .moderate
        case ..<10:   self = .vigorous
        default:      self = .maximal
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

/// Above this pre-exercise glucose no starting carbohydrate is given, whatever the
/// intensity. Shared with the retrospective insight, which must not advise eating
/// "before" a session the prospective model would have sent out unfuelled.
let preCarbCeilingMgdl: Double = 180

/// Default interval between mid-session feeds. A session no longer than this never earns
/// one, so there is no "during" to advise either. The fuel plan can use a shorter interval
/// (Settings ▸ Profile); it changes how the session's total is split, never the total.
let carbFeedIntervalMin = 45

/// Range the user may choose the feed interval from, in 5-minute steps.
let carbFeedIntervalRange = 20...45

/// Below this, the session's during-exercise total isn't worth scheduling (a 15-min walk
/// at 15 g/h would be ~4 g) — the rescue snack you carry covers it.
let minDuringFuelG = 5

/// One scheduled intake during the session.
struct FeedStop: Hashable {
    let minute: Int
    let grams: Int
}

// Carbs to take at the start of a session — a glucose-based base (Riddell-style
// pre-exercise bands) plus a small bump for harder efforts. Returns 0 when glucose is
// already high, regardless of intensity. No live reading → assume in-range.
func startCarbGrams(glucoseMgdl: Double?, difficulty: WorkoutDifficulty,
                    kind: ExerciseKind = .aerobic) -> Int {
    let base: Int
    if let g = glucoseMgdl, g > 0 {
        if g < 90 { base = 20 }
        else if g < 126 { base = 15 }
        else if g <= preCarbCeilingMgdl { base = 10 }
        else { base = 0 }
    } else {
        base = 10
    }
    guard base > 0 else { return 0 }
    // The intensity bump exists because harder aerobic work drops glucose faster; harder
    // interval or resistance work doesn't, so those keep only the glucose-based base.
    return base + (kind.isAnaerobic ? 0 : difficulty.startBumpG)
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
    let duringSchedule: [FeedStop]   // intakes during the session, in order
    let duringTotalG: Int            // total carbs across the session (start + intakes)
    let duringIntervalMin: Int       // feed interval (minutes)
    // The long-form "accept 140–200" and "learn your own response" copy used to live here.
    // It now belongs to Settings ▸ Help & FAQ, which looks the strings up directly, and
    // the Plan tab shows only the one-line version — so the guide no longer carries it.
    let deliveryIsPump: Bool
    let usedGlucose: Double?
    /// Interval / resistance only: what to expect afterwards (possible rise, conservative
    /// corrections, delayed low). nil for aerobic.
    let afterText: String?
}

func buildRunGuide(sportId: String, durationMin: Int, iob: Double,
                   glucoseMgdl: Double?, trendFalling: Bool, trendRising: Bool,
                   deliveryIsPump: Bool, difficulty: WorkoutDifficulty,
                   feedIntervalMin: Int = carbFeedIntervalMin,
                   kind: ExerciseKind = .aerobic,
                   unit: GlucoseUnit = .mgdl, lang: AppLanguage = .en) -> RunGuide {
    // ── 2. Match advice to run duration ──
    let bandKey = durationMin < 45 ? "easy" : (durationMin <= 90 ? "moderate" : "long")
    let band = lang.t("band.\(bandKey)")
    // Duration bands speak in fuelling terms ("fuel for performance") that only hold for
    // aerobic work; interval and resistance sessions get their own line instead.
    let bandDetail = kind.isAnaerobic ? lang.t("band.anaerobic.detail")
                                      : lang.t("band.\(bandKey).detail")

    // Insulin-on-board uplift: carbs stay as-is at ≤ 1 U, then rise a little above 1 U —
    // a small, bounded nudge (capped ~+25%) toward the Riddell/EXTOD high-IOB end, not a
    // raw proportional scale.
    let iobFactor = 1 + min(0.25, max(0, iob - 1) * 0.15)

    // Carbs to take before starting — the same value the During card shows "at start",
    // so the banner's top-up amount always matches the During section.
    let duringStartG = Int((Double(startCarbGrams(glucoseMgdl: glucoseMgdl, difficulty: difficulty,
                                                  kind: kind)) * iobFactor).rounded())

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
    // The consensus gives a rate per hour of exercise and says nothing about spacing, so
    // the session total is rate × full duration and the interval only decides how it's
    // split: intakes at every interval mark before the end, sharing the total evenly.
    // (Earlier versions fed one interval at a time from the first mark, which left the
    // first interval unfuelled and overshot the end — so a 20-min interval gave a 90-min
    // run 60 g where a 45-min interval gave 34 g.) The start carbs are separate: they're
    // set by glucose at the start, not by the hourly rate.
    let feedIntervalMin = min(max(feedIntervalMin, carbFeedIntervalRange.lowerBound),
                              carbFeedIntervalRange.upperBound)
    // Interval and resistance work: nothing scheduled. The consensus notes carbohydrate
    // may not be needed, and glucose falls least in these sessions (T1DEXI); a rescue
    // snack is carried instead, used only on a real fall.
    let duringPerHourG = kind.isAnaerobic ? 0
        : Int((Double(difficulty.carbsPerHour) * iobFactor).rounded())
    let schedule = duringFeedSchedule(perHourG: duringPerHourG, durationMin: durationMin,
                                      intervalMin: feedIntervalMin)
    let duringTotalG = duringStartG + schedule.reduce(0) { $0 + $1.grams }

    let during: String
    var duringHeadline: String? = nil
    if kind.isAnaerobic {
        during = lang.t(kind == .resistance ? "during.resistance" : "during.interval")
    } else if duringTotalG == 0 {
        during = lang.t("during.none")
    } else {
        duringHeadline = "~\(duringPerHourG) g/h"
        during = lang.t("during.some")
    }

    return RunGuide(band: band, bandDetail: bandDetail, status: status, startTitle: title,
                    startReason: reason, beforeText: before, duringText: during,
                    duringHeadline: duringHeadline, duringPerHourG: duringPerHourG, duringStartG: duringStartG,
                    duringSchedule: schedule,
                    duringTotalG: duringTotalG, duringIntervalMin: feedIntervalMin,
                    deliveryIsPump: deliveryIsPump, usedGlucose: glucoseMgdl,
                    afterText: kind.isAnaerobic ? lang.t("after.anaerobic") : nil)
}

/// Splits rate × duration into intakes at each interval mark strictly before the end,
/// as evenly as whole grams allow (any remainder goes to the earliest intakes). A session
/// shorter than one interval gets a single intake halfway through.
func duringFeedSchedule(perHourG: Int, durationMin: Int, intervalMin: Int) -> [FeedStop] {
    guard perHourG > 0, durationMin > 0, intervalMin > 0 else { return [] }
    let total = Int((Double(perHourG) * Double(durationMin) / 60).rounded())
    guard total >= minDuringFuelG else { return [] }

    var marks = Array(stride(from: intervalMin, to: durationMin, by: intervalMin))
    if marks.isEmpty {
        marks = [max(5, Int((Double(durationMin) / 2 / 5).rounded()) * 5)]
    }
    let base = total / marks.count, extra = total % marks.count
    return marks.enumerated().map { i, m in
        FeedStop(minute: m, grams: base + (i < extra ? 1 : 0))
    }
}
