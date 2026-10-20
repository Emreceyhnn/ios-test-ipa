import SwiftUI

struct ContentView: View {
    @State private var counter: Int = 0
    @State private var isOnline: Bool = true
    @State private var lastActionTime: String = "Henüz işlem yapılmadı"
    
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.07, green: 0.09, blue: 0.15), Color(red: 0.12, green: 0.15, blue: 0.25)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 24) {
                // Header Card
                VStack(spacing: 8) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 56))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.cyan, .blue],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .padding(.top, 16)
                    
                    Text("iOS Test IPA")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    
                    Text("GitHub Actions Derleme Başarılı")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color.white.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                )
                
                // Status Section
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Label("Cihaz Durumu", systemImage: "iphone")
                            .font(.headline)
                            .foregroundColor(.white)
                        Spacer()
                        Circle()
                            .fill(isOnline ? Color.green : Color.orange)
                            .frame(width: 10, height: 10)
                        Text(isOnline ? "Aktif" : "Beklemede")
                            .font(.caption)
                            .foregroundColor(isOnline ? .green : .orange)
                    }
                    
                    Divider().background(Color.white.opacity(0.1))
                    
                    HStack {
                        Text("Son İşlem:")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                        Spacer()
                        Text(lastActionTime)
                            .font(.subheadline)
                            .foregroundColor(.cyan)
                    }
                    
                    HStack {
                        Text("Tıklama Sayacı:")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                        Spacer()
                        Text("\(counter)")
                            .font(.system(size: 20, weight: .bold, design: .monospaced))
                            .foregroundColor(.white)
                    }
                }
                .padding(20)
                .background(Color.white.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                )
                
                // Interactive Buttons
                VStack(spacing: 12) {
                    Button(action: {
                        counter += 1
                        let formatter = DateFormatter()
                        formatter.dateFormat = "HH:mm:ss"
                        lastActionTime = formatter.string(from: Date())
                        let generator = UIImpactFeedbackGenerator(style: .medium)
                        generator.impactOccurred()
                    }) {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                            Text("Butonu Test Et")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            LinearGradient(
                                colors: [Color.blue, Color.cyan],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .foregroundColor(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .shadow(color: Color.blue.opacity(0.4), radius: 8, x: 0, y: 4)
                    }
                    
                    Button(action: {
                        counter = 0
                        lastActionTime = "Sıfırlandı"
                        let generator = UINotificationFeedbackGenerator()
                        generator.notificationOccurred(.warning)
                    }) {
                        HStack {
                            Image(systemName: "arrow.counterclockwise")
                            Text("Sıfırla")
                                .fontWeight(.medium)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.white.opacity(0.08))
                        .foregroundColor(.white.opacity(0.8))
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                }
                
                Spacer()
                
                // Footer
                VStack(spacing: 4) {
                    Text("TrollStore / AltStore / Sideloadly / Scarlet ile Uyumlu")
                        .font(.caption2)
                        .foregroundColor(.gray)
                    Text("v1.0.0 (Build 1)")
                        .font(.caption2)
                        .foregroundColor(.gray.opacity(0.7))
                }
                .padding(.bottom, 8)
            }
            .padding(.horizontal, 20)
            .padding(.top, 10)
        }
    }
}
