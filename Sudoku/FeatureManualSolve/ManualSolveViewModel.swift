import Foundation
import SwiftUI

final class ManualSolveViewModel: ObservableObject {
    enum AlertKind: Identifiable {
        case cleanConfirm
        case insufficientDigits
        case unsolvable
        case emptyBoard

        var id: String {
            switch self {
            case .cleanConfirm:
                return "cleanConfirm"
            case .insufficientDigits:
                return "insufficientDigits"
            case .unsolvable:
                return "unsolvable"
            case .emptyBoard:
                return "emptyBoard"
            }
        }
    }

    @Published private(set) var board: [Int]
    @Published private(set) var conflictingIndices: Set<Int>
    @Published private(set) var highlightedIndices: Set<Int>
    @Published private(set) var blockedDigits: Set<Int>
    @Published private(set) var isSolving: Bool
    @Published var selectedIndex: Int?
    @Published var alertKind: AlertKind?

    private let boardSolver: SudokuBoardSolving

    init(boardSolver: SudokuBoardSolving = LegacySudokuBoardSolver()) {
        self.boardSolver = boardSolver
        self.board = Array(repeating: 0, count: 81)
        self.conflictingIndices = []
        self.highlightedIndices = []
        self.blockedDigits = []
        self.isSolving = false
        self.selectedIndex = nil
        self.alertKind = nil
        recalculateDerivedState()
    }

    func selectCell(at index: Int) {
        guard index >= 0, index < 81 else { return }
        selectedIndex = index
        recalculateDerivedState()
    }

    func inputDigit(_ digit: Int) {
        guard let selectedIndex else { return }
        guard (1...9).contains(digit) else { return }
        board[selectedIndex] = digit
        recalculateDerivedState()
    }

    func deleteSelectedCellValue() {
        guard let selectedIndex else { return }
        board[selectedIndex] = 0
        recalculateDerivedState()
    }

    func requestCleanBoard() {
        alertKind = .cleanConfirm
    }

    func clearBoard() {
        board = Array(repeating: 0, count: 81)
        selectedIndex = nil
        recalculateDerivedState()
    }

    func solveButtonTapped() {
        guard !isSolving else { return }
        guard board.contains(where: { $0 != 0 }) else {
            alertKind = .emptyBoard
            return
        }

        if board.filter({ $0 != 0 }).count < 17 {
            alertKind = .insufficientDigits
            return
        }

        solveCurrentBoard()
    }

    func solveIgnoringMinimumDigits() {
        guard !isSolving else { return }
        solveCurrentBoard()
    }

    private func solveCurrentBoard() {
        isSolving = true
        let boardSnapshot = boardMatrix(from: board)

        DispatchQueue.global(qos: .userInitiated).async { [boardSolver] in
            let result = boardSolver.solve(board: boardSnapshot, iterationLimit: 1_000_000)
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.isSolving = false
                switch result {
                case .success(let solvedBoard):
                    self.board = solvedBoard.flatMap { $0 }
                    self.recalculateDerivedState()
                case .failure:
                    self.alertKind = .unsolvable
                }
            }
        }
    }

    private func recalculateDerivedState() {
        conflictingIndices = Self.makeConflictingIndices(from: board)

        if let selectedIndex {
            highlightedIndices = Self.makeRelatedIndices(for: selectedIndex)
            blockedDigits = Self.makeBlockedDigits(for: selectedIndex, from: board)
        } else {
            highlightedIndices = []
            blockedDigits = []
        }
    }

    private func boardMatrix(from board: [Int]) -> [[Int]] {
        stride(from: 0, to: board.count, by: 9).map { offset in
            Array(board[offset..<(offset + 9)])
        }
    }

    private static func makeConflictingIndices(from board: [Int]) -> Set<Int> {
        var conflicts = Set<Int>()

        for row in 0..<9 {
            mergeDuplicateIndices(indicesInRow(row), from: board, into: &conflicts)
        }

        for col in 0..<9 {
            mergeDuplicateIndices(indicesInColumn(col), from: board, into: &conflicts)
        }

        for boxRow in 0..<3 {
            for boxCol in 0..<3 {
                mergeDuplicateIndices(indicesInBox(row: boxRow, col: boxCol), from: board, into: &conflicts)
            }
        }

        return conflicts
    }

    private static func mergeDuplicateIndices(_ indices: [Int], from board: [Int], into conflicts: inout Set<Int>) {
        var groupedByDigit: [Int: [Int]] = [:]

        for index in indices {
            let digit = board[index]
            guard digit != 0 else { continue }
            groupedByDigit[digit, default: []].append(index)
        }

        for duplicateIndices in groupedByDigit.values where duplicateIndices.count > 1 {
            conflicts.formUnion(duplicateIndices)
        }
    }

    private static func makeRelatedIndices(for index: Int) -> Set<Int> {
        let row = index / 9
        let col = index % 9
        let boxRow = row / 3
        let boxCol = col / 3

        var indices = Set(indicesInRow(row))
        indices.formUnion(indicesInColumn(col))
        indices.formUnion(indicesInBox(row: boxRow, col: boxCol))
        return indices
    }

    private static func makeBlockedDigits(for index: Int, from board: [Int]) -> Set<Int> {
        let relatedIndices = makeRelatedIndices(for: index)
        var blockedDigits = Set<Int>()

        for relatedIndex in relatedIndices where relatedIndex != index {
            let digit = board[relatedIndex]
            if digit != 0 {
                blockedDigits.insert(digit)
            }
        }

        return blockedDigits
    }

    private static func indicesInRow(_ row: Int) -> [Int] {
        (0..<9).map { row * 9 + $0 }
    }

    private static func indicesInColumn(_ col: Int) -> [Int] {
        (0..<9).map { $0 * 9 + col }
    }

    private static func indicesInBox(row boxRow: Int, col boxCol: Int) -> [Int] {
        let rowStart = boxRow * 3
        let colStart = boxCol * 3
        var indices: [Int] = []
        indices.reserveCapacity(9)

        for row in rowStart..<(rowStart + 3) {
            for col in colStart..<(colStart + 3) {
                indices.append(row * 9 + col)
            }
        }

        return indices
    }
}
