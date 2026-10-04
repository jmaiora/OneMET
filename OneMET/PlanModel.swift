import Foundation

// PlanModel.swift — sport catalogue + the exercise fuel plan (Plan tab).
//
// The guidance is built from two consensus documents. Both grade their recommendations as
// evidence level D (expert opinion over small, mostly adult studies), so every number here
// is a starting point to personalise, not a validated algorithm:
//
//   • EASD/ISPAD 2020 — Moser O, Riddell MC, et al. Glucose management for exercise using
//     CGM and isCGM systems in type 1 diabetes. Diabetologia 2020;63:2501–2520.
//     Adult tables for before (Table 1), during (Table 2) and after (Table 3) exercise, by
//     sensor glucose, trend arrow, whether glucose is expected to fall or rise, and a
//     hypoglycaemia-risk group (Fig. 2).
//   • ISPAD 2022 — Adolfsson P, Taplin CE, Zaharieva DP, et al. Exercise in children and
//     adolescents with diabetes. Pediatr Diabetes 2022;23:1341–1372.
//     Exercise types (Table 1), carbohydrate rates by circulating insulin (§7.3), per-check
//     adjustments by glucose and arrow (Table 5), the ~1 g/min absorption limit and the
//     bedtime snack (§7.5). A paediatric guideline, but these parts rest on adult data.
//
// Neither table set was written for hybrid closed-loop systems. No insulin doses are
// computed anywhere — insulin advice stays strategy-only, to agree with the clinician.
// Illustrative guidance, NOT medical advice.

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

// Generic "before workout" strategy — the insulin-first principle. Depends only on
// the user's insulin-delivery method (a Profile setting), not on any live session
// input, so it can be shown as a standalone summary on the Summary tab.
func beforeWorkoutSummary(deliveryIsPump: Bool, unit: GlucoseUnit = .mgdl,
                          lang: AppLanguage = .en) -> String {
    lang.t(deliveryIsPump ? "before.pump" : "before.mdi", unit.range(140, 180))
}

enum StartStatus { case go, topUp, wait, stop, unknown }

// MARK: - Exercise type

/// ISPAD 2022 Table 1: continuous aerobic work lowers glucose; mixed work with anaerobic
/// bursts (resistance, circuits, intervals) and anaerobic work blunt the fall or raise
/// glucose. In the real-world T1DEXI study the mean change during a session was −18 mg/dL
/// aerobic, −14 interval and −9 resistance.
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

    /// Which column of the EASD tables applies.
    var expectation: GlucoseExpectation { isAnaerobic ? .staysOrRises : .falls }
}

/// The two action columns of the EASD/ISPAD tables: "decrease in sensor glucose expected"
/// and "increase in sensor glucose expected".
enum GlucoseExpectation { case falls, staysOrRises }

enum WorkoutDifficulty: String, CaseIterable, Identifiable, Hashable {
    // Raw values are stable ids, never shown; use label(_:) for display.
    case light, moderate, vigorous, maximal
    var id: String { rawValue }

    func label(_ lang: AppLanguage) -> String { lang.t("difficulty.\(rawValue)") }

    /// Band for a MET value, on the usual ACSM cut-points (light under 3, moderate to 6,
    /// vigorous to 10), with "maximal" for the sprint end.
    init(met: Double) {
        switch met {
        case ..<3:    self = .light
        case ..<6:    self = .moderate
        case ..<10:   self = .vigorous
        default:      self = .maximal
        }
    }

    /// Where in ISPAD's carbohydrate-rate range this intensity sits: 0 = low end,
    /// 1 = high end. The app's mapping; ISPAD gives the ranges, not the position.
    var ratePosition: Double {
        switch self {
        case .light:              return 0
        case .moderate:           return 0.5
        case .vigorous, .maximal: return 1
        }
    }
}

// MARK: - Trend arrow

/// Generic CGM trend arrow as the EASD/ISPAD statement defines it from the change over
/// 15 min: under 15 mg/dL flat, 15–30 slanted, over 30 vertical (ISPAD 2022 Table 7).
enum GlucoseArrow: Int, CaseIterable {
    case risingFast, rising, flat, falling, fallingFast     // display order ↑ ↗ → ↘ ↓

