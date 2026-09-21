import Foundation
import SwiftUI
import Combine

public struct LaunchItem: Identifiable, Hashable, Sendable {
    public let id = UUID()
    public let label: String
    public let fileName: String
    public let filePath: String
    public let locationCategory: String
    public let vendor: String
    public let programPath: String
    public let isRunAtLoad: Bool
    public var isEnabled: Bool
    public let sizeBytes: Int64
    
    public init(label: String, fileName: String, filePath: String, locationCategory: String, vendor: String, programPath: String, isRunAtLoad: Bool, isEnabled: Bool, sizeBytes: Int64) {
        self.label = label
        self.fileName = fileName
        self.filePath = filePath
        self.locationCategory = locationCategory
        self.vendor = vendor
        self.programPath = programPath
        self.isRunAtLoad = isRunAtLoad
        self.isEnabled = isEnabled
        self.sizeBytes = sizeBytes
    }
}

@MainActor
public final class StartupManagerService: ObservableObject {
    @Published public var items: [LaunchItem] = []
    @Published public var isScanning: Bool = false
    @Published public var totalFoundCount: Int = 0
    @Published public var statusMessage: String = "Ready to inspect startup items"
    
    public init() {
        scanStartupItems()
    }
    
    public func scanStartupItems() {
        guard !isScanning else { return }
        isScanning = true
        statusMessage = "Scanning LaunchAgents & LaunchDaemons..."
        
        Task.detached(priority: .userInitiated) {
            let fm = FileManager.default
            let home = fm.homeDirectoryForCurrentUser
            
            let searchDirs: [(url: URL, category: String)] = [
                (home.appendingPathComponent("Library/LaunchAgents"), "User Launch Agent"),
                (URL(fileURLWithPath: "/Library/LaunchAgents"), "System Launch Agent"),
                (URL(fileURLWithPath: "/Library/LaunchDaemons"), "System Launch Daemon")
            ]
            
            var discovered: [LaunchItem] = []
            
            for (dir, category) in searchDirs {
                guard let contents = try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: [.fileAllocatedSizeKey], options: [.skipsHiddenFiles]) else {
                    continue
                }
                
                for fileURL in contents {
                    let name = fileURL.lastPathComponent
                    guard name.hasSuffix(".plist") || name.hasSuffix(".plist.disabled") else { continue }
                    
                    let isEnabled = !name.hasSuffix(".disabled")
                    let size = (try? fileURL.resourceValues(forKeys: [.fileAllocatedSizeKey]))?.fileAllocatedSize ?? 1024
                    
                    var label = fileURL.deletingPathExtension().lastPathComponent
                    var program = ""
                    var runAtLoad = true
                    
                    if let dict = NSDictionary(contentsOf: fileURL) as? [String: Any] {
                        if let l = dict["Label"] as? String {
                            label = l
                        }
                        if let p = dict["Program"] as? String {
                            program = p
                        } else if let args = dict["ProgramArguments"] as? [String], let first = args.first {
                            program = first
                        }
                        if let r = dict["RunAtLoad"] as? Bool {
                            runAtLoad = r
                        }
                    }
                    
                    let vendor = Self.detectVendor(label: label, path: program)
                    
                    discovered.append(LaunchItem(
                        label: label,
                        fileName: name,
                        filePath: fileURL.path,
                        locationCategory: category,
                        vendor: vendor,
                        programPath: program,
                        isRunAtLoad: runAtLoad,
                        isEnabled: isEnabled,
                        sizeBytes: Int64(size)
                    ))
                }
            }
            
            discovered.sort { $0.vendor < $1.vendor }
            
            await MainActor.run {
                self.items = discovered
                self.totalFoundCount = discovered.count
                self.isScanning = false
                self.statusMessage = "Discovered \(discovered.count) background startup services."
            }
        }
    }
    
    public func toggleItemState(item: LaunchItem) {
        let fm = FileManager.default
        let currentURL = URL(fileURLWithPath: item.filePath)
        
        let newURL: URL
        if item.isEnabled {
            // Disable: rename to .plist.disabled
            newURL = currentURL.deletingPathExtension().appendingPathExtension("plist.disabled")
        } else {
            // Enable: rename back to .plist
            let base = currentURL.path.replacingOccurrences(of: ".plist.disabled", with: ".plist")
            newURL = URL(fileURLWithPath: base)
        }
        
        do {
            try fm.moveItem(at: currentURL, to: newURL)
            scanStartupItems()
        } catch {
            statusMessage = "Notice: Modifying system daemon requires root admin permissions."
        }
    }
    
    private nonisolated static func detectVendor(label: String, path: String) -> String {
        let l = label.lowercased()
        let p = path.lowercased()
        
        if l.contains("google") || p.contains("google") { return "Google" }
        if l.contains("microsoft") || p.contains("microsoft") { return "Microsoft" }
        if l.contains("adobe") || p.contains("adobe") { return "Adobe" }
        if l.contains("apple") || p.contains("apple") { return "Apple" }
        if l.contains("dropbox") || p.contains("dropbox") { return "Dropbox" }
        if l.contains("spotify") || p.contains("spotify") { return "Spotify" }
        if l.contains("docker") || p.contains("docker") { return "Docker" }
        if l.contains("slack") || p.contains("slack") { return "Slack" }
        if l.contains("zoom") || p.contains("zoom") { return "Zoom" }
        if l.contains("1password") || p.contains("1password") { return "1Password" }
        if l.contains("cleanmymac") || p.contains("cleanmymac") { return "CleanMyMac" }
        if l.contains("homebrew") || p.contains("homebrew") { return "Homebrew" }
        
        // Extract top-level domain / company from reverse DNS
        let parts = label.components(separatedBy: ".")
        if parts.count >= 2 {
            return parts[1].capitalized
        }
        return "Third-Party Service"
    }
}
