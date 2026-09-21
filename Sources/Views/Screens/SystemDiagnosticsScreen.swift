import SwiftUI

public struct SystemDiagnosticsScreen: View {
    @ObservedObject var diagnosticsService: SystemDiagnosticsService
    @ObservedObject var adEngine: AdEngineService
    
    public init(diagnosticsService: SystemDiagnosticsService, adEngine: AdEngineService) {
        self.diagnosticsService = diagnosticsService
        self.adEngine = adEngine
    }
    
    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header Bar
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("System Health & Security Diagnostics")
                            .font(.system(size: 22, weight: .bold))
                        Text("Audits System Integrity Protection (SIP), FileVault encryption, crash logs, and thermal pressure.")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Button(action: {
                        diagnosticsService.runDiagnostics()
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.clockwise")
                            Text("Re-scan System")
                        }
                        .font(.system(size: 12, weight: .semibold))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(CovaTheme.primaryGradient)
                        .foregroundColor(.white)
                        .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                }
                .covaCardStyle()
                
                // Score & Overview Card
                HStack(spacing: 20) {
                    ZStack {
                        Circle()
                            .stroke(Color.gray.opacity(0.18), lineWidth: 10)
                            .frame(width: 90, height: 90)
                        Circle()
                            .trim(from: 0.0, to: CGFloat(Double(diagnosticsService.overallHealthScore) / 100.0))
                            .stroke(CovaTheme.greenGradient, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                            .frame(width: 90, height: 90)
                            .rotationEffect(.degrees(-90))
                        
                        VStack(spacing: 2) {
                            Text("\(diagnosticsService.overallHealthScore)")
                                .font(.system(size: 26, weight: .black, design: .rounded))
                            Text("SCORE")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 6) {
                        Text("System Status: Operational & Secure")
                            .font(.system(size: 16, weight: .bold))
                        Text("Operating System: \(diagnosticsService.osVersionString)")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                        Text("Uptime: \(diagnosticsService.uptimeString)")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(CovaTheme.primaryBlue)
                    }
                    
                    Spacer()
                }
                .covaCardStyle()
                
                // Diagnostic Checks List
                VStack(alignment: .leading, spacing: 14) {
                    Text("Audit Results & Security Checks")
                        .font(.system(size: 15, weight: .bold))
                    
                    Divider()
                    
                    ForEach(diagnosticsService.checkItems) { item in
                        HStack(spacing: 12) {
                            Image(systemName: item.icon)
                                .font(.system(size: 18))
                                .foregroundColor(item.status.color)
                                .frame(width: 32, height: 32)
                                .background(item.status.color.opacity(0.12))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                            
                            VStack(alignment: .leading, spacing: 3) {
                                HStack {
                                    Text(item.title)
                                        .font(.system(size: 13, weight: .bold))
                                    Text("• \(item.category)")
                                        .font(.system(size: 11))
                                        .foregroundColor(.secondary)
                                    Spacer()
                                    Text(item.status.rawValue)
                                        .font(.system(size: 11, weight: .semibold))
                                        .foregroundColor(item.status.color)
                                }
                                Text(item.details)
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                        
                        Divider()
                    }
                }
                .covaCardStyle()
            }
            .padding(20)
        }
    }
}
