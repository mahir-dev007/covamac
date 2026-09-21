import SwiftUI

public struct UninstallerScreen: View {
    @ObservedObject var uninstallerService: AppUninstallerService
    @ObservedObject var adEngine: AdEngineService
    
    @State private var selectedTab: Int = 0 // 0: Installed Apps, 1: Orphan Leftovers Hunter
    @State private var searchText: String = ""
    @State private var showConfirmUninstall: Bool = false
    
    public init(uninstallerService: AppUninstallerService, adEngine: AdEngineService) {
        self.uninstallerService = uninstallerService
        self.adEngine = adEngine
    }
    
    private var filteredApps: [AppItem] {
        if searchText.isEmpty {
            return uninstallerService.apps
        }
        return uninstallerService.apps.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            $0.bundleId.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            // Header Bar
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Pro Uninstaller & Leftovers Cleaner")
                        .font(.system(size: 22, weight: .bold))
                    Text("Deep-clean application binaries, hidden caches, preferences, and orphaned files.")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Picker("", selection: $selectedTab) {
                    Text("Installed Apps (\(uninstallerService.apps.count))").tag(0)
                    Text("Orphan Leftovers (\(uninstallerService.orphanLeftovers.count))").tag(1)
                }
                .pickerStyle(.segmented)
                .frame(width: 320)
                
                Button(action: {
                    uninstallerService.scanInstalledApps()
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.clockwise")
                        Text(uninstallerService.isScanning ? "Scanning..." : "Scan Apps")
                    }
                    .font(.system(size: 12, weight: .semibold))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(CovaTheme.primaryGradient)
                    .foregroundColor(.white)
                    .cornerRadius(6)
                }
                .buttonStyle(.plain)
                .disabled(uninstallerService.isScanning)
            }
            .padding(16)
            .background(Color(NSColor.windowBackgroundColor).opacity(0.8))
            
            Divider()
            
            if uninstallerService.isScanning {
                VStack(spacing: 16) {
                    ProgressView(value: uninstallerService.scanProgress)
                        .frame(width: 300)
                    Text(uninstallerService.statusMessage)
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if selectedTab == 0 {
                // Installed Apps Mode
                installedAppsView
            } else {
                // Orphan Leftovers Hunter Mode
                orphanLeftoversView
            }
        }
        .onAppear {
            if uninstallerService.apps.isEmpty {
                uninstallerService.scanInstalledApps()
            }
        }
    }
    
    // MARK: - Installed Apps View
    
