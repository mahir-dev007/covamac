import SwiftUI
import AppKit

public struct DuplicateFinderScreen: View {
    @ObservedObject var duplicateService: DuplicateFinderService
    @ObservedObject var adEngine: AdEngineService
    
    @State private var showConfirmTrash: Bool = false
    
    public init(duplicateService: DuplicateFinderService, adEngine: AdEngineService) {
        self.duplicateService = duplicateService
        self.adEngine = adEngine
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            // Header Bar
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Duplicate File Finder")
                        .font(.system(size: 22, weight: .bold))
                    Text("Scan directories using cryptographic SHA-256 matching to safely reclaim storage.")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Target Folder Picker
                Button(action: selectCustomFolder) {
                    HStack(spacing: 6) {
                        Image(systemName: "folder")
                        Text(duplicateService.selectedFolderURL.lastPathComponent)
                            .lineLimit(1)
                    }
                    .font(.system(size: 12, weight: .medium))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.gray.opacity(0.15))
                    .cornerRadius(6)
                }
                .buttonStyle(.plain)
                
                Button(action: {
                    duplicateService.startScan()
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "magnifyingglass")
                        Text(duplicateService.isScanning ? "Scanning..." : "Find Duplicates")
                    }
                    .font(.system(size: 12, weight: .bold))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .background(CovaTheme.primaryGradient)
                    .foregroundColor(.white)
                    .cornerRadius(6)
                }
                .buttonStyle(.plain)
                .disabled(duplicateService.isScanning)
            }
            .padding(16)
            .background(Color(NSColor.windowBackgroundColor).opacity(0.8))
            
            Divider()
            
            if duplicateService.isScanning {
                VStack(spacing: 16) {
                    ProgressView(value: duplicateService.progress)
                        .frame(width: 300)
                    Text(duplicateService.statusMessage)
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if duplicateService.duplicateGroups.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 40))
                        .foregroundColor(CovaTheme.primaryBlue)
                    Text("Ready to Find Duplicates")
                        .font(.system(size: 16, weight: .bold))
                    Text("Select a folder above and click 'Find Duplicates' to scan for exact file duplicates.")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                    
                    HStack(spacing: 10) {
                        QuickFolderButton(name: "Downloads", icon: "arrow.down.circle", url: FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first) { url in
                            duplicateService.selectedFolderURL = url
                            duplicateService.startScan()
                        }
                        QuickFolderButton(name: "Documents", icon: "doc.text", url: FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first) { url in
                            duplicateService.selectedFolderURL = url
                            duplicateService.startScan()
                        }
                        QuickFolderButton(name: "Pictures", icon: "photo", url: FileManager.default.urls(for: .picturesDirectory, in: .userDomainMask).first) { url in
                            duplicateService.selectedFolderURL = url
                            duplicateService.startScan()
                        }
                    }
                    .padding(.top, 10)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                // Results View
                VStack(spacing: 12) {
                    // Action & Summary Bar
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Found \(duplicateService.duplicateGroups.count) Duplicate Sets")
                                .font(.system(size: 14, weight: .bold))
                            Text("Wasted Space: \(formatBytes(duplicateService.totalWastedBytes)) | Selected to Trash: \(formatBytes(duplicateService.selectedBytesToClean))")
                                .font(.system(size: 12))
                                .foregroundColor(CovaTheme.accentAmber)
                        }
                        
                        Spacer()
                        
                        Menu("Smart Select") {
                            Button("Keep Oldest Files") { duplicateService.autoSelectOldest() }
                            Button("Keep Newest Files") { duplicateService.autoSelectNewest() }
                            Button("Select All Duplicates") { duplicateService.selectAllDuplicates() }
                            Button("Deselect All") { duplicateService.deselectAll() }
                        }
                        .menuStyle(.borderedButton)
                        
                        Button(action: {
                            showConfirmTrash = true
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: "trash.fill")
                                Text("Trash Selected (\(formatBytes(duplicateService.selectedBytesToClean)))")
                            }
                            .font(.system(size: 12, weight: .bold))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(duplicateService.selectedBytesToClean > 0 ? CovaTheme.accentRed : Color.gray)
                            .foregroundColor(.white)
                            .cornerRadius(6)
                        }
                        .buttonStyle(.plain)
                        .disabled(duplicateService.selectedBytesToClean == 0)
                        .alert(isPresented: $showConfirmTrash) {
                            Alert(
                                title: Text("Move Selected Duplicates to Trash?"),
                                message: Text("This will safely move the selected duplicate copies to the macOS Trash. The original copies will be kept untouched."),
                                primaryButton: .destructive(Text("Move to Trash")) {
                                    duplicateService.trashSelectedDuplicates()
                                },
                                secondaryButton: .cancel()
                            )
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 10)
                    
                    // List of duplicate sets
                    List {
                        ForEach(duplicateService.duplicateGroups.indices, id: \.self) { gIndex in
                            let group = duplicateService.duplicateGroups[gIndex]
                            Section(header: duplicateGroupHeader(group: group)) {
                                ForEach(group.files.indices, id: \.self) { fIndex in
                                    let file = group.files[fIndex]
                                    HStack(spacing: 10) {
                                        Toggle("", isOn: Binding(
                                            get: { duplicateService.duplicateGroups[gIndex].files[fIndex].isSelected },
                                            set: { duplicateService.duplicateGroups[gIndex].files[fIndex].isSelected = $0 }
                                        ))
                                        .toggleStyle(.checkbox)
                                        .disabled(file.isOriginal)
                                        
                                        Image(systemName: "doc")
                                            .foregroundColor(.secondary)
                                        
                                        VStack(alignment: .leading, spacing: 2) {
                                            HStack {
                                                Text(file.name)
                                                    .font(.system(size: 12, weight: .semibold))
                                                if file.isOriginal {
                                                    Text("ORIGINAL")
                                                        .font(.system(size: 8, weight: .black))
                                                        .padding(.horizontal, 4)
                                                        .padding(.vertical, 1)
                                                        .background(Color.blue.opacity(0.18))
                                                        .foregroundColor(.blue)
                                                        .cornerRadius(3)
                                                }
                                            }
                                            Text(file.path)
                                                .font(.system(size: 10, design: .monospaced))
                                                .foregroundColor(.secondary)
                                                .lineLimit(1)
                                        }
                                        
                                        Spacer()
                                        
                                        Text(file.modifiedDate, style: .date)
                                            .font(.system(size: 10))
                                            .foregroundColor(.secondary)
                                    }
                                    .padding(.vertical, 2)
                                }
                            }
                        }
                    }
                    .listStyle(.inset)
                }
            }
        }
    }
    
    private func duplicateGroupHeader(group: DuplicateGroup) -> some View {
        HStack {
            Image(systemName: "doc.on.doc.fill")
                .foregroundColor(CovaTheme.primaryBlue)
            Text("\(group.files.count) Duplicate Files (\(formatBytes(group.fileSize)) each)")
                .font(.system(size: 12, weight: .bold))
            Spacer()
            Text("Wasted: \(formatBytes(group.totalWastedSize))")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(CovaTheme.accentAmber)
        }
        .padding(.vertical, 2)
    }
    
    private func selectCustomFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = false
        if panel.runModal() == .OK, let url = panel.url {
            duplicateService.selectedFolderURL = url
        }
    }
    
    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}

private struct QuickFolderButton: View {
    let name: String
    let icon: String
    let url: URL?
    let onSelect: (URL) -> Void
    
    var body: some View {
        Button(action: {
            if let u = url { onSelect(u) }
        }) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                Text(name)
            }
            .font(.system(size: 12, weight: .medium))
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.gray.opacity(0.15))
            .cornerRadius(6)
        }
        .buttonStyle(.plain)
    }
}
