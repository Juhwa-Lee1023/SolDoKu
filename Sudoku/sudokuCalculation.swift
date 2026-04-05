import AVFoundation
import CoreML
import Foundation
import Photos
import UIKit
import Vision

enum SudokuOCRConfig {
    enum Cell {
        static let blankInkRatioThreshold = 0.018
        static let minComponentAreaRatio = 0.0022
        static let maxCentroidDistanceRatio = 0.42
        static let secondaryInsetRatio: CGFloat = 0.12
        static let aggressiveBorderCentroidRatio = 0.22
        static let borderRefinementAreaRetention = 0.58
    }

    enum Prediction {
        static let minimumAcceptedConfidence = 0.58
        static let minimumAcceptedMargin = 0.10
        static let strongAcceptedConfidence = 0.82
        static let alternativeCount = 3
    }

    enum VisionFallback {
        static let minimumAcceptedConfidence = 0.45
        static let preferredConfidence = 0.62
        static let maximumCandidates = 3
        static let minimumTextHeight: Float = 0.2
        static let normalizedImageScale: CGFloat = 3.0
    }

    enum Correction {
        static let maximumCells = 6
        static let maximumChoicesPerCell = 2
        static let maximumCombinationCount = 64
        static let iterationLimit = 250_000
        static let lowConfidenceCutoff = 0.84
        static let lowConfidenceMargin = 0.12
        static let blankingMarginCutoff = 0.18
        static let blankingInkRatioThreshold = 0.036
        static let blankingComponentAreaThreshold = 0.005
    }

    enum Preview {
        static let stableFrameCount = 3
        static let maximumCornerDriftRatio: CGFloat = 0.022
        static let maximumAreaRatioDelta: CGFloat = 0.03
        static let minimumPreviewBoardAreaRatio: CGFloat = 0.20
        static let minimumPreviewQualityScore = 0.55
    }

    enum BoardDetection {
        static let maximumVisionRectangleCandidates = 14
        static let maximumCandidatesToEvaluate = 8
        static let minimumRectangleConfidence: Float = 0.45
        static let minimumRectangleSize: Float = 0.05
        static let minimumRectangleAspectRatio: Float = 0.65
        static let quadratureTolerance: Float = 24
        static let suspiciousLargeAreaThreshold: CGFloat = 0.94
    }

    enum BoardText {
        static let minimumAcceptedConfidence = 0.35
        static let preferredConfidence = 0.55
        static let maximumCandidates = 3
        static let minimumTextHeight: Float = 0.008
        static let minimumBoxArea: CGFloat = 0.0002
        static let maximumBoxArea: CGFloat = 0.12
        static let minimumBoxHeight: CGFloat = 0.012
        static let maximumPlausibleRecognizedDigits = 42
        static let minimumFallbackGridConfidence = 0.35
        static let minimumFallbackQualityScore = 0.66
        static let minimumMeaningfulCellSupport = 6
    }
}

enum SudokuSolveError: Error, Equatable {
    case invalidBoard
    case unsolvable
    case iterationLimitExceeded
}

protocol SudokuBoardSolving {
    func solve(board: [[Int]], iterationLimit: Int) -> Result<[[Int]], SudokuSolveError>
}

final class LegacySudokuBoardSolver: SudokuBoardSolving {
    func solve(board: [[Int]], iterationLimit: Int = 1_000_000) -> Result<[[Int]], SudokuSolveError> {
        guard SudokuBoardRules.isBoardValid(board) else {
            return .failure(.invalidBoard)
        }

        var workingBoard = board
        var check = 0
        let solved = solveSudokuInPlace(&workingBoard, 0, 0, &check, iterationLimit)
        if solved {
            return .success(workingBoard)
        }
        if check >= iterationLimit {
            return .failure(.iterationLimitExceeded)
        }
        return .failure(.unsolvable)
    }
}

private enum SudokuBoardRules {
    static func hasValidShape(_ sudoku: [[Int]]) -> Bool {
        guard sudoku.count == 9 else { return false }
        return sudoku.allSatisfy { $0.count == 9 }
    }

    static func isBoardValid(_ sudoku: [[Int]]) -> Bool {
        guard hasValidShape(sudoku) else { return false }

        for row in 0..<9 {
            var rowSeen = Set<Int>()
            var colSeen = Set<Int>()
            for col in 0..<9 {
                let rowValue = sudoku[row][col]
                let colValue = sudoku[col][row]

                if rowValue != 0 {
                    if rowValue < 1 || rowValue > 9 || rowSeen.contains(rowValue) {
                        return false
                    }
                    rowSeen.insert(rowValue)
                }

                if colValue != 0 {
                    if colValue < 1 || colValue > 9 || colSeen.contains(colValue) {
                        return false
                    }
                    colSeen.insert(colValue)
                }
            }
        }

        for boxRow in stride(from: 0, to: 9, by: 3) {
            for boxCol in stride(from: 0, to: 9, by: 3) {
                var boxSeen = Set<Int>()
                for row in boxRow..<(boxRow + 3) {
                    for col in boxCol..<(boxCol + 3) {
                        let value = sudoku[row][col]
                        if value == 0 { continue }
                        if value < 1 || value > 9 || boxSeen.contains(value) {
                            return false
                        }
                        boxSeen.insert(value)
                    }
                }
            }
        }

        return true
    }

    static func isPlacementValid(_ number: Int, _ sudoku: [[Int]], _ row: Int, _ col: Int) -> Bool {
        guard hasValidShape(sudoku) else { return false }
        guard (0..<9).contains(row), (0..<9).contains(col) else { return false }
        guard (1...9).contains(number) else { return false }

        for i in 0..<9 {
            if sudoku[i][col] == number { return false }
            if sudoku[row][i] == number { return false }
        }

        let sectorRow = 3 * Int(row / 3)
        let sectorCol = 3 * Int(col / 3)
        for checkRow in sectorRow..<(sectorRow + 3) {
            for checkCol in sectorCol..<(sectorCol + 3) {
                if sudoku[checkRow][checkCol] == number {
                    return false
                }
            }
        }

        return true
    }

    static func conflictingCellIndices(_ sudoku: [[Int]]) -> Set<Int> {
        guard hasValidShape(sudoku) else { return [] }

        var conflicts = Set<Int>()

        for row in 0..<9 {
            var rowPositions: [Int: [Int]] = [:]
            var colPositions: [Int: [Int]] = [:]

            for col in 0..<9 {
                let rowValue = sudoku[row][col]
                if rowValue != 0 {
                    rowPositions[rowValue, default: []].append((row * 9) + col)
                }

                let colValue = sudoku[col][row]
                if colValue != 0 {
                    colPositions[colValue, default: []].append((col * 9) + row)
                }
            }

            insertConflicts(from: rowPositions, into: &conflicts)
            insertConflicts(from: colPositions, into: &conflicts)
        }

        for boxRow in stride(from: 0, to: 9, by: 3) {
            for boxCol in stride(from: 0, to: 9, by: 3) {
                var boxPositions: [Int: [Int]] = [:]
                for row in boxRow..<(boxRow + 3) {
                    for col in boxCol..<(boxCol + 3) {
                        let value = sudoku[row][col]
                        if value == 0 { continue }
                        boxPositions[value, default: []].append((row * 9) + col)
                    }
                }
                insertConflicts(from: boxPositions, into: &conflicts)
            }
        }

        return conflicts
    }

    private static func insertConflicts(from positions: [Int: [Int]], into conflicts: inout Set<Int>) {
        for indices in positions.values where indices.count > 1 {
            conflicts.formUnion(indices)
        }
    }
}

