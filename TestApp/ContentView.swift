import SwiftUI

// MARK: - Main Root ContentView with TabBar & Biometric Gate
struct ContentView: View {
    @ObservedObject var supabase = SupabaseService.shared
    @State private var selectedTab: Int = 0
    
    init() {
        // Customize TabBar Appearance for Glassmorphism
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(Color(hex: "#0F172A").opacity(0.95))
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }
    
    var body: some View {
        TabView(selection: $selectedTab) {
            DashboardView()
                .tabItem {
                    Label("Genel Bakış", systemImage: "square.grid.2x2.fill")
                }
                .tag(0)
            
            TransactionsView()
                .tabItem {
                    Label("İşlemler", systemImage: "chart.pie.fill")
                }
                .tag(1)
            
            HealthTrackerView()
                .tabItem {
                    Label("Sağlık & Analiz", systemImage: "heart.fill")
                }
                .tag(2)
            
            SubscriptionsView()
                .tabItem {
                    Label("Abonelik", systemImage: "repeat.circle.fill")
                }
                .tag(3)
            
            SplitBillView()
                .tabItem {
                    Label("Hesap Bölüş", systemImage: "person.2.fill")
                }
                .tag(4)
            
            SavingsGoalsView()
                .tabItem {
                    Label("Birikim", systemImage: "target")
                }
                .tag(5)
            
            SettingsView()
                .tabItem {
                    Label("Ayarlar", systemImage: "gearshape.fill")
                }
                .tag(6)
        }
        .tint(Theme.emerald)
    }
}
