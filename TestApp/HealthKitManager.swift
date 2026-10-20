import Foundation
import HealthKit
import CoreMotion

// MARK: - Motion & HealthKit Combined Sensor Engine
@MainActor
final class HealthKitManager: ObservableObject {
    static let shared = HealthKitManager()
    
    private let healthStore = HKHealthStore()
    private let pedometer = CMPedometer()
    
    @Published var isAuthorized: Bool = false
    @Published var isMotionAuthorized: Bool = false
    @Published var isSyncing: Bool = false
    @Published var authorizationError: String?
    
    // Live Today Data (Real sensor metrics)
    @Published var todaySteps: Int = 0
    @Published var todayActiveCalories: Double = 0.0
    @Published var todayDistanceMeters: Double = 0.0
    @Published var latestWeightKg: Double? = nil
    @Published var restingHeartRateBpm: Double? = nil
    
    // Historical Trends (Last 7 Days)
    @Published var weeklyRecords: [HealthMetricRecord] = []
    
    private init() {
        startMotionTracking()
        if HKHealthStore.isHealthDataAvailable() {
            Task {
                await self.requestAuthorization()
            }
        }
    }
    
    var isHealthDataAvailable: Bool {
        HKHealthStore.isHealthDataAvailable()
    }
    
    // MARK: - Direct Hardware CoreMotion Step Tracking (Works 100% on Free Apple ID / Sideloadly)
    func startMotionTracking() {
        guard CMPedometer.isStepCountingAvailable() else { return }
        
        let startOfDay = Calendar.current.startOfDay(for: Date())
        
        // 1. Query today's steps up to now
        pedometer.queryPedometerData(from: startOfDay, to: Date()) { [weak self] data, error in
            guard let data = data, error == nil else { return }
            Task { @MainActor in
                self?.isMotionAuthorized = true
                let steps = data.numberOfSteps.intValue
                if steps > (self?.todaySteps ?? 0) {
                    self?.todaySteps = steps
                    if let dist = data.distance?.doubleValue {
                        self?.todayDistanceMeters = dist
                    } else {
                        self?.todayDistanceMeters = Double(steps) * 0.76
                    }
                    if self?.todayActiveCalories == 0 {
                        self?.todayActiveCalories = Double(steps) * 0.04
                    }
                }
            }
        }
        
        // 2. Start live step updates as user walks
        pedometer.startUpdates(from: startOfDay) { [weak self] data, error in
            guard let data = data, error == nil else { return }
            Task { @MainActor in
                self?.isMotionAuthorized = true
                let steps = data.numberOfSteps.intValue
                self?.todaySteps = steps
                if let dist = data.distance?.doubleValue {
                    self?.todayDistanceMeters = dist
                } else {
                    self?.todayDistanceMeters = Double(steps) * 0.76
                }
                self?.todayActiveCalories = Double(steps) * 0.04
            }
        }
        
        // 3. Query Past 7 Days via CoreMotion
        fetchWeeklyCoreMotionTrends()
    }
    
    private func fetchWeeklyCoreMotionTrends() {
        guard CMPedometer.isStepCountingAvailable() else { return }
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        for dayOffset in 0..<7 {
            guard let startDate = calendar.date(byAdding: .day, value: -dayOffset, to: today) else { continue }
            guard let endDate = calendar.date(byAdding: .day, value: 1, to: startDate) else { continue }
            
            pedometer.queryPedometerData(from: startDate, to: endDate) { [weak self] data, _ in
                guard let data = data else { return }
                Task { @MainActor in
                    let steps = data.numberOfSteps.intValue
                    let dist = data.distance?.doubleValue ?? (Double(steps) * 0.76)
                    let cal = Double(steps) * 0.04
                    
                    if let index = self?.weeklyRecords.firstIndex(where: { calendar.isDate($0.date, inSameDayAs: startDate) }) {
                        self?.weeklyRecords[index].steps = steps
                        self?.weeklyRecords[index].distanceMeters = dist
                        self?.weeklyRecords[index].activeCalories = cal
                    } else {
                        self?.weeklyRecords.append(
                            HealthMetricRecord(
                                weight: self?.latestWeightKg,
                                steps: steps,
                                activeCalories: cal,
                                distanceMeters: dist,
                                date: startDate,
                                isSyncedToSupabase: false
                            )
                        )
                        self?.weeklyRecords.sort { $0.date < $1.date }
                    }
                }
            }
        }
    }
    