private func solveSudokuInPlace(
    _ sudoku: inout [[Int]],
    _ row: Int,
    _ col: Int,
    _ check: inout Int,
    _ iterationLimit: Int
) -> Bool {
    if check >= iterationLimit { return false }
    if row == 9 { return SudokuBoardRules.isBoardValid(sudoku) }

    if sudoku[row][col] != 0 {
        if col == 8 {
            check += 1
            if solveSudokuInPlace(&sudoku, row + 1, 0, &check, iterationLimit) {
                return true
            }
        } else {
            check += 1
            if solveSudokuInPlace(&sudoku, row, col + 1, &check, iterationLimit) {
                return true
            }
        }
        return false
    }

    for number in 1..<10 {
        if SudokuBoardRules.isPlacementValid(number, sudoku, row, col) {
            sudoku[row][col] = number
            if col == 8 {
                check += 1
                if solveSudokuInPlace(&sudoku, row + 1, 0, &check, iterationLimit) {
                    return true
                }
            } else {
                check += 1
                if solveSudokuInPlace(&sudoku, row, col + 1, &check, iterationLimit) {
                    return true
                }
            }
            sudoku[row][col] = 0
        }
    }

    return false
}

func isVerify(_ number: Int, _ sudoku: [[Int]], _ row: Int, _ col: Int) -> Bool {
    SudokuBoardRules.isPlacementValid(number, sudoku, row, col)
}

func sudokuCalculation(_ sudoku: inout [[Int]], _ row: Int, _ col: Int, _ check: inout Int) -> Bool {
    solveSudokuInPlace(&sudoku, row, col, &check, 1_000_000)
}

struct OpenCVBoardObservation {
    let corners: [CGPoint]
    let boardAreaRatio: CGFloat
    let qualityScore: Double
    let gridConfidence: Double
}

struct OpenCVDetectedRectangle {
    let corners: [CGPoint]
    let warpedImage: UIImage
    let boardAreaRatio: CGFloat
    let qualityScore: Double
    let gridConfidence: Double
}

struct OpenCVSlicedCells {
    let cellImages: [UIImage]
    let mergedImage: UIImage?
}

struct OpenCVCellAnalysis {
    let hasMeaningfulInk: Bool
    let normalizedDigitImage: UIImage?
    let inkRatio: Double
    let componentAreaRatio: Double
    let centroidDistanceRatio: Double
    let touchesBorder: Bool
}

protocol SudokuVisionProcessing {
    func detectRectangle(in image: UIImage) -> OpenCVDetectedRectangle?
    func detectBoardObservation(in image: UIImage) -> OpenCVBoardObservation?
    func detectCorners(in image: UIImage) -> [CGPoint]?
    func sliceCells(from image: UIImage, imageSize: Int, cutOffset: Int) -> OpenCVSlicedCells?
    func analyzeCell(_ image: UIImage, imageSize: Int) -> OpenCVCellAnalysis?
    func cellHasDigit(_ image: UIImage, imageSize: Int) -> Bool?
}

private protocol SudokuBoardCandidateProviding: SudokuVisionProcessing {
    func detectRectangleCandidates(in image: UIImage) -> [OpenCVDetectedRectangle]
}

private enum VisionRectangleBoardDetector {
    static func detectCandidates(in image: UIImage) -> [[CGPoint]] {
        guard let cgImage = image.cgImage else { return [] }

        let request = VNDetectRectanglesRequest()
        request.maximumObservations = SudokuOCRConfig.BoardDetection.maximumVisionRectangleCandidates
        request.minimumConfidence = SudokuOCRConfig.BoardDetection.minimumRectangleConfidence
        request.minimumSize = SudokuOCRConfig.BoardDetection.minimumRectangleSize
        request.minimumAspectRatio = SudokuOCRConfig.BoardDetection.minimumRectangleAspectRatio
        request.quadratureTolerance = SudokuOCRConfig.BoardDetection.quadratureTolerance

        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        do {
            try handler.perform([request])
        } catch {
            return []
        }

        return (request.results ?? []).map { observation in
            [
                imagePoint(for: observation.topLeft, imageSize: image.size),
                imagePoint(for: observation.topRight, imageSize: image.size),
                imagePoint(for: observation.bottomRight, imageSize: image.size),
                imagePoint(for: observation.bottomLeft, imageSize: image.size),
            ]
        }
    }

    private static func imagePoint(for normalizedPoint: CGPoint, imageSize: CGSize) -> CGPoint {
        CGPoint(
            x: normalizedPoint.x * imageSize.width,
            y: (1.0 - normalizedPoint.y) * imageSize.height
        )
    }
}

private enum SudokuBoardCandidateRanker {
    static func sort(_ candidates: [OpenCVDetectedRectangle]) -> [OpenCVDetectedRectangle] {
        candidates.sorted { lhs, rhs in
            let lhsScore = prioritizationScore(for: lhs)
            let rhsScore = prioritizationScore(for: rhs)
            if lhsScore == rhsScore {
                return lhs.qualityScore > rhs.qualityScore
            }
            return lhsScore > rhsScore
        }
    }

    private static func prioritizationScore(for candidate: OpenCVDetectedRectangle) -> Double {
        let suspiciousLargeAreaPenalty: Double
        if candidate.boardAreaRatio > SudokuOCRConfig.BoardDetection.suspiciousLargeAreaThreshold,
           candidate.gridConfidence < 0.55 {
            suspiciousLargeAreaPenalty = Double(candidate.boardAreaRatio - SudokuOCRConfig.BoardDetection.suspiciousLargeAreaThreshold) * 4.0
        } else {
            suspiciousLargeAreaPenalty = 0
        }

        return candidate.qualityScore
            + (candidate.gridConfidence * 0.9)
            - suspiciousLargeAreaPenalty
    }

    static func deduplicate(_ candidates: [OpenCVDetectedRectangle]) -> [OpenCVDetectedRectangle] {
        var seen = Set<String>()
        return candidates.filter { candidate in
            let signature = candidate.corners
                .map { "\(Int($0.x.rounded() / 12))x\(Int($0.y.rounded() / 12))" }
                .joined(separator: "|") + "|\(Int((candidate.boardAreaRatio * 100).rounded()))"
            return seen.insert(signature).inserted
        }
    }
}

final class OpenCVSudokuVisionAdapter: SudokuBoardCandidateProviding {
    func detectRectangle(in image: UIImage) -> OpenCVDetectedRectangle? {
        detectRectangleCandidates(in: image).first
    }

    func detectBoardObservation(in image: UIImage) -> OpenCVBoardObservation? {
        let normalizedImage = image.fixOrientation()
        guard let payload = wrapper.detectRect(normalizedImage) else {
            return nil
        }
        return Self.parseBoardObservation(payload)
    }

    func detectCorners(in image: UIImage) -> [CGPoint]? {
        detectBoardObservation(in: image)?.corners
    }

    func sliceCells(from image: UIImage, imageSize: Int = 64, cutOffset: Int = 0) -> OpenCVSlicedCells? {
        let normalizedImage = image.fixOrientation()
        guard let sliceResult = wrapper.sliceImages(normalizedImage, imageSize: Int32(imageSize), cutOffset: Int32(cutOffset)) as? [Any],
              sliceResult.count >= 2,
              let cellImages = sliceResult[0] as? [UIImage] else {
            return nil
        }
        let mergedImage = sliceResult[1] as? UIImage
        return OpenCVSlicedCells(cellImages: cellImages, mergedImage: mergedImage)
    }

