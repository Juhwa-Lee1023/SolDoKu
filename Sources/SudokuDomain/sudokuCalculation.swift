import Foundation

public enum SudokuSolverError: Error, Equatable {
    case invalidBoard
    case unsolvable
    case iterationLimitExceeded
}

public struct SudokuSolver {
    public init() {}

    public func solve(_ board: [[Int]], iterationLimit: Int = 1_000_000) -> Result<[[Int]], SudokuSolverError> {
        guard SudokuBoardValidator.isBoardValid(board) else {
            return .failure(.invalidBoard)
        }

        var workingBoard = board
        var stepCounter = 0
        let solved = legacySudokuCalculation(&workingBoard, 0, 0, &stepCounter, iterationLimit: iterationLimit)

        if solved {
            return .success(workingBoard)
        }
        if stepCounter >= iterationLimit {
            return .failure(.iterationLimitExceeded)
        }
        return .failure(.unsolvable)
    }

    public func isValid(board: [[Int]]) -> Bool {
        SudokuBoardValidator.isBoardValid(board)
    }
}

private enum SudokuBoardValidator {
    static func hasValidShape(_ board: [[Int]]) -> Bool {
        guard board.count == 9 else { return false }
        return board.allSatisfy { $0.count == 9 }
    }

    static func isBoardValid(_ board: [[Int]]) -> Bool {
        guard hasValidShape(board) else { return false }

        for row in 0..<9 {
            var rowSeen = Set<Int>()
            var colSeen = Set<Int>()
            for col in 0..<9 {
                let rowValue = board[row][col]
                let colValue = board[col][row]

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
                        let value = board[row][col]
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

    static func isPlacementValid(_ number: Int, board: [[Int]], row: Int, col: Int) -> Bool {
        guard number >= 1 && number <= 9 else { return false }
        guard hasValidShape(board) else { return false }
        guard (0..<9).contains(row), (0..<9).contains(col) else { return false }

        for index in 0..<9 {
            if board[index][col] == number { return false }
            if board[row][index] == number { return false }
        }

        let boxStartRow = (row / 3) * 3
        let boxStartCol = (col / 3) * 3
        for targetRow in boxStartRow..<(boxStartRow + 3) {
            for targetCol in boxStartCol..<(boxStartCol + 3) {
                if board[targetRow][targetCol] == number {
                    return false
                }
            }
        }
        return true
    }
}

// Legacy API for existing UIKit controllers
public func isVerify(_ number: Int, _ sudoku: [[Int]], _ row: Int, _ col: Int) -> Bool {
    SudokuBoardValidator.isPlacementValid(number, board: sudoku, row: row, col: col)
}

// Legacy API for existing UIKit controllers
public func sudokuCalculation(_ sudoku: inout [[Int]], _ row: Int, _ col: Int, _ check: inout Int) -> Bool {
    legacySudokuCalculation(&sudoku, row, col, &check, iterationLimit: 1_000_000)
}

private func legacySudokuCalculation(
    _ sudoku: inout [[Int]],
    _ row: Int,
    _ col: Int,
    _ check: inout Int,
    iterationLimit: Int
) -> Bool {
    if check >= iterationLimit { return false }
    if row == 9 { return SudokuBoardValidator.isBoardValid(sudoku) }
    if !(0..<9).contains(row) || !(0..<9).contains(col) { return false }

    if sudoku[row][col] != 0 {
        if col == 8 {
            check += 1
            if legacySudokuCalculation(&sudoku, row + 1, 0, &check, iterationLimit: iterationLimit) {
                return true
            }
        } else {
            check += 1
            if legacySudokuCalculation(&sudoku, row, col + 1, &check, iterationLimit: iterationLimit) {
                return true
            }
        }
        return false
    }

    for number in 1..<10 {
        if isVerify(number, sudoku, row, col) {
            sudoku[row][col] = number
            if col == 8 {
                check += 1
                if legacySudokuCalculation(&sudoku, row + 1, 0, &check, iterationLimit: iterationLimit) {
                    return true
                }
            } else {
                check += 1
                if legacySudokuCalculation(&sudoku, row, col + 1, &check, iterationLimit: iterationLimit) {
                    return true
                }
            }
            sudoku[row][col] = 0
        }
    }

    return false
}