    // MARK: - HealthKit Authorization (For devices/certs supporting HealthKit)
    @discardableResult
    func requestAuthorization() async -> Bool {
        startMotionTracking()
        
        guard isHealthDataAvailable else {
            authorizationError = "Apple Health desteği yok; CoreMotion aktif."
            return false
        }
        
        guard let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount),
              let calorieType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned),
              let distanceType = HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning),
              let weightType = HKQuantityType.quantityType(forIdentifier: .bodyMass),
              let heartRateType = HKQuantityType.quantityType(forIdentifier: .restingHeartRate) else {
            return false
        }
        
        let readTypes: Set<HKObjectType> = [stepType, calorieType, distanceType, weightType, heartRateType]
        let shareTypes: Set<HKSampleType> = [weightType]
        
        return await withCheckedContinuation { continuation in
            healthStore.requestAuthorization(toShare: shareTypes, read: readTypes) { [weak self] success, error in
                Task { @MainActor in
                    guard let self = self else { return }
                    if success {
                        self.isAuthorized = true
                        await self.fetchAllHealthData()
                        continuation.resume(returning: true)
                    } else {
                        self.isAuthorized = false
                        continuation.resume(returning: false)
                    }
                }
            }
        }
    }
    
    func fetchAllHealthData() async {
        isSyncing = true
        defer { isSyncing = false }
        
        startMotionTracking()
        
        async let steps = fetchTodaySteps()
        async let calories = fetchTodayActiveCalories()
        async let distance = fetchTodayDistance()
        async let weight = fetchLatestWeight()
        async let restingHR = fetchRestingHeartRate()
        
        let (s, c, d, w, hr) = await (steps, calories, distance, weight, restingHR)
        
        if s > 0 { self.todaySteps = s }
        if c > 0 { self.todayActiveCalories = c }
        if d > 0 { self.todayDistanceMeters = d }
        if let w = w { self.latestWeightKg = w }
        if let hr = hr { self.restingHeartRateBpm = hr }
    }
    
    func saveWeight(kilograms: Double, date: Date = Date()) async -> Bool {
        self.latestWeightKg = kilograms
        Haptic.success()
        
        guard let weightType = HKQuantityType.quantityType(forIdentifier: .bodyMass) else { return true }
        let quantity = HKQuantity(unit: .gramUnit(with: .kilo), doubleValue: kilograms)
        let sample = HKQuantitySample(type: weightType, quantity: quantity, start: date, end: date)
        
        return await withCheckedContinuation { continuation in
            healthStore.save(sample) { _, _ in
                continuation.resume(returning: true)
            }
        }
    }
    
    private func fetchTodaySteps() async -> Int {
        guard let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount) else { return 0 }
        let now = Date()
        let startOfDay = Calendar.current.startOfDay(for: now)
        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: now, options: .strictStartDate)
        
        return await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(quantityType: stepType, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, stat, _ in
                let sum = stat?.sumQuantity()?.doubleValue(for: .count()) ?? 0
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
            let query = HKStatisticsQuery(quantityType: calType, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, stat, _ in
                let sum = stat?.sumQuantity()?.doubleValue(for: .kilocalorie()) ?? 0.0
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
            let query = HKStatisticsQuery(quantityType: distType, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, stat, _ in
                let sum = stat?.sumQuantity()?.doubleValue(for: .meter()) ?? 0.0
                continuation.resume(returning: sum)
            }
            healthStore.execute(query)
        }
    }
    
    private func fetchLatestWeight() async -> Double? {
        guard let weightType = HKQuantityType.quantityType(forIdentifier: .bodyMass) else { return nil }
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
        
        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(sampleType: weightType, predicate: nil, limit: 1, sortDescriptors: [sortDescriptor]) { _, samples, _ in
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
            let query = HKSampleQuery(sampleType: hrType, predicate: nil, limit: 1, sortDescriptors: [sortDescriptor]) { _, samples, _ in
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
}
