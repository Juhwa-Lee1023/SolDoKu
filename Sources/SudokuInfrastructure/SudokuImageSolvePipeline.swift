import Foundation
import DomainVision
import SudokuDomain

public enum SudokuPipelineError: Error, Equatable {
    case invalidImage
    case boardNotFound
    case invalidCellCount(expected: Int, actual: Int)
    case invalidPredictionCount(expected: Int, actual: Int)
    case insufficientDigits(minimum: Int, actual: Int)
    case invalidPuzzle
    case unsolvable
    case iterationLimitExceeded
    case processingFailed(String)
}

public struct SudokuImageSolvePipeline {
    private let detector: SudokuBoardDetecting
    private let slicer: SudokuCellSlicing
    private let predictor: SudokuDigitPredicting
    private let solver: SudokuSolver

    public init(
        detector: SudokuBoardDetecting,
        slicer: SudokuCellSlicing,
        predictor: SudokuDigitPredicting,
        solver: SudokuSolver = .init()
    ) {
        self.detector = detector
        self.slicer = slicer
        self.predictor = predictor
        self.solver = solver
    }

    public func solve(
        imageData: Data,
        minimumRequiredDigits: Int = 17,
        iterationLimit: Int = 1_000_000
    ) -> Result<[[Int]], SudokuPipelineError> {
        let detection: SudokuBoardDetection
        do {
            detection = try detector.detectBoard(in: imageData)
        } catch {
            return .failure(mapVisionError(error))
        }

        let cellImages: [Data]
        do {
            cellImages = try slicer.sliceCells(from: detection.warpedBoardImageData)
        } catch {
            return .failure(mapVisionError(error))
        }

        guard cellImages.count == 81 else {
            return .failure(.invalidCellCount(expected: 81, actual: cellImages.count))
        }

        let digits: [Int]
        do {
            digits = try predictor.predictDigits(in: cellImages)
        } catch {
            return .failure(mapVisionError(error))
        }

        guard digits.count == 81 else {
            return .failure(.invalidPredictionCount(expected: 81, actual: digits.count))
        }

        let givenCount = digits.filter { $0 != 0 }.count
        guard givenCount >= minimumRequiredDigits else {
            return .failure(.insufficientDigits(minimum: minimumRequiredDigits, actual: givenCount))
        }

        let board = toBoard(from: digits)
        switch solver.solve(board, iterationLimit: iterationLimit) {
        case .success(let solvedBoard):
            return .success(solvedBoard)
        case .failure(let error):
            return .failure(mapSolverError(error))
        }
    }

    private func toBoard(from digits: [Int]) -> [[Int]] {
        stride(from: 0, to: digits.count, by: 9).map {
            Array(digits[$0..<($0 + 9)])
        }
    }

    private func mapVisionError(_ error: Error) -> SudokuPipelineError {
        guard let contractError = error as? VisionContractError else {
            return .processingFailed(String(describing: error))
        }

        switch contractError {
        case .invalidImage:
            return .invalidImage
        case .boardNotFound:
            return .boardNotFound
        case .predictionFailed:
            return .processingFailed("predictionFailed")
        case .unexpected(let message):
            return .processingFailed(message)
        }
    }

    private func mapSolverError(_ error: SudokuSolverError) -> SudokuPipelineError {
        switch error {
        case .invalidBoard:
            return .invalidPuzzle
        case .unsolvable:
            return .unsolvable
        case .iterationLimitExceeded:
            return .iterationLimitExceeded
        }
    }
}
