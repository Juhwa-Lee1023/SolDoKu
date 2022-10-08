//
//  ViewController.swift
//  Sudoku
//
//  Created by 이주화 on 2022/09/06.
//

import UIKit
import SnapKit

class ViewController: UIViewController {

    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var goPhotoView: UIButton!
    @IBOutlet weak var goPickerView: UIButton!
    @IBOutlet weak var goInsertView: UIButton!
    @IBOutlet weak var mainSudokuCollectionView: UICollectionView!
    
    let bounds = UIScreen.main.bounds
    let sudokuNum = [Int](repeating: 0, count: 81)
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setButton()
        setTitleLabel()
        collectionViewLink()
        setLayout()
//        imageView.image = UIImage(named: "sudokuImage")
        // Do any additional setup after loading the view.
    }

    private func setTitleLabel() {
        self.view.addSubview(titleLabel)
        titleLabel.text = "SolDoKu".localized
        titleLabel.textColor = UIColor.sudokuColor(.sudokuDeepPurple)
        titleLabel.font = .boldSystemFont(ofSize: 60)
        titleLabel.minimumScaleFactor = 0.5
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.topAnchor.constraint(equalTo: self.view.topAnchor, constant: bounds.height/13).isActive = true
        titleLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor).isActive = true
    }

    private func setButton() {
        goPhotoView.setTitle("Take a Picture".localized, for: .normal)
        goPickerView.setTitle("Import from Album".localized, for: .normal)
        goInsertView.setTitle("Direct Input".localized, for: .normal)
        [goPhotoView, goPickerView, goInsertView].forEach {
            $0.layer.cornerRadius = 10
            $0.backgroundColor = UIColor.sudokuColor(.sudokuDeepButton)
            $0.titleLabel?.textColor = .white
            $0.titleLabel?.font = .boldSystemFont(ofSize: 30)
            $0.titleLabel?.minimumScaleFactor = 0.5
        }
    }
    
    private func collectionViewLink() {
        self.mainSudokuCollectionView.delegate = self
        self.mainSudokuCollectionView.dataSource = self
    }
    
    private func setLayout() {
        if ((bounds.width / bounds.height) <= 9/19) {
            titleLabel.snp.makeConstraints() { make in
                make.centerX.equalToSuperview()
                make.top.equalTo(view.safeAreaLayoutGuide).offset(10)
            }
            
            mainSudokuCollectionView.snp.makeConstraints() { make in
                make.centerX.equalToSuperview()
                make.top.equalTo(titleLabel.snp.bottom).offset(bounds.height / 45)
                make.leading.equalTo(self.view).offset(bounds.width/20)
                make.trailing.equalTo(self.view).offset(-(bounds.width/20))
                make.size.width.height.equalTo(bounds.width * 0.9)
            }
            
            goPhotoView.snp.makeConstraints() { make in
                make.centerX.equalToSuperview()
                make.top.equalTo(mainSudokuCollectionView.snp.bottom).offset(bounds.height / 35)
                make.leading.equalTo(self.view).offset(bounds.width/20)
                make.trailing.equalTo(self.view).offset(-(bounds.width/20))
                make.size.height.equalTo((bounds.width * 0.9) * 1/6.5)
            }
            
            goPickerView.snp.makeConstraints() { make in
                make.centerX.equalToSuperview()
                make.top.equalTo(goPhotoView.snp.bottom).offset(bounds.height / 35)
                make.leading.equalTo(self.view).offset(bounds.width/20)
                make.trailing.equalTo(self.view).offset(-(bounds.width/20))
                make.size.height.equalTo((bounds.width * 0.9) * 1/6.5)
            }
            
            goInsertView.snp.makeConstraints() { make in
                make.centerX.equalToSuperview()
                make.top.equalTo(goPickerView.snp.bottom).offset(bounds.height / 35)
                make.leading.equalTo(self.view).offset(bounds.width/20)
                make.trailing.equalTo(self.view).offset(-(bounds.width/20))
                make.size.height.equalTo((bounds.width * 0.9) * 1/6.5)
            }
        } else {
            titleLabel.snp.makeConstraints() { make in
                make.centerX.equalToSuperview()
                make.top.equalTo(view.safeAreaLayoutGuide).offset(5)
            }
            
            mainSudokuCollectionView.snp.makeConstraints() { make in
                make.centerX.equalToSuperview()
                make.top.equalTo(titleLabel.snp.bottom).offset(bounds.height / 45)
                make.leading.equalTo(self.view).offset(bounds.width/10)
                make.trailing.equalTo(self.view).offset(-(bounds.width/10))
                make.size.width.height.equalTo(bounds.width * 0.8)
            }
            
            goPhotoView.snp.makeConstraints() { make in
                make.centerX.equalToSuperview()
                make.top.equalTo(mainSudokuCollectionView.snp.bottom).offset(bounds.height / 35)
                make.leading.equalTo(self.view).offset(bounds.width/10)
                make.trailing.equalTo(self.view).offset(-(bounds.width/10))
                make.size.height.equalTo((bounds.width * 0.8) * 1/6.5)
            }
            
            goPickerView.snp.makeConstraints() { make in
                make.centerX.equalToSuperview()
                make.top.equalTo(goPhotoView.snp.bottom).offset(bounds.height / 35)
                make.leading.equalTo(self.view).offset(bounds.width/10)
                make.trailing.equalTo(self.view).offset(-(bounds.width/10))
                make.size.height.equalTo((bounds.width * 0.8) * 1/6.5)
            }
            
            goInsertView.snp.makeConstraints() { make in
                make.centerX.equalToSuperview()
                make.top.equalTo(goPickerView.snp.bottom).offset(bounds.height / 35)
                make.leading.equalTo(self.view).offset(bounds.width/10)
                make.trailing.equalTo(self.view).offset(-(bounds.width/10))
                make.size.height.equalTo((bounds.width * 0.8) * 1/6.5)
            }
        }
        
    }
}


