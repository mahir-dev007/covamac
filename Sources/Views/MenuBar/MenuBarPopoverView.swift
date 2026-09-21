import SwiftUI
import AppKit

public struct MenuBarPopoverView: View {
    @ObservedObject var monitor: SystemMonitorService
    @ObservedObject var batteryService: BatteryHealthService
    @ObservedObject var adEngine: AdEngineService
    var onOpenMainWindow: () -> Void
    
    public init(
        monitor: SystemMonitorService,
        batteryService: BatteryHealthService,
        adEngine: AdEngineService,
        onOpenMainWindow: @escaping () -> Void
    ) {
        self.monitor = monitor
        self.batteryService = batteryService
        self.adEngine = adEngine
        self.onOpenMainWindow = onOpenMainWindow
    }
    
    public var body: some View {
        VStack(spacing: 14) {
            // Header
            HStack(spacing: 8) {
                if let appIcon = NSImage(named: NSImage.applicationIconName) ?? (Bundle.main.path(forResource: "AppLogo", ofType: "png").flatMap { NSImage(contentsOfFile: $0) }) ?? NSImage(contentsOfFile: "AppIcon_1024.png") {
                    Image(nsImage: appIcon)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 18, height: 18)
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                } else {
                    Image(systemName: "bolt.shield.fill")
                        .foregroundColor(CovaTheme.primaryBlue)
                        .font(.system(size: 16))
                }
                Text("CovaMac Monitor")
                    .font(.system(size: 13, weight: .bold))
                
                Spacer()
                
                if let charger = batteryService.batteryInfo.charger, charger.isConnected {
                    HStack(spacing: 3) {
                        Image(systemName: "powerplug.fill")
                            .foregroundColor(.orange)
                            .font(.system(size: 10))
                        Text("\(charger.wattage)W")
                            .font(.system(size: 10, weight: .bold))
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.orange.opacity(0.18))
                    .cornerRadius(4)
                }
            }
            
            Divider()
            
            // Real-Time Gauges Row
            HStack(spacing: 12) {
                MiniMetricBox(
                    title: "CPU",
                    value: "\(Int(round(monitor.cpuUsagePercent)))%",
                    icon: "cpu",
                    color: monitor.cpuUsagePercent > 75 ? .orange : .blue
                )
                
                MiniMetricBox(
                    title: "RAM",
                    value: "\(String(format: "%.1f", monitor.memoryUsedGB))G",
                    icon: "memorychip",
                    color: .purple
                )
                
                MiniMetricBox(
                    title: "Battery",
                    value: "\(batteryService.batteryInfo.stateOfCharge)%",
                    icon: batteryService.batteryInfo.isCharging ? "battery.100.bolt" : "battery.100",
                    color: .green
                )
                
                MiniMetricBox(
                    title: "Disk",
                    value: "\(Int(monitor.diskAvailableGB))G",
                    icon: "internaldrive",
                    color: .teal
                )
            }
            
            Divider()
            
            // Quick Actions: Clean Junk & Purge RAM
            HStack(spacing: 8) {
                Button(action: {
                    monitor.cleanQuickJunk()
                }) {
                    HStack(spacing: 5) {
                        if monitor.isCleaningJunk {
                            ProgressView()
                                .scaleEffect(0.6)
                                .frame(width: 12, height: 12)
                        } else {
                            Image(systemName: "sparkles")
                                .foregroundColor(CovaTheme.accentAmber)
                                .font(.system(size: 10))
                        }
                        Text(monitor.isCleaningJunk ? "Cleaning..." : "Clean Junk")
                            .font(.system(size: 10, weight: .bold))
                        Spacer()
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .background(Color.gray.opacity(0.12))
                    .cornerRadius(6)
                }
                .buttonStyle(.plain)
                .disabled(monitor.isCleaningJunk)
                
                Button(action: {
                    monitor.purgeInactiveRAM()
                }) {
                    HStack(spacing: 5) {
                        if monitor.isPurgingRAM {
                            ProgressView()
                                .scaleEffect(0.6)
                                .frame(width: 12, height: 12)
                        } else {
                            Image(systemName: "memorychip")
                                .foregroundColor(CovaTheme.accentPurple)
                                .font(.system(size: 10))
                        }
                        Text(monitor.isPurgingRAM ? "Purging..." : "Purge RAM")
                            .font(.system(size: 10, weight: .bold))
                        Spacer()
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .background(Color.gray.opacity(0.12))
                    .cornerRadius(6)
                }
                .buttonStyle(.plain)
                .disabled(monitor.isPurgingRAM)
            }
            
            // Compact Sponsor Card (Hidden if Ad-Free Pro is unlocked)
            if !adEngine.isAdFreeUnlocked {
                let ad = adEngine.currentSponsorAd
                Button(action: {
                    adEngine.recordAdClick(ad: ad)
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: ad.iconSystemName)
                            .font(.system(size: 12))
                            .foregroundColor(CovaTheme.primaryBlue)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(ad.title)
                                .font(.system(size: 10, weight: .bold))
                                .lineLimit(1)
                            Text(ad.tagline)
                                .font(.system(size: 9))
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                        Spacer()
                        Image(systemName: "arrow.up.right")
                            .font(.system(size: 9))
                            .foregroundColor(.secondary)
                    }
                    .padding(8)
                    .background(Color.blue.opacity(0.08))
                    .cornerRadius(6)
                }
                .buttonStyle(.plain)
                
                Divider()
            }
            
            // Footer Navigation Buttons
            HStack {
                Button("Open CovaMac") {
                    onOpenMainWindow()
                }
                .font(.system(size: 11, weight: .bold))
                .buttonStyle(.borderedProminent)
                
                Spacer()
                
                Button("Quit") {
                    NSApplication.shared.terminate(nil)
                }
                .font(.system(size: 11))
                .buttonStyle(.plain)
                .foregroundColor(.secondary)
            }
        }
        .padding(14)
        .frame(width: 290)
    }
}

private struct MiniMetricBox: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundColor(color)
            Text(value)
                .font(.system(size: 12, weight: .bold, design: .rounded))
            Text(title)
                .font(.system(size: 9))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(6)
    }
}
