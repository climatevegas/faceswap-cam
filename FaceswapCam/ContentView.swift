import SwiftUI
import AVFoundation
import UniformTypeIdentifiers

// Desktop palette
private let BG = Color(red: 0.10, green: 0.10, blue: 0.18)      // #1a1a2e
private let PANEL = Color(red: 0.09, green: 0.13, blue: 0.24)   // #16213e
private let ACCENT = Color(red: 0.91, green: 0.27, blue: 0.38)  // #e94560
private let PREVIEW = Color(red: 0.06, green: 0.20, blue: 0.38) // #0f3460
private let GREEN = Color(red: 0.0, green: 0.72, blue: 0.58)    // #00b894
private let RED = Color(red: 0.84, green: 0.19, blue: 0.19)     // #d63031
private let MUTED = Color(red: 0.63, green: 0.63, blue: 0.69)   // #a0a0b0

struct ContentView: View {
    @StateObject private var cameraManager = CameraManager()
    @StateObject private var faceSwapProcessor = FaceSwapProcessor()
    @State private var isRunning = false
    @State private var showMediaPicker = false
    @State private var showAudioPicker = false
    @State private var selectedImage: UIImage?
    @State private var videoURL: URL?
    @State private var mediaName: String = ""
    @State private var isProcessingMedia = false
    @StateObject private var voiceChanger = VoiceChangerManager.shared
    @State private var blendAmount: Double = 0.85
    @State private var faceSizeFactor: Double = 1.3
    @State private var showPreview = true
    @State private var smoothing = true
    @State private var faceDetected = false
    @State private var fps: Int = 0
    @State private var isRecordingVoice = false
    @State private var voiceFileLabel: String = ""

    private var statusText: String { isRunning ? "Running" : "Stopped" }
    private var detectionText: String { faceDetected ? "Face detected" : "No face detected" }
    private var voiceStatusText: String {
        if !voiceChanger.isEnabled { return "Voice: Not listening" }
        if voiceChanger.isVoiceDetected { return "Voice detected - playing pre-recorded" }
        return "Voice: Listening"
    }

