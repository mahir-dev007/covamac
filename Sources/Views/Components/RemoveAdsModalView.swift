import SwiftUI

public struct RemoveAdsModalView: View {
    @ObservedObject var adEngine: AdEngineService
    @Environment(\.dismiss) private var dismiss
    
    public init(adEngine: AdEngineService) {
        self.adEngine = adEngine
    }
    
    public var body: some View {
        VStack(spacing: 20) {
            // Header
            HStack {
                if let appIcon = NSImage(named: NSImage.applicationIconName) ?? (Bundle.main.path(forResource: "AppLogo", ofType: "png").flatMap { NSImage(contentsOfFile: $0) }) ?? NSImage(contentsOfFile: "AppIcon_1024.png") {
                    Image(nsImage: appIcon)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 32, height: 32)
                        .clipShape(RoundedRectangle(cornerRadius: 7))
                } else {
                    Image(systemName: "shield.lefthalf.filled.badge.checkmark")
                        .font(.system(size: 28))
                        .foregroundColor(CovaTheme.accentAmber)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Ad-Free Pro Experience")
                        .font(.system(size: 18, weight: .bold))
                    Text("Redeem a license key or promo code to hide sponsor banners")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                Spacer()
                Button(action: {
                    dismiss()
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            
            Divider()
            
            // Description
            VStack(alignment: .leading, spacing: 12) {
                Text("All features in CovaMac are 100% unrestricted and free to use forever:")
                    .font(.system(size: 13, weight: .medium))
                
                VStack(alignment: .leading, spacing: 6) {
                    FeatureCheckRow(title: "Deep Leftovers Hunter & Pro Uninstaller")
                    FeatureCheckRow(title: "Cryptographic Duplicate File Finder")
                    FeatureCheckRow(title: "Hardware Stress & Benchmark Testers (CPU, RAM, Disk)")
                    FeatureCheckRow(title: "Comprehensive Battery Health & Live Charger Specs")
                    FeatureCheckRow(title: "Top Menu Bar Live Status Monitor")
                }
                .padding(.leading, 6)
                
                Text("We display non-intrusive sponsor cards to keep CovaMac free. You can remove all ads at any time.")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            .padding(14)
            .background(Color(NSColor.controlBackgroundColor).opacity(0.4))
            .cornerRadius(10)
            
            // License Key Input
            VStack(alignment: .leading, spacing: 8) {
                Text("Redeem License Key / Promo Code")
                    .font(.system(size: 12, weight: .semibold))
                
                HStack {
                    TextField("Enter code (e.g. COVAPRO)", text: $adEngine.licenseKeyInput)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 13, design: .monospaced))
                    
                    Button(action: {
                        _ = adEngine.validateLicenseKey()
                    }) {
                        Text("Redeem")
                            .font(.system(size: 12, weight: .bold))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(CovaTheme.primaryGradient)
                            .foregroundColor(.white)
                            .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                }
                
                if !adEngine.licenseStatusMessage.isEmpty {
                    Text(adEngine.licenseStatusMessage)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(adEngine.isAdFreeUnlocked ? .green : .orange)
                }
            }
            
            Divider()
            
            // Ad-Free Status
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Ad-Free Mode Status")
                        .font(.system(size: 13, weight: .semibold))
                    Text(adEngine.isAdFreeUnlocked ? "Pro active: All sponsor cards hidden" : "Standard mode: Sponsor cards currently visible")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if adEngine.isAdFreeUnlocked {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundColor(.green)
                        Text("Active")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.green)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.green.opacity(0.15))
                    .cornerRadius(6)
                } else {
                    Text("Standard")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.gray.opacity(0.15))
                        .cornerRadius(6)
                }
            }
            
            // Footer Done Button
            Button(action: {
                dismiss()
            }) {
                Text("Done")
                    .font(.system(size: 13, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(8)
            }
            .buttonStyle(.plain)
        }
        .padding(24)
        .frame(width: 460)
    }
}

private struct FeatureCheckRow: View {
    let title: String
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(CovaTheme.accentGreen)
                .font(.system(size: 13))
            Text(title)
                .font(.system(size: 12))
        }
    }
}
