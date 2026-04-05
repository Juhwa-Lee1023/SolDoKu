import XCTest

final class OCRGuardrailSourceTests: XCTestCase {
    func testPuzzleRecognizerCountsOnlyAcceptedDigits() throws {
        let source = try contents(
            "Sudoku",
            "sudokuCalculation.swift"
        )

        XCTAssertTrue(source.contains("let acceptedDigit = SudokuRecognitionDecisionEngine.acceptedDigit"))
        XCTAssertTrue(source.contains("if cell.acceptedDigit != 0"))
        XCTAssertFalse(source.contains("recognizedCount += 1"))
        XCTAssertFalse(source.contains("guard let hasDigit = visionProcessor.cellHasDigit"))
    }

    func testWrapperUsesSymmetricInsetCropHelper() throws {
        let source = try contents(
            "Sudoku",
            "Wrapper",
            "wrapper.mm"
        )

        XCTAssertTrue(source.contains("cv::Rect symmetricInsetRect"))
        XCTAssertTrue(source.contains("baseRect.width - (inset * 2)"))
        XCTAssertTrue(source.contains("baseRect.height - (inset * 2)"))
    }

    func testCameraLiveOCRRequiresStableRectangle() throws {
        let source = try contents(
            "Sudoku",
            "FeatureCameraSolve",
            "CameraSolveViewModel.swift"
        )

        XCTAssertTrue(source.contains("observation.isStable"))
        XCTAssertTrue(source.contains("observation.boardAreaRatio >= SudokuOCRConfig.Preview.minimumPreviewBoardAreaRatio"))
        XCTAssertTrue(source.contains("guard signature != lastLiveRecognitionSignature else { return }"))
    }

    func testConflictAwareCorrectionAndScoringArePresent() throws {
        let source = try contents(
            "Sudoku",
            "sudokuCalculation.swift"
        )

        XCTAssertTrue(source.contains("static func conflictingCellIndices"))
        XCTAssertTrue(source.contains("func correctionChoices(isConflicting: Bool)"))
        XCTAssertTrue(source.contains("let conflictIndices = SudokuBoardRules.conflictingCellIndices"))
        XCTAssertTrue(source.contains("let conflictCount = SudokuBoardRules.conflictingCellIndices"))
    }

    func testSolvePathAlwaysTriesBoardTextAndConservativeFallbacks() throws {
        let source = try contents(
            "Sudoku",
            "sudokuCalculation.swift"
        )

        XCTAssertTrue(source.contains("guard let boardTextRecognition = boardTextRecognizer.recognizeBoard"))
        XCTAssertFalse(source.contains("let shouldTryBoardText ="))
        XCTAssertTrue(source.contains("let strictRecognition = makeRecognitionConservative(baselineRecognition)"))
    }

    func testBorderTouchingCellsUseInsetRefinement() throws {
        let source = try contents(
            "Sudoku",
            "sudokuCalculation.swift"
        )
        let imageSource = try contents(
            "Sudoku",
            "Extensions",
            "UIImage+.swift"
        )

        XCTAssertTrue(source.contains("let shouldRefineBorderCell = baseAnalysis.touchesBorder"))
        XCTAssertTrue(source.contains("cellImage.insetCropped(ratio: SudokuOCRConfig.Cell.secondaryInsetRatio)"))
        XCTAssertTrue(imageSource.contains("func insetCropped(ratio: CGFloat)"))
    }

    func testWrapperRescuesStrongSmallerBoardCandidates() throws {
        let source = try contents(
            "Sudoku",
            "Wrapper",
            "wrapper.mm"
        )

        XCTAssertTrue(source.contains("minimumRescuableBoardAreaRatio"))
        XCTAssertTrue(source.contains("strongSmallBoardGridConfidence"))
        XCTAssertTrue(source.contains("rescuedCandidateAcceptanceScore"))
    }

    func testBoardTextFallbackNeedsUsableGridOrMeaningfulSupport() throws {
        let source = try contents(
            "Sudoku",
            "sudokuCalculation.swift"
        )

        XCTAssertTrue(source.contains("minimumFallbackGridConfidence"))
        XCTAssertTrue(source.contains("minimumFallbackQualityScore"))
        XCTAssertTrue(source.contains("minimumMeaningfulCellSupport"))
        XCTAssertTrue(source.contains("private func shouldAttemptBoardTextRecognition"))
        XCTAssertTrue(source.contains("meaningfulAcceptedDigitCount(in: baselineRecognition)"))
    }

    private func contents(_ components: String...) throws -> String {
        let path = repositoryRootURL()
            .appendingPathComponent(components.joined(separator: "/"))
        return try String(contentsOf: path, encoding: .utf8)
    }

    private func repositoryRootURL(filePath: StaticString = #filePath) -> URL {
        URL(fileURLWithPath: "\(filePath)")
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }
}
