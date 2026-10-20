import SwiftUI
import Charts

// MARK: - Dashboard View
struct DashboardView: View {
    @ObservedObject var store = AppStore.shared
    @ObservedObject var healthKit = HealthKitManager.shared
    @State private var showingAddTransaction = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        // Header Profile Bar
                        headerBar
                        
                        // Main Balance Card
                        balanceCard
                        
                        // Integrated Health Pill Widget
                        healthPillWidget
                        
                        // Income / Expense Stats
                        incomeExpenseCards
                        
                        // Quick Action Buttons
                        quickActions
                        
                        // Recent Transactions List
                        recentTransactionsSection
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 32)
                }
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $showingAddTransaction) {
                AddTransactionSheet(store: store)
            }
            .task {
                if !healthKit.isAuthorized {
                    _ = await healthKit.requestAuthorization()
                } else {
                    await healthKit.fetchAllHealthData()
                }
            }
        }
    }
    
    // MARK: - Header
    private var headerBar: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Hoş Geldiniz 👋")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                Text("AuraFit Finance")
                    .font(.title2.bold())
                    .foregroundStyle(
                        LinearGradient(colors: [.white, .white.opacity(0.8)], startPoint: .top, endPoint: .bottom)
                    )
            }
            Spacer()
            
            Button {
                Task {
                    Haptic.light()
                    await store.syncAllHealthDataToDatabase()
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .rotationEffect(.degrees(store.supabase.isSyncing ? 360 : 0))
                        .animation(store.supabase.isSyncing ? Animation.linear(duration: 1).repeatForever(autoreverses: false) : .default, value: store.supabase.isSyncing)
                    Text("Senkronize")
                        .font(.caption.bold())
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Theme.emerald.opacity(0.15))
                .foregroundColor(Theme.emerald)
                .clipShape(Capsule())
                .overlay(Capsule().stroke(Theme.emerald.opacity(0.3), lineWidth: 1))
            }
        }
        .padding(.top, 8)
    }
    
    // MARK: - Main Balance Card
    private var balanceCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Toplam Net Bakiye")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.7))
                Spacer()
                Image(systemName: "creditcard.and.123")
                    .foregroundColor(.white.opacity(0.5))
            }
            
            Text("\(store.selectedCurrency)\(String(format: "%.2f", store.netBalance))")
                .font(.system(size: 38, weight: .bold, design: .rounded))
                .foregroundColor(.white)
            
            HStack(spacing: 24) {
                Label("\(store.transactions.count) Kayıtlı İşlem", systemImage: "arrow.up.arrow.down")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
                
                Spacer()
                
                Label(store.netBalance >= 0 ? "Bütçe Pozitif" : "Açık Bütçe", systemImage: "sparkles")
                    .font(.caption.bold())
                    .foregroundColor(store.netBalance >= 0 ? Theme.emerald : Theme.rose)
            }
        }
        .padding(22)
        .background(
            LinearGradient(
                colors: [Color(hex: "#1E293B"), Color(hex: "#0F172A")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .glassCard(cornerRadius: 24, strokeColor: Theme.cardBorder)
    }
    
    // MARK: - Health Mini Widget
    private var healthPillWidget: some View {
        NavigationLink(destination: HealthTrackerView()) {
            HStack(spacing: 16) {
                // Steps Progress Ring
                ZStack {
                    Circle()
                        .stroke(Theme.emerald.opacity(0.2), lineWidth: 5)
                        .frame(width: 44, height: 44)
                    Circle()
                        .trim(from: 0, to: min(Double(healthKit.todaySteps) / 10000.0, 1.0))
                        .stroke(Theme.emerald, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .frame(width: 44, height: 44)
                    
                    Image(systemName: "figure.walk")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(Theme.emerald)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("GÜNLÜK SAĞLIK ÖZETİ")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(Theme.emerald)
                    Text("\(healthKit.todaySteps) Adım • \(String(format: "%.0f", healthKit.todayActiveCalories)) kcal")
                        .font(.subheadline.bold())
                        .foregroundColor(.white)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text("Kilo (OKOK)")
                        .font(.caption2)
                        .foregroundColor(.gray)
                    Text(healthKit.latestWeightKg != nil ? "\(String(format: "%.2f", healthKit.latestWeightKg!)) kg" : "-- kg")
                        .font(.subheadline.bold())
                        .foregroundColor(.cyan)
                }
                
                Image(systemName: "chevron.right")
                    .font(.caption.bold())
                    .foregroundColor(.gray)
            }
            .padding(14)
            .background(Theme.cardBackground.opacity(0.8))
            .glassCard(cornerRadius: 18)
        }
    }
    
    // MARK: - Income & Expense Grid
    private var incomeExpenseCards: some View {
        HStack(spacing: 14) {
            // Income
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "arrow.down.left.circle.fill")
                        .foregroundColor(Theme.emerald)
                    Text("Gelir")
                        .font(.caption.bold())
                        .foregroundColor(.gray)
                }
                Text("\(store.selectedCurrency)\(String(format: "%.2f", store.totalIncome))")
                    .font(.title3.bold())
                    .foregroundColor(.white)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassCard(cornerRadius: 18)
            
            // Expense
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "arrow.up.right.circle.fill")
                        .foregroundColor(Theme.rose)
                    Text("Gider")
                        .font(.caption.bold())
                        .foregroundColor(.gray)
                }
                Text("\(store.selectedCurrency)\(String(format: "%.2f", store.totalExpense))")
                    .font(.title3.bold())
                    .foregroundColor(.white)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassCard(cornerRadius: 18)
        }
    }
    
    // MARK: - Quick Actions
    private var quickActions: some View {
        HStack(spacing: 12) {
            Button {
                Haptic.medium()
                showingAddTransaction = true
            } label: {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text("Yeni İşlem Ekle")
                        .font(.subheadline.bold())
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Theme.primaryGradient)
                .foregroundColor(.white)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .shadow(color: Theme.indigo.opacity(0.3), radius: 8, x: 0, y: 4)
            }
        }
    }
    
    // MARK: - Recent Transactions
    private var recentTransactionsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Son İşlemler")
                    .font(.headline)
                    .foregroundColor(.white)
                Spacer()
                if !store.transactions.isEmpty {
                    Text("\(store.transactions.count) İşlem")
                        .font(.caption.bold())
                        .foregroundColor(.gray)
                }
            }
            
            if store.transactions.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "tray")
                        .font(.system(size: 36))
                        .foregroundColor(.gray.opacity(0.5))
                    Text("Henüz finansal işlem eklenmedi")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                    Button {
                        showingAddTransaction = true
                    } label: {
                        Text("İlk İşlemini Kaydet")
                            .font(.caption.bold())
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Theme.cardBackground)
                            .foregroundColor(Theme.cyan)
                            .cornerRadius(10)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 32)
                .glassCard(cornerRadius: 18)
            } else {
                ForEach(store.transactions.prefix(5)) { item in
                    HStack(spacing: 14) {
                        Image(systemName: item.categoryIcon)
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(Color(hex: item.categoryColorHex))
                            .frame(width: 44, height: 44)
                            .background(Color(hex: item.categoryColorHex).opacity(0.15))
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.title)
                                .font(.subheadline.bold())
                                .foregroundColor(.white)
                            Text(item.categoryName)
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        
                        Spacer()
                        
                        Text("\(item.type == .income ? "+" : "-")\(store.selectedCurrency)\(String(format: "%.2f", item.amount))")
                            .font(.subheadline.bold())
                            .foregroundColor(item.type == .income ? Theme.emerald : .white)
                    }
                    .padding(14)
                    .glassCard(cornerRadius: 16)
                }
            }
        }
    }
}

