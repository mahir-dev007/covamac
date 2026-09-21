import Foundation
import SwiftUI
import AppKit

@MainActor
public final class AppUninstallerService: ObservableObject {
    @Published public var apps: [AppItem] = []
    @Published public var orphanLeftovers: [OrphanFolder] = []
    @Published public var isScanning: Bool = false
    @Published public var scanProgress: Double = 0.0
    @Published public var statusMessage: String = "Ready to scan"
    @Published public var selectedApp: AppItem? = nil
    
    public init() {}
    
    public func scanInstalledApps() {
        guard !isScanning else { return }
        isScanning = true
        scanProgress = 0.0
        statusMessage = "Discovering installed applications..."
        
        Task.detached(priority: .userInitiated) {
            let fileManager = FileManager.default
            let appDirectories: [URL] = [
                URL(fileURLWithPath: "/Applications"),
                URL(fileURLWithPath: "/System/Applications"),
                fileManager.homeDirectoryForCurrentUser.appendingPathComponent("Applications")
            ]
            
            var discoveredAppURLs: [URL] = []
            for dir in appDirectories {
                if let contents = try? fileManager.contentsOfDirectory(at: dir, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles]) {
                    for url in contents where url.pathExtension == "app" {
                        discoveredAppURLs.append(url)
                    }
                }
            }
            
            var installedBundleIds = Set<String>()
            var installedAppNames = Set<String>()
            var processedApps: [AppItem] = []
            
            let total = discoveredAppURLs.count
            for (index, appURL) in discoveredAppURLs.enumerated() {
                let progress = Double(index + 1) / Double(max(1, total))
                let infoPlistURL = appURL.appendingPathComponent("Contents/Info.plist")
                
                var bundleId = ""
                var appName = appURL.deletingPathExtension().lastPathComponent
                var version = "1.0"
                
                if let plistData = try? Data(contentsOf: infoPlistURL),
                   let plist = try? PropertyListSerialization.propertyList(from: plistData, options: [], format: nil) as? [String: Any] {
                    bundleId = (plist["CFBundleIdentifier"] as? String) ?? ""
                    if let displayName = plist["CFBundleDisplayName"] as? String, !displayName.isEmpty {
                        appName = displayName
                    } else if let bundleName = plist["CFBundleName"] as? String, !bundleName.isEmpty {
                        appName = bundleName
                    }
                    version = (plist["CFBundleShortVersionString"] as? String) ?? (plist["CFBundleVersion"] as? String) ?? "1.0"
                }
                
                if !bundleId.isEmpty {
                    installedBundleIds.insert(bundleId.lowercased())
                }
                installedAppNames.insert(appName.lowercased())
                
                let appSize = Self.calculateSize(of: appURL)
                let leftovers = Self.findLeftovers(forBundleId: bundleId, appName: appName)
                let isSystem = appURL.path.hasPrefix("/System/")
                
                let item = AppItem(
                    name: appName,
                    bundleId: bundleId,
                    version: version,
                    bundleURL: appURL,
                    appSize: appSize,
                    leftoverItems: leftovers,
                    isSelected: false,
                    isSystemApp: isSystem
                )
                processedApps.append(item)
                
                if index % 5 == 0 || index == total - 1 {
                    await MainActor.run {
                        self.scanProgress = progress
                        self.statusMessage = "Scanning: \(appName)"
                    }
                }
            }
            
            // Sort apps: largest first
            processedApps.sort { $0.totalSize > $1.totalSize }
            
            // Now hunt for orphans (abandoned files whose apps are gone)
            await MainActor.run {
                self.statusMessage = "Hunting orphaned leftovers..."
            }
            let orphans = Self.huntOrphans(installedBundleIds: installedBundleIds, installedAppNames: installedAppNames)
            
            await MainActor.run {
                self.apps = processedApps
                self.orphanLeftovers = orphans
                self.selectedApp = processedApps.first
                self.isScanning = false
                self.scanProgress = 1.0
                self.statusMessage = "Found \(processedApps.count) apps and \(orphans.count) orphaned leftover items."
            }
        }
    }
    
    public func uninstallApp(app: AppItem, removeLeftovers: Bool) -> Bool {
        let fileManager = FileManager.default
        var success = true
        
        // 1. Move app bundle to Trash if not system app
        if !app.isSystemApp {
            do {
                try fileManager.trashItem(at: app.bundleURL, resultingItemURL: nil)
            } catch {
                print("Failed to trash app bundle: \(error)")
                success = false
            }
        }
        
        // 2. Remove selected leftovers
        if removeLeftovers {
            for leftover in app.leftoverItems where leftover.isSelected {
                do {
                    try fileManager.trashItem(at: leftover.url, resultingItemURL: nil)
                } catch {
                    print("Failed to trash leftover at \(leftover.path): \(error)")
                }
            }
        }
        
        // Remove from list
        apps.removeAll { $0.id == app.id }
        if selectedApp?.id == app.id {
            selectedApp = apps.first
        }
        return success
    }
    
    public func cleanSelectedLeftovers(for app: AppItem) {
        let fileManager = FileManager.default
        var remainingLeftovers: [LeftoverItem] = []
        
        for leftover in app.leftoverItems {
            if leftover.isSelected {
                do {
                    try fileManager.trashItem(at: leftover.url, resultingItemURL: nil)
                } catch {
                    print("Error trashing \(leftover.path): \(error)")
                    remainingLeftovers.append(leftover)
                }
            } else {
                remainingLeftovers.append(leftover)
            }
        }
        
        if let idx = apps.firstIndex(where: { $0.id == app.id }) {
            apps[idx].leftoverItems = remainingLeftovers
            if selectedApp?.id == app.id {
                selectedApp = apps[idx]
            }
        }
    }
    
    public func cleanSelectedOrphans() {
        let fileManager = FileManager.default
        var remaining: [OrphanFolder] = []
        
        for orphan in orphanLeftovers {
            if orphan.isSelected {
                do {
                    try fileManager.trashItem(at: orphan.url, resultingItemURL: nil)
                } catch {
                    print("Error trashing orphan: \(error)")
                    remaining.append(orphan)
                }
            } else {
                remaining.append(orphan)
            }
        }
        orphanLeftovers = remaining
    }
    
    // MARK: - Internal Helper Functions
    
    private nonisolated static func calculateSize(of url: URL) -> Int64 {
        let fileManager = FileManager.default
        var isDir: ObjCBool = false
        guard fileManager.fileExists(atPath: url.path, isDirectory: &isDir) else { return 0 }
        
        if !isDir.boolValue {
            let attrs = try? fileManager.attributesOfItem(atPath: url.path)
            return (attrs?[.size] as? Int64) ?? 0
        }
        
        guard let enumerator = fileManager.enumerator(
            at: url,
            includingPropertiesForKeys: [.totalFileAllocatedSizeKey, .fileAllocatedSizeKey, .fileSizeKey],
            options: [.skipsHiddenFiles]
        ) else { return 0 }
        
        var totalSize: Int64 = 0
        while let fileURL = enumerator.nextObject() as? URL {
            if let resourceValues = try? fileURL.resourceValues(forKeys: [.totalFileAllocatedSizeKey, .fileSizeKey]) {
                totalSize += Int64(resourceValues.totalFileAllocatedSize ?? resourceValues.fileSize ?? 0)
            }
        }
        return totalSize
    }
    
    private nonisolated static func findLeftovers(forBundleId bundleId: String, appName: String) -> [LeftoverItem] {
        guard !bundleId.isEmpty || !appName.isEmpty else { return [] }
        let fm = FileManager.default
        let home = fm.homeDirectoryForCurrentUser
        let library = home.appendingPathComponent("Library")
        
        var candidates: [(URL, LeftoverCategory)] = []
        
        // 1. Application Support
        if !appName.isEmpty {
            candidates.append((library.appendingPathComponent("Application Support").appendingPathComponent(appName), .applicationSupport))
        }
        if !bundleId.isEmpty {
            candidates.append((library.appendingPathComponent("Application Support").appendingPathComponent(bundleId), .applicationSupport))
        }
        
        // 2. Caches
        if !bundleId.isEmpty {
            candidates.append((library.appendingPathComponent("Caches").appendingPathComponent(bundleId), .caches))
        }
        if !appName.isEmpty {
            candidates.append((library.appendingPathComponent("Caches").appendingPathComponent(appName), .caches))
        }
        
        // 3. Preferences (.plist)
        if !bundleId.isEmpty {
            candidates.append((library.appendingPathComponent("Preferences").appendingPathComponent("\(bundleId).plist"), .preferences))
        }
        
        // 4. Containers
        if !bundleId.isEmpty {
            candidates.append((library.appendingPathComponent("Containers").appendingPathComponent(bundleId), .containers))
        }
        
        // 5. Saved Application State
        if !bundleId.isEmpty {
            candidates.append((library.appendingPathComponent("Saved Application State").appendingPathComponent("\(bundleId).savedState"), .savedState))
        }
        
        // 6. Logs
        if !appName.isEmpty {
            candidates.append((library.appendingPathComponent("Logs").appendingPathComponent(appName), .logs))
        }
        if !bundleId.isEmpty {
            candidates.append((library.appendingPathComponent("Logs").appendingPathComponent(bundleId), .logs))
        }
        
        // 7. WebKit & HTTPStorages
        if !bundleId.isEmpty {
            candidates.append((library.appendingPathComponent("WebKit").appendingPathComponent(bundleId), .webKit))
            candidates.append((library.appendingPathComponent("HTTPStorages").appendingPathComponent(bundleId), .httpStorages))
        }
        
        var results: [LeftoverItem] = []
        var checkedPaths = Set<String>()
        
        for (url, category) in candidates {
            let path = url.path
            guard !checkedPaths.contains(path), fm.fileExists(atPath: path) else { continue }
            checkedPaths.insert(path)
            
            let size = calculateSize(of: url)
            results.append(LeftoverItem(path: path, url: url, category: category, size: size, isSelected: true))
        }
        
        return results
    }
    
    private nonisolated static func huntOrphans(installedBundleIds: Set<String>, installedAppNames: Set<String>) -> [OrphanFolder] {
        let fm = FileManager.default
        let home = fm.homeDirectoryForCurrentUser
        let library = home.appendingPathComponent("Library")
        var orphans: [OrphanFolder] = []
        
        let searchRoots: [(URL, LeftoverCategory)] = [
            (library.appendingPathComponent("Application Support"), .applicationSupport),
            (library.appendingPathComponent("Caches"), .caches),
            (library.appendingPathComponent("Saved Application State"), .savedState)
        ]
        
        // System / Apple folders to always protect from being marked orphan
        let protectedPrefixes = [
            "apple", "com.apple", "google", "microsoft", "adobe", "cloudstorage",
            "crashreporter", "quicklook", "siri", "spotlight", "addressbook",
            "calendars", "accounts", "fontcollections", "messages", "safari"
        ]
        
        for (rootURL, category) in searchRoots {
            guard let contents = try? fm.contentsOfDirectory(at: rootURL, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) else {
                continue
            }
            
            for itemURL in contents {
                let name = itemURL.deletingPathExtension().lastPathComponent
                let lowerName = name.lowercased()
                
                // Skip protected prefixes
                if protectedPrefixes.contains(where: { lowerName.hasPrefix($0) }) {
                    continue
                }
                
                // If it's a bundle ID like com.vendor.App
                let isInstalled: Bool
                if lowerName.contains(".") {
                    isInstalled = installedBundleIds.contains(lowerName) || installedAppNames.contains(lowerName)
                } else {
                    isInstalled = installedAppNames.contains(lowerName)
                }
                
                if !isInstalled {
                    let size = calculateSize(of: itemURL)
                    if size > 1024 * 100 { // Only flag entries > 100 KB
                        orphans.append(OrphanFolder(
                            presumedAppName: name,
                            path: itemURL.path,
                            url: itemURL,
                            category: category,
                            size: size,
                            isSelected: true
                        ))
                    }
                }
            }
        }
        
        orphans.sort { $0.size > $1.size }
        return orphans
    }
}
