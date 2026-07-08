import SwiftUI
import HealthKit

// HealthDataStore.swift — live HealthKit-backed data for the OneMET screens.
// Publishes a single HealthSnapshot; screens read store.data.*.
// Seeds from SampleData so previews/first-launch show content before HealthKit loads.

// MARK: - Supporting models

struct Rings {
    var move: RingMetric
    var exer: RingMetric
    var met:  RingMetric
}

struct DayEvent: Identifiable {
    let id = UUID()
    let date: Date
    let time: String
    let text: String
    let color: Color
}

// MARK: - Math helpers

enum HealthMath {
    /// kcal per (kg·min) for 1 MET (1 MET = 3.5 mlO₂/kg/min ≈ 0.0175 kcal/kg/min).
    static let metKcalFactor = 0.0175

    /// MET·min from total energy (active + basal) and body mass. Chosen methodology.
    static func metMin(totalKcal: Double, massKg: Double) -> Double {
        massKg > 0 ? totalKcal / (metKcalFactor * massKg) : 0
    }

    static func tir(_ vals: [Double]) -> TimeInRange {
        guard !vals.isEmpty else { return TimeInRange(low: 0, inRange: 0, high: 0) }
        var low = 0, inr = 0, high = 0
        for v in vals {
            if v < Theme.targetLow { low += 1 }
            else if v > Theme.targetHigh { high += 1 }
            else { inr += 1 }
        }
        let n = Double(vals.count)
        return TimeInRange(
            low: Int((Double(low) / n * 100).rounded()),
            inRange: Int((Double(inr) / n * 100).rounded()),
            high: Int((Double(high) / n * 100).rounded())
        )
    }

    static func stddev(_ vals: [Double]) -> Double {
        guard vals.count > 1 else { return 0 }
        let m = vals.reduce(0, +) / Double(vals.count)
        let variance = vals.reduce(0) { $0 + ($1 - m) * ($1 - m) } / Double(vals.count)
        return variance.squareRoot()
    }

    /// Glucose Management Indicator (%) from mean glucose (mg/dL).
    static func gmi(meanMgdl: Double) -> Double { 3.31 + 0.02392 * meanMgdl }

    /// Count of hypo excursions (transitions into < target low).
    static func lowEvents(_ vals: [Double]) -> Int {
        var count = 0, below = false
        for v in vals {
            if v < Theme.targetLow { if !below { count += 1; below = true } }
            else { below = false }
        }
        return count
    }
}

// MARK: - Snapshot

struct HealthSnapshot {
    // Glucose (today)
    var glucose: [Double] = []          // 5-min grid from midnight → last reading
    var currentIdx: Int = 0
    var runFrom: Int? = nil
    var runTo: Int? = nil
    var current: Double = 0
    var currentTrend: TrendArrow.Dir = .flat
    var avg: Double = 0
    var tir: TimeInRange = TimeInRange(low: 0, inRange: 0, high: 0)
    var lowestToday: Double = 0
    var highestToday: Double = 0
    var sdToday: Double = 0
    var hasGlucose: Bool = false

    // Activity
    var rings: Rings
    var steps: Int = 0
    var stepsGoal: Int = 10000
    var distanceKm: Double = 0
    var flights: Int = 0
    var metToday: Double = 0
    var metPeak: Double = 0
    var metByHour: [Double] = Array(repeating: 0, count: 12)
    var peakBucketLabel: String = "—"

    // Heart
    var heartCurrent: Int = 0
    var heartResting: Int = 0
    var heartLow: Int = 0
    var heartHigh: Int = 0
    var heartSeries: [Double] = Array(repeating: 0, count: 12)

    // Workouts / nutrition / events
    var workouts: [Workout] = []
    var nutrition: Nutrition = Nutrition(carbs: 0, carbsGoal: 200, insulinUnits: 0, meals: [])
    var events: [DayEvent] = []

    // History (14-day)
    var tirTrend: [Double] = []
    var corr: [CorrPoint] = []
    var avgTir14: Int = 0
    var tirDeltaVsPrior: Int = 0
    var gmi: Double = 0
    var avgGlucose14: Double = 0
    var avgMet14: Int = 0
    var lowEvents14: Int = 0
    var avgSteps14: Int = 0
    var workoutCount14: Int = 0

