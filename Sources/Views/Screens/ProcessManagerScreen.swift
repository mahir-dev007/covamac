import SwiftUI
import AppKit

public struct ProcessManagerScreen: View {
    @ObservedObject var service: ProcessManagerService
    @ObservedObject var adEngine: AdEngineService
    @State private var processToKill: ProcessItem? = nil
    @State private var isForceQuit: Bool = false
    @State private var showKillConfirm: Bool = false
    
    public init(service: ProcessManagerService, adEngine: AdEngineService) {
        self.service = service
        self.adEngine = adEngine
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView
                .padding(.horizontal, 24)
                .padding(.top, 20)
                .padding(.bottom, 16)
            
            // Metrics Row
            metricsRowView
                .padding(.horizontal, 24)
                .padding(.bottom, 16)
            
            // Filters & Search
            toolbarView
                .padding(.horizontal, 24)
                .padding(.bottom, 12)
            
            Divider()
            
            // Table Header
            tableHeaderView
                .padding(.horizontal, 24)
                .padding(.vertical, 8)
                .background(Color(NSColor.controlBackgroundColor).opacity(0.3))
            
            Divider()
            
            // Process Rows
            ScrollView {
                LazyVStack(spacing: 2) {
                    let items = service.filteredProcesses
                    if items.isEmpty {
                        emptyFilterView
                    } else {
                        ForEach(items) { item in
                            ProcessRowView(
                                item: item,
                                onQuit: {
                                    processToKill = item
                                    isForceQuit = false
                                    showKillConfirm = true
                                },
                                onForceQuit: {
                                    processToKill = item
                                    isForceQuit = true
                                    showKillConfirm = true
                                }
                            )
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 8)
            }
        }
        .confirmationDialog(
            isForceQuit ? "Force Quit \(processToKill?.name ?? "Process")?" : "Quit \(processToKill?.name ?? "Process")?",
            isPresented: $showKillConfirm,
            titleVisibility: .visible
        ) {
            Button(isForceQuit ? "Force Quit" : "Quit Process", role: .destructive) {
                if let proc = processToKill {
                    _ = service.terminateProcess(pid: proc.pid, force: isForceQuit)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(isForceQuit
                ? "Force quitting may cause unsaved changes in \(processToKill?.name ?? "this process") to be lost."
                : "This will send a graceful termination request to \(processToKill?.name ?? "this process") (PID: \(processToKill?.pid ?? 0)).")
        }
        .onAppear {
            service.refreshProcesses()
            service.startTimer()
        }
        .onDisappear {
            service.stopTimer()
        }
    }
    
    // MARK: - Header
    private var headerView: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text("Process Manager")
                        .font(.system(size: 24, weight: .bold))
                    
                    Text("ACTIVITY")
                        .font(.system(size: 9, weight: .heavy))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(CovaTheme.primaryBlue.opacity(0.15))
                        .foregroundColor(CovaTheme.primaryBlue)
                        .cornerRadius(5)
                }
                
                Text(service.statusMessage)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            HStack(spacing: 10) {
                Button(action: {
                    let url = URL(fileURLWithPath: "/System/Applications/Utilities/Activity Monitor.app")
                    NSWorkspace.shared.open(url)
                }) {
                    HStack(spacing: 5) {
                        Image(systemName: "gauge.with.needle")
                            .font(.system(size: 11))
                        Text("Activity Monitor")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(Color.white.opacity(0.08))
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
                
                Button(action: {
                    service.refreshProcesses()
                }) {
                    HStack(spacing: 5) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 11, weight: .bold))
                        Text("Refresh")
                            .font(.system(size: 11, weight: .bold))
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .background(CovaTheme.primaryGradient)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
            }
        }
    }
    
    // MARK: - Metrics Row
    private var metricsRowView: some View {
        HStack(spacing: 14) {
            ProcessStatBox(
                title: "Total Processes",
                value: "\(service.processes.count)",
                subtitle: "Active system threads",
                icon: "cpu",
                color: CovaTheme.primaryBlue
            )
            
            ProcessStatBox(
                title: "Resource Hogs",
                value: "\(service.resourceHogCount)",
                subtitle: service.resourceHogCount > 0 ? "High CPU or RAM footprint" : "All apps behaving normally",
                icon: "flame.fill",
                color: service.resourceHogCount > 0 ? .red : .secondary
            )
            
            if let topCPU = service.processes.first {
                ProcessStatBox(
                    title: "Top CPU Consumer",
                    value: "\(Int(topCPU.cpuPercent))%",
                    subtitle: topCPU.name,
                    icon: "speedometer",
                    color: topCPU.cpuPercent > 35.0 ? .orange : .blue
                )
            }
            
            if let topMem = service.processes.max(by: { $0.memoryBytes < $1.memoryBytes }) {
                ProcessStatBox(
                    title: "Top RAM Consumer",
                    value: topMem.memoryFormatted,
                    subtitle: topMem.name,
                    icon: "memorychip",
                    color: .purple
                )
            }
        }
    }
    
    // MARK: - Toolbar
    private var toolbarView: some View {
        HStack(spacing: 12) {
            Picker("Filter", selection: $service.selectedFilter) {
                ForEach(ProcessManagerService.ProcessFilter.allCases) { f in
                    Text(f.rawValue).tag(f)
                }
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 340)
            
            Spacer()
            
            // Search
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                    .font(.system(size: 11))
                TextField("Search name or PID...", text: $service.searchQuery)
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
            .padding(.vertical, 5)
            .background(Color.white.opacity(0.06))
            .cornerRadius(7)
            .frame(width: 200)
            
            // Sort
            Picker("Sort", selection: $service.sortBy) {
                ForEach(ProcessManagerService.ProcessSortOption.allCases) { s in
                    Text(s.rawValue).tag(s)
                }
            }
            .pickerStyle(.menu)
            .frame(width: 150)
        }
    }
    
    // MARK: - Table Header
    private var tableHeaderView: some View {
        HStack {
            Text("Process Name")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.secondary)
                .frame(width: 260, alignment: .leading)
            
            Text("PID")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.secondary)
                .frame(width: 70, alignment: .leading)
            
            Text("CPU %")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.secondary)
                .frame(width: 110, alignment: .trailing)
            
