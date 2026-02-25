import XCTest
import DomainVision
@testable import SudokuInfrastructure

final class SudokuImageSolvePipelineTests: XCTestCase {
    func testSolveReturnsSolvedBoardOnHappyPath() {
        let detector = StubDetector(result: .success(.init(
            corners: [
                .init(x: 0, y: 0),
                .init(x: 1, y: 0),
                .init(x: 1, y: 1),
                .init(x: 0, y: 1),
            ],
            warpedBoardImageData: Data([1, 2, 3])
        )))
        let slicer = StubSlicer(result: .success(Array(repeating: Data([0]), count: 81)))
        let predictor = StubPredictor(result: .success(Self.samplePuzzle))

        let pipeline = SudokuImageSolvePipeline(
            detector: detector,
            slicer: slicer,
            predictor: predictor
        )

        let result = pipeline.solve(imageData: Data([9, 9, 9]))

        switch result {
        case .success(let solvedBoard):
            XCTAssertEqual(solvedBoard[0], [5, 3, 4, 6, 7, 8, 9, 1, 2])
            XCTAssertEqual(solvedBoard[8], [3, 4, 5, 2, 8, 6, 1, 7, 9])
        case .failure(let error):
            XCTFail("expected solved board, got error: \(error)")
        }
    }

    func testSolveReturnsInsufficientDigitsWhenGivenCountIsBelowThreshold() {
        let detector = StubDetector(result: .success(.init(corners: [], warpedBoardImageData: Data([1]))))
        let slicer = StubSlicer(result: .success(Array(repeating: Data([0]), count: 81)))

        var sparseDigits = Array(repeating: 0, count: 81)
        for index in 0..<16 {
            sparseDigits[index] = (index % 9) + 1
        }
        let predictor = StubPredictor(result: .success(sparseDigits))

        let pipeline = SudokuImageSolvePipeline(
            detector: detector,
            slicer: slicer,
            predictor: predictor
        )

        let result = pipeline.solve(imageData: Data([9, 9, 9]))

        XCTAssertEqual(
            result,
            .failure(.insufficientDigits(minimum: 17, actual: 16))
        )
    }

    func testSolveMapsBoardNotFoundFromDetector() {
        let detector = StubDetector(result: .failure(VisionContractError.boardNotFound))
        let slicer = StubSlicer(result: .success(Array(repeating: Data([0]), count: 81)))
        let predictor = StubPredictor(result: .success(Self.samplePuzzle))

        let pipeline = SudokuImageSolvePipeline(
            detector: detector,
            slicer: slicer,
            predictor: predictor
        )

        let result = pipeline.solve(imageData: Data([9, 9, 9]))

        XCTAssertEqual(result, .failure(.boardNotFound))
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
}

private final class StubDetector: SudokuBoardDetecting {
    private let result: Result<SudokuBoardDetection, Error>

    init(result: Result<SudokuBoardDetection, Error>) {
        self.result = result
    }

    func detectBoard(in imageData: Data) throws -> SudokuBoardDetection {
        try result.get()
    }
}

private final class StubSlicer: SudokuCellSlicing {
    private let result: Result<[Data], Error>

    init(result: Result<[Data], Error>) {
        self.result = result
    }

    func sliceCells(from warpedBoardImageData: Data) throws -> [Data] {
        try result.get()
    }
}

private final class StubPredictor: SudokuDigitPredicting {
    private let result: Result<[Int], Error>

    init(result: Result<[Int], Error>) {
        self.result = result
    }

    func predictDigits(in cellImageData: [Data]) throws -> [Int] {
        try result.get()
    }
}
