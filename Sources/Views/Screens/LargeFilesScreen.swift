import SwiftUI
import AppKit

public struct LargeFilesScreen: View {
    @ObservedObject var service: LargeFilesService
    @ObservedObject var adEngine: AdEngineService
    @State private var showingFolderPicker: Bool = false
    @State private var confirmTrashAlert: Bool = false
    
    public init(service: LargeFilesService, adEngine: AdEngineService) {
        self.service = service
        self.adEngine = adEngine
    }
    
    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header Row
                headerView
                
                // Metrics Overview Cards
                if !service.largeFiles.isEmpty {
                    metricsCardsView
                }
                
                // Filter & Search Toolbar
                if !service.largeFiles.isEmpty {
                    filterToolbarView
                }
                
                // Content Area: List or Empty / Scanning State
                if service.isScanning {
                    scanningStateView
                } else if service.largeFiles.isEmpty {
                    emptyStateView
                } else {
                    fileListView
                }
            }
            .padding(24)
        }
        .confirmationDialog(
            "Move Selected Files to Trash?",
            isPresented: $confirmTrashAlert,
            titleVisibility: .visible
        ) {
            Button("Move \(service.selectedCount) Files to Trash", role: .destructive) {
                service.moveSelectedToTrash()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Selected items (\(ByteCountFormatter.string(fromByteCount: service.selectedBytes, countStyle: .file))) will be safely moved to macOS Trash and can be restored if needed.")
        }
    }
    
    // MARK: - Header
    private var headerView: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text("Large & Old Files")
                        .font(.system(size: 24, weight: .bold))
                    
                    Text("SPACE LENS")
                        .font(.system(size: 9, weight: .heavy))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(CovaTheme.primaryBlue.opacity(0.15))
                        .foregroundColor(CovaTheme.primaryBlue)
                        .cornerRadius(5)
                }
                
                Text("Locate large forgotten installers, archives, video recordings, and media hogging your storage.")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            HStack(spacing: 10) {
                Button(action: {
                    selectFolderAndScan()
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "folder.badge.gearshape")
                            .font(.system(size: 11))
                        Text("Choose Folder...")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(Color.white.opacity(0.08))
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
                .disabled(service.isScanning)
                
                Button(action: {
                    service.startScan()
                }) {
                    HStack(spacing: 6) {
                        if service.isScanning {
                            ProgressView()
                                .scaleEffect(0.6)
                                .frame(width: 14, height: 14)
                        } else {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 11, weight: .bold))
                        }
                        Text(service.isScanning ? "Scanning..." : "Deep Scan Home")
                            .font(.system(size: 11, weight: .bold))
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .background(CovaTheme.primaryGradient)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
                .disabled(service.isScanning)
            }
        }
    }
    
    // MARK: - Metrics Cards
    private var metricsCardsView: some View {
        HStack(spacing: 14) {
            let totalStr = ByteCountFormatter.string(fromByteCount: service.totalReclaimableBytes, countStyle: .file)
            MetricCard(
                title: "Total Large Files",
                value: totalStr,
                subtitle: "\(service.largeFiles.count) files (\(service.selectedFolderURL.lastPathComponent))",
                icon: "chart.pie.fill",
                accentColor: CovaTheme.primaryBlue
            )
            
            let hugeCount = service.largeFiles.filter { $0.sizeBytes >= 1024*1024*1024 }.count
            MetricCard(
                title: "Huge Files (>1GB)",
                value: "\(hugeCount)",
                subtitle: "Prime candidates for cleanup",
                icon: "externaldrive.fill",
                accentColor: .purple
            )
            
            let oldCount = service.largeFiles.filter {
                Calendar.current.dateComponents([.day], from: $0.modificationDate, to: Date()).day ?? 0 >= 365
            }.count
            MetricCard(
                title: "Old Files (>1 Year)",
                value: "\(oldCount)",
                subtitle: "Untouched for over 12 months",
                icon: "clock.arrow.circlepath",
                accentColor: CovaTheme.accentAmber
            )
            
            let selectedStr = ByteCountFormatter.string(fromByteCount: service.selectedBytes, countStyle: .file)
            MetricCard(
                title: "Selected",
                value: selectedStr,
                subtitle: "\(service.selectedCount) files checked",
                icon: "checkmark.circle.fill",
                accentColor: service.selectedCount > 0 ? CovaTheme.accentGreen : .gray
            )
        }
    }
    
    // MARK: - Filter Toolbar
    private var filterToolbarView: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                // Size Filters
                Picker("Size", selection: $service.selectedSizeTier) {
                    ForEach(LargeFileSizeTier.allCases) { tier in
                        Text(tier.rawValue).tag(tier)
                    }
                }
                .pickerStyle(.segmented)
                
                // Kind Filters
                Picker("Kind", selection: $service.selectedKind) {
                    ForEach(LargeFileKind.allCases) { kind in
                        Text(kind.rawValue).tag(kind)
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 170)
                
                // Age Filters
                Picker("Age", selection: $service.selectedAgeTier) {
                    ForEach(LargeFileAgeTier.allCases) { age in
                        Text(age.rawValue).tag(age)
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 150)
                
                Spacer()
                
                // Sort
                Picker("Sort", selection: $service.sortBy) {
                    ForEach(LargeFilesService.SortOption.allCases) { opt in
                        Text(opt.rawValue).tag(opt)
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 140)
            }
            
            // Search and Selection Row
            HStack(spacing: 12) {
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                        .font(.system(size: 11))
                    TextField("Filter by filename or extension...", text: $service.searchQuery)
                        .textFieldStyle(.plain)
                        .font(.system(size: 11))
                    if !service.searchQuery.isEmpty {
                        Button(action: { service.searchQuery = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                                .font(.system(size: 10))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.white.opacity(0.06))
                .cornerRadius(7)
                
                Spacer()
                
                Button(action: {
                    service.selectAllFiltered()
                }) {
                    Text("Select All")
                        .font(.system(size: 11, weight: .semibold))
                }
                .buttonStyle(.plain)
                
                Text("•").foregroundColor(.secondary.opacity(0.4))
                
                Button(action: {
                    service.deselectAll()
                }) {
                    Text("Deselect")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                
                if service.selectedCount > 0 {
                    Button(action: {
                        confirmTrashAlert = true
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "trash.fill")
                                .font(.system(size: 10))
                            Text("Move to Trash (\(service.selectedCount))")
                                .font(.system(size: 11, weight: .bold))
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.red.opacity(0.85))
                        .foregroundColor(.white)
                        .cornerRadius(7)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(14)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.4))
        .cornerRadius(10)
    }
    
    // MARK: - File List
    private var fileListView: some View {
        VStack(spacing: 8) {
            let files = service.filteredFiles
            
            if files.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "line.3.horizontal.decrease.circle")
                        .font(.system(size: 32))
                        .foregroundColor(.secondary)
                    Text("No files match the active filters")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(40)
            } else {
                ForEach(files) { item in
                    LargeFileRowView(
                        item: item,
                        onToggle: { service.toggleItemSelection(id: item.id) },
                        onReveal: { service.revealInFinder(url: item.url) }
                    )
                }
            }
        }
    }
    
    // MARK: - Scanning State
    private var scanningStateView: some View {
        VStack(spacing: 18) {
            ProgressView()
                .scaleEffect(1.2)
            
            VStack(spacing: 6) {
                Text("Scanning for Large Files...")
                    .font(.system(size: 15, weight: .bold))
                Text(service.statusMessage)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(60)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.3))
        .cornerRadius(14)
    }
    
    // MARK: - Empty State
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(CovaTheme.primaryBlue.opacity(0.12))
                    .frame(width: 72, height: 72)
                Image(systemName: "chart.pie.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(CovaTheme.primaryGradient)
            }
            
            VStack(spacing: 6) {
                Text("Scan Your Mac for Space-Hogging Files")
                    .font(.system(size: 16, weight: .bold))
                Text("Find multi-gigabyte disk images, forgotten video files, and uncompressed archives taking up SSD space.")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 460)
            }
            
            Button(action: {
                service.startScan()
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "play.fill")
                        .font(.system(size: 11))
                    Text("Start Scan on Home Folder")
                        .font(.system(size: 12, weight: .bold))
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 9)
                .background(CovaTheme.primaryGradient)
                .foregroundColor(.white)
                .cornerRadius(8)
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity)
        .padding(60)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.3))
        .cornerRadius(14)
    }
    
    private func selectFolderAndScan() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Scan Folder"
        if panel.runModal() == .OK, let url = panel.url {
            service.startScan(targetURL: url)
        }
    }
}

