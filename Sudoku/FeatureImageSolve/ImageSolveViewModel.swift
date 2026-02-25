import Foundation
import UIKit

final class ImageSolveViewModel: ObservableObject {
    enum AlertKind: Identifiable {
        case imageMissing
        case imageLoadFailed
        case insufficientDigits
        case unsolvable
        case albumPermissionDenied

        var id: String {
            switch self {
            case .imageMissing:
                return "imageMissing"
            case .imageLoadFailed:
                return "imageLoadFailed"
            case .insufficientDigits:
                return "insufficientDigits"
            case .unsolvable:
                return "unsolvable"
            case .albumPermissionDenied:
                return "albumPermissionDenied"
            }
        }
    }

    @Published private(set) var displayImage: UIImage?
    @Published private(set) var isSolving: Bool
    @Published var alertKind: AlertKind?

    private let permissionAuthorizer: PermissionAuthorizing
    private let visionProcessor: SudokuVisionProcessing
    private let puzzleRecognizer: SudokuPuzzleRecognizing
    private let boardSolver: SudokuBoardSolving

    private var sourceImage: UIImage?
    private var activeSolveToken = UUID()

    init(
        permissionAuthorizer: PermissionAuthorizing = SystemPermissionAuthorizer(),
        visionProcessor: SudokuVisionProcessing = OpenCVSudokuVisionAdapter(),
        boardSolver: SudokuBoardSolving = LegacySudokuBoardSolver()
    ) {
        self.permissionAuthorizer = permissionAuthorizer
        self.visionProcessor = visionProcessor
        self.boardSolver = boardSolver
        self.puzzleRecognizer = SudokuPuzzleRecognizer(
            visionProcessor: visionProcessor,
            digitPredictor: CoreMLDigitPredictor()
        )
        self.displayImage = nil
        self.isSolving = false
        self.alertKind = nil
    }

    func requestPhotoPermissionAndThen(_ onGranted: @escaping () -> Void) {
        permissionAuthorizer.requestPhotoLibraryReadWrite { [weak self] granted in
            guard let self else { return }
            DispatchQueue.main.async {
                if granted {
                    onGranted()
                } else {
                    self.alertKind = .albumPermissionDenied
                }
            }
        }
    }

    func applyPickedImage(_ image: UIImage) {
        invalidateSolveToken()
        isSolving = false
        let normalized = image.fixOrientation()
        if let detectedRectangle = visionProcessor.detectRectangle(in: normalized) {
            sourceImage = detectedRectangle.warpedImage
            displayImage = detectedRectangle.warpedImage
        } else {
            sourceImage = normalized
            displayImage = normalized
        }
    }

    func clearImage() {
        invalidateSolveToken()
        isSolving = false
        sourceImage = nil
        displayImage = nil
    }

    func solveButtonTapped() {
        guard !isSolving else { return }
        guard sourceImage != nil else {
            alertKind = .imageMissing
            return
        }
        runSolve(ignoreMinimumDigits: false)
    }

    func solveIgnoringMinimumDigits() {
        guard !isSolving else { return }
        runSolve(ignoreMinimumDigits: true)
    }

    func openSettings() {
        guard let settingURL = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(settingURL)
    }

    private func runSolve(ignoreMinimumDigits: Bool) {
        guard let image = sourceImage else {
            alertKind = .imageMissing
            return
        }

        let solveToken = UUID()
        activeSolveToken = solveToken
        isSolving = true
        DispatchQueue.global(qos: .userInitiated).async {
            let recognitionResult = self.puzzleRecognizer.recognizeBoard(from: image, imageSize: 64, cutOffset: 0)

            DispatchQueue.main.async {
                guard self.activeSolveToken == solveToken else { return }
                guard let recognitionResult else {
                    self.isSolving = false
                    self.alertKind = .unsolvable
                    return
                }

                if !ignoreMinimumDigits && recognitionResult.recognizedCount < 17 {
                    self.isSolving = false
                    self.alertKind = .insufficientDigits
                    return
                }

                self.solveRecognizedBoard(recognitionResult.board, on: image, solveToken: solveToken)
            }
        }
    }

    private func solveRecognizedBoard(_ recognizedBoard: [[Int]], on image: UIImage, solveToken: UUID) {
        DispatchQueue.global(qos: .userInitiated).async {
            let solveResult = self.boardSolver.solve(board: recognizedBoard, iterationLimit: 1_000_000)

            DispatchQueue.main.async {
                guard self.activeSolveToken == solveToken else { return }
                self.isSolving = false

                switch solveResult {
                case .success(let solvedBoard):
                    self.displayImage = SudokuBoardOverlayRenderer.drawSolvedBoard(
                        solvedBoard: solvedBoard,
                        recognizedBoard: recognizedBoard,
                        on: image
                    )
                case .failure:
                    self.alertKind = .unsolvable
                }
            }
        }
    }

    private func invalidateSolveToken() {
        activeSolveToken = UUID()
    }
}
