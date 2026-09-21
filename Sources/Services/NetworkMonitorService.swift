import Foundation
import SwiftUI
import Combine

public struct PingResult: Identifiable, Hashable, Sendable {
    public let id = UUID()
    public let host: String
    public let label: String
    public let latencyMs: Double
    public let packetLossPercent: Double
    public let status: String
    public let timestamp: Date
    
    public init(host: String, label: String, latencyMs: Double, packetLossPercent: Double, status: String) {
        self.host = host
        self.label = label
        self.latencyMs = latencyMs
        self.packetLossPercent = packetLossPercent
        self.status = status
        self.timestamp = Date()
    }
}

@MainActor
public final class NetworkMonitorService: ObservableObject {
    @Published public var interfaceName: String = "en0"
    @Published public var interfaceType: String = "Wi-Fi"
    @Published public var localIPAddress: String = "Detecting..."
    @Published public var wifiSSID: String = "Connected"
    @Published public var routerGateway: String = "192.168.1.1"
    @Published public var dnsServer: String = "1.1.1.1"
    @Published public var isOnline: Bool = true
    
    @Published public var pingTargets: [PingResult] = []
    @Published public var isTestingPing: Bool = false
    @Published public var averageLatencyMs: Double = 0.0
    @Published public var networkGrade: String = "A+"
    
    public init() {
        refreshNetworkInfo()
        runPingDiagnostics()
    }
    
    public func refreshNetworkInfo() {
        Task.detached(priority: .userInitiated) {
            let ip = Self.getLocalIP()
            let (iface, ifaceType) = Self.getActiveInterface()
            let ssid = Self.getWiFiSSID()
            let router = Self.getRouterIP()
            let dns = Self.getDNSServers()
            
            await MainActor.run {
                self.localIPAddress = ip
                self.interfaceName = iface
                self.interfaceType = ifaceType
                self.wifiSSID = ssid
                self.routerGateway = router
                self.dnsServer = dns
            }
        }
    }
    
    public func runPingDiagnostics() {
        guard !isTestingPing else { return }
        isTestingPing = true
        
        let targets = [
            ("1.1.1.1", "Cloudflare Anycast DNS"),
            ("8.8.8.8", "Google Public DNS"),
            ("apple.com", "Apple Edge CDN")
        ]
        
        Task.detached(priority: .userInitiated) {
            var results: [PingResult] = []
            
            for (host, label) in targets {
                let (latency, loss) = Self.pingHost(host: host)
                let status: String
                if loss >= 100.0 {
                    status = "Timeout"
                } else if latency < 25.0 {
                    status = "Ultra Fast"
                } else if latency < 60.0 {
                    status = "Optimal"
                } else {
                    status = "Elevated"
                }
                results.append(PingResult(host: host, label: label, latencyMs: latency, packetLossPercent: loss, status: status))
            }
            
            let valid = results.filter { $0.packetLossPercent < 100.0 }
            let avg = valid.isEmpty ? 0.0 : valid.reduce(0.0) { $0 + $1.latencyMs } / Double(valid.count)
            
            let grade: String
            if avg == 0 {
                grade = "Offline"
            } else if avg < 20.0 {
                grade = "A+ (Ultra-Fast)"
            } else if avg < 45.0 {
                grade = "A (Optimal)"
            } else if avg < 80.0 {
                grade = "B (Good)"
            } else {
                grade = "C (High Latency)"
            }
            
            await MainActor.run {
                self.pingTargets = results
                self.averageLatencyMs = round(avg * 10) / 10
                self.networkGrade = grade
                self.isOnline = !valid.isEmpty
                self.isTestingPing = false
            }
        }
    }
    
    // MARK: - Native Helpers
    
    private nonisolated static func getLocalIP() -> String {
        var address = "127.0.0.1"
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0, let firstAddr = ifaddr else { return address }
        defer { freeifaddrs(ifaddr) }
        
        for ptr in sequence(first: firstAddr, next: { $0.pointee.ifa_next }) {
            let flags = Int32(ptr.pointee.ifa_flags)
            let addr = ptr.pointee.ifa_addr.pointee
            if (flags & (IFF_UP|IFF_RUNNING|IFF_LOOPBACK)) == (IFF_UP|IFF_RUNNING) {
                if addr.sa_family == UInt8(AF_INET) {
                    var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                    if getnameinfo(ptr.pointee.ifa_addr, socklen_t(addr.sa_len), &hostname, socklen_t(hostname.count), nil, 0, NI_NUMERICHOST) == 0 {
                        address = hostname.withUnsafeBufferPointer { p in
                            p.baseAddress != nil ? String(cString: p.baseAddress!) : "127.0.0.1"
                        }
                        break
                    }
                }
            }
        }
        return address
    }
    