extension ViewController: UICollectionViewDelegate, UICollectionViewDataSource {
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
            return sudokuNum.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
            guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "cell", for: indexPath) as? mainSudokuCollectionViewCell else { return UICollectionViewCell()}
            
            cell.layer.borderWidth = 1
            cell.layer.borderColor = UIColor.black.cgColor
            
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
    }
    func cellSet(cell: UICollectionViewCell){
        cell.backgroundColor = UIColor.sudokuColor(.sudokuLightPurple)
    }
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let selectCoordinate: [Int] = [indexPath.row / 9, indexPath.row % 9]
        let sectorRow: Int = 3 * Int(selectCoordinate[0] / 3)
        let sectorCol: Int = 3 * Int(selectCoordinate[1] / 3)
        let row1 = (selectCoordinate[0] + 2) % 3
        let row2 = (selectCoordinate[0] + 4) % 3
        let col1 = (selectCoordinate[1] + 2) % 3
        let col2 = (selectCoordinate[1] + 4) % 3
        
            for i in 0..<81 {
                guard let cell = mainSudokuCollectionView.cellForItem(at: [0, i]) as? mainSudokuCollectionViewCell else {
                    fatalError()
                }
                let cellCoordinate: [Int] = [i / 9, i % 9]
                
                cell.backgroundColor = .white
                cell.layer.borderWidth = 1
                cell.layer.borderColor = UIColor.black.cgColor
                cell.alpha = 1
                
                if cellCoordinate[0] == selectCoordinate[0] {
                    cellSet(cell: cell)
                } else if cellCoordinate[1] == selectCoordinate[1] {
                    cellSet(cell: cell)
                }
                if (row1 + sectorRow) == cellCoordinate[0] && (col1 + sectorCol) == cellCoordinate[1] { cellSet(cell: cell)
                }
                if (row2 + sectorRow) == cellCoordinate[0] && (col1 + sectorCol) == cellCoordinate[1] { cellSet(cell: cell)
                }
                if (row1 + sectorRow) == cellCoordinate[0] && (col2 + sectorCol) == cellCoordinate[1] { cellSet(cell: cell)
                }
                if (row2 + sectorRow) == cellCoordinate[0] && (col2 + sectorCol) == cellCoordinate[1] { cellSet(cell: cell)
                }
            }
        
            guard let cell = collectionView.cellForItem(at: indexPath) as? mainSudokuCollectionViewCell else {
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
            cell.alpha = 1
            cell.backgroundColor = UIColor.sudokuColor(.sudokuPurple)
    }
}

extension ViewController: UICollectionViewDelegateFlowLayout {
    // cell 사이즈( 옆 라인을 고려하여 설정 )
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumLineSpacingForSectionAt section: Int) -> CGFloat {
            return 0
    }
    
    // 옆 간격
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumInteritemSpacingForSectionAt section: Int) -> CGFloat {
            return 0
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
            let doubleNum: Double = Double(mainSudokuCollectionView.frame.width) / Double(9.0)
            let width = CGFloat(doubleNum)
            let size = CGSize(width: width, height: width)
            return size
    }
}

class mainSudokuCollectionViewCell: UICollectionViewCell {
    

}

