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
    
    var sudokuNum = [Int](repeating: 0, count: 81)
    let buttonArr = ["1", "2", "3", "Clean", "4", "5", "6", "Delete", "7", "8", "9", "Solve"]
    var solSudokuNum: [[Int]] = Array(repeating: Array(repeating: 0, count: 9), count: 9)
    var selectNum: IndexPath = []
    let setNumArray = [1, 2, 3, 4, 5, 6, 7, 8, 9]
    var count:Int = 0
    private var sudokuSolvingWorkItem: DispatchWorkItem?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        collectionViewLink()
        hideIndicator()
    }
    
    private func showIndicator() {
        activityIndicator.startAnimating()
        loadingView.isHidden = false
    }
    
    private func hideIndicator() {
        activityIndicator.stopAnimating()
        loadingView.isHidden = true
    }
    func shootSolveSudoku() {
        showIndicator()
        sudokuSolvingWorkItem = DispatchWorkItem(block: self.solve)
        DispatchQueue.main.async(execute: sudokuSolvingWorkItem!)
    }
    
    func solve() {
        var check: Int = 0
        for i in 0..<9 {
            for j in 0..<9 {
                solSudokuNum[i][j] = sudokuNum[check]
                check += 1
            }
        }
        count = 0
        let successCheck  = sudokuCalculation(&solSudokuNum, 0, 0, &count)
        if !successCheck {
            let alert = UIAlertController(title: "Cannot solve Sudoku.", message: "Do you want to re-enter Sudoku?", preferredStyle: .alert)
            let yes = UIAlertAction(title: "Yes", style: .default) { (action) in
                for i in 0..<81 {
                    guard let cell = self.sudokuCollectionView.cellForItem(at: [0, i]) as? sudokuCollectionViewCell else {
                        fatalError()
                    }
                    
                    cell.importNum.text = ""
                    self.sudokuNum[i] = 0
                    self.hideIndicator()
                }
            }
            let no = UIAlertAction(title: "No", style: .destructive) { (action) in
                self.hideIndicator()
            }
            alert.addAction(no)
            alert.addAction(yes)
            present(alert, animated: true, completion: nil)
            return
        }
        hideIndicator()
        drawSudoku()
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
        if collectionView == sudokuCollectionView {
            guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "cell", for: indexPath) as? sudokuCollectionViewCell else { return UICollectionViewCell()}
            
            cell.importNum.text = ""
            cell.layer.borderWidth = 1
            cell.layer.borderColor = UIColor.black.cgColor
            switch indexPath.row / 9  {
            case 0 :
                cell.layer.addBorder([.top], color: UIColor.black, width: 4)
                break
            case 3, 6 :
                cell.layer.addBorder([.top], color: UIColor.black, width: 2)
                break
            case 8 :
                cell.layer.addBorder([.bottom], color: UIColor.black, width: 4)
            default:
                break
            }
            switch indexPath.row % 9  {
            case 0 :
                cell.layer.addBorder([.left], color: UIColor.black, width: 4)
                break
            case 3, 6 :
                cell.layer.addBorder([.left], color: UIColor.black, width: 2)
                break
            case 8 :
                cell.layer.addBorder([.right], color: UIColor.black, width: 4)
            default:
                break
            }
            
            
            return cell
        } else {
            guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "cell", for: indexPath) as? buttonCollectionViewCell else { return UICollectionViewCell()}
            
            cell.importButton.text = buttonArr[indexPath.row]
            if (cell.importButton.text == "Clean" || cell.importButton.text == "Delete" || cell.importButton.text == "Solve") {
                cell.importButton.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
                cell.importButton.minimumScaleFactor = 0.5
            } else {
                cell.importButton.font = UIFont.boldSystemFont(ofSize: 25)
                cell.importButton.minimumScaleFactor = 0.5
            }
            cell.layer.cornerRadius = cell.frame.width / 2
            cell.layer.backgroundColor = UIColor(red: 217/255, green: 217/255, blue: 217/255, alpha: 100/100).cgColor
            
            
            return cell
        }
        
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        if collectionView == sudokuCollectionView {
            for i in 0..<81 {
                guard let cell = sudokuCollectionView.cellForItem(at: [0, i]) as? sudokuCollectionViewCell else {
                    fatalError()
                }
                cell.backgroundColor = .white
                cell.layer.borderWidth = 1
                cell.layer.borderColor = UIColor.black.cgColor
            }
            guard let cell = collectionView.cellForItem(at: indexPath) as? sudokuCollectionViewCell else{
                fatalError()
            }
            cell.backgroundColor = UIColor(red: 107/255, green: 28/255, blue: 255/255, alpha: 60/100)
            cell.layer.borderWidth = 2
            cell.layer.borderColor = UIColor(red: 107/255, green: 28/255, blue: 255/255, alpha: 60/100).cgColor
            selectNum = indexPath
        } else {
            guard let cell = buttonCollectionView.cellForItem(at: indexPath) as? buttonCollectionViewCell else {
                fatalError()
            }
            switch cell.importButton.text {
            case "Delete":
                if(selectNum != []) {
                    guard let changeCell = sudokuCollectionView.cellForItem(at: selectNum) as? sudokuCollectionViewCell else{
                        fatalError()
                    }
                    changeCell.importNum.text = ""
                    sudokuNum[selectNum.row] = 0
                }
                break
            case "Clean":
                let alert = UIAlertController(title: "Clean Sudoku.", message: "Do you want to re-enter Sudoku?", preferredStyle: .alert)
                let yes = UIAlertAction(title: "Yes", style: .default) { (action) in
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
                break
            case "Solve":
                if(selectNum != []) {
                    shootSolveSudoku()
                } else {
                    let alert = UIAlertController(title: "Sudoku has not entered.", message: "Please enter Sudoku.", preferredStyle: .alert)
                    let yes = UIAlertAction(title: "Yes", style: .default)
                    alert.addAction(yes)
                    present(alert, animated: true, completion: nil)
                }
                break
            default:
                if(selectNum != []) {
                    guard let changeCell = sudokuCollectionView.cellForItem(at: selectNum) as? sudokuCollectionViewCell else{
                        fatalError()
                    }
                    changeCell.importNum.text = cell.importButton.text
                    sudokuNum[selectNum.row] = Int(changeCell.importNum.text!) ?? 0
                }
                break
            }
            
        }
        
    }
    
}

extension importSudokuViewController: UICollectionViewDelegateFlowLayout {
    // cell 사이즈( 옆 라인을 고려하여 설정 )
    
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
            return buttonCollectionView.frame.width / 15
        }
        
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        if collectionView == sudokuCollectionView {
            let width = sudokuCollectionView.frame.width / 9
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

