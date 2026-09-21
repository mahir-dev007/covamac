import Foundation
import SwiftUI
import AppKit

@MainActor
public final class LargeFilesService: ObservableObject {
    @Published public var largeFiles: [LargeFileItem] = []
    @Published public var isScanning: Bool = false
    @Published public var progress: Double = 0.0
    @Published public var statusMessage: String = "Ready to scan for large & old files"
    @Published public var scannedCount: Int = 0
    @Published public var selectedFolderURL: URL
    
    // Filters & Sorting
    @Published public var selectedSizeTier: LargeFileSizeTier = .all
    @Published public var selectedKind: LargeFileKind = .all
    @Published public var selectedAgeTier: LargeFileAgeTier = .all
    @Published public var searchQuery: String = ""
    @Published public var sortBy: SortOption = .sizeDescending
    
    public enum SortOption: String, CaseIterable, Identifiable {
        case sizeDescending = "Largest First"
        case sizeAscending = "Smallest First"
        case dateOldest = "Oldest First"
        case dateNewest = "Newest First"
        case name = "Name"
        
        public var id: String { rawValue }
    }
    
    public var minSizeBytes: Int64 = 100 * 1024 * 1024 // 100 MB threshold
    
    public var totalReclaimableBytes: Int64 {
        largeFiles.reduce(0) { $0 + $1.sizeBytes }
    }
    
    public var selectedBytes: Int64 {
        largeFiles.filter { $0.isSelected }.reduce(0) { $0 + $1.sizeBytes }
    }
    
    public var selectedCount: Int {
        largeFiles.filter { $0.isSelected }.count
    }
    
    public var filteredFiles: [LargeFileItem] {
        largeFiles.filter { item in
            // Size filter
            switch selectedSizeTier {
            case .all: break
            case .huge:
                guard item.sizeBytes >= (1024 * 1024 * 1024) else { return false }
            case .large:
                guard item.sizeBytes >= (500 * 1024 * 1024) && item.sizeBytes < (1024 * 1024 * 1024) else { return false }
            case .medium:
                guard item.sizeBytes < (500 * 1024 * 1024) else { return false }
            }
            
            // Kind filter
            if selectedKind != .all && item.kind != selectedKind {
                return false
            }
            
            // Age filter
            let now = Date()
            let daysOld = Calendar.current.dateComponents([.day], from: item.modificationDate, to: now).day ?? 0
            switch selectedAgeTier {
            case .all: break
            case .olderThanYear:
                guard daysOld >= 365 else { return false }
            case .olderThanThreeMonths:
                guard daysOld >= 90 else { return false }
            case .olderThanMonth:
                guard daysOld >= 30 else { return false }
            }
            
            // Search query
            if !searchQuery.trimmingCharacters(in: .whitespaces).isEmpty {
                guard item.name.localizedCaseInsensitiveContains(searchQuery) else { return false }
            }
            
            return true
        }
        .sorted { a, b in
            switch sortBy {
            case .sizeDescending: return a.sizeBytes > b.sizeBytes
            case .sizeAscending: return a.sizeBytes < b.sizeBytes
            case .dateOldest: return a.modificationDate < b.modificationDate
            case .dateNewest: return a.modificationDate > b.modificationDate
            case .name: return a.name.localizedCompare(b.name) == .orderedAscending
            }
        }
    }
    
    public init() {
        self.selectedFolderURL = FileManager.default.homeDirectoryForCurrentUser
    }
    
