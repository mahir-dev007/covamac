import Foundation
import SwiftUI
import Combine

public struct DeveloperJunkItem: Identifiable, Hashable, Sendable {
    public let id = UUID()
    public let name: String
    public let path: String
    public let category: String
    public let sizeBytes: Int64
    public let iconName: String
    public var isSelected: Bool
    
    public init(name: String, path: String, category: String, sizeBytes: Int64, iconName: String, isSelected: Bool = true) {
        self.name = name
        self.path = path
        self.category = category
        self.sizeBytes = sizeBytes
        self.iconName = iconName
        self.isSelected = isSelected
    }
}

@MainActor
public final class DeveloperCleanService: ObservableObject {
    @Published public var junkItems: [DeveloperJunkItem] = []
    @Published public var isScanning: Bool = false
    @Published public var isCleaning: Bool = false
    @Published public var totalReclaimableBytes: Int64 = 0
    @Published public var lastFreedBytesString: String = ""
    @Published public var statusMessage: String = "Ready to scan developer caches"
    
    public init() {
        scanDeveloperCaches()
    }
    
    public var selectedBytes: Int64 {
        junkItems.filter { $0.isSelected }.reduce(0) { $0 + $1.sizeBytes }
    }
    
    public func toggleItemSelection(id: UUID) {
        if let idx = junkItems.firstIndex(where: { $0.id == id }) {
            junkItems[idx].isSelected.toggle()
        }
    }
    
    public func selectAll() {
        for i in 0..<junkItems.count {
            junkItems[i].isSelected = true
        }
    }
    
    public func deselectAll() {
        for i in 0..<junkItems.count {
            junkItems[i].isSelected = false
        }
    }
    