    // Insight banner
    var insight: String = "Log a workout to see how activity shifts your glucose."

    var unit: String = "mg/dL"

    /// Mock snapshot mirroring the original SampleData mock (previews / first paint).
    static var mock: HealthSnapshot {
        var s = HealthSnapshot(rings: Rings(move: SampleData.rings.move,
                                            exer: SampleData.rings.exer,
                                            met:  SampleData.rings.met))
        s.glucose = SampleData.glucose
        s.currentIdx = SampleData.currentIdx
        s.runFrom = 192; s.runTo = 216
        s.current = SampleData.current
        s.currentTrend = .down
        s.avg = SampleData.avg
        s.tir = SampleData.tir
        s.lowestToday = 68; s.highestToday = 191; s.sdToday = 32
        s.hasGlucose = true
        s.steps = SampleData.steps; s.stepsGoal = SampleData.stepsGoal
        s.distanceKm = 6.6; s.flights = 11
        s.metToday = 486; s.metPeak = 9.1; s.metByHour = SampleData.metByHour
        s.peakBucketLabel = "4–6 PM"
        s.heartCurrent = SampleData.heart.current; s.heartResting = SampleData.heart.resting
        s.heartLow = SampleData.heart.range.low; s.heartHigh = SampleData.heart.range.high
        s.heartSeries = SampleData.heart.series
        s.workouts = SampleData.workouts
        s.nutrition = SampleData.nutrition
        s.tirTrend = SampleData.tirTrend
        s.corr = SampleData.corr
        s.avgTir14 = 82; s.tirDeltaVsPrior = 8; s.gmi = 6.4; s.avgGlucose14 = SampleData.avg
        s.avgMet14 = 412; s.lowEvents14 = 3; s.avgSteps14 = 9140; s.workoutCount14 = 9
        s.insight = "Your 4:08 PM run lowered glucose by 38 mg/dL over 32 min — consider 15g carbs before similar sessions."
        return s
    }
}

// MARK: - Store

@MainActor
final class HealthDataStore: ObservableObject {
    @Published var data: HealthSnapshot = .mock
    @Published var isLoading = false
    @Published var authorized = false
    @Published var statusMessage: String? = nil

    private let svc = HealthKitService()
    private let cal = Calendar.current

