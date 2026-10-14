import SwiftUI
import AVFoundation
import Accelerate
#if canImport(GoogleWebRTC)
import GoogleWebRTC
#endif

/**
 * VoiceChangerManager
 *
 * Detects when the user is speaking (Voice Activity Detection) and replaces
 * the real microphone audio with a pre-recorded voice sample.
 *
 * Flow:
 *  1. AVAudioEngine installs a tap on the input node's output bus
 *  2. The tap buffers receive real mic PCM samples
 *  3. RMS energy is computed to detect speech (VAD)
 *  4. When speech is detected, the pre-recorded voice file is played
 *     instead of the real audio via AVAudioPlayerNode
 *  5. The output connects to the main mixer for call routing
 */
class VoiceChangerManager: ObservableObject {

    static let shared = VoiceChangerManager()

    // MARK: - Published properties
    @Published var isEnabled: Bool = false {
        didSet {
            if isEnabled {
                startListening()
            } else {
                stopListening()
            }
        }
    }

    @Published var isVoiceDetected: Bool = false
    @Published var preRecordedVoiceURL: URL? {
        didSet {
            loadPreRecordedVoice()
        }
    }

    // MARK: - Private properties
    private let engine = AVAudioEngine()
    private var playerNode = AVAudioPlayerNode()
    private var preRecordedFile: AVAudioFile?
    private var preRecordedBuffer: AVAudioPCMBuffer?

    private let sampleRate: Double = 16000
    private let vadThreshold: Float = 1000  // RMS threshold (0..32767 scale)

    private var speechStartTime: Date?
    private var isSpeaking = false

    // MARK: - Initialization
    private init() {
        engine.attach(playerNode)
        engine.connect(playerNode, to: engine.mainMixerNode, format: nil)
    }

    // MARK: - Configure Pre-recorded Voice

    /// Load the pre-recorded voice file (.wav, .mp3, .m4a, .caf)
    private func loadPreRecordedVoice() {
        guard let url = preRecordedVoiceURL else {
            preRecordedBuffer = nil
            return
        }

        do {
            preRecordedFile = try AVAudioFile(forReading: url)
            let format = preRecordedFile!.processingFormat
            let frameCount = UInt32(preRecordedFile!.length)

            preRecordedBuffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount)
            try preRecordedFile!.read(into: preRecordedBuffer!)
            print("VoiceChanger: Pre-recorded voice loaded (\(frameCount) frames)")
        } catch {
            print("VoiceChanger: Failed to load pre-recorded voice: \(error)")
            preRecordedBuffer = nil
        }
    }

    /// Record a new voice sample (iOS requires user permission for mic)
    func recordVoiceSample(duration: TimeInterval = 5.0) {
        // Implementation uses AVCaptureSession or AVAudioRecorder
        // Left as extension point for full recording workflow
        print("VoiceChanger: Record voice sample - implement with AVAudioRecorder")
    }

    // MARK: - Start / Stop Listening

    func startListening() {
        guard !engine.isRunning else { return }

        let inputNode = engine.inputNode
        let inputFormat = inputNode.outputFormat(forBus: 0)

        // Install tap on input node
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: inputFormat) { [weak self] buffer, time in
            self?.processAudioBuffer(buffer)
        }

        // Prepare and start engine
        engine.prepare()
        do {
            try engine.start()
            print("VoiceChanger: Engine started. Listening for voice...")
        } catch {
            print("VoiceChanger: Failed to start engine: \(error)")
        }
    }

    func stopListening() {
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        playerNode.stop()
        isVoiceDetected = false
        print("VoiceChanger: Stopped listening.")
    }

    // MARK: - Voice Activity Detection & Replacement

    private func processAudioBuffer(_ buffer: AVAudioPCMBuffer) {
        guard isEnabled else { return }

        let rms = calculateRMS(buffer)
        let now = Date()

        if rms > vadThreshold {
            // Voice detected
            if !isSpeaking {
                isSpeaking = true
                speechStartTime = now
                DispatchQueue.main.async {
                    self.isVoiceDetected = true
                }
            }

            // Check minimum speech duration
            if let start = speechStartTime,
               now.timeIntervalSince(start) >= 0.2 {  // 200ms

                // Replace real voice with pre-recorded voice
                playPreRecordedVoice()

                // Reset to avoid repeated triggers
                speechStartTime = now
            }
        } else {
            // Silence
            if isSpeaking {
                isSpeaking = false
                DispatchQueue.main.async {
                    self.isVoiceDetected = false
                }
            }
        }
    }

    private func calculateRMS(_ buffer: AVAudioPCMBuffer) -> Float {
        guard let channelData = buffer.floatChannelData else { return 0 }

        let channelDataValue = channelData.pointee
        let frameLength = Int(buffer.frameLength)

        var sum: Float = 0
        vDSP_measqv(channelDataValue, 1, &sum, vDSP_Length(frameLength))
        let mean = sum / Float(frameLength)
        return sqrtf(mean) * 32767.0  // Scale to 0..32767 for consistency with Android
    }

    // MARK: - Pre-recorded Voice Playback

    private func playPreRecordedVoice() {
        guard let buffer = preRecordedBuffer else {
            print("VoiceChanger: No pre-recorded buffer set")
            return
        }

        if playerNode.isPlaying { return }

        // Re-create buffer for replay
        playerNode.scheduleBuffer(buffer, at: nil, options: .interrupts, completionHandler: nil)
        playerNode.play()
        print("VoiceChanger: Playing pre-recorded voice")
    }

    // MARK: - WebRTC Audio Integration

    /// Returns the audio track for WebRTC calls
    #if canImport(GoogleWebRTC)
    func createWebRTCAudioTrack(_ factory: RTCPeerConnectionFactory) -> RTCAudioTrack? {
        let audioSource = factory.audioSource(with: RTCMediaConstraints())
        let audioTrack = factory.audioTrack(with: audioSource, trackId: "voice0")
        return audioTrack
    }
    #endif

    // MARK: - Cleanup

    func release() {
        stopListening()
        playerNode = AVAudioPlayerNode()
    }
}