    func analyzeCell(_ image: UIImage, imageSize: Int = 64) -> OpenCVCellAnalysis? {
        let normalizedImage = image.fixOrientation()
        guard let payload = wrapper.analyzeCell(normalizedImage, imageSize: Int32(imageSize)) else {
            return nil
        }

        return OpenCVCellAnalysis(
            hasMeaningfulInk: (payload["hasMeaningfulInk"] as? NSNumber)?.boolValue ?? false,
            normalizedDigitImage: payload["normalizedDigitImage"] as? UIImage,
            inkRatio: (payload["inkRatio"] as? NSNumber)?.doubleValue ?? 0,
            componentAreaRatio: (payload["componentAreaRatio"] as? NSNumber)?.doubleValue ?? 0,
            centroidDistanceRatio: (payload["centroidDistanceRatio"] as? NSNumber)?.doubleValue ?? 1,
            touchesBorder: (payload["touchesBorder"] as? NSNumber)?.boolValue ?? false
        )
    }

    func cellHasDigit(_ image: UIImage, imageSize: Int = 64) -> Bool? {
        analyzeCell(image, imageSize: imageSize)?.hasMeaningfulInk
    }

    fileprivate func detectRectangleCandidates(in image: UIImage) -> [OpenCVDetectedRectangle] {
        let normalizedImage = image.fixOrientation()
        var candidates: [OpenCVDetectedRectangle] = []

        if let payload = wrapper.detectRectangle(normalizedImage),
           let candidate = Self.parseDetectedRectangle(payload) {
            candidates.append(candidate)
        }

        let visionCandidates = VisionRectangleBoardDetector.detectCandidates(in: normalizedImage).compactMap { corners -> OpenCVDetectedRectangle? in
            let values = corners.map(NSValue.init(cgPoint:))
            guard let payload = wrapper.warpBoard(normalizedImage, corners: values) else {
                return nil
            }
            return Self.parseDetectedRectangle(payload)
        }
        candidates.append(contentsOf: visionCandidates)

        return SudokuBoardCandidateRanker.sort(SudokuBoardCandidateRanker.deduplicate(candidates))
    }

    func debugRectangleCandidates(in image: UIImage) -> [OpenCVDetectedRectangle] {
        detectRectangleCandidates(in: image)
    }

    private static func parseBoardObservation(_ payload: [AnyHashable: Any]) -> OpenCVBoardObservation? {
        guard let corners = payload["corners"] as? [NSValue], corners.count >= 4 else {
            return nil
        }

        return OpenCVBoardObservation(
            corners: Array(corners.prefix(4)).map(\.cgPointValue),
            boardAreaRatio: CGFloat((payload["boardAreaRatio"] as? NSNumber)?.doubleValue ?? 0),
            qualityScore: (payload["qualityScore"] as? NSNumber)?.doubleValue ?? 0,
            gridConfidence: (payload["gridConfidence"] as? NSNumber)?.doubleValue ?? 0
        )
    }

    private static func parseDetectedRectangle(_ payload: [AnyHashable: Any]) -> OpenCVDetectedRectangle? {
        guard let observation = parseBoardObservation(payload),
              let warpedImage = payload["warpedImage"] as? UIImage else {
            return nil
        }

        return OpenCVDetectedRectangle(
            corners: observation.corners,
            warpedImage: warpedImage.fixOrientation(),
            boardAreaRatio: observation.boardAreaRatio,
            qualityScore: observation.qualityScore,
            gridConfidence: observation.gridConfidence
        )
    }
}

struct DigitPredictionAlternative: Equatable {
    let digit: Int
    let confidence: Double
}

struct DigitPrediction: Equatable {
    let digit: Int
    let confidence: Double
    let alternatives: [DigitPredictionAlternative]
    let isBlankLikely: Bool

    var marginToNextBestCandidate: Double {
        confidence - (alternatives.first?.confidence ?? 0)
    }
}

protocol SudokuDigitPredicting {
    func predictDigit(from image: UIImage) -> DigitPrediction?
}

final class CoreMLDigitPredictor: SudokuDigitPredicting {
    func predictDigit(from image: UIImage) -> DigitPrediction? {
        guard let buffer = image.UIImageToPixelBuffer() else { return nil }
        let configuration = MLModelConfiguration()
        guard let model = try? model_64(configuration: configuration),
              let prediction = try? model.prediction(x: buffer) else { return nil }

        let scoresCount = prediction.y.count
        let scoresPointer = prediction.y.dataPointer.bindMemory(to: Double.self, capacity: scoresCount)
        let scoreBuffer = UnsafeBufferPointer(start: scoresPointer, count: scoresCount)
        let scores = Array(scoreBuffer)
        guard !scores.isEmpty else { return nil }

        let normalizedScores = Self.normalizeScores(scores)
        let ranked = normalizedScores.enumerated().sorted { lhs, rhs in
            if lhs.element == rhs.element {
                return lhs.offset < rhs.offset
            }
            return lhs.element > rhs.element
        }
        guard let top = ranked.first else { return nil }

        let alternatives = ranked
            .dropFirst()
            .prefix(SudokuOCRConfig.Prediction.alternativeCount)
            .map { DigitPredictionAlternative(digit: $0.offset, confidence: $0.element) }

        let margin = top.element - (alternatives.first?.confidence ?? 0)
        let isBlankLikely = top.offset == 0
            || top.element < SudokuOCRConfig.Prediction.minimumAcceptedConfidence
            || margin < SudokuOCRConfig.Prediction.minimumAcceptedMargin

        return DigitPrediction(
            digit: top.offset,
            confidence: top.element,
            alternatives: alternatives,
            isBlankLikely: isBlankLikely
        )
    }

    private static func normalizeScores(_ values: [Double]) -> [Double] {
        if areProbabilities(values) {
            let sum = values.reduce(0.0, +)
            guard sum > 0 else { return values }
            return values.map { $0 / sum }
        }

        if values.allSatisfy({ $0 >= 0 }) {
            let sum = values.reduce(0.0, +)
            if sum > 0 {
                return values.map { $0 / sum }
            }
        }

        return softmax(values)
    }

    private static func areProbabilities(_ values: [Double]) -> Bool {
        guard !values.isEmpty else { return false }
        guard values.allSatisfy({ (0...1).contains($0) }) else { return false }
        let sum = values.reduce(0.0, +)
        return (0.95...1.05).contains(sum)
    }

    private static func softmax(_ values: [Double]) -> [Double] {
        guard let maximumValue = values.max() else { return [] }
        let shifted = values.map { exp($0 - maximumValue) }
        let denominator = shifted.reduce(0.0, +)
        guard denominator > 0 else { return Array(repeating: 0, count: values.count) }
        return shifted.map { $0 / denominator }
    }
}

private enum VisionDigitPredictionParser {
    static func parseDigitCandidate(_ candidate: VNRecognizedText) -> DigitPredictionAlternative? {
        let trimmed = candidate.string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return nil
        }

        let mappedDigits = trimmed.compactMap { character -> Int? in
            switch character {
            case "1", "2", "3", "4", "5", "6", "7", "8", "9":
                return Int(String(character))
            case "I", "l", "|":
                return 1
            case "S", "s":
                return 5
            default:
                return nil
            }
        }

        let uniqueDigits = Array(Set(mappedDigits)).sorted()
        guard uniqueDigits.count == 1, let digit = uniqueDigits.first, (1...9).contains(digit) else {
            return nil
        }

        return DigitPredictionAlternative(digit: digit, confidence: Double(candidate.confidence))
    }
}

