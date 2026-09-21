import Foundation
import SwiftUI

@MainActor
public final class SystemDiagnosticsService: ObservableObject {
    @Published public var checkItems: [DiagnosticCheckItem] = []
    @Published public var isScanning: Bool = false
    @Published public var overallHealthScore: Int = 98
    @Published public var osVersionString: String = ""
    @Published public var uptimeString: String = ""
    
    public init() {
        runDiagnostics()
    }
    
    public func runDiagnostics() {
        guard !isScanning else { return }
        isScanning = true
        
        Task.detached(priority: .userInitiated) {
            let version = ProcessInfo.processInfo.operatingSystemVersionString
            let uptime = Self.formatUptime(ProcessInfo.processInfo.systemUptime)
            
            // 1. SIP Status
            let sipOutput = Self.runCommand(path: "/usr/bin/csrutil", args: ["status"])
            let isSipEnabled = sipOutput.lowercased().contains("enabled")
            
            // 2. FileVault Status
            let fdeOutput = Self.runCommand(path: "/usr/bin/fdesetup", args: ["status"])
            let isFdeOn = fdeOutput.lowercased().contains("on")
            
            // 3. Thermal State
            let thermal = ProcessInfo.processInfo.thermalState
            let thermalStatus: DiagnosticStatus
            let thermalDetail: String
            switch thermal {
            case .nominal:
                thermalStatus = .healthy
                thermalDetail = "Operating within normal temperature limits. No throttling."
            case .fair:
                thermalStatus = .info
                thermalDetail = "Slight thermal elevation. Fans may spin up slightly."
            case .serious:
                thermalStatus = .warning
                thermalDetail = "High temperature detected. System may be actively throttling."
            case .critical:
                thermalStatus = .critical
                thermalDetail = "Critical heat! System is heavily throttling CPU to prevent damage."
            @unknown default:
                thermalStatus = .healthy
                thermalDetail = "Thermal state normal."
            }
            
            // 4. Crash Reports Scanner
            let crashCount = Self.countCrashReports()
            let crashStatus: DiagnosticStatus
            let crashDetail: String
            if crashCount == 0 {
                crashStatus = .healthy
                crashDetail = "Zero recent application crashes or kernel panics found."
            } else if crashCount < 5 {
                crashStatus = .info
                crashDetail = "\(crashCount) crash reports logged in DiagnosticReports."
            } else {
                crashStatus = .warning
                crashDetail = "\(crashCount) crash reports found! Some apps may be crashing frequently."
            }
            
            // 5. Memory Swap Pressure
            let swapOutput = Self.runCommand(path: "/usr/sbin/sysctl", args: ["vm.swapusage"])
            
            var items: [DiagnosticCheckItem] = []
            
            items.append(DiagnosticCheckItem(
                title: "System Integrity Protection (SIP)",
                category: "Security & Kernel",
                status: isSipEnabled ? .healthy : .warning,
                details: isSipEnabled ? "SIP is active and safeguarding system binaries." : "SIP is disabled. Kernel modifications are unrestricted.",
                icon: isSipEnabled ? "lock.shield.fill" : "exclamationmark.shield.fill"
            ))
            
            items.append(DiagnosticCheckItem(
                title: "FileVault Disk Encryption",
                category: "Data Security",
                status: isFdeOn ? .healthy : .info,
                details: isFdeOn ? "Full Disk Encryption (XTS-AES 128) is enabled." : "FileVault is turned off. Your disk data is not encrypted at rest.",
                icon: isFdeOn ? "externaldrive.badge.checkmark" : "externaldrive.badge.xmark"
            ))
            
            items.append(DiagnosticCheckItem(
                title: "Thermal Pressure & Throttling",
                category: "Hardware",
                status: thermalStatus,
                details: thermalDetail,
                icon: "thermometer.medium"
            ))
            
            items.append(DiagnosticCheckItem(
                title: "System Stability & Crash Auditor",
                category: "Diagnostics",
                status: crashStatus,
                details: crashDetail,
                icon: "waveform.path.ecg"
            ))
            
            items.append(DiagnosticCheckItem(
                title: "Virtual Memory Swap Usage",
                category: "Memory",
                status: .healthy,
                details: swapOutput.trimmingCharacters(in: .whitespacesAndNewlines),
                icon: "memorychip"
            ))
            
            // Score calculation
            var score = 100
            if !isSipEnabled { score -= 15 }
            if !isFdeOn { score -= 10 }
            if thermalStatus == .warning { score -= 15 }
            if thermalStatus == .critical { score -= 30 }
            if crashCount > 10 { score -= 10 }
            score = max(30, min(100, score))
            
            await MainActor.run {
                self.checkItems = items
                self.osVersionString = version
                self.uptimeString = uptime
                self.overallHealthScore = score
                self.isScanning = false
            }
        }
    }
    
    private nonisolated static func runCommand(path: String, args: [String]) -> String {
        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = args
        process.standardOutput = pipe
        process.standardError = pipe
        
        do {
            try process.run()
            process.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            return String(data: data, encoding: .utf8) ?? ""
        } catch {
            return "N/A"
        }
    }
    
    private nonisolated static func formatUptime(_ seconds: TimeInterval) -> String {
        let days = Int(seconds) / 86400
        let hours = (Int(seconds) % 86400) / 3600
        let minutes = (Int(seconds) % 3600) / 60
        
        if days > 0 {
            return "\(days)d \(hours)h \(minutes)m"
        } else {
            return "\(hours)h \(minutes)m"
        }
    }
    
    private nonisolated static func countCrashReports() -> Int {
        let fm = FileManager.default
        let userReports = fm.homeDirectoryForCurrentUser.appendingPathComponent("Library/Logs/DiagnosticReports")
        guard let files = try? fm.contentsOfDirectory(at: userReports, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) else {
            return 0
        }
        return files.filter { $0.pathExtension == "ips" || $0.pathExtension == "crash" }.count
    }
}
