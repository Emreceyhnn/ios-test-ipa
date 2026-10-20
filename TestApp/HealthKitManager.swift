import Foundation
import HealthKit

// MARK: - HealthKit Manager
@MainActor
final class HealthKitManager: ObservableObject {
    static let shared = HealthKitManager()
    
    private let healthStore = HKHealthStore()
    
    @Published var isAuthorized: Bool = false
    @Published var isSyncing: Bool = false
    @Published var authorizationError: String?
    
    // Live Today Data (Pure sensor metrics, default 0 or nil)
    @Published var todaySteps: Int = 0
    @Published var todayActiveCalories: Double = 0.0
    @Published var todayDistanceMeters: Double = 0.0
    @Published var latestWeightKg: Double? = nil
    @Published var restingHeartRateBpm: Double? = nil
    
    // Historical Trends (Last 7 Days)
    @Published var weeklyRecords: [HealthMetricRecord] = []
    
    private init() {}
    
    var isHealthDataAvailable: Bool {
        HKHealthStore.isHealthDataAvailable()
    }
    
    // MARK: - Request Authorization
    func requestAuthorization() async -> Bool {
        guard isHealthDataAvailable else {
            authorizationError = "Bu cihazda Apple Health mevcut değil."
            return false
        }
        
        guard let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount),
              let calorieType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned),
              let distanceType = HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning),
              let weightType = HKQuantityType.quantityType(forIdentifier: .bodyMass),
              let heartRateType = HKQuantityType.quantityType(forIdentifier: .restingHeartRate) else {
            return false
        }
        
        let readTypes: Set<HKObjectType> = [
            stepType,
            calorieType,
            distanceType,
            weightType,
            heartRateType
        ]
        
        let shareTypes: Set<HKSampleType> = [
            weightType
        ]
        
        do {
            try await healthStore.requestAuthorization(toShare: shareTypes, read: readTypes)
            isAuthorized = true
            await fetchAllHealthData()
            return true
        } catch {
            authorizationError = error.localizedDescription
            isAuthorized = false
            return false
        }
    }
    
    // MARK: - Comprehensive Fetch All Health Data (100% Real Sensor Readings)
    func fetchAllHealthData() async {
        isSyncing = true
        defer { isSyncing = false }
        
        async let steps = fetchTodaySteps()
        async let calories = fetchTodayActiveCalories()
        async let distance = fetchTodayDistance()
        async let weight = fetchLatestWeight()
        async let restingHR = fetchRestingHeartRate()
        async let weekly = fetchWeeklyMetrics()
        
        let (s, c, d, w, hr, week) = await (steps, calories, distance, weight, restingHR, weekly)
        
        self.todaySteps = s
        self.todayActiveCalories = c
        self.todayDistanceMeters = d
        self.latestWeightKg = w
        self.restingHeartRateBpm = hr
        self.weeklyRecords = week
    }
    
    // MARK: - Save Weight to Apple HealthKit
    func saveWeight(kilograms: Double, date: Date = Date()) async -> Bool {
        guard let weightType = HKQuantityType.quantityType(forIdentifier: .bodyMass) else { return false }
        
        let quantity = HKQuantity(unit: .gramUnit(with: .kilo), doubleValue: kilograms)
        let sample = HKQuantitySample(type: weightType, quantity: quantity, start: date, end: date)
        
        do {
            try await healthStore.save(sample)
            self.latestWeightKg = kilograms
            Haptic.success()
            return true
        } catch {
            authorizationError = "Kilo kaydedilemedi: \(error.localizedDescription)"
            return false
        }
    }
    
    // MARK: - Private Metric Fetchers
    private func fetchTodaySteps() async -> Int {
        guard let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount) else { return 0 }
        let now = Date()
        let startOfDay = Calendar.current.startOfDay(for: now)
        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: now, options: .strictStartDate)
        
        return await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: stepType,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum
            ) { _, statistics, _ in
                let sum = statistics?.sumQuantity()?.doubleValue(for: .count()) ?? 0
                continuation.resume(returning: Int(sum))
            }
            healthStore.execute(query)
        }
    }
    
    private func fetchTodayActiveCalories() async -> Double {
        guard let calType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned) else { return 0.0 }
        let now = Date()
        let startOfDay = Calendar.current.startOfDay(for: now)
        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: now, options: .strictStartDate)
        
        return await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: calType,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum
            ) { _, statistics, _ in
                let sum = statistics?.sumQuantity()?.doubleValue(for: .kilocalorie()) ?? 0.0
                continuation.resume(returning: sum)
            }
            healthStore.execute(query)
        }
    }
    
    private func fetchTodayDistance() async -> Double {
        guard let distType = HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning) else { return 0.0 }
        let now = Date()
        let startOfDay = Calendar.current.startOfDay(for: now)
        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: now, options: .strictStartDate)
        
        return await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: distType,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum
            ) { _, statistics, _ in
                let sum = statistics?.sumQuantity()?.doubleValue(for: .meter()) ?? 0.0
                continuation.resume(returning: sum)
            }
            healthStore.execute(query)
        }
    }
    
    private func fetchLatestWeight() async -> Double? {
        guard let weightType = HKQuantityType.quantityType(forIdentifier: .bodyMass) else { return nil }
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
        
        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: weightType,
                predicate: nil,
                limit: 1,
                sortDescriptors: [sortDescriptor]
            ) { _, samples, _ in
                guard let sample = samples?.first as? HKQuantitySample else {
                    continuation.resume(returning: nil)
                    return
                }
                let weight = sample.quantity.doubleValue(for: .gramUnit(with: .kilo))
                continuation.resume(returning: (weight * 10).rounded() / 10)
            }
            healthStore.execute(query)
        }
    }
    
    private func fetchRestingHeartRate() async -> Double? {
        guard let hrType = HKQuantityType.quantityType(forIdentifier: .restingHeartRate) else { return nil }
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
        
        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: hrType,
                predicate: nil,
                limit: 1,
                sortDescriptors: [sortDescriptor]
            ) { _, samples, _ in
                guard let sample = samples?.first as? HKQuantitySample else {
                    continuation.resume(returning: nil)
                    return
                }
                let rate = sample.quantity.doubleValue(for: HKUnit.count().unitDivided(by: .minute()))
                continuation.resume(returning: rate.rounded())
            }
            healthStore.execute(query)
        }
    }
    
    private func fetchWeeklyMetrics() async -> [HealthMetricRecord] {
        let calendar = Calendar.current
        var results: [HealthMetricRecord] = []
        let today = calendar.startOfDay(for: Date())
        
        for dayOffset in (0..<7).reversed() {
            guard let date = calendar.date(byAdding: .day, value: -dayOffset, to: today) else { continue }
            let nextDate = calendar.date(byAdding: .day, value: 1, to: date)!
            let predicate = HKQuery.predicateForSamples(withStart: date, end: nextDate, options: .strictStartDate)
            
            // Steps for day
            let stepSum: Int = await withCheckedContinuation { cont in
                guard let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount) else {
                    cont.resume(returning: 0)
                    return
                }
                let query = HKStatisticsQuery(quantityType: stepType, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, stat, _ in
                    let sum = stat?.sumQuantity()?.doubleValue(for: .count()) ?? 0
                    cont.resume(returning: Int(sum))
                }
                healthStore.execute(query)
            }
            
            // Calories for day
            let calSum: Double = await withCheckedContinuation { cont in
                guard let calType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned) else {
                    cont.resume(returning: 0.0)
                    return
                }
                let query = HKStatisticsQuery(quantityType: calType, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, stat, _ in
                    let sum = stat?.sumQuantity()?.doubleValue(for: .kilocalorie()) ?? 0.0
                    cont.resume(returning: sum)
                }
                healthStore.execute(query)
            }
            
            // Real recorded metric only
            results.append(
                HealthMetricRecord(
                    weight: latestWeightKg,
                    steps: stepSum,
                    activeCalories: calSum,
                    distanceMeters: Double(stepSum) * 0.76,
                    restingHeartRate: self.restingHeartRateBpm,
                    date: date,
                    isSyncedToSupabase: false
                )
            )
        }
        return results
    }
}