    init(per15Min r: Double) {
        if r >= 30 { self = .risingFast }
        else if r >= 15 { self = .rising }
        else if r > -15 { self = .flat }
        else if r > -30 { self = .falling }
        else { self = .fallingFast }
    }

    var symbol: String {
        switch self {
        case .risingFast:  return "arrow.up"
        case .rising:      return "arrow.up.right"
        case .flat:        return "arrow.right"
        case .falling:     return "arrow.down.right"
        case .fallingFast: return "arrow.down"
        }
    }

    var isFalling: Bool { self == .falling || self == .fallingFast }
    var isRising: Bool { self == .rising || self == .risingFast }
}

// MARK: - Hypoglycaemia-risk group (EASD 2020 Fig. 2)

/// EASD's three groups. Ex2 = intensively exercising and/or low risk of hypoglycaemia,
/// Ex1 = moderately exercising and/or moderate risk, Ex0 = minimally exercising and/or
/// high risk. The group moves every glucose threshold in the tables.
enum RiskGroup: String, CaseIterable {
    case low, moderate, high          // Ex2, Ex1, Ex0

    func label(_ lang: AppLanguage) -> String { lang.t("risk.\(rawValue)") }

    /// During exercise, carbohydrate is taken below this (Table 2): 7.0 / 8.0 / 9.0 mmol/L.
    /// It is also the bottom of the pre-exercise target (Table 1).
    var duringThreshold: Double {
        switch self { case .low: return 126; case .moderate: return 145; case .high: return 162 }
    }
    /// Top of the pre-exercise target (Table 1): 10.0 / 11.0 / 12.0 mmol/L.
    var targetTop: Double {
        switch self { case .low: return 180; case .moderate: return 198; case .high: return 216 }
    }
    /// After exercise, carbohydrate is taken below this (Table 3): 4.4 / 5.0 / 5.6 mmol/L.
    var afterThreshold: Double {
        switch self { case .low: return 80; case .moderate: return 90; case .high: return 100 }
    }

    /// The more cautious of two groups.
    func moreCautious(_ other: RiskGroup) -> RiskGroup {
        let order: [RiskGroup] = [.low, .moderate, .high]
        return order.firstIndex(of: self)! >= order.firstIndex(of: other)! ? self : other
    }
}

/// Profile setting: work the group out, or pin one.
enum RiskGroupSetting: String, Codable, CaseIterable {
    case automatic, low, moderate, high

    func label(_ lang: AppLanguage) -> String {
        self == .automatic ? lang.t("risk.auto") : lang.t("risk.\(rawValue)")
    }
    var pinned: RiskGroup? { RiskGroup(rawValue: rawValue) }
}

struct RiskAssessment: Equatable {
    let group: RiskGroup
    /// Inputs, kept so Settings can show where an automatic result came from.
    let sessionsPerWeek: Double?
    let tbrPct: Double?
    let isPinned: Bool

    static let unknown = RiskAssessment(group: .low, sessionsPerWeek: nil, tbrPct: nil, isPinned: false)
}

/// EASD Fig. 2. Exercise routine: sessions of ≥ 45 min per week — none → Ex0, 1–2 → Ex1,
/// more than 2 → Ex2 (averaged over 4 weeks, so "none" means fewer than one every two
/// weeks). Hypoglycaemia risk: impaired awareness or a severe low in the last 6 months →
/// high; otherwise time below 70 mg/dL — under 4 % low, 4–8 % moderate, over 8 % high.
/// EASD reads TBR over 3 months; the app has 14 days, the standard CGM report window.
/// The group is the more cautious of the two ("and/or" in the figure).
func assessRiskGroup(sessionsPerWeek: Double?, tbrPct: Double?,
                     unaware: Bool, severeHypo: Bool,
                     setting: RiskGroupSetting) -> RiskAssessment {
    if let pinned = setting.pinned {
        return RiskAssessment(group: pinned, sessionsPerWeek: sessionsPerWeek, tbrPct: tbrPct, isPinned: true)
    }
    let fromExercise: RiskGroup
    switch sessionsPerWeek ?? 0 {
    case ..<0.5: fromExercise = .high
    case ...2:   fromExercise = .moderate
    default:     fromExercise = .low
    }
    let fromRisk: RiskGroup
    if unaware || severeHypo { fromRisk = .high }
    else if let t = tbrPct { fromRisk = t > 8 ? .high : (t >= 4 ? .moderate : .low) }
    else { fromRisk = .low }       // no CGM history: rely on the two profile answers
    return RiskAssessment(group: fromExercise.moreCautious(fromRisk),
                          sessionsPerWeek: sessionsPerWeek, tbrPct: tbrPct, isPinned: false)
}

