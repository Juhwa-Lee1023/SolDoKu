//
//  sudokuCalculation.swift
//  Sudoku
//
//  Created by 이주화 on 2022/09/11.
//

import Foundation

// 해당하는 숫자가 들어가도 되는지 검증
func isVerify(_ number: Int, _ sudoku: [[Int]], _ row: Int, _ col:Int) -> Bool {
    let sectorRow: Int = 3 * Int(row / 3)
    let sectorCol: Int = 3 * Int(col / 3)
    let row1 = (row + 2) % 3
    let row2 = (row + 4) % 3
    let col1 = (col + 2) % 3
    let col2 = (col + 4) % 3

    // 들어갈 숫자가 row, column에 있는 숫자와 겹치는지 확인
    for i in 0..<9 {
        if (sudoku[i][col] == number) { return false }
        if (sudoku[row][i] == number) { return false }
    }

    // 숫자가 들어갈 3*3의 공간에 숫자가 겹치는지 확인
    if (sudoku[row1 + sectorRow][col1 + sectorCol] == number) { return false }
    if (sudoku[row2 + sectorRow][col1 + sectorCol] == number) { return false }
    if (sudoku[row1 + sectorRow][col2 + sectorCol] == number) { return false }
    if (sudoku[row2 + sectorRow][col2 + sectorCol] == number) { return false }

    return true
}

func sudokuCalcuation(_ sudoku: inout [[Int]], _ row: Int, _ col: Int, _ check: inout Int) -> Bool {
    
    if(check >= 700000){
        return false
    }
    if (row == 9) { return true }

    // 기존에 존재하는 숫자가 있다면
    if (sudoku[row][col] != 0) {
        if (col == 8) {
            check += 1
            if (sudokuCalcuation(&sudoku, row+1, 0, &check) == true) { return true }
        } else {
            check += 1
            if (sudokuCalcuation(&sudoku, row, col+1, &check) == true) { return true }
        }
        return false
    }

    // 모든 칸을 채울 때까지 재귀함수 호출
    for num in 1..<10 {
        if (isVerify(num, sudoku, row, col) == true) {
            sudoku[row][col] = num
            if (col == 8) {
                check += 1
                if (sudokuCalcuation(&sudoku, row+1, 0, &check) == true) { return true }
            } else {
                check += 1
                if (sudokuCalcuation(&sudoku, row, col+1, &check) == true) { return true }
            }
            // 계산이 불가능하면...
            sudoku[row][col] = 0
        }
    }
    
    return false
}
