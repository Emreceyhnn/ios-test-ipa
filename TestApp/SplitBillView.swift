import SwiftUI

// MARK: - Split Bill & Group Debt Tracker
struct SplitBillView: View {
    @ObservedObject var store = AppStore.shared
    @State private var showingAddGroupSheet = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        // Summary Banner
                        summaryBanner
                        
                        // Groups List
                        ForEach(store.groupSplits) { group in
                            groupCard(group)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 32)
                }
            }
            .navigationTitle("Borç & Hesap Bölüştürme")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        // Quick demo add
                        let newSplit = GroupSplitItem(
                            title: "Kahve & Tatlı",
                            totalAmount: 640,
                            participants: [
                                ParticipantShare(name: "Ben", shareAmount: 160, paidAmount: 640, isSettled: false),
                                ParticipantShare(name: "Mehmet", shareAmount: 160, paidAmount: 0, isSettled: false),
                                ParticipantShare(name: "Ayşe", shareAmount: 160, paidAmount: 0, isSettled: false),
                                ParticipantShare(name: "Murat", shareAmount: 160, paidAmount: 0, isSettled: true)
                            ]
                        )
                        store.addGroupSplit(newSplit)
                    } label: {
                        Image(systemName: "plus")
                            .foregroundColor(.white)
                    }
                }
            }
        }
    }
    
    private var summaryBanner: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Akıllı Hesap Bölüştürücü", systemImage: "person.2.fill")
                .font(.headline)
                .foregroundColor(.white)
            Text("Toplu harcamalarda kim kime ne kadar borçlu anında hesaplayın.")
                .font(.subheadline)
                .foregroundColor(.gray)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(cornerRadius: 20)
    }
    
    private func groupCard(_ group: GroupSplitItem) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(group.title)
                        .font(.headline)
                        .foregroundColor(.white)
                    Text("Toplam: \(store.selectedCurrency)\(String(format: "%.2f", group.totalAmount))")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                Spacer()
                
                Text(group.isSettled ? "Tamamlandı" : "Aktif")
                    .font(.caption.bold())
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(group.isSettled ? Theme.emerald.opacity(0.2) : Theme.amber.opacity(0.2))
                    .foregroundColor(group.isSettled ? Theme.emerald : Theme.amber)
                    .cornerRadius(8)
            }
            
            Divider().background(Color.white.opacity(0.1))
            
            VStack(spacing: 8) {
                ForEach(group.participants) { person in
                    HStack {
                        Circle()
                            .fill(person.isSettled ? Theme.emerald : Theme.rose)
                            .frame(width: 8, height: 8)
                        
                        Text(person.name)
                            .font(.subheadline)
                            .foregroundColor(.white)
                        
                        Spacer()
                        
                        if person.balance > 0 {
                            Text("+\(store.selectedCurrency)\(String(format: "%.2f", person.balance)) alacaklı")
                                .font(.caption.bold())
                                .foregroundColor(Theme.emerald)
                        } else if person.balance < 0 {
                            Text("\(store.selectedCurrency)\(String(format: "%.2f", abs(person.balance))) borçlu")
                                .font(.caption.bold())
                                .foregroundColor(Theme.rose)
                        } else {
                            Text("Dengede")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }
                }
            }
        }
        .padding(18)
        .glassCard(cornerRadius: 20)
    }
}