    private var installedAppsView: some View {
        HSplitView {
            // Left List: Apps
            VStack(spacing: 8) {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField("Search installed applications...", text: $searchText)
                        .textFieldStyle(.plain)
                }
                .padding(8)
                .background(Color.gray.opacity(0.12))
                .cornerRadius(8)
                .padding(.horizontal, 10)
                .padding(.top, 8)
                
                List(filteredApps, selection: $uninstallerService.selectedApp) { app in
                    HStack(spacing: 10) {
                        Image(nsImage: NSWorkspace.shared.icon(forFile: app.bundleURL.path))
                            .resizable()
                            .frame(width: 32, height: 32)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            HStack {
                                Text(app.name)
                                    .font(.system(size: 13, weight: .semibold))
                                if app.isSystemApp {
                                    Text("SYSTEM")
                                        .font(.system(size: 8, weight: .black))
                                        .padding(.horizontal, 4)
                                        .padding(.vertical, 1)
                                        .background(Color.gray.opacity(0.2))
                                        .cornerRadius(4)
                                }
                            }
                            Text(app.bundleId)
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(formatBytes(app.totalSize))
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                            if !app.leftoverItems.isEmpty {
                                Text("\(app.leftoverItems.count) leftovers")
                                    .font(.system(size: 10))
                                    .foregroundColor(CovaTheme.accentAmber)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                    .tag(app)
                }
                .listStyle(.inset)
            }
            .frame(minWidth: 320, maxWidth: 420)
            
            // Right Inspector: Leftovers & Uninstall
            if let selectedApp = uninstallerService.selectedApp {
                appInspectorView(app: selectedApp)
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "app.dashed")
                        .font(.system(size: 36))
                        .foregroundColor(.secondary)
                    Text("Select an application from the list to inspect files and leftovers.")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
    
    private func appInspectorView(app: AppItem) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            // App Header
            HStack(spacing: 14) {
                Image(nsImage: NSWorkspace.shared.icon(forFile: app.bundleURL.path))
                    .resizable()
                    .frame(width: 48, height: 48)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(app.name)
                        .font(.system(size: 18, weight: .bold))
                    Text("Version \(app.version) • \(app.bundleId)")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                    Text("Bundle Size: \(formatBytes(app.appSize)) | Residual Leftovers: \(formatBytes(app.totalLeftoverSize))")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(CovaTheme.accentTeal)
                }
                
                Spacer()
                
                if !app.isSystemApp {
                    Button(action: {
                        showConfirmUninstall = true
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "trash.fill")
                            Text("Uninstall & Clean")
                        }
                        .font(.system(size: 12, weight: .bold))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(CovaTheme.accentRed)
                        .foregroundColor(.white)
                        .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                    .alert(isPresented: $showConfirmUninstall) {
                        Alert(
                            title: Text("Uninstall \(app.name)?"),
                            message: Text("This will safely move \(app.name) and all \(app.leftoverItems.count) leftover support files (\(formatBytes(app.totalSize))) to macOS Trash. You can restore them from Trash if needed."),
                            primaryButton: .destructive(Text("Move to Trash")) {
                                _ = uninstallerService.uninstallApp(app: app, removeLeftovers: true)
                            },
                            secondaryButton: .cancel()
                        )
                    }
                }
            }
            .padding(14)
            .covaCardStyle()
            
            // Leftovers List
            HStack {
                Text("Associated Files & Residual Leftovers (\(app.leftoverItems.count))")
                    .font(.system(size: 13, weight: .bold))
                Spacer()
                if !app.leftoverItems.isEmpty {
                    Button("Clean Only Leftovers") {
                        uninstallerService.cleanSelectedLeftovers(for: app)
                    }
                    .font(.system(size: 11, weight: .semibold))
                }
            }
            .padding(.horizontal, 4)
            
            if app.leftoverItems.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundColor(.green)
                        .font(.system(size: 28))
                    Text("No hidden leftover files found in Library. Clean application.")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(app.leftoverItems) { item in
                        HStack(spacing: 8) {
                            Image(systemName: item.category.iconName)
                                .foregroundColor(CovaTheme.primaryBlue)
                                .font(.system(size: 13))
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.category.rawValue)
                                    .font(.system(size: 11, weight: .bold))
                                Text(item.path)
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                            }
                            
                            Spacer()
                            
                            Text(formatBytes(item.size))
                                .font(.system(size: 11, weight: .medium, design: .rounded))
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 2)
                    }
                }
                .listStyle(.plain)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Orphan Leftovers View
    
    private var orphanLeftoversView: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Orphaned Application Residuals")
                        .font(.system(size: 16, weight: .bold))
                    Text("These folders belong to apps that were already uninstalled in the past, but left behind cached data.")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if !uninstallerService.orphanLeftovers.isEmpty {
                    Button(action: {
                        uninstallerService.cleanSelectedOrphans()
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "trash")
                            Text("Clean All Residuals")
                        }
                        .font(.system(size: 12, weight: .bold))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(CovaTheme.primaryGradient)
                        .foregroundColor(.white)
                        .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(14)
            .covaCardStyle()
            
            if uninstallerService.orphanLeftovers.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 32))
                        .foregroundColor(CovaTheme.accentGreen)
                    Text("No orphaned leftovers found on your system!")
                        .font(.system(size: 14, weight: .bold))
                    Text("Your Mac is free of abandoned application files.")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(uninstallerService.orphanLeftovers) { orphan in
                        HStack(spacing: 10) {
                            Image(systemName: orphan.category.iconName)
                                .foregroundColor(CovaTheme.accentAmber)
                                .font(.system(size: 14))
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(orphan.presumedAppName)
                                    .font(.system(size: 13, weight: .semibold))
                                Text(orphan.path)
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                            }
                            
                            Spacer()
                            
                            Text(formatBytes(orphan.size))
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                .foregroundColor(CovaTheme.primaryBlue)
                        }
                    }
                }
                .listStyle(.inset)
            }
        }
        .padding(14)
    }
    
    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}
