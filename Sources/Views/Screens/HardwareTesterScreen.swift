import SwiftUI

public struct HardwareTesterScreen: View {
    @ObservedObject var hardwareService: HardwareTesterService
    @ObservedObject var audioDisplayService: AudioDisplayTesterService
    @ObservedObject var adEngine: AdEngineService
    
    @State private var selectedTab: Int = 0 // 0: CPU, 1: RAM, 2: Disk, 3: Audio & Mic, 4: Display
    @State private var showDisplayTesterFullscreen: Bool = false
    @State private var displayTestColorIndex: Int = 0
    
    private let testColors: [Color] = [.red, .green, .blue, .white, .black, .yellow, .cyan]
    
    public init(
        hardwareService: HardwareTesterService,
        audioDisplayService: AudioDisplayTesterService,
        adEngine: AdEngineService
    ) {
        self.hardwareService = hardwareService
        self.audioDisplayService = audioDisplayService
        self.adEngine = adEngine
    }
    
    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header Bar
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Hardware & Diagnostics Suite")
                            .font(.system(size: 22, weight: .bold))
                        Text("Run intensive stress tests, memory integrity verifications, disk speeds, and audio/display diagnostics.")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                }
                .covaCardStyle()
                
                // Mode Picker
                Picker("", selection: $selectedTab) {
                    Text("CPU Benchmark").tag(0)
                    Text("RAM Integrity").tag(1)
                    Text("Disk Speed").tag(2)
                    Text("Audio & Mic").tag(3)
                    Text("Display Check").tag(4)
                }
                .pickerStyle(.segmented)
                
                // Tab Content
                switch selectedTab {
                case 0:
                    cpuTesterView
                case 1:
                    ramTesterView
                case 2:
                    diskTesterView
                case 3:
                    audioMicTesterView
                case 4:
                    displayTesterView
                default:
                    EmptyView()
                }
            }
            .padding(20)
        }
        .sheet(isPresented: $showDisplayTesterFullscreen) {
            fullscreenDisplayTesterView
        }
    }
    
    // MARK: - 1. CPU Tester View
    
    private var cpuTesterView: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("CPU Multi-Core Compute & Stress Test")
                        .font(.system(size: 16, weight: .bold))
                    Text("Executes heavy mathematical matrix workloads across all \(hardwareService.cpuCoreCount) CPU cores simultaneously.")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button(action: {
                    hardwareService.runCPUTest()
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "play.fill")
                        Text("Start CPU Test")
                    }
                    .font(.system(size: 13, weight: .bold))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(CovaTheme.primaryGradient)
                    .foregroundColor(.white)
                    .cornerRadius(6)
                }
                .buttonStyle(.plain)
            }
            
            Divider()
            
            if case .running(let progress, let message) = hardwareService.testState {
                VStack(spacing: 8) {
                    ProgressView(value: progress)
                    Text(message)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 10)
            }
            
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                StatRowView(title: "Active Cores", value: "\(hardwareService.cpuCoreCount) Cores", icon: "cpu")
                StatRowView(title: "Throughput", value: "\(hardwareService.cpuGFlops) GFLOPS", icon: "speedometer", iconColor: .teal)
                StatRowView(title: "Thermal State", value: hardwareService.cpuThermalStatus, icon: "thermometer.medium", iconColor: .orange)
            }
            
            if hardwareService.cpuScore > 0 {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Benchmark Score")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.secondary)
                        Text("\(Int(hardwareService.cpuScore)) Points")
                            .font(.system(size: 28, weight: .black, design: .rounded))
                            .foregroundColor(CovaTheme.primaryBlue)
                    }
                    Spacer()
                    Text("Multi-threaded FP64 execution passed with zero thread panics.")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                .padding(12)
                .background(Color.blue.opacity(0.1))
                .cornerRadius(8)
            }
        }
        .covaCardStyle()
    }
    
    // MARK: - 2. RAM Tester View
    
    private var ramTesterView: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("RAM Integrity & Bus Bandwidth Test")
                        .font(.system(size: 16, weight: .bold))
                    Text("Allocates a 256MB memory buffer and performs alternating bit-pattern tests to check for faulty memory cells.")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button(action: {
                    hardwareService.runRAMTest()
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "play.fill")
                        Text("Run Memory Test")
                    }
                    .font(.system(size: 13, weight: .bold))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(CovaTheme.purpleGradient)
                    .foregroundColor(.white)
                    .cornerRadius(6)
                }
                .buttonStyle(.plain)
            }
            
            Divider()
            
            if case .running(let progress, let message) = hardwareService.testState {
                VStack(spacing: 8) {
                    ProgressView(value: progress)
                    Text(message)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 10)
            }
            
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                StatRowView(title: "Write Speed", value: "\(Int(hardwareService.ramWriteThroughputMBs)) MB/s", icon: "arrow.down.doc.fill", iconColor: .purple)
                StatRowView(title: "Read Speed", value: "\(Int(hardwareService.ramReadThroughputMBs)) MB/s", icon: "arrow.up.doc.fill", iconColor: .blue)
                StatRowView(title: "Pattern Integrity", value: hardwareService.ramIntegrityPassed ? "Passed (No Errors)" : "Pending Test", icon: "checkmark.seal.fill", iconColor: hardwareService.ramIntegrityPassed ? .green : .secondary)
            }
        }
        .covaCardStyle()
    }
    
    // MARK: - 3. Disk Tester View
    
    private var diskTesterView: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Disk Read & Write Speed Benchmark")
                        .font(.system(size: 16, weight: .bold))
                    Text("Measures sequential disk throughput by generating and verifying temporary 128MB test blocks.")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button(action: {
                    hardwareService.runDiskTest()
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "play.fill")
                        Text("Start Disk Test")
                    }
                    .font(.system(size: 13, weight: .bold))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(CovaTheme.primaryGradient)
                    .foregroundColor(.white)
                    .cornerRadius(6)
                }
                .buttonStyle(.plain)
            }
            
            Divider()
            
            if case .running(let progress, let message) = hardwareService.testState {
                VStack(spacing: 8) {
                    ProgressView(value: progress)
                    Text(message)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 10)
            }
            
            HStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Sequential Write")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                    Text("\(Int(hardwareService.diskWriteSpeedMBs)) MB/s")
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                        .foregroundColor(CovaTheme.accentAmber)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(14)
                .background(Color.orange.opacity(0.1))
                .cornerRadius(10)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Sequential Read")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                    Text("\(Int(hardwareService.diskReadSpeedMBs)) MB/s")
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                        .foregroundColor(CovaTheme.accentGreen)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(14)
                .background(Color.green.opacity(0.1))
                .cornerRadius(10)
            }
        }
        .covaCardStyle()
    }
    
    // MARK: - 4. Audio & Microphone Tester
    
    private var audioMicTesterView: some View {
        VStack(alignment: .leading, spacing: 18) {
            // Speaker Section
            VStack(alignment: .leading, spacing: 12) {
                Text("Stereo Speaker Balance & Channel Separation")
                    .font(.system(size: 15, weight: .bold))
                Text("Plays independent left, right, and center test frequencies to verify speaker hardware balance.")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                
                HStack(spacing: 12) {
                    Button(action: {
                        audioDisplayService.testStereoSpeakers()
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: audioDisplayService.isPlayingAudio ? "stop.fill" : "speaker.wave.3.fill")
                            Text(audioDisplayService.isPlayingAudio ? "Stop Tone Test" : "Play Stereo Test Tones")
                        }
                        .font(.system(size: 12, weight: .semibold))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(CovaTheme.primaryGradient)
                        .foregroundColor(.white)
                        .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                    
                    if !audioDisplayService.activeChannelPlaying.isEmpty {
                        Text(audioDisplayService.activeChannelPlaying)
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(CovaTheme.accentGreen)
                    }
                }
            }
            .covaCardStyle()
            
            // Microphone Section
            VStack(alignment: .leading, spacing: 12) {
                Text("Microphone Input Level Meter")
                    .font(.system(size: 15, weight: .bold))
                Text("Speak into your Mac's microphone to inspect input responsiveness and decibel sensitivity.")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                
                HStack(spacing: 14) {
                    Button(action: {
                        audioDisplayService.toggleMicMonitoring()
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: audioDisplayService.isListeningMic ? "mic.fill" : "mic.slash")
                            Text(audioDisplayService.isListeningMic ? "Stop Mic Monitor" : "Start Live Mic Meter")
                        }
                        .font(.system(size: 12, weight: .semibold))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(audioDisplayService.isListeningMic ? Color.red.opacity(0.8) : Color.gray.opacity(0.2))
                        .foregroundColor(.white)
                        .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                    
                    // Live VU Meter Bar
                    VStack(alignment: .leading, spacing: 4) {
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color.gray.opacity(0.2))
                                    .frame(height: 12)
                                
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(audioDisplayService.micLevel > 0.8 ? Color.red : (audioDisplayService.micLevel > 0.5 ? Color.yellow : Color.green))
                                    .frame(width: geo.size.width * CGFloat(audioDisplayService.micLevel), height: 12)
                                    .animation(.easeOut(duration: 0.08), value: audioDisplayService.micLevel)
                            }
                        }
                        .frame(height: 12)
                    }
                }
            }
            .covaCardStyle()
        }
    }
    
    // MARK: - 5. Display Tester View
    
    private var displayTesterView: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Display Quality & Dead Pixel Inspector")
                        .font(.system(size: 16, weight: .bold))
                    Text("Verify panel color uniformity, inspect dead or stuck sub-pixels, and check display refresh rate.")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button(action: {
                    displayTestColorIndex = 0
                    showDisplayTesterFullscreen = true
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "rectangle.inset.filled")
                        Text("Launch Fullscreen Pixel Test")
                    }
                    .font(.system(size: 13, weight: .bold))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .background(CovaTheme.primaryGradient)
                    .foregroundColor(.white)
                    .cornerRadius(6)
                }
                .buttonStyle(.plain)
            }
            
            Divider()
            
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                StatRowView(title: "Native Resolution", value: "\(audioDisplayService.displayWidth) × \(audioDisplayService.displayHeight) px", icon: "display", iconColor: .blue)
                StatRowView(title: "Refresh Rate", value: "\(audioDisplayService.displayRefreshRate) Hz (ProMotion)", icon: "speedometer", iconColor: .green)
                StatRowView(title: "Scale Factor", value: "\(Int(audioDisplayService.displayScale))x Retina", icon: "eye.fill", iconColor: .teal)
                StatRowView(title: "Color Gamut", value: audioDisplayService.colorDepth, icon: "paintpalette.fill", iconColor: .purple)
            }
        }
        .covaCardStyle()
    }
    
    // MARK: - Fullscreen Display Tester Modal
    
    private var fullscreenDisplayTesterView: some View {
        ZStack {
            testColors[displayTestColorIndex]
                .ignoresSafeArea()
                .onTapGesture {
                    displayTestColorIndex = (displayTestColorIndex + 1) % testColors.count
                }
            
            VStack {
                HStack {
                    Text("Click anywhere to cycle colors (Red, Green, Blue, White, Black). Inspect display for stuck pixels.")
                        .font(.system(size: 12, weight: .medium))
                        .padding(8)
                        .background(Color.black.opacity(0.6))
                        .foregroundColor(.white)
                        .cornerRadius(6)
                    
                    Spacer()
                    
                    Button("Exit Test (ESC)") {
                        showDisplayTesterFullscreen = false
                    }
                    .font(.system(size: 12, weight: .bold))
                    .padding(8)
                    .background(Color.black.opacity(0.6))
                    .foregroundColor(.white)
                    .cornerRadius(6)
                    .buttonStyle(.plain)
                }
                .padding(20)
                Spacer()
            }
        }
        .frame(minWidth: 800, minHeight: 600)
    }
}
