import SwiftUI

// MARK: - Savings Goals View
struct SavingsGoalsView: View {
    @ObservedObject var store = AppStore.shared
    @State private var showingAddGoalSheet = false
    @State private var showingDepositSheet = false
    @State private var selectedGoal: SavingsGoalItem?
    @State private var depositAmountText: String = ""
    
    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 16) {
                        if store.savingsGoals.isEmpty {
                            emptyState
                        } else {
                            ForEach(store.savingsGoals) { goal in
                                goalCard(goal)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 32)
                }
            }
            .navigationTitle("Birikim Hedefleri")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingAddGoalSheet = true
                    } label: {
                        Image(systemName: "plus")
                            .foregroundColor(.white)
                    }
                }
            }
            .sheet(isPresented: $showingAddGoalSheet) {
                AddSavingsGoalSheet(store: store)
            }
            .sheet(item: $selectedGoal) { goal in
                depositSheet(goal)
            }
        }
    }
    
    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "target")
                .font(.system(size: 40))
                .foregroundColor(.gray.opacity(0.4))
            Text("Henüz birikim hedefi belirlenmedi")
                .font(.subheadline.bold())
                .foregroundColor(.white)
            Text("Yeni araba, tatil, acil durum fonu gibi hedeflerinizi belirleyip ilerlemenizi takip edin.")
                .font(.caption)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
            Button {
                showingAddGoalSheet = true
            } label: {
                Text("İlk Hedefini Belirle")
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
    
    private func goalCard(_ goal: SavingsGoalItem) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Image(systemName: goal.iconSymbol)
                    .font(.title3)
                    .foregroundColor(Color(hex: goal.colorHex))
                Text(goal.title)
                    .font(.headline)
                    .foregroundColor(.white)
                Spacer()
                Text("%\(Int(goal.progress * 100))")
                    .font(.headline.bold())
                    .foregroundColor(Color(hex: goal.colorHex))
            }
            
            // Progress Bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.white.opacity(0.1))
                        .frame(height: 10)
                    RoundedRectangle(cornerRadius: 6)
                        .fill(
                            LinearGradient(
                                colors: [Color(hex: goal.colorHex), Theme.cyan],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geo.size.width * CGFloat(goal.progress), height: 10)
                }
            }
            .frame(height: 10)
            
            HStack {
                Text("\(store.selectedCurrency)\(String(format: "%.0f", goal.currentAmount)) birikti")
                    .font(.caption)
                    .foregroundColor(.gray)
                Spacer()
                Text("Hedef: \(store.selectedCurrency)\(String(format: "%.0f", goal.targetAmount))")
                    .font(.caption.bold())
                    .foregroundColor(.white)
            }
            
            Button {
                selectedGoal = goal
            } label: {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text("Para Yatır")
                }
                .font(.caption.bold())
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(Color.white.opacity(0.08))
                .foregroundColor(.white)
                .cornerRadius(10)
            }
        }
        .padding(18)
        .glassCard(cornerRadius: 20)
    }
    
    private func depositSheet(_ goal: SavingsGoalItem) -> some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()
                
                VStack(spacing: 20) {
                    Text("\(goal.title) hedefine eklenecek tutar")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                    
                    TextField("Tutar (\(store.selectedCurrency))", text: $depositAmountText)
                        .keyboardType(.decimalPad)
                        .padding()
                        .background(Theme.cardBackground)
                        .cornerRadius(12)
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    Button {
                        if let amount = Double(depositAmountText.replacingOccurrences(of: ",", with: ".")) {
                            store.depositToGoal(id: goal.id, amount: amount)
                            depositAmountText = ""
                            selectedGoal = nil
                        }
                    } label: {
                        Text("Hedefe Ekle")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Theme.emeraldGradient)
                            .foregroundColor(.white)
                            .cornerRadius(14)
                    }
                    .disabled(depositAmountText.isEmpty)
                }
                .padding()
            }
            .navigationTitle("Para Ekle")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Kapat") { selectedGoal = nil }
                }
            }
        }
    }
}

// MARK: - Add Savings Goal Sheet
struct AddSavingsGoalSheet: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var store: AppStore
    
    @State private var title: String = ""
    @State private var targetAmountText: String = ""
    @State private var initialAmountText: String = ""
    @State private var selectedColorHex: String = "#10B981"
    
    let colors = ["#10B981", "#3B82F6", "#8B5CF6", "#F59E0B", "#F43F5E", "#06B6D4"]
    
    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()
                
                VStack(spacing: 20) {
                    TextField("Hedef Adı (Örn: Yeni Bilgisayar)", text: $title)
                        .padding()
                        .background(Theme.cardBackground)
                        .cornerRadius(12)
                        .foregroundColor(.white)
                    
                    TextField("Hedef Tutar (\(store.selectedCurrency))", text: $targetAmountText)
                        .keyboardType(.decimalPad)
                        .padding()
                        .background(Theme.cardBackground)
                        .cornerRadius(12)
                        .foregroundColor(.white)
                    
                    TextField("Başlangıçta Biriken Tutar (Opsiyonel)", text: $initialAmountText)
                        .keyboardType(.decimalPad)
                        .padding()
                        .background(Theme.cardBackground)
                        .cornerRadius(12)
                        .foregroundColor(.white)
                    
                    HStack(spacing: 12) {
                        ForEach(colors, id: \.self) { hex in
                            Circle()
                                .fill(Color(hex: hex))
                                .frame(width: 36, height: 36)
                                .overlay(
                                    Circle()
                                        .stroke(Color.white, lineWidth: selectedColorHex == hex ? 3 : 0)
                                )
                                .onTapGesture {
                                    selectedColorHex = hex
                                    Haptic.light()
                                }
                        }
                    }
                    .padding(.vertical, 8)
                    
                    Spacer()
                    
                    Button {
                        if let target = Double(targetAmountText.replacingOccurrences(of: ",", with: ".")), !title.isEmpty {
                            let initial = Double(initialAmountText.replacingOccurrences(of: ",", with: ".")) ?? 0.0
                            let item = SavingsGoalItem(
                                title: title,
                                targetAmount: target,
                                currentAmount: initial,
                                colorHex: selectedColorHex
                            )
                            store.addSavingsGoal(item)
                            dismiss()
                        }
                    } label: {
                        Text("Hedefi Oluştur")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Theme.emeraldGradient)
                            .foregroundColor(.white)
                            .cornerRadius(14)
                    }
                    .disabled(title.isEmpty || targetAmountText.isEmpty)
                }
                .padding()
            }
            .navigationTitle("Yeni Birikim Hedefi")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Kapat") { dismiss() }
                }
            }
        }
    }
}
