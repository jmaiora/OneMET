import Foundation
import HealthKit

// HealthKitService.swift — thin async wrapper over HealthKit (iOS 16 query descriptors).
// All reads only; OneMET never writes to HealthKit.

struct HealthKitService {
    let store = HKHealthStore()

    static var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    // Convenience unit accessors
    static let mgdl = HKUnit(from: "mg/dL")
    static let bpm  = HKUnit.count().unitDivided(by: .minute())

    var readTypes: Set<HKObjectType> {
        [
            HKQuantityType(.bloodGlucose),
            HKQuantityType(.stepCount),
            HKQuantityType(.activeEnergyBurned),
            HKQuantityType(.basalEnergyBurned),
            HKQuantityType(.appleExerciseTime),
            HKQuantityType(.heartRate),
            HKQuantityType(.restingHeartRate),
            HKQuantityType(.bodyMass),
            HKQuantityType(.dietaryCarbohydrates),
            HKQuantityType(.insulinDelivery),
            HKQuantityType(.distanceWalkingRunning),
            HKQuantityType(.flightsClimbed),
            HKObjectType.workoutType(),
            HKObjectType.activitySummaryType()
        ]
    }

    func requestAuthorization() async throws {
        try await store.requestAuthorization(toShare: [], read: readTypes)
    }

    // MARK: - Predicates

    private func samplePredicate(_ from: Date, _ to: Date) -> NSPredicate {
        HKQuery.predicateForSamples(withStart: from, end: to, options: .strictStartDate)
    }

    // MARK: - Quantity samples

    func samples(_ id: HKQuantityTypeIdentifier, from: Date, to: Date,
                 limit: Int = HKObjectQueryNoLimit, ascending: Bool = true) async throws -> [HKQuantitySample] {
        let desc = HKSampleQueryDescriptor(
            predicates: [.quantitySample(type: HKQuantityType(id), predicate: samplePredicate(from, to))],
            sortDescriptors: [SortDescriptor(\.startDate, order: ascending ? .forward : .reverse)],
            limit: limit
        )
        return try await desc.result(for: store)
    }

    func latest(_ id: HKQuantityTypeIdentifier, unit: HKUnit) async throws -> Double? {
        let s = try await samples(id, from: .distantPast, to: Date(), limit: 1, ascending: false)
        return s.first?.quantity.doubleValue(for: unit)
    }

    // MARK: - Aggregates

    func sum(_ id: HKQuantityTypeIdentifier, unit: HKUnit, from: Date, to: Date) async throws -> Double {
        let desc = HKStatisticsQueryDescriptor(
            predicate: .quantitySample(type: HKQuantityType(id), predicate: samplePredicate(from, to)),
            options: .cumulativeSum
        )
        return try await desc.result(for: store)?.sumQuantity()?.doubleValue(for: unit) ?? 0
    }

    func average(_ id: HKQuantityTypeIdentifier, unit: HKUnit, from: Date, to: Date) async throws -> Double {
        let desc = HKStatisticsQueryDescriptor(
            predicate: .quantitySample(type: HKQuantityType(id), predicate: samplePredicate(from, to)),
            options: .discreteAverage
        )
        return try await desc.result(for: store)?.averageQuantity()?.doubleValue(for: unit) ?? 0
    }

    // MARK: - Intraday buckets (fixed count over a window)

    /// Cumulative-sum buckets across [from, to] using an interval of `hours`, returning `count` slots.
    func bucketSums(_ id: HKQuantityTypeIdentifier, unit: HKUnit,
                    from: Date, to: Date, hours: Int, count: Int) async throws -> [Double] {
        let desc = HKStatisticsCollectionQueryDescriptor(
            predicate: .quantitySample(type: HKQuantityType(id), predicate: samplePredicate(from, to)),
            options: .cumulativeSum,
            anchorDate: from,
            intervalComponents: DateComponents(hour: hours)
        )
        let coll = try await desc.result(for: store)
        var out = Array(repeating: 0.0, count: count)
        let cal = Calendar.current
        coll.enumerateStatistics(from: from, to: to) { st, _ in
            let h = cal.dateComponents([.hour], from: from, to: st.startDate).hour ?? 0
            let idx = h / hours
            if idx >= 0 && idx < count { out[idx] += st.sumQuantity()?.doubleValue(for: unit) ?? 0 }
        }
        return out
    }

    /// Discrete-average buckets across [from, to] using an interval of `hours`, returning `count` slots.
    func bucketAverages(_ id: HKQuantityTypeIdentifier, unit: HKUnit,
                        from: Date, to: Date, hours: Int, count: Int) async throws -> [Double] {
        let desc = HKStatisticsCollectionQueryDescriptor(
            predicate: .quantitySample(type: HKQuantityType(id), predicate: samplePredicate(from, to)),
            options: .discreteAverage,
            anchorDate: from,
            intervalComponents: DateComponents(hour: hours)
        )
        let coll = try await desc.result(for: store)
        var out = Array(repeating: 0.0, count: count)
        let cal = Calendar.current
        coll.enumerateStatistics(from: from, to: to) { st, _ in
            let h = cal.dateComponents([.hour], from: from, to: st.startDate).hour ?? 0
            let idx = h / hours
            if idx >= 0 && idx < count { out[idx] = st.averageQuantity()?.doubleValue(for: unit) ?? 0 }
        }
        return out
    }

    // MARK: - Daily sums (history)

    /// Per-day cumulative sums for the last `days` days, keyed by start-of-day.
    func dailySums(_ id: HKQuantityTypeIdentifier, unit: HKUnit, days: Int) async throws -> [Date: Double] {
        let cal = Calendar.current
        let end = Date()
        let start = cal.date(byAdding: .day, value: -(days - 1), to: cal.startOfDay(for: end))!
        let desc = HKStatisticsCollectionQueryDescriptor(
            predicate: .quantitySample(type: HKQuantityType(id), predicate: samplePredicate(start, end)),
            options: .cumulativeSum,
            anchorDate: start,
            intervalComponents: DateComponents(day: 1)
        )
        let coll = try await desc.result(for: store)
        var out: [Date: Double] = [:]
        coll.enumerateStatistics(from: start, to: end) { st, _ in
            out[cal.startOfDay(for: st.startDate)] = st.sumQuantity()?.doubleValue(for: unit) ?? 0
        }
        return out
    }

    // MARK: - Workouts

    func workouts(from: Date, to: Date) async throws -> [HKWorkout] {
        let desc = HKSampleQueryDescriptor(
            predicates: [.workout(samplePredicate(from, to))],
            sortDescriptors: [SortDescriptor(\.startDate, order: .reverse)]
        )
        return try await desc.result(for: store)
    }

    // MARK: - Activity summary (rings)

    func activitySummaryToday() async throws -> HKActivitySummary? {
        let cal = Calendar.current
        var comps = cal.dateComponents([.year, .month, .day], from: Date())
        comps.calendar = cal
        let desc = HKActivitySummaryQueryDescriptor(predicate: HKQuery.predicateForActivitySummary(with: comps))
        return try await desc.result(for: store).first
    }
}
