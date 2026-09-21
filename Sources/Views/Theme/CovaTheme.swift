import SwiftUI

public struct CovaTheme {
    // Primary Accents
    public static let primaryBlue = Color(red: 0.05, green: 0.50, blue: 1.00)
    public static let primaryTeal = Color(red: 0.12, green: 0.82, blue: 0.80)
    public static let accentTeal = primaryTeal
    public static let accentPurple = Color(red: 0.68, green: 0.32, blue: 0.98)
    public static let accentAmber = Color(red: 1.00, green: 0.65, blue: 0.15)
    public static let accentGreen = Color(red: 0.20, green: 0.85, blue: 0.45)
    public static let accentRed = Color(red: 1.00, green: 0.27, blue: 0.33)
    
    // Gradients
    public static let primaryGradient = LinearGradient(
        colors: [primaryBlue, primaryTeal],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    public static let purpleGradient = LinearGradient(
        colors: [accentPurple, primaryBlue],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    public static let amberGradient = LinearGradient(
        colors: [accentAmber, Color.orange],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    public static let greenGradient = LinearGradient(
        colors: [accentGreen, Color.teal],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    // Surface & Glassmorphic Backgrounds
    public static let cardBackground = Color(NSColor.windowBackgroundColor).opacity(0.65)
    public static let glassBorder = Color.white.opacity(0.12)
    public static let subtleDivider = Color.gray.opacity(0.2)
}

extension View {
    public func covaCardStyle(padding: CGFloat = 16) -> some View {
        self
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color(NSColor.controlBackgroundColor).opacity(0.55))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(CovaTheme.glassBorder, lineWidth: 1)
                    )
                    .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 3)
            )
    }
}

extension Color {
    public init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")
        
        var rgb: UInt64 = 0
        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else { return nil }
        
        let length = hexSanitized.count
        let r, g, b, a: Double
        if length == 6 {
            r = Double((rgb & 0xFF0000) >> 16) / 255.0
            g = Double((rgb & 0x00FF00) >> 8) / 255.0
            b = Double(rgb & 0x0000FF) / 255.0
            a = 1.0
        } else if length == 8 {
            r = Double((rgb & 0xFF000000) >> 24) / 255.0
            g = Double((rgb & 0x00FF0000) >> 16) / 255.0
            b = Double((rgb & 0x0000FF00) >> 8) / 255.0
            a = Double(rgb & 0x000000FF) / 255.0
        } else {
            return nil
        }
        
        self.init(.sRGB, red: r, green: g, blue: b, opacity: a)
    }
}
