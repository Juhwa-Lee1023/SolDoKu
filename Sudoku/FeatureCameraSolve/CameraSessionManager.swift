import AVFoundation
import QuartzCore
import SwiftUI
import UIKit

struct CameraBoardObservation {
    let corners: [CGPoint]
    let boardAreaRatio: CGFloat
    let qualityScore: Double
    let gridConfidence: Double
    let frameSize: CGSize
    let isStable: Bool

    var recognitionSignature: Int {
        let referenceSide = max(max(frameSize.width, frameSize.height), 1)
        var hasher = Hasher()
        for corner in corners {
            hasher.combine(Int((corner.x / referenceSide * 100).rounded()))
            hasher.combine(Int((corner.y / referenceSide * 100).rounded()))
        }
        hasher.combine(Int((boardAreaRatio * 100).rounded()))
        hasher.combine(Int((qualityScore * 100).rounded()))
        return hasher.finalize()
    }
}

private struct CameraBoardSnapshot {
    let corners: [CGPoint]
    let boardAreaRatio: CGFloat
    let qualityScore: Double
    let gridConfidence: Double
    let frameSize: CGSize
}

private enum CameraRecognitionGate {
    static func observation(
        from snapshots: [CameraBoardSnapshot],
        latest: CameraBoardSnapshot
    ) -> CameraBoardObservation {
        let recent = Array(snapshots.suffix(SudokuOCRConfig.Preview.stableFrameCount))
        let smoothedCorners = smoothedCorners(from: recent)
        let stable = isStable(recent, referenceSide: max(latest.frameSize.width, latest.frameSize.height))

        return CameraBoardObservation(
            corners: smoothedCorners,
            boardAreaRatio: latest.boardAreaRatio,
            qualityScore: latest.qualityScore,
            gridConfidence: latest.gridConfidence,
            frameSize: latest.frameSize,
            isStable: stable
        )
    }

    static func isReadyForLiveOCR(_ observation: CameraBoardObservation?) -> Bool {
        guard let observation else { return false }
        return observation.isStable
            && observation.boardAreaRatio >= SudokuOCRConfig.Preview.minimumPreviewBoardAreaRatio
            && observation.qualityScore >= SudokuOCRConfig.Preview.minimumPreviewQualityScore
    }

    private static func smoothedCorners(from snapshots: [CameraBoardSnapshot]) -> [CGPoint] {
        guard let first = snapshots.first, first.corners.count == 4 else { return [] }
        var smoothed: [CGPoint] = []
        smoothed.reserveCapacity(4)

        for index in 0..<4 {
            let xs = snapshots.compactMap { snapshot -> CGFloat? in
                guard snapshot.corners.count > index else { return nil }
                return snapshot.corners[index].x
            }
            let ys = snapshots.compactMap { snapshot -> CGFloat? in
                guard snapshot.corners.count > index else { return nil }
                return snapshot.corners[index].y
            }

            guard !xs.isEmpty, !ys.isEmpty else { continue }
            smoothed.append(
                CGPoint(
                    x: xs.reduce(CGFloat(0), +) / CGFloat(xs.count),
                    y: ys.reduce(CGFloat(0), +) / CGFloat(ys.count)
                )
            )
        }

        return smoothed
    }

    private static func isStable(_ snapshots: [CameraBoardSnapshot], referenceSide: CGFloat) -> Bool {
        guard snapshots.count >= SudokuOCRConfig.Preview.stableFrameCount else { return false }
        guard referenceSide > 0 else { return false }

        let maximumAllowedDrift = referenceSide * SudokuOCRConfig.Preview.maximumCornerDriftRatio
        for pair in zip(snapshots, snapshots.dropFirst()) {
            guard pair.0.corners.count == 4, pair.1.corners.count == 4 else { return false }

            let averageDrift = zip(pair.0.corners, pair.1.corners)
                .map { hypot($0.x - $1.x, $0.y - $1.y) }
                .reduce(CGFloat(0), +) / 4.0

            if averageDrift > maximumAllowedDrift {
                return false
            }

            let areaDelta = abs(pair.0.boardAreaRatio - pair.1.boardAreaRatio)
            if areaDelta > SudokuOCRConfig.Preview.maximumAreaRatioDelta {
                return false
            }
        }

        return snapshots.allSatisfy {
            $0.boardAreaRatio >= SudokuOCRConfig.Preview.minimumPreviewBoardAreaRatio
                && $0.qualityScore >= SudokuOCRConfig.Preview.minimumPreviewQualityScore
        }
    }
}

final class CameraSessionManager: NSObject, ObservableObject {
    let session = AVCaptureSession()

    @Published private(set) var latestFrame: UIImage?
    @Published private(set) var latestDetectedCorners: [CGPoint]
    @Published private(set) var latestBoardObservation: CameraBoardObservation?

    private var isConfigured = false
    private let configurationQueue = DispatchQueue(label: "com.soldoku.camera.configure")
    private let sampleBufferQueue = DispatchQueue(label: "com.soldoku.camera.sample-buffer")
    private let cornerDetectionQueue = DispatchQueue(label: "com.soldoku.camera.corner-detection")
    private var lastFrameTimestamp: CFTimeInterval = 0
    private let frameThrottleInterval: CFTimeInterval = 0.12
    private let cornerDetectionSemaphore = DispatchSemaphore(value: 1)
    private var consecutiveCornerDetectionFailures = 0
    private let cornerFailureResetThreshold = 3
    private var recentSnapshots: [CameraBoardSnapshot] = []
    private let visionProcessor: SudokuVisionProcessing

