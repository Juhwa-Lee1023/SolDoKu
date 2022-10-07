//
//  importSudokuViewController.swift
//  Sudoku
//
//  Created by 이주화 on 2022/09/06.
//

import UIKit

class importSudokuViewController: UIViewController {
    
    @IBOutlet weak var sudokuCollectionView: UICollectionView!
    @IBOutlet weak var buttonCollectionView: UICollectionView!
    @IBOutlet weak var loadingView: UIView!
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!
    @IBOutlet weak var loadingLabel: UILabel!
    
    let bounds = UIScreen.main.bounds
    var selectSudoku: Int = 0
    var selectSudokuArr: [Int] = []
    var sudokuNum = [Int](repeating: 0, count: 81)
    let buttonArr = ["1", "2", "3", "Clean", "4", "5", "6", "Delete", "7", "8", "9", "Solve"]
    var solSudokuNum: [[Int]] = Array(repeating: Array(repeating: 0, count: 9), count: 9)
    var selectNum: IndexPath = []
    let setNumArray = [1, 2, 3, 4, 5, 6, 7, 8, 9]
    var count: Int = 0
    private var ignoreSolve: Bool = false
    private var sudokuSolvingWorkItem: DispatchWorkItem?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        collectionViewLink()
        hideIndicator()
        setLayout()
    }
    
    private func showIndicator() {
        activityIndicator.startAnimating()
        loadingView.isHidden = false
    }
    
    private func hideIndicator() {
        activityIndicator.stopAnimating()
        loadingView.isHidden = true
    }
    
    private func setLayout() {
        if ((bounds.width / bounds.height) <= 9/19) {
            sudokuCollectionView.snp.makeConstraints() { make in
                make.centerX.equalToSuperview()
                make.top.equalTo(self.view.safeAreaLayoutGuide).offset(bounds.height * 0.03)
                make.leading.equalTo(self.view).offset(bounds.width * 0.05)
                make.trailing.equalTo(self.view).offset(-(bounds.width * 0.05))
                make.size.width.height.equalTo(bounds.width * 0.9)
            }
            
            buttonCollectionView.snp.makeConstraints() { make in
                make.centerX.equalToSuperview()
                make.top.equalTo(sudokuCollectionView.snp.bottom).offset(bounds.height * 0.03)
                make.leading.equalTo(self.view).offset(bounds.width * 0.05)
                make.trailing.equalTo(self.view).offset(-(bounds.width * 0.05))
                make.size.width.height.equalTo(bounds.width * 0.9)
            }

            loadingView.snp.makeConstraints() { make in
                make.centerX.equalToSuperview()
                make.top.equalTo(self.view.safeAreaLayoutGuide).offset(bounds.height * 0.03)
                make.leading.equalTo(self.view).offset(bounds.width * 0.05)
                make.trailing.equalTo(self.view).offset(-(bounds.width * 0.05))
                make.size.width.height.equalTo(bounds.width * 0.9)
            }

            activityIndicator.snp.makeConstraints() { make in
                make.centerX.equalToSuperview()
                make.top.equalTo(loadingView.snp.top).offset(loadingView.frame.height * 0.45)
            }

            loadingLabel.snp.makeConstraints() { make in
                make.centerX.equalToSuperview()
                make.top.equalTo(loadingView.snp.top).offset(loadingView.frame.height * 0.7)
            }
        } else {
            sudokuCollectionView.snp.makeConstraints() { make in
                make.centerX.equalToSuperview()
                make.top.equalTo(self.view.safeAreaLayoutGuide).offset(bounds.height * 0.03)
                make.leading.equalTo(self.view).offset(bounds.width * 0.1)
                make.trailing.equalTo(self.view).offset(-(bounds.width * 0.1))
                make.size.width.height.equalTo(bounds.width * 0.8)
            }
            
            buttonCollectionView.snp.makeConstraints() { make in
                make.centerX.equalToSuperview()
                make.top.equalTo(sudokuCollectionView.snp.bottom).offset(bounds.height * 0.03)
                make.leading.equalTo(self.view).offset(bounds.width * 0.1)
                make.trailing.equalTo(self.view).offset(-(bounds.width * 0.1))
                make.size.width.height.equalTo(bounds.width * 0.8)
            }

            loadingView.snp.makeConstraints() { make in
                make.centerX.equalToSuperview()
                make.top.equalTo(self.view.safeAreaLayoutGuide).offset(bounds.height * 0.03)
                make.leading.equalTo(self.view).offset(bounds.width * 0.1)
                make.trailing.equalTo(self.view).offset(-(bounds.width * 0.1))
                make.size.width.height.equalTo(bounds.width * 0.8)
            }

            activityIndicator.snp.makeConstraints() { make in
                make.centerX.equalToSuperview()
                make.top.equalTo(loadingView.snp.top).offset(loadingView.frame.height * 0.45)
            }

            loadingLabel.snp.makeConstraints() { make in
                make.centerX.equalToSuperview()
                make.top.equalTo(loadingView.snp.top).offset(loadingView.frame.height * 0.7)
            }
        }
        

    }
    func shootSolveSudoku() {
        showIndicator()
        sudokuSolvingWorkItem = DispatchWorkItem(block: self.solveSudoku)
        DispatchQueue.main.async(execute: sudokuSolvingWorkItem!)
    }
    
    func solveSudoku() {
        var check: Int = 0
        var numCount: Int = 0
        for i in 0..<9 {
            for j in 0..<9 {
                if sudokuNum[check] != 0 {
                    numCount += 1
                }
                solSudokuNum[i][j] = sudokuNum[check]
                check += 1
            }
        }
        if !ignoreSolve {
            if numCount < 17 {
                let alert = UIAlertController(title: "Really want to Solve?", message: "Sudoku Solve requires more than 17 numbers.", preferredStyle: .alert)
                let yes = UIAlertAction(title: "Yes", style: .default) { _ in
                    self.hideIndicator()
                    self.ignoreSolve.toggle()
                    self.solveSudoku()
                }
                let no = UIAlertAction(title: "No", style: .destructive) { _ in
                    self.hideIndicator()
                }
                alert.addAction(no)
                alert.addAction(yes)
                present(alert, animated: true, completion: nil)
                return
            }
        }
        count = 0
        let successCheck  = sudokuCalculation(&solSudokuNum, 0, 0, &count)
        if !successCheck {
            let alert = UIAlertController(title: "Cannot solve Sudoku.", message: "Do you want to re-enter Sudoku?", preferredStyle: .alert)
            let yes = UIAlertAction(title: "Yes", style: .default) { _ in
                for i in 0..<81 {
                    guard let cell = self.sudokuCollectionView.cellForItem(at: [0, i]) as? sudokuCollectionViewCell else {
                        fatalError()
                    }
                    
                    cell.importNum.text = ""
                    self.sudokuNum[i] = 0
                    self.hideIndicator()
                }
            }
            let no = UIAlertAction(title: "No", style: .destructive) { _ in
                self.hideIndicator()
            }
            alert.addAction(no)
            alert.addAction(yes)
            present(alert, animated: true, completion: nil)
            return
        }
        hideIndicator()
        drawSudoku()
        ignoreSolve.toggle()
    }
    
    private func drawSudoku() {
        var check: Int = 0
        for i in 0..<9 {
            for j in 0..<9 {
                sudokuNum[check] = solSudokuNum[i][j]
                check += 1
            }
        }
        
        for i in 0..<81 {
            guard let cell = sudokuCollectionView.cellForItem(at: [0, i]) as? sudokuCollectionViewCell else {
                fatalError()
            }
            
            cell.importNum.text = String(sudokuNum[i])
        }
    }
    
    private func collectionViewLink() {
        self.sudokuCollectionView.delegate = self
        self.sudokuCollectionView.dataSource = self
        self.buttonCollectionView.delegate = self
        self.buttonCollectionView.dataSource = self
    }
    /*
     // MARK: - Navigation
     
     // In a storyboard-based application, you will often want to do a little preparation before navigation
     override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
     // Get the new view controller using segue.destination.
     // Pass the selected object to the new view controller.
     }
     */
    
}

