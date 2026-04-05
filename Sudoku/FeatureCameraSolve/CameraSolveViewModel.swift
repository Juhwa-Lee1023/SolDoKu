import Combine
import Foundation
import UIKit

final class CameraSolveViewModel: ObservableObject {
    enum AlertKind: Identifiable {
        case permissionDenied
        case insufficientDigits
        case solveFailed

        var id: String {
            switch self {
            case .permissionDenied:
                return "permissionDenied"
            case .insufficientDigits:
                return "insufficientDigits"
            case .solveFailed:
                return "solveFailed"
            }
        }
    }

    enum PrimaryButtonMode {
        case shoot
        case shootAgain
    }

    @Published private(set) var isSolving: Bool
    @Published private(set) var solvedImage: UIImage?
    @Published private(set) var recognizedPreviewImage: UIImage?
    @Published private(set) var latestDetectedCorners: [CGPoint]
    @Published private(set) var latestFrameSize: CGSize?
    @Published private(set) var primaryButtonMode: PrimaryButtonMode
    @Published var alertKind: AlertKind?

    let cameraManager: CameraSessionManager

    private let permissionAuthorizer: PermissionAuthorizing
    private let visionProcessor: SudokuVisionProcessing
    private let puzzleRecognizer: SudokuPuzzleRecognizing
    private let boardSolver: SudokuBoardSolving

    private var frameObservation: AnyCancellable?
    private var cornersObservation: AnyCancellable?
    private var boardObservation: AnyCancellable?
    private var pendingSolveImage: UIImage?
    private var activeSolveToken = UUID()
    private var isLiveRecognitionInProgress = false
    private var liveRecognitionFrameCounter = 0
    private let liveRecognitionFrameInterval = 4
    private var latestBoardObservation: CameraBoardObservation?
    private var lastLiveRecognitionSignature: Int?

    init(
        cameraManager: CameraSessionManager = .init(),
        permissionAuthorizer: PermissionAuthorizing = SystemPermissionAuthorizer(),
        visionProcessor: SudokuVisionProcessing = OpenCVSudokuVisionAdapter(),
        boardSolver: SudokuBoardSolving = LegacySudokuBoardSolver()
    ) {
        self.cameraManager = cameraManager
        self.permissionAuthorizer = permissionAuthorizer
        self.visionProcessor = visionProcessor
        self.boardSolver = boardSolver
        self.puzzleRecognizer = SudokuPuzzleRecognizer(
            visionProcessor: visionProcessor,
            digitPredictor: HybridDigitPredictor()
        )
        self.isSolving = false
        self.solvedImage = nil
        self.recognizedPreviewImage = nil
        self.latestDetectedCorners = []
        self.latestFrameSize = nil
        self.primaryButtonMode = .shoot
        self.alertKind = nil
        self.pendingSolveImage = nil
        bindLivePreviewRecognition()
    }

    var primaryButtonTitle: String {
        switch primaryButtonMode {
        case .shoot:
            return L10n.Camera.shootingSudoku.localized
        case .shootAgain:
            return L10n.Camera.shootAgain.localized
        }
    }

    func onAppear() {
        requestCameraPermission()
    }

    func onDisappear() {
        invalidateSolveToken()
        isSolving = false
        recognizedPreviewImage = nil
        latestDetectedCorners = []
        latestFrameSize = nil
        latestBoardObservation = nil
        liveRecognitionFrameCounter = 0
        lastLiveRecognitionSignature = nil
        cameraManager.stopRunning()
    }

    func primaryActionTapped() {
        switch primaryButtonMode {
        case .shoot:
            startSolve(ignoreMinimumDigits: false, sourceImage: nil)
        case .shootAgain:
            resetToCameraPreview()
        }
    }

    func solveIgnoringMinimumDigits() {
        startSolve(ignoreMinimumDigits: true, sourceImage: pendingSolveImage)
    }

    func cancelSolveAndResumeCamera() {
        invalidateSolveToken()
        isSolving = false
        primaryButtonMode = .shoot
        recognizedPreviewImage = nil
        latestDetectedCorners = []
        latestFrameSize = nil
        latestBoardObservation = nil
        liveRecognitionFrameCounter = 0
        pendingSolveImage = nil
        lastLiveRecognitionSignature = nil
        configureAndStartCamera()
    }

    func openSettings() {
        guard let settingURL = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(settingURL)
    }

