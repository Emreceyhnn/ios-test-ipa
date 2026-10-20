import Foundation
import SwiftUI

// MARK: - App Data Store & View Model with UserDefaults Persistence
@MainActor
final class AppStore: ObservableObject {
    static let shared = AppStore()
    
    // Keys for local persistence
    private let kCurrency = "app_currency_pref"
    private let kTransactions = "app_stored_transactions_v1"
    private let kCategories = "app_stored_categories_v1"
    private let kPlannedPayments = "app_stored_payments_v1"
    private let kSavingsGoals = "app_stored_goals_v1"
    private let kGroupSplits = "app_stored_splits_v1"
    
    // Currency
    @Published var selectedCurrency: String = "₺" {
        didSet {
            UserDefaults.standard.set(selectedCurrency, forKey: kCurrency)
        }
    }
    
    // Clean Data collections (No fake/hardcoded dummy records)
    @Published var transactions: [TransactionItem] = [] {
        didSet { saveTransactions() }
    }
    @Published var categories: [CategoryItem] = [] {
        didSet { saveCategories() }
    }
    @Published var plannedPayments: [PlannedPaymentItem] = [] {
        didSet { savePlannedPayments() }
    }
    @Published var savingsGoals: [SavingsGoalItem] = [] {
        didSet { saveSavingsGoals() }
    }
    @Published var groupSplits: [GroupSplitItem] = [] {
        didSet { saveGroupSplits() }
    }
    
    // Global Health & Bluetooth Managers
    let healthKit = HealthKitManager.shared
    let bluetooth = BluetoothScaleManager.shared
    let supabase = SupabaseService.shared
    
    private init() {
        loadPersistedData()
    }
    
    // MARK: - Computed Financial Totals
    var totalIncome: Double {
        transactions.filter { $0.type == .income }.reduce(0) { $0 + $1.amount }
    }
    
    var totalExpense: Double {
        transactions.filter { $0.type == .expense }.reduce(0) { $0 + $1.amount }
    }
    
    var netBalance: Double {
        totalIncome - totalExpense
    }
    
    // MARK: - Synchronize Health Data To Cloud
    func syncAllHealthDataToDatabase() async {
        await healthKit.fetchAllHealthData()
        
        let record = HealthMetricRecord(
            weight: bluetooth.isStabilized && bluetooth.liveWeightKg > 0 ? bluetooth.liveWeightKg : healthKit.latestWeightKg,
            steps: healthKit.todaySteps,
            activeCalories: healthKit.todayActiveCalories,
            distanceMeters: healthKit.todayDistanceMeters,
            restingHeartRate: healthKit.restingHeartRateBpm,
            date: Date(),
            isSyncedToSupabase: true
        )
        
        _ = await supabase.syncHealthMetricsToCloud(record: record)
    }
    
    // MARK: - Actions
    func addTransaction(_ item: TransactionItem) {
        transactions.insert(item, at: 0)
        Haptic.success()
    }
    
    func deleteTransaction(at offsets: IndexSet) {
        transactions.remove(atOffsets: offsets)
        Haptic.warning()
    }
    
    func addCategory(_ item: CategoryItem) {
        categories.append(item)
        Haptic.success()
    }
    
    func deleteCategory(at offsets: IndexSet) {
        categories.remove(atOffsets: offsets)
        Haptic.warning()
    }
    
    func addPlannedPayment(_ item: PlannedPaymentItem) {
        plannedPayments.append(item)
        Haptic.success()
    }
    
    func deletePlannedPayment(at offsets: IndexSet) {
        plannedPayments.remove(atOffsets: offsets)
        Haptic.warning()
    }
    
    func togglePaymentStatus(id: UUID) {
        if let index = plannedPayments.firstIndex(where: { $0.id == id }) {
            plannedPayments[index].isPaid.toggle()
            Haptic.light()
        }
    }
    
    func addSavingsGoal(_ item: SavingsGoalItem) {
        savingsGoals.append(item)
        Haptic.success()
    }
    
    func deleteSavingsGoal(at offsets: IndexSet) {
        savingsGoals.remove(atOffsets: offsets)
        Haptic.warning()
    }
    
    func depositToGoal(id: UUID, amount: Double) {
        if let index = savingsGoals.firstIndex(where: { $0.id == id }) {
            savingsGoals[index].currentAmount += amount
            Haptic.success()
        }
    }
    
    func addGroupSplit(_ item: GroupSplitItem) {
        groupSplits.insert(item, at: 0)
        Haptic.success()
    }
    
    func deleteGroupSplit(at offsets: IndexSet) {
        groupSplits.remove(atOffsets: offsets)
        Haptic.warning()
    }
    
    // MARK: - Local Persistence
    private func loadPersistedData() {
        if let curr = UserDefaults.standard.string(forKey: kCurrency), !curr.isEmpty {
            self.selectedCurrency = curr
        }
        
        let decoder = JSONDecoder()
        
        if let data = UserDefaults.standard.data(forKey: kTransactions),
           let items = try? decoder.decode([TransactionItem].self, from: data) {
            self.transactions = items
        }
        
        if let data = UserDefaults.standard.data(forKey: kCategories),
           let items = try? decoder.decode([CategoryItem].self, from: data), !items.isEmpty {
            self.categories = items
        } else {
            // Essential Default Categories only (Empty expenses/incomes)
            self.categories = [
                CategoryItem(name: "Yiyecek & İçecek", iconSymbol: "fork.knife", colorHex: "#F59E0B", type: .expense),
                CategoryItem(name: "Kira & Faturalar", iconSymbol: "house.fill", colorHex: "#3B82F6", type: .expense),
                CategoryItem(name: "Ulaşım", iconSymbol: "car.fill", colorHex: "#06B6D4", type: .expense),
                CategoryItem(name: "Sağlık & Spor", iconSymbol: "heart.fill", colorHex: "#10B981", type: .expense),
                CategoryItem(name: "Maaş / Gelir", iconSymbol: "banknote.fill", colorHex: "#10B981", type: .income)
            ]
        }
        
        if let data = UserDefaults.standard.data(forKey: kPlannedPayments),
           let items = try? decoder.decode([PlannedPaymentItem].self, from: data) {
            self.plannedPayments = items
        }
        
        if let data = UserDefaults.standard.data(forKey: kSavingsGoals),
           let items = try? decoder.decode([SavingsGoalItem].self, from: data) {
            self.savingsGoals = items
        }
        
        if let data = UserDefaults.standard.data(forKey: kGroupSplits),
           let items = try? decoder.decode([GroupSplitItem].self, from: data) {
            self.groupSplits = items
        }
    }
    
    private func saveTransactions() {
        if let data = try? JSONEncoder().encode(transactions) {
            UserDefaults.standard.set(data, forKey: kTransactions)
        }
    }
    
    private func saveCategories() {
        if let data = try? JSONEncoder().encode(categories) {
            UserDefaults.standard.set(data, forKey: kCategories)
        }
    }
    
    private func savePlannedPayments() {
        if let data = try? JSONEncoder().encode(plannedPayments) {
            UserDefaults.standard.set(data, forKey: kPlannedPayments)
        }
    }
    
    private func saveSavingsGoals() {
        if let data = try? JSONEncoder().encode(savingsGoals) {
            UserDefaults.standard.set(data, forKey: kSavingsGoals)
        }
    }
    
    private func saveGroupSplits() {
        if let data = try? JSONEncoder().encode(groupSplits) {
            UserDefaults.standard.set(data, forKey: kGroupSplits)
        }
    }
}