// MARK: - Constants

/// Interval between planned intakes: the values the user can pick (fuel-plan slider, and
/// the default in Settings ▸ Profile). It decides how the session total is split, never
/// the total. Checking the sensor more often is always fine.
let carbFeedIntervalOptions = [30, 45, 60]
let carbFeedIntervalMin = 45

/// Largest single planned intake ("snack size"): the values the fuel-plan slider offers.
/// Not a published limit — 20–45 g spans a small gel to a large one or two.
let intakeCapOptions = [20, 30, 45]
let defaultIntakeCapG = 30

/// Snap a stored or passed value to the nearest allowed option.
func nearestOption(_ value: Int, in options: [Int]) -> Int {
    options.min(by: { abs($0 - value) < abs($1 - value) }) ?? value
}

/// Sessions shorter than this never get a planned intake in the retrospective insight's
/// eyes: even the lightest planned rate gives under `minDuringFuelG` there.
let minFedSessionMin = 20

/// Below this, the session's during-exercise total isn't worth scheduling — the rescue
/// carbohydrate you carry covers it.
let minDuringFuelG = 5

/// ISPAD 2022: the upper limit of gut glucose absorption is about 1.0 g/min, so planned
/// fuelling never exceeds 60 g/h.
let maxFuelGPerH = 60.0

/// Extra to carry for a fast drop: EASD Table 2's largest single amount — ~35 g when
/// glucose is expected to fall, ~20 g when it is expected to stay or rise.
let maxSingleCorrectionG = 35

/// Glucose distribution volume, ~0.2 L/kg (extracellular fluid). Physiology estimate used
/// to turn a high starting glucose into grams — not guideline text.
let glucoseDistributionLPerKg = 0.2

/// No usable weight anywhere → plan for 70 kg and say so.
let defaultPlanWeightKg = 70.0

/// One scheduled intake during the session.
struct FeedStop: Hashable {
    let minute: Int
    let grams: Int
}

// MARK: - Before (EASD 2020 Table 1, adults)

struct StartDecision {
    let status: StartStatus
    let grams: Int            // ~g before starting (0 = none)
    let individual: Bool      // treat as a low: EASD's "individual amount"
    let title: String
    let reason: String
}

