import SwiftUI
import Charts

// MARK: - Transactions View
struct TransactionsView: View {
    @ObservedObject var store = AppStore.shared
    @State private var selectedFilter: TransactionType? = nil
    @State private var showingAddSheet = false
    
    var filteredTransactions: [TransactionItem] {
        if let filter = selectedFilter {
            return store.transactions.filter { $0.type == filter }
        }
        return store.transactions
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        // Category Spend Distribution Chart
                        expenseDistributionChart
                        
                        // Filter Pills
                        filterSection
                        
                        // Transactions List
                        if filteredTransactions.isEmpty {
                            emptyState
                        } else {
                            VStack(spacing: 12) {
                                ForEach(filteredTransactions) { item in
                                    transactionRow(item)
                                }
                                .onDelete(perform: store.deleteTransaction)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 32)
                }
            }
            .navigationTitle("İşlemler & Analiz")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        Haptic.medium()
                        showingAddSheet = true
                    } label: {
                        Image(systemName: "plus")
                            .foregroundColor(.white)
                    }
                }
            }
            .sheet(isPresented: $showingAddSheet) {
                AddTransactionSheet(store: store)
            }
        }
    }
    
    // MARK: - Distribution Chart
    private var expenseDistributionChart: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Kategori Bazlı Harcama Dağılımı")
                .font(.headline)
                .foregroundColor(.white)
            
            let expenses = store.transactions.filter { $0.type == .expense }
            
            if !expenses.isEmpty {
                Chart(expenses) { item in
                    SectorMark(
                        angle: .value("Tutar", item.amount),
                        innerRadius: .ratio(0.65),
                        angularInset: 2.0
                    )
                    .cornerRadius(5)
                    .foregroundStyle(Color(hex: item.categoryColorHex))
                }
                .frame(height: 180)
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "chart.pie")
                        .font(.system(size: 36))
                        .foregroundColor(.gray.opacity(0.4))
                    Text("Gider grafiği için henüz işlem eklenmedi")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 150)
            }
        }
        .padding(18)
        .glassCard(cornerRadius: 20)
    }
    
    // MARK: - Filter Pills
    private var filterSection: some View {
        HStack(spacing: 10) {
            filterButton(title: "Tümü (\(store.transactions.count))", filter: nil)
            filterButton(title: "Giderler", filter: .expense)
            filterButton(title: "Gelirler", filter: .income)
            Spacer()
        }
    }
    
    private func filterButton(title: String, filter: TransactionType?) -> some View {
        Button {
            selectedFilter = filter
            Haptic.light()
        } label: {
            Text(title)
                .font(.caption.bold())
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(selectedFilter == filter ? Theme.indigo : Theme.cardBackground)
                .foregroundColor(.white)
                .cornerRadius(20)
        }
    }
    
    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "tray.fill")
                .font(.system(size: 40))
                .foregroundColor(.gray.opacity(0.4))
            Text("Kayıtlı işlem bulunamadı")
                .font(.subheadline.bold())
                .foregroundColor(.white)
            Text("Gelir ve giderlerinizi sağ üstteki + butonundan ekleyebilirsiniz.")
                .font(.caption)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 36)
        .glassCard(cornerRadius: 18)
    }
    
    // MARK: - Row
    private func transactionRow(_ item: TransactionItem) -> some View {
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
                Text(item.date.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption2)
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