final class VisionTextDigitPredictor: SudokuDigitPredicting {
    func predictDigit(from image: UIImage) -> DigitPrediction? {
        guard let cgImage = upscaledCGImage(from: image) else { return nil }

        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = false
        request.minimumTextHeight = SudokuOCRConfig.VisionFallback.minimumTextHeight

        let handler = VNImageRequestHandler(
            cgImage: cgImage,
            orientation: cgImageOrientation(for: image.imageOrientation),
            options: [:]
        )

        do {
            try handler.perform([request])
        } catch {
            return nil
        }

        let digitCandidates = (request.results ?? [])
            .flatMap { observation in
                observation.topCandidates(SudokuOCRConfig.VisionFallback.maximumCandidates).compactMap {
                    VisionDigitPredictionParser.parseDigitCandidate($0)
                }
            }
            .sorted {
                if $0.confidence == $1.confidence {
                    return $0.digit < $1.digit
                }
                return $0.confidence > $1.confidence
            }

        guard let top = digitCandidates.first else { return nil }
        let alternatives = digitCandidates
            .dropFirst()
            .prefix(SudokuOCRConfig.Prediction.alternativeCount)
            .map { DigitPredictionAlternative(digit: $0.digit, confidence: $0.confidence) }

        return DigitPrediction(
            digit: top.digit,
            confidence: top.confidence,
            alternatives: alternatives,
            isBlankLikely: top.confidence < SudokuOCRConfig.VisionFallback.minimumAcceptedConfidence
        )
    }

    private func upscaledCGImage(from image: UIImage) -> CGImage? {
        let targetSize = CGSize(
            width: max(image.size.width, 1) * SudokuOCRConfig.VisionFallback.normalizedImageScale,
            height: max(image.size.height, 1) * SudokuOCRConfig.VisionFallback.normalizedImageScale
        )
        let renderer = UIGraphicsImageRenderer(size: targetSize)
        let renderedImage = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }
        return renderedImage.cgImage ?? image.cgImage
    }

    private func cgImageOrientation(for orientation: UIImage.Orientation) -> CGImagePropertyOrientation {
        switch orientation {
        case .up: return .up
        case .down: return .down
        case .left: return .left
        case .right: return .right
        case .upMirrored: return .upMirrored
        case .downMirrored: return .downMirrored
        case .leftMirrored: return .leftMirrored
        case .rightMirrored: return .rightMirrored
        @unknown default: return .up
        }
    }
}

final class HybridDigitPredictor: SudokuDigitPredicting {
    private let primary: SudokuDigitPredicting
    private let fallback: SudokuDigitPredicting

    init(
        primary: SudokuDigitPredicting = CoreMLDigitPredictor(),
        fallback: SudokuDigitPredicting = VisionTextDigitPredictor()
    ) {
        self.primary = primary
        self.fallback = fallback
    }

    func predictDigit(from image: UIImage) -> DigitPrediction? {
        let primaryPrediction = primary.predictDigit(from: image)
        guard shouldConsultFallback(for: primaryPrediction) else {
            return primaryPrediction
        }

        guard let fallbackPrediction = fallback.predictDigit(from: image) else {
            return primaryPrediction
        }

        return choosePreferredPrediction(primary: primaryPrediction, fallback: fallbackPrediction)
    }

    private func shouldConsultFallback(for prediction: DigitPrediction?) -> Bool {
        guard let prediction else { return true }
        if !(1...9).contains(prediction.digit) { return true }
        if prediction.isBlankLikely { return true }
        if prediction.confidence < SudokuOCRConfig.Prediction.strongAcceptedConfidence { return true }
        return prediction.marginToNextBestCandidate < SudokuOCRConfig.Prediction.minimumAcceptedMargin
    }

    private func choosePreferredPrediction(
        primary: DigitPrediction?,
        fallback: DigitPrediction
    ) -> DigitPrediction {
        guard let primary else { return fallback }

        let fallbackStrongEnough = fallback.confidence >= SudokuOCRConfig.VisionFallback.minimumAcceptedConfidence
        let primaryWeak = primary.isBlankLikely
            || !(1...9).contains(primary.digit)
            || primary.confidence < SudokuOCRConfig.Prediction.minimumAcceptedConfidence
            || primary.marginToNextBestCandidate < SudokuOCRConfig.Prediction.minimumAcceptedMargin

        if fallbackStrongEnough && (primaryWeak || fallback.confidence >= SudokuOCRConfig.VisionFallback.preferredConfidence) {
            return mergePredictions(preferred: fallback, secondary: primary)
        }

        return mergePredictions(preferred: primary, secondary: fallback)
    }

    private func mergePredictions(preferred: DigitPrediction, secondary: DigitPrediction) -> DigitPrediction {
        var alternativeByDigit: [Int: Double] = [:]

        for alternative in preferred.alternatives {
            alternativeByDigit[alternative.digit] = max(alternative.confidence, alternativeByDigit[alternative.digit] ?? 0)
        }

        if secondary.digit != preferred.digit {
            alternativeByDigit[secondary.digit] = max(secondary.confidence, alternativeByDigit[secondary.digit] ?? 0)
        }

        for alternative in secondary.alternatives where alternative.digit != preferred.digit {
            alternativeByDigit[alternative.digit] = max(alternative.confidence, alternativeByDigit[alternative.digit] ?? 0)
        }

        let mergedAlternatives = alternativeByDigit
            .map { DigitPredictionAlternative(digit: $0.key, confidence: $0.value) }
            .sorted {
                if $0.confidence == $1.confidence {
                    return $0.digit < $1.digit
                }
                return $0.confidence > $1.confidence
            }
            .prefix(SudokuOCRConfig.Prediction.alternativeCount)

        return DigitPrediction(
            digit: preferred.digit,
            confidence: preferred.confidence,
            alternatives: Array(mergedAlternatives),
            isBlankLikely: preferred.isBlankLikely && secondary.isBlankLikely
        )
    }
}

private final class VisionBoardTextRecognizer {
    func recognizeBoard(from image: UIImage) -> SudokuRecognitionResult? {
        let normalizedImage = image.fixOrientation()
        guard let cgImage = normalizedImage.cgImage else { return nil }

        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = false
        request.minimumTextHeight = SudokuOCRConfig.BoardText.minimumTextHeight

        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        do {
            try handler.perform([request])
        } catch {
            return nil
        }

        var predictionsByCell: [Int: DigitPrediction] = [:]
        for observation in request.results ?? [] {
            let box = observation.boundingBox
            let boxArea = box.width * box.height
            guard boxArea >= SudokuOCRConfig.BoardText.minimumBoxArea,
                  boxArea <= SudokuOCRConfig.BoardText.maximumBoxArea,
                  box.height >= SudokuOCRConfig.BoardText.minimumBoxHeight else {
                continue
            }

            let candidates = observation.topCandidates(SudokuOCRConfig.BoardText.maximumCandidates).compactMap {
                VisionDigitPredictionParser.parseDigitCandidate($0)
            }
            guard let top = candidates.first else { continue }

            let alternatives = candidates.dropFirst().prefix(SudokuOCRConfig.Prediction.alternativeCount)
            let centerX = box.midX
            let centerY = 1.0 - box.midY
            let col = min(max(Int(centerX * 9.0), 0), 8)
            let row = min(max(Int(centerY * 9.0), 0), 8)
            let cellIndex = (row * 9) + col

            let prediction = DigitPrediction(
                digit: top.digit,
                confidence: top.confidence,
                alternatives: Array(alternatives),
                isBlankLikely: top.confidence < SudokuOCRConfig.BoardText.minimumAcceptedConfidence
            )

            if let existing = predictionsByCell[cellIndex], existing.confidence >= prediction.confidence {
                continue
            }
            predictionsByCell[cellIndex] = prediction
        }

        guard !predictionsByCell.isEmpty else { return nil }

        var board = Array(repeating: Array(repeating: 0, count: 9), count: 9)
        var cells: [SudokuRecognizedCell] = []
        cells.reserveCapacity(81)

        for index in 0..<81 {
            let prediction = predictionsByCell[index]
            let acceptedDigit: Int
            if let prediction,
               prediction.confidence >= SudokuOCRConfig.BoardText.minimumAcceptedConfidence,
               (1...9).contains(prediction.digit) {
                acceptedDigit = prediction.digit
            } else {
                acceptedDigit = 0
            }

            board[index / 9][index % 9] = acceptedDigit
            cells.append(
                SudokuRecognizedCell(
                    index: index,
                    analysis: nil,
                    prediction: prediction,
                    acceptedDigit: acceptedDigit
                )
            )
        }

        let recognizedCount = board.flatMap { $0 }.filter { $0 != 0 }.count
        return SudokuRecognitionResult(board: board, recognizedCount: recognizedCount, cells: cells)
    }
}

