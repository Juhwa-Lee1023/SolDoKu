import AVFoundation
import QuartzCore
import SwiftUI
import UIKit

final class CameraSessionManager: NSObject, ObservableObject {
    let session = AVCaptureSession()

    @Published private(set) var latestFrame: UIImage?
    @Published private(set) var latestDetectedCorners: [CGPoint]

    private var isConfigured = false
    private let configurationQueue = DispatchQueue(label: "com.soldoku.camera.configure")
    private let sampleBufferQueue = DispatchQueue(label: "com.soldoku.camera.sample-buffer")
    private let cornerDetectionQueue = DispatchQueue(label: "com.soldoku.camera.corner-detection")
    private var lastFrameTimestamp: CFTimeInterval = 0
    private let frameThrottleInterval: CFTimeInterval = 0.12
    private let cornerDetectionSemaphore = DispatchSemaphore(value: 1)
    private var consecutiveCornerDetectionFailures = 0
    private let cornerFailureResetThreshold = 3
    private let visionProcessor: SudokuVisionProcessing

    init(visionProcessor: SudokuVisionProcessing = OpenCVSudokuVisionAdapter()) {
        self.visionProcessor = visionProcessor
        self.latestDetectedCorners = []
        self.latestFrame = nil
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

        detectCornersIfPossible(from: square)

        DispatchQueue.main.async {
            self.latestFrame = square
        }
    }

    private func detectCornersIfPossible(from image: UIImage) {
        guard cornerDetectionSemaphore.wait(timeout: .now()) == .success else { return }
        cornerDetectionQueue.async {
            defer {
                self.cornerDetectionSemaphore.signal()
            }
            let corners = self.visionProcessor.detectCorners(in: image)
            DispatchQueue.main.async {
                guard let corners, corners.count >= 4 else {
                    self.consecutiveCornerDetectionFailures += 1
                    if self.consecutiveCornerDetectionFailures >= self.cornerFailureResetThreshold {
                        self.latestDetectedCorners = []
                    }
                    return
                }
                self.consecutiveCornerDetectionFailures = 0
                self.latestDetectedCorners = Array(corners.prefix(4))
            }
        }
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
