import SwiftUI

public struct DeveloperCleanScreen: View {
    @ObservedObject var devService: DeveloperCleanService
    @ObservedObject var adEngine: AdEngineService
    
    public init(devService: DeveloperCleanService, adEngine: AdEngineService) {
        self.devService = devService
        self.adEngine = adEngine
    }
    
    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header Banner
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 10) {
                            Image(systemName: "hammer.fill")
                                .font(.system(size: 24))
                                .foregroundStyle(CovaTheme.purpleGradient)
                            Text("Developer Clean")
                                .font(.system(size: 24, weight: .bold, design: .rounded))
                        }
                        Text("Reclaim 10GB–60GB by safely clearing Xcode DerivedData, build archives, simulator caches, and package manager downloads.")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Button(action: {
                        devService.scanDeveloperCaches()
                    }) {
                        Label("Rescan", systemImage: "arrow.clockwise")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .buttonStyle(.bordered)
                    .disabled(devService.isScanning || devService.isCleaning)
                }
                .covaCardStyle()
                
                // Telemetry Summary Card
                HStack(spacing: 20) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Reclaimable Cache")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.secondary)
                        Text(formattedBytes(devService.totalReclaimableBytes))
                            .font(.system(size: 28, weight: .black, design: .rounded))
                            .foregroundColor(CovaTheme.accentPurple)
                    }
                    
                    Divider()
                        .frame(height: 40)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Selected for Purge")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.secondary)
                        Text(formattedBytes(devService.selectedBytes))
                            .font(.system(size: 28, weight: .black, design: .rounded))
                            .foregroundColor(CovaTheme.primaryBlue)
                    }
                    
                    Spacer()
                    
                    if !devService.lastFreedBytesString.isEmpty {
                        VStack(alignment: .trailing, spacing: 4) {
                            Text("Last Purged")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.secondary)
                            Text("+\(devService.lastFreedBytesString) Freed")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(CovaTheme.accentGreen)
                        }
                    }
                    
                    Button(action: {
                        devService.cleanSelectedJunk()
                    }) {
                        HStack(spacing: 8) {
                            if devService.isCleaning {
                                ProgressView()
                                    .scaleEffect(0.8)
                                    .frame(width: 16, height: 16)
                            } else {
                                Image(systemName: "trash.fill")
                            }
                            Text(devService.isCleaning ? "Purging..." : "Purge Selected")
                                .font(.system(size: 13, weight: .bold))
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(devService.selectedBytes > 0 && !devService.isCleaning ? CovaTheme.purpleGradient : LinearGradient(colors: [Color.gray.opacity(0.3)], startPoint: .leading, endPoint: .trailing))
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }
                    .buttonStyle(.plain)
                    .disabled(devService.selectedBytes == 0 || devService.isCleaning)
                }
                .covaCardStyle()
                
                // Selection controls
                HStack {
                    Text(devService.statusMessage)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Button("Select All") {
                        devService.selectAll()
                    }
                    .buttonStyle(.link)
                    .font(.system(size: 12))
                    
                    Text("•")
                        .foregroundColor(.secondary)
                    
                    Button("Deselect All") {
                        devService.deselectAll()
                    }
                    .buttonStyle(.link)
                    .font(.system(size: 12))
                }
                .padding(.horizontal, 4)
                
                // List of items
                if devService.isScanning {
                    HStack {
                        Spacer()
                        VStack(spacing: 12) {
                            ProgressView()
                            Text("Calculating developer folder sizes...")
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)
                        }
                        .padding(40)
                        Spacer()
                    }
                } else if devService.junkItems.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 44))
                            .foregroundColor(CovaTheme.accentGreen)
                        Text("Zero Developer Junk Detected")
                            .font(.system(size: 16, weight: .bold))
                        Text("Your Xcode, CocoaPods, and package manager directories are spotless.")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(40)
                    .covaCardStyle()
                } else {
                    VStack(spacing: 10) {
                        ForEach(devService.junkItems) { item in
                            HStack(spacing: 14) {
                                Toggle("", isOn: Binding(
                                    get: { item.isSelected },
                                    set: { _ in devService.toggleItemSelection(id: item.id) }
                                ))
                                .labelsHidden()
                                .toggleStyle(.checkbox)
                                
                                Image(systemName: item.iconName)
                                    .font(.system(size: 18))
                                    .foregroundColor(CovaTheme.primaryBlue)
                                    .frame(width: 32, height: 32)
                                    .background(Color(NSColor.controlBackgroundColor))
                                    .cornerRadius(8)
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    HStack {
                                        Text(item.name)
                                            .font(.system(size: 14, weight: .semibold))
                                        
                                        Text(item.category)
                                            .font(.system(size: 10, weight: .medium))
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(Color.secondary.opacity(0.15))
                                            .cornerRadius(4)
                                    }
                                    Text(item.path)
                                        .font(.system(size: 11, design: .monospaced))
                                        .foregroundColor(.secondary)
                                        .lineLimit(1)
                                        .truncationMode(.middle)
                                }
                                
                                Spacer()
                                
                                Text(formattedBytes(item.sizeBytes))
                                    .font(.system(size: 14, weight: .bold, design: .rounded))
                                    .foregroundColor(item.sizeBytes > 1024 * 1024 * 1024 ? CovaTheme.accentAmber : .primary)
                                
                                Button(action: {
                                    NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: item.path)
                                }) {
                                    Image(systemName: "folder")
                                        .font(.system(size: 12))
                                }
                                .buttonStyle(.borderless)
                                .help("Reveal in Finder")
                            }
                            .padding(.vertical, 8)
                            .padding(.horizontal, 12)
                            .background(Color(NSColor.controlBackgroundColor).opacity(0.4))
                            .cornerRadius(10)
                        }
                    }
                    .covaCardStyle()
                }
                
                // Embedded Section Sponsor Ad
                SectionSponsorCardView(adEngine: adEngine, section: .duplicates)
            }
            .padding(20)
        }
    }
    
    private func formattedBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}
