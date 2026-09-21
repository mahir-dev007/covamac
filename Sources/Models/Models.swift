import Foundation
import SwiftUI

// MARK: - Navigation Enums

public enum NavigationSection: String, CaseIterable, Identifiable {
    case dashboard = "Smart Care"
    case spaceLens = "Large & Old Files"
    case processes = "Process Manager"
    case maintenance = "System Maintenance"
    case battery = "Battery & Charger"
    case uninstaller = "Pro Uninstaller"
    case devClean = "Developer Clean"
    case duplicates = "Duplicate Finder"
    case network = "Network & Ping"
    case startup = "Startup Items"
    case hardwareTesters = "Hardware Testers"
    case diagnostics = "System Health"
    case settings = "Settings"
    
    public var id: String { rawValue }
    
    public var iconName: String {
        switch self {
        case .dashboard: return "sparkles"
        case .spaceLens: return "chart.pie.fill"
        case .processes: return "list.bullet.rectangle.portrait.fill"
        case .maintenance: return "wrench.and.screwdriver.fill"
        case .battery: return "battery.100.bolt"
        case .uninstaller: return "trash.square.fill"
        case .devClean: return "hammer.fill"
        case .duplicates: return "doc.on.doc.fill"
        case .network: return "network"
        case .startup: return "bolt.horizontal.fill"
        case .hardwareTesters: return "cpu.fill"
        case .diagnostics: return "waveform.path.ecg"
        case .settings: return "gearshape.fill"
        }
    }
}

// MARK: - Leftover & Uninstaller Models

public enum LeftoverCategory: String, CaseIterable, Identifiable, Codable {
    case applicationSupport = "Application Support"
    case caches = "Caches"
    case preferences = "Preferences"
    case containers = "Containers"
    case groupContainers = "Group Containers"
    case savedState = "Saved State"
    case logs = "Logs & Diagnostics"
    case httpStorages = "HTTP Storages"
    case webKit = "WebKit Data"
    case other = "Other Residuals"
    
    public var id: String { rawValue }
    
    public var iconName: String {
        switch self {
        case .applicationSupport: return "folder.fill.badge.gearshape"
        case .caches: return "archivebox.fill"
        case .preferences: return "slider.horizontal.3"
        case .containers: return "shippingbox.fill"
        case .groupContainers: return "square.stack.3d.down.right.fill"
        case .savedState: return "clock.arrow.circlepath"
        case .logs: return "doc.text.fill"
        case .httpStorages: return "network"
        case .webKit: return "safari.fill"
        case .other: return "doc.badge.ellipsis"
        }
    }
}

public struct LeftoverItem: Identifiable, Hashable {
    public let id = UUID()
    public let path: String
    public let url: URL
    public let category: LeftoverCategory
    public let size: Int64
    public var isSelected: Bool = true
    
    public init(path: String, url: URL, category: LeftoverCategory, size: Int64, isSelected: Bool = true) {
        self.path = path
        self.url = url
        self.category = category
        self.size = size
        self.isSelected = isSelected
    }
}

public struct AppItem: Identifiable, Hashable {
    public let id = UUID()
    public let name: String
    public let bundleId: String
    public let version: String
    public let bundleURL: URL
    public let appSize: Int64
    public var leftoverItems: [LeftoverItem]
    public var isSelected: Bool = false
    public var isSystemApp: Bool = false
    
    public var totalLeftoverSize: Int64 {
        leftoverItems.reduce(0) { $0 + $1.size }
    }
    
    public var totalSize: Int64 {
        appSize + totalLeftoverSize
    }
    
    public init(name: String, bundleId: String, version: String, bundleURL: URL, appSize: Int64, leftoverItems: [LeftoverItem] = [], isSelected: Bool = false, isSystemApp: Bool = false) {
        self.name = name
        self.bundleId = bundleId
        self.version = version
        self.bundleURL = bundleURL
        self.appSize = appSize
        self.leftoverItems = leftoverItems
        self.isSelected = isSelected
        self.isSystemApp = isSystemApp
    }
}

