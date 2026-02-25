import Foundation

public struct VisionPoint: Equatable {
    public let x: Double
    public let y: Double

    public init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }
}

public struct SudokuBoardDetection: Equatable {
    public let corners: [VisionPoint]
    public let warpedBoardImageData: Data

    public init(corners: [VisionPoint], warpedBoardImageData: Data) {
        self.corners = corners
        self.warpedBoardImageData = warpedBoardImageData
    }
}

public enum VisionContractError: Error, Equatable {
    case invalidImage
    case boardNotFound
    case predictionFailed
    case unexpected(String)
}

public protocol SudokuBoardDetecting {
    func detectBoard(in imageData: Data) throws -> SudokuBoardDetection
}

public protocol SudokuCellSlicing {
    func sliceCells(from warpedBoardImageData: Data) throws -> [Data]
}

public protocol SudokuDigitPredicting {
    func predictDigits(in cellImageData: [Data]) throws -> [Int]
}
