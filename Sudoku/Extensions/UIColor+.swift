//
//  UIColor.swift
//  Sudoku
//
//  Created by 이주화 on 2022/09/29.
//
enum Colors {
    case sudokuLightPurple
    case sudokuDeepPurple
    case sudokuPurple
    case sudokuButton
    case sudokuRed
    case sudokuEmpty
    case sudokuDeepButton
    case sudokuLightRed
}

extension UIColor {
    static func sudokuColor(_ color: Colors) -> UIColor {
        switch color {
        case .sudokuDeepButton:
            return UIColor(red: 85/255, green: 85/255, blue: 103/255, alpha: 255/255)
        case .sudokuLightPurple:
            return UIColor(red: 107/255, green: 28/255, blue: 255/255, alpha: 20/100)
        case .sudokuDeepPurple:
            return UIColor(red: 107/255, green: 28/255, blue: 255/255, alpha: 100/100)
        case .sudokuPurple:
            return UIColor(red: 107/255, green: 28/255, blue: 255/255, alpha: 60/100)
        case .sudokuButton:
            return UIColor(red: 217/255, green: 217/255, blue: 217/255, alpha: 100/100)
        case .sudokuRed:
            return UIColor(red: 210/255, green: 31/255, blue: 0/255, alpha: 100/100)
        case .sudokuEmpty:
            return UIColor(red: 210/255, green: 31/255, blue: 0/255, alpha: 0/100)
        case .sudokuLightRed:
            return UIColor(red: 255/255, green: 28/255, blue: 107/255, alpha: 60/100)
        }
    }
}