    init(visionProcessor: SudokuVisionProcessing = OpenCVSudokuVisionAdapter()) {
        self.visionProcessor = visionProcessor
        self.latestDetectedCorners = []
        self.latestFrame = nil
        self.latestBoardObservation = nil
    }

    func configureIfNeeded(completion: @escaping (Bool) -> Void) {
        configurationQueue.async {
            guard !self.isConfigured else {
                completion(true)
                return
            }

            guard let camera = AVCaptureDevice.default(for: .video) else {
                completion(false)
                return
            }

            do {
                let input = try AVCaptureDeviceInput(device: camera)

                self.session.beginConfiguration()
                self.session.sessionPreset = .hd1280x720

                if self.session.canAddInput(input) {
                    self.session.addInput(input)
                }

                let output = AVCaptureVideoDataOutput()
                output.alwaysDiscardsLateVideoFrames = true
                output.videoSettings = [
                    kCVPixelBufferPixelFormatTypeKey as String: NSNumber(value: kCVPixelFormatType_32BGRA),
                ]
                output.setSampleBufferDelegate(self, queue: self.sampleBufferQueue)

                if self.session.canAddOutput(output) {
                    self.session.addOutput(output)
                }

                if let connection = output.connection(with: .video), connection.isVideoOrientationSupported {
                    connection.videoOrientation = .portrait
                }

                self.session.commitConfiguration()
                self.isConfigured = true
                completion(true)
            } catch {
                completion(false)
            }
        }
    }

    func startRunning() {
        configurationQueue.async {
            guard self.isConfigured else { return }
            guard !self.session.isRunning else { return }
            self.session.startRunning()
        }
    }

    func stopRunning() {
        configurationQueue.async {
            guard self.session.isRunning else { return }
            self.session.stopRunning()
        }
    }
}

extension CameraSessionManager: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        connection.videoOrientation = .portrait
        let now = CACurrentMediaTime()
        guard now - lastFrameTimestamp >= frameThrottleInterval else { return }
        lastFrameTimestamp = now

        guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        CVPixelBufferLockBaseAddress(imageBuffer, CVPixelBufferLockFlags(rawValue: 0))
        defer {
            CVPixelBufferUnlockBaseAddress(imageBuffer, CVPixelBufferLockFlags(rawValue: 0))
        }

        let width = CVPixelBufferGetWidth(imageBuffer)
        let height = CVPixelBufferGetHeight(imageBuffer)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(imageBuffer)
        guard let baseAddress = CVPixelBufferGetBaseAddress(imageBuffer) else { return }

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue
        guard let context = CGContext(
            data: baseAddress,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: bitmapInfo
        ), let cgImage = context.makeImage() else {
            return
        }

        let frameImage = UIImage(cgImage: cgImage)
        let square = cropToCenterSquare(frameImage)

        detectBoardObservationIfPossible(from: square)

        DispatchQueue.main.async {
            self.latestFrame = square
        }
    }

    private func detectBoardObservationIfPossible(from image: UIImage) {
        guard cornerDetectionSemaphore.wait(timeout: .now()) == .success else { return }
        cornerDetectionQueue.async {
            defer {
                self.cornerDetectionSemaphore.signal()
            }
            let observation = self.visionProcessor.detectBoardObservation(in: image)
            DispatchQueue.main.async {
                self.applyBoardObservation(observation, frameSize: image.size)
            }
        }
    }

    private func applyBoardObservation(_ observation: OpenCVBoardObservation?, frameSize: CGSize) {
        guard let observation, observation.corners.count >= 4 else {
            consecutiveCornerDetectionFailures += 1
            if consecutiveCornerDetectionFailures >= cornerFailureResetThreshold {
                latestDetectedCorners = []
                latestBoardObservation = nil
                recentSnapshots.removeAll()
            }
            return
        }

        consecutiveCornerDetectionFailures = 0
        let snapshot = CameraBoardSnapshot(
            corners: observation.corners,
            boardAreaRatio: observation.boardAreaRatio,
            qualityScore: observation.qualityScore,
            gridConfidence: observation.gridConfidence,
            frameSize: frameSize
        )

        recentSnapshots.append(snapshot)
        if recentSnapshots.count > max(SudokuOCRConfig.Preview.stableFrameCount, 5) {
            recentSnapshots.removeFirst(recentSnapshots.count - max(SudokuOCRConfig.Preview.stableFrameCount, 5))
        }

        let cameraObservation = CameraRecognitionGate.observation(from: recentSnapshots, latest: snapshot)
        latestBoardObservation = cameraObservation
        latestDetectedCorners = cameraObservation.corners
    }

    private func cropToCenterSquare(_ image: UIImage) -> UIImage {
        guard let cgImage = image.cgImage else { return image }

        let width = CGFloat(cgImage.width)
        let height = CGFloat(cgImage.height)
        let side = min(width, height)
        let originX = (width - side) / 2
        let originY = (height - side) / 2

        let cropRect = CGRect(x: originX, y: originY, width: side, height: side)
        guard let cropped = cgImage.cropping(to: cropRect) else {
            return image
        }
        return UIImage(cgImage: cropped)
    }
}

struct CameraPreviewView: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> CameraPreviewContainerView {
        let view = CameraPreviewContainerView()
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ uiView: CameraPreviewContainerView, context: Context) {
        uiView.previewLayer.session = session
    }
}

final class CameraPreviewContainerView: UIView {
    override class var layerClass: AnyClass {
        AVCaptureVideoPreviewLayer.self
    }

    var previewLayer: AVCaptureVideoPreviewLayer {
        (layer as? AVCaptureVideoPreviewLayer) ?? AVCaptureVideoPreviewLayer()
    }
}