/// EASD Table 1 for adults. Bands move with the risk group: the target is
/// `duringThreshold…targetTop`, the low band 90 up to the target, the high band the target
/// top to 270. Amounts are the table's (~10–35 g); "delay" rows wait until glucose is at
/// least 90 with a steady or rising arrow (or rising quickly, for the 70–89 rows of the
/// rise-expected column).
func preExerciseDecision(glucoseMgdl: Double?, arrow: GlucoseArrow?,
                         expectation: GlucoseExpectation, group: RiskGroup,
                         unit: GlucoseUnit, lang: AppLanguage) -> StartDecision {
    guard let g = glucoseMgdl, g > 0 else {
        return StartDecision(status: .unknown, grams: 0, individual: false,
                             title: lang.t("start.unknown.title"), reason: lang.t("start.unknown.reason"))
    }
    let a = arrow ?? .flat
    let falls = expectation == .falls
    let amount = unit.amount(g)
    let target = unit.range(group.duringThreshold, group.targetTop)
    let untilSteady = lang.t("start.until90", unit.amount(90))
    let untilRising = lang.t("start.untilRising")

    func go(_ reason: String) -> StartDecision {
        StartDecision(status: .go, grams: 0, individual: false, title: lang.t("start.go.title"),
                      reason: reason)
    }
    func topUp(_ grams: Int, _ reason: String) -> StartDecision {
        StartDecision(status: .topUp, grams: grams, individual: false,
                      title: lang.t("start.topUp.title", String(grams)), reason: reason)
    }
    func wait(_ grams: Int, until: String) -> StartDecision {
        StartDecision(status: .wait, grams: grams, individual: false,
                      title: lang.t("start.wait.title", String(grams)),
                      reason: lang.t("start.wait.reason", amount, String(grams), until))
    }
    func treat(until: String) -> StartDecision {
        StartDecision(status: .stop, grams: 0, individual: true, title: lang.t("start.treat.title"),
                      reason: lang.t("start.treat.reason", amount, until))
    }

    if g > 270 {
        // Ketones > 1.5 mmol/L: no exercise. Otherwise, with glucose steady or rising and
        // a rise expected, the table allows aerobic exercise only.
        let key = (!falls && !a.isFalling) ? "start.ketones.reasonRise" : "start.ketones.reason"
        return StartDecision(status: .wait, grams: 0, individual: false,
                             title: lang.t("start.ketones.title"), reason: lang.t(key, amount))
    }
    if g > group.targetTop {
        return (!falls && a.isRising) ? go(lang.t("start.highRising.reason", amount))
                                      : go(lang.t("start.high.reason", amount, target))
    }
    if g >= group.duringThreshold {
        if a.isFalling && falls {
            return topUp(15, lang.t("start.targetFalling.reason", amount, "15"))
        }
        return go(lang.t("start.go.reason", amount, target))
    }
    if g >= 90 {
        switch a {
        case .risingFast, .rising:
            return falls ? topUp(15, lang.t("start.low.reason", amount, target, "15"))
                         : go(lang.t("start.lowRising.reason", amount))
        case .flat:
            let gr = falls ? 20 : 10
            return topUp(gr, lang.t("start.low.reason", amount, target, String(gr)))
        case .falling:     return wait(falls ? 25 : 15, until: untilSteady)
        case .fallingFast: return wait(falls ? 30 : 20, until: untilSteady)
        }
    }
    if g >= 70 {
        if a == .fallingFast { return treat(until: falls ? untilSteady : untilRising) }
        if falls {
            switch a {
            case .risingFast: return wait(20, until: untilSteady)
            case .rising:     return wait(25, until: untilSteady)
            case .flat:       return wait(30, until: untilSteady)
            default:          return wait(35, until: untilSteady)
            }
        }
        switch a {
        case .risingFast: return topUp(10, lang.t("start.low.reason", amount, target, "10"))
        case .rising:     return wait(15, until: untilRising)
        case .flat:       return wait(20, until: untilRising)
        default:          return wait(25, until: untilRising)
        }
    }
    return StartDecision(status: .stop, grams: 0, individual: true, title: lang.t("start.stop.title"),
                         reason: lang.t("start.stop.reason", amount, falls ? untilSteady : untilRising))
}

// MARK: - During: planned rate (ISPAD 2022 §7.3)

/// ISPAD 2022 §7.3: ~0.3–0.5 g/kg/h when only basal insulin is active (> 2 h since the last
/// bolus), ~0.5–1.0 g/kg/h with high circulating bolus insulin. Insulin on board picks the
/// range — ≤ 0.5 U basal-only, ≥ 1.5 U high bolus, linear in between — and intensity
/// picks the point inside it. Both mappings are the app's; the ranges are ISPAD's.
func ispadCarbRate(iob: Double, difficulty: WorkoutDifficulty) -> Double {
    let p = difficulty.ratePosition
    let basalOnly = 0.3 + 0.2 * p
    let highBolus = 0.5 + 0.5 * p
    let s = min(1, max(0, (iob - 0.5) / 1.0))
    return basalOnly + (highBolus - basalOnly) * s
}

