import Foundation
import SwiftUI
import Combine

public enum HardwareTestType: String, CaseIterable, Identifiable {
    case cpu = "CPU Stress & Compute"
    case ram = "RAM Integrity & Bandwidth"
    case disk = "Disk Read & Write Speed"
    
    public var id: String { rawValue }
    
    public var iconName: String {
        switch self {
        case .cpu: return "cpu"
        case .ram: return "memorychip"
        case .disk: return "internaldrive.fill"
        }
    }
}

public enum HardwareTestState: Equatable {
    case idle
    case running(progress: Double, message: String)
    case completed(summary: String)
    case failed(error: String)
}

@MainActor
public final class HardwareTesterService: ObservableObject {
    @Published public var activeTest: HardwareTestType = .cpu
    @Published public var testState: HardwareTestState = .idle
    
    // Test Results
    @Published public var cpuScore: Double = 0.0
    @Published public var cpuGFlops: Double = 0.0
    @Published public var cpuCoreCount: Int = ProcessInfo.processInfo.activeProcessorCount
    @Published public var cpuThermalStatus: String = "Nominal"
    
    @Published public var ramWriteThroughputMBs: Double = 0.0
    @Published public var ramReadThroughputMBs: Double = 0.0
    @Published public var ramIntegrityPassed: Bool = false
    
    @Published public var diskWriteSpeedMBs: Double = 0.0
    @Published public var diskReadSpeedMBs: Double = 0.0
    
    public init() {}
    
    // MARK: - CPU Benchmark
    
    public func runCPUTest() {
        guard testState == .idle || testState != .running(progress: 0, message: "") else { return }
        testState = .running(progress: 0.1, message: "Starting multi-core stress workload...")
        
        Task.detached(priority: .userInitiated) {
            let cores = ProcessInfo.processInfo.activeProcessorCount
            let iterationsPerCore = 3_500_000
            let startTime = CFAbsoluteTimeGetCurrent()
            
            await withTaskGroup(of: Void.self) { group in
                for _ in 0..<cores {
                    group.addTask {
                        var x: Double = 1.0001
                        for i in 1...iterationsPerCore {
                            x = sin(x) * cos(Double(i)) + sqrt(Double(i))
                        }
                    }
                }
            }
            
            let elapsed = CFAbsoluteTimeGetCurrent() - startTime
            let totalOps = Double(cores * iterationsPerCore * 8) // ~8 floating point operations per loop
            let gflops = (totalOps / elapsed) / 1_000_000_000.0
            let score = round(gflops * 1250.0)
            
            let thermalState = ProcessInfo.processInfo.thermalState
            var thermalText = "Nominal"
            switch thermalState {
            case .nominal: thermalText = "Nominal (Cool)"
            case .fair: thermalText = "Fair (Slight heat)"
            case .serious: thermalText = "Serious (Thermal throttle warning)"
            case .critical: thermalText = "Critical (High throttle)"
            @unknown default: thermalText = "Normal"
            }
            
            await MainActor.run {
                self.cpuGFlops = Double(round(gflops * 100) / 100)
                self.cpuScore = score
                self.cpuThermalStatus = thermalText
                self.testState = .completed(summary: "CPU Score: \(Int(score)) | \(String(format: "%.2f", gflops)) GFLOPS across \(cores) Cores")
            }
        }
    }
    
    // MARK: - RAM Test
    