public struct OrphanFolder: Identifiable, Hashable {
    public let id = UUID()
    public let presumedAppName: String
    public let path: String
    public let url: URL
    public let category: LeftoverCategory
    public let size: Int64
    public var isSelected: Bool = true
    
    public init(presumedAppName: String, path: String, url: URL, category: LeftoverCategory, size: Int64, isSelected: Bool = true) {
        self.presumedAppName = presumedAppName
        self.path = path
        self.url = url
        self.category = category
        self.size = size
        self.isSelected = isSelected
    }
}

// MARK: - Duplicate Finder Models

public struct DuplicateFile: Identifiable, Hashable {
    public let id = UUID()
    public let url: URL
    public let path: String
    public let name: String
    public let size: Int64
    public let modifiedDate: Date
    public var isSelected: Bool
    public var isOriginal: Bool
    
    public init(url: URL, path: String, name: String, size: Int64, modifiedDate: Date, isSelected: Bool = false, isOriginal: Bool = false) {
        self.url = url
        self.path = path
        self.name = name
        self.size = size
        self.modifiedDate = modifiedDate
        self.isSelected = isSelected
        self.isOriginal = isOriginal
    }
}

public struct DuplicateGroup: Identifiable, Hashable {
    public let id = UUID()
    public let hash: String
    public let fileSize: Int64
    public var files: [DuplicateFile]
    
    public var totalWastedSize: Int64 {
        let count = files.count
        guard count > 1 else { return 0 }
        return fileSize * Int64(count - 1)
    }
    
    public init(hash: String, fileSize: Int64, files: [DuplicateFile]) {
        self.hash = hash
        self.fileSize = fileSize
        self.files = files
    }
}

// MARK: - Battery & Charger Models

public struct ChargerInfo: Hashable {
    public var isConnected: Bool
    public var wattage: Int
    public var name: String
    public var manufacturer: String
    public var serialNumber: String
    public var voltageMV: Int
    public var currentMA: Int
    public var hardwareVersion: String
    public var firmwareVersion: String
    public var chargingStatusText: String
    
    public init(
        isConnected: Bool = false,
        wattage: Int = 0,
        name: String = "Not Connected",
        manufacturer: String = "Apple Inc.",
        serialNumber: String = "N/A",
        voltageMV: Int = 0,
        currentMA: Int = 0,
        hardwareVersion: String = "1.0",
        firmwareVersion: String = "N/A",
        chargingStatusText: String = "Not Charging"
    ) {
        self.isConnected = isConnected
        self.wattage = wattage
        self.name = name
        self.manufacturer = manufacturer
        self.serialNumber = serialNumber
        self.voltageMV = voltageMV
        self.currentMA = currentMA
        self.hardwareVersion = hardwareVersion
        self.firmwareVersion = firmwareVersion
        self.chargingStatusText = chargingStatusText
    }
}

public struct BatteryInfo: Hashable {
    public var isBatteryInstalled: Bool
    public var stateOfCharge: Int // 0-100%
    public var isCharging: Bool
    public var isAcConnected: Bool
    public var isFullyCharged: Bool
    public var cycleCount: Int
    public var maxCycleCount: Int
    public var currentCapacitymAh: Int
    public var maxCapacitymAh: Int
    public var designCapacitymAh: Int
    public var healthPercentage: Double
    public var temperatureCelsius: Double
    public var voltageVolts: Double
    public var amperagemA: Int
    public var condition: String
    public var serialNumber: String
    public var manufacturer: String
    public var deviceName: String
    public var charger: ChargerInfo?
    
    public var temperatureFahrenheit: Double {
        (temperatureCelsius * 9.0 / 5.0) + 32.0
    }
    