    private nonisolated static func getActiveInterface() -> (String, String) {
        let pipe = Pipe()
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/sbin/route")
        proc.arguments = ["get", "default"]
        proc.standardOutput = pipe
        try? proc.run()
        proc.waitUntilExit()
        
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        if let output = String(data: data, encoding: .utf8) {
            for line in output.components(separatedBy: "\n") {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                if trimmed.hasPrefix("interface:") {
                    let parts = trimmed.components(separatedBy: ":")
                    if parts.count > 1 {
                        let iface = parts[1].trimmingCharacters(in: .whitespaces)
                        let type = iface.contains("en0") ? "Wi-Fi (en0)" : "Ethernet / Thunderbolt (\(iface))"
                        return (iface, type)
                    }
                }
            }
        }
        return ("en0", "Wi-Fi")
    }
    
    private nonisolated static func getWiFiSSID() -> String {
        let pipe = Pipe()
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/sbin/networksetup")
        proc.arguments = ["-getairportnetwork", "en0"]
        proc.standardOutput = pipe
        try? proc.run()
        proc.waitUntilExit()
        
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        if let output = String(data: data, encoding: .utf8) {
            if output.contains("Current Wi-Fi Network:") {
                let parts = output.components(separatedBy: ":")
                if parts.count > 1 {
                    let ssid = parts[1].trimmingCharacters(in: .whitespacesAndNewlines)
                    return ssid.isEmpty ? "Connected (Hidden SSID)" : ssid
                }
            }
        }
        return "Connected Network"
    }
    
    private nonisolated static func getRouterIP() -> String {
        let pipe = Pipe()
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/sbin/route")
        proc.arguments = ["-n", "get", "default"]
        proc.standardOutput = pipe
        try? proc.run()
        proc.waitUntilExit()
        
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        if let output = String(data: data, encoding: .utf8) {
            for line in output.components(separatedBy: "\n") {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                if trimmed.hasPrefix("gateway:") {
                    let parts = trimmed.components(separatedBy: ":")
                    if parts.count > 1 {
                        return parts[1].trimmingCharacters(in: .whitespaces)
                    }
                }
            }
        }
        return "192.168.1.1"
    }
    
    private nonisolated static func getDNSServers() -> String {
        let pipe = Pipe()
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/sbin/scutil")
        proc.arguments = ["--dns"]
        proc.standardOutput = pipe
        try? proc.run()
        proc.waitUntilExit()
        
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        if let output = String(data: data, encoding: .utf8) {
            for line in output.components(separatedBy: "\n") {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                if trimmed.hasPrefix("nameserver[0]") {
                    let parts = trimmed.components(separatedBy: ":")
                    if parts.count > 1 {
                        return parts[1].trimmingCharacters(in: .whitespaces)
                    }
                }
            }
        }
        return "1.1.1.1 (Cloudflare)"
    }
    
    private nonisolated static func pingHost(host: String) -> (latency: Double, packetLoss: Double) {
        let pipe = Pipe()
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/sbin/ping")
        proc.arguments = ["-c", "2", "-t", "2", host]
        proc.standardOutput = pipe
        try? proc.run()
        proc.waitUntilExit()
        
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let output = String(data: data, encoding: .utf8) else {
            return (0.0, 100.0)
        }
        
        var packetLoss = 0.0
        var avgLatency = 0.0
        
        // Parse packet loss
        if let lossRange = output.range(of: "% packet loss") {
            let sub = output[..<lossRange.lowerBound]
            if let lastSpace = sub.lastIndex(of: " ") {
                let numStr = sub[lastSpace...].trimmingCharacters(in: .whitespaces)
                packetLoss = Double(numStr) ?? 0.0
            }
        }
        
        // Parse avg latency: "round-trip min/avg/max/stddev = 12.34/15.67/..."
        if let avgRange = output.range(of: "round-trip min/avg/max/stddev = ") {
            let sub = output[avgRange.upperBound...]
            let parts = sub.components(separatedBy: "/")
            if parts.count > 1 {
                avgLatency = Double(parts[1]) ?? 0.0
            }
        }
        
        return (avgLatency, packetLoss)
    }
}
