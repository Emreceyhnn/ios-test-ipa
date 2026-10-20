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
                        if store.groupSplits.isEmpty {
                            emptyState
                        } else {
                            ForEach(store.groupSplits) { group in
                                groupCard(group)
                            }
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
                        showingAddGroupSheet = true
                    } label: {
                        Image(systemName: "plus")
                            .foregroundColor(.white)
                    }
                }
            }
            .sheet(isPresented: $showingAddGroupSheet) {
                AddSplitGroupSheet(store: store)
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
    
    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "person.2.badge.gearshape")
                .font(.system(size: 40))
                .foregroundColor(.gray.opacity(0.4))
            Text("Kayıtlı grup hesabı yok")
                .font(.subheadline.bold())
                .foregroundColor(.white)
            Text("Arkadaşlarınızla akşam yemeği veya seyahat harcamasını eşit veya özel bölüştürün.")
                .font(.caption)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
            Button {
                showingAddGroupSheet = true
            } label: {
                Text("Grup Harcaması Bölüştür")
                    .font(.caption.bold())
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Theme.cardBackground)
                    .foregroundColor(Theme.emerald)
                    .cornerRadius(10)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 36)
        .glassCard(cornerRadius: 18)
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

// MARK: - Add Split Group Sheet
struct AddSplitGroupSheet: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var store: AppStore
    
    @State private var title: String = ""
    @State private var totalAmountText: String = ""
    @State private var namesList: String = "Ben, Can, Ali"
    
    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()
                
                VStack(spacing: 20) {
                    TextField("Etkinlik / Harcama (Örn: Akşam Yemeği)", text: $title)
                        .padding()
                        .background(Theme.cardBackground)
                        .cornerRadius(12)
                        .foregroundColor(.white)
                    
                    TextField("Toplam Hesap (\(store.selectedCurrency))", text: $totalAmountText)
                        .keyboardType(.decimalPad)
                        .padding()
                        .background(Theme.cardBackground)
                        .cornerRadius(12)
                        .foregroundColor(.white)
                    
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Kişiler (Virgülle ayırın)")
                            .font(.caption)
                            .foregroundColor(.gray)
                        TextField("Örn: Ben, Ahmet, Burak", text: $namesList)
                            .padding()
                            .background(Theme.cardBackground)
                            .cornerRadius(12)
                            .foregroundColor(.white)
                    }
                    
                    Spacer()
                    
                    Button {
                        if let total = Double(totalAmountText.replacingOccurrences(of: ",", with: ".")), !title.isEmpty {
                            let names = namesList.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
                            let count = Double(max(names.count, 1))
                            let perPerson = (total / count * 100).rounded() / 100
                            
                            var participants: [ParticipantShare] = []
                            for (index, name) in names.enumerated() {
                                // First person is treated as payer
                                let paid = index == 0 ? total : 0.0
                                participants.append(
                                    ParticipantShare(
                                        name: name,
                                        shareAmount: perPerson,
                                        paidAmount: paid,
                                        isSettled: false
                                    )
                                )
                            }
                            
                            let split = GroupSplitItem(
                                title: title,
                                totalAmount: total,
                                participants: participants
                            )
                            store.addGroupSplit(split)
                            dismiss()
                        }
                    } label: {
                        Text("Bölüştürmeyi Başlat")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Theme.emeraldGradient)
                            .foregroundColor(.white)
                            .cornerRadius(14)
                    }
                    .disabled(title.isEmpty || totalAmountText.isEmpty)
                }
                .padding()
            }
            .navigationTitle("Yeni Hesap Bölüş")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Kapat") { dismiss() }
                }
            }
        }
    }
}
