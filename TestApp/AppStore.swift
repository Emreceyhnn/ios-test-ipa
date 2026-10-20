import Foundation
import SwiftUI

// MARK: - App Data Store & View Model
@MainActor
final class AppStore: ObservableObject {
    static let shared = AppStore()
    
    // Currency
    @Published var selectedCurrency: String = "₺" // "₺", "$", "€"
    
    // Data collections
    @Published var transactions: [TransactionItem] = []
    @Published var categories: [CategoryItem] = []
    @Published var plannedPayments: [PlannedPaymentItem] = []
    @Published var savingsGoals: [SavingsGoalItem] = []
    @Published var groupSplits: [GroupSplitItem] = []
    
    // Global Health & Bluetooth Managers
    let healthKit = HealthKitManager.shared
    let bluetooth = BluetoothScaleManager.shared
    let supabase = SupabaseService.shared
    
    private init() {
        seedSampleData()
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
    
    func addPlannedPayment(_ item: PlannedPaymentItem) {
        plannedPayments.append(item)
        Haptic.success()
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
    
    // MARK: - Sample Seed Data
    private func seedSampleData() {
        categories = [
            CategoryItem(name: "Yiyecek & İçecek", iconSymbol: "fork.knife", colorHex: "#F59E0B", type: .expense, budgetLimit: 7500),
            CategoryItem(name: "Kira & Faturalar", iconSymbol: "house.fill", colorHex: "#3B82F6", type: .expense, budgetLimit: 18000),
            CategoryItem(name: "Ulaşım", iconSymbol: "car.fill", colorHex: "#06B6D4", type: .expense, budgetLimit: 4000),
            CategoryItem(name: "Eğlence & Hobi", iconSymbol: "gamecontroller.fill", colorHex: "#8B5CF6", type: .expense, budgetLimit: 3000),
            CategoryItem(name: "Sağlık & Spor", iconSymbol: "heart.fill", colorHex: "#10B981", type: .expense, budgetLimit: 3500),
            CategoryItem(name: "Maaş / Gelir", iconSymbol: "banknote.fill", colorHex: "#10B981", type: .income, budgetLimit: 0)
        ]
        
        transactions = [
            TransactionItem(categoryName: "Maaş / Gelir", categoryIcon: "banknote.fill", categoryColorHex: "#10B981", amount: 65000, type: .income, title: "Aylık Şirket Maaşı", date: Date().addingTimeInterval(-86400 * 2)),
            TransactionItem(categoryName: "Kira & Faturalar", categoryIcon: "house.fill", categoryColorHex: "#3B82F6", amount: 16500, type: .expense, title: "Ev Kirası", date: Date().addingTimeInterval(-86400 * 3)),
            TransactionItem(categoryName: "Yiyecek & İçecek", categoryIcon: "fork.knife", categoryColorHex: "#F59E0B", amount: 840, type: .expense, title: "Haftalık Market Alışverişi", date: Date().addingTimeInterval(-3600 * 4)),
            TransactionItem(categoryName: "Sağlık & Spor", categoryIcon: "heart.fill", categoryColorHex: "#10B981", amount: 1200, type: .expense, title: "Fitness Üyeliği", date: Date().addingTimeInterval(-86400 * 5)),
            TransactionItem(categoryName: "Ulaşım", categoryIcon: "car.fill", categoryColorHex: "#06B6D4", amount: 650, type: .expense, title: "Benzin", date: Date().addingTimeInterval(-3600 * 18))
        ]
        
        plannedPayments = [
            PlannedPaymentItem(title: "Netflix 4K Ultra", amount: 249.99, dueDate: Date().addingTimeInterval(86400 * 4), frequency: .monthly, iconSymbol: "tv.fill"),
            PlannedPaymentItem(title: "Spotify Aile", amount: 99.90, dueDate: Date().addingTimeInterval(86400 * 8), frequency: .monthly, iconSymbol: "music.note"),
            PlannedPaymentItem(title: "Ev İnterneti (Fiber)", amount: 480.00, dueDate: Date().addingTimeInterval(86400 * 12), frequency: .monthly, iconSymbol: "wifi"),
            PlannedPaymentItem(title: "iCloud+ 2TB", amount: 199.99, dueDate: Date().addingTimeInterval(86400 * 15), frequency: .monthly, iconSymbol: "icloud.fill")
        ]
        
        savingsGoals = [
            SavingsGoalItem(title: "Yeni iPhone Pro", targetAmount: 85000, currentAmount: 48000, deadline: Date().addingTimeInterval(86400 * 60), iconSymbol: "iphone.gen3", colorHex: "#6366F1"),
            SavingsGoalItem(title: "Acil Durum Fonu", targetAmount: 120000, currentAmount: 92000, deadline: nil, iconSymbol: "shield.lefthalf.filled", colorHex: "#10B981"),
            SavingsGoalItem(title: "Yurt Dışı Tatili", targetAmount: 50000, currentAmount: 15500, deadline: Date().addingTimeInterval(86400 * 120), iconSymbol: "airplane.departure", colorHex: "#06B6D4")
        ]
        
        groupSplits = [
            GroupSplitItem(
                title: "Hafta Sonu Akşam Yemeği",
                totalAmount: 3600,
                participants: [
                    ParticipantShare(name: "Ben", shareAmount: 900, paidAmount: 3600, isSettled: false),
                    ParticipantShare(name: "Ahmet", shareAmount: 900, paidAmount: 0, isSettled: false),
                    ParticipantShare(name: "Can", shareAmount: 900, paidAmount: 0, isSettled: false),
                    ParticipantShare(name: "Selin", shareAmount: 900, paidAmount: 0, isSettled: true)
                ],
                isSettled: false,
                date: Date().addingTimeInterval(-86400 * 1)
            )
        ]
    }
}
