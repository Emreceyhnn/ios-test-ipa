import SwiftUI

@main
struct TestApp: App {
    @StateObject private var store = AppStore.shared
    @StateObject private var healthKit = HealthKitManager.shared
    @StateObject private var bluetooth = BluetoothScaleManager.shared
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
                .environmentObject(healthKit)
                .environmentObject(bluetooth)
                .onAppear {
                    // Trigger permissions immediately on launch
                    Task {
                        _ = await healthKit.requestAuthorization()
                    }
                }
        }
    }
}