// MARK: - Add Transaction Sheet
struct AddTransactionSheet: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var store: AppStore
    
    @State private var title: String = ""
    @State private var amountText: String = ""
    @State private var type: TransactionType = .expense
    @State private var selectedCategory: CategoryItem?
    
    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()
                
                VStack(spacing: 20) {
                    Picker("Tür", selection: $type) {
                        Text("Gider").tag(TransactionType.expense)
                        Text("Gelir").tag(TransactionType.income)
                    }
                    .pickerStyle(.segmented)
                    
                    TextField("Açıklama (Örn: Market Alışverişi)", text: $title)
                        .padding()
                        .background(Theme.cardBackground)
                        .cornerRadius(12)
                        .foregroundColor(.white)
                    
                    TextField("Tutar (\(store.selectedCurrency))", text: $amountText)
                        .keyboardType(.decimalPad)
                        .padding()
                        .background(Theme.cardBackground)
                        .cornerRadius(12)
                        .foregroundColor(.white)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Kategori Seçin")
                            .font(.caption)
                            .foregroundColor(.gray)
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(store.categories.filter { $0.type == type }) { cat in
                                    Button {
                                        selectedCategory = cat
                                        Haptic.light()
                                    } label: {
                                        HStack {
                                            Image(systemName: cat.iconSymbol)
                                            Text(cat.name)
                                        }
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 10)
                                        .background(selectedCategory?.id == cat.id ? Color(hex: cat.colorHex) : Theme.cardBackground)
                                        .foregroundColor(.white)
                                        .cornerRadius(12)
                                    }
                                }
                            }
                        }
                    }
                    
                    Spacer()
                    
                    Button {
                        if let amount = Double(amountText.replacingOccurrences(of: ",", with: ".")), !title.isEmpty {
                            let cat = selectedCategory ?? store.categories.first(where: { $0.type == type })
                            let item = TransactionItem(
                                categoryId: cat?.id,
                                categoryName: cat?.name ?? "Genel",
                                categoryIcon: cat?.iconSymbol ?? "cart.fill",
                                categoryColorHex: cat?.colorHex ?? "#3B82F6",
                                amount: amount,
                                type: type,
                                title: title,
                                date: Date()
                            )
                            store.addTransaction(item)
                            dismiss()
                        }
                    } label: {
                        Text("İşlemi Kaydet")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Theme.primaryGradient)
                            .foregroundColor(.white)
                            .cornerRadius(16)
                    }
                    .disabled(title.isEmpty || amountText.isEmpty)
                    .opacity(title.isEmpty || amountText.isEmpty ? 0.6 : 1.0)
                }
                .padding()
            }
            .navigationTitle("Yeni İşlem")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Vazgeç") { dismiss() }
                }
            }
        }
    }
}
