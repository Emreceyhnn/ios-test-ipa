import SwiftUI
import Charts

// MARK: - Health & Smart Scale View
struct HealthTrackerView: View {
    @ObservedObject var healthKit = HealthKitManager.shared
    @ObservedObject var bluetooth = BluetoothScaleManager.shared
    @ObservedObject var store = AppStore.shared
    
    @State private var manualWeightText: String = ""
    @State private var showingManualInput: Bool = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        // Top Sync Status Bar
                        syncStatusBar
                        
                        // Smart Bluetooth Scale Interactive Card
                        bluetoothScaleCard
                        
                        // Today's Apple Health Ring Metrics
                        todayHealthSummaryCards
                        
                        // Steps & Calories Chart
                        weeklyTrendsChart
                        
                        // Weight Tracking History Chart
                        weightHistoryCard
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 32)
                }
            }
            .navigationTitle("Sağlık & Tartı")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        Task {
                            Haptic.medium()
                            await store.syncAllHealthDataToDatabase()
                        }
                    } label: {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .foregroundColor(Theme.emerald)
                    }
                }
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
    
    // MARK: - Sync Status Bar
    private var syncStatusBar: some View {
        HStack {
            Circle()
                .fill(healthKit.isAuthorized ? Theme.emerald : Theme.amber)
                .frame(width: 8, height: 8)
            
            Text(healthKit.isAuthorized ? "Apple Health Bağlı & Aktif" : "HealthKit İzni Bekleniyor")
                .font(.caption.bold())
                .foregroundColor(healthKit.isAuthorized ? Theme.emerald : Theme.amber)
            
            Spacer()
            
            Button("İzin İste") {
                Task {
                    _ = await healthKit.requestAuthorization()
                }
            }
            .font(.caption2.bold())
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(Theme.cardBackground)
            .foregroundColor(.white)
            .cornerRadius(8)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .glassCard(cornerRadius: 12)
    }
    
    // MARK: - Smart Scale Interactive Card
    private var bluetoothScaleCard: some View {
        VStack(spacing: 16) {
            HStack {
                Label("Bluetooth Akıllı Tartı", systemImage: "wave.3.right.circle.fill")
                    .font(.headline)
                    .foregroundColor(.white)
                
                Spacer()
                
                Text(bluetooth.statusMessage)
                    .font(.caption)
                    .foregroundColor(bluetooth.isConnected ? Theme.emerald : .gray)
            }
            
            // Weight Display
            VStack(spacing: 4) {
                HStack(alignment: .lastTextBaseline, spacing: 6) {
                    Text(bluetooth.liveWeightKg > 0 ? String(format: "%.1f", bluetooth.liveWeightKg) : (healthKit.latestWeightKg != nil ? String(format: "%.1f", healthKit.latestWeightKg!) : "--.-"))
                        .font(.system(size: 54, weight: .bold, design: .rounded))
                        .foregroundColor(bluetooth.isStabilized ? Theme.emerald : .white)
                    
                    Text("kg")
                        .font(.title2.bold())
                        .foregroundColor(.gray)
                }
                
                if let fat = bluetooth.bodyFatPercentage {
                    Text("Tahmini Vücut Yağı: %\(String(format: "%.1f", fat))")
                        .font(.caption)
                        .foregroundColor(.cyan)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Color.black.opacity(0.2))
            .cornerRadius(18)
            
            // BLE Actions
            HStack(spacing: 12) {
                Button {
                    if bluetooth.isScanning {
                        bluetooth.stopScanning()
                    } else {
                        bluetooth.startScanning()
                    }
                } label: {
                    HStack {
                        Image(systemName: bluetooth.isScanning ? "stop.circle.fill" : "antenna.radiowaves.left.and.right")
                        Text(bluetooth.isScanning ? "Durdur" : "Tartı Tara")
                    }
                    .font(.subheadline.bold())
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(bluetooth.isScanning ? Theme.rose.opacity(0.3) : Theme.cardBackground)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                
                // Simulation Button for Testing without Physical Scale
                Button {
                    bluetooth.simulateScaleReading(targetWeight: 75.2)
                } label: {
                    HStack {
                        Image(systemName: "sparkles")
                        Text("Simüle Et")
                    }
                    .font(.subheadline.bold())
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Theme.cyanGradient)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
            }
            
            // Auto Save to Apple Health & Supabase Button
            if bluetooth.liveWeightKg > 0 {
                Button {
                    Task {
                        let saved = await healthKit.saveWeight(kilograms: bluetooth.liveWeightKg)
                        if saved {
                            await store.syncAllHealthDataToDatabase()
                        }
                    }
                } label: {
                    HStack {
                        Image(systemName: "square.and.arrow.down.fill")
                        Text("Apple Sağlık & DB'ye Kaydet")
                    }
                    .font(.subheadline.bold())
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Theme.emeraldGradient)
                    .foregroundColor(.white)
                    .cornerRadius(14)
                }
            }
        }
        .padding(18)
        .glassCard(cornerRadius: 22, strokeColor: bluetooth.isConnected ? Theme.emerald.opacity(0.5) : Theme.cardBorder)
    }
    
    // MARK: - Health Ring Summary Cards
    private var todayHealthSummaryCards: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
            // Steps
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "figure.walk")
                        .foregroundColor(Theme.emerald)
                    Text("Adım")
                        .font(.caption.bold())
                        .foregroundColor(.gray)
                }
                Text("\(healthKit.todaySteps)")
                    .font(.title2.bold())
                    .foregroundColor(.white)
                Text("Hedef: 10.000")
                    .font(.caption2)
                    .foregroundColor(.gray)
            }
            .padding(16)
            .glassCard(cornerRadius: 18)
            
            // Active Calories
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "flame.fill")
                        .foregroundColor(Theme.rose)
                    Text("Aktif Kalori")
                        .font(.caption.bold())
                        .foregroundColor(.gray)
                }
                Text("\(String(format: "%.0f", healthKit.todayActiveCalories)) kcal")
                    .font(.title2.bold())
                    .foregroundColor(.white)
                Text("Mesafe: \(String(format: "%.1f", healthKit.todayDistanceMeters / 1000)) km")
                    .font(.caption2)
                    .foregroundColor(.gray)
            }
            .padding(16)
            .glassCard(cornerRadius: 18)
            
            // Resting Heart Rate
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "heart.fill")
                        .foregroundColor(.pink)
                    Text("Dinlenme Nabız")
                        .font(.caption.bold())
                        .foregroundColor(.gray)
                }
                Text(healthKit.restingHeartRateBpm != nil ? "\(Int(healthKit.restingHeartRateBpm!)) bpm" : "-- bpm")
                    .font(.title2.bold())
                    .foregroundColor(.white)
                Text("Normal Aralık: 60-80")
                    .font(.caption2)
                    .foregroundColor(.gray)
            }
            .padding(16)
            .glassCard(cornerRadius: 18)
            
            // Cloud Sync State
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "icloud.fill")
                        .foregroundColor(.cyan)
                    Text("Bulut Senkronu")
                        .font(.caption.bold())
                        .foregroundColor(.gray)
                }
                Text("Supabase DB")
                    .font(.title3.bold())
                    .foregroundColor(.white)
                Text("Her ölçümde anında yazılır")
                    .font(.caption2)
                    .foregroundColor(Theme.emerald)
            }
            .padding(16)
            .glassCard(cornerRadius: 18)
        }
    }
    
    // MARK: - Weekly Trends Chart
    private var weeklyTrendsChart: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Haftalık Adım Trendi")
                .font(.headline)
                .foregroundColor(.white)
            
            if !healthKit.weeklyRecords.isEmpty {
                Chart(healthKit.weeklyRecords) { item in
                    BarMark(
                        x: .value("Gün", item.date, unit: .day),
                        y: .value("Adım", item.steps)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Theme.emerald, Theme.cyan],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .cornerRadius(6)
                }
                .frame(height: 160)
            } else {
                Text("Veriler yükleniyor...")
                    .foregroundColor(.gray)
                    .frame(height: 160)
            }
        }
        .padding(18)
        .glassCard(cornerRadius: 20)
    }
    
    // MARK: - Weight History
    private var weightHistoryCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Kilo Gelişimi & Analiz")
                .font(.headline)
                .foregroundColor(.white)
            
            HStack {
                VStack(alignment: .leading) {
                    Text("Son Ölçüm")
                        .font(.caption)
                        .foregroundColor(.gray)
                    Text(healthKit.latestWeightKg != nil ? "\(String(format: "%.1f", healthKit.latestWeightKg!)) kg" : "75.0 kg")
                        .font(.title2.bold())
                        .foregroundColor(.cyan)
                }
                Spacer()
                VStack(alignment: .trailing) {
                    Text("İdeal Kilo Aralığı")
                        .font(.caption)
                        .foregroundColor(.gray)
                    Text("68 - 77 kg")
                        .font(.subheadline.bold())
                        .foregroundColor(Theme.emerald)
                }
            }
            .padding(14)
            .background(Color.white.opacity(0.04))
            .cornerRadius(14)
        }
        .padding(18)
        .glassCard(cornerRadius: 20)
    }
}
