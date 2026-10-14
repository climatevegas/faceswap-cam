import AVFoundation
import UIKit
import CoreImage
import Vision

class CameraManager: NSObject, ObservableObject {
    private var captureSession: AVCaptureSession?
    private var videoOutput: AVCaptureVideoDataOutput?

    private var isRunning = false
    private var frameCount = 0
    private var fpsStartTime = CFAbsoluteTimeGetCurrent()

    private weak var processor: FaceSwapProcessor?
    private var onUpdate: ((Bool, Int) -> Void)?

    func startCamera(processor: FaceSwapProcessor, onUpdate: @escaping (Bool, Int) -> Void) {
        self.processor = processor
        self.onUpdate = onUpdate
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.setupCamera(processor: processor, onUpdate: onUpdate)
        }
    }

    private func setupCamera(processor: FaceSwapProcessor, onUpdate: @escaping (Bool, Int) -> Void) {
        captureSession = AVCaptureSession()
        guard let captureSession = captureSession else { return }

        captureSession.beginConfiguration()
        captureSession.sessionPreset = .vga640x480

        // Get front camera
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front) else {
            print("Front camera not available")
            return
        }

        do {
            let input = try AVCaptureDeviceInput(device: device)
            if captureSession.canAddInput(input) {
                captureSession.addInput(input)
            }

            videoOutput = AVCaptureVideoDataOutput()
            videoOutput?.setSampleBufferDelegate(self, queue: DispatchQueue(label: "videoQueue"))
            videoOutput?.alwaysDiscardsLateVideoFrames = true

            if let videoOutput = videoOutput, captureSession.canAddOutput(videoOutput) {
                captureSession.addOutput(videoOutput)
            }

            captureSession.commitConfiguration()
            captureSession.startRunning()
            isRunning = true

        } catch {
            print("Camera setup error: \(error)")
        }
    }

    func stopCamera() {
        isRunning = false
        captureSession?.stopRunning()
        captureSession = nil
        videoOutput = nil
        processor = nil
        onUpdate = nil
    }

    func getPreviewLayer() -> AVCaptureVideoPreviewLayer? {
        guard let captureSession = captureSession else { return nil }
        let layer = AVCaptureVideoPreviewLayer(session: captureSession)
        layer.videoGravity = .resizeAspectFill
        return layer
    }
}

extension CameraManager: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard isRunning else { return }

        frameCount += 1
        let elapsed = CFAbsoluteTimeGetCurrent() - fpsStartTime
        if elapsed >= 1.0 {
            let currentFps = Int(Double(frameCount) / elapsed)
            frameCount = 0
            fpsStartTime = CFAbsoluteTimeGetCurrent()

            DispatchQueue.main.async { [weak self] in
                self?.onUpdate?(false, currentFps)
            }
        }

        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let context = CIContext()

        // Detect faces
        let faceDetectionRequest = VNDetectFaceRectanglesRequest()
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])

        do {
            try handler.perform([faceDetectionRequest])
            let faces = faceDetectionRequest.results ?? []

            DispatchQueue.main.async { [weak self] in
                self?.onUpdate?(!faces.isEmpty, 0)
            }

            // Process face swap if face detected
            if let face = faces.first {
                processor?.processFrame(ciImage: ciImage, faceObservation: face, context: context)
            }
        } catch {
            print("Face detection error: \(error)")
        }
    }
}
