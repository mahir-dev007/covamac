import Foundation
import SwiftUI
import CryptoKit

@MainActor
public final class DuplicateFinderService: ObservableObject {
    @Published public var duplicateGroups: [DuplicateGroup] = []
    @Published public var isScanning: Bool = false
    @Published public var progress: Double = 0.0
    @Published public var statusMessage: String = "Select a folder to search for duplicate files"
    @Published public var totalScannedFiles: Int = 0
    @Published public var selectedFolderURL: URL
    
    public var totalWastedBytes: Int64 {
        duplicateGroups.reduce(0) { $0 + $1.totalWastedSize }
    }
    
    public var selectedBytesToClean: Int64 {
        duplicateGroups.reduce(0) { groupSum, group in
            let selectedCount = group.files.filter { $0.isSelected }.count
            return groupSum + (Int64(selectedCount) * group.fileSize)
        }
    }
    
    public init() {
        self.selectedFolderURL = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser
    }
    
    public func startScan(targetURL: URL? = nil) {
        guard !isScanning else { return }
        let searchURL = targetURL ?? selectedFolderURL
        self.selectedFolderURL = searchURL
        self.isScanning = true
        self.progress = 0.0
        self.duplicateGroups = []
        self.totalScannedFiles = 0
        self.statusMessage = "Indexing directory tree..."
        
        Task.detached(priority: .userInitiated) {
            let fm = FileManager.default
            guard let enumerator = fm.enumerator(
                at: searchURL,
                includingPropertiesForKeys: [.isRegularFileKey, .fileSizeKey, .contentModificationDateKey],
                options: [.skipsHiddenFiles, .skipsPackageDescendants]
            ) else {
                await MainActor.run {
                    self.isScanning = false
                    self.statusMessage = "Unable to read selected directory."
                }
                return
            }
            
            var sizeToURLs: [Int64: [URL]] = [:]
            var count = 0
            
            // Phase 1: Size grouping
            while let fileURL = enumerator.nextObject() as? URL {
                count += 1
                if count % 100 == 0 {
                    let currentCount = count
                    await MainActor.run {
                        self.totalScannedFiles = currentCount
                        self.statusMessage = "Indexed \(currentCount) files..."
                    }
                }
                
                guard let values = try? fileURL.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey]),
                      values.isRegularFile == true,
                      let size = values.fileSize,
                      size > 128 else { continue } // Skip tiny files and directories
                
                let size64 = Int64(size)
                sizeToURLs[size64, default: []].append(fileURL)
            }
            
            // Filter candidate sizes that have 2 or more files
            let candidateSizes = sizeToURLs.filter { $0.value.count > 1 }
            let totalCandidates = candidateSizes.reduce(0) { $0 + $1.value.count }
            
            await MainActor.run {
                self.statusMessage = "Analyzing \(totalCandidates) potential duplicates..."
                self.progress = 0.3
            }
            
            // Phase 2: Prefix hash (first 4KB)
            var prefixToURLs: [String: [URL]] = [:]
            var processed = 0
            
            for (size, urls) in candidateSizes {
                for url in urls {
                    processed += 1
                    if let prefixHash = Self.computePrefixHash(url: url) {
                        let key = "\(size)_\(prefixHash)"
                        prefixToURLs[key, default: []].append(url)
                    }
                }
            }
            
            // Filter prefix candidates
            let candidatePrefixes = prefixToURLs.filter { $0.value.count > 1 }
            
            await MainActor.run {
                self.statusMessage = "Performing deep cryptographic verification..."
                self.progress = 0.6
            }
            
            // Phase 3: Full SHA-256 hash
            var fullHashToURLs: [String: (Int64, [URL])] = [:]
            
            for (prefixKey, urls) in candidatePrefixes {
                guard let sizeStr = prefixKey.split(separator: "_").first,
                      let size = Int64(sizeStr) else { continue }
                
                for url in urls {
                    if let fullHash = Self.computeFullSHA256(url: url) {
                        if fullHashToURLs[fullHash] == nil {
                            fullHashToURLs[fullHash] = (size, [url])
                        } else {
                            fullHashToURLs[fullHash]?.1.append(url)
                        }
                    }
                }
            }
            
            // Phase 4: Construct groups & smart selection
            var finalGroups: [DuplicateGroup] = []
            
