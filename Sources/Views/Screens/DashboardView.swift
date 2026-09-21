import SwiftUI

public struct DashboardView: View {
    @ObservedObject var monitor: SystemMonitorService
    @ObservedObject var batteryService: BatteryHealthService
    @ObservedObject var adEngine: AdEngineService
    
    public init(
        monitor: SystemMonitorService,
        batteryService: BatteryHealthService,
        adEngine: AdEngineService
    ) {
        self.monitor = monitor
        self.batteryService = batteryService
        self.adEngine = adEngine
    }
    
    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header Banner
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Smart System Care")
                            .font(.system(size: 24, weight: .bold))
                        Text("Real-time monitoring, deep optimization, and diagnostic health.")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    HStack(spacing: 10) {
                        Button(action: {
                            monitor.purgeInactiveRAM()
                        }) {
                            HStack(spacing: 6) {
                                if monitor.isPurgingRAM {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                    Text("Purging RAM...")
                                } else {
                                    Image(systemName: "memorychip")
                                    Text("Purge RAM")
                                }
                            }
                            .font(.system(size: 13, weight: .semibold))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 9)
                            .background(CovaTheme.purpleGradient)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                        }
                        .buttonStyle(.plain)
                        .disabled(monitor.isPurgingRAM)
                        
                        Button(action: {
                            monitor.cleanQuickJunk()
                        }) {
                            HStack(spacing: 6) {
                                if monitor.isCleaningJunk {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                    Text("Optimizing...")
                                } else {
                                    Image(systemName: "sparkles")
                                    Text("Quick Clean Junk")
                                }
                            }
                            .font(.system(size: 13, weight: .bold))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 9)
                            .background(CovaTheme.primaryGradient)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                        }
                        .buttonStyle(.plain)
                        .disabled(monitor.isCleaningJunk)
                    }
                }
                .covaCardStyle()
                
                if !monitor.ramPurgedMessage.isEmpty {
                    HStack {
                        Image(systemName: "bolt.fill")
                            .foregroundColor(CovaTheme.accentPurple)
                        Text(monitor.ramPurgedMessage)
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(CovaTheme.accentPurple.opacity(0.12))
                    .cornerRadius(8)
                }
                
                if !monitor.lastCleanedAmountString.isEmpty {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(CovaTheme.accentGreen)
                        Text("Cleaned \(monitor.lastCleanedAmountString) of system junk successfully!")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.green.opacity(0.12))
                    .cornerRadius(8)
                }
                
                // 4 Main System Gauges
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
                    CircularGaugeView(
                        title: "CPU Load",
                        value: monitor.cpuUsagePercent,
                        displayString: "\(Int(round(monitor.cpuUsagePercent)))%",
                        subtitle: "\(ProcessInfo.processInfo.activeProcessorCount) Cores",
                        icon: "cpu",
                        gradient: monitor.cpuUsagePercent > 80 ? CovaTheme.amberGradient : CovaTheme.primaryGradient
                    )
                    
                    CircularGaugeView(
                        title: "Memory Used",
                        value: monitor.memoryPercent,
                        displayString: "\(String(format: "%.1f", monitor.memoryUsedGB)) GB",
                        subtitle: "of \(Int(monitor.memoryTotalGB)) GB",
                        icon: "memorychip",
                        gradient: CovaTheme.purpleGradient
                    )
                    
                    CircularGaugeView(
                        title: "Battery Level",
                        value: Double(batteryService.batteryInfo.stateOfCharge),
                        displayString: "\(batteryService.batteryInfo.stateOfCharge)%",
                        subtitle: batteryService.batteryInfo.isCharging ? "Charging" : (batteryService.batteryInfo.isAcConnected ? "AC Attached" : "On Battery"),
                        icon: batteryService.batteryInfo.isCharging ? "battery.100.bolt" : "battery.100",
                        gradient: batteryService.batteryInfo.stateOfCharge > 20 ? CovaTheme.greenGradient : CovaTheme.amberGradient
                    )
                    
                    CircularGaugeView(
                        title: "Disk Storage",
                        value: monitor.diskPercent,
                        displayString: "\(Int(monitor.diskUsedGB)) GB",
                        subtitle: "\(Int(monitor.diskAvailableGB)) GB Free",
                        icon: "internaldrive",
                        gradient: CovaTheme.primaryGradient
                    )
                }
                
                // System Summary Cards
                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Hardware Snapshot")
                            .font(.system(size: 14, weight: .bold))
                        
                        Divider()
                        
                        StatRowView(title: "Processor Cores", value: "\(ProcessInfo.processInfo.activeProcessorCount) Active Cores", icon: "cpu")
                        StatRowView(title: "Thermal Pressure", value: "Normal (Nominal)", icon: "thermometer.medium", iconColor: .green)
                        StatRowView(title: "System Uptime", value: "\(Int(ProcessInfo.processInfo.systemUptime / 3600)) Hours", icon: "clock")
                        StatRowView(title: "macOS Kernel", value: ProcessInfo.processInfo.operatingSystemVersionString, icon: "applelogo")
                    }
                    .covaCardStyle()
                    
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Power & Battery Snapshot")
                            .font(.system(size: 14, weight: .bold))
                        
                        Divider()
                        
                        StatRowView(title: "Battery Health", value: "\(String(format: "%.1f", batteryService.batteryInfo.healthPercentage))% (\(batteryService.batteryInfo.condition))", icon: "heart.fill", iconColor: .pink)
                        StatRowView(title: "Cycle Count", value: "\(batteryService.batteryInfo.cycleCount) / \(batteryService.batteryInfo.maxCycleCount)", icon: "arrow.triangle.2.circlepath", iconColor: .cyan)
                        StatRowView(title: "Battery Temperature", value: "\(String(format: "%.1f", batteryService.batteryInfo.temperatureCelsius)) °C", icon: "thermometer.snowflake", iconColor: .blue)
                        
                        if let charger = batteryService.batteryInfo.charger {
                            StatRowView(title: "Connected Charger", value: "\(charger.wattage)W (\(charger.name))", icon: "powerplug.fill", iconColor: .orange)
                        } else {
                            StatRowView(title: "Power Source", value: "Internal Battery", icon: "battery.100", iconColor: .secondary)
                        }
                    }
                    .covaCardStyle()
                }
            }
            .padding(20)
        }
    }
}
