import SwiftUI

public struct SettingsView: View {
    @ObservedObject var adEngine: AdEngineService
    
    @AppStorage("tempUnitIsFahrenheit") private var tempUnitIsFahrenheit: Bool = false
    @AppStorage("confirmBeforeTrash") private var confirmBeforeTrash: Bool = true
    @AppStorage("showCpuInMenuBar") private var showCpuInMenuBar: Bool = true
    @AppStorage("showBatteryInMenuBar") private var showBatteryInMenuBar: Bool = true
    @AppStorage("monitoringInterval") private var monitoringInterval: Double = 3.0
    
    public init(adEngine: AdEngineService) {
        self.adEngine = adEngine
    }
    
    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header Bar
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Preferences & Settings")
                            .font(.system(size: 22, weight: .bold))
                        Text("Configure system monitoring, display units, and pro license status.")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                }
                .covaCardStyle()
                
                // Pro License & Ad-Free Section
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Image(systemName: adEngine.isAdFreeUnlocked ? "checkmark.seal.fill" : "shield.lefthalf.filled.badge.checkmark")
                            .foregroundColor(adEngine.isAdFreeUnlocked ? CovaTheme.accentGreen : CovaTheme.accentAmber)
                            .font(.system(size: 16))
                        Text("CovaMac Pro License")
                            .font(.system(size: 15, weight: .bold))
                        
                        Spacer()
                        
                        Text(adEngine.isAdFreeUnlocked ? "AD-FREE ACTIVE" : "STANDARD")
                            .font(.system(size: 9, weight: .black))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(adEngine.isAdFreeUnlocked ? Color.green.opacity(0.18) : Color.blue.opacity(0.18))
                            .foregroundColor(adEngine.isAdFreeUnlocked ? .green : .blue)
                            .cornerRadius(4)
                    }
                    
                    Divider()
                    
                    if adEngine.isAdFreeUnlocked {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Pro status is active. All sponsor banners and recommendation cards are completely hidden.")
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                        }
                    } else {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("All features in CovaMac are free. Support development and remove all sponsor recommendation banners by entering a license key or promo code.")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                            
                            Button(action: {
                                adEngine.showRemoveAdsModal = true
                            }) {
                                HStack(spacing: 6) {
                                    Image(systemName: "key.fill")
                                    Text("Redeem Pro Key / Remove Ads")
                                }
                                .font(.system(size: 12, weight: .bold))
                                .padding(.horizontal, 14)
                                .padding(.vertical, 7)
                                .background(CovaTheme.primaryGradient)
                                .foregroundColor(.white)
                                .cornerRadius(6)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .covaCardStyle()
                
                // General Application Preferences
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Image(systemName: "slider.horizontal.3")
                            .foregroundColor(CovaTheme.primaryBlue)
                        Text("General Preferences")
                            .font(.system(size: 15, weight: .bold))
                    }
                    
                    Divider()
                    
                    // Temperature Unit
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Temperature Unit")
                                .font(.system(size: 13, weight: .semibold))
                            Text("Used in Battery Health and Hardware diagnostics")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Picker("", selection: $tempUnitIsFahrenheit) {
                            Text("Celsius (°C)").tag(false)
                            Text("Fahrenheit (°F)").tag(true)
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 180)
                    }
                    .padding(.vertical, 4)
                    
                    Divider()
                    
                    // Safe Trashing confirmation
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Confirm Before Trashing Files")
                                .font(.system(size: 13, weight: .semibold))
                            Text("Show a confirmation prompt when uninstalling apps or deleting duplicate files")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Toggle("", isOn: $confirmBeforeTrash)
                            .toggleStyle(.switch)
                    }
                    .padding(.vertical, 4)
                    
                    Divider()
                    
                    // Background refresh rate
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Hardware Telemetry Refresh Rate")
                                .font(.system(size: 13, weight: .semibold))
                            Text("Frequency of background battery and CPU polling")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Picker("", selection: $monitoringInterval) {
                            Text("2 Seconds").tag(2.0)
                            Text("3 Seconds").tag(3.0)
                            Text("5 Seconds").tag(5.0)
                        }
                        .pickerStyle(.menu)
                        .frame(width: 130)
                    }
                }
                .covaCardStyle()
                
                // Top Bar Status Monitor Preferences
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Image(systemName: "menubar.rectangle")
                            .foregroundColor(CovaTheme.primaryTeal)
                        Text("Top Bar Status Monitor Preferences")
                            .font(.system(size: 15, weight: .bold))
                    }
                    
                    Divider()
                    
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Show CPU Load in Menu Bar")
                                .font(.system(size: 13, weight: .semibold))
                            Text("Display real-time CPU percentage directly in the top menu bar")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Toggle("", isOn: $showCpuInMenuBar)
                            .toggleStyle(.switch)
                    }
                    
                    Divider()
                    
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Show Battery Level in Menu Bar")
                                .font(.system(size: 13, weight: .semibold))
                            Text("Display battery charge percentage and charging bolt in the top bar")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Toggle("", isOn: $showBatteryInMenuBar)
                            .toggleStyle(.switch)
                    }
                }
                .covaCardStyle()
                
                // About Section
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 14) {
                        if let appIcon = NSImage(named: NSImage.applicationIconName) ?? (Bundle.main.path(forResource: "AppLogo", ofType: "png").flatMap { NSImage(contentsOfFile: $0) }) ?? NSImage(contentsOfFile: "AppIcon_1024.png") {
                            Image(nsImage: appIcon)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 44, height: 44)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                                .shadow(color: Color.blue.opacity(0.3), radius: 6, x: 0, y: 2)
                        }
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("CovaMac Pro")
                                .font(.system(size: 16, weight: .bold))
                            Text("System Maintenance & Diagnostic Suite for macOS")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                    }
                    
                    Divider()
                    
                    Text("CovaMac is an all-in-one native macOS system maintenance, pro uninstaller, duplicate finder, hardware diagnostic, and battery health suite.")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                    
                    HStack {
                        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
                        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "100"
                        Text("Version \(version) (Build \(build))")
                            .font(.system(size: 11, weight: .semibold, design: .monospaced))
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("Native macOS • Swift 6 & SwiftUI")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                }
                .covaCardStyle()
            }
            .padding(20)
        }
    }
}
