import SwiftUI

// MARK: - Savings Goals View
struct SavingsGoalsView: View {
    @ObservedObject var store = AppStore.shared
    @State private var showingDepositSheet = false
    @State private var selectedGoal: SavingsGoalItem?
    
    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 16) {
                        ForEach(store.savingsGoals) { goal in
                            goalCard(goal)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 32)
                }
            }
            .navigationTitle("Birikim Hedefleri")
            .navigationBarTitleDisplayMode(.inline)
        }
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
                store.depositToGoal(id: goal.id, amount: 1000)
            } label: {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text("+\(store.selectedCurrency)1.000 Ekle")
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
}
