import SwiftUI
import Charts
import PhotosUI

// MARK: - Health & Body Composition View (Pure CoreMotion & OKOK Photo Scanner)
struct HealthTrackerView: View {
    @ObservedObject var healthKit = HealthKitManager.shared
    @ObservedObject var store = AppStore.shared
    @StateObject private var ocr = ScaleOCRScanner.shared
    
    // Photo Picker States
    @State private var selectedPhotoItem: PhotosPickerItem? = nil
    @State private var selectedImage: UIImage? = nil
    @State private var showingScanSuccessSheet = false
    @State private var manualWeightText: String = ""
    @State private var showingManualSheet = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        // Top Sensor Bar
                        motionSensorStatusBar
                        
                        // OKOK Photo Import & AI Vision Card
                        okokPhotoScannerCard
                        
                        // Today's CoreMotion Walking & Calorie Metrics
                        todayMotionSummaryCards
                        
                        // Body Metrics Detail Card (If Scanned from OKOK)
                        if let result = ocr.lastResult, result.weightKg > 0 {
                            scannedBodyMetricsCard(result)
                        }
                        
                        // Weekly Steps Trend Chart
                        weeklyTrendsChart
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 32)
                }
            }
            .navigationTitle("Sağlık & Vücut Analizi")
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
            .sheet(isPresented: $showingManualSheet) {
                manualWeightSheet
            }
            .sheet(isPresented: $showingScanSuccessSheet) {
                if let res = ocr.lastResult {
                    scanConfirmationSheet(res)
                }
            }
            .onChange(of: selectedPhotoItem) { newItem in
                Task {
                    if let data = try? await newItem?.loadTransferable(type: Data.self),
                       let uiImage = UIImage(data: data) {
                        selectedImage = uiImage
                        if let result = await ocr.processScaleImage(uiImage) {
                            // Update weight
                            healthKit.latestWeightKg = result.weightKg
                            showingScanSuccessSheet = true
                            await store.syncAllHealthDataToDatabase()
                        }
                    }
                }
            }
            .task {
                healthKit.startMotionTracking()
            }
        }
    }
    
    // MARK: - Motion Sensor Status Bar
    private var motionSensorStatusBar: some View {
        HStack {
            Circle()
                .fill(healthKit.isMotionAuthorized ? Theme.emerald : Theme.amber)
                .frame(width: 8, height: 8)
            
            Text(healthKit.isMotionAuthorized ? "CoreMotion Donanım Sensörü Aktif" : "Hareket İzni Bekleniyor")
                .font(.caption.bold())
                .foregroundColor(healthKit.isMotionAuthorized ? Theme.emerald : Theme.amber)
            
            Spacer()
            
            Text("Adımlar Canlı")
                .font(.caption2)
                .foregroundColor(.gray)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .glassCard(cornerRadius: 12)
    }
    
    // MARK: - OKOK Photo Scanner Card (The Highlight Feature)
    private var okokPhotoScannerCard: some View {
        VStack(spacing: 16) {
            HStack {
                Label("OKOK Ekranı ile Kilo & Analiz Çek", systemImage: "sparkles")
                    .font(.headline)
                    .foregroundColor(.white)
                Spacer()
                Image(systemName: "camera.viewfinder")
                    .foregroundColor(Theme.cyan)
            }
            
            // Prominent Display
            VStack(spacing: 4) {
                Text(healthKit.latestWeightKg != nil ? String(format: "%.2f", healthKit.latestWeightKg!) : "--.--")
                    .font(.system(size: 56, weight: .bold, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.white, Theme.cyan],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                
                Text("kg (Son Güncel Ölçüm)")
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Color.black.opacity(0.2))
            .cornerRadius(18)
            
            // Action Buttons
            HStack(spacing: 12) {
                // Photos Picker Button
                PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                    HStack {
                        Image(systemName: "photo.on.rectangle.angled")
                        Text(ocr.isScanning ? "Taranıyor..." : "Fotoğraf Seç / Paylaş")
                    }
                    .font(.subheadline.bold())
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Theme.cyanGradient)
                    .foregroundColor(.white)
                    .cornerRadius(14)
                    .shadow(color: Theme.cyan.opacity(0.3), radius: 8, x: 0, y: 4)
                }
                
                // Manual Button
                Button {
                    showingManualSheet = true
                } label: {
                    HStack {
                        Image(systemName: "square.and.pencil")
                        Text("Manuel")
                    }
                    .font(.subheadline.bold())
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .background(Theme.cardBackground)
                    .foregroundColor(.white)
                    .cornerRadius(14)
                }
            }
            
            Text("OKOK uygulamasındaki paylaşım ekran görüntüsünü seçtiğinizde tüm veriler (Kilo, Yağ, Kas, Su, BMI vb.) anında okunur ve kaydedilir.")
                .font(.caption2)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
        }
        .padding(18)
        .glassCard(cornerRadius: 22, strokeColor: Theme.cyan.opacity(0.4))
    }
    
    // MARK: - CoreMotion Step & Walking Cards
    private var todayMotionSummaryCards: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
            // Steps
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "figure.walk")
                        .foregroundColor(Theme.emerald)
                    Text("Bugün Adım")
                        .font(.caption.bold())
                        .foregroundColor(.gray)
                }
                Text("\(healthKit.todaySteps)")
                    .font(.title.bold())
                    .foregroundColor(.white)
                Text("Hedef: 10.000 adım")
                    .font(.caption2)
                    .foregroundColor(.gray)
            }
            .padding(16)
            .glassCard(cornerRadius: 18)
            
            // Distance
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "location.fill")
                        .foregroundColor(Theme.cyan)
                    Text("Mesafe")
                        .font(.caption.bold())
                        .foregroundColor(.gray)
                }
                Text("\(String(format: "%.2f", healthKit.todayDistanceMeters / 1000)) km")
                    .font(.title.bold())
                    .foregroundColor(.white)
                Text("iPhone M-sensörü")
                    .font(.caption2)
                    .foregroundColor(Theme.cyan)
            }
            .padding(16)
            .glassCard(cornerRadius: 18)
            
            // Active Calories
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "flame.fill")
                        .foregroundColor(Theme.rose)
                    Text("Yakılan Kalori")
                        .font(.caption.bold())
                        .foregroundColor(.gray)
                }
                Text("\(String(format: "%.0f", healthKit.todayActiveCalories)) kcal")
                    .font(.title2.bold())
                    .foregroundColor(.white)
                Text("Yürüyüş ve hareket")
                    .font(.caption2)
                    .foregroundColor(.gray)
            }
            .padding(16)
            .glassCard(cornerRadius: 18)
            
            // Cloud Sync State
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "icloud.fill")
                        .foregroundColor(Theme.indigo)
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
    
    // MARK: - Scanned Body Metrics Card
    private func scannedBodyMetricsCard(_ result: OKOKScanResult) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("OKOK Vücut Kompozisyonu Analizi", systemImage: "person.text.rectangle.fill")
                .font(.headline)
                .foregroundColor(.white)
            
            Divider().background(Color.white.opacity(0.1))
            
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                if let bmi = result.bmi {
                    metricItem(label: "BMI (VKI)", value: String(format: "%.1f", bmi), unit: "")
                }
                if let fat = result.bodyFatPercent {
                    metricItem(label: "Vücut Yağı", value: String(format: "%.1f", fat), unit: "%")
                }
                if let fatKg = result.bodyFatWeightKg {
                    metricItem(label: "Yağ Kütlesi", value: String(format: "%.1f", fatKg), unit: "kg")
                }
                if let muscle = result.skeletalMusclePercent {
                    metricItem(label: "İskelet Kası", value: String(format: "%.1f", muscle), unit: "%")
                }
                if let muscleKg = result.skeletalMuscleWeightKg {
                    metricItem(label: "Kas Kütlesi", value: String(format: "%.1f", muscleKg), unit: "kg")
                }
                if let water = result.waterPercent {
                    metricItem(label: "Su Oranı", value: String(format: "%.1f", water), unit: "%")
                }
                if let bmr = result.bmrKcal {
                    metricItem(label: "Metabolizma", value: String(format: "%.0f", bmr), unit: "kcal")
                }
                if let vfat = result.visceralFat {
                    metricItem(label: "İç Yağlanma (V-Fat)", value: String(format: "%.1f", vfat), unit: "")
                }
            }
        }
        .padding(18)
        .glassCard(cornerRadius: 20)
    }
    
    private func metricItem(label: String, value: String, unit: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption2)
                .foregroundColor(.gray)
            HStack(spacing: 2) {
                Text(value)
                    .font(.subheadline.bold())
                    .foregroundColor(.white)
                Text(unit)
                    .font(.caption2)
                    .foregroundColor(.gray)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(Color.white.opacity(0.04))
        .cornerRadius(10)
    }
    
    // MARK: - Weekly Trends Chart
    private var weeklyTrendsChart: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Haftalık Adım Trendi (CoreMotion)")
                .font(.headline)
                .foregroundColor(.white)
            
            let nonZero = healthKit.weeklyRecords.filter { $0.steps > 0 }
            if !nonZero.isEmpty {
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
                VStack(spacing: 8) {
                    Image(systemName: "figure.walk")
                        .font(.system(size: 32))
                        .foregroundColor(.gray.opacity(0.4))
                    Text("Adım verileriniz telefonunuz cebinizdeyken toplanmaktadır")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 140)
            }
        }
        .padding(18)
        .glassCard(cornerRadius: 20)
    }
    
    // MARK: - Scan Confirmation Sheet
    private func scanConfirmationSheet(_ res: OKOKScanResult) -> some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()
                
                VStack(spacing: 20) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 56))
                        .foregroundColor(Theme.emerald)
                    
                    Text("OKOK Ekranı Başarıyla Okundu!")
                        .font(.title3.bold())
                        .foregroundColor(.white)
                    
                    VStack(spacing: 8) {
                        Text("\(String(format: "%.2f", res.weightKg)) kg")
                            .font(.system(size: 42, weight: .bold, design: .rounded))
                            .foregroundColor(Theme.cyan)
                        
                        if let fat = res.bodyFatPercent {
                            Text("Vücut Yağı: %\(String(format: "%.1f", fat))")
                                .foregroundColor(.gray)
                        }
                        if let bmi = res.bmi {
                            Text("BMI: \(String(format: "%.1f", bmi))")
                                .foregroundColor(.gray)
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Theme.cardBackground)
                    .cornerRadius(16)
                    
                    Spacer()
                    
                    Button("Tamam & Kaydet") {
                        showingScanSuccessSheet = false
                    }
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Theme.emeraldGradient)
                    .foregroundColor(.white)
                    .cornerRadius(14)
                }
                .padding()
            }
            .navigationTitle("Ölçüm Özeti")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
    
    // MARK: - Manual Weight Sheet
    private var manualWeightSheet: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()
                
                VStack(spacing: 20) {
                    TextField("Kilonuz (kg, Örn: 91.95)", text: $manualWeightText)
                        .keyboardType(.decimalPad)
                        .padding()
                        .background(Theme.cardBackground)
                        .cornerRadius(12)
                        .foregroundColor(.white)
                    
                    Button {
                        if let weight = Double(manualWeightText.replacingOccurrences(of: ",", with: ".")) {
                            Task {
                                healthKit.latestWeightKg = weight
                                await store.syncAllHealthDataToDatabase()
                                showingManualSheet = false
                            }
                        }
                    } label: {
                        Text("Kaydet")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Theme.emeraldGradient)
                            .foregroundColor(.white)
                            .cornerRadius(14)
                    }
                    .disabled(manualWeightText.isEmpty)
                    
                    Spacer()
                }
                .padding()
            }
            .navigationTitle("Manuel Kilo Girişi")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Kapat") { showingManualSheet = false }
                }
            }
        }
    }
}
