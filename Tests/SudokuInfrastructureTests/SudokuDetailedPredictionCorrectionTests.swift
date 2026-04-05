import XCTest
import DomainVision
@testable import SudokuInfrastructure

final class SudokuDetailedPredictionCorrectionTests: XCTestCase {
    func testPipelineUsesDetailedAlternativesToRecoverInvalidPuzzle() {
        let detector = DetailedStubDetector(result: .success(.init(corners: [], warpedBoardImageData: Data([1]))))
        let slicer = DetailedStubSlicer(result: .success(Array(repeating: Data([0]), count: 81)))

        var invalidDigits = Self.samplePuzzle
        invalidDigits[1] = 5

        var details = Self.samplePuzzle.map {
            SudokuDigitPredictionDetail(
                digit: $0,
                confidence: $0 == 0 ? 0.25 : 0.96,
                alternatives: [],
                isBlankLikely: $0 == 0
            )
        }
        details[1] = SudokuDigitPredictionDetail(
            digit: 5,
            confidence: 0.61,
            alternatives: [.init(digit: 3, confidence: 0.33)],
            isBlankLikely: false
        )

        let predictor = DetailedStubPredictor(digits: invalidDigits, details: details)
        let pipeline = SudokuImageSolvePipeline(
            detector: detector,
            slicer: slicer,
            predictor: predictor
        )

        let result = pipeline.solve(imageData: Data([9, 9, 9]))

        switch result {
        case .success(let solvedBoard):
            XCTAssertEqual(solvedBoard[0], [5, 3, 4, 6, 7, 8, 9, 1, 2])
        case .failure(let error):
            XCTFail("expected correction-assisted solve, got \(error)")
        }
    }

    func testPipelineMinimumDigitsUsesFinalNonZeroDigitsNotAlternatives() {
        let detector = DetailedStubDetector(result: .success(.init(corners: [], warpedBoardImageData: Data([1]))))
        let slicer = DetailedStubSlicer(result: .success(Array(repeating: Data([0]), count: 81)))

        var sparseDigits = Array(repeating: 0, count: 81)
        for index in 0..<16 {
            sparseDigits[index] = (index % 9) + 1
        }

        let details = sparseDigits.map {
            SudokuDigitPredictionDetail(
                digit: $0,
                confidence: $0 == 0 ? 0.3 : 0.92,
                alternatives: $0 == 0 ? [.init(digit: 8, confidence: 0.29)] : [],
                isBlankLikely: $0 == 0
            )
        }

        let predictor = DetailedStubPredictor(digits: sparseDigits, details: details)
        let pipeline = SudokuImageSolvePipeline(
            detector: detector,
            slicer: slicer,
            predictor: predictor
        )

        let result = pipeline.solve(imageData: Data([9, 9, 9]))

        XCTAssertEqual(result, .failure(.insufficientDigits(minimum: 17, actual: 16)))
    }

    func testDetailedPredictionCorrectionReturnsNilForHighConfidenceBoard() {
        let board = Self.board(from: Self.samplePuzzle)
        let details = Self.samplePuzzle.map {
            SudokuDigitPredictionDetail(
                digit: $0,
                confidence: 0.97,
                alternatives: [],
                isBlankLikely: false
            )
        }

        let result = DetailedPredictionCorrection.solveIfNeeded(
            board: board,
            details: details,
            solver: .init()
        )

        XCTAssertNil(result)
    }

    func testDetailedPredictionCorrectionCanBlankConflictingDigit() {
        var invalidDigits = Self.samplePuzzle
        invalidDigits[2] = 5

        let details = invalidDigits.enumerated().map { index, digit in
            SudokuDigitPredictionDetail(
                digit: digit,
                confidence: index == 2 ? 0.88 : (digit == 0 ? 0.25 : 0.97),
                alternatives: [],
                isBlankLikely: false
            )
        }

        let result = DetailedPredictionCorrection.solveIfNeeded(
            board: Self.board(from: invalidDigits),
            details: details,
            solver: .init()
        )

        XCTAssertEqual(result?.correctedBoard[0][2], 0)
        XCTAssertEqual(result?.solvedBoard[0], [5, 3, 4, 6, 7, 8, 9, 1, 2])
    }

    func testDetailedPredictionCorrectionCanBlankLowConfidenceDigitWithoutExplicitAlternative() {
        var invalidDigits = Self.samplePuzzle
        invalidDigits[2] = 2

        let details = invalidDigits.enumerated().map { index, digit in
            SudokuDigitPredictionDetail(
                digit: digit,
                confidence: index == 2 ? 0.80 : (digit == 0 ? 0.25 : 0.97),
                alternatives: [],
                isBlankLikely: false
            )
        }

        let result = DetailedPredictionCorrection.solveIfNeeded(
            board: Self.board(from: invalidDigits),
            details: details,
            solver: .init()
        )

        XCTAssertEqual(result?.correctedBoard[0][2], 0)
        XCTAssertEqual(result?.solvedBoard[0], [5, 3, 4, 6, 7, 8, 9, 1, 2])
    }

    private static let samplePuzzle: [Int] = [
        5, 3, 0, 0, 7, 0, 0, 0, 0,
        6, 0, 0, 1, 9, 5, 0, 0, 0,
        0, 9, 8, 0, 0, 0, 0, 6, 0,
        8, 0, 0, 0, 6, 0, 0, 0, 3,
        4, 0, 0, 8, 0, 3, 0, 0, 1,
        7, 0, 0, 0, 2, 0, 0, 0, 6,
        0, 6, 0, 0, 0, 0, 2, 8, 0,
        0, 0, 0, 4, 1, 9, 0, 0, 5,
        0, 0, 0, 0, 8, 0, 0, 7, 9,
    ]

    private static func board(from digits: [Int]) -> [[Int]] {
        stride(from: 0, to: digits.count, by: 9).map { offset in
            Array(digits[offset..<(offset + 9)])
        }
    }
}

private final class DetailedStubDetector: SudokuBoardDetecting {
    private let result: Result<SudokuBoardDetection, Error>

    init(result: Result<SudokuBoardDetection, Error>) {
        self.result = result
    }

    func detectBoard(in imageData: Data) throws -> SudokuBoardDetection {
        try result.get()
    }
}

private final class DetailedStubSlicer: SudokuCellSlicing {
    private let result: Result<[Data], Error>

    init(result: Result<[Data], Error>) {
        self.result = result
    }

    func sliceCells(from warpedBoardImageData: Data) throws -> [Data] {
        try result.get()
    }
}

private final class DetailedStubPredictor: SudokuDigitPredictingDetailed {
    private let digits: [Int]
    private let details: [SudokuDigitPredictionDetail]

    init(digits: [Int], details: [SudokuDigitPredictionDetail]) {
        self.digits = digits
        self.details = details
    }

    func predictDigits(in cellImageData: [Data]) throws -> [Int] {
        digits
    }

    func predictDigitsDetailed(in cellImageData: [Data]) throws -> [SudokuDigitPredictionDetail] {
        details
    }
}
