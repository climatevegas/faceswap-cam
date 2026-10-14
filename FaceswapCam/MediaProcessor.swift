import UIKit
import AVFoundation
import Vision

/**
 * MediaProcessor
 *
 * Turns a user-picked VIDEO into the two things the app needs:
 *   1. a still frame containing the largest face  -> the replacement face
 *   2. the video's audio track                    -> the replacement voice
 *
 * Photos are handled directly by the existing image path.
 */
class MediaProcessor {

    /// Scan several timestamps and return the frame with the largest face.
    static func extractFaceFrame(from url: URL, completion: @escaping (UIImage?) -> Void) {
        let asset = AVAsset(url: url)
        let duration = CMTimeGetSeconds(asset.duration)

        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.requestedTimeToleranceBefore = .zero
        generator.requestedTimeToleranceAfter = .zero

        let timestamps: [Double]
        if duration > 1 {
            timestamps = [0.5, duration * 0.25, duration * 0.5,
                          duration * 0.75, max(0, duration - 0.2)]
        } else {
            timestamps = [min(0.5, max(0, duration / 2))]
        }

        var bestImage: UIImage? = nil
        var bestScore: CGFloat = 0
        let group = DispatchGroup()

        for t in timestamps {
            group.enter()
            let cmTime = CMTime(seconds: t, preferredTimescale: 600)
            generator.generateCGImagesAsynchronously(forTimes: [NSValue(time: cmTime)]) { _, image, _, _, _ in
                if let cgImage = image {
                    let uiImage = UIImage(cgImage: cgImage)
                    let score = faceScore(in: uiImage)
                    if score > bestScore {
                        bestScore = score
                        bestImage = uiImage
                    }
                }
                group.leave()
            }
        }

        group.notify(queue: .main) {
            completion(bestImage)
        }
    }

    /// Export just the audio track to a standalone .m4a file.
    static func extractAudio(from url: URL, completion: @escaping (URL?) -> Void) {
        let asset = AVAsset(url: url)
        guard let audioTrack = asset.tracks(withMediaType: .audio).first else {
            completion(nil)
            return
        }

        let composition = AVMutableComposition()
        guard let compTrack = composition.addMutableTrack(
            withMediaType: .audio,
            preferredTrackID: kCMPersistentTrackID_Invalid
        ) else {
            completion(nil)
            return
        }

        do {
            try compTrack.insertTimeRange(
                CMTimeRange(start: .zero, duration: asset.duration),
                of: audioTrack,
                at: .zero
            )
        } catch {
            print("MediaProcessor: audio composition failed: \(error)")
            completion(nil)
            return
        }

        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("voice_\(UUID().uuidString).m4a")

        guard let exportSession = AVAssetExportSession(
            asset: composition,
            presetName: AVAssetExportPresetAppleM4A
        ) else {
            completion(nil)
            return
        }

        exportSession.outputURL = outputURL
        exportSession.outputFileType = .m4a
        exportSession.exportAsynchronously {
            DispatchQueue.main.async {
                if exportSession.status == .completed {
                    completion(outputURL)
                } else {
                    print("MediaProcessor: audio export failed: \(exportSession.error?.localizedDescription ?? "unknown")")
                    completion(nil)
                }
            }
        }
    }

    /// Fraction of the image covered by the largest detected face (0..1).
    private static func faceScore(in image: UIImage) -> CGFloat {
        guard let cgImage = image.cgImage else { return 0 }
        var best: CGFloat = 0
        let request = VNDetectFaceRectanglesRequest { request, _ in
            guard let observations = request.results as? [VNFaceObservation] else { return }
            for obs in observations {
                let fraction = obs.boundingBox.width * obs.boundingBox.height
                if fraction > best { best = fraction }
            }
        }
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        try? handler.perform([request])
        return best
    }
}
