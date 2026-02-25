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
    private var pendingSolveImage: UIImage?
    private var activeSolveToken = UUID()
    private var isLiveRecognitionInProgress = false
    private var liveRecognitionFrameCounter = 0
    private let liveRecognitionFrameInterval = 8

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
            digitPredictor: CoreMLDigitPredictor()
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
        liveRecognitionFrameCounter = 0
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
        liveRecognitionFrameCounter = 0
        pendingSolveImage = nil
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
        guard !isLiveRecognitionInProgress else { return }

        liveRecognitionFrameCounter += 1
        guard liveRecognitionFrameCounter >= liveRecognitionFrameInterval else { return }
        liveRecognitionFrameCounter = 0

        isLiveRecognitionInProgress = true
        DispatchQueue.global(qos: .userInitiated).async {
            defer {
                DispatchQueue.main.async {
                    self.isLiveRecognitionInProgress = false
                }
            }

            guard let detectedRectangle = self.visionProcessor.detectRectangle(in: frame),
                  self.isDetectedRectangleLargeEnough(detectedRectangle.corners),
                  let recognitionResult = self.puzzleRecognizer.recognizeBoard(
                      from: detectedRectangle.warpedImage,
                      imageSize: 64,
                      cutOffset: 0
                  ),
                  let boardImage = UIImage(named: "sudoku") else {
                return
            }

            let previewImage = SudokuBoardOverlayRenderer.drawRecognizedBoard(
                board: recognitionResult.board,
                on: boardImage
            )

            DispatchQueue.main.async {
                guard self.solvedImage == nil,
                      !self.isSolving,
                      self.primaryButtonMode == .shoot else { return }
                self.recognizedPreviewImage = previewImage
            }
        }
    }

    private func isDetectedRectangleLargeEnough(_ corners: [CGPoint]) -> Bool {
        guard corners.count >= 4 else { return false }
        let valueX = corners[0].x - corners[3].x
        let valueY = corners[0].y - corners[1].y
        let valueX2 = corners[1].x - corners[2].x
        let valueY2 = corners[2].y - corners[3].y
        return abs(valueX) > 100 && abs(valueY) > 100 && abs(valueX2) > 100 && abs(valueY2) > 100
    }

    private func startSolve(ignoreMinimumDigits: Bool, sourceImage: UIImage?) {
        guard !isSolving else { return }
        guard let frame = sourceImage ?? cameraManager.latestFrame else {
            alertKind = .solveFailed
            return
        }

        let solveToken = UUID()
        activeSolveToken = solveToken
        isSolving = true
        cameraManager.stopRunning()

        DispatchQueue.global(qos: .userInitiated).async {
            guard let warpedImage = self.visionProcessor.detectRectangle(in: frame)?.warpedImage,
                  let recognitionResult = self.puzzleRecognizer.recognizeBoard(from: warpedImage, imageSize: 64, cutOffset: 0) else {
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
                if !ignoreMinimumDigits && recognitionResult.recognizedCount < 17 {
                    self.isSolving = false
                    self.pendingSolveImage = warpedImage
                    self.alertKind = .insufficientDigits
                    return
                }

                self.solveRecognizedBoard(recognitionResult.board, warpedImage: warpedImage, solveToken: solveToken)
            }
        }
    }

    private func solveRecognizedBoard(_ recognizedBoard: [[Int]], warpedImage: UIImage, solveToken: UUID) {
        DispatchQueue.global(qos: .userInitiated).async {
            let result = self.boardSolver.solve(board: recognizedBoard, iterationLimit: 1_000_000)

            DispatchQueue.main.async {
                guard self.activeSolveToken == solveToken else { return }
                self.isSolving = false

                switch result {
                case .success(let solvedBoard):
                    self.solvedImage = SudokuBoardOverlayRenderer.drawSolvedBoard(
                        solvedBoard: solvedBoard,
                        recognizedBoard: recognizedBoard,
                        on: warpedImage
                    )
                    self.primaryButtonMode = .shootAgain
                    self.pendingSolveImage = nil

                case .failure:
                    self.primaryButtonMode = .shoot
                    self.alertKind = .solveFailed
                    self.cameraManager.startRunning()
                }
            }
        }
    }

    private func resetToCameraPreview() {
        invalidateSolveToken()
        solvedImage = nil
        recognizedPreviewImage = nil
        latestDetectedCorners = []
        latestFrameSize = nil
        liveRecognitionFrameCounter = 0
        primaryButtonMode = .shoot
        pendingSolveImage = nil
        configureAndStartCamera()
    }

    private func invalidateSolveToken() {
        activeSolveToken = UUID()
    }
}
