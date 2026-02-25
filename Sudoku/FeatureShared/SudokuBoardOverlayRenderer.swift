import UIKit

enum SudokuBoardOverlayRenderer {
    static func drawSolvedBoard(
        solvedBoard: [[Int]],
        recognizedBoard: [[Int]],
        on image: UIImage,
        textColor: UIColor = UIColor.sudokuColor(.sudokuRed)
    ) -> UIImage {
        let boardSize = image.size
        let cellWidth = boardSize.width / 9
        let cellHeight = boardSize.height / 9

        let renderer = UIGraphicsImageRenderer(size: boardSize)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: boardSize))

            for row in 0..<9 {
                for col in 0..<9 {
                    if recognizedBoard[row][col] != 0 { continue }

                    let number = String(solvedBoard[row][col])
                    let fontSize = min(cellWidth, cellHeight) * 0.62
                    let font = UIFont(name: "Helvetica", size: fontSize) ?? UIFont.systemFont(ofSize: fontSize)
                    let attributes: [NSAttributedString.Key: Any] = [
                        .font: font,
                        .foregroundColor: textColor,
                    ]

                    let textSize = number.size(withAttributes: attributes)
                    let textX = CGFloat(col) * cellWidth + (cellWidth - textSize.width) / 2
                    let textY = CGFloat(row) * cellHeight + (cellHeight - textSize.height) / 2
                    number.draw(at: CGPoint(x: textX, y: textY), withAttributes: attributes)
                }
            }
        }
    }

    static func drawRecognizedBoard(
        board: [[Int]],
        on image: UIImage,
        textColor: UIColor = .black
    ) -> UIImage {
        let boardSize = image.size
        let cellWidth = boardSize.width / 9
        let cellHeight = boardSize.height / 9

        let renderer = UIGraphicsImageRenderer(size: boardSize)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: boardSize))

            for row in 0..<9 {
                for col in 0..<9 {
                    let value = board[row][col]
                    if value == 0 { continue }

                    let number = String(value)
                    let fontSize = min(cellWidth, cellHeight) * 0.62
                    let font = UIFont(name: "Helvetica", size: fontSize) ?? UIFont.systemFont(ofSize: fontSize)
                    let attributes: [NSAttributedString.Key: Any] = [
                        .font: font,
                        .foregroundColor: textColor,
                    ]

                    let textSize = number.size(withAttributes: attributes)
                    let textX = CGFloat(col) * cellWidth + (cellWidth - textSize.width) / 2
                    let textY = CGFloat(row) * cellHeight + (cellHeight - textSize.height) / 2
                    number.draw(at: CGPoint(x: textX, y: textY), withAttributes: attributes)
                }
            }
        }
    }
}
