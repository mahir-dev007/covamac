import Foundation
import SwiftUI
import AppKit

@MainActor
public final class ProcessManagerService: ObservableObject {
    @Published public var processes: [ProcessItem] = []
    @Published public var isRefreshing: Bool = false
    @Published public var searchQuery: String = ""
    @Published public var selectedFilter: ProcessFilter = .all
    @Published public var sortBy: ProcessSortOption = .cpuDescending
    @Published public var statusMessage: String = "Monitoring active processes"
    
    public enum ProcessFilter: String, CaseIterable, Identifiable {
        case all = "All Processes"
        case apps = "User Applications"
        case hogs = "Resource Hogs"
        
        public var id: String { rawValue }
    }
    
    public enum ProcessSortOption: String, CaseIterable, Identifiable {
        case cpuDescending = "Highest CPU %"
        case memoryDescending = "Highest RAM"
        case name = "Process Name"
        case pid = "PID"
        
        public var id: String { rawValue }
    }
    
    private var timer: Timer?
    
    public var resourceHogCount: Int {
        processes.filter { $0.isResourceHog }.count
    }
    
    public var topResourceHogs: [ProcessItem] {
        Array(processes.filter { $0.isResourceHog || $0.cpuPercent > 10.0 }.prefix(3))
    }
    
    public var filteredProcesses: [ProcessItem] {
        processes.filter { item in
            switch selectedFilter {
            case .all: break
            case .apps:
                guard !item.isSystemProcess || item.bundleID != nil else { return false }
            case .hogs:
                guard item.isResourceHog else { return false }
            }
            
            if !searchQuery.trimmingCharacters(in: .whitespaces).isEmpty {
                let q = searchQuery.lowercased()
                let matchesName = item.name.lowercased().contains(q)
                let matchesPID = "\(item.pid)".contains(q)
                guard matchesName || matchesPID else { return false }
            }
            
            return true
        }
        .sorted { a, b in
            switch sortBy {
            case .cpuDescending: return a.cpuPercent > b.cpuPercent
            case .memoryDescending: return a.memoryBytes > b.memoryBytes
            case .name: return a.name.localizedCompare(b.name) == .orderedAscending
            case .pid: return a.pid < b.pid
            }
        }
    }
    
    public init() {
        refreshProcesses()
    }
    
    public func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.refreshProcesses()
            }
        }
    }
    
    public func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
    
    public func refreshProcesses() {
        guard !isRefreshing else { return }
        isRefreshing = true
        
        let runningApps = NSWorkspace.shared.runningApplications
        var appMap: [Int32: (name: String, bundleID: String?)] = [:]
        for app in runningApps {
            appMap[app.processIdentifier] = (app.localizedName ?? "", app.bundleIdentifier)
        }
        let myPID = ProcessInfo.processInfo.processIdentifier
        
        Task.detached(priority: .userInitiated) {
            let proc = Process()
            let pipe = Pipe()
            proc.executableURL = URL(fileURLWithPath: "/bin/ps")
            proc.arguments = ["-eo", "pid,%cpu,rss,comm"]
            proc.standardOutput = pipe
            
            do {
                try proc.run()
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                proc.waitUntilExit()
                guard let output = String(data: data, encoding: .utf8) else {
                    await MainActor.run { self.isRefreshing = false }
                    return
                }
                
                var parsedItems: [ProcessItem] = []
                let lines = output.components(separatedBy: "\n")
                
                for line in lines.dropFirst() { // Skip header line
                    let trimmed = line.trimmingCharacters(in: .whitespaces)
                    guard !trimmed.isEmpty else { continue }
                    
                    let parts = trimmed.split(separator: " ", maxSplits: 3, omittingEmptySubsequences: true)
                    guard parts.count >= 4 else { continue }
                    
                    guard let pid = Int32(parts[0]), pid != myPID else { continue }
                    let cpu = Double(parts[1]) ?? 0.0
                    let rssKB = Int64(parts[2]) ?? 0
                    let memBytes = rssKB * 1024
                    let comm = String(parts[3])
                    
                    // Determine display name and application status
                    var displayName = URL(fileURLWithPath: comm).lastPathComponent
                    var bundleID: String? = nil
                    var isSys = pid < 100 || comm.hasPrefix("/System/") || comm.hasPrefix("/usr/libexec/") || comm.hasPrefix("/sbin/")
                    
                    if let appInfo = appMap[pid] {
                        if !appInfo.name.isEmpty {
                            displayName = appInfo.name
                        }
                        bundleID = appInfo.bundleID
                        isSys = false
                    }
                    
                    // Skip tiny zero-resource system daemon artifacts
                    if isSys && cpu < 0.1 && memBytes < (5 * 1024 * 1024) {
                        continue
                    }
                    
                    let item = ProcessItem(
                        pid: pid,
                        name: displayName,
                        cpuPercent: cpu,
                        memoryBytes: memBytes,
                        path: comm,
                        isSystemProcess: isSys,
                        bundleID: bundleID
                    )
                    parsedItems.append(item)
                }
                
                // Sort by CPU descending by default
                parsedItems.sort { $0.cpuPercent > $1.cpuPercent }
                
                let finalItems = parsedItems
                await MainActor.run {
                    self.processes = finalItems
                    self.isRefreshing = false
                    let hogCount = finalItems.filter { $0.isResourceHog }.count
                    if hogCount > 0 {
                        self.statusMessage = "\(finalItems.count) processes active • \(hogCount) resource hogs detected"
                    } else {
                        self.statusMessage = "\(finalItems.count) processes active • System load normal"
                    }
                }
            } catch {
                await MainActor.run {
                    self.isRefreshing = false
                    self.statusMessage = "Process monitor error: \(error.localizedDescription)"
                }
            }
        }
    }
    
    public func terminateProcess(pid: Int32, force: Bool = false) -> Bool {
        // Protect critical macOS components
        guard pid > 1 else { return false }
        let criticalPIDs: Set<Int32> = [0, 1]
        guard !criticalPIDs.contains(pid) else { return false }
        
        let myPID = ProcessInfo.processInfo.processIdentifier
        guard pid != myPID else { return false }
        
        if let app = NSRunningApplication(processIdentifier: pid) {
            let criticalNames = ["WindowServer", "loginwindow", "launchd"]
            if let name = app.localizedName, criticalNames.contains(name) {
                return false
            }
            
            if force {
                _ = app.forceTerminate()
            } else {
                _ = app.terminate()
            }
        } else {
            let sig = force ? SIGKILL : SIGTERM
            kill(pid, sig)
        }
        
        // Remove immediately from UI and refresh
        processes.removeAll { $0.pid == pid }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            self.refreshProcesses()
        }
        return true
    }
}
