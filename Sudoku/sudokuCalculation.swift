//
//  sudokuCalculation.swift
//  Sudoku
//
//  Created by 이주화 on 2022/09/11.
//

import Foundation

// 해당하는 숫자가 들어가도 되는지 검증
func isVerify(_ number: Int, _ sudoku: [[Int]], _ row: Int, _ col: Int) -> Bool {
    let sectorRow: Int = 3 * Int(row / 3)
    let sectorCol: Int = 3 * Int(col / 3)

    // 들어갈 숫자가 row, column에 있는 숫자와 겹치는지 확인
    for i in 0..<9 {
        if sudoku[i][col] == number { return false }
        if sudoku[row][i] == number { return false }
    }

    // 숫자가 들어갈 3*3의 공간에 숫자가 겹치는지 확인
    for i in 0..<3 {
        for j in 0..<3 {
            if sudoku[sectorRow + i][sectorCol + j] == number { return false }
        }
    }

    return true
}

// 가능한 숫자 목록을 반환
func getPossibleNumbers(_ sudoku: [[Int]], _ row: Int, _ col: Int) -> [Int] {
    var possibleNumbers: [Int] = []
    for num in 1...9 {
        if isVerify(num, sudoku, row, col) {
            possibleNumbers.append(num)
        }
    }
    return possibleNumbers
}

// 최소 남은 값 휴리스틱을 사용하여 빈 셀 찾기
func findEmptyCellWithMinimumOptions(_ sudoku: [[Int]]) -> (Int, Int)? {
    var minOptions = 10
    var minCell: (Int, Int)? = nil

    for row in 0..<9 {
        for col in 0..<9 {
            if sudoku[row][col] == 0 {
                let optionsCount = getPossibleNumbers(sudoku, row, col).count
                if optionsCount < minOptions {
                    minOptions = optionsCount
                    minCell = (row, col)
                }
                if minOptions == 1 {
                    return minCell
                }
            }
        }
    }

    return minCell
}

// 제한 시간을 설정하여 해결 시도
func sudokuCalculation(_ sudoku: inout [[Int]], _ row: Int, _ col: Int, _ check: inout Int) -> Bool {
    if check >= 3000 { return false }

    // 빈 셀 찾기 (최소 남은 값 휴리스틱 사용)
    guard let (emptyRow, emptyCol) = findEmptyCellWithMinimumOptions(sudoku) else { return true }

    // 가능한 숫자 목록을 정렬하여 처리
    var possibleNumbers = getPossibleNumbers(sudoku, emptyRow, emptyCol)
    possibleNumbers.sort { a, b in
        getPossibleNumbers(sudoku, emptyRow, emptyCol).count < getPossibleNumbers(sudoku, emptyRow, emptyCol).count
    }

    // 가능한 숫자들로 셀 채우기
    for num in possibleNumbers {
        sudoku[emptyRow][emptyCol] = num
        check += 1
        if sudokuCalculation(&sudoku, emptyRow, emptyCol, &check) {
            return true
        }
        // 계산이 불가능하면...
        sudoku[emptyRow][emptyCol] = 0
    }

    return false
}