struct SudokuRecognizedCell {
    let index: Int
    let analysis: OpenCVCellAnalysis?
    let prediction: DigitPrediction?
    let acceptedDigit: Int

    var row: Int { index / 9 }
    var col: Int { index % 9 }

    func correctionChoices(isConflicting: Bool) -> [Int] {
        guard acceptedDigit != 0 else { return [] }

        var digits: [Int] = [acceptedDigit]
        if let alternative = preferredCorrectionAlternative(isConflicting: isConflicting),
           !digits.contains(alternative) {
            digits.append(alternative)
        }

        return Array(digits.prefix(SudokuOCRConfig.Correction.maximumChoicesPerCell))
    }

    func shouldParticipateInCorrection(isConflicting: Bool) -> Bool {
        guard acceptedDigit != 0 else { return false }
        guard correctionChoices(isConflicting: isConflicting).count > 1 else { return false }
        if isConflicting { return true }
        if let analysis {
            if analysis.inkRatio < 0.028 || analysis.componentAreaRatio < 0.0032 {
                return true
            }
            if analysis.touchesBorder && analysis.centroidDistanceRatio > 0.22 {
                return true
            }
        }
        guard let prediction else { return false }
        return prediction.confidence < SudokuOCRConfig.Correction.lowConfidenceCutoff
            || prediction.marginToNextBestCandidate < SudokuOCRConfig.Correction.lowConfidenceMargin
            || prediction.isBlankLikely
    }

    func correctionPriority(isConflicting: Bool) -> Double {
        guard let prediction else { return isConflicting ? 0.45 : 1 }
        let ambiguityPenalty = max(0, SudokuOCRConfig.Correction.lowConfidenceMargin - prediction.marginToNextBestCandidate)
        let conflictPenalty = isConflicting ? 0.24 : 0
        let weakInkPenalty: Double
        if let analysis {
            weakInkPenalty = max(0, 0.03 - analysis.inkRatio) * 2.5
        } else {
            weakInkPenalty = 0
        }
        return prediction.confidence - ambiguityPenalty - conflictPenalty - weakInkPenalty
    }

    private var shouldConsiderBlankDuringCorrection: Bool {
        guard let prediction else { return false }
        if prediction.isBlankLikely { return true }
        if prediction.confidence < SudokuOCRConfig.Correction.lowConfidenceCutoff { return true }
        if prediction.marginToNextBestCandidate < SudokuOCRConfig.Correction.blankingMarginCutoff { return true }
        if let analysis {
            if analysis.inkRatio < SudokuOCRConfig.Correction.blankingInkRatioThreshold { return true }
            if analysis.componentAreaRatio < SudokuOCRConfig.Correction.blankingComponentAreaThreshold { return true }
            if analysis.touchesBorder && analysis.centroidDistanceRatio > 0.22 { return true }
        }
        return false
    }

    private func preferredCorrectionAlternative(isConflicting: Bool) -> Int? {
        var candidates: [(digit: Int, score: Double)] = []

        if isConflicting || shouldConsiderBlankDuringCorrection {
            candidates.append((digit: 0, score: blankAlternativeScore(isConflicting: isConflicting)))
        }

        if let prediction {
            for alternative in prediction.alternatives where (1...9).contains(alternative.digit) {
                guard alternative.digit != acceptedDigit else { continue }
                candidates.append(
                    (digit: alternative.digit, score: digitAlternativeScore(alternative, isConflicting: isConflicting))
                )
            }
        }

        return candidates
            .sorted {
                if $0.score == $1.score {
                    return $0.digit < $1.digit
                }
                return $0.score > $1.score
            }
            .first?.digit
    }

    private func blankAlternativeScore(isConflicting: Bool) -> Double {
        var score = isConflicting ? 0.78 : 0.50

        if let prediction {
            if prediction.isBlankLikely { score += 0.18 }
            if prediction.confidence < SudokuOCRConfig.Correction.lowConfidenceCutoff { score += 0.16 }
            if prediction.marginToNextBestCandidate < SudokuOCRConfig.Correction.blankingMarginCutoff { score += 0.12 }
        } else {
            score += 0.12
        }

        if let analysis {
            if analysis.inkRatio < SudokuOCRConfig.Correction.blankingInkRatioThreshold { score += 0.12 }
            if analysis.componentAreaRatio < SudokuOCRConfig.Correction.blankingComponentAreaThreshold { score += 0.08 }
            if analysis.touchesBorder { score += 0.08 }
            if analysis.touchesBorder && analysis.centroidDistanceRatio > 0.22 { score += 0.12 }
        }

        return score
    }

    private func digitAlternativeScore(_ alternative: DigitPredictionAlternative, isConflicting: Bool) -> Double {
        var score = alternative.confidence
        if isConflicting { score += 0.05 }
        if let analysis {
            score += min(analysis.inkRatio * 0.45, 0.08)
            if analysis.touchesBorder { score -= 0.05 }
        }
        return score
    }
}

struct SudokuRecognitionResult {
    let board: [[Int]]
    let recognizedCount: Int
    let cells: [SudokuRecognizedCell]
}

struct SudokuCorrectionResult {
    let correctedBoard: [[Int]]
    let solvedBoard: [[Int]]
}

struct SudokuPuzzleAnalysis {
    let detectedBoard: OpenCVDetectedRectangle
    let recognitionResult: SudokuRecognitionResult
    let correctionResult: SudokuCorrectionResult?
}

private enum SudokuRecognitionDecisionEngine {
    static func acceptedDigit(from analysis: OpenCVCellAnalysis?, prediction: DigitPrediction?) -> Int {
        guard let analysis, analysis.hasMeaningfulInk else { return 0 }
        guard analysis.inkRatio >= SudokuOCRConfig.Cell.blankInkRatioThreshold else { return 0 }
        guard analysis.componentAreaRatio >= SudokuOCRConfig.Cell.minComponentAreaRatio else { return 0 }
        guard !(analysis.touchesBorder && analysis.centroidDistanceRatio > SudokuOCRConfig.Cell.maxCentroidDistanceRatio) else {
            return 0
        }

        guard let prediction else { return 0 }
        guard (1...9).contains(prediction.digit) else { return 0 }
        guard prediction.confidence >= SudokuOCRConfig.Prediction.minimumAcceptedConfidence else { return 0 }

        let margin = prediction.marginToNextBestCandidate
        if prediction.isBlankLikely && prediction.confidence < SudokuOCRConfig.Prediction.strongAcceptedConfidence {
            return 0
        }
        if margin < SudokuOCRConfig.Prediction.minimumAcceptedMargin
            && prediction.confidence < SudokuOCRConfig.Prediction.strongAcceptedConfidence {
            return 0
        }

        return prediction.digit
    }
}

