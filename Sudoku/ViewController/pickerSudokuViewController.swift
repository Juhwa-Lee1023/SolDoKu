//
//  pickerSudokuViewController.swift
//  Sudoku
//
//  Created by 이주화 on 2022/09/14.
//
import UIKit
import SnapKit

class pickerSudokuViewController: UIViewController {
    
    @IBOutlet weak var photoPicker: UIButton!
    @IBOutlet weak var solSudoku: UIButton!
    @IBOutlet weak var loadingLabel: UILabel!
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!
    @IBOutlet weak var loadingView: UIView!
    @IBOutlet weak var pickerImage: UIImageView!
    
    
    private var sudokuSolvingWorkItem: DispatchWorkItem?
    private let permissionAuthorizer: PermissionAuthorizing = SystemPermissionAuthorizer()
    private let visionProcessor: SudokuVisionProcessing = OpenCVSudokuVisionAdapter()
    private let boardSolver: SudokuBoardSolving = LegacySudokuBoardSolver()
    private lazy var puzzleRecognizer: SudokuPuzzleRecognizing = SudokuPuzzleRecognizer(
        visionProcessor: visionProcessor,
        digitPredictor: CoreMLDigitPredictor()
    )
    private let picker = UIImagePickerController()
    private let solveStateQueue = DispatchQueue(label: "com.soldoku.picker.solve-state")
    private var _ignoreSolve: Bool = false
    private var _isSolving: Bool = false
    private var ignoreSolve: Bool {
        get { solveStateQueue.sync { _ignoreSolve } }
        set { solveStateQueue.sync { _ignoreSolve = newValue } }
    }
    private let bounds = UIScreen.main.bounds

    private func runSudokuSolvingTask(_ task: @escaping () -> Void) {
        sudokuSolvingWorkItem = DispatchWorkItem(block: task)
        guard let workItem = sudokuSolvingWorkItem else { return }
        DispatchQueue.global(qos: .userInitiated).async(execute: workItem)
    }

    @discardableResult
    private func beginSolvingIfPossible() -> Bool {
        solveStateQueue.sync {
            if _isSolving {
                return false
            }
            _isSolving = true
            return true
        }
    }

