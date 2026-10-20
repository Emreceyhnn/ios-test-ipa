import Foundation
import SwiftUI

// MARK: - App Color Palette
enum Theme {
    static let background = Color(hex: "#0B101B")
    static let secondaryBackground = Color(hex: "#151D2E")
    static let cardBackground = Color(hex: "#1E293B")
    static let cardBorder = Color(hex: "#334155").opacity(0.6)
    
    // Accents
    static let emerald = Color(hex: "#10B981")
    static let emeraldGlow = Color(hex: "#059669")
    static let rose = Color(hex: "#F43F5E")
    static let indigo = Color(hex: "#6366F1")
    static let cyan = Color(hex: "#06B6D4")
    static let amber = Color(hex: "#F59E0B")
    static let purple = Color(hex: "#8B5CF6")
    
    // Gradients
    static let primaryGradient = LinearGradient(
        colors: [Color(hex: "#6366F1"), Color(hex: "#3B82F6")],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    static let emeraldGradient = LinearGradient(
        colors: [Color(hex: "#10B981"), Color(hex: "#059669")],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    static let roseGradient = LinearGradient(
        colors: [Color(hex: "#F43F5E"), Color(hex: "#BE123C")],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    static let cyanGradient = LinearGradient(
        colors: [Color(hex: "#06B6D4"), Color(hex: "#0284C7")],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

// MARK: - Color Hex Extension
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - Haptic Feedback Utility
enum Haptic {
    static func light() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
    
    static func medium() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }
    
    static func heavy() {
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
    }
    
    static func success() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
    
    static func warning() {
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
    }
    
    static func error() {
        UINotificationFeedbackGenerator().notificationOccurred(.error)
    }
}

// MARK: - Glassmorphism Card Modifier
struct GlassCardModifier: ViewModifier {
    var cornerRadius: CGFloat = 20
    var strokeColor: Color = Theme.cardBorder
    
    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Theme.cardBackground.opacity(0.75))
                    .background(
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .fill(.ultraThinMaterial)
                    )
            )
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(strokeColor, lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.25), radius: 10, x: 0, y: 5)
    }
}

extension View {
    func glassCard(cornerRadius: CGFloat = 20, strokeColor: Color = Theme.cardBorder) -> some View {
        modifier(GlassCardModifier(cornerRadius: cornerRadius, strokeColor: strokeColor))
    }
}