// MARK: - Subviews

private struct MetricCard: View {
    let title: String
    let value: String
    let subtitle: String
    let icon: String
    let accentColor: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.secondary)
                Spacer()
                Image(systemName: icon)
                    .font(.system(size: 12))
                    .foregroundColor(accentColor)
            }
            
            Text(value)
                .font(.system(size: 19, weight: .bold))
                .foregroundColor(.primary)
            
            Text(subtitle)
                .font(.system(size: 10))
                .foregroundColor(.secondary)
                .lineLimit(1)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.55))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
    }
}

private struct LargeFileRowView: View {
    let item: LargeFileItem
    let onToggle: () -> Void
    let onReveal: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            Button(action: onToggle) {
                Image(systemName: item.isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 16))
                    .foregroundColor(item.isSelected ? CovaTheme.accentGreen : .secondary)
            }
            .buttonStyle(.plain)
            
            // Icon
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.primary.opacity(0.06))
                    .frame(width: 36, height: 36)
                Image(systemName: item.kind.iconName)
                    .font(.system(size: 16))
                    .foregroundColor(CovaTheme.primaryBlue)
            }
            
            // File Info
            VStack(alignment: .leading, spacing: 3) {
                Text(item.name)
                    .font(.system(size: 12, weight: .bold))
                    .lineLimit(1)
                
                HStack(spacing: 6) {
                    Text(item.url.deletingLastPathComponent().path)
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    
                    Text("•")
                        .font(.system(size: 8))
                        .foregroundColor(.secondary.opacity(0.6))
                    
                    Text(item.formattedDate)
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            // Size & Reveal
            HStack(spacing: 14) {
                Text(item.formattedSize)
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .foregroundColor(item.sizeBytes >= 1024*1024*1024 ? .purple : .primary)
                
                Button(action: onReveal) {
                    Image(systemName: "arrow.up.forward.app")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help("Reveal in Finder")
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color(NSColor.controlBackgroundColor).opacity(item.isSelected ? 0.8 : 0.4))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(item.isSelected ? CovaTheme.accentGreen.opacity(0.4) : Color.white.opacity(0.06), lineWidth: 1)
        )
    }
}
