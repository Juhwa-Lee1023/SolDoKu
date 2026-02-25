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

    func testSolveMapsPermissionDeniedFromDetector() {
        let detector = StubDetector(result: .failure(VisionContractError.permissionDenied))
        let slicer = StubSlicer(result: .success(Array(repeating: Data([0]), count: 81)))
        let predictor = StubPredictor(result: .success(Self.samplePuzzle))

        let pipeline = SudokuImageSolvePipeline(
            detector: detector,
            slicer: slicer,
            predictor: predictor
        )

        let result = pipeline.solve(imageData: Data([9, 9, 9]))

        XCTAssertEqual(result, .failure(.permissionDenied))
    }

    func testSolveMapsPredictionFailureFromPredictor() {
        let detector = StubDetector(result: .success(.init(corners: [], warpedBoardImageData: Data([1]))))
        let slicer = StubSlicer(result: .success(Array(repeating: Data([0]), count: 81)))
        let predictor = StubPredictor(result: .failure(VisionContractError.predictionFailed))

        let pipeline = SudokuImageSolvePipeline(
            detector: detector,
            slicer: slicer,
            predictor: predictor
        )

        let result = pipeline.solve(imageData: Data([9, 9, 9]))

        XCTAssertEqual(result, .failure(.predictionFailed))
    }

    func testSolveReturnsInvalidCellCountWhenSliceCountIsNot81() {
        let detector = StubDetector(result: .success(.init(corners: [], warpedBoardImageData: Data([1]))))
        let slicer = StubSlicer(result: .success(Array(repeating: Data([0]), count: 80)))
        let predictor = StubPredictor(result: .success(Self.samplePuzzle))

        let pipeline = SudokuImageSolvePipeline(
            detector: detector,
            slicer: slicer,
            predictor: predictor
        )

        let result = pipeline.solve(imageData: Data([9, 9, 9]))

        XCTAssertEqual(result, .failure(.invalidCellCount(expected: 81, actual: 80)))
    }

    func testSolveReturnsInvalidPredictionCountWhenPredictionCountIsNot81() {
        let detector = StubDetector(result: .success(.init(corners: [], warpedBoardImageData: Data([1]))))
        let slicer = StubSlicer(result: .success(Array(repeating: Data([0]), count: 81)))
        let predictor = StubPredictor(result: .success(Array(repeating: 0, count: 80)))

        let pipeline = SudokuImageSolvePipeline(
            detector: detector,
            slicer: slicer,
            predictor: predictor
        )

        let result = pipeline.solve(imageData: Data([9, 9, 9]))

        XCTAssertEqual(result, .failure(.invalidPredictionCount(expected: 81, actual: 80)))
    }

    func testSolveReturnsIterationLimitExceededWhenLimitIsZero() {
        let detector = StubDetector(result: .success(.init(corners: [], warpedBoardImageData: Data([1]))))
        let slicer = StubSlicer(result: .success(Array(repeating: Data([0]), count: 81)))
        let predictor = StubPredictor(result: .success(Self.samplePuzzle))

        let pipeline = SudokuImageSolvePipeline(
            detector: detector,
            slicer: slicer,
            predictor: predictor
        )

        let result = pipeline.solve(
            imageData: Data([9, 9, 9]),
            minimumRequiredDigits: 17,
            iterationLimit: 0
        )

        XCTAssertEqual(result, .failure(.iterationLimitExceeded))
    }

    func testFixtureBasedPipelineFlowUsesFixtureImageData() throws {
        let fixtureData = try Self.loadFixtureData(named: "sample-image", ext: "bin")
        let expectedWarpedData = Data("fixture-warped-data".utf8)
        let expectedCells = Array(repeating: Data([1]), count: 81)

        var detectorInput: Data?
        var slicerInput: Data?
        var predictorInputCount: Int?

        let detector = StubDetector(
            result: .success(.init(corners: [], warpedBoardImageData: expectedWarpedData)),
            onDetect: { detectorInput = $0 }
        )
        let slicer = StubSlicer(
            result: .success(expectedCells),
            onSlice: { slicerInput = $0 }
        )
        let predictor = StubPredictor(
            result: .success(Self.samplePuzzle),
            onPredict: { predictorInputCount = $0.count }
        )

        let pipeline = SudokuImageSolvePipeline(
            detector: detector,
            slicer: slicer,
            predictor: predictor
        )

        _ = pipeline.solve(imageData: fixtureData)

        XCTAssertEqual(detectorInput, fixtureData)
        XCTAssertEqual(slicerInput, expectedWarpedData)
        XCTAssertEqual(predictorInputCount, 81)
    }

    func testSolveReturnsInvalidPuzzleWhenDigitsContainContradiction() {
        let detector = StubDetector(result: .success(.init(corners: [], warpedBoardImageData: Data([1]))))
        let slicer = StubSlicer(result: .success(Array(repeating: Data([0]), count: 81)))

        var invalidDigits = Self.samplePuzzle
        invalidDigits[0] = 5
        invalidDigits[1] = 5
        let predictor = StubPredictor(result: .success(invalidDigits))

        let pipeline = SudokuImageSolvePipeline(
            detector: detector,
            slicer: slicer,
            predictor: predictor
        )

        let result = pipeline.solve(imageData: Data([9, 9, 9]))

        XCTAssertEqual(result, .failure(.invalidPuzzle))
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

    private static func loadFixtureData(named: String, ext: String) throws -> Data {
        guard let url = Bundle.module.url(forResource: named, withExtension: ext) else {
            throw NSError(domain: "Fixture", code: 1)
        }
        return try Data(contentsOf: url)
    }
}

private final class StubDetector: SudokuBoardDetecting {
    private let result: Result<SudokuBoardDetection, Error>
    private let onDetect: ((Data) -> Void)?

    init(result: Result<SudokuBoardDetection, Error>, onDetect: ((Data) -> Void)? = nil) {
        self.result = result
        self.onDetect = onDetect
    }

    func detectBoard(in imageData: Data) throws -> SudokuBoardDetection {
        onDetect?(imageData)
        return try result.get()
    }
}

private final class StubSlicer: SudokuCellSlicing {
    private let result: Result<[Data], Error>
    private let onSlice: ((Data) -> Void)?

    init(result: Result<[Data], Error>, onSlice: ((Data) -> Void)? = nil) {
        self.result = result
        self.onSlice = onSlice
    }

    func sliceCells(from warpedBoardImageData: Data) throws -> [Data] {
        onSlice?(warpedBoardImageData)
        return try result.get()
    }
}

private final class StubPredictor: SudokuDigitPredicting {
    private let result: Result<[Int], Error>
    private let onPredict: (([Data]) -> Void)?

    init(result: Result<[Int], Error>, onPredict: (([Data]) -> Void)? = nil) {
        self.result = result
        self.onPredict = onPredict
    }

    func predictDigits(in cellImageData: [Data]) throws -> [Int] {
        onPredict?(cellImageData)
        return try result.get()
    }
}