    public init(
        isBatteryInstalled: Bool = true,
        stateOfCharge: Int = 100,
        isCharging: Bool = false,
        isAcConnected: Bool = true,
        isFullyCharged: Bool = false,
        cycleCount: Int = 0,
        maxCycleCount: Int = 1000,
        currentCapacitymAh: Int = 5000,
        maxCapacitymAh: Int = 5000,
        designCapacitymAh: Int = 5000,
        healthPercentage: Double = 100.0,
        temperatureCelsius: Double = 30.0,
        voltageVolts: Double = 12.0,
        amperagemA: Int = 0,
        condition: String = "Normal",
        serialNumber: String = "N/A",
        manufacturer: String = "Apple",
        deviceName: String = "InternalBattery",
        charger: ChargerInfo? = nil
    ) {
        self.isBatteryInstalled = isBatteryInstalled
        self.stateOfCharge = stateOfCharge
        self.isCharging = isCharging
        self.isAcConnected = isAcConnected
        self.isFullyCharged = isFullyCharged
        self.cycleCount = cycleCount
        self.maxCycleCount = maxCycleCount
        self.currentCapacitymAh = currentCapacitymAh
        self.maxCapacitymAh = maxCapacitymAh
        self.designCapacitymAh = designCapacitymAh
        self.healthPercentage = healthPercentage
        self.temperatureCelsius = temperatureCelsius
        self.voltageVolts = voltageVolts
        self.amperagemA = amperagemA
        self.condition = condition
        self.serialNumber = serialNumber
        self.manufacturer = manufacturer
        self.deviceName = deviceName
        self.charger = charger
    }
}

// MARK: - Diagnostic & Hardware Tester Models

public enum DiagnosticStatus: String {
    case healthy = "Healthy"
    case warning = "Attention Needed"
    case critical = "Critical"
    case info = "Informational"
    
    public var color: Color {
        switch self {
        case .healthy: return Color.green
        case .warning: return Color.orange
        case .critical: return Color.red
        case .info: return Color.blue
        }
    }
}

public struct DiagnosticCheckItem: Identifiable {
    public let id = UUID()
    public let title: String
    public let category: String
    public let status: DiagnosticStatus
    public let details: String
    public let icon: String
    
    public init(title: String, category: String, status: DiagnosticStatus, details: String, icon: String) {
        self.title = title
        self.category = category
        self.status = status
        self.details = details
        self.icon = icon
    }
}

// MARK: - Ad & Monetization Models

public struct SponsorAd: Identifiable, Codable, Hashable {
    public let id: String
    public let title: String
    public let tagline: String
    public let description: String
    public let callToAction: String
    public let targetURLString: String
    public let iconSystemName: String
    public let badgeText: String
    public let rating: Double
    public let reviewCount: String
    public let category: String
    public let accentColorHex: String
    public let specs: [String]
    public let highlights: [String]
    public let priceNote: String
    public let imageURLString: String?
    
    public var targetURL: URL {
        URL(string: targetURLString) ?? URL(string: "https://apple.com")!
    }
    
    public init(
        id: String,
        title: String,
        tagline: String,
        description: String,
        callToAction: String,
        targetURLString: String,
        iconSystemName: String,
        badgeText: String,
        rating: Double,
        reviewCount: String = "4,500+ reviews",
        category: String,
        accentColorHex: String,
        specs: [String] = [],
        highlights: [String] = [],
        priceNote: String = "Prime Fast Delivery",
        imageURLString: String? = nil
    ) {
        self.id = id
        self.title = title
        self.tagline = tagline
        self.description = description
        self.callToAction = callToAction
        self.targetURLString = targetURLString
        self.iconSystemName = iconSystemName
        self.badgeText = badgeText
        self.rating = rating
        self.reviewCount = reviewCount
        self.category = category
        self.accentColorHex = accentColorHex
        self.specs = specs
        self.highlights = highlights
        self.priceNote = priceNote
        self.imageURLString = imageURLString
    }
}

// MARK: - Large & Old Files Models

