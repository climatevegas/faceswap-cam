import UIKit
import CoreImage
import Vision

class FaceSwapProcessor: ObservableObject {
    private var faceImage: UIImage?
    private var faceImageCIImage: CIImage?

    var blendAmount: Float = 0.85
    var faceSizeFactor: Float = 1.3

    private var smoothFaceRect: CGRect?
    private let smoothingAlpha: Float = 0.3

    // Published property to hold the processed frame for display
    @Published var processedImage: CIImage?

    func setFaceImage(_ image: UIImage) {
        faceImage = image
        faceImageCIImage = CIImage(image: image)
    }

    func processFrame(ciImage: CIImage, faceObservation: VNFaceObservation, context: CIContext) {
        guard let faceImage = faceImageCIImage else { return }

        let imageSize = ciImage.extent.size
        let faceRect = VNImageRectForNormalizedRect(faceObservation.boundingBox, Int(imageSize.width), Int(imageSize.height))

        // Apply temporal smoothing
        let smoothedRect = smoothFaceRect(faceRect)
        smoothFaceRect = smoothedRect

        // Scale face
        let newWidth = CGFloat(Float(smoothedRect.width) * faceSizeFactor)
        let newHeight = CGFloat(Float(smoothedRect.height) * faceSizeFactor)
        let cx = smoothedRect.midX
        let cy = smoothedRect.midY

        let targetRect = CGRect(
            x: cx - newWidth / 2,
            y: cy - newHeight / 2,
            width: newWidth,
            height: newHeight
        )

        // Resize face image
        let scaleX = newWidth / faceImage.extent.width
        let scaleY = newHeight / faceImage.extent.height
        let scaledFace = faceImage.transformed(by: CGAffineTransform(scaleX: scaleX, y: scaleY))

        // Create mask
        let maskImage = CIImage(color: CIColor(red: 1, green: 1, blue: 1, alpha: 1))
            .cropped(to: targetRect)

        // Blend using Core Image
        let blendFilter = CIFilter(name: "CIBlendWithMask")
        blendFilter?.setValue(scaledFace, forKey: kCIInputImageKey)
        blendFilter?.setValue(ciImage, forKey: kCIInputBackgroundImageKey)
        blendFilter?.setValue(maskImage, forKey: kCIInputMaskImageKey)

        if let output = blendFilter?.outputImage {
            // Apply blend amount
            if blendAmount < 1.0 {
                let alphaFilter = CIFilter(name: "CIColorMatrix")
                alphaFilter?.setValue(output, forKey: kCIInputImageKey)
                alphaFilter?.setValue(CIVector(x: 0, y: 0, z: 0, w: CGFloat(blendAmount)), forKey: "inputAVector")

                if let blended = alphaFilter?.outputImage {
                    processedImage = blended
                }
            } else {
                processedImage = output
            }
        }
    }

    private func smoothFaceRect(_ rect: CGRect) -> CGRect {
        guard let current = smoothFaceRect else { return rect }

        let sx = CGFloat(smoothingAlpha * Float(rect.minX) + (1 - smoothingAlpha) * Float(current.minX))
        let sy = CGFloat(smoothingAlpha * Float(rect.minY) + (1 - smoothingAlpha) * Float(current.minY))
        let sw = CGFloat(smoothingAlpha * Float(rect.width) + (1 - smoothingAlpha) * Float(current.width))
        let sh = CGFloat(smoothingAlpha * Float(rect.height) + (1 - smoothingAlpha) * Float(current.height))

        return CGRect(x: sx, y: sy, width: sw, height: sh)
    }
}