    private static let timeFmt: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "h:mm a"; return f
    }()

    func load() async {
        guard HealthKitService.isAvailable else {
            statusMessage = "Health data isn't available on this device."
            return
        }
        do {
            try await svc.requestAuthorization()
            authorized = true
        } catch {
            statusMessage = "HealthKit authorization failed: \(error.localizedDescription)"
        }
        await refresh()
    }

    func refresh() async {
        isLoading = true
        defer { isLoading = false }

        let now = Date()
        let startOfDay = cal.startOfDay(for: now)
        let massKg = (try? await svc.latest(.bodyMass, unit: .gramUnit(with: .kilo))) ?? 70

        var snap = HealthSnapshot(rings: Rings(
            move: RingMetric(value: 0, goal: 500, unit: "KCAL"),
            exer: RingMetric(value: 0, goal: 30,  unit: "MIN"),
            met:  RingMetric(value: 0, goal: 500, unit: "MET·MIN")
        ))

        await loadGlucoseToday(&snap, startOfDay: startOfDay, now: now)
        await loadActivityToday(&snap, startOfDay: startOfDay, now: now, massKg: massKg)
        await loadHeartToday(&snap, startOfDay: startOfDay, now: now)
        await loadWorkoutsToday(&snap, startOfDay: startOfDay, now: now, massKg: massKg)
        await loadNutritionToday(&snap, startOfDay: startOfDay, now: now)
        buildEvents(&snap)
        await loadHistory(&snap, now: now, massKg: massKg)

        data = snap
    }

    // MARK: Glucose (today)

    private func loadGlucoseToday(_ snap: inout HealthSnapshot, startOfDay: Date, now: Date) async {
        guard let samples = try? await svc.samples(.bloodGlucose, from: startOfDay, to: now, ascending: true),
              !samples.isEmpty else { return }
        let unit = HealthKitService.mgdl
        let readings = samples.map { (date: $0.startDate, v: $0.quantity.doubleValue(for: unit)) }

        // Build a 5-min grid from midnight, forward/back filled.
        var grid = [Double?](repeating: nil, count: 288)
        for r in readings {
            let slot = max(0, min(287, Int(r.date.timeIntervalSince(startOfDay) / 300)))
            grid[slot] = r.v
        }
        var last: Double? = nil
        for i in 0..<288 { if let v = grid[i] { last = v } else { grid[i] = last } }
        if let first = readings.first?.v {
            for i in 0..<288 { if grid[i] == nil { grid[i] = first } else { break } }
        }
        let lastSlot = max(0, min(287, Int(now.timeIntervalSince(startOfDay) / 300)))
        let fallback = readings.first!.v
        snap.glucose = (0...lastSlot).map { grid[$0] ?? fallback }
        snap.currentIdx = snap.glucose.count - 1

        let vals = readings.map { $0.v }
        snap.current = readings.last!.v
        if readings.count >= 2 {
            let d = readings.last!.v - readings[readings.count - 2].v
            snap.currentTrend = d > 3 ? .up : (d < -3 ? .down : .flat)
        }
        snap.avg = (vals.reduce(0, +) / Double(vals.count)).rounded()
        snap.tir = HealthMath.tir(vals)
        snap.lowestToday = vals.min() ?? 0
        snap.highestToday = vals.max() ?? 0
        snap.sdToday = HealthMath.stddev(vals).rounded()
        snap.hasGlucose = true
    }

    private func slot(_ date: Date, _ startOfDay: Date) -> Int {
        max(0, min(287, Int(date.timeIntervalSince(startOfDay) / 300)))
    }

    private func glucoseAt(_ date: Date, snap: HealthSnapshot, startOfDay: Date) -> Double? {
        guard snap.hasGlucose, !snap.glucose.isEmpty else { return nil }
        let i = min(snap.glucose.count - 1, slot(date, startOfDay))
        return i >= 0 ? snap.glucose[i] : nil
    }

    // MARK: Activity (today)

    private func loadActivityToday(_ snap: inout HealthSnapshot, startOfDay: Date, now: Date, massKg: Double) async {
        // Rings from the Activity summary (authoritative for Move/Exercise goals).
        if let summ = try? await svc.activitySummaryToday() {
            let moveVal = summ.activeEnergyBurned.doubleValue(for: .kilocalorie())
            let moveGoal = summ.activeEnergyBurnedGoal.doubleValue(for: .kilocalorie())
            let exVal = summ.appleExerciseTime.doubleValue(for: .minute())
            let exGoal = summ.appleExerciseTimeGoal.doubleValue(for: .minute())
            snap.rings.move = RingMetric(value: moveVal.rounded(), goal: moveGoal > 0 ? moveGoal : 500, unit: "KCAL")
            snap.rings.exer = RingMetric(value: exVal.rounded(), goal: exGoal > 0 ? exGoal : 30, unit: "MIN")
        }

        snap.steps = Int((try? await svc.sum(.stepCount, unit: .count(), from: startOfDay, to: now)) ?? 0)
        snap.distanceKm = ((try? await svc.sum(.distanceWalkingRunning, unit: .meterUnit(with: .kilo), from: startOfDay, to: now)) ?? 0)
        snap.flights = Int((try? await svc.sum(.flightsClimbed, unit: .count(), from: startOfDay, to: now)) ?? 0)

        // MET·min from total energy (active + basal).
        let activeToday = (try? await svc.sum(.activeEnergyBurned, unit: .kilocalorie(), from: startOfDay, to: now)) ?? 0
        let basalToday = (try? await svc.sum(.basalEnergyBurned, unit: .kilocalorie(), from: startOfDay, to: now)) ?? 0
        snap.metToday = HealthMath.metMin(totalKcal: activeToday + basalToday, massKg: massKg).rounded()
        snap.rings.met = RingMetric(value: snap.metToday, goal: 500, unit: "MET·MIN")

        // MET by 2h bucket (12 buckets).
        let activeBuckets = (try? await svc.bucketSums(.activeEnergyBurned, unit: .kilocalorie(), from: startOfDay, to: now, hours: 2, count: 12)) ?? Array(repeating: 0, count: 12)
        let basalBuckets = (try? await svc.bucketSums(.basalEnergyBurned, unit: .kilocalorie(), from: startOfDay, to: now, hours: 2, count: 12)) ?? Array(repeating: 0, count: 12)
        snap.metByHour = (0..<12).map { HealthMath.metMin(totalKcal: activeBuckets[$0] + basalBuckets[$0], massKg: massKg).rounded() }

        if let peakIdx = snap.metByHour.indices.max(by: { snap.metByHour[$0] < snap.metByHour[$1] }),
           snap.metByHour[peakIdx] > 0 {
            snap.peakBucketLabel = bucketLabel(peakIdx)
        }
    }

    private func bucketLabel(_ i: Int) -> String {
        func h(_ hr: Int) -> String { hr == 0 ? "12 AM" : hr == 12 ? "12 PM" : hr < 12 ? "\(hr) AM" : "\(hr - 12) PM" }
        return "\(h(i * 2))–\(h(i * 2 + 2))"
    }

    // MARK: Heart (today)

    private func loadHeartToday(_ snap: inout HealthSnapshot, startOfDay: Date, now: Date) async {
        let unit = HealthKitService.bpm
        snap.heartCurrent = Int(((try? await svc.latest(.heartRate, unit: unit)) ?? 0).rounded())
        snap.heartResting = Int(((try? await svc.latest(.restingHeartRate, unit: unit)) ?? 0).rounded())

        if let hr = try? await svc.samples(.heartRate, from: startOfDay, to: now, ascending: true), !hr.isEmpty {
            let vals = hr.map { $0.quantity.doubleValue(for: unit) }
            snap.heartLow = Int(vals.min() ?? 0)
            snap.heartHigh = Int(vals.max() ?? 0)
        }
        if let series = try? await svc.bucketAverages(.heartRate, unit: unit, from: startOfDay, to: now, hours: 2, count: 12) {
            snap.heartSeries = series
        }
    }

    // MARK: Workouts (today)

    private func loadWorkoutsToday(_ snap: inout HealthSnapshot, startOfDay: Date, now: Date, massKg: Double) async {
        guard let wks = try? await svc.workouts(from: startOfDay, to: now), !wks.isEmpty else { return }

        var out: [Workout] = []
        for w in wks {
            let kcal = w.statistics(for: HKQuantityType(.activeEnergyBurned))?.sumQuantity()?.doubleValue(for: .kilocalorie())
                ?? (w.totalEnergyBurned?.doubleValue(for: .kilocalorie()) ?? 0)
            let distM = w.statistics(for: HKQuantityType(.distanceWalkingRunning))?.sumQuantity()?.doubleValue(for: .meter())
                ?? (w.totalDistance?.doubleValue(for: .meter()) ?? 0)
            let mins = w.duration / 60
            // Avg MET incl. resting baseline (+1 MET) for consistency with the total-energy method.
            let avgMet = (mins > 0 && massKg > 0) ? (kcal / mins) / (HealthMath.metKcalFactor * massKg) + 1 : 0
            let avgHR = Int((try? await svc.average(.heartRate, unit: HealthKitService.bpm, from: w.startDate, to: w.endDate)) ?? 0)

            var delta = 0
            if let gStart = glucoseAt(w.startDate, snap: snap, startOfDay: startOfDay),
               let gEnd = glucoseAt(w.endDate, snap: snap, startOfDay: startOfDay) {
                delta = Int((gEnd - gStart).rounded())
            }
            out.append(Workout(
                name: workoutName(w.workoutActivityType),
                time: Self.timeFmt.string(from: w.startDate),
                dur: "\(Int(mins.rounded())) min",
                dist: distM > 0 ? String(format: "%.1f km", distM / 1000) : "—",
                kcal: Int(kcal.rounded()),
                avgMet: (avgMet * 10).rounded() / 10,
                hr: avgHR,
                glucoseDelta: delta
            ))
        }
        snap.workouts = out
        snap.metPeak = out.map { $0.avgMet }.max() ?? 0

        // Primary workout drives the glucose-chart RUN band + the insight banner.
        if let primary = wks.max(by: { $0.duration < $1.duration }) {
            snap.runFrom = slot(primary.startDate, startOfDay)
            snap.runTo = slot(primary.endDate, startOfDay)
            if let pw = out.first(where: { $0.time == Self.timeFmt.string(from: primary.startDate) }) {
                if pw.glucoseDelta < 0 {
                    snap.insight = "Your \(pw.time) \(pw.name.lowercased()) lowered glucose by \(abs(pw.glucoseDelta)) mg/dL over \(pw.dur) — consider 15g carbs before similar sessions."
                } else {
                    snap.insight = "Your \(pw.time) \(pw.name.lowercased()) kept glucose steady (\(pw.glucoseDelta >= 0 ? "+" : "")\(pw.glucoseDelta) mg/dL) over \(pw.dur)."
                }
            }
        }
    }

    private func workoutName(_ t: HKWorkoutActivityType) -> String {
        switch t {
        case .running: return "Outdoor Run"
        case .walking: return "Walk"
        case .cycling: return "Cycling"
        case .swimming: return "Swim"
        case .hiking: return "Hike"
        case .traditionalStrengthTraining, .functionalStrengthTraining: return "Strength"
        case .highIntensityIntervalTraining: return "HIIT"
        case .yoga: return "Yoga"
        default: return "Workout"
        }
    }

    // MARK: Nutrition (today)

    private func loadNutritionToday(_ snap: inout HealthSnapshot, startOfDay: Date, now: Date) async {
        let carbs = (try? await svc.sum(.dietaryCarbohydrates, unit: .gram(), from: startOfDay, to: now)) ?? 0
        let insulin = (try? await svc.sum(.insulinDelivery, unit: .internationalUnit(), from: startOfDay, to: now)) ?? 0
        let carbSamples = (try? await svc.samples(.dietaryCarbohydrates, from: startOfDay, to: now, ascending: true)) ?? []

        struct Grp { var carbs: Double; var first: Date }
        var groups: [String: Grp] = [:]
        for s in carbSamples {
            let g = s.quantity.doubleValue(for: .gram())
            let hr = cal.component(.hour, from: s.startDate)
            let name = hr < 4 ? "Dinner" : hr < 11 ? "Breakfast" : hr < 15 ? "Lunch" : hr < 18 ? "Snack" : "Dinner"
            if var ex = groups[name] {
                ex.carbs += g
                if s.startDate < ex.first { ex.first = s.startDate }
                groups[name] = ex
            } else {
                groups[name] = Grp(carbs: g, first: s.startDate)
            }
        }
        let meals = ["Breakfast", "Lunch", "Snack", "Dinner"].compactMap { name -> Meal? in
            guard let grp = groups[name], grp.carbs > 0 else { return nil }
            return Meal(name: name, carbs: Int(grp.carbs.rounded()), time: Self.timeFmt.string(from: grp.first))
        }
        snap.nutrition = Nutrition(carbs: Int(carbs.rounded()), carbsGoal: 200,
                                   insulinUnits: Int(insulin.rounded()), meals: meals)
    }

    // MARK: Events timeline (for the glucose detail view)

    private func buildEvents(_ snap: inout HealthSnapshot) {
        let today = cal.startOfDay(for: Date())
        func parse(_ s: String) -> Date {
            guard let t = Self.timeFmt.date(from: s) else { return today }
            let c = cal.dateComponents([.hour, .minute], from: t)
            return cal.date(bySettingHour: c.hour ?? 0, minute: c.minute ?? 0, second: 0, of: today) ?? today
        }
        var evs: [DayEvent] = []
        for m in snap.nutrition.meals {
            evs.append(DayEvent(date: parse(m.time), time: m.time,
                                text: "\(m.name) · \(m.carbs)g carbs", color: Theme.amber))
        }
        for w in snap.workouts {
            let sign = w.glucoseDelta > 0 ? "+" : ""
            evs.append(DayEvent(date: parse(w.time), time: w.time,
                                text: "\(w.name) · \(sign)\(w.glucoseDelta) mg/dL",
                                color: w.glucoseDelta < 0 ? Theme.green : Theme.amber))
        }
        snap.events = evs.sorted { $0.date < $1.date }
    }

    // MARK: History (14-day)

    private func loadHistory(_ snap: inout HealthSnapshot, now: Date, massKg: Double) async {
        let start14 = cal.date(byAdding: .day, value: -13, to: cal.startOfDay(for: now))!
        let unit = HealthKitService.mgdl

        let g14 = (try? await svc.samples(.bloodGlucose, from: start14, to: now, ascending: true)) ?? []
        var byDay: [Date: [Double]] = [:]
        for s in g14 {
            byDay[cal.startOfDay(for: s.startDate), default: []].append(s.quantity.doubleValue(for: unit))
        }
        let active14 = (try? await svc.dailySums(.activeEnergyBurned, unit: .kilocalorie(), days: 14)) ?? [:]
        let basal14  = (try? await svc.dailySums(.basalEnergyBurned, unit: .kilocalorie(), days: 14)) ?? [:]
        let steps14  = (try? await svc.dailySums(.stepCount, unit: .count(), days: 14)) ?? [:]

        let days = (0..<14).compactMap { cal.date(byAdding: .day, value: $0, to: start14) }
        var tirTrend: [Double] = [], metPerDay: [Double] = [], stepsPerDay: [Double] = []
        var corr: [CorrPoint] = [], allGlucose: [Double] = []

        for d in days {
            let key = cal.startOfDay(for: d)
            let vals = byDay[key] ?? []
            let tirDay = vals.isEmpty ? 0 : Double(HealthMath.tir(vals).inRange)
            tirTrend.append(tirDay)
            let energy = (active14[key] ?? 0) + (basal14[key] ?? 0)
            let metDay = HealthMath.metMin(totalKcal: energy, massKg: massKg)
            metPerDay.append(metDay)
            stepsPerDay.append(steps14[key] ?? 0)
            if !vals.isEmpty {
                corr.append(CorrPoint(metMin: metDay.rounded(), tirPct: tirDay))
                allGlucose += vals
            }
        }

        guard !g14.isEmpty else { return }   // keep seeded history if there's no CGM history yet

        snap.tirTrend = tirTrend
        snap.corr = corr

        let withData = tirTrend.filter { $0 > 0 }
        snap.avgTir14 = withData.isEmpty ? 0 : Int((withData.reduce(0, +) / Double(withData.count)).rounded())
        let last7 = Array(tirTrend.suffix(7)).filter { $0 > 0 }
        let prior7 = Array(tirTrend.prefix(7)).filter { $0 > 0 }
        let m7 = last7.isEmpty ? 0 : last7.reduce(0, +) / Double(last7.count)
        let mp = prior7.isEmpty ? 0 : prior7.reduce(0, +) / Double(prior7.count)
        snap.tirDeltaVsPrior = Int((m7 - mp).rounded())
        let mean14 = allGlucose.isEmpty ? 0 : allGlucose.reduce(0, +) / Double(allGlucose.count)
        snap.gmi = allGlucose.isEmpty ? 0 : HealthMath.gmi(meanMgdl: mean14)
        snap.avgGlucose14 = mean14.rounded()
        snap.avgMet14 = metPerDay.isEmpty ? 0 : Int((metPerDay.reduce(0, +) / Double(metPerDay.count)).rounded())
        snap.avgSteps14 = stepsPerDay.isEmpty ? 0 : Int((stepsPerDay.reduce(0, +) / Double(stepsPerDay.count)).rounded())
        snap.lowEvents14 = HealthMath.lowEvents(g14.map { $0.quantity.doubleValue(for: unit) })
        snap.workoutCount14 = ((try? await svc.workouts(from: start14, to: now)) ?? []).count
    }
}
