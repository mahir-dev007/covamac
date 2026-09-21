import SwiftUI

public struct MainView: View {
    @StateObject private var monitor = SystemMonitorService()
    @StateObject private var batteryService = BatteryHealthService()
    @StateObject private var uninstallerService = AppUninstallerService()
    @StateObject private var duplicateService = DuplicateFinderService()
    @StateObject private var hardwareService = HardwareTesterService()
    @StateObject private var audioDisplayService = AudioDisplayTesterService()
    @StateObject private var diagnosticsService = SystemDiagnosticsService()
    @StateObject private var devCleanService = DeveloperCleanService()
    @StateObject private var networkService = NetworkMonitorService()
    @StateObject private var startupService = StartupManagerService()
    @StateObject private var largeFilesService = LargeFilesService()
    @StateObject private var maintenanceService = MaintenanceService()
    @StateObject private var processService = ProcessManagerService()
    @StateObject private var adEngine = AdEngineService()
    
    @State private var selectedSection: NavigationSection? = .dashboard
    
    public init() {}
    
    public var body: some View {
        NavigationSplitView {
            // Sidebar
            VStack(alignment: .leading, spacing: 0) {
                // App Branding Header
                HStack(spacing: 10) {
                    if let appIcon = NSImage(named: NSImage.applicationIconName) ?? (Bundle.main.path(forResource: "AppLogo", ofType: "png").flatMap { NSImage(contentsOfFile: $0) }) ?? NSImage(contentsOfFile: "AppIcon_1024.png") {
                        Image(nsImage: appIcon)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 28, height: 28)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                            .shadow(color: Color.blue.opacity(0.35), radius: 4, x: 0, y: 2)
                    } else {
                        Image(systemName: "bolt.shield.fill")
                            .font(.system(size: 20))
                            .foregroundStyle(CovaTheme.primaryGradient)
                    }
                    
                    VStack(alignment: .leading, spacing: 1) {
                        Text("CovaMac")
                            .font(.system(size: 15, weight: .black, design: .rounded))
                        Text("System Pro Suite")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                
                Divider()
                
                // Navigation Items
                List(NavigationSection.allCases, selection: $selectedSection) { section in
                    NavigationLink(value: section) {
                        HStack(spacing: 10) {
                            Image(systemName: section.iconName)
                                .font(.system(size: 14))
                                .foregroundColor(selectedSection == section ? CovaTheme.primaryBlue : .secondary)
                                .frame(width: 22)
                            Text(section.rawValue)
                                .font(.system(size: 13, weight: selectedSection == section ? .semibold : .regular))
                            Spacer()
                        }
                        .padding(.vertical, 4)
                    }
                }
                .listStyle(.sidebar)
                
                Divider()
                
                // Compact Sidebar Native Sponsor Card
                SidebarSponsorCardView(adEngine: adEngine)
            }
            .frame(minWidth: 220, idealWidth: 240, maxWidth: 280)
        } detail: {
            VStack(spacing: 0) {
                // TopBar Sponsor Banner (Clean, Dedicated Top Bar Ad - Never inside functions)
                TopBarSponsorView(adEngine: adEngine)
                
                // Main Content Area (100% clean and unobstructed)
                Group {
                    switch selectedSection ?? .dashboard {
                    case .dashboard:
                        DashboardView(
                            monitor: monitor,
                            batteryService: batteryService,
                            adEngine: adEngine
                        )
                    case .spaceLens:
                        LargeFilesScreen(
                            service: largeFilesService,
                            adEngine: adEngine
                        )
                    case .processes:
                        ProcessManagerScreen(
                            service: processService,
                            adEngine: adEngine
                        )
                    case .maintenance:
                        MaintenanceScreen(
                            service: maintenanceService,
                            adEngine: adEngine
                        )
                    case .battery:
                        BatteryHealthView(
                            batteryService: batteryService,
                            adEngine: adEngine
                        )
                    case .uninstaller:
                        UninstallerScreen(
                            uninstallerService: uninstallerService,
                            adEngine: adEngine
                        )
                    case .devClean:
                        DeveloperCleanScreen(
                            devService: devCleanService,
                            adEngine: adEngine
                        )
                    case .duplicates:
                        DuplicateFinderScreen(
                            duplicateService: duplicateService,
                            adEngine: adEngine
                        )
                    case .network:
                        NetworkMonitorScreen(
                            networkService: networkService,
                            adEngine: adEngine
                        )
                    case .startup:
                        StartupManagerScreen(
                            startupService: startupService,
                            adEngine: adEngine
                        )
                    case .hardwareTesters:
                        HardwareTesterScreen(
                            hardwareService: hardwareService,
                            audioDisplayService: audioDisplayService,
                            adEngine: adEngine
                        )
                    case .diagnostics:
                        SystemDiagnosticsScreen(
                            diagnosticsService: diagnosticsService,
                            adEngine: adEngine
                        )
                    case .settings:
                        SettingsView(
                            adEngine: adEngine
                        )
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(minWidth: 700, minHeight: 560)
            .sheet(isPresented: $adEngine.showRemoveAdsModal) {
                RemoveAdsModalView(adEngine: adEngine)
            }
        }
    }
}
