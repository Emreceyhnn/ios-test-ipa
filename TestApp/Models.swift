import Foundation

// MARK: - Transaction Model
enum TransactionType: String, Codable, CaseIterable {
    case expense
    case income
}

struct TransactionItem: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var categoryId: UUID?
    var categoryName: String
    var categoryIcon: String
    var categoryColorHex: String
    var amount: Double
    var type: TransactionType
    var title: String
    var receiptUrl: String?
    var date: Date
    
    init(
        id: UUID = UUID(),
        categoryId: UUID? = nil,
        categoryName: String,
        categoryIcon: String = "cart.fill",
        categoryColorHex: String = "#3B82F6",
        amount: Double,
        type: TransactionType = .expense,
        title: String,
        receiptUrl: String? = nil,
        date: Date = Date()
    ) {
        self.id = id
        self.categoryId = categoryId
        self.categoryName = categoryName
        self.categoryIcon = categoryIcon
        self.categoryColorHex = categoryColorHex
        self.amount = amount
        self.type = type
        self.title = title
        self.receiptUrl = receiptUrl
        self.date = date
    }
}

// MARK: - Category Model
struct CategoryItem: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var name: String
    var iconSymbol: String
    var colorHex: String
    var type: TransactionType
    var budgetLimit: Double
    
    init(
        id: UUID = UUID(),
        name: String,
        iconSymbol: String,
        colorHex: String,
        type: TransactionType = .expense,
        budgetLimit: Double = 0.0
    ) {
        self.id = id
        self.name = name
        self.iconSymbol = iconSymbol
        self.colorHex = colorHex
        self.type = type
        self.budgetLimit = budgetLimit
    }
}

// MARK: - Planned Payment / Subscription
enum PaymentFrequency: String, Codable, CaseIterable {
    case weekly = "Haftalık"
    case monthly = "Aylık"
    case yearly = "Yıllık"
}

struct PlannedPaymentItem: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var title: String
    var amount: Double
    var dueDate: Date
    var frequency: PaymentFrequency
    var iconSymbol: String
    var isPaid: Bool
    
    init(
        id: UUID = UUID(),
        title: String,
        amount: Double,
        dueDate: Date,
        frequency: PaymentFrequency = .monthly,
        iconSymbol: String = "repeat.circle.fill",
        isPaid: Bool = false
    ) {
        self.id = id
        self.title = title
        self.amount = amount
        self.dueDate = dueDate
        self.frequency = frequency
        self.iconSymbol = iconSymbol
        self.isPaid = isPaid
    }
}

// MARK: - Savings Goal
struct SavingsGoalItem: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var title: String
    var targetAmount: Double
    var currentAmount: Double
    var deadline: Date?
    var iconSymbol: String
    var colorHex: String
    
    var progress: Double {
        guard targetAmount > 0 else { return 0 }
        return min(currentAmount / targetAmount, 1.0)
    }
    
    init(
        id: UUID = UUID(),
        title: String,
        targetAmount: Double,
        currentAmount: Double = 0,
        deadline: Date? = nil,
        iconSymbol: String = "target",
        colorHex: String = "#10B981"
    ) {
        self.id = id
        self.title = title
        self.targetAmount = targetAmount
        self.currentAmount = currentAmount
        self.deadline = deadline
        self.iconSymbol = iconSymbol
        self.colorHex = colorHex
    }
}

// MARK: - Group Split / Split Bill
struct ParticipantShare: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var name: String
    var shareAmount: Double
    var paidAmount: Double
    var isSettled: Bool
    
    var balance: Double {
        paidAmount - shareAmount
    }
}

struct GroupSplitItem: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var title: String
    var totalAmount: Double
    var participants: [ParticipantShare]
    var isSettled: Bool
    var date: Date
    
    init(
        id: UUID = UUID(),
        title: String,
        totalAmount: Double,
        participants: [ParticipantShare] = [],
        isSettled: Bool = false,
        date: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.totalAmount = totalAmount
        self.participants = participants
        self.isSettled = isSettled
        self.date = date
    }
}

// MARK: - Health Metric Snapshot
struct HealthMetricRecord: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var weight: Double? // kg
    var steps: Int
    var activeCalories: Double // kcal
    var distanceMeters: Double // meters
    var restingHeartRate: Double? // bpm
    var date: Date
    var isSyncedToSupabase: Bool
    
    init(
        id: UUID = UUID(),
        weight: Double? = nil,
        steps: Int = 0,
        activeCalories: Double = 0,
        distanceMeters: Double = 0,
        restingHeartRate: Double? = nil,
        date: Date = Date(),
        isSyncedToSupabase: Bool = false
    ) {
        self.id = id
        self.weight = weight
        self.steps = steps
        self.activeCalories = activeCalories
        self.distanceMeters = distanceMeters
        self.restingHeartRate = restingHeartRate
        self.date = date
        self.isSyncedToSupabase = isSyncedToSupabase
    }
}

// MARK: - User Profile
struct UserProfile: Codable {
    var id: UUID
    var email: String
    var currency: String
    var biometricEnabled: Bool
}