/// Intakes at each interval mark strictly before the end, sharing `totalG` as evenly as
/// whole grams allow (remainder to the earliest). Marks inside the first `coveredMin`
/// — time a high starting glucose already pays for — are dropped. If no mark is left, a
/// single intake goes halfway through the uncovered part.
func planFeedSchedule(totalG: Int, durationMin: Int, intervalMin: Int,
                      coveredMin: Double) -> [FeedStop] {
    guard totalG >= minDuringFuelG, durationMin > 0, intervalMin > 0 else { return [] }
    var marks = Array(stride(from: intervalMin, to: durationMin, by: intervalMin))
        .filter { Double($0) > coveredMin }
    if marks.isEmpty {
        let from = min(Double(durationMin), max(0, coveredMin))
        let mid = Int(((from + Double(durationMin)) / 2 / 5).rounded()) * 5
        marks = [min(max(5, mid), max(5, durationMin - 5))]
    }
    let base = totalG / marks.count, extra = totalG % marks.count
    return marks.enumerated().map { i, m in FeedStop(minute: m, grams: base + (i < extra ? 1 : 0)) }
}

// MARK: - After (EASD 2020 Table 3, ISPAD 2022 §7.5)

struct AfterPlan {
    /// Below this in the 90 min after, take carbs by arrow: ↑↗ none, → ~10 g, ↘ ~15 g,
    /// ↓ treat as a low.
    let threshold: Double
    /// Overnight CGM low alert (EASD: 80 mg/dL, higher with elevated risk).
    let nightAlert: Double
    /// ISPAD: after exercise ending after 4 pm and lasting ≥ 30 min, a bedtime snack of
    /// 0.4 g/kg low–medium GI carbohydrate without bolus if glucose is under 180;
    /// add ~15 g protein under 126.
    let bedtimeSnackG: Int
}

// MARK: - The plan

struct RunGuide {
    let bandDetail: String
    let group: RiskGroup
    let expectation: GlucoseExpectation
    let status: StartStatus
    let startTitle: String
    let startReason: String
    let duringText: String           // source line under the timeline / no-plan text
    let ratePerKg: Double            // ISPAD g/kg/h used (0 when nothing is planned)
    let duringPerHourG: Int          // planned fuelling rate (g/h)
    let duringStartG: Int            // carbs before starting, from Table 1
    let intakeCapG: Int              // largest planned intake (slider)
    let startIndividual: Bool        // start is "treat as a low" — no number to show
    let duringSchedule: [FeedStop]   // planned intakes during the session, in order
    let startMovedG: Int             // intake excess over the cap moved to the start
    let duringTotalG: Int            // start + intakes
    let duringIntervalMin: Int
    let startAboveTarget: Bool       // intakes are conditional: "if under the target top"
    let excessG: Int                 // starting glucose above the target top, as grams
    let coveredMin: Int              // minutes of planned fuel that excess pays for
    let carryRescueG: Int            // extra to carry for a fast drop (Table 2, ↓)
    let after: AfterPlan
    let afterText: String?           // interval / resistance only: possible rise, etc.
    let weightKg: Double
    let weightIsDefault: Bool
    let usedGlucose: Double?

    /// Everything to pack: the plan plus the rescue amount.
    var carryG: Int { duringTotalG + carryRescueG }
}

