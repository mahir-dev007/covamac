import SwiftUI

public struct StartupManagerScreen: View {
    @ObservedObject var startupService: StartupManagerService
    @ObservedObject var adEngine: AdEngineService
    
    @State private var searchText: String = ""
    @State private var selectedFilter: String = "All"
    
    public init(startupService: StartupManagerService, adEngine: AdEngineService) {
        self.startupService = startupService
        self.adEngine = adEngine
    }
    
    private var filteredItems: [LaunchItem] {
        startupService.items.filter { item in
            let matchesSearch = searchText.isEmpty ||
                item.label.localizedCaseInsensitiveContains(searchText) ||
                item.vendor.localizedCaseInsensitiveContains(searchText) ||
                item.programPath.localizedCaseInsensitiveContains(searchText)
            
            let matchesFilter = selectedFilter == "All" || item.locationCategory.contains(selectedFilter)
            return matchesSearch && matchesFilter
        }
    }
    
    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header Banner
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 10) {
                            Image(systemName: "bolt.horizontal.fill")
                                .font(.system(size: 24))
                                .foregroundStyle(CovaTheme.amberGradient)
                            Text("Startup Items & Daemons")
                                .font(.system(size: 24, weight: .bold, design: .rounded))
                        }
                        Text("Audit and manage background launch agents, daemons, and autostart services that boot with macOS and consume RAM.")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Button(action: {
                        startupService.scanStartupItems()
                    }) {
                        Label("Rescan", systemImage: "arrow.clockwise")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .buttonStyle(.bordered)
                    .disabled(startupService.isScanning)
                }
                .covaCardStyle()
                
                // Summary Bar
                HStack(spacing: 20) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Total Services")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.secondary)
                        Text("\(startupService.totalFoundCount)")
                            .font(.system(size: 28, weight: .black, design: .rounded))
                            .foregroundColor(CovaTheme.accentAmber)
                    }
                    
                    Divider()
                        .frame(height: 40)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Active on Boot")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.secondary)
                        Text("\(startupService.items.filter { $0.isEnabled }.count)")
                            .font(.system(size: 28, weight: .black, design: .rounded))
                            .foregroundColor(CovaTheme.accentGreen)
                    }
                    
                    Divider()
                        .frame(height: 40)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Disabled")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.secondary)
                        Text("\(startupService.items.filter { !$0.isEnabled }.count)")
                            .font(.system(size: 28, weight: .black, design: .rounded))
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    // Search bar
                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.secondary)
                        TextField("Filter startup items...", text: $searchText)
                            .textFieldStyle(.plain)
                            .frame(width: 180)
                    }
                    .padding(8)
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(8)
                }
                .covaCardStyle()
                
                // Filter Tabs
                HStack(spacing: 8) {
                    filterButton("All")
                    filterButton("User")
                    filterButton("System")
                    filterButton("Daemon")
                    
                    Spacer()
                    
                    Text(startupService.statusMessage)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 4)
                
                // Item List
                if startupService.isScanning {
                    HStack {
                        Spacer()
                        ProgressView("Scanning system launch directories...")
                            .padding(40)
                        Spacer()
                    }
                } else if filteredItems.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 40))
                            .foregroundColor(CovaTheme.accentGreen)
                        Text("No matching startup items found")
                            .font(.system(size: 15, weight: .bold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(30)
                    .covaCardStyle()
                } else {
                    VStack(spacing: 10) {
                        ForEach(filteredItems) { item in
                            HStack(spacing: 14) {
                                Image(systemName: iconForVendor(item.vendor))
                                    .font(.system(size: 16))
                                    .foregroundColor(item.isEnabled ? CovaTheme.primaryBlue : .secondary)
                                    .frame(width: 34, height: 34)
                                    .background(Color(NSColor.controlBackgroundColor))
                                    .cornerRadius(8)
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    HStack(spacing: 8) {
                                        Text(item.vendor)
                                            .font(.system(size: 13, weight: .bold))
                                        
                                        Text(item.locationCategory)
                                            .font(.system(size: 10, weight: .medium))
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(Color.secondary.opacity(0.12))
                                            .cornerRadius(4)
                                    }
                                    
                                    Text(item.label)
                                        .font(.system(size: 12, design: .monospaced))
                                        .foregroundColor(.primary)
                                    
                                    if !item.programPath.isEmpty {
                                        Text(item.programPath)
                                            .font(.system(size: 10, design: .monospaced))
                                            .foregroundColor(.secondary)
                                            .lineLimit(1)
                                            .truncationMode(.middle)
                                    }
                                }
                                
                                Spacer()
                                
                                Button(action: {
                                    startupService.toggleItemState(item: item)
                                }) {
                                    Text(item.isEnabled ? "Enabled" : "Disabled")
                                        .font(.system(size: 11, weight: .semibold))
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 4)
                                        .background(item.isEnabled ? CovaTheme.accentGreen.opacity(0.15) : Color.secondary.opacity(0.15))
                                        .foregroundColor(item.isEnabled ? CovaTheme.accentGreen : .secondary)
                                        .cornerRadius(6)
                                }
                                .buttonStyle(.plain)
                                .help("Click to toggle service status")
                                
                                Button(action: {
                                    NSWorkspace.shared.selectFile(item.filePath, inFileViewerRootedAtPath: "")
                                }) {
                                    Image(systemName: "folder")
                                        .font(.system(size: 13))
                                        .foregroundColor(.secondary)
                                }
                                .buttonStyle(.borderless)
                                .help("Reveal in Finder")
                            }
                            .padding(.vertical, 8)
                            .padding(.horizontal, 12)
                            .background(Color(NSColor.controlBackgroundColor).opacity(0.35))
                            .cornerRadius(10)
                        }
                    }
                    .covaCardStyle()
                }
                
                // Embedded Section Sponsor Ad
                SectionSponsorCardView(adEngine: adEngine, section: .settings)
            }
            .padding(20)
        }
    }
    
    private func filterButton(_ title: String) -> some View {
        Button(action: {
            selectedFilter = title
        }) {
            Text(title)
                .font(.system(size: 12, weight: selectedFilter == title ? .bold : .regular))
                .padding(.horizontal, 12)
                .padding(.vertical, 5)
                .background(selectedFilter == title ? CovaTheme.amberGradient : LinearGradient(colors: [Color(NSColor.controlBackgroundColor)], startPoint: .leading, endPoint: .trailing))
                .foregroundColor(selectedFilter == title ? .white : .secondary)
                .cornerRadius(6)
        }
        .buttonStyle(.plain)
    }
    
    private func iconForVendor(_ vendor: String) -> String {
        switch vendor.lowercased() {
        case "apple": return "apple.logo"
        case "google": return "g.circle.fill"
        case "microsoft": return "square.grid.2x2.fill"
        case "adobe": return "a.circle.fill"
        case "dropbox": return "shippingbox.fill"
        case "spotify": return "music.note"
        case "docker": return "shippingbox.and.arrow.backward.fill"
        default: return "gearshape.2.fill"
        }
    }
}