private enum SudokuSolverAssistedCorrection {
    static func solveIfNeeded(
        from recognitionResult: SudokuRecognitionResult,
        using boardSolver: SudokuBoardSolving
    ) -> SudokuCorrectionResult? {
        let conflictIndices = SudokuBoardRules.conflictingCellIndices(recognitionResult.board)
        let candidates = recognitionResult.cells
            .filter {
                let isConflicting = conflictIndices.contains($0.index)
                return $0.shouldParticipateInCorrection(isConflicting: isConflicting)
            }
            .sorted {
                let lhsPriority = $0.correctionPriority(isConflicting: conflictIndices.contains($0.index))
                let rhsPriority = $1.correctionPriority(isConflicting: conflictIndices.contains($1.index))
                if lhsPriority == rhsPriority {
                    return $0.index < $1.index
                }
                return lhsPriority < rhsPriority
            }
            .prefix(SudokuOCRConfig.Correction.maximumCells)

        let correctionCandidates = Array(candidates)
        guard !correctionCandidates.isEmpty else { return nil }

        let combinationLimit = min(
            SudokuOCRConfig.Correction.maximumCombinationCount,
            1 << correctionCandidates.count
        )

        for changeCount in 1...correctionCandidates.count {
            for mask in 1..<combinationLimit where mask.nonzeroBitCount == changeCount {
                var candidateBoard = recognitionResult.board

                for (candidateIndex, candidate) in correctionCandidates.enumerated() {
                    let choices = candidate.correctionChoices(
                        isConflicting: conflictIndices.contains(candidate.index)
                    )
                    guard choices.count > 1 else { continue }
                    let useAlternative = ((mask >> candidateIndex) & 1) == 1
                    candidateBoard[candidate.row][candidate.col] = useAlternative ? choices[1] : choices[0]
                }

                switch boardSolver.solve(
                    board: candidateBoard,
                    iterationLimit: SudokuOCRConfig.Correction.iterationLimit
                ) {
                case .success(let solvedBoard):
                    return SudokuCorrectionResult(correctedBoard: candidateBoard, solvedBoard: solvedBoard)
                case .failure:
                    continue
                }
            }
        }

        return nil
    }
}

protocol SudokuPuzzleRecognizing {
    func recognizeBoard(from image: UIImage, imageSize: Int, cutOffset: Int) -> SudokuRecognitionResult?
    func solveRecognizedBoard(
        from recognitionResult: SudokuRecognitionResult,
        using boardSolver: SudokuBoardSolving
    ) -> SudokuCorrectionResult?
    func analyzePuzzle(
        in image: UIImage,
        imageSize: Int,
        cutOffset: Int,
        using boardSolver: SudokuBoardSolving
    ) -> SudokuPuzzleAnalysis?
}

final class SudokuPuzzleRecognizer: SudokuPuzzleRecognizing {
    private let visionProcessor: SudokuVisionProcessing
    private let digitPredictor: SudokuDigitPredicting
    private let boardTextRecognizer = VisionBoardTextRecognizer()

    init(
        visionProcessor: SudokuVisionProcessing = OpenCVSudokuVisionAdapter(),
        digitPredictor: SudokuDigitPredicting = HybridDigitPredictor()
    ) {
        self.visionProcessor = visionProcessor
        self.digitPredictor = digitPredictor
    }

    func recognizeBoard(from image: UIImage, imageSize: Int = 64, cutOffset: Int = 0) -> SudokuRecognitionResult? {
        guard let slicedCells = visionProcessor.sliceCells(from: image, imageSize: imageSize, cutOffset: cutOffset),
              slicedCells.cellImages.count == 81 else {
            return nil
        }

        var board = Array(repeating: Array(repeating: 0, count: 9), count: 9)
        var cells: [SudokuRecognizedCell] = []
        cells.reserveCapacity(81)

        for (index, cellImage) in slicedCells.cellImages.enumerated() {
            let interpretation = interpretCell(cellImage, imageSize: imageSize)
            let analysis = interpretation.analysis
            let prediction = interpretation.prediction
            let acceptedDigit = SudokuRecognitionDecisionEngine.acceptedDigit(from: analysis, prediction: prediction)

            board[index / 9][index % 9] = acceptedDigit
            cells.append(
                SudokuRecognizedCell(
                    index: index,
                    analysis: analysis,
                    prediction: prediction,
                    acceptedDigit: acceptedDigit
                )
            )
        }

        let recognizedCount = cells.reduce(into: 0) { partialResult, cell in
            if cell.acceptedDigit != 0 {
                partialResult += 1
            }
        }

        return SudokuRecognitionResult(
            board: board,
            recognizedCount: recognizedCount,
            cells: cells
        )
    }

    private func interpretCell(_ cellImage: UIImage, imageSize: Int) -> (analysis: OpenCVCellAnalysis?, prediction: DigitPrediction?) {
        let baseAnalysis = visionProcessor.analyzeCell(cellImage, imageSize: imageSize)
        let basePrediction = prediction(for: baseAnalysis, cellImage: cellImage)

        guard let baseAnalysis, baseAnalysis.hasMeaningfulInk else {
            return (baseAnalysis, nil)
        }

        let shouldRefineBorderCell = baseAnalysis.touchesBorder
            || baseAnalysis.centroidDistanceRatio >= SudokuOCRConfig.Cell.aggressiveBorderCentroidRatio
        guard shouldRefineBorderCell,
              let tightenedImage = cellImage.insetCropped(ratio: SudokuOCRConfig.Cell.secondaryInsetRatio) else {
            return (baseAnalysis, basePrediction)
        }

        let tightenedAnalysis = visionProcessor.analyzeCell(tightenedImage, imageSize: imageSize)
        let tightenedPrediction = prediction(for: tightenedAnalysis, cellImage: tightenedImage)
        return chooseCellInterpretation(
            base: (baseAnalysis, basePrediction),
            tightened: (tightenedAnalysis, tightenedPrediction)
        )
    }

    private func prediction(for analysis: OpenCVCellAnalysis?, cellImage: UIImage) -> DigitPrediction? {
        guard analysis?.hasMeaningfulInk == true else { return nil }
        let predictionImage = analysis?.normalizedDigitImage ?? cellImage
        return digitPredictor.predictDigit(from: predictionImage)
    }

    private func chooseCellInterpretation(
        base: (analysis: OpenCVCellAnalysis, prediction: DigitPrediction?),
        tightened: (analysis: OpenCVCellAnalysis?, prediction: DigitPrediction?)
    ) -> (analysis: OpenCVCellAnalysis?, prediction: DigitPrediction?) {
        guard let tightenedAnalysis = tightened.analysis, tightenedAnalysis.hasMeaningfulInk else {
            if base.analysis.touchesBorder {
                return (tightened.analysis, nil)
            }
            return base
        }

        let tightenedRetainsEnoughArea =
            tightenedAnalysis.componentAreaRatio >= base.analysis.componentAreaRatio * SudokuOCRConfig.Cell.borderRefinementAreaRetention
        let tightenedLooksCleaner =
            (!tightenedAnalysis.touchesBorder && base.analysis.touchesBorder)
            || (tightenedAnalysis.centroidDistanceRatio + 0.08 < base.analysis.centroidDistanceRatio)
            || (tightenedRetainsEnoughArea && tightenedAnalysis.inkRatio + 0.01 < base.analysis.inkRatio)

        if tightenedLooksCleaner {
            return (tightenedAnalysis, tightened.prediction)
        }

        if let basePrediction = base.prediction,
           let tightenedPrediction = tightened.prediction,
           basePrediction.digit != tightenedPrediction.digit {
            let tightenedSupportedByGeometry =
                tightenedRetainsEnoughArea
                && tightenedAnalysis.centroidDistanceRatio <= base.analysis.centroidDistanceRatio
            if tightenedSupportedByGeometry
                && tightenedPrediction.confidence + 0.02 >= basePrediction.confidence {
                return (tightenedAnalysis, tightenedPrediction)
            }
        }

        return base
    }