            for (hash, tuple) in fullHashToURLs where tuple.1.count > 1 {
                let size = tuple.0
                var files: [DuplicateFile] = []
                
                for (index, url) in tuple.1.enumerated() {
                    let date = (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? Date()
                    // Default: First is marked original, rest are selected
                    let isOriginal = (index == 0)
                    files.append(DuplicateFile(
                        url: url,
                        path: url.path,
                        name: url.lastPathComponent,
                        size: size,
                        modifiedDate: date,
                        isSelected: !isOriginal,
                        isOriginal: isOriginal
                    ))
                }
                
                finalGroups.append(DuplicateGroup(hash: hash, fileSize: size, files: files))
            }
            
            finalGroups.sort { $0.totalWastedSize > $1.totalWastedSize }
            
            await MainActor.run {
                self.duplicateGroups = finalGroups
                self.isScanning = false
                self.progress = 1.0
                self.statusMessage = "Scan complete: Found \(finalGroups.count) duplicate groups."
            }
        }
    }
    
    public func autoSelectOldest() {
        for gIndex in duplicateGroups.indices {
            // Sort files by date ascending (oldest first)
            var sortedFiles = duplicateGroups[gIndex].files.sorted { $0.modifiedDate < $1.modifiedDate }
            for fIndex in sortedFiles.indices {
                if fIndex == 0 {
                    sortedFiles[fIndex].isOriginal = true
                    sortedFiles[fIndex].isSelected = false
                } else {
                    sortedFiles[fIndex].isOriginal = false
                    sortedFiles[fIndex].isSelected = true
                }
            }
            duplicateGroups[gIndex].files = sortedFiles
        }
    }
    
    public func autoSelectNewest() {
        for gIndex in duplicateGroups.indices {
            // Sort files by date descending (newest first)
            var sortedFiles = duplicateGroups[gIndex].files.sorted { $0.modifiedDate > $1.modifiedDate }
            for fIndex in sortedFiles.indices {
                if fIndex == 0 {
                    sortedFiles[fIndex].isOriginal = true
                    sortedFiles[fIndex].isSelected = false
                } else {
                    sortedFiles[fIndex].isOriginal = false
                    sortedFiles[fIndex].isSelected = true
                }
            }
            duplicateGroups[gIndex].files = sortedFiles
        }
    }
    
    public func selectAllDuplicates() {
        for gIndex in duplicateGroups.indices {
            for fIndex in duplicateGroups[gIndex].files.indices {
                if !duplicateGroups[gIndex].files[fIndex].isOriginal {
                    duplicateGroups[gIndex].files[fIndex].isSelected = true
                }
            }
        }
    }
    
    public func deselectAll() {
        for gIndex in duplicateGroups.indices {
            for fIndex in duplicateGroups[gIndex].files.indices {
                duplicateGroups[gIndex].files[fIndex].isSelected = false
            }
        }
    }
    
    public func trashSelectedDuplicates() {
        let fm = FileManager.default
        var updatedGroups: [DuplicateGroup] = []
        
        for group in duplicateGroups {
            var remainingFiles: [DuplicateFile] = []
            for file in group.files {
                if file.isSelected && !file.isOriginal {
                    do {
                        try fm.trashItem(at: file.url, resultingItemURL: nil)
                    } catch {
                        print("Error trashing file: \(error)")
                        remainingFiles.append(file)
                    }
                } else {
                    remainingFiles.append(file)
                }
            }
            
            // Only keep group if it still has duplicates
            if remainingFiles.count > 1 {
                var updatedGroup = group
                updatedGroup.files = remainingFiles
                updatedGroups.append(updatedGroup)
            }
        }
        
        self.duplicateGroups = updatedGroups
        self.statusMessage = "Selected duplicates moved to Trash."
    }
    
    // MARK: - Hashing Helpers
    
    private nonisolated static func computePrefixHash(url: URL) -> String? {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? handle.close() }
        let prefixData = handle.readData(ofLength: 4096)
        guard !prefixData.isEmpty else { return nil }
        let digest = Insecure.MD5.hash(data: prefixData)
        return digest.map { String(format: "%02hhx", $0) }.joined()
    }
    
    private nonisolated static func computeFullSHA256(url: URL) -> String? {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? handle.close() }
        
        var hasher = SHA256()
        while autoreleasepool(invoking: {
            let chunk = handle.readData(ofLength: 1024 * 1024)
            if chunk.isEmpty { return false }
            hasher.update(data: chunk)
            return true
        }) {}
        
        let digest = hasher.finalize()
        return digest.map { String(format: "%02hhx", $0) }.joined()
    }
}
