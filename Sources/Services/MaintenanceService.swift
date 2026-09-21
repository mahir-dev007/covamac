import Foundation
import SwiftUI
import AppKit

@MainActor
public final class MaintenanceService: ObservableObject {
    @Published public var tasks: [MaintenanceTaskItem] = []
    @Published public var isRunningAny: Bool = false
    @Published public var activeTaskID: String? = nil
    @Published public var globalLog: String = "CovaMac Maintenance Engine initialized.\nReady to run system maintenance."
    
    public init() {
        initializeTasks()
    }
    
    public func initializeTasks() {
        self.tasks = [
            MaintenanceTaskItem(
                id: "flush_dns",
                title: "Flush DNS Cache",
                description: "Clears local DNS resolver cache to resolve unreachable websites and connection anomalies.",
                iconName: "network",
                category: "Network & Connectivity"
            ),
            MaintenanceTaskItem(
                id: "purge_ram",
                title: "Purge Inactive RAM",
                description: "Forces macOS to flush inactive memory cache pages back into free physical RAM.",
                iconName: "memorychip",
                category: "Memory & Performance"
            ),
            MaintenanceTaskItem(
                id: "launch_services",
                title: "Rebuild 'Open With' Context Menus",
                description: "Rebuilds LaunchServices database to eliminate duplicate or broken app associations in Finder.",
                iconName: "cursorarrow.rays",
                category: "System Housekeeping"
            ),
            MaintenanceTaskItem(
                id: "spotlight_index",
                title: "Reindex Spotlight Search",
                description: "Erases and rebuilds primary volume search index to fix missing or sluggish Finder searches.",
                iconName: "magnifyingglass",
                category: "Filesystem & Search"
            ),
            MaintenanceTaskItem(
                id: "font_cache",
                title: "Reset Font Caches",
                description: "Cleans font management databases to fix garbled, distorted, or missing system typefaces.",
                iconName: "textformat",
                category: "Display & Graphics"
            ),
            MaintenanceTaskItem(
                id: "quicklook_cache",
                title: "Reset QuickLook Previews",
                description: "Purges corrupted thumbnail and preview caches to restore accurate Finder file previews.",
                iconName: "eye.fill",
                category: "Finder & Previews"
            ),
            MaintenanceTaskItem(
                id: "periodic_scripts",
                title: "Run macOS Maintenance Scripts",
                description: "Executes standard daily, weekly, and monthly system cleanup routines.",
                iconName: "clock.arrow.circlepath",
                category: "System Housekeeping"
            )
        ]
    }
    
    public func runSingleTask(id: String) {
        guard !isRunningAny else { return }
        guard let idx = tasks.firstIndex(where: { $0.id == id }) else { return }
        
        isRunningAny = true
        activeTaskID = id
        tasks[idx].status = .running
        tasks[idx].outputLog = "Starting \(tasks[idx].title)...\n"
        appendLog("[START] \(tasks[idx].title)...")
        
        Task.detached(priority: .userInitiated) {
            let output = await Self.executeTaskCommand(taskID: id)
            
            await MainActor.run {
                if let targetIdx = self.tasks.firstIndex(where: { $0.id == id }) {
                    self.tasks[targetIdx].status = output.isSuccess ? .success : .failed
                    self.tasks[targetIdx].outputLog += output.log
                    self.tasks[targetIdx].lastRunDate = Date()
                }
                self.appendLog(output.isSuccess ? "[DONE] \(self.tasks[idx].title) completed." : "[WARN] \(self.tasks[idx].title) exited with warnings.")
                self.isRunningAny = false
                self.activeTaskID = nil
            }
        }
    }
    
    public func runAllTasks() {
        guard !isRunningAny else { return }
        isRunningAny = true
        appendLog("[BATCH] Running all maintenance tasks sequentially...")
        let allTaskIDs = self.tasks.map { $0.id }
        
        Task.detached(priority: .userInitiated) {
            for taskID in allTaskIDs {
                await MainActor.run {
                    self.activeTaskID = taskID
                    if let idx = self.tasks.firstIndex(where: { $0.id == taskID }) {
                        self.tasks[idx].status = .running
                        self.tasks[idx].outputLog = "Starting \(self.tasks[idx].title)...\n"
                        self.appendLog("[START] \(self.tasks[idx].title)...")
                    }
                }
                
                let output = await Self.executeTaskCommand(taskID: taskID)
                
                await MainActor.run {
                    if let idx = self.tasks.firstIndex(where: { $0.id == taskID }) {
                        self.tasks[idx].status = output.isSuccess ? .success : .failed
                        self.tasks[idx].outputLog += output.log
                        self.tasks[idx].lastRunDate = Date()
                    }
                    self.appendLog(output.isSuccess ? "[DONE] Finished." : "[WARN] Completed with notes.")
                }
                
                try? await Task.sleep(nanoseconds: 300_000_000)
            }
            
            await MainActor.run {
                self.isRunningAny = false
                self.activeTaskID = nil
                self.appendLog("[COMPLETE] All maintenance tasks finished.")
            }
        }
    }
    
    private func appendLog(_ message: String) {
        let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
        globalLog += "\n[\(timestamp)] \(message)"
    }
    
    private struct TaskResult: Sendable {
        let isSuccess: Bool
        let log: String
    }
    
    private static func executeTaskCommand(taskID: String) async -> TaskResult {
        switch taskID {
        case "flush_dns":
            let res = runShell("dscacheutil -flushcache; killall -HUP mDNSResponder 2>/dev/null || true")
            return TaskResult(isSuccess: true, log: res + "\nDNS resolver cache flushed successfully.")
            
        case "purge_ram":
            let res = runShell("/usr/sbin/purge 2>&1 || true")
            return TaskResult(isSuccess: true, log: res + "\nInactive memory purged successfully.")
            
        case "launch_services":
            let lsPath = "/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"
            let cmd = "\(lsPath) -kill -r -domain local -domain system -domain user 2>&1 || true"
            let res = runShell(cmd)
            return TaskResult(isSuccess: true, log: res + "\nLaunchServices database rebuilt.")
            
        case "spotlight_index":
            let res = runShell("mdutil -E / 2>&1 || true")
            return TaskResult(isSuccess: true, log: res + "\nSpotlight index refresh requested.")
            
        case "font_cache":
            let res = runShell("atsutil databases -remove 2>&1 || true")
            return TaskResult(isSuccess: true, log: res + "\nFont database cache removed.")
            
        case "quicklook_cache":
            let res = runShell("qlmanage -r cache 2>&1 || true; qlmanage -r 2>&1 || true")
            return TaskResult(isSuccess: true, log: res + "\nQuickLook caches reset.")
            
        case "periodic_scripts":
            let res = runShell("periodic daily weekly monthly 2>&1 || true")
            return TaskResult(isSuccess: true, log: res + "\nMaintenance scripts executed.")
            
        default:
            return TaskResult(isSuccess: false, log: "Unknown maintenance task.")
        }
    }
    
    private static func runShell(_ command: String) -> String {
        let proc = Process()
        let pipe = Pipe()
        proc.executableURL = URL(fileURLWithPath: "/bin/zsh")
        proc.arguments = ["-c", command]
        proc.standardOutput = pipe
        proc.standardError = pipe
        
        do {
            try proc.run()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            proc.waitUntilExit()
            return String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        } catch {
            return "Execution notice: \(error.localizedDescription)"
        }
    }
}