extension importSudokuViewController: UICollectionViewDelegate, UICollectionViewDataSource {
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        if collectionView == sudokuCollectionView {
            return sudokuNum.count
        } else {
            return buttonArr.count
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        // 스도쿠 영역
        if collectionView == sudokuCollectionView {
            guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "cell", for: indexPath) as? sudokuCollectionViewCell else { return UICollectionViewCell()}
            
            cell.importNum.text = ""
            cell.layer.borderWidth = 1
            cell.layer.borderColor = UIColor.black.cgColor
            
            // 각 행, 렬에 따라 각기 다른 테두리 굵기를 가지게 하여 스도쿠의 영역을 표시
            switch indexPath.row / 9  {
            case 0 :
                cell.layer.addBorder([.top], color: UIColor.black, width: 4)
            case 3, 6 :
                cell.layer.addBorder([.top], color: UIColor.black, width: 2)
            case 8 :
                cell.layer.addBorder([.bottom], color: UIColor.black, width: 4)
            default: break
            }
            
            switch indexPath.row % 9  {
            case 0 :
                cell.layer.addBorder([.left], color: UIColor.black, width: 4)
            case 3, 6 :
                cell.layer.addBorder([.left], color: UIColor.black, width: 2)
            case 8 :
                cell.layer.addBorder([.right], color: UIColor.black, width: 4)
            default: break
            }
            
            return cell
        } else { // 버튼 영역
            guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "cell", for: indexPath) as? buttonCollectionViewCell else { return UICollectionViewCell()}
            