    func solveRecognizedBoard(
        from recognitionResult: SudokuRecognitionResult,
        using boardSolver: SudokuBoardSolving
    ) -> SudokuCorrectionResult? {
        guard recognitionResult.recognizedCount >= 17 else {
            return nil
        }

        switch boardSolver.solve(board: recognitionResult.board, iterationLimit: 1_000_000) {
        case .success(let solvedBoard):
            return SudokuCorrectionResult(correctedBoard: recognitionResult.board, solvedBoard: solvedBoard)
        case .failure(.invalidBoard), .failure(.unsolvable):
            return SudokuSolverAssistedCorrection.solveIfNeeded(from: recognitionResult, using: boardSolver)
        case .failure(.iterationLimitExceeded):
            return nil
        }
    }

    func analyzePuzzle(
        in image: UIImage,
        imageSize: Int = 64,
        cutOffset: Int = 0,
        using boardSolver: SudokuBoardSolving
    ) -> SudokuPuzzleAnalysis? {
        let normalizedImage = image.fixOrientation()
        let candidates: [OpenCVDetectedRectangle]
        if let provider = visionProcessor as? SudokuBoardCandidateProviding {
            candidates = provider.detectRectangleCandidates(in: normalizedImage)
        } else if let candidate = visionProcessor.detectRectangle(in: normalizedImage) {
            candidates = [candidate]
        } else {
            return nil
        }

        var bestAnalysis: SudokuPuzzleAnalysis?
        var bestScore = -Double.infinity

        for candidate in candidates.prefix(SudokuOCRConfig.BoardDetection.maximumCandidatesToEvaluate) {
            guard let recognitionResult = recognizeBoard(
                from: candidate.warpedImage,
                imageSize: imageSize,
                cutOffset: cutOffset
            ) else {
                continue
            }

            let correctionResult = solveRecognizedBoard(from: recognitionResult, using: boardSolver)
            let analysis = SudokuPuzzleAnalysis(
                detectedBoard: candidate,
                recognitionResult: recognitionResult,
                correctionResult: correctionResult
            )
            if correctionResult != nil && recognitionResult.recognizedCount >= 17 {
                return analysis
            }

            if let boardTextAnalysis = boardTextFallbackAnalysis(
                for: candidate,
                baselineRecognition: recognitionResult,
                using: boardSolver
            ) {
                if boardTextAnalysis.correctionResult != nil
                    && boardTextAnalysis.recognitionResult.recognizedCount >= 17 {
                    return boardTextAnalysis
                }

                let boardTextScore = puzzleAnalysisScore(boardTextAnalysis)
                if boardTextScore > bestScore {
                    bestScore = boardTextScore
                    bestAnalysis = boardTextAnalysis
                }
            }

            if let mergedAnalysis = mergedBoardTextAnalysis(
                for: candidate,
                baselineRecognition: recognitionResult,
                using: boardSolver
            ) {
                if mergedAnalysis.correctionResult != nil
                    && mergedAnalysis.recognitionResult.recognizedCount >= 17 {
                    return mergedAnalysis
                }

                let mergedScore = puzzleAnalysisScore(mergedAnalysis)
                if mergedScore > bestScore {
                    bestScore = mergedScore
                    bestAnalysis = mergedAnalysis
                }
            }

            if let strictAnalysis = strictRecognitionAnalysis(
                for: candidate,
                baselineRecognition: recognitionResult,
                using: boardSolver
            ) {
                if strictAnalysis.correctionResult != nil
                    && strictAnalysis.recognitionResult.recognizedCount >= 17 {
                    return strictAnalysis
                }

                let strictScore = puzzleAnalysisScore(strictAnalysis)
                if strictScore > bestScore {
                    bestScore = strictScore
                    bestAnalysis = strictAnalysis
                }
            }

            let analysisScore = puzzleAnalysisScore(analysis)
            if analysisScore > bestScore {
                bestScore = analysisScore
                bestAnalysis = analysis
            }
        }

        return bestAnalysis
    }

    private func puzzleAnalysisScore(_ analysis: SudokuPuzzleAnalysis) -> Double {
        let recognition = analysis.recognitionResult
        let candidate = analysis.detectedBoard
        let conflictCount = SudokuBoardRules.conflictingCellIndices(recognition.board).count
        let validBoardBonus = conflictCount == 0 && SudokuBoardRules.isBoardValid(recognition.board) ? 10.0 : 0.0
        let solvedBonus = analysis.correctionResult == nil ? 0.0 : 18.0
        let digitCount = recognition.recognizedCount
        let meaningfulAcceptedCount = meaningfulAcceptedDigitCount(in: recognition)
        let effectiveDigitCount = min(digitCount, SudokuOCRConfig.BoardText.maximumPlausibleRecognizedDigits)
        let digitCountPenalty: Double
        if digitCount < 17 {
            digitCountPenalty = Double(17 - digitCount) * 3.5
        } else if digitCount > SudokuOCRConfig.BoardText.maximumPlausibleRecognizedDigits {
            digitCountPenalty = Double(digitCount - SudokuOCRConfig.BoardText.maximumPlausibleRecognizedDigits) * 5.5
        } else {
            digitCountPenalty = 0
        }
        let conflictPenalty = Double(conflictCount) * 1.35
        let suspiciousLargeAreaPenalty: Double
        if candidate.boardAreaRatio > SudokuOCRConfig.BoardDetection.suspiciousLargeAreaThreshold,
           candidate.gridConfidence < 0.55 {
            suspiciousLargeAreaPenalty = Double(candidate.boardAreaRatio - SudokuOCRConfig.BoardDetection.suspiciousLargeAreaThreshold) * 18.0
        } else {
            suspiciousLargeAreaPenalty = 0
        }
        let unsupportedDigitPenalty: Double
        if candidate.gridConfidence < SudokuOCRConfig.BoardText.minimumFallbackGridConfidence {
            unsupportedDigitPenalty = Double(max(0, digitCount - meaningfulAcceptedCount)) * 0.8
        } else {
            unsupportedDigitPenalty = Double(max(0, digitCount - meaningfulAcceptedCount)) * 0.15
        }

        return Double(effectiveDigitCount) * 0.95
            + validBoardBonus
            + solvedBonus
            + (candidate.qualityScore * 12.0)
            + (candidate.gridConfidence * 16.0)
            - digitCountPenalty
            - conflictPenalty
            - unsupportedDigitPenalty
            - suspiciousLargeAreaPenalty
    }

    private func boardTextFallbackAnalysis(
        for candidate: OpenCVDetectedRectangle,
        baselineRecognition: SudokuRecognitionResult,
        using boardSolver: SudokuBoardSolving
    ) -> SudokuPuzzleAnalysis? {
        guard shouldAttemptBoardTextRecognition(for: candidate, baselineRecognition: baselineRecognition) else {
            return nil
        }
        guard let boardTextRecognition = boardTextRecognizer.recognizeBoard(from: candidate.warpedImage) else {
            return nil
        }
        guard boardTextRecognition.recognizedCount >= 17 else {
            return nil
        }

        let correctionResult = solveRecognizedBoard(from: boardTextRecognition, using: boardSolver)
        return SudokuPuzzleAnalysis(
            detectedBoard: candidate,
            recognitionResult: boardTextRecognition,
            correctionResult: correctionResult
        )
    }

    private func mergedBoardTextAnalysis(
        for candidate: OpenCVDetectedRectangle,
        baselineRecognition: SudokuRecognitionResult,
        using boardSolver: SudokuBoardSolving
    ) -> SudokuPuzzleAnalysis? {
        guard shouldAttemptBoardTextRecognition(for: candidate, baselineRecognition: baselineRecognition) else {
            return nil
        }
        guard let boardTextRecognition = boardTextRecognizer.recognizeBoard(from: candidate.warpedImage) else {
            return nil
        }

        let mergedRecognition = mergeRecognitionResults(
            baseline: baselineRecognition,
            boardText: boardTextRecognition
        )
        guard mergedRecognition.board != baselineRecognition.board else {
            return nil
        }
        guard mergedRecognition.recognizedCount >= 17 || baselineRecognition.recognizedCount < 17 else {
            return nil
        }

        let correctionResult = solveRecognizedBoard(from: mergedRecognition, using: boardSolver)
        return SudokuPuzzleAnalysis(
            detectedBoard: candidate,
            recognitionResult: mergedRecognition,
            correctionResult: correctionResult
        )
    }

