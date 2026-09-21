import SwiftUI

public struct BatteryHealthView: View {
    @ObservedObject var batteryService: BatteryHealthService
    @ObservedObject var adEngine: AdEngineService
    
    public init(batteryService: BatteryHealthService, adEngine: AdEngineService) {
        self.batteryService = batteryService
        self.adEngine = adEngine
    }
    
    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Screen Title
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Battery Health & Power")
                            .font(.system(size: 24, weight: .bold))
                        Text("Low-level Apple Smart Battery diagnostics and live AC charger telemetry.")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Button(action: {
                        batteryService.refresh()
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.clockwise")
                            Text("Refresh")
                        }
                        .font(.system(size: 12, weight: .semibold))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.gray.opacity(0.18))
                        .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                }
                .covaCardStyle()
                
                // Top Highlight Cards
                HStack(spacing: 16) {
                    // Battery Level & Health
                    VStack(spacing: 14) {
                        HStack {
                            Image(systemName: "battery.100.bolt")
                                .foregroundColor(CovaTheme.accentGreen)
                                .font(.system(size: 16, weight: .bold))
                            Text("Battery State")
                                .font(.system(size: 14, weight: .bold))
                            Spacer()
                            Text(batteryService.batteryInfo.condition)
                                .font(.system(size: 11, weight: .bold))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(batteryService.batteryInfo.condition == "Normal" ? Color.green.opacity(0.2) : Color.orange.opacity(0.2))
                                .foregroundColor(batteryService.batteryInfo.condition == "Normal" ? .green : .orange)
                                .cornerRadius(6)
                        }
                        
                        HStack(spacing: 20) {
                            ZStack {
                                Circle()
                                    .stroke(Color.gray.opacity(0.2), lineWidth: 10)
                                    .frame(width: 100, height: 100)
                                Circle()
                                    .trim(from: 0.0, to: CGFloat(Double(batteryService.batteryInfo.stateOfCharge) / 100.0))
                                    .stroke(CovaTheme.greenGradient, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                                    .frame(width: 100, height: 100)
                                    .rotationEffect(.degrees(-90))
                                
                                VStack(spacing: 2) {
                                    Text("\(batteryService.batteryInfo.stateOfCharge)%")
                                        .font(.system(size: 22, weight: .black, design: .rounded))
                                    Text("Charge")
                                        .font(.system(size: 10, weight: .semibold))
                                        .foregroundColor(.secondary)
                                }
                            }
                            
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Maximum Capacity")
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                                Text("\(String(format: "%.1f", batteryService.batteryInfo.healthPercentage))%")
                                    .font(.system(size: 24, weight: .black, design: .rounded))
                                    .foregroundColor(batteryService.batteryInfo.healthPercentage > 85 ? .green : .orange)
                                Text(batteryService.batteryInfo.healthPercentage >= 80 ? "Healthy condition. Retains original factory capacity." : "Degraded. Consider servicing battery.")
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .covaCardStyle()
                    
                    // Cycle Count Card
                    VStack(alignment: .leading, spacing: 14) {
                        HStack {
                            Image(systemName: "arrow.triangle.2.circlepath")
                                .foregroundColor(CovaTheme.primaryBlue)
                                .font(.system(size: 16, weight: .bold))
                            Text("Cycle Count & Longevity")
                                .font(.system(size: 14, weight: .bold))
                            Spacer()
                        }
                        
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text("\(batteryService.batteryInfo.cycleCount)")
                                    .font(.system(size: 26, weight: .black, design: .rounded))
                                Text("/ \(batteryService.batteryInfo.maxCycleCount) Rating")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(.secondary)
                            }
                            
                            ProgressView(value: Double(batteryService.batteryInfo.cycleCount), total: Double(batteryService.batteryInfo.maxCycleCount))
                                .accentColor(CovaTheme.primaryBlue)
                            
                            Text("Apple evaluates Mac batteries for up to 1,000 full charge cycles while retaining up to 80% original capacity.")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                    }
                    .covaCardStyle()
                }
                
                // Charger Specifications Section (CRITICAL USER REQUIREMENT)
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Image(systemName: "powerplug.fill")
                            .foregroundColor(CovaTheme.accentAmber)
                            .font(.system(size: 18))
                        Text("AC Charger & Power Adapter Specifications")
                            .font(.system(size: 16, weight: .bold))
                        
                        Spacer()
                        
                        if let charger = batteryService.batteryInfo.charger, charger.isConnected {
                            HStack(spacing: 6) {
                                Circle()
                                    .fill(Color.green)
                                    .frame(width: 8, height: 8)
                                Text("\(charger.wattage)W Connected")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(.green)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Color.green.opacity(0.15))
                            .cornerRadius(6)
                        } else {
                            Text("Not Connected")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Divider()
                    
                    if let charger = batteryService.batteryInfo.charger, charger.isConnected {
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                            StatRowView(title: "Adapter Model", value: charger.name, icon: "powerplug.fill", iconColor: .orange)
                            StatRowView(title: "Manufacturer", value: charger.manufacturer, icon: "building.2.fill", iconColor: .blue)
                            StatRowView(title: "Negotiated Wattage", value: "\(charger.wattage) Watts", icon: "bolt.fill", iconColor: .yellow)
                            StatRowView(title: "Charging Telemetry", value: charger.chargingStatusText, icon: "bolt.badge.checkmark.fill", iconColor: .green)
                            StatRowView(title: "Input Voltage", value: "\(charger.voltageMV / 1000) Volts (\(charger.voltageMV) mV)", icon: "waveform.path", iconColor: .purple)
                            StatRowView(title: "Input Current", value: "\(charger.currentMA) mA (\(String(format: "%.1f", Double(charger.currentMA) / 1000.0)) A)", icon: "arrow.right.arrow.left", iconColor: .teal)
                            StatRowView(title: "Hardware Revision", value: charger.hardwareVersion, icon: "cpu", iconColor: .gray)
                            StatRowView(title: "Firmware Revision", value: charger.firmwareVersion, icon: "internaldrive", iconColor: .gray)
                            StatRowView(title: "Serial Number", value: charger.serialNumber, icon: "barcode", iconColor: .secondary)
                        }
                    } else {
                        VStack(spacing: 8) {
                            Image(systemName: "bolt.slash.fill")
                                .font(.system(size: 28))
                                .foregroundColor(.secondary)
                            Text("Mac is currently running on Battery Power.")
                                .font(.system(size: 13, weight: .medium))
                            Text("Plug in your USB-C or MagSafe power adapter to view live charger wattage, serial number, voltage, and firmware specs.")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 20)
                    }
                }
                .covaCardStyle()
                
                // Deep Technical Battery Specs
                VStack(alignment: .leading, spacing: 14) {
                    Text("Technical Battery Diagnostics")
                        .font(.system(size: 15, weight: .bold))
                    
                    Divider()
                    
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        StatRowView(title: "Current Capacity", value: "\(batteryService.batteryInfo.currentCapacitymAh) mAh", icon: "gauge.with.needle", iconColor: .blue)
                        StatRowView(title: "Full Charge Capacity", value: "\(batteryService.batteryInfo.maxCapacitymAh) mAh", icon: "battery.100", iconColor: .green)
                        StatRowView(title: "Design Capacity", value: "\(batteryService.batteryInfo.designCapacitymAh) mAh", icon: "ruler", iconColor: .cyan)
                        StatRowView(title: "Battery Temperature", value: "\(String(format: "%.1f", batteryService.batteryInfo.temperatureCelsius)) °C (\(String(format: "%.1f", batteryService.batteryInfo.temperatureFahrenheit)) °F)", icon: "thermometer.medium", iconColor: .orange)
                        StatRowView(title: "Live Voltage", value: "\(String(format: "%.2f", batteryService.batteryInfo.voltageVolts)) V", icon: "bolt.fill", iconColor: .yellow)
                        StatRowView(title: "Amperage Draw", value: "\(batteryService.batteryInfo.amperagemA) mA", icon: "arrow.up.and.down", iconColor: .purple)
                        StatRowView(title: "Device Name", value: batteryService.batteryInfo.deviceName, icon: "memorychip", iconColor: .gray)
                        StatRowView(title: "Battery Serial Number", value: batteryService.batteryInfo.serialNumber, icon: "number", iconColor: .secondary)
                    }
                }
                .covaCardStyle()
            }
            .padding(20)
        }
    }
}