    private func finishSolving() {
        solveStateQueue.sync {
            _isSolving = false
            _ignoreSolve = false
        }
        DispatchQueue.main.async {
            self.solSudoku.isEnabled = true
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.navigationController?.navigationBar.tintColor = .black
        hideIndicator()
        picker.delegate = self
        setbutton()
        setLayout()
        // Do any additional setup after loading the view.
    }
    
    @IBAction func shootPhotoPicker(_ sender: UIButton) {
        let alert = UIAlertController(title: "Select".localized, message: nil, preferredStyle: .actionSheet)
        let library = UIAlertAction(title: "Album".localized, style: .default) { _ in
            self.requestPhotoPermission { granted in
                if granted {
                    self.openLibrary()
                } else {
                    self.AuthSettingOpen(AuthString: "Album")
                }
            }
        }
        let camera = UIAlertAction(title: "Camera".localized, style: .default) { _ in
            self.requestCameraPermission { granted in
                if granted {
                    self.openCamera()
                } else {
                    self.AuthSettingOpen(AuthString: "Camera")
                }
            }
        }
        let cancel = UIAlertAction(title: "Cancel".localized, style: .cancel, handler: nil)
        
        alert.addAction(library)
        alert.addAction(camera)
        alert.addAction(cancel)
        
        present(alert, animated: true, completion: nil)
    }
    
    @IBAction func shootSolSudoku(_ sender: Any) {
        if pickerImage.image != nil {
            guard beginSolvingIfPossible() else { return }
            solSudoku.isEnabled = false
            showIndicator()
            runSudokuSolvingTask(self.sudokuSolvingQueue)
        } else {
            let alert = UIAlertController(title: "Picture hasn't been Uploaded.".localized, message: "Want to Upload a Picture?".localized, preferredStyle: .alert)
            let yes = UIAlertAction(title: "Yes".localized, style: .default) { _ in
                self.requestPhotoPermission { granted in
                    if granted {
                        self.openLibrary()
                    } else {
                        self.AuthSettingOpen(AuthString: "Album")
                    }
                }
            }
            let no = UIAlertAction(title: "No".localized, style: .destructive, handler: nil)
            alert.addAction(no)
            alert.addAction(yes)
            present(alert, animated: true, completion: nil)
        }
    }
    
    private func setLayout() {
        loadingLabel.text = "Currently solving Sudoku".localized
        
        pickerImage.snp.makeConstraints() { make in
            make.centerX.equalToSuperview()
            make.top.equalTo(self.view.safeAreaLayoutGuide).offset(bounds.height * 0.01)
            make.leading.equalTo(self.view).offset(bounds.width * 0.05)
            make.trailing.equalTo(self.view).offset(-(bounds.width * 0.05))
            make.size.width.height.equalTo(bounds.width * 0.9)
        }
        
        loadingView.snp.makeConstraints() { make in
            make.centerX.equalToSuperview()
            make.top.equalTo(self.view.safeAreaLayoutGuide).offset(bounds.height * 0.01)
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
            make.top.equalTo(loadingView.snp.top).offset(loadingView.frame.height * 0.45)
        }
        
        photoPicker.snp.makeConstraints() { make in
            make.centerX.equalToSuperview()
            make.top.equalTo(pickerImage.snp.bottom).offset(bounds.height / 35)
            make.leading.equalTo(self.view).offset(bounds.width * 0.05)
            make.trailing.equalTo(self.view).offset(-(bounds.width * 0.05))
            make.size.width.equalTo(bounds.width * 0.9)
            make.size.height.equalTo(bounds.width * 0.9 * 1/6)
        }
        
        solSudoku.snp.makeConstraints() { make in
            make.centerX.equalToSuperview()
            make.top.equalTo(photoPicker.snp.bottom).offset(bounds.height / 35)
            make.leading.equalTo(self.view).offset(bounds.width * 0.05)
            make.trailing.equalTo(self.view).offset(-(bounds.width * 0.05))
            make.size.width.equalTo(bounds.width * 0.9)
            make.size.height.equalTo(bounds.width * 0.9 * 1/6)
        }
    }
    
    private func setbutton() {
        photoPicker.setTitle("Upload from Album".localized, for: .normal)
        solSudoku.setTitle("Solving Sudoku".localized, for: .normal)
        
        [photoPicker, solSudoku].forEach {
            $0.layer.cornerRadius = 10
            $0.backgroundColor = UIColor.sudokuColor(.sudokuDeepButton)
            $0.titleLabel?.textColor = .white
            $0.titleLabel?.font = .boldSystemFont(ofSize: 30)
            $0.titleLabel?.minimumScaleFactor = 0.5
        }
    }
    
    private func showIndicator() {
        activityIndicator.startAnimating()
        loadingView.isHidden = false
    }
    
    private func hideIndicator() {
        activityIndicator.stopAnimating()
        loadingView.isHidden = true
    }
    
    private func sudokuSolvingQueue() {
        guard let image = pickerImage.image else {
            DispatchQueue.main.async {
                self.hideIndicator()
            }
            finishSolving()
            return
        }
        self.recognizeNum(image: image)
    }
    
    private func recognizeNum(image: UIImage) {
        guard let recognitionResult = puzzleRecognizer.recognizeBoard(from: image, imageSize: 64, cutOffset: 0) else {
            DispatchQueue.main.async {
                self.hideIndicator()
            }
            finishSolving()
            return
        }
        let sudokuArray = recognitionResult.board
        let sudokuNumbersCount = recognitionResult.recognizedCount

        if !ignoreSolve && sudokuNumbersCount < 17 {
            DispatchQueue.main.async {
                let alert = UIAlertController(title: "Really want to Solve?".localized, message: "Sudoku Solve requires more than 17 numbers.".localized, preferredStyle: .alert)
                let yes = UIAlertAction(title: "Yes".localized, style: .default) { _ in
                    self.hideIndicator()
                    self.ignoreSolve = true
                    self.runSudokuSolvingTask {
                        self.recognizeNum(image: image)
                    }
                }
                let no = UIAlertAction(title: "No".localized, style: .destructive) { _ in
                    self.hideIndicator()
                    self.finishSolving()
                }
                alert.addAction(no)
                alert.addAction(yes)
                self.present(alert, animated: true, completion: nil)
            }
            return
        }

        let solvedSudokuArray: [[Int]]
        switch boardSolver.solve(board: sudokuArray, iterationLimit: 1_000_000) {
        case .success(let solvedBoard):
            solvedSudokuArray = solvedBoard
        case .failure:
            DispatchQueue.main.async {
                let alert = UIAlertController(title: "Cannot solve Sudoku.".localized, message: "Upload another Picture?".localized, preferredStyle: .alert)
                let yes = UIAlertAction(title: "Yes".localized, style: .default) { _ in
                    self.requestPhotoPermission { granted in
                        if granted {
                            self.openLibrary()
                        } else {
                            self.AuthSettingOpen(AuthString: "Album")
                        }
                    }
                }
                let no = UIAlertAction(title: "No".localized, style: .destructive, handler: nil)
                alert.addAction(no)
                alert.addAction(yes)
                self.present(alert, animated: true, completion: nil)
                self.hideIndicator()
                self.finishSolving()
            }
            return
        }
        DispatchQueue.main.async {
            self.hideIndicator()
            self.showNum(solvedSudokuArray, sudokuArray, image)
            self.finishSolving()
        }
    }

    private func showNum(_ sudoku: [[Int]], _ solSudoku: [[Int]], _ image: UIImage) {
        UIGraphicsBeginImageContext(pickerImage.bounds.size)
        image.draw(in: CGRect(origin: CGPoint.zero, size: pickerImage.bounds.size))
        let cutViewWidth = pickerImage.bounds.size.width / 9
        let cutViewHeight = pickerImage.bounds.size.height / 9
        let cutViewWidthInt = Int(cutViewWidth)
        let cutViewHeightInt = Int(cutViewHeight)
        for row in 0..<9 {
            let yCoordinate = Int(CGFloat(row) * cutViewHeight)
            for col in 0..<9 {
                let xCoordinate = Int(CGFloat(col) * cutViewWidth)
                var fontColor: UIColor = UIColor.sudokuColor(.sudokuRed)
                let fontSize: CGFloat = 28
                //인식했던 숫자가 있는 경우 표현하지 않는다.
                if (solSudoku[row][col] != 0) {
                    fontColor = UIColor.sudokuColor(.sudokuEmpty)
                }
                let num = String(sudoku[row][col])
                let font = UIFont(name: "Helvetica", size: fontSize) ?? UIFont.systemFont(ofSize: fontSize)
                let textFontAttributes = [
                    NSAttributedString.Key.font: font,
                    NSAttributedString.Key.foregroundColor: fontColor,
                ] as [NSAttributedString.Key : Any]
                let numSize = num.size(withAttributes: textFontAttributes)
                let rect: CGRect = CGRect(x: xCoordinate + Int((cutViewWidth - numSize.width) / 2), y: yCoordinate + Int((cutViewHeight - numSize.height) / 2), width: cutViewWidthInt, height: cutViewHeightInt)
                num.draw(in: rect, withAttributes: textFontAttributes)
            }
        }
        let newImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        pickerImage.image = newImage
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

extension pickerSudokuViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    private func openLibrary() {
        DispatchQueue.main.async {
            self.picker.sourceType = .photoLibrary
            self.present(self.picker, animated: true, completion: nil)
        }
    }
    
    private func openCamera() {
        guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
            AuthSettingOpen(AuthString: "Camera")
            return
        }
        DispatchQueue.main.async {
            self.picker.sourceType = .camera
            self.present(self.picker, animated: true, completion: nil)
        }
    }
    
    internal func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        guard let image = info[UIImagePickerController.InfoKey.originalImage] as? UIImage else {
            picker.dismiss(animated: true)
            return
        }
        let fixOrientationImage = image.fixOrientation()
        
        if let detectedRectangle = visionProcessor.detectRectangle(in: fixOrientationImage) {
            pickerImage.image = detectedRectangle.warpedImage
        }
        picker.dismiss(animated: true)
    }
    
    private func requestPhotoPermission(_ completion: @escaping (Bool) -> Void) {
        permissionAuthorizer.requestPhotoLibraryReadWrite(completion)
    }
    
    private func requestCameraPermission(_ completion: @escaping (Bool) -> Void) {
        permissionAuthorizer.requestCameraAccess(completion)
    }
    
    
    func AuthSettingOpen(AuthString: String) {
        let message: String
        if AuthString == "Camera" {
            message = "If didn't allow the camera permission, \r\n Would like to go to the Setting Screen?".localized
        } else {
            message = "Soldoku is not allowed access to Album. \r\n Do you want to go to the Setting Screen?".localized
        }

        let alert = UIAlertController(title: "Setting".localized, message: message, preferredStyle: .alert)
        let cancel = UIAlertAction(title: "Cancel".localized, style: .default)
        let confirm = UIAlertAction(title: "Confirm".localized, style: .default) { _ in
            guard let settingURL = URL(string: UIApplication.openSettingsURLString) else { return }
            UIApplication.shared.open(settingURL)
        }
        alert.addAction(cancel)
        alert.addAction(confirm)

        DispatchQueue.main.async {
            self.present(alert, animated: true, completion: nil)
        }
    }
}