    public func startScan(targetURL: URL? = nil) {
        guard !isScanning else { return }
        let searchDir = targetURL ?? selectedFolderURL
        self.selectedFolderURL = searchDir
        self.isScanning = true
        self.progress = 0.0
        self.scannedCount = 0
        self.largeFiles = []
        self.statusMessage = "Indexing \(searchDir.lastPathComponent)..."
        
        Task.detached(priority: .userInitiated) {
            let fm = FileManager.default
            let keys: [URLResourceKey] = [
                .isRegularFileKey,
                .fileSizeKey,
                .contentModificationDateKey,
                .contentAccessDateKey,
                .isPackageKey
            ]
            
            guard let enumerator = fm.enumerator(
                at: searchDir,
                includingPropertiesForKeys: keys,
                options: [.skipsHiddenFiles, .skipsPackageDescendants]
            ) else {
                await MainActor.run {
                    self.isScanning = false
                    self.statusMessage = "Unable to read selected folder."
                }
                return
            }
            
            var discovered: [LargeFileItem] = []
            var count = 0
            let threshold = await self.minSizeBytes
            
            while let fileURL = enumerator.nextObject() as? URL {
                count += 1
                if count % 200 == 0 {
                    let currentCount = count
                    await MainActor.run {
                        self.scannedCount = currentCount
                        self.statusMessage = "Scanned \(currentCount) files..."
                    }
                }
                
                guard let values = try? fileURL.resourceValues(forKeys: Set(keys)),
                      values.isRegularFile == true,
                      values.isPackage != true,
                      let size = values.fileSize,
                      Int64(size) >= threshold else {
                    continue
                }
                
                let ext = fileURL.pathExtension.lowercased()
                let kind = Self.classifyKind(extension: ext)
                let modDate = values.contentModificationDate ?? Date()
                let accDate = values.contentAccessDate
                
                let item = LargeFileItem(
                    url: fileURL,
                    name: fileURL.lastPathComponent,
                    sizeBytes: Int64(size),
                    modificationDate: modDate,
                    accessDate: accDate,
                    kind: kind,
                    isSelected: false
                )
                discovered.append(item)
            }
            
            // Sort by size descending initially
            discovered.sort { $0.sizeBytes > $1.sizeBytes }
            
            let finalItems = discovered
            let finalCount = count
            await MainActor.run {
                self.largeFiles = finalItems
                self.scannedCount = finalCount
                self.isScanning = false
                self.progress = 1.0
                let totalStr = ByteCountFormatter.string(fromByteCount: finalItems.reduce(0) { $0 + $1.sizeBytes }, countStyle: .file)
                self.statusMessage = "Found \(finalItems.count) large files taking up \(totalStr)."
            }
        }
    }
    
    nonisolated private static func classifyKind(extension ext: String) -> LargeFileKind {
        switch ext {
        case "dmg", "iso", "pkg", "toast", "vdi", "vmdk", "qcow2", "img":
            return .diskImages
        case "zip", "tar", "gz", "tgz", "bz2", "7z", "rar", "xz", "zst":
            return .archives
        case "mov", "mp4", "m4v", "mkv", "avi", "webm", "wav", "flac", "aif", "mp3", "aac":
            return .media
        case "sqlite", "db", "psd", "ai", "sketch", "fig", "pdf", "raw", "cr2", "nef", "doc", "docx", "xls", "xlsx":
            return .documents
        default:
            return .other
        }
    }
    
    public func toggleItemSelection(id: UUID) {
        if let idx = largeFiles.firstIndex(where: { $0.id == id }) {
            largeFiles[idx].isSelected.toggle()
        }
    }
    
    public func selectAllFiltered() {
        let filteredIDs = Set(filteredFiles.map { $0.id })
        for i in 0..<largeFiles.count {
            if filteredIDs.contains(largeFiles[i].id) {
                largeFiles[i].isSelected = true
            }
        }
    }
    
    public func deselectAll() {
        for i in 0..<largeFiles.count {
            largeFiles[i].isSelected = false
        }
    }
    
    public func revealInFinder(url: URL) {
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }
    
    public func moveSelectedToTrash() {
        let selectedItems = largeFiles.filter { $0.isSelected }
        guard !selectedItems.isEmpty else { return }
        
        let fm = FileManager.default
        var deletedIDs: Set<UUID> = []
        var failedCount = 0
        
        for item in selectedItems {
            do {
                try fm.trashItem(at: item.url, resultingItemURL: nil)
                deletedIDs.insert(item.id)
            } catch {
                failedCount += 1
            }
        }
        
        largeFiles.removeAll { deletedIDs.contains($0.id) }
        
        let freedBytes = selectedItems.filter { deletedIDs.contains($0.id) }.reduce(0) { $0 + $1.sizeBytes }
        let freedStr = ByteCountFormatter.string(fromByteCount: freedBytes, countStyle: .file)
        
        if failedCount > 0 {
            statusMessage = "Moved \(deletedIDs.count) files (\(freedStr)) to Trash. (\(failedCount) failed)."
        } else {
            statusMessage = "Successfully moved \(deletedIDs.count) files (\(freedStr)) to Trash."
        }
    }
}
