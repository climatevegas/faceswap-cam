import SwiftUI
import AVFoundation

struct ContentView: View {
    @StateObject private var cameraManager = CameraManager()
    @StateObject private var faceSwapProcessor = FaceSwapProcessor()
    @State private var isRunning = false
    @State private var showImagePicker = false
    @State private var selectedImage: UIImage?
    @State private var blendAmount: Double = 0.85
    @State private var faceSizeFactor: Double = 1.3
    @State private var faceDetected = false
    @State private var fps: Int = 0

    var body: some View {
        NavigationView {
            ZStack {
                Color(red: 0.1, green: 0.1, blue: 0.18)
                    .ignoresSafeArea()

                VStack(spacing: 16) {
                    // Camera Preview
                    ZStack {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color(red: 0.06, green: 0.2, blue: 0.38))

                        if isRunning {
                            CameraPreviewView(cameraManager: cameraManager)
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                        } else {
                            VStack(spacing: 12) {
                                Image(systemName: "camera.fill")
                                    .font(.system(size: 60))
                                    .foregroundColor(.gray)
                                Text("Camera Preview")
                                    .foregroundColor(.gray)
                                    .font(.headline)
                            }
                        }

                        // Status overlay
                        if isRunning {
                            VStack {
                                HStack {
                                    Text(faceDetected ? "Face Detected" : "No Face")
                                        .font(.caption.bold())
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(faceDetected ? Color.green : Color.red)
                                        .foregroundColor(.white)
                                        .cornerRadius(8)
                                    Spacer()
                                    Text("\(fps) FPS")
                                        .font(.caption.bold())
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(Color.black.opacity(0.7))
                                        .foregroundColor(.white)
                                        .cornerRadius(8)
                                }
                                Spacer()
                            }
                            .padding(12)
                        }
                    }
                    .frame(maxHeight: .infinity)

                    // Face Image Selector
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Face Image")
                            .font(.caption.bold())
                            .foregroundColor(.gray)

                        HStack {
                            if let image = selectedImage {
                                Image(uiImage: image)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 50, height: 50)
                                    .clipShape(Circle())
                            } else {
                                Circle()
                                    .fill(Color.gray.opacity(0.3))
                                    .frame(width: 50, height: 50)
                                    .overlay(
                                        Image(systemName: "face.smiling")
                                            .foregroundColor(.gray)
                                    )
                            }

                            Text(selectedImage != nil ? "Image Selected" : "No image selected")
                                .foregroundColor(selectedImage != nil ? .green : .gray)
                                .font(.subheadline)

                            Spacer()

                            Button("Browse") {
                                showImagePicker = true
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(Color(red: 0.91, green: 0.27, blue: 0.38))
                        }
                    }
                    .padding()
                    .background(Color(red: 0.09, green: 0.13, blue: 0.24))
                    .cornerRadius(12)

                    // Blend Settings
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Blend Settings")
                            .font(.caption.bold())
                            .foregroundColor(.gray)

                        HStack {
                            Text("Blend: \(Int(blendAmount * 100))%")
                                .font(.caption)
                                .foregroundColor(.white)
                            Slider(value: $blendAmount, in: 0...1)
                                .tint(Color(red: 0.91, green: 0.27, blue: 0.38))
                                .onChange(of: blendAmount) { newValue in
                                    faceSwapProcessor.blendAmount = Float(newValue)
                                }
                        }

                        HStack {
                            Text("Size: \(String(format: "%.1f", faceSizeFactor))x")
                                .font(.caption)
                                .foregroundColor(.white)
                            Slider(value: $faceSizeFactor, in: 0.5...2.5)
                                .tint(Color(red: 0.91, green: 0.27, blue: 0.38))
                                .onChange(of: faceSizeFactor) { newValue in
                                    faceSwapProcessor.faceSizeFactor = Float(newValue)
                                }
                        }
                    }
                    .padding()
                    .background(Color(red: 0.09, green: 0.13, blue: 0.24))
                    .cornerRadius(12)

                    // Control Buttons
                    HStack(spacing: 12) {
                        Button(action: {
                            startCamera()
                        }) {
                            HStack {
                                Image(systemName: "play.fill")
                                Text("START")
                                    .fontWeight(.bold)
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(isRunning ? Color.gray : Color.green)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                        }
                        .disabled(isRunning || selectedImage == nil)

                        Button(action: {
                            stopCamera()
                        }) {
                            HStack {
                                Image(systemName: "stop.fill")
                                Text("STOP")
                                    .fontWeight(.bold)
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(!isRunning ? Color.gray : Color.red)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                        }
                        .disabled(!isRunning)
                    }

                    // Instructions
                    VStack(alignment: .leading, spacing: 4) {
                        Text("How to Use")
                            .font(.caption.bold())
                            .foregroundColor(.gray)
                        Text("1. Upload a face image\n2. Click START\n3. Use in supported apps")
                            .font(.caption2)
                            .foregroundColor(.gray)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(red: 0.09, green: 0.13, blue: 0.24))
                    .cornerRadius(12)
                }
                .padding()
            }
            .navigationTitle("FaceSwap Cam")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
        .sheet(isPresented: $showImagePicker) {
            ImagePicker(image: $selectedImage)
        }
        .onChange(of: selectedImage) { newImage in
            if let image = newImage {
                faceSwapProcessor.setFaceImage(image)
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
