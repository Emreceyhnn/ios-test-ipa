import SwiftUI

// MARK: - Settings View
struct SettingsView: View {
    @ObservedObject var store = AppStore.shared
    @ObservedObject var supabase = SupabaseService.shared
    @ObservedObject var healthKit = HealthKitManager.shared
    
    @State private var showingSupabaseConfig = false
    @State private var inputUrl: String = ""
    @State private var inputKey: String = ""
    
    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        // Profile Banner
                        profileCard
                        
                        // Currency Selection
                        currencySection
                        
                        // Security & Biometrics
                        securitySection
                        
                        // HealthKit & Cloud Sync
                        cloudSyncSection
                        
                        // App Info
                        appInfoSection
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 32)
                }
            }
            .navigationTitle("Ayarlar")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showingSupabaseConfig) {
                supabaseConfigSheet
            }
        }
    }
    
    private var profileCard: some View {
        HStack(spacing: 16) {
            Image(systemName: "person.crop.circle.fill")
                .font(.system(size: 52))
                .foregroundColor(Theme.indigo)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(supabase.currentUserEmail ?? "Kullanıcı")
                    .font(.headline)
                    .foregroundColor(.white)
                Text("Pro Üye • Apple Ekosistemi")
                    .font(.caption)
                    .foregroundColor(Theme.emerald)
            }
            Spacer()
        }
        .padding(18)
        .glassCard(cornerRadius: 20)
    }
    
    private var currencySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Para Birimi")
                .font(.headline)
                .foregroundColor(.white)
            
            HStack(spacing: 12) {
                currencyButton(symbol: "₺", name: "TRY")
                currencyButton(symbol: "$", name: "USD")
                currencyButton(symbol: "€", name: "EUR")
                currencyButton(symbol: "£", name: "GBP")
            }
        }
        .padding(18)
        .glassCard(cornerRadius: 20)
    }
    
    private func currencyButton(symbol: String, name: String) -> some View {
        Button {
            store.selectedCurrency = symbol
            Haptic.light()
        } label: {
            VStack(spacing: 4) {
                Text(symbol)
                    .font(.title2.bold())
                Text(name)
                    .font(.caption2)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(store.selectedCurrency == symbol ? Theme.indigo : Theme.cardBackground)
            .foregroundColor(.white)
            .cornerRadius(12)
        }
    }
    
    private var securitySection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Güvenlik & Biyometri")
                .font(.headline)
                .foregroundColor(.white)
            
            HStack {
                Label("Face ID / Touch ID Kilidi", systemImage: "faceid")
                    .foregroundColor(.white)
                Spacer()
                Image(systemName: "checkmark.seal.fill")
                    .foregroundColor(Theme.emerald)
            }
            
            Button {
                Task {
                    _ = await supabase.authenticateWithBiometrics()
                }
            } label: {
                Text("Biyometrik Kilidi Test Et")
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
    
    private var cloudSyncSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Bulut & Apple Health")
                .font(.headline)
                .foregroundColor(.white)
            
            HStack {
                Label("HealthKit İzin Durumu", systemImage: "heart.fill")
                    .foregroundColor(.white)
                Spacer()
                Text(healthKit.isAuthorized ? "Verildi" : "Bekliyor")
                    .font(.caption.bold())
                    .foregroundColor(healthKit.isAuthorized ? Theme.emerald : Theme.amber)
            }
            
            Button {
                inputUrl = supabase.supabaseUrl
                inputKey = supabase.supabaseAnonKey
                showingSupabaseConfig = true
            } label: {
                HStack {
                    Image(systemName: "externaldrive.badge.icloud")
                    Text("Supabase Bağlantısını Yapılandır")
                }
                .font(.caption.bold())
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(Theme.cyanGradient)
                .foregroundColor(.white)
                .cornerRadius(10)
            }
        }
        .padding(18)
        .glassCard(cornerRadius: 20)
    }
    
    private var appInfoSection: some View {
        VStack(spacing: 6) {
            Text("AuraFit Finance")
                .font(.headline)
                .foregroundColor(.white)
            Text("Sürüm 1.0.0 (Build 2) • Native Swift & SwiftUI")
                .font(.caption2)
                .foregroundColor(.gray)
            Text("TrollStore / Sideloadly / AltStore ile Tam Uyumlu")
                .font(.caption2)
                .foregroundColor(Theme.emerald)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
    }
    
    private var supabaseConfigSheet: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()
                
                VStack(spacing: 20) {
                    TextField("Supabase URL", text: $inputUrl)
                        .padding()
                        .background(Theme.cardBackground)
                        .cornerRadius(12)
                        .foregroundColor(.white)
                    
                    TextField("Anon API Key", text: $inputKey)
                        .padding()
                        .background(Theme.cardBackground)
                        .cornerRadius(12)
                        .foregroundColor(.white)
                    
                    Button("Kaydet") {
                        supabase.updateConfig(url: inputUrl, anonKey: inputKey)
                        showingSupabaseConfig = false
                    }
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Theme.emeraldGradient)
                    .foregroundColor(.white)
                    .cornerRadius(14)
                    
                    Spacer()
                }
                .padding()
            }
            .navigationTitle("Supabase Yapılandırması")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