    private func requestCameraPermission() {
        permissionAuthorizer.requestCameraAccess { [weak self] granted in
            guard let self else { return }
            DispatchQueue.main.async {
                if granted {
                    self.configureAndStartCamera()
                } else {
                    self.alertKind = .permissionDenied
                }
            }
        }
    }

    private func configureAndStartCamera() {
        cameraManager.configureIfNeeded { [weak self] configured in
            guard let self else { return }
            DispatchQueue.main.async {
                if configured {
                    self.cameraManager.startRunning()
                } else {
                    self.alertKind = .solveFailed
                }
            }
        }
    }

    private func bindLivePreviewRecognition() {
        cornersObservation = cameraManager.$latestDetectedCorners
            .receive(on: DispatchQueue.main)
            .sink { [weak self] corners in
                self?.latestDetectedCorners = corners
            }

        boardObservation = cameraManager.$latestBoardObservation
            .receive(on: DispatchQueue.main)
            .sink { [weak self] observation in
                self?.latestBoardObservation = observation
                if observation == nil {
                    self?.lastLiveRecognitionSignature = nil
                    self?.recognizedPreviewImage = nil
                }
            }

        frameObservation = cameraManager.$latestFrame
            .receive(on: DispatchQueue.main)
            .sink { [weak self] frame in
                guard let self else { return }
                self.latestFrameSize = frame?.size
                guard let frame else { return }
                self.updateLiveRecognizedPreviewIfNeeded(from: frame)
            }
    }

    private func updateLiveRecognizedPreviewIfNeeded(from frame: UIImage) {
        guard solvedImage == nil,
              !isSolving,
              primaryButtonMode == .shoot else {
            return
        }
        guard let observation = latestBoardObservation,
              observation.isStable,
              observation.boardAreaRatio >= SudokuOCRConfig.Preview.minimumPreviewBoardAreaRatio,
              observation.qualityScore >= SudokuOCRConfig.Preview.minimumPreviewQualityScore else {
            return
        }
        guard !isLiveRecognitionInProgress else { return }

        liveRecognitionFrameCounter += 1
        guard liveRecognitionFrameCounter >= liveRecognitionFrameInterval else { return }
        liveRecognitionFrameCounter = 0

        let signature = observation.recognitionSignature
        guard signature != lastLiveRecognitionSignature else { return }
        lastLiveRecognitionSignature = signature

        isLiveRecognitionInProgress = true
        DispatchQueue.global(qos: .userInitiated).async {
            defer {
                DispatchQueue.main.async {
                    self.isLiveRecognitionInProgress = false
                }
            }

            guard let detectedRectangle = self.visionProcessor.detectRectangle(in: frame),
                  self.isRectangleConsistent(with: observation, detectedRectangle: detectedRectangle),
                  let recognitionResult = self.puzzleRecognizer.recognizeBoard(
                      from: detectedRectangle.warpedImage,
                      imageSize: 64,
                      cutOffset: 0
                  ),
                  let boardImage = UIImage(named: "sudoku") else {
                DispatchQueue.main.async {
                    if self.lastLiveRecognitionSignature == signature {
                        self.lastLiveRecognitionSignature = nil
                    }
                }
                return
            }

            let previewBoard: [[Int]]
            if let corrected = self.puzzleRecognizer.solveRecognizedBoard(from: recognitionResult, using: self.boardSolver) {
                previewBoard = corrected.correctedBoard
            } else {
                previewBoard = recognitionResult.board
            }

            let previewImage = SudokuBoardOverlayRenderer.drawRecognizedBoard(
                board: previewBoard,
                on: boardImage
            )

            DispatchQueue.main.async {
                guard self.solvedImage == nil,
                      !self.isSolving,
                      self.primaryButtonMode == .shoot,
                      self.latestBoardObservation?.recognitionSignature == signature else { return }
                self.recognizedPreviewImage = previewImage
            }
        }
    }