public enum LargeFileSizeTier: String, CaseIterable, Identifiable, Sendable {
    case all = "All Sizes"
    case huge = "> 1 GB"
    case large = "500 MB – 1 GB"
    case medium = "100 MB – 500 MB"
    
    public var id: String { rawValue }
}

public enum LargeFileKind: String, CaseIterable, Identifiable, Sendable {
    case all = "All Kinds"
    case diskImages = "Disk Images & Installers"
    case archives = "Archives & ZIPs"
    case media = "Movies & Audio"
    case documents = "Documents & DBs"
    case other = "Other Files"
    
    public var id: String { rawValue }
    
    public var iconName: String {
        switch self {
        case .all: return "square.grid.2x2.fill"
        case .diskImages: return "opticaldisc.fill"
        case .archives: return "archivebox.fill"
        case .media: return "film.fill"
        case .documents: return "doc.text.fill"
        case .other: return "doc.fill"
        }
    }
}

public enum LargeFileAgeTier: String, CaseIterable, Identifiable, Sendable {
    case all = "Any Age"
    case olderThanYear = "> 1 Year Ago"
    case olderThanThreeMonths = "> 3 Months Ago"
    case olderThanMonth = "> 1 Month Ago"
    
    public var id: String { rawValue }
}

public struct LargeFileItem: Identifiable, Hashable, Sendable {
    public let id = UUID()
    public let url: URL
    public let name: String
    public let sizeBytes: Int64
    public let modificationDate: Date
    public let accessDate: Date?
    public let kind: LargeFileKind
    public var isSelected: Bool
    
    public var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: sizeBytes, countStyle: .file)
    }
    
    public var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: modificationDate)
    }
    
    public init(url: URL, name: String, sizeBytes: Int64, modificationDate: Date, accessDate: Date?, kind: LargeFileKind, isSelected: Bool = false) {
        self.url = url
        self.name = name
        self.sizeBytes = sizeBytes
        self.modificationDate = modificationDate
        self.accessDate = accessDate
        self.kind = kind
        self.isSelected = isSelected
    }
}

// MARK: - macOS System Maintenance Models

public enum MaintenanceTaskStatus: String, CaseIterable, Sendable {
    case idle = "Ready"
    case running = "Running"
    case success = "Completed"
    case failed = "Failed"
}

public struct MaintenanceTaskItem: Identifiable, Sendable {
    public let id: String
    public let title: String
    public let description: String
    public let iconName: String
    public let category: String
    public var status: MaintenanceTaskStatus
    public var outputLog: String
    public var lastRunDate: Date?
    
    public init(id: String, title: String, description: String, iconName: String, category: String, status: MaintenanceTaskStatus = .idle, outputLog: String = "", lastRunDate: Date? = nil) {
        self.id = id
        self.title = title
        self.description = description
        self.iconName = iconName
        self.category = category
        self.status = status
        self.outputLog = outputLog
        self.lastRunDate = lastRunDate
    }
}

// MARK: - Process Manager Models

public struct ProcessItem: Identifiable, Hashable, Sendable {
    public let id: Int32
    public let pid: Int32
    public let name: String
    public let cpuPercent: Double
    public let memoryBytes: Int64
    public let path: String
    public let isSystemProcess: Bool
    public let bundleID: String?
    
    public var memoryFormatted: String {
        ByteCountFormatter.string(fromByteCount: memoryBytes, countStyle: .memory)
    }
    
    public var isResourceHog: Bool {
        cpuPercent > 35.0 || memoryBytes > (1024 * 1024 * 1024 * 2)
    }
    
    public init(pid: Int32, name: String, cpuPercent: Double, memoryBytes: Int64, path: String, isSystemProcess: Bool, bundleID: String? = nil) {
        self.id = pid
        self.pid = pid
        self.name = name
        self.cpuPercent = cpuPercent
        self.memoryBytes = memoryBytes
        self.path = path
        self.isSystemProcess = isSystemProcess
        self.bundleID = bundleID
    }
}