    public func scanDeveloperCaches() {
        guard !isScanning else { return }
        isScanning = true
        statusMessage = "Scanning Xcode, Gradle & package manager caches..."
        
        Task.detached(priority: .userInitiated) {
            let fm = FileManager.default
            let home = fm.homeDirectoryForCurrentUser
            
            var discovered: [DeveloperJunkItem] = []
            
            // 1. Xcode DerivedData
            let derivedDataURL = home.appendingPathComponent("Library/Developer/Xcode/DerivedData")
            if fm.fileExists(atPath: derivedDataURL.path) {
                let size = Self.calculateDirectorySize(url: derivedDataURL)
                if size > 0 {
                    discovered.append(DeveloperJunkItem(
                        name: "Xcode DerivedData",
                        path: derivedDataURL.path,
                        category: "Xcode Build Artifacts",
                        sizeBytes: size,
                        iconName: "hammer.fill",
                        isSelected: true
                    ))
                }
            }
            
            // 2. Xcode Archives
            let archivesURL = home.appendingPathComponent("Library/Developer/Xcode/Archives")
            if fm.fileExists(atPath: archivesURL.path) {
                let size = Self.calculateDirectorySize(url: archivesURL)
                if size > 0 {
                    discovered.append(DeveloperJunkItem(
                        name: "Xcode Project Archives",
                        path: archivesURL.path,
                        category: "Xcode App Releases",
                        sizeBytes: size,
                        iconName: "archivebox.fill",
                        isSelected: false // Deselected by default for user safety
                    ))
                }
            }
            
            // 3. CoreSimulator Caches
            let simulatorCachesURL = home.appendingPathComponent("Library/Developer/CoreSimulator/Caches")
            if fm.fileExists(atPath: simulatorCachesURL.path) {
                let size = Self.calculateDirectorySize(url: simulatorCachesURL)
                if size > 0 {
                    discovered.append(DeveloperJunkItem(
                        name: "iOS Simulator Caches",
                        path: simulatorCachesURL.path,
                        category: "iOS Simulators",
                        sizeBytes: size,
                        iconName: "iphone.gen3",
                        isSelected: true
                    ))
                }
            }
            
            // 4. CocoaPods Cache
            let cocoapodsURL = home.appendingPathComponent("Library/Caches/CocoaPods")
            if fm.fileExists(atPath: cocoapodsURL.path) {
                let size = Self.calculateDirectorySize(url: cocoapodsURL)
                if size > 0 {
                    discovered.append(DeveloperJunkItem(
                        name: "CocoaPods Cache",
                        path: cocoapodsURL.path,
                        category: "Dependency Managers",
                        sizeBytes: size,
                        iconName: "shippingbox.fill",
                        isSelected: true
                    ))
                }
            }
            
            // 5. Gradle Caches (Android/Java)
            let gradleURL = home.appendingPathComponent(".gradle/caches")
            if fm.fileExists(atPath: gradleURL.path) {
                let size = Self.calculateDirectorySize(url: gradleURL)
                if size > 0 {
                    discovered.append(DeveloperJunkItem(
                        name: "Gradle Build Caches",
                        path: gradleURL.path,
                        category: "Android & Java",
                        sizeBytes: size,
                        iconName: "cpu.fill",
                        isSelected: true
                    ))
                }
            }
            
            // 6. Homebrew Cache
            let homebrewURL = home.appendingPathComponent("Library/Caches/Homebrew")
            if fm.fileExists(atPath: homebrewURL.path) {
                let size = Self.calculateDirectorySize(url: homebrewURL)
                if size > 0 {
                    discovered.append(DeveloperJunkItem(
                        name: "Homebrew Downloads Cache",
                        path: homebrewURL.path,
                        category: "macOS Package Manager",
                        sizeBytes: size,
                        iconName: "mug.fill",
                        isSelected: true
                    ))
                }
            }
            
            // 7. Swift Package Manager Cache
            let spmCacheURL = home.appendingPathComponent("Library/Caches/org.swift.swiftpm")
            if fm.fileExists(atPath: spmCacheURL.path) {
                let size = Self.calculateDirectorySize(url: spmCacheURL)
                if size > 0 {
                    discovered.append(DeveloperJunkItem(
                        name: "Swift Package Manager Cache",
                        path: spmCacheURL.path,
                        category: "Swift & Xcode",
                        sizeBytes: size,
                        iconName: "swift",
                        isSelected: true
                    ))
                }
            }
            
            await MainActor.run {
                self.junkItems = discovered
                self.totalReclaimableBytes = discovered.reduce(0) { $0 + $1.sizeBytes }
                self.isScanning = false
                if discovered.isEmpty {
                    self.statusMessage = "Developer workspace is clean. No large build caches found."
                } else {
                    let formatter = ByteCountFormatter()
                    formatter.countStyle = .file
                    let totalStr = formatter.string(fromByteCount: self.totalReclaimableBytes)
                    self.statusMessage = "Found \(discovered.count) developer cache targets (\(totalStr) reclaimable)."
                }
            }
        }
    }
    
    public func cleanSelectedJunk() {
        guard !isCleaning else { return }
        isCleaning = true
        statusMessage = "Safely purging selected developer caches..."
        
        let targets = junkItems.filter { $0.isSelected }
        
        Task.detached(priority: .userInitiated) {
            let fm = FileManager.default
            var freed: Int64 = 0
            
            for item in targets {
                let url = URL(fileURLWithPath: item.path)
                if let contents = try? fm.contentsOfDirectory(at: url, includingPropertiesForKeys: nil) {
                    for child in contents {
                        try? fm.removeItem(at: child)
                    }
                    freed += item.sizeBytes
                }
            }
            
            try? await Task.sleep(nanoseconds: 800_000_000)
            
            await MainActor.run {
                let formatter = ByteCountFormatter()
                formatter.countStyle = .file
                let freedStr = formatter.string(fromByteCount: freed)
                self.lastFreedBytesString = freedStr
                self.isCleaning = false
                self.scanDeveloperCaches()
            }
        }
    }
    
    private nonisolated static func calculateDirectorySize(url: URL) -> Int64 {
        let fm = FileManager.default
        var total: Int64 = 0
        if let enumerator = fm.enumerator(at: url, includingPropertiesForKeys: [.fileAllocatedSizeKey, .isRegularFileKey]) {
            while let fileURL = enumerator.nextObject() as? URL {
                if let vals = try? fileURL.resourceValues(forKeys: [.fileAllocatedSizeKey, .isRegularFileKey]),
                   vals.isRegularFile == true,
                   let sz = vals.fileAllocatedSize {
                    total += Int64(sz)
                }
            }
        }
        return total
    }
}
