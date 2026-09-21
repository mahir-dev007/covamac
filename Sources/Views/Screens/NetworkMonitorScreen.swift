import SwiftUI

public struct NetworkMonitorScreen: View {
    @ObservedObject var networkService: NetworkMonitorService
    @ObservedObject var adEngine: AdEngineService
    
    public init(networkService: NetworkMonitorService, adEngine: AdEngineService) {
        self.networkService = networkService
        self.adEngine = adEngine
    }
    
    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                headerView
                metricCardsView
                configView
                pingBenchmarkView
                SectionSponsorCardView(adEngine: adEngine, section: .hardwareTesters)
            }
            .padding(20)
        }
    }
    
    // MARK: - Subviews
    
    private var headerView: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 10) {
                    Image(systemName: "network")
                        .font(.system(size: 24))
                        .foregroundStyle(CovaTheme.primaryGradient)
                    Text("Network & Ping Monitor")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                }
                Text("Live network interface telemetry, gateway routing, DNS status, and real-time packet latency diagnostics.")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Button(action: {
                networkService.refreshNetworkInfo()
                networkService.runPingDiagnostics()
            }) {
                Label("Test Ping", systemImage: "arrow.triangle.2.circlepath")
                    .font(.system(size: 12, weight: .medium))
            }
            .buttonStyle(.bordered)
            .disabled(networkService.isTestingPing)
        }
        .covaCardStyle()
    }
    
    private var metricCardsView: some View {
        HStack(spacing: 16) {
            // Latency Card
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Image(systemName: "waveform.path")
                        .foregroundColor(CovaTheme.primaryBlue)
                    Text("Average Latency")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.secondary)
                }
                HStack(alignment: .lastTextBaseline, spacing: 4) {
                    if networkService.isTestingPing {
                        ProgressView()
                            .scaleEffect(0.7)
                    } else {
                        Text(networkService.averageLatencyMs > 0 ? "\(String(format: "%.1f", networkService.averageLatencyMs))" : "--")
                            .font(.system(size: 28, weight: .black, design: .rounded))
                            .foregroundColor(latencyColor(networkService.averageLatencyMs))
                        Text("ms")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.secondary)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .covaCardStyle()
            
            // Grade Card
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Image(systemName: "speedometer")
                        .foregroundColor(CovaTheme.accentGreen)
                    Text("Connection Grade")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.secondary)
                }
                Text(networkService.networkGrade)
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundColor(CovaTheme.accentGreen)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .covaCardStyle()
            
            // Status Card
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Circle()
                        .fill(networkService.isOnline ? CovaTheme.accentGreen : CovaTheme.accentRed)
                        .frame(width: 8, height: 8)
                    Text("Internet Status")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.secondary)
                }
                Text(networkService.isOnline ? "Online & Connected" : "No Connection")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(networkService.isOnline ? .primary : CovaTheme.accentRed)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .covaCardStyle()
        }
    }
    
    private var configView: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Interface Configuration")
                .font(.system(size: 15, weight: .bold))
            
            VStack(spacing: 8) {
                configRow(title: "Active Adapter", value: networkService.interfaceType, icon: "cable.connector")
                Divider()
                configRow(title: "Wi-Fi Network / SSID", value: networkService.wifiSSID, icon: "wifi")
                Divider()
                configRow(title: "Local IP Address (IPv4)", value: networkService.localIPAddress, icon: "desktopcomputer")
                Divider()
                configRow(title: "Default Gateway Router", value: networkService.routerGateway, icon: "point.3.connected.trianglepath.dotted")
                Divider()
                configRow(title: "Primary DNS Resolver", value: networkService.dnsServer, icon: "globe")
            }
        }
        .covaCardStyle()
    }
    
    private var pingBenchmarkView: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Live Ping Benchmarks")
                    .font(.system(size: 15, weight: .bold))
                Spacer()
                if networkService.isTestingPing {
                    HStack(spacing: 6) {
                        ProgressView()
                            .scaleEffect(0.7)
                        Text("Pinging edge hosts...")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            VStack(spacing: 10) {
                ForEach(networkService.pingTargets) { target in
                    HStack(spacing: 12) {
                        Circle()
                            .fill(target.packetLossPercent > 0 ? CovaTheme.accentRed : CovaTheme.accentGreen)
                            .frame(width: 8, height: 8)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(target.label)
                                .font(.system(size: 13, weight: .semibold))
                            Text(target.host)
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        if target.packetLossPercent > 0 {
                            Text("\(Int(target.packetLossPercent))% Packet Loss")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(CovaTheme.accentRed)
                        }
                        
                        Text(target.status)
                            .font(.system(size: 11, weight: .semibold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(target.latencyMs < 50 ? CovaTheme.accentGreen.opacity(0.15) : CovaTheme.accentAmber.opacity(0.15))
                            .foregroundColor(target.latencyMs < 50 ? CovaTheme.accentGreen : CovaTheme.accentAmber)
                            .cornerRadius(6)
                        
                        Text("\(String(format: "%.1f", target.latencyMs)) ms")
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .frame(width: 75, alignment: .trailing)
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 12)
                    .background(Color(NSColor.controlBackgroundColor).opacity(0.35))
                    .cornerRadius(10)
                }
            }
        }
        .covaCardStyle()
    }
    
    private func configRow(title: String, value: String, icon: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(CovaTheme.primaryBlue)
                .frame(width: 24)
            Text(title)
                .font(.system(size: 13))
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.system(size: 13, weight: .semibold, design: .monospaced))
        }
        .padding(.vertical, 3)
    }
    
    private func latencyColor(_ ms: Double) -> Color {
        if ms <= 0 { return .secondary }
        if ms < 35 { return CovaTheme.accentGreen }
        if ms < 75 { return CovaTheme.accentAmber }
        return CovaTheme.accentRed
    }
}
