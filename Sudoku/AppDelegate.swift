//
//  AppDelegate.swift
//  Sudoku
//
//  Created by 이주화 on 2022/09/06.
//

import UIKit

class AppDelegate: UIResponder, UIApplicationDelegate {

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        #if DEBUG
        SudokuDebugImageBatchRunner.launchIfRequested()
        #endif
        return true
    }
}

#if DEBUG
private enum SudokuDebugImageBatchRunner {
    private static let supportedExtensions = Set(["heic", "jpg", "jpeg", "png"])

    static func launchIfRequested() {
        guard ProcessInfo.processInfo.environment["SUDOKU_BATCH_TEST_IMAGES"] == "1" else { return }
        DispatchQueue.main.async {
            run()
        }
    }

    @MainActor
    private static func run() {
        let fileManager = FileManager.default
        guard let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            print("BATCH_TEST|status=no_documents_directory")
            fflush(stdout)
            exit(0)
        }

        let imageURLs = ((try? fileManager.contentsOfDirectory(
            at: documentsURL,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )) ?? [])
            .filter { supportedExtensions.contains($0.pathExtension.lowercased()) }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }

        let visionProcessor = OpenCVSudokuVisionAdapter()
        let puzzleRecognizer = SudokuPuzzleRecognizer(
            visionProcessor: visionProcessor,
            digitPredictor: HybridDigitPredictor()
        )
        let visionOnlyRecognizer = SudokuPuzzleRecognizer(
            visionProcessor: visionProcessor,
            digitPredictor: VisionTextDigitPredictor()
        )
        let boardSolver = LegacySudokuBoardSolver()

        print("BATCH_TEST|documents=\(documentsURL.path)|files=\(imageURLs.count)")

        for imageURL in imageURLs {
            autoreleasepool {
                guard let image = UIImage(contentsOfFile: imageURL.path) else {
                    print("BATCH_TEST|file=\(imageURL.lastPathComponent)|status=load_failed")
                    return
                }

                let normalizedImage = image.fixOrientation()
                if let candidateProvider = visionProcessor as? OpenCVSudokuVisionAdapter {
                    let candidates = candidateProvider.debugRectangleCandidates(in: normalizedImage)
                    let candidateSummary = candidates.prefix(4).enumerated().map { index, candidate in
                        "#\(index):a=\(String(format: "%.3f", Double(candidate.boardAreaRatio)))" +
                        ",q=\(String(format: "%.3f", candidate.qualityScore))" +
                        ",g=\(String(format: "%.3f", candidate.gridConfidence))"
                    }.joined(separator: ";")
                    print(
                        "BATCH_TEST|file=\(imageURL.lastPathComponent)|candidates=\(candidates.count)" +
                        (candidateSummary.isEmpty ? "" : "|summary=\(candidateSummary)")
                    )

                    for (index, candidate) in candidates.prefix(4).enumerated() {
                        let candidateRecognition = puzzleRecognizer.recognizeBoard(
                            from: candidate.warpedImage,
                            imageSize: 64,
                            cutOffset: 6
                        )
                        let candidateSolved = candidateRecognition.flatMap {
                            puzzleRecognizer.solveRecognizedBoard(from: $0, using: boardSolver)
                        } != nil
                        let visionOnlyRecognition = visionOnlyRecognizer.recognizeBoard(
                            from: candidate.warpedImage,
                            imageSize: 64,
                            cutOffset: 6
                        )
                        let visionOnlySolved = visionOnlyRecognition.flatMap {
                            visionOnlyRecognizer.solveRecognizedBoard(from: $0, using: boardSolver)
                        } != nil
                        let recognizedCount = candidateRecognition?.recognizedCount ?? -1
                        let visionOnlyCount = visionOnlyRecognition?.recognizedCount ?? -1
                        print(
                            "BATCH_TEST|file=\(imageURL.lastPathComponent)|candidate_eval=\(index)" +
                            "|recognized=\(recognizedCount)" +
                            "|solved=\(candidateSolved)" +
                            "|vision_recognized=\(visionOnlyCount)" +
                            "|vision_solved=\(visionOnlySolved)"
                        )
                    }
                }

                guard let analysis = puzzleRecognizer.analyzePuzzle(
                    in: normalizedImage,
                    imageSize: 64,
                    cutOffset: 6,
                    using: boardSolver
                ) else {
                    print("BATCH_TEST|file=\(imageURL.lastPathComponent)|status=board_not_detected")
                    return
                }

                let detectedBoard = analysis.detectedBoard
                let recognition = analysis.recognitionResult
                let correction = analysis.correctionResult
                let correctedBoard = correction?.correctedBoard ?? recognition.board
                let correctedCount = correctedBoard.flatMap { $0 }.filter { $0 != 0 }.count
                let meaningfulCount = recognition.cells.filter { $0.analysis?.hasMeaningfulInk == true }.count
                let predictedNonzeroCount = recognition.cells.filter {
                    guard let prediction = $0.prediction else { return false }
                    return (1...9).contains(prediction.digit)
                }.count
                let mediumConfidencePredictionCount = recognition.cells.filter {
                    guard let prediction = $0.prediction else { return false }
                    return (1...9).contains(prediction.digit) && prediction.confidence >= 0.45
                }.count
                let solved = correction != nil

                print(
                    "BATCH_TEST|file=\(imageURL.lastPathComponent)|status=ok" +
                    "|meaningful=\(meaningfulCount)" +
                    "|predicted=\(predictedNonzeroCount)" +
                    "|pred45=\(mediumConfidencePredictionCount)" +
                    "|recognized=\(recognition.recognizedCount)" +
                    "|corrected=\(correctedCount)" +
                    "|solved=\(solved)" +
                    "|area=\(String(format: "%.3f", Double(detectedBoard.boardAreaRatio)))" +
                    "|quality=\(String(format: "%.3f", detectedBoard.qualityScore))" +
                    "|grid=\(String(format: "%.3f", detectedBoard.gridConfidence))"
                )

                if !solved {
                    for (rowIndex, row) in correctedBoard.enumerated() {
                        let rowText = row.map(String.init).joined(separator: ",")
                        print("BATCH_TEST|file=\(imageURL.lastPathComponent)|row=\(rowIndex)|digits=\(rowText)")
                    }

                    let suspiciousCells = recognition.cells
                        .filter { $0.acceptedDigit != 0 }
                        .sorted { lhs, rhs in
                            let lhsScore = suspiciousCellScore(lhs)
                            let rhsScore = suspiciousCellScore(rhs)
                            if lhsScore == rhsScore {
                                return lhs.index < rhs.index
                            }
                            return lhsScore < rhsScore
                        }
                        .prefix(12)

                    for cell in suspiciousCells {
                        let prediction = cell.prediction
                        let analysis = cell.analysis
                        let alternatives = prediction?.alternatives.prefix(2).map {
                            "\($0.digit):\(String(format: "%.2f", $0.confidence))"
                        }.joined(separator: ",") ?? ""
                        print(
                            "BATCH_TEST|file=\(imageURL.lastPathComponent)|cell=\(cell.index)" +
                            "|digit=\(cell.acceptedDigit)" +
                            "|conf=\(String(format: "%.3f", prediction?.confidence ?? 0))" +
                            "|margin=\(String(format: "%.3f", prediction?.marginToNextBestCandidate ?? 0))" +
                            "|blank=\(prediction?.isBlankLikely ?? false)" +
                            "|ink=\(String(format: "%.4f", analysis?.inkRatio ?? 0))" +
                            "|areaRatio=\(String(format: "%.4f", analysis?.componentAreaRatio ?? 0))" +
                            "|centroid=\(String(format: "%.3f", analysis?.centroidDistanceRatio ?? 0))" +
                            "|border=\(analysis?.touchesBorder ?? false)" +
                            (alternatives.isEmpty ? "" : "|alts=\(alternatives)")
                        )
                    }
                }
            }
        }

        fflush(stdout)
        exit(0)
    }
}

private func suspiciousCellScore(_ cell: SudokuRecognizedCell) -> Double {
    let confidence = cell.prediction?.confidence ?? 0
    let margin = cell.prediction?.marginToNextBestCandidate ?? 0
    let ink = cell.analysis?.inkRatio ?? 0
    let areaRatio = cell.analysis?.componentAreaRatio ?? 0
    let borderPenalty = (cell.analysis?.touchesBorder ?? false) ? 0.08 : 0
    return confidence + margin + (ink * 0.8) + (areaRatio * 12.0) - borderPenalty
}
#endif
