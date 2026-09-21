import SwiftUI

public struct CircularGaugeView: View {
    public let title: String
    public let value: Double // 0.0 to 100.0
    public let displayString: String
    public let subtitle: String
    public let icon: String
    public let gradient: LinearGradient
    
    public init(
        title: String,
        value: Double,
        displayString: String,
        subtitle: String,
        icon: String,
        gradient: LinearGradient = CovaTheme.primaryGradient
    ) {
        self.title = title
        self.value = max(0.0, min(100.0, value))
        self.displayString = displayString
        self.subtitle = subtitle
        self.icon = icon
        self.gradient = gradient
    }
    
    public var body: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(CovaTheme.primaryTeal)
                    .font(.system(size: 14, weight: .bold))
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.secondary)
                Spacer()
            }
            
            ZStack {
                // Background Track
                Circle()
                    .stroke(Color.gray.opacity(0.18), lineWidth: 10)
                    .frame(width: 90, height: 90)
                
                // Active Progress
                Circle()
                    .trim(from: 0.0, to: CGFloat(value / 100.0))
                    .stroke(gradient, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                    .frame(width: 90, height: 90)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 0.6), value: value)
                
                // Centered text
                VStack(spacing: 2) {
                    Text(displayString)
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                    Text(subtitle)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.secondary)
                }
            }
            .padding(.vertical, 4)
        }
        .covaCardStyle()
    }
}

public struct StatRowView: View {
    public let title: String
    public let value: String
    public let icon: String
    public var iconColor: Color = CovaTheme.primaryBlue
    
    public init(title: String, value: String, icon: String, iconColor: Color = CovaTheme.primaryBlue) {
        self.title = title
        self.value = value
        self.icon = icon
        self.iconColor = iconColor
    }
    
    public var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(iconColor)
                .frame(width: 22)
            Text(title)
                .font(.system(size: 13))
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundColor(.primary)
        }
        .padding(.vertical, 4)
    }
}
