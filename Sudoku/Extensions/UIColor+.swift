//
//  UIColor.swift
//  Sudoku
//
//  Created by 이주화 on 2022/09/29.
//
enum Colors {
  case sudokuPuple
  case sudokuButton
  case sudokuRed
}

extension UIColor {
    static func sudokuColor(_ color: Colors) -> UIColor {
        switch color {
        case .sudokuPuple:
            return UIColor(red: 107/255, green: 28/255, blue: 255/255, alpha: 60/100)
        case .sudokuButton:
            return UIColor(red: 217/255, green: 217/255, blue: 217/255, alpha: 100/100)
        case .sudokuRed:
            return UIColor(red: 210/255, green: 31/255, blue: 0/255, alpha: 100/100)
        }
      }
}