func buildRunGuide(sportId: String, durationMin: Int, iob: Double,
                   glucoseMgdl: Double?, arrow: GlucoseArrow?,
                   difficulty: WorkoutDifficulty,
                   feedIntervalMin: Int = carbFeedIntervalMin,
                   intakeCapG: Int = defaultIntakeCapG,
                   kind: ExerciseKind = .aerobic,
                   group: RiskGroup = .low,
                   weightKg: Double? = nil,
                   unit: GlucoseUnit = .mgdl, lang: AppLanguage = .en) -> RunGuide {
    let expectation = kind.expectation
    let weight = weightKg ?? defaultPlanWeightKg

    // Duration bands speak in fuelling terms that only hold for aerobic work; interval and
    // resistance sessions get their own line instead.
    let bandKey = durationMin < 45 ? "easy" : (durationMin <= 90 ? "moderate" : "long")
    let bandDetail = kind.isAnaerobic ? lang.t("band.anaerobic.detail")
                                      : lang.t("band.\(bandKey).detail")

    // ── Before ──
    let decision = preExerciseDecision(glucoseMgdl: glucoseMgdl, arrow: arrow,
                                       expectation: expectation, group: group,
                                       unit: unit, lang: lang)

    // ── During: planned intakes ──
    let interval = nearestOption(feedIntervalMin, in: carbFeedIntervalOptions)
    let cap = nearestOption(intakeCapG, in: intakeCapOptions)
    // Interval and resistance work: nothing planned (ISPAD Table 1 / EASD rise column);
    // the CGM table covers a real fall.
    let ratePerKg = kind.isAnaerobic ? 0 : ispadCarbRate(iob: iob, difficulty: difficulty)
    let perHour = min(maxFuelGPerH, ratePerKg * weight)

    // A start above the target top pays for the first part of the session: glucose the
    // body burns before planned intakes are needed (ISPAD Table 5 gives nothing above the
    // target while steady).
    var excessG = 0.0
    if let g = glucoseMgdl, g > group.targetTop, perHour > 0 {
        excessG = (g - group.targetTop) / 100 * glucoseDistributionLPerKg * weight
    }
    let coveredMin = perHour > 0 ? min(Double(durationMin), excessG / perHour * 60) : 0
    let planned = max(0, Int((perHour * Double(durationMin) / 60 - excessG).rounded()))
    var schedule = planFeedSchedule(totalG: planned, durationMin: durationMin,
                                    intervalMin: interval, coveredMin: coveredMin)

    // Move intake excess over the cap to the start, only into the room the start has left
    // under the same cap, and only when starting glucose is not above the target.
    // The Table 1 start amount itself is never cut — at the low end it prevents a low.
    let startG = decision.grams
    var startMovedG = 0
    if let g = glucoseMgdl, g > 0, g <= group.targetTop, !decision.individual {
        var room = max(0, cap - startG)
        schedule = schedule.map { feed in
            let take = min(room, max(0, feed.grams - cap))
            room -= take
            startMovedG += take
            return FeedStop(minute: feed.minute, grams: feed.grams - take)
        }
    }
    let totalG = startG + startMovedG + schedule.reduce(0) { $0 + $1.grams }

    let during: String
    if kind.isAnaerobic {
        during = lang.t(kind == .resistance ? "during.resistance" : "during.interval",
                        unit.amount(group.duringThreshold))
    } else if schedule.isEmpty {
        during = lang.t("during.none", unit.amount(group.duringThreshold))
    } else {
        during = lang.t("during.some", String(format: "%.2g", ratePerKg))
    }

    let after = AfterPlan(threshold: group.afterThreshold,
                          nightAlert: group.afterThreshold,
                          bedtimeSnackG: max(5, Int((0.4 * weight / 5).rounded()) * 5))

    return RunGuide(bandDetail: bandDetail, group: group, expectation: expectation,
                    status: decision.status, startTitle: decision.title, startReason: decision.reason,
                    duringText: during, ratePerKg: ratePerKg, duringPerHourG: Int(perHour.rounded()),
                    duringStartG: startG, intakeCapG: cap, startIndividual: decision.individual,
                    duringSchedule: schedule, startMovedG: startMovedG, duringTotalG: totalG,
                    duringIntervalMin: interval,
                    startAboveTarget: (glucoseMgdl ?? 0) > group.targetTop,
                    excessG: Int(excessG.rounded()), coveredMin: Int(coveredMin.rounded()),
                    carryRescueG: expectation == .falls ? maxSingleCorrectionG : 20,
                    after: after,
                    afterText: kind.isAnaerobic ? lang.t("after.anaerobic") : nil,
                    weightKg: weight, weightIsDefault: weightKg == nil,
                    usedGlucose: glucoseMgdl)
}
