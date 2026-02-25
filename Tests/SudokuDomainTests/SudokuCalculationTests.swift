import XCTest
@testable import SudokuDomain

final class SudokuCalculationTests: XCTestCase {
    func testSudokuSolverRejectsInvalidShape() {
        let solver = SudokuSolver()
        let invalidShapeBoard = Array(repeating: Array(repeating: 0, count: 8), count: 8)

        let result = solver.solve(invalidShapeBoard)

        XCTAssertEqual(result, .failure(.invalidBoard))
    }

    func testSudokuSolverRejectsInvalidBoard() {
        let solver = SudokuSolver()
        let invalidBoard = Array(repeating: Array(repeating: 1, count: 9), count: 9)

        let result = solver.solve(invalidBoard)

        XCTAssertEqual(result, .failure(.invalidBoard))
    }

    func testSudokuSolverReturnsIterationLimitExceededWhenLimitIsZero() {
        let solver = SudokuSolver()
        let board: [[Int]] = [
            [5, 3, 0, 0, 7, 0, 0, 0, 0],
            [6, 0, 0, 1, 9, 5, 0, 0, 0],
            [0, 9, 8, 0, 0, 0, 0, 6, 0],
            [8, 0, 0, 0, 6, 0, 0, 0, 3],
            [4, 0, 0, 8, 0, 3, 0, 0, 1],
            [7, 0, 0, 0, 2, 0, 0, 0, 6],
            [0, 6, 0, 0, 0, 0, 2, 8, 0],
            [0, 0, 0, 4, 1, 9, 0, 0, 5],
            [0, 0, 0, 0, 8, 0, 0, 7, 9],
        ]

        let result = solver.solve(board, iterationLimit: 0)

        XCTAssertEqual(result, .failure(.iterationLimitExceeded))
    }

    func testInvalidFilledGridIsRejected() {
        var board = Array(repeating: Array(repeating: 1, count: 9), count: 9)
        var check = 0

        XCTAssertFalse(sudokuCalculation(&board, 0, 0, &check))
    }

    func testSolvableGridReturnsTrue() {
        var board: [[Int]] = [
            [5, 3, 0, 0, 7, 0, 0, 0, 0],
            [6, 0, 0, 1, 9, 5, 0, 0, 0],
            [0, 9, 8, 0, 0, 0, 0, 6, 0],
            [8, 0, 0, 0, 6, 0, 0, 0, 3],
            [4, 0, 0, 8, 0, 3, 0, 0, 1],
            [7, 0, 0, 0, 2, 0, 0, 0, 6],
            [0, 6, 0, 0, 0, 0, 2, 8, 0],
            [0, 0, 0, 4, 1, 9, 0, 0, 5],
            [0, 0, 0, 0, 8, 0, 0, 7, 9],
        ]
        var check = 0

        XCTAssertTrue(sudokuCalculation(&board, 0, 0, &check))
        XCTAssertEqual(board[0], [5, 3, 4, 6, 7, 8, 9, 1, 2])
        XCTAssertEqual(board[8], [3, 4, 5, 2, 8, 6, 1, 7, 9])
    }
}
