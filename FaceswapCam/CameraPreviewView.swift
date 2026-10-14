import SwiftUI
import AVFoundation

struct CameraPreviewView: UIViewRepresentable {
    @ObservedObject var cameraManager: CameraManager

    func makeUIView(context: Context) -> CameraPreviewUIView {
        let view = CameraPreviewUIView()
        view.backgroundColor = .black
        return view
    }

    func updateUIView(_ uiView: CameraPreviewUIView, context: Context) {
        uiView.updatePreviewLayer(with: cameraManager)
    }
}

class CameraPreviewUIView: UIView {
    private var previewLayer: AVCaptureVideoPreviewLayer?

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupLayer()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupLayer()
    }

    private func setupLayer() {
        layer.masksToBounds = true
    }

    func updatePreviewLayer(with cameraManager: CameraManager) {
        if previewLayer == nil {
            if let layer = cameraManager.getPreviewLayer() {
                layer.frame = bounds
                self.layer.addSublayer(layer)
                previewLayer = layer
            }
        } else {
            previewLayer?.frame = bounds
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        previewLayer?.frame = bounds
    }
}
