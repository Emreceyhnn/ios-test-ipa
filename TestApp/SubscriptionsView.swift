import SwiftUI

// MARK: - Subscriptions & Planned Payments View
struct SubscriptionsView: View {
    @ObservedObject var store = AppStore.shared
    @State private var showingAddSheet = false
    
    var totalMonthlyCommitment: Double {
        store.plannedPayments.reduce(0) { $0 + $1.amount }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        // Total Commitment Card
                        commitmentCard
                        
                        // List of Subscriptions
                        VStack(spacing: 12) {
                            ForEach(store.plannedPayments) { item in
                                subscriptionRow(item)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 32)
                }
            }
            .navigationTitle("Abonelikler & Planlı")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingAddSheet = true
                    } label: {
                        Image(systemName: "plus")
                            .foregroundColor(.white)
                    }
                }
            }
        }
    }
    
    private var commitmentCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Aylık Sabit Yükümlülük")
                .font(.subheadline)
                .foregroundColor(.gray)
            
            Text("\(store.selectedCurrency)\(String(format: "%.2f", totalMonthlyCommitment))")
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .foregroundColor(.white)
            
            HStack {
                Label("\(store.plannedPayments.count) Aktif Abonelik", systemImage: "bell.badge.fill")
                    .font(.caption)
                    .foregroundColor(Theme.cyan)
                Spacer()
                Text("Vade günü hatırlatıcıları açık")
                    .font(.caption2)
                    .foregroundColor(.gray)
            }
        }
        .padding(20)
        .glassCard(cornerRadius: 22)
    }
    
    private func subscriptionRow(_ item: PlannedPaymentItem) -> some View {
        HStack(spacing: 14) {
            Image(systemName: item.iconSymbol)
                .font(.system(size: 20))
                .foregroundColor(Theme.cyan)
                .frame(width: 44, height: 44)
                .background(Theme.cyan.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            
            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.subheadline.bold())
                    .foregroundColor(.white)
                Text("Vade: \(item.dueDate.formatted(date: .abbreviated, time: .omitted)) • \(item.frequency.rawValue)")
                    .font(.caption2)
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 6) {
                Text("\(store.selectedCurrency)\(String(format: "%.2f", item.amount))")
                    .font(.subheadline.bold())
                    .foregroundColor(.white)
                
                Button {
                    store.togglePaymentStatus(id: item.id)
                } label: {
                    Text(item.isPaid ? "Ödendi" : "Bekliyor")
                        .font(.system(size: 10, weight: .bold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(item.isPaid ? Theme.emerald.opacity(0.2) : Theme.rose.opacity(0.2))
                        .foregroundColor(item.isPaid ? Theme.emerald : Theme.rose)
                        .cornerRadius(6)
                }
            }
        }
        .padding(14)
        .glassCard(cornerRadius: 16)
    }
}