    private func startSolve(ignoreMinimumDigits: Bool, sourceImage: UIImage?) {
        guard !isSolving else { return }
        guard let frame = sourceImage ?? cameraManager.latestFrame else {
            alertKind = .solveFailed
            return
        }

        if sourceImage == nil && !isCameraReadyForSolve() {
            alertKind = .solveFailed
            return
        }

        let solveToken = UUID()
        activeSolveToken = solveToken
        isSolving = true
        cameraManager.stopRunning()

        DispatchQueue.global(qos: .userInitiated).async {
            let analysis: SudokuPuzzleAnalysis?
            if let sourceImage {
                analysis = self.puzzleRecognizer.analyzePuzzle(
                    in: sourceImage,
                    imageSize: 64,
                    cutOffset: 0,
                    using: self.boardSolver
                )
            } else if let observation = self.latestBoardObservation,
                      let detectedRectangle = self.visionProcessor.detectRectangle(in: frame),
                      self.isRectangleConsistent(with: observation, detectedRectangle: detectedRectangle) {
                analysis = self.puzzleRecognizer.analyzePuzzle(
                    in: frame,
                    imageSize: 64,
                    cutOffset: 0,
                    using: self.boardSolver
                )
            } else {
                analysis = nil
            }

            guard let analysis else {
                DispatchQueue.main.async {
                    guard self.activeSolveToken == solveToken else { return }
                    self.isSolving = false
                    self.primaryButtonMode = .shoot
                    self.alertKind = .solveFailed
                    self.cameraManager.startRunning()
                }
                return
            }

            DispatchQueue.main.async {
                guard self.activeSolveToken == solveToken else { return }
                let recognitionResult = analysis.recognitionResult
                if !ignoreMinimumDigits && recognitionResult.recognizedCount < 17 {
                    self.isSolving = false
                    self.pendingSolveImage = sourceImage ?? frame
                    self.alertKind = .insufficientDigits
                    return
                }

                self.solveRecognizedBoard(analysis, solveToken: solveToken)
            }
        }
    }

    private func solveRecognizedBoard(_ analysis: SudokuPuzzleAnalysis, solveToken: UUID) {
        DispatchQueue.main.async {
            guard self.activeSolveToken == solveToken else { return }
            self.isSolving = false

            guard let solveResult = analysis.correctionResult else {
                self.primaryButtonMode = .shoot
                self.alertKind = .solveFailed
                self.cameraManager.startRunning()
                return
            }

            self.solvedImage = SudokuBoardOverlayRenderer.drawSolvedBoard(
                solvedBoard: solveResult.solvedBoard,
                recognizedBoard: solveResult.correctedBoard,
                on: analysis.detectedBoard.warpedImage
            )
            self.primaryButtonMode = .shootAgain
            self.pendingSolveImage = nil
        }
    }

    private func resetToCameraPreview() {
        invalidateSolveToken()
        solvedImage = nil
        recognizedPreviewImage = nil
        latestDetectedCorners = []
        latestFrameSize = nil
        latestBoardObservation = nil
        liveRecognitionFrameCounter = 0
        primaryButtonMode = .shoot
        pendingSolveImage = nil
        lastLiveRecognitionSignature = nil
        configureAndStartCamera()
    }

    private func invalidateSolveToken() {
        activeSolveToken = UUID()
    }

    private func isCameraReadyForSolve() -> Bool {
        guard let observation = latestBoardObservation else { return false }
        return observation.isStable
            && observation.boardAreaRatio >= SudokuOCRConfig.Preview.minimumPreviewBoardAreaRatio
            && observation.qualityScore >= SudokuOCRConfig.Preview.minimumPreviewQualityScore
    }

    private func isRectangleConsistent(with observation: CameraBoardObservation, detectedRectangle: OpenCVDetectedRectangle) -> Bool {
        guard observation.corners.count == 4, detectedRectangle.corners.count == 4 else { return false }
        let referenceSide = max(max(observation.frameSize.width, observation.frameSize.height), 1)
        let maximumAllowedDrift = referenceSide * SudokuOCRConfig.Preview.maximumCornerDriftRatio * CGFloat(1.5)
        let averageCornerDrift = zip(observation.corners, detectedRectangle.corners)
            .map { hypot($0.x - $1.x, $0.y - $1.y) }
            .reduce(CGFloat(0), +) / 4.0
        let areaDelta = abs(observation.boardAreaRatio - detectedRectangle.boardAreaRatio)
        return averageCornerDrift <= maximumAllowedDrift
            && areaDelta <= SudokuOCRConfig.Preview.maximumAreaRatioDelta * CGFloat(1.5)
            && detectedRectangle.qualityScore >= SudokuOCRConfig.Preview.minimumPreviewQualityScore
    }
}
