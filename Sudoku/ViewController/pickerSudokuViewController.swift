//
//  pickerSudokuViewController.swift
//  Sudoku
//
//  Created by 이주화 on 2022/09/14.
//
import UIKit
import AVFoundation
import CoreML
import Vision
import Photos

class pickerSudokuViewController: UIViewController {
    
    @IBOutlet weak var photoPicker: UIButton!
    @IBOutlet weak var solSudoku: UIButton!
    @IBOutlet weak var loadingLabel: UILabel!
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!
    @IBOutlet weak var loadingView: UIView!
    @IBOutlet weak var pickerImage: UIImageView!
    
    
    private var sudokuSolvingWorkItem: DispatchWorkItem?
    private var count:Int = 0
    private let picker = UIImagePickerController()
    private var ignoreSolve: Bool = false
    private let bounds = UIScreen.main.bounds
    
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
            if self.PhotoAuth() {
                self.openLibrary()
            }
            else {
                self.AuthSettingOpen(AuthString: "Album")
            }
        }
        let camera = UIAlertAction(title: "Camera".localized, style: .default) { _ in
            if self.CameraAuth() {
                self.openCamera()
            }
            else {
                self.AuthSettingOpen(AuthString: "Camera")
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
            showIndicator()
            sudokuSolvingWorkItem = DispatchWorkItem(block: self.sudokuSolvingQueue)
            DispatchQueue.main.async(execute: sudokuSolvingWorkItem!)
        } else {
            let alert = UIAlertController(title: "Picture hasn't been Uploaded.".localized, message: "Want to Upload a Picture?".localized, preferredStyle: .alert)
            let yes = UIAlertAction(title: "Yes".localized, style: .default) { _ in
                if self.PhotoAuth() {
                    self.openLibrary()
                }
                else {
                    self.AuthSettingOpen(AuthString: "Album")
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
        self.recognizeNum(image: pickerImage.image!)
    }
    
    private func recognizeNum(image: UIImage) {
        // get sudoku number images
        var sudokuArray:[[Int]] = Array(repeating: Array(repeating: 0, count: 9), count: 9)
        var sudokuNumbersCount: Int = 0
        if let UIImgaeSliceArr = wrapper.sliceImages(image, imageSize: 64, cutOffset: 0) {
            let numImages = UIImgaeSliceArr[0] as! NSArray
            for i in 0..<numImages.count {
                let numimg = numImages[i]
                let col = i % 9
                let row = Int(i / 9)
                let img = numimg as! UIImage
                if let sliceNumImage = wrapper.getNumImage(img, imageSize: 64) {
                    // 숫자가 있으면 true, 없으면 false 이다
                    let numExist = (sliceNumImage[0] as! NSNumber).boolValue
                    if numExist == true {
                        // 숫자가 존재 하는 경우 처리
                        sudokuNumbersCount += 1
                        guard let buf = img.UIImageToPixelBuffer() else { return }
                        
                        let model = model_64()
                        guard let predList = try? model.prediction(x: buf) else {
                            break
                        }
                        let predListLength = predList.y.count
                        let doublePtr =  predList.y.dataPointer.bindMemory(to: Double.self, capacity: predListLength)
                        let doubleBuffer = UnsafeBufferPointer(start: doublePtr, count: predListLength)
                        let predArr = Array(doubleBuffer)
                        let predArrMax = predArr.max()
                        let result = predArr.firstIndex(of: predArrMax!)
                        
                        sudokuArray[row][col] = result ?? 0
                    } else {
                        sudokuArray[row][col] = 0
                    }
                } else {
                    sudokuArray[row][col] = 0
                }
            }
            
            if !ignoreSolve {
                if sudokuNumbersCount < 17 {
                    let alert = UIAlertController(title: "Really want to Solve?".localized, message: "Sudoku Solve requires more than 17 numbers.".localized, preferredStyle: .alert)
                    let yes = UIAlertAction(title: "Yes".localized, style: .default) { _ in
                        self.hideIndicator()
                        self.ignoreSolve.toggle()
                        self.recognizeNum(image: image)
                    }
                    let no = UIAlertAction(title: "No".localized, style: .destructive) { _ in
                        self.hideIndicator()
                    }
                    alert.addAction(no)
                    alert.addAction(yes)
                    present(alert, animated: true, completion: nil)
                    return
                }
            }
            
            // sudoku 풀이
            var solvedSudokuArray = sudokuArray
            count = 0
            let successCheck = sudokuCalculation(&solvedSudokuArray, 0, 0, &count)
            if !successCheck {
                let alert = UIAlertController(title: "Cannot solve Sudoku.".localized, message: "Upload another Picture?".localized, preferredStyle: .alert)
                let yes = UIAlertAction(title: "Yes".localized, style: .default) { _ in
                    self.openLibrary()
                }
                let no = UIAlertAction(title: "No".localized, style: .destructive, handler: nil)
                alert.addAction(no)
                alert.addAction(yes)
                present(alert, animated: true, completion: nil)
                hideIndicator()
                return
            }
            hideIndicator()
            // 풀어진 sudoku 표시
            showNum(solvedSudokuArray, sudokuArray, image)
            ignoreSolve.toggle()
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
                let textFontAttributes = [
                    NSAttributedString.Key.font: UIFont(name: "Helvetica", size: fontSize)!,
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
        picker.sourceType = .photoLibrary
        
        self.present(picker, animated: true, completion: nil)
    }
    
    private func openCamera() {
        picker.sourceType = .camera
        self.present(picker, animated: true, completion: nil)
    }
    
    internal func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        guard let image = info[UIImagePickerController.InfoKey.originalImage] as? UIImage else {
            picker.dismiss(animated: true)
            return
        }
        let fixOrientationImage = image.fixOrientation()
        
        if let detectRectangle = wrapper.detectRectangle(fixOrientationImage) {
            pickerImage.image = detectRectangle[1] as? UIImage
        }
        picker.dismiss(animated: true)
    }
    
    func PhotoAuth() -> Bool {
        // 포토 라이브러리 접근 권한
        let authorizationStatus = PHPhotoLibrary.authorizationStatus()
        
        var isAuth = false
        
        switch authorizationStatus {
        case .authorized: return true // 사용자가 앱에 사진 라이브러리에 대한 액세스 권한을 명시 적으로 부여했습니다.
        case .denied: break // 사용자가 사진 라이브러리에 대한 앱 액세스를 명시 적으로 거부했습니다.
        case .limited: break // ?
        case .notDetermined: // 사진 라이브러리 액세스에는 명시적인 사용자 권한이 필요하지만 사용자가 아직 이러한 권한을 부여하거나 거부하지 않았습니다
            PHPhotoLibrary.requestAuthorization { (state) in
                if state == .authorized {
                    isAuth = true
                }
            }
            return isAuth
        case .restricted: break // 앱이 사진 라이브러리에 액세스 할 수있는 권한이 없으며 사용자는 이러한 권한을 부여 할 수 없습니다.
        default: break
        }
        
        return false;
    }
    
    func CameraAuth() -> Bool {
        return AVCaptureDevice.authorizationStatus(for: .video) == AVAuthorizationStatus.authorized
    }
    
    
    func AuthSettingOpen(AuthString: String) {
        if let AppName = Bundle.main.infoDictionary!["CFBundleName"] as? String {
            let message = "Soldoku is not allowed access to Album. \r\n Do you want to go to the Setting Screen?".localized
            let alert = UIAlertController(title: "Setting".localized, message: message, preferredStyle: .alert)
            
            let cancle = UIAlertAction(title: "Cancel".localized, style: .default) { _ in
                
            }
            let confirm = UIAlertAction(title: "Confirm".localized, style: .default) { (UIAlertAction) in
                UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!)
            }
            alert.addAction(cancle)
            alert.addAction(confirm)
            
            self.present(alert, animated: true, completion: nil)
        }
    }
}