    var body: some View {
        NavigationView {
            ZStack {
                BG.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 14) {
                        Text("Real-time Face & Voice Replacement  |  Platform: iOS")
                            .font(.caption2)
                            .foregroundColor(MUTED)

                        previewPanel
                        faceSourcePanel
                        blendPanel
                        voicePanel
                        optionsPanel
                        instructionsPanel

                        Text("Press START to go live. Face and voice replacement run on-device.")
                            .font(.caption2)
                            .foregroundColor(MUTED)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                    .padding(.bottom, 8)
                }
            }
            .navigationTitle("FaceSwap Cam")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            // START / STOP pinned to the bottom, always visible
            .safeAreaInset(edge: .bottom) {
                HStack(spacing: 12) {
                    Button(action: { startCamera() }) {
                        HStack {
                            Image(systemName: "play.fill")
                            Text("START").fontWeight(.bold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(isRunning || selectedImage == nil ? Color.gray : GREEN)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                    }
                    .disabled(isRunning || selectedImage == nil)

                    Button(action: { stopCamera() }) {
                        HStack {
                            Image(systemName: "stop.fill")
                            Text("STOP").fontWeight(.bold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(!isRunning ? Color.gray : RED)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                    }
                    .disabled(!isRunning)
                }
                .padding(.horizontal)
                .padding(.vertical, 10)
                .background(PANEL)
            }
        }
        .sheet(isPresented: $showMediaPicker) {
            MediaPicker(image: $selectedImage, videoURL: $videoURL)
        }
        .fileImporter(
            isPresented: $showAudioPicker,
            allowedContentTypes: [.audio],
            allowsMultipleSelection: false
        ) { result in
            if case .success(let urls) = result, let url = urls.first {
                let needsScope = url.startAccessingSecurityScopedResource()
                defer { if needsScope { url.stopAccessingSecurityScopedResource() } }
                voiceChanger.preRecordedVoiceURL = url
                voiceFileLabel = url.lastPathComponent
            }
        }
        .onChange(of: selectedImage) { newImage in
            if let image = newImage {
                faceSwapProcessor.setFaceImage(image)
                mediaName = "Photo selected"
            }
        }
        .onChange(of: videoURL) { newURL in
            guard let url = newURL else { return }
            processVideo(url)
        }
    }

    // MARK: - Panels

    private var previewPanel: some View {
        panel(title: "Camera Preview") {
            ZStack {
                RoundedRectangle(cornerRadius: 12).fill(PREVIEW)

                if isRunning {
                    if showPreview {
                        CameraPreviewView(cameraManager: cameraManager)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    } else {
                        Text("Preview hidden").foregroundColor(MUTED)
                    }
                } else if let image = selectedImage {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    VStack {
                        Spacer()
                        Text("Press START to go live")
                            .font(.caption2)
                            .foregroundColor(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Color.black.opacity(0.6))
                            .cornerRadius(8)
                            .padding(8)
                    }
                } else {
                    VStack(spacing: 12) {
                        Image(systemName: "camera.fill")
                            .font(.system(size: 52))
                            .foregroundColor(MUTED)
                        Text("Camera Preview").foregroundColor(MUTED)
                    }
                }

                if isRunning {
                    VStack {
                        HStack {
                            Text(faceDetected ? "Face Detected" : "No Face")
                                .font(.caption2.bold())
                                .padding(.horizontal, 10).padding(.vertical, 5)
                                .background(faceDetected ? GREEN : RED)
                                .foregroundColor(.white)
                                .cornerRadius(8)
                            Spacer()
                            Text("\(fps) FPS")
                                .font(.caption2.bold())
                                .padding(.horizontal, 10).padding(.vertical, 5)
                                .background(Color.black.opacity(0.7))
                                .foregroundColor(.white)
                                .cornerRadius(8)
                        }
                        Spacer()
                    }
                    .padding(10)
                }
            }
            .aspectRatio(4 / 3, contentMode: .fit)
            .frame(maxHeight: 320)
            .clipShape(RoundedRectangle(cornerRadius: 12))

            HStack {
                Text(statusText).font(.caption).foregroundColor(ACCENT)
                Spacer()
                Text(detectionText).font(.caption).foregroundColor(MUTED)
                Text("\(fps) FPS").font(.caption)
                    .foregroundColor(PREVIEW)
                    .padding(.leading, 6)
            }
            .padding(.top, 6)

            HStack {
                Text(voiceStatusText).font(.caption2).foregroundColor(GREEN)
                Spacer()
            }
            .padding(.top, 2)
        }
    }

    private var faceSourcePanel: some View {
        panel(title: "Face Source (Photo or Video)") {
            HStack(spacing: 12) {
                if let image = selectedImage {
                    Image(uiImage: image)
                        .resizable().scaledToFill()
                        .frame(width: 56, height: 56)
                        .clipShape(Circle())
                } else {
                    Circle().fill(PREVIEW)
                        .frame(width: 56, height: 56)
                        .overlay(Image(systemName: "face.smiling").foregroundColor(MUTED))
                }

                if isProcessingMedia {
                    ProgressView().scaleEffect(0.8)
                    Text("Processing…").font(.subheadline).foregroundColor(GREEN)
                } else {
                    Text(mediaName.isEmpty ? "No photo or video selected" : mediaName)
                        .font(.subheadline)
                        .foregroundColor(mediaName.isEmpty ? MUTED : GREEN)
                }

                Spacer()

                Button("Browse") { showMediaPicker = true }
                    .buttonStyle(.borderedProminent)
                    .tint(ACCENT)
            }
        }
    }

    private var blendPanel: some View {
        panel(title: "Blend Settings") {
            Text("Blend Amount: \(Int(blendAmount * 100))%")
                .font(.caption).foregroundColor(.white)
            Slider(value: $blendAmount, in: 0...1)
                .tint(ACCENT)
                .onChange(of: blendAmount) { faceSwapProcessor.blendAmount = Float($0) }

            Text("Face Size Factor: \(String(format: "%.1f", faceSizeFactor))x")
                .font(.caption).foregroundColor(.white)
            Slider(value: $faceSizeFactor, in: 0.5...2.5)
                .tint(ACCENT)
                .onChange(of: faceSizeFactor) { faceSwapProcessor.faceSizeFactor = Float($0) }
        }
    }

    private var voicePanel: some View {
        panel(title: "Voice Changer") {
            Toggle("Enable Voice Replacement", isOn: $voiceChanger.isEnabled)
                .tint(ACCENT)
                .font(.subheadline)
                .foregroundColor(MUTED)

            if voiceChanger.isEnabled {
                HStack(spacing: 8) {
                    Image(systemName: "waveform")
                        .foregroundColor(voiceChanger.isVoiceDetected ? GREEN : MUTED)
                    Text(voiceFileLabel.isEmpty ? "No voice file selected" : "Voice file selected")
                        .font(.caption).foregroundColor(MUTED)
                    Spacer()
                }
                .padding(.top, 4)

                HStack(spacing: 8) {
                    Button("Select Voice") { showAudioPicker = true }
                        .buttonStyle(.borderedProminent).tint(ACCENT)
                        .frame(maxWidth: .infinity)

                    Button(isRecordingVoice ? "Recording…" : "Record Sample") {
                        isRecordingVoice = true
                        voiceChanger.recordVoiceSample { url in
                            isRecordingVoice = false
                            if let url = url {
                                voiceChanger.preRecordedVoiceURL = url
                                voiceFileLabel = url.lastPathComponent
                            }
                        }
                    }
                    .buttonStyle(.borderedProminent).tint(PREVIEW)
                    .frame(maxWidth: .infinity)
                    .disabled(isRecordingVoice)
                }
                .padding(.top, 2)
            }
        }
    }

    private var optionsPanel: some View {
        panel(title: "Options") {
            Toggle("Show Preview", isOn: $showPreview)
                .tint(ACCENT).font(.subheadline).foregroundColor(MUTED)
            Toggle("Temporal Smoothing", isOn: $smoothing)
                .tint(ACCENT).font(.subheadline).foregroundColor(MUTED)
                .onChange(of: smoothing) { faceSwapProcessor.smoothingEnabled = $0 }
        }
    }

    private var instructionsPanel: some View {
        panel(title: "How to Use (iOS)") {
            Text("1. Upload a photo or a video\n2. Enable the voice changer (optional)\n3. Click START\n4. Face replacement runs on the live preview")
                .font(.caption)
                .foregroundColor(MUTED)
                .lineSpacing(3)
        }
    }

    // MARK: - Reusable panel

    @ViewBuilder
    private func panel<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.caption.bold()).foregroundColor(MUTED)
            content()
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(PANEL)
        .cornerRadius(12)
    }

    // MARK: - Actions

    /// A video supplies a face frame (its look) and its audio (its tone).
    private func processVideo(_ url: URL) {
        isProcessingMedia = true
        mediaName = "Processing video..."

        MediaProcessor.extractFaceFrame(from: url) { frame in
            DispatchQueue.main.async {
                if let frame = frame {
                    self.selectedImage = frame
                    self.faceSwapProcessor.setFaceImage(frame)
                    self.mediaName = "Video frame captured"
                } else {
                    self.mediaName = "No face frame found"
                }
                self.isProcessingMedia = false
            }
        }

        MediaProcessor.extractAudio(from: url) { audioURL in
            DispatchQueue.main.async {
                if let audioURL = audioURL {
                    self.voiceChanger.preRecordedVoiceURL = audioURL
                    self.voiceFileLabel = audioURL.lastPathComponent
                }
            }
        }
    }

    private func startCamera() {
        guard selectedImage != nil else { return }
        isRunning = true
        cameraManager.startCamera(processor: faceSwapProcessor) { detected, currentFps in
            DispatchQueue.main.async {
                faceDetected = detected
                fps = currentFps
            }
        }
    }

    private func stopCamera() {
        isRunning = false
        faceDetected = false
        fps = 0
        cameraManager.stopCamera()
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
