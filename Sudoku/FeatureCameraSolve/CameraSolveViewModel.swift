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
    @Published private(set) var primaryButtonMode: PrimaryButtonMode
    @Published var alertKind: AlertKind?

    let cameraManager: CameraSessionManager

    private let permissionAuthorizer: PermissionAuthorizing
    private let visionProcessor: SudokuVisionProcessing
    private let puzzleRecognizer: SudokuPuzzleRecognizing
    private let boardSolver: SudokuBoardSolving

    private var pendingSolveImage: UIImage?
    private var activeSolveToken = UUID()

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
        self.primaryButtonMode = .shoot
        self.alertKind = nil
        self.pendingSolveImage = nil
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
        primaryButtonMode = .shoot
        pendingSolveImage = nil
        configureAndStartCamera()
    }

    private func invalidateSolveToken() {
        activeSolveToken = UUID()
    }
}