            Text("Memory")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.secondary)
                .frame(width: 100, alignment: .trailing)
            
            Spacer()
            
            Text("Actions")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.secondary)
                .frame(width: 120, alignment: .trailing)
        }
    }
    
    // MARK: - Empty State
    private var emptyFilterView: some View {
        VStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 28))
                .foregroundColor(.secondary)
            Text("No processes match your search or filter")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.secondary)
        }
        .padding(50)
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Subviews

private struct ProcessStatBox: View {
    let title: String
    let value: String
    let subtitle: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.secondary)
                Spacer()
                Image(systemName: icon)
                    .font(.system(size: 12))
                    .foregroundColor(color)
            }
            
            Text(value)
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.primary)
            
            Text(subtitle)
                .font(.system(size: 10))
                .foregroundColor(.secondary)
                .lineLimit(1)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }
}

@MainActor
final class AppIconCache {
    static let shared = AppIconCache()
    private var cache: [String: NSImage] = [:]
    
    func icon(for bundleID: String?) -> NSImage? {
        guard let bid = bundleID, !bid.isEmpty else { return nil }
        if let cached = cache[bid] { return cached }
        if let app = NSWorkspace.shared.runningApplications.first(where: { $0.bundleIdentifier == bid }), let icon = app.icon {
            cache[bid] = icon
            return icon
        }
        return nil
    }
}

private struct ProcessRowView: View {
    let item: ProcessItem
    let onQuit: () -> Void
    let onForceQuit: () -> Void
    
    var body: some View {
        HStack {
            // App Icon & Name
            HStack(spacing: 8) {
                if let icon = AppIconCache.shared.icon(for: item.bundleID) {
                    Image(nsImage: icon)
                        .resizable()
                        .frame(width: 18, height: 18)
                } else {
                    Image(systemName: item.isSystemProcess ? "gearshape.2.fill" : "app.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .frame(width: 18, height: 18)
                }
                
                VStack(alignment: .leading, spacing: 1) {
                    HStack(spacing: 4) {
                        Text(item.name)
                            .font(.system(size: 12, weight: .bold))
                            .lineLimit(1)
                        
                        if item.isResourceHog {
                            Image(systemName: "flame.fill")
                                .font(.system(size: 9))
                                .foregroundColor(.red)
                        }
                    }
                }
            }
            .frame(width: 260, alignment: .leading)
            
            // PID
            Text("\(item.pid)")
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(.secondary)
                .frame(width: 70, alignment: .leading)
            
            // CPU %
            HStack(spacing: 6) {
                // Mini bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.primary.opacity(0.06))
                        Capsule()
                            .fill(item.cpuPercent > 35.0 ? Color.red : CovaTheme.primaryBlue)
                            .frame(width: min(geo.size.width, geo.size.width * CGFloat(item.cpuPercent / 100.0)))
                    }
                }
                .frame(width: 50, height: 6)
                
                Text(String(format: "%.1f%%", item.cpuPercent))
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundColor(item.cpuPercent > 35.0 ? .red : .primary)
            }
            .frame(width: 110, alignment: .trailing)
            
            // Memory
            Text(item.memoryFormatted)
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundColor(.secondary)
                .frame(width: 100, alignment: .trailing)
            
            Spacer()
            
            // Actions
            HStack(spacing: 6) {
                Button(action: onQuit) {
                    Text("Quit")
                        .font(.system(size: 10, weight: .semibold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3.5)
                        .background(Color.white.opacity(0.08))
                        .cornerRadius(5)
                }
                .buttonStyle(.plain)
                
                Button(action: onForceQuit) {
                    Text("Force")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.red)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3.5)
                        .background(Color.red.opacity(0.12))
                        .cornerRadius(5)
                }
                .buttonStyle(.plain)
            }
            .frame(width: 120, alignment: .trailing)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(Color(NSColor.controlBackgroundColor).opacity(item.isResourceHog ? 0.35 : 0.15))
        .cornerRadius(6)
    }
}
