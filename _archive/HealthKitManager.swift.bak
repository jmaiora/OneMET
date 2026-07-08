import Foundation
import HealthKit
import Combine

@MainActor
final class HealthKitManager: ObservableObject {

    // MARK: – Published state
    @Published var isAuthorized     = false
    @Published var stepsToday: Int  = 0
    @Published var caloriesActive: Double = 0
    @Published var heartRateLatest: Double = 0
    @Published var sleepHoursLast: Double = 0
    @Published var mindfulMinutes: Double = 0
    @Published var hrvLatest: Double = 0

    // Weekly arrays  (index 0 = oldest, 6 = today)
    @Published var weeklySteps:    [Double] = Array(repeating: 0, count: 7)
    @Published var weeklyCalories: [Double] = Array(repeating: 0, count: 7)
    @Published var weeklyHR:       [Double] = Array(repeating: 0, count: 7)

    private let store = HKHealthStore()

    // MARK: – Types to read
    private var readTypes: Set<HKObjectType> {
        let ids: [HKQuantityTypeIdentifier] = [
            .stepCount, .activeEnergyBurned, .heartRate,
            .heartRateVariabilitySDNN, .oxygenSaturation
        ]
        var types: Set<HKObjectType> = Set(ids.compactMap { HKQuantityType.quantityType(forIdentifier: $0) })
        if let sleep = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) { types.insert(sleep) }
        if let mind  = HKObjectType.categoryType(forIdentifier: .mindfulSession) { types.insert(mind) }
        return types
    }

    // MARK: – Authorization
    func requestAuthorization() {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        store.requestAuthorization(toShare: [], read: readTypes) { [weak self] granted, _ in
            Task { @MainActor in
                self?.isAuthorized = granted
                if granted { self?.fetchAll() }
            }
        }
    }

    // MARK: – Fetch helpers
    func fetchAll() {
        fetchStepsToday()
        fetchCaloriesToday()
        fetchLatestHeartRate()
        fetchLatestHRV()
        fetchSleepLastNight()
        fetchMindfulMinutesToday()
        fetchWeeklySteps()
        fetchWeeklyCalories()
        fetchWeeklyHeartRate()
    }

    private func quantity(_ id: HKQuantityTypeIdentifier) -> HKQuantityType {
        HKQuantityType.quantityType(forIdentifier: id)!
    }

    // Steps today
    private func fetchStepsToday() {
        let now = Date()
        let start = Calendar.current.startOfDay(for: now)
        let predicate = HKQuery.predicateForSamples(withStart: start, end: now)
        let query = HKStatisticsQuery(quantityType: quantity(.stepCount),
                                      quantitySamplePredicate: predicate,
                                      options: .cumulativeSum) { [weak self] _, result, _ in
            Task { @MainActor in
                self?.stepsToday = Int(result?.sumQuantity()?.doubleValue(for: .count()) ?? 0)
            }
        }
        store.execute(query)
    }

    // Active calories today
    private func fetchCaloriesToday() {
        let now = Date()
        let start = Calendar.current.startOfDay(for: now)
        let predicate = HKQuery.predicateForSamples(withStart: start, end: now)
        let query = HKStatisticsQuery(quantityType: quantity(.activeEnergyBurned),
                                      quantitySamplePredicate: predicate,
                                      options: .cumulativeSum) { [weak self] _, result, _ in
            Task { @MainActor in
                self?.caloriesActive = result?.sumQuantity()?.doubleValue(for: .kilocalorie()) ?? 0
            }
        }
        store.execute(query)
    }

    // Latest heart rate sample
    private func fetchLatestHeartRate() {
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
        let query = HKSampleQuery(sampleType: quantity(.heartRate),
                                  predicate: nil, limit: 1,
                                  sortDescriptors: [sort]) { [weak self] _, samples, _ in
            guard let s = samples?.first as? HKQuantitySample else { return }
            Task { @MainActor in
                self?.heartRateLatest = s.quantity.doubleValue(for: HKUnit(from: "count/min"))
            }
        }
        store.execute(query)
    }

    // Latest HRV sample
    private func fetchLatestHRV() {
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
        let query = HKSampleQuery(sampleType: quantity(.heartRateVariabilitySDNN),
                                  predicate: nil, limit: 1,
                                  sortDescriptors: [sort]) { [weak self] _, samples, _ in
            guard let s = samples?.first as? HKQuantitySample else { return }
            Task { @MainActor in
                self?.hrvLatest = s.quantity.doubleValue(for: .secondUnit(with: .milli))
            }
        }
        store.execute(query)
    }

    // Sleep last night (hours of asleep)
    private func fetchSleepLastNight() {
        guard let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else { return }
        let now   = Date()
        let start = Calendar.current.date(byAdding: .hour, value: -24, to: now)!
        let predicate = HKQuery.predicateForSamples(withStart: start, end: now)
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
        let query = HKSampleQuery(sampleType: sleepType, predicate: predicate,
                                  limit: HKObjectQueryNoLimit,
                                  sortDescriptors: [sort]) { [weak self] _, samples, _ in
            let asleepSamples = (samples as? [HKCategorySample])?.filter {
                $0.value == HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue ||
                $0.value == HKCategoryValueSleepAnalysis.asleepCore.rawValue       ||
                $0.value == HKCategoryValueSleepAnalysis.asleepDeep.rawValue       ||
                $0.value == HKCategoryValueSleepAnalysis.asleepREM.rawValue
            } ?? []
            let totalSeconds = asleepSamples.reduce(0.0) { $0 + $1.endDate.timeIntervalSince($1.startDate) }
            Task { @MainActor in
                self?.sleepHoursLast = totalSeconds / 3600
            }
        }
        store.execute(query)
    }

    // Mindful minutes today
    private func fetchMindfulMinutesToday() {
        guard let mindType = HKObjectType.categoryType(forIdentifier: .mindfulSession) else { return }
        let now   = Date()
        let start = Calendar.current.startOfDay(for: now)
        let predicate = HKQuery.predicateForSamples(withStart: start, end: now)
        let query = HKSampleQuery(sampleType: mindType, predicate: predicate,
                                  limit: HKObjectQueryNoLimit,
                                  sortDescriptors: nil) { [weak self] _, samples, _ in
            let total = (samples ?? []).reduce(0.0) {
                $0 + $1.endDate.timeIntervalSince($1.startDate)
            }
            Task { @MainActor in
                self?.mindfulMinutes = total / 60
            }
        }
        store.execute(query)
    }

    // Weekly steps (last 7 days)
    private func fetchWeeklySteps() {
        fetchWeekly(typeID: .stepCount, unit: .count(), options: .cumulativeSum) { [weak self] vals in
            self?.weeklySteps = vals
        }
    }

    private func fetchWeeklyCalories() {
        fetchWeekly(typeID: .activeEnergyBurned, unit: .kilocalorie(), options: .cumulativeSum) { [weak self] vals in
            self?.weeklyCalories = vals
        }
    }

    private func fetchWeeklyHeartRate() {
        fetchWeekly(typeID: .heartRate, unit: HKUnit(from: "count/min"), options: .discreteAverage) { [weak self] vals in
            self?.weeklyHR = vals
        }
    }

    private func fetchWeekly(typeID: HKQuantityTypeIdentifier,
                              unit: HKUnit,
                              options: HKStatisticsOptions,
                              completion: @escaping @MainActor ([Double]) -> Void) {
        let cal   = Calendar.current
        let now   = Date()
        let start = cal.date(byAdding: .day, value: -6, to: cal.startOfDay(for: now))!
        let interval = DateComponents(day: 1)
        let predicate = HKQuery.predicateForSamples(withStart: start, end: now)
        let query = HKStatisticsCollectionQuery(quantityType: quantity(typeID),
                                                quantitySamplePredicate: predicate,
                                                options: options,
                                                anchorDate: start,
                                                intervalComponents: interval)
        query.initialResultsHandler = { _, results, _ in
            var vals = Array(repeating: 0.0, count: 7)
            results?.enumerateStatistics(from: start, to: now) { stats, _ in
                let idx = cal.dateComponents([.day], from: start, to: stats.startDate).day ?? 0
                if idx >= 0 && idx < 7 {
                    let v: Double
                    if options.contains(.cumulativeSum) {
                        v = stats.sumQuantity()?.doubleValue(for: unit) ?? 0
                    } else {
                        v = stats.averageQuantity()?.doubleValue(for: unit) ?? 0
                    }
                    vals[idx] = v
                }
            }
            Task { @MainActor in
                completion(vals)
            }
        }
        store.execute(query)
    }
}
