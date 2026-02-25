import AVFoundation
import CoreML
import Foundation
import Photos
import UIKit

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

// Legacy API compatibility
func isVerify(_ number: Int, _ sudoku: [[Int]], _ row: Int, _ col: Int) -> Bool {
    SudokuBoardRules.isPlacementValid(number, sudoku, row, col)
}

// Legacy API compatibility
func sudokuCalculation(_ sudoku: inout [[Int]], _ row: Int, _ col: Int, _ check: inout Int) -> Bool {
    solveSudokuInPlace(&sudoku, row, col, &check, 1_000_000)
}

struct OpenCVDetectedRectangle {
    let corners: [CGPoint]
    let warpedImage: UIImage
}

struct OpenCVSlicedCells {
    let cellImages: [UIImage]
    let mergedImage: UIImage?
}

protocol SudokuVisionProcessing {
    func detectRectangle(in image: UIImage) -> OpenCVDetectedRectangle?
    func detectCorners(in image: UIImage) -> [CGPoint]?
    func sliceCells(from image: UIImage, imageSize: Int, cutOffset: Int) -> OpenCVSlicedCells?
    func cellHasDigit(_ image: UIImage, imageSize: Int) -> Bool?
}

final class OpenCVSudokuVisionAdapter: SudokuVisionProcessing {
    func detectRectangle(in image: UIImage) -> OpenCVDetectedRectangle? {
        guard let detectResult = wrapper.detectRectangle(image) as? [Any], detectResult.count >= 2 else {
            return nil
        }
        guard let corners = detectResult[0] as? [NSValue],
              let warpedImage = detectResult[1] as? UIImage else {
            return nil
        }
        return OpenCVDetectedRectangle(
            corners: corners.map { $0.cgPointValue },
            warpedImage: warpedImage
        )
    }

    func detectCorners(in image: UIImage) -> [CGPoint]? {
        guard let corners = wrapper.detectRect(image) as? [NSValue], corners.count >= 4 else {
            return nil
        }
        return corners.map { $0.cgPointValue }
    }

    func sliceCells(from image: UIImage, imageSize: Int = 64, cutOffset: Int = 0) -> OpenCVSlicedCells? {
        guard let sliceResult = wrapper.sliceImages(image, imageSize: Int32(imageSize), cutOffset: Int32(cutOffset)) as? [Any],
              sliceResult.count >= 2,
              let cellImages = sliceResult[0] as? [UIImage] else {
            return nil
        }
        let mergedImage = sliceResult[1] as? UIImage
        return OpenCVSlicedCells(cellImages: cellImages, mergedImage: mergedImage)
    }

    func cellHasDigit(_ image: UIImage, imageSize: Int = 64) -> Bool? {
        guard let detectResult = wrapper.getNumImage(image, imageSize: Int32(imageSize)) as? [Any],
              let hasDigit = (detectResult.first as? NSNumber)?.boolValue else {
            return nil
        }
        return hasDigit
    }
}

protocol SudokuDigitPredicting {
    func predictDigit(from image: UIImage) -> Int?
}

final class CoreMLDigitPredictor: SudokuDigitPredicting {
    func predictDigit(from image: UIImage) -> Int? {
        guard let buffer = image.UIImageToPixelBuffer() else { return nil }
        guard let prediction = try? model_64().prediction(x: buffer) else { return nil }

        let scoresCount = prediction.y.count
        let scoresPointer = prediction.y.dataPointer.bindMemory(to: Double.self, capacity: scoresCount)
        let scoreBuffer = UnsafeBufferPointer(start: scoresPointer, count: scoresCount)
        let scores = Array(scoreBuffer)
        guard let maxScore = scores.max(), let predicted = scores.firstIndex(of: maxScore) else {
            return nil
        }
        return predicted
    }
}

struct SudokuRecognitionResult {
    let board: [[Int]]
    let recognizedCount: Int
}

protocol SudokuPuzzleRecognizing {
    func recognizeBoard(from image: UIImage, imageSize: Int, cutOffset: Int) -> SudokuRecognitionResult?
}

final class SudokuPuzzleRecognizer: SudokuPuzzleRecognizing {
    private let visionProcessor: SudokuVisionProcessing
    private let digitPredictor: SudokuDigitPredicting

    init(
        visionProcessor: SudokuVisionProcessing = OpenCVSudokuVisionAdapter(),
        digitPredictor: SudokuDigitPredicting = CoreMLDigitPredictor()
    ) {
        self.visionProcessor = visionProcessor
        self.digitPredictor = digitPredictor
    }

    func recognizeBoard(from image: UIImage, imageSize: Int = 64, cutOffset: Int = 0) -> SudokuRecognitionResult? {
        guard let slicedCells = visionProcessor.sliceCells(from: image, imageSize: imageSize, cutOffset: cutOffset),
              slicedCells.cellImages.count == 81 else {
            return nil
        }

        var recognizedCount = 0
        var board = Array(repeating: Array(repeating: 0, count: 9), count: 9)

        for (index, cellImage) in slicedCells.cellImages.enumerated() {
            let row = index / 9
            let col = index % 9
            guard row < 9, col < 9 else { continue }

            guard let hasDigit = visionProcessor.cellHasDigit(cellImage, imageSize: imageSize) else {
                board[row][col] = 0
                continue
            }

            if hasDigit {
                recognizedCount += 1
                board[row][col] = digitPredictor.predictDigit(from: cellImage) ?? 0
            } else {
                board[row][col] = 0
            }
        }

        return SudokuRecognitionResult(board: board, recognizedCount: recognizedCount)
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
