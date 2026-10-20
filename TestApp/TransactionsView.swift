import SwiftUI
import Charts
import PhotosUI

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
                        VStack(spacing: 12) {
                            ForEach(filteredTransactions) { item in
                                transactionRow(item)
                            }
                            .onDelete(perform: store.deleteTransaction)
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
                Text("Henüz harcama verisi yok")
                    .foregroundColor(.gray)
                    .frame(height: 180)
            }
        }
        .padding(18)
        .glassCard(cornerRadius: 20)
    }
    
    // MARK: - Filter Pills
    private var filterSection: some View {
        HStack(spacing: 10) {
            filterButton(title: "Tümü", filter: nil)
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
