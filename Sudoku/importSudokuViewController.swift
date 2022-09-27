//
//  importSudokuViewController.swift
//  Sudoku
//
//  Created by 이주화 on 2022/09/06.
//

import UIKit

class importSudokuViewController: UIViewController {
    
    @IBOutlet weak var sudokuCollectionView: UICollectionView!
    
    @IBOutlet var buttons: [UIButton]!
    
    private var sudokuNum = [Int](repeating: 0, count: 81)
    private var solSudokuNum: [[Int]] = Array(repeating: Array(repeating: 0, count: 9), count: 9)
    private var selectNum: IndexPath = []
    private let setNumArray = [1, 2, 3, 4, 5, 6, 7, 8, 9]
    private var count:Int = 0
    
    override func viewDidLoad() {
        super.viewDidLoad()
        collectionViewLink()
        setButton()
    }
    
    @IBAction func setSudoku(_ sender: UIButton) {
        if(selectNum != []) {
            guard let cell = sudokuCollectionView.cellForItem(at: selectNum) as? sudokuCollectionViewCell else {
                fatalError()
            }
            
            cell.importNum.text = sender.titleLabel!.text
            sudokuNum[selectNum.row] = Int(cell.importNum.text!) ?? 0
        }
    }
    
    @IBAction func solve(_ sender: Any) {
        var check: Int = 0
        for i in 0...8 {
            for j in 0...8 {
                solSudokuNum[i][j] = sudokuNum[check]
                check += 1
            }
        }
        count = 0
        let successCheck  = sudokuCalculation(&solSudokuNum, 0, 0, &count)
        if !successCheck && count > 300 {
            let alert = UIAlertController(title: "Cannot solve Sudoku.", message: "Do you want to re-enter Sudoku?", preferredStyle: .alert)
            let yes = UIAlertAction(title: "Yes", style: .default) { (action) in
                for i in 0...80 {
                    guard let cell = self.sudokuCollectionView.cellForItem(at: [0, i]) as? sudokuCollectionViewCell else{
                        fatalError()
                    }
                    
                    cell.importNum.text = String(0)
                }
            }
            let no = UIAlertAction(title: "No", style: .destructive, handler: nil)
            alert.addAction(no)
            alert.addAction(yes)
            present(alert, animated: true, completion: nil)
            return
        }
        drawSudoku()
    }
    
    private func drawSudoku() {
        var check: Int = 0
        for i in 0...8 {
            for j in 0...8 {
                sudokuNum[check] = solSudokuNum[i][j]
                check += 1
            }
        }
        
        for i in 0...80 {
            guard let cell = sudokuCollectionView.cellForItem(at: [0, i]) as? sudokuCollectionViewCell else{
                fatalError()
            }
            
            cell.importNum.text = String(sudokuNum[i])
        }
    }
    
    private func collectionViewLink() {
        self.sudokuCollectionView.delegate = self
        self.sudokuCollectionView.dataSource = self
    }
    
    private func setButton() {
        for i in 0..<setNumArray.count {
            buttons[i].setTitle(String(setNumArray[i]), for: .normal)
        }
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
        return sudokuNum.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "cell", for: indexPath) as? sudokuCollectionViewCell else { return UICollectionViewCell()}
        
        cell.importNum.text = String(sudokuNum[indexPath.row])
        cell.contentView.layer.borderWidth = 1
        cell.contentView.layer.borderColor = UIColor.black.cgColor
        
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        
        for i in 0...80 {
            guard let cell = sudokuCollectionView.cellForItem(at: [0, i]) as? sudokuCollectionViewCell else{
                fatalError()
            }
            cell.contentView.layer.borderWidth = 1
            cell.contentView.layer.borderColor = UIColor.black.cgColor
        }
        guard let cell = collectionView.cellForItem(at: indexPath) as? sudokuCollectionViewCell else{
            fatalError()
        }
        cell.contentView.layer.borderWidth = 2
        cell.contentView.layer.borderColor = UIColor.red.cgColor
        selectNum = indexPath
    }
    
}

extension importSudokuViewController: UICollectionViewDelegateFlowLayout {
    // cell 사이즈( 옆 라인을 고려하여 설정 )
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumLineSpacingForSectionAt section: Int) -> CGFloat {
        return 0
    }
    
    // 옆 간격
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumInteritemSpacingForSectionAt section: Int) -> CGFloat {
        return 0
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        
        let width = sudokuCollectionView.frame.width / 9
        let size = CGSize(width: width, height: width)
        return size
    }
}

class sudokuCollectionViewCell: UICollectionViewCell {
    @IBOutlet weak var importNum: UILabel!
    
}
