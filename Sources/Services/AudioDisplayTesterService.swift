import Foundation
import SwiftUI
@preconcurrency import AVFoundation
import AppKit

@MainActor
public final class AudioDisplayTesterService: ObservableObject {
    // Audio Testing
    @Published public var isPlayingAudio: Bool = false
    @Published public var activeChannelPlaying: String = ""
    @Published public var micLevel: Float = 0.0
    @Published public var isListeningMic: Bool = false
    
    // Display Testing
    @Published public var displayWidth: Int = 0
    @Published public var displayHeight: Int = 0
    @Published public var displayScale: Double = 2.0
    @Published public var displayRefreshRate: Int = 60
    @Published public var colorDepth: String = "10-bit Color (P3)"
    
    private var audioEngine: AVAudioEngine?
    private var tonePlayer: AVAudioPlayerNode?
    private var micRecorder: AVAudioRecorder?
    private var micTimer: Timer?
    
    public init() {
        inspectDisplay()
    }
    
    deinit {
        // Resources cleaned up automatically
    }
    
    public func inspectDisplay() {
        if let screen = NSScreen.main {
            let frame = screen.frame
            self.displayWidth = Int(frame.width * screen.backingScaleFactor)
            self.displayHeight = Int(frame.height * screen.backingScaleFactor)
            self.displayScale = Double(screen.backingScaleFactor)
            
            // Try reading refresh rate via CoreGraphics mode
            if let mode = CGDisplayCopyDisplayMode(CGMainDisplayID()) {
                let rate = mode.refreshRate
                self.displayRefreshRate = rate > 0 ? Int(rate) : (screen.maximumExtendedDynamicRangeColorComponentValue > 1.0 ? 120 : 60)
            } else {
                self.displayRefreshRate = 60
            }
            
            self.colorDepth = screen.colorSpace?.localizedName ?? "Wide Color (Display P3)"
        }
    }
    
    // MARK: - Audio Stereo Test
    
    public func testStereoSpeakers() {
        guard !isPlayingAudio else {
            stopAudioTest()
            return
        }
        
        isPlayingAudio = true
        activeChannelPlaying = "Left Channel..."
        
        Task.detached(priority: .userInitiated) {
            // Play Left Channel Tone
            Self.playSineWave(frequency: 440.0, pan: -1.0, duration: 1.0)
            
            try? await Task.sleep(nanoseconds: 1_200_000_000)
            await MainActor.run {
                self.activeChannelPlaying = "Right Channel..."
            }
            
            // Play Right Channel Tone
            Self.playSineWave(frequency: 440.0, pan: 1.0, duration: 1.0)
            
            try? await Task.sleep(nanoseconds: 1_200_000_000)
            await MainActor.run {
                self.activeChannelPlaying = "Both Channels (Center)..."
            }
            
            // Play Both Channels
            Self.playSineWave(frequency: 523.25, pan: 0.0, duration: 1.2) // High C
            
            try? await Task.sleep(nanoseconds: 1_400_000_000)
            await MainActor.run {
                self.activeChannelPlaying = "Stereo Audio Test Completed"
                self.isPlayingAudio = false
            }
        }
    }
    
    public func stopAudioTest() {
        isPlayingAudio = false
        activeChannelPlaying = ""
    }
    
    private nonisolated static func playSineWave(frequency: Double, pan: Float, duration: Double) {
        let sampleRate: Double = 44100.0
        let frameCount = AVAudioFrameCount(sampleRate * duration)
        
        guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 2),
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else { return }
        
        buffer.frameLength = frameCount
        let leftChannel = buffer.floatChannelData?[0]
        let rightChannel = buffer.floatChannelData?[1]
        
        let leftVol: Float = pan <= 0 ? 1.0 : (1.0 - pan)
        let rightVol: Float = pan >= 0 ? 1.0 : (1.0 + pan)
        
        for i in 0..<Int(frameCount) {
            let sample = Float(sin(2.0 * .pi * frequency * Double(i) / sampleRate)) * 0.25
            leftChannel?[i] = sample * leftVol
            rightChannel?[i] = sample * rightVol
        }
        
        let engine = AVAudioEngine()
        let player = AVAudioPlayerNode()
        engine.attach(player)
        engine.connect(player, to: engine.mainMixerNode, format: format)
        
        do {
            try engine.start()
            player.play()
            player.scheduleBuffer(buffer, at: nil, options: .interrupts) {
                DispatchQueue.global().asyncAfter(deadline: .now() + 0.1) {
                    player.stop()
                    engine.stop()
                }
            }
        } catch {
            print("Audio Engine error: \(error)")
        }
    }
    
    // MARK: - Microphone VU Meter
    
    public func toggleMicMonitoring() {
        if isListeningMic {
            stopMicMonitoring()
        } else {
            startMicMonitoring()
        }
    }
    
    public func startMicMonitoring() {
        guard !isListeningMic else { return }
        let tempURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("mic_test.m4a")
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100.0,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.min.rawValue
        ]
        
        do {
            micRecorder = try AVAudioRecorder(url: tempURL, settings: settings)
            micRecorder?.isMeteringEnabled = true
            micRecorder?.record()
            isListeningMic = true
            
            micTimer = Timer.scheduledTimer(withTimeInterval: 0.08, repeats: true) { [weak self] _ in
                Task { @MainActor [weak self] in
                    guard let self = self, let recorder = self.micRecorder, recorder.isRecording else { return }
                    recorder.updateMeters()
                    let avgPower = recorder.averagePower(forChannel: 0) // dB (-160 to 0)
                    // Normalize dB (-60dB to 0dB -> 0.0 to 1.0)
                    let normalized = max(0.0, min(1.0, (avgPower + 60.0) / 60.0))
                    self.micLevel = normalized
                }
            }
        } catch {
            print("Failed to start mic monitoring: \(error)")
            isListeningMic = false
        }
    }
    
    public func stopMicMonitoring() {
        micTimer?.invalidate()
        micTimer = nil
        micRecorder?.stop()
        micRecorder = nil
        isListeningMic = false
        micLevel = 0.0
    }
}