    public func runRAMTest() {
        guard testState == .idle || testState != .running(progress: 0, message: "") else { return }
        testState = .running(progress: 0.1, message: "Allocating memory test buffer (256MB)...")
        
        Task.detached(priority: .userInitiated) {
            let bufferSize = 256 * 1024 * 1024 // 256 MB buffer
            let byteCount = bufferSize
            
            await MainActor.run {
                self.testState = .running(progress: 0.3, message: "Writing bit patterns to RAM...")
            }
            
            guard let rawPointer = malloc(byteCount) else {
                await MainActor.run {
                    self.testState = .failed(error: "Out of memory: Unable to allocate buffer.")
                }
                return
            }
            defer { free(rawPointer) }
            
            let pointer = rawPointer.bindMemory(to: UInt64.self, capacity: byteCount / 8)
            let u64Count = byteCount / 8
            
            // Measure Write Speed
            let writeStart = CFAbsoluteTimeGetCurrent()
            let pattern1: UInt64 = 0xAA55AA55AA55AA55
            for i in 0..<u64Count {
                pointer[i] = pattern1
            }
            let writeElapsed = CFAbsoluteTimeGetCurrent() - writeStart
            let writeMBs = (Double(byteCount) / (1024.0 * 1024.0)) / max(0.001, writeElapsed)
            
            await MainActor.run {
                self.testState = .running(progress: 0.7, message: "Reading and verifying memory patterns...")
            }
            
            // Measure Read & Verify Speed
            let readStart = CFAbsoluteTimeGetCurrent()
            var passed = true
            for i in 0..<u64Count {
                if pointer[i] != pattern1 {
                    passed = false
                    break
                }
            }
            let readElapsed = CFAbsoluteTimeGetCurrent() - readStart
            let readMBs = (Double(byteCount) / (1024.0 * 1024.0)) / max(0.001, readElapsed)
            
            await MainActor.run {
                self.ramWriteThroughputMBs = Double(round(writeMBs))
                self.ramReadThroughputMBs = Double(round(readMBs))
                self.ramIntegrityPassed = passed
                self.testState = .completed(summary: "RAM Integrity: \(passed ? "Passed 100%" : "Errors Found") | Write: \(Int(writeMBs)) MB/s | Read: \(Int(readMBs)) MB/s")
            }
        }
    }
    
    // MARK: - Disk Benchmark
    
    public func runDiskTest() {
        guard testState == .idle || testState != .running(progress: 0, message: "") else { return }
        testState = .running(progress: 0.1, message: "Preparing test file (128MB)...")
        
        Task.detached(priority: .userInitiated) {
            let tempDir = URL(fileURLWithPath: NSTemporaryDirectory())
            let testFileURL = tempDir.appendingPathComponent("covamac_disk_benchmark.bin")
            defer {
                try? FileManager.default.removeItem(at: testFileURL)
            }
            
            let fileSize = 128 * 1024 * 1024 // 128 MB
            let chunkSize = 1024 * 1024 // 1MB
            let chunk = Data(repeating: 0x5A, count: chunkSize)
            
            await MainActor.run {
                self.testState = .running(progress: 0.3, message: "Benchmarking Sequential Write Speed...")
            }
            
            // 1. Write Benchmark
            let writeStart = CFAbsoluteTimeGetCurrent()
            FileManager.default.createFile(atPath: testFileURL.path, contents: nil, attributes: nil)
            guard let fileHandle = try? FileHandle(forWritingTo: testFileURL) else {
                await MainActor.run {
                    self.testState = .failed(error: "Could not create temporary benchmark file.")
                }
                return
            }
            
            for _ in 0..<(fileSize / chunkSize) {
                fileHandle.write(chunk)
            }
            try? fileHandle.synchronize()
            try? fileHandle.close()
            let writeElapsed = CFAbsoluteTimeGetCurrent() - writeStart
            let writeMBs = 128.0 / max(0.001, writeElapsed)
            
            await MainActor.run {
                self.testState = .running(progress: 0.7, message: "Benchmarking Sequential Read Speed...")
            }
            
            // 2. Read Benchmark
            guard let readHandle = try? FileHandle(forReadingFrom: testFileURL) else {
                await MainActor.run {
                    self.testState = .failed(error: "Could not open benchmark file for reading.")
                }
                return
            }
            
            let readStart = CFAbsoluteTimeGetCurrent()
            while autoreleasepool(invoking: {
                let data = readHandle.readData(ofLength: chunkSize)
                return !data.isEmpty
            }) {}
            try? readHandle.close()
            let readElapsed = CFAbsoluteTimeGetCurrent() - readStart
            let readMBs = 128.0 / max(0.001, readElapsed)
            
            await MainActor.run {
                self.diskWriteSpeedMBs = Double(round(writeMBs))
                self.diskReadSpeedMBs = Double(round(readMBs))
                self.testState = .completed(summary: "Disk Write: \(Int(writeMBs)) MB/s | Disk Read: \(Int(readMBs)) MB/s")
            }
        }
    }
}