            cell.importButton.text = buttonArr[indexPath.row]
            if (cell.importButton.text == "Clean" || cell.importButton.text == "Delete" || cell.importButton.text == "Solve") {
                cell.importButton.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
                cell.contentView.backgroundColor = UIColor.sudokuColor(.sudokuDeepButton)
                cell.importButton.textColor = .white
                cell.importButton.minimumScaleFactor = 0.5
            } else {
                cell.importButton.font = UIFont.boldSystemFont(ofSize: 25)
                cell.contentView.backgroundColor = UIColor.sudokuColor(.sudokuDeepButton)
                cell.importButton.textColor = .white
                cell.importButton.minimumScaleFactor = 0.5
            }
            cell.layer.cornerRadius = cell.frame.width / 2
            cell.layer.backgroundColor = UIColor.sudokuColor(.sudokuButton).cgColor
            
            return cell
        }
    }

    // 셀을 변경 시키는 함수
    func cellColorSet(cell: sudokuCollectionViewCell){
        cell.backgroundColor = UIColor.sudokuColor(.sudokuLightPurple)
        if cell.importNum.text != "0" {
            selectSudoku = Int(cell.importNum.text!) ?? 0
            selectSudokuArr.append(selectSudoku)
        }
    }
    
    // 셀을 클릭하였을때
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        if collectionView == sudokuCollectionView { // 클릭한 셀이 스도쿠 영역이라면
            selectSudokuArr.removeAll()
            let selectCoordinate: [Int] = [indexPath.row / 9, indexPath.row % 9]
            let sectorRow: Int = 3 * Int(selectCoordinate[0] / 3)
            let sectorCol: Int = 3 * Int(selectCoordinate[1] / 3)
            let row1 = (selectCoordinate[0] + 2) % 3
            let row2 = (selectCoordinate[0] + 4) % 3
            let col1 = (selectCoordinate[1] + 2) % 3
            let col2 = (selectCoordinate[1] + 4) % 3
            for i in 0..<81 {
                guard let cell = sudokuCollectionView.cellForItem(at: [0, i]) as? sudokuCollectionViewCell else {
                    fatalError()
                }
                let cellNum: String = cell.importNum.text ?? ""
                let cellCoordinateX = i / 9
                let cellCoordinateY = i % 9
                // 셀 색상 초기화
                cell.backgroundColor = .white
                cell.layer.borderWidth = 1
                cell.layer.borderColor = UIColor.black.cgColor
                cell.alpha = 1
                if cellCoordinateX == selectCoordinate[0] { cellColorSet(cell: cell) }
                else if cellCoordinateY == selectCoordinate[1] { cellColorSet(cell: cell) }
                
                if (row1 + sectorRow) == cellCoordinateX && (col1 + sectorCol) == cellCoordinateY { cellColorSet(cell: cell) }
                if (row2 + sectorRow) == cellCoordinateX && (col1 + sectorCol) == cellCoordinateY { cellColorSet(cell: cell) }
                if (row1 + sectorRow) == cellCoordinateX && (col2 + sectorCol) == cellCoordinateY { cellColorSet(cell: cell) }
                if (row2 + sectorRow) == cellCoordinateX && (col2 + sectorCol) == cellCoordinateY { cellColorSet(cell: cell) }
                
                // 셀에 입력된 숫자가 있다면
                if cellNum != "" {
                    let cellSectorRow: Int = 3 * Int(cellCoordinateX / 3)
                    let cellSectorCol: Int = 3 * Int(cellCoordinateY / 3)
                    let cellRow1 = (cellCoordinateX + 2) % 3
                    let cellRow2 = (cellCoordinateX + 4) % 3
                    let cellCol1 = (cellCoordinateY + 2) % 3
                    let cellCol2 = (cellCoordinateY + 4) % 3
                    // 다른 셀들을 확인
                    for j in 0..<81 {
                        guard let checkCell = sudokuCollectionView.cellForItem(at: [0, j]) as? sudokuCollectionViewCell else {
                            fatalError()
                        }
                        // 셀의 값이 다른 셀의 값과 같다면
                        if cellNum == checkCell.importNum.text {
                            let checkCellCoordinateX = j / 9
                            let checkCellCoordinateY = j % 9
                            // 해당하는 숫자가 그곳이 있어도 되는지 확인하여 있으면 안되는 곳이라면 셀의 색상을 변경한다.
                            if cellCoordinateX != checkCellCoordinateX || cellCoordinateY != checkCellCoordinateY {
                                if cellCoordinateX == checkCellCoordinateX {
                                    cell.backgroundColor = UIColor.sudokuColor(.sudokuLightRed)
                                } else if cellCoordinateY == checkCellCoordinateY {
                                    cell.backgroundColor = UIColor.sudokuColor(.sudokuLightRed) }
                                if (cellRow1 + cellSectorRow) == checkCellCoordinateX && (cellCol1 + cellSectorCol) == checkCellCoordinateY { cell.backgroundColor = UIColor.sudokuColor(.sudokuLightRed) }
                                if (cellRow2 + cellSectorRow) == checkCellCoordinateX && (cellCol1 + cellSectorCol) == checkCellCoordinateY { cell.backgroundColor = UIColor.sudokuColor(.sudokuLightRed) }
                                if (cellRow1 + cellSectorRow) == checkCellCoordinateX && (cellCol2 + cellSectorCol) == checkCellCoordinateY { cell.backgroundColor = UIColor.sudokuColor(.sudokuLightRed) }
                                if (cellRow2 + cellSectorRow) == checkCellCoordinateX && (cellCol2 + cellSectorCol) == checkCellCoordinateY { cell.backgroundColor = UIColor.sudokuColor(.sudokuLightRed) }
                            }
                        }
                    }
                }
            }
            // 들어가면 안되는 숫자 버튼 색 변경
            for i in 0..<buttonArr.count {
                guard let cell = buttonCollectionView.cellForItem(at: [0, i]) as? buttonCollectionViewCell else {
                    fatalError()
                }
                cell.contentView.backgroundColor = UIColor.sudokuColor(.sudokuDeepButton)
                for j in 0..<selectSudokuArr.count {
                    if cell.importButton.text == String(selectSudokuArr[j]) {
                        cell.contentView.backgroundColor = UIColor.sudokuColor(.sudokuButton)
                    }
                }
            }
            
            // 클릭된 셀 애니메이션 추가
            guard let cell = collectionView.cellForItem(at: indexPath) as? sudokuCollectionViewCell else {
                fatalError()
            }
            UIView.animate(withDuration: 0.1,
                           animations: {
                cell.transform = .init(scaleX: 0.90, y: 0.90)
            }) { (completed) in
                UIView.animate(withDuration: 0.1,
                               animations: {
                    cell.transform = .init(scaleX: 1, y: 1)
                })
            }
            
            cell.backgroundColor = UIColor.sudokuColor(.sudokuPurple)
            selectNum = indexPath
        } else { // 클릭한 셀이 버튼 영역이라면
            guard let cell = buttonCollectionView.cellForItem(at: indexPath) as? buttonCollectionViewCell else {
                fatalError()
            }
            // 선택된 셀에 버튼처럼 애니메이션 추가
            UIView.animate(withDuration: 0.2,
                           animations: {
                cell.transform = .init(scaleX: 0.90, y: 0.90)
                cell.alpha = 0.5
            }) { (completed) in
                UIView.animate(withDuration: 0.2,
                               animations: {
                    cell.alpha = 1
                    cell.transform = .init(scaleX: 1, y: 1)
                })
            }
            // 버튼에 입력된 값에 따라 다른 액션
            switch cell.importButton.text {
            case "Delete":
                if(selectNum != []) {
                    guard let changeCell = sudokuCollectionView.cellForItem(at: selectNum) as? sudokuCollectionViewCell else{
                        fatalError()
                    }
                    changeCell.importNum.text = ""
                    sudokuNum[selectNum.row] = 0
                }
            case "Clean":
                let alert = UIAlertController(title: "Clean Sudoku.", message: "Do you want to re-enter Sudoku?", preferredStyle: .alert)
                let yes = UIAlertAction(title: "Yes", style: .default) { _ in
                    for i in 0..<81 {
                        guard let cell = self.sudokuCollectionView.cellForItem(at: [0, i]) as? sudokuCollectionViewCell else {
                            fatalError()
                        }
                        self.sudokuNum[i] = 0
                        cell.importNum.text = ""
                    }
                }
                let no = UIAlertAction(title: "No", style: .destructive, handler: nil)
                alert.addAction(no)
                alert.addAction(yes)
                present(alert, animated: true, completion: nil)
            case "Solve":
                if(selectNum != []) {
                    shootSolveSudoku()
                } else {
                    hideIndicator()
                    let alert = UIAlertController(title: "Sudoku has not Entered.", message: "Please enter Sudoku.", preferredStyle: .alert)
                    let yes = UIAlertAction(title: "Yes", style: .default)
                    alert.addAction(yes)
                    present(alert, animated: true, completion: nil)
                }
            default:
                if(selectNum != []) {
                    guard let changeCell = sudokuCollectionView.cellForItem(at: selectNum) as? sudokuCollectionViewCell else{
                        fatalError()
                    }
                    changeCell.importNum.text = cell.importButton.text
                    sudokuNum[selectNum.row] = Int(changeCell.importNum.text!) ?? 0
                }
            }
        }
    }
}

extension importSudokuViewController: UICollectionViewDelegateFlowLayout {
    // cell 사이즈
    
    // 위 아래 간격
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumLineSpacingForSectionAt section: Int) -> CGFloat {
        if collectionView == sudokuCollectionView {
            return 0
        } else {
            return buttonCollectionView.frame.height / 10
        }
    }
    
    // 옆 간격
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumInteritemSpacingForSectionAt section: Int) -> CGFloat {
        if collectionView == sudokuCollectionView {
            return 0
        } else {
            return buttonCollectionView.frame.width / 20
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        if collectionView == sudokuCollectionView {
            let doubleNum: Double = Double(sudokuCollectionView.frame.width) / Double(9.0)
            let width = CGFloat(doubleNum)
            let size = CGSize(width: width, height: width)
            return size
        } else {
            let width = buttonCollectionView.frame.width / 5
            let size = CGSize(width: width, height: width)
            return size
        }
        
        
    }
}
class sudokuCollectionViewCell: UICollectionViewCell {
    @IBOutlet weak var importNum: UILabel!
    
}

class buttonCollectionViewCell: UICollectionViewCell {
    @IBOutlet weak var importButton: UILabel!
    
}