    private func strictRecognitionAnalysis(
        for candidate: OpenCVDetectedRectangle,
        baselineRecognition: SudokuRecognitionResult,
        using boardSolver: SudokuBoardSolving
    ) -> SudokuPuzzleAnalysis? {
        guard baselineRecognition.cells.count == 81 else { return nil }

        let strictRecognition = makeRecognitionConservative(baselineRecognition)
        guard strictRecognition.board != baselineRecognition.board else {
            return nil
        }
        guard strictRecognition.recognizedCount >= 17 else {
            return nil
        }

        let correctionResult = solveRecognizedBoard(from: strictRecognition, using: boardSolver)
        return SudokuPuzzleAnalysis(
            detectedBoard: candidate,
            recognitionResult: strictRecognition,
            correctionResult: correctionResult
        )
    }

    private func makeRecognitionConservative(_ recognition: SudokuRecognitionResult) -> SudokuRecognitionResult {
        var board = Array(repeating: Array(repeating: 0, count: 9), count: 9)
        var cells: [SudokuRecognizedCell] = []
        cells.reserveCapacity(81)

        for cell in recognition.cells {
            let keepDigit = shouldKeepConservativeDigit(cell) ? cell.acceptedDigit : 0
            board[cell.row][cell.col] = keepDigit
            cells.append(
                SudokuRecognizedCell(
                    index: cell.index,
                    analysis: cell.analysis,
                    prediction: cell.prediction,
                    acceptedDigit: keepDigit
                )
            )
        }

        let recognizedCount = board.flatMap { $0 }.filter { $0 != 0 }.count
        return SudokuRecognitionResult(board: board, recognizedCount: recognizedCount, cells: cells)
    }

    private func shouldKeepConservativeDigit(_ cell: SudokuRecognizedCell) -> Bool {
        guard cell.acceptedDigit != 0, let prediction = cell.prediction else { return false }
        guard prediction.confidence >= 0.82 else { return false }
        guard prediction.marginToNextBestCandidate >= 0.20 else { return false }
        guard !prediction.isBlankLikely else { return false }
        if let analysis = cell.analysis {
            guard analysis.inkRatio >= 0.034 else { return false }
            guard analysis.componentAreaRatio >= 0.004 else { return false }
            if analysis.touchesBorder {
                guard prediction.confidence >= 0.97 else { return false }
                guard analysis.centroidDistanceRatio <= 0.10 else { return false }
                guard analysis.inkRatio >= 0.055 else { return false }
            }
        }
        return true
    }

    private func mergeRecognitionResults(
        baseline: SudokuRecognitionResult,
        boardText: SudokuRecognitionResult
    ) -> SudokuRecognitionResult {
        guard baseline.cells.count == 81, boardText.cells.count == 81 else {
            return baseline
        }

        var board = Array(repeating: Array(repeating: 0, count: 9), count: 9)
        var mergedCells: [SudokuRecognizedCell] = []
        mergedCells.reserveCapacity(81)

        for index in 0..<81 {
            let baselineCell = baseline.cells[index]
            let boardTextCell = boardText.cells[index]
            let shouldUseBoardText = shouldUseBoardText(cell: boardTextCell, over: baselineCell)
            let shouldBlankBaseline = shouldBlankBaseline(cell: baselineCell, with: boardTextCell)

            let acceptedDigit: Int
            let prediction: DigitPrediction?
            if shouldUseBoardText {
                acceptedDigit = boardTextCell.acceptedDigit
                prediction = boardTextCell.prediction
            } else if shouldBlankBaseline {
                acceptedDigit = 0
                prediction = baselineCell.prediction
            } else {
                acceptedDigit = baselineCell.acceptedDigit
                prediction = baselineCell.prediction
            }
            let analysis = baselineCell.analysis

            board[index / 9][index % 9] = acceptedDigit
            mergedCells.append(
                SudokuRecognizedCell(
                    index: index,
                    analysis: analysis,
                    prediction: prediction,
                    acceptedDigit: acceptedDigit
                )
            )
        }

        let recognizedCount = board.flatMap { $0 }.filter { $0 != 0 }.count
        return SudokuRecognitionResult(board: board, recognizedCount: recognizedCount, cells: mergedCells)
    }

    private func meaningfulAcceptedDigitCount(in recognition: SudokuRecognitionResult) -> Int {
        recognition.cells.reduce(into: 0) { count, cell in
            guard cell.acceptedDigit != 0 else { return }
            if cell.analysis?.hasMeaningfulInk == true {
                count += 1
            }
        }
    }

    private func shouldAttemptBoardTextRecognition(
        for candidate: OpenCVDetectedRectangle,
        baselineRecognition: SudokuRecognitionResult
    ) -> Bool {
        if candidate.gridConfidence >= SudokuOCRConfig.BoardText.minimumFallbackGridConfidence {
            return true
        }

        let meaningfulSupport = meaningfulAcceptedDigitCount(in: baselineRecognition)
        return candidate.qualityScore >= SudokuOCRConfig.BoardText.minimumFallbackQualityScore
            && meaningfulSupport >= SudokuOCRConfig.BoardText.minimumMeaningfulCellSupport
    }

    private func shouldUseBoardText(cell boardTextCell: SudokuRecognizedCell, over baselineCell: SudokuRecognizedCell) -> Bool {
        guard boardTextCell.acceptedDigit != 0 else { return false }
        if baselineCell.acceptedDigit == 0 {
            return true
        }
        if baselineCell.acceptedDigit == boardTextCell.acceptedDigit {
            return false
        }

        let baselineConfidence = baselineCell.prediction?.confidence ?? 0
        let boardTextConfidence = boardTextCell.prediction?.confidence ?? 0
        if baselineConfidence < 0.75 {
            return true
        }
        return boardTextConfidence > baselineConfidence + 0.07
    }

    private func shouldBlankBaseline(cell baselineCell: SudokuRecognizedCell, with boardTextCell: SudokuRecognizedCell) -> Bool {
        guard baselineCell.acceptedDigit != 0 else { return false }
        guard boardTextCell.acceptedDigit == 0 else { return false }
        guard let prediction = baselineCell.prediction else { return false }
        if prediction.confidence < 0.72 {
            return true
        }
        if prediction.marginToNextBestCandidate < 0.14 {
            return true
        }
        return prediction.isBlankLikely
    }
}

protocol PermissionAuthorizing {
    func requestPhotoLibraryReadWrite(_ completion: @escaping (Bool) -> Void)
    func requestCameraAccess(_ completion: @escaping (Bool) -> Void)
}

final class SystemPermissionAuthorizer: PermissionAuthorizing {
    func requestPhotoLibraryReadWrite(_ completion: @escaping (Bool) -> Void) {
        let authorizationStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        switch authorizationStatus {
        case .authorized, .limited:
            completion(true)
        case .notDetermined:
            PHPhotoLibrary.requestAuthorization(for: .readWrite) { state in
                DispatchQueue.main.async {
                    completion(state == .authorized || state == .limited)
                }
            }
        case .denied, .restricted:
            completion(false)
        @unknown default:
            completion(false)
        }
    }

    func requestCameraAccess(_ completion: @escaping (Bool) -> Void) {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        switch status {
        case .authorized:
            completion(true)
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    completion(granted)
                }
            }
        case .denied, .restricted:
            completion(false)
        @unknown default:
            completion(false)
        }
    }
}
