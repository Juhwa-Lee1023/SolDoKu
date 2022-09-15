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

class pickerSudokuViewController: UIViewController {

    @IBOutlet weak var photoPicker: UIButton!
    @IBOutlet weak var solSudoku: UIButton!
    
    @IBOutlet weak var pickerImage: UIImageView!
    
    
    var sudokuSolvingWorkItem: DispatchWorkItem?
    var count:Int = 0
    let picker = UIImagePickerController()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        picker.delegate = self
        // Do any additional setup after loading the view.
    }
    

    
    @IBAction func shootPhotoPicker(_ sender: UIButton) {
        let alert = UIAlertController(title: "Select", message: nil, preferredStyle: .actionSheet)
        let library = UIAlertAction(title: "Album", style: .default) { (action) in
            self.openLibrary()
        }
        let camera = UIAlertAction(title: "Camera", style: .default) { (action) in
            self.openCamera()
        }
        let cancel = UIAlertAction(title: "Cancel", style: .cancel, handler: nil)
        
        alert.addAction(library)
        alert.addAction(camera)
        alert.addAction(cancel)
        
        present(alert, animated: true, completion: nil)
    }
    
    @IBAction func shootSolSudoku(_ sender: Any) {
        if pickerImage.image != nil {
            sudokuSolvingWorkItem = DispatchWorkItem(block: self.sudokuSolvingQueue)
            DispatchQueue.main.async(execute: sudokuSolvingWorkItem!)
        } else {
            let alret = UIAlertController(title: "사진이 업로드 되지 않았습니다.", message: "사진을 업로드 하시겠습니까?", preferredStyle: .alert)
            let yes = UIAlertAction(title: "네", style: .default) { (action) in
                self.openLibrary()
            }
            let no = UIAlertAction(title: "아니요", style: .destructive, handler: nil)
            alret.addAction(no)
            alret.addAction(yes)
            present(alret, animated: true, completion: nil)
        }
        
    }
    
    func sudokuSolvingQueue() {
        self.recognizeNum(image: pickerImage.image!)
    }
    
    func recognizeNum(image: UIImage) {
        // get sudoku number images
        var sudokuArray:[[Int]] = Array(repeating: Array(repeating: 0, count: 9), count: 9)
        if let UIImgaeSliceArr = wrapper.sliceImages(image, imageSize: 64, cutOffset: 0) {
            let numImages = UIImgaeSliceArr[0] as! NSArray
            for i in 0..<numImages.count {
                let numimg = numImages[i]
                let col = i % 9
                let row = Int(i / 9)
                let img = numimg as! UIImage
                if let sliceNumImage = wrapper.getNumImage(img, imageSize: 64) {
                    // r3[0]는 64x64 크기의 이미지 내에 숫자가 있으면 true, 없으면 false 이다
                    let numExist = (sliceNumImage[0] as! NSNumber).boolValue
                    if numExist == true {
                        // 숫자가 존재 하는 경우 처리
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
            // sudoku 풀이
            
            var solvedSudokuArray = sudokuArray
            count = 0
            let successCheck = sudokuCalcuation(&solvedSudokuArray, 0, 0, &count);
            if !successCheck && count > 300 {
                let alret = UIAlertController(title: "스도쿠 문제를 풀이할 수 없습니다.", message: "다른 사진을 업로드 하시겠습니까?", preferredStyle: .alert)
                let yes = UIAlertAction(title: "네", style: .default) { (action) in
                    self.openLibrary()
                }
                let no = UIAlertAction(title: "아니요", style: .destructive, handler: nil)
                alret.addAction(no)
                alret.addAction(yes)
                present(alret, animated: true, completion: nil)
                return
            }
            
            // 풀어진 sudoku 표시
            showNum(solvedSudokuArray, sudokuArray, image)
            
            
        }
    }
    
    
    func showNum(_ sudoku: [[Int]], _ solSudoku: [[Int]], _ image: UIImage) {
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
                var fontColor: UIColor = UIColor(red: 210/255, green: 31/255, blue: 0/255, alpha: 100)
                let fontSize: CGFloat = 28
                //인식했던 숫자가 있는 경우 표현하지 않는다.
                if (solSudoku[row][col] != 0) {
                    fontColor = UIColor(red: 210/255, green: 31/255, blue: 81/255, alpha: 0)
                }
                let num = String(sudoku[row][col])
                let textFontAttributes = [
                    NSAttributedString.Key.font: UIFont(name: "Arial", size: fontSize)!,
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
    func openLibrary() {
        picker.sourceType = .photoLibrary
        
        self.present(picker, animated: false, completion: nil)
    }
    
    func openCamera() {
        picker.sourceType = .camera
        self.present(picker, animated: false, completion: nil)
    }
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        guard let image = info[UIImagePickerController.InfoKey.originalImage] as? UIImage else {
            picker.dismiss(animated: true)
            return
        }
        let fixOrientationImage = image.fixOrientation()
        
        if let detectRectangle = wrapper.detectRectangle(fixOrientationImage){
            pickerImage.image = detectRectangle[1] as? UIImage
        }
        picker.dismiss(animated: true)
    }
    
}

extension UIImage {

    func fixOrientation() -> UIImage {

        // 이미지의 방향이 올바를 경우 수정하지 않는다.
        if ( self.imageOrientation == UIImage.Orientation.up ) {
            return self;
        }

        // 이미지를 변환시키기 위한 함수 선언
        var transform: CGAffineTransform = CGAffineTransform.identity

        // 이미지의 상태에 맞게 이미지를 돌린다.
        if ( self.imageOrientation == UIImage.Orientation.down || self.imageOrientation == UIImage.Orientation.downMirrored ) {
            transform = transform.translatedBy(x: self.size.width, y: self.size.height)
            transform = transform.rotated(by: CGFloat(Double.pi))
        }

        if ( self.imageOrientation == UIImage.Orientation.left || self.imageOrientation == UIImage.Orientation.leftMirrored ) {
            transform = transform.translatedBy(x: self.size.width, y: 0)
            transform = transform.rotated(by: CGFloat(Double.pi / 2.0))
        }

        if ( self.imageOrientation == UIImage.Orientation.right || self.imageOrientation == UIImage.Orientation.rightMirrored ) {
            transform = transform.translatedBy(x: 0, y: self.size.height);
            transform = transform.rotated(by: CGFloat(-Double.pi / 2.0));
        }

        if ( self.imageOrientation == UIImage.Orientation.upMirrored || self.imageOrientation == UIImage.Orientation.downMirrored ) {
            transform = transform.translatedBy(x: self.size.width, y: 0)
            transform = transform.scaledBy(x: -1, y: 1)
        }

        if ( self.imageOrientation == UIImage.Orientation.leftMirrored || self.imageOrientation == UIImage.Orientation.rightMirrored ) {
            transform = transform.translatedBy(x: self.size.height, y: 0);
            transform = transform.scaledBy(x: -1, y: 1);
        }

        // 이미지 변환용 값 선언
        let cgValue: CGContext = CGContext(data: nil, width: Int(self.size.width), height: Int(self.size.height),
                                                      bitsPerComponent: self.cgImage!.bitsPerComponent, bytesPerRow: 0,
                                                      space: self.cgImage!.colorSpace!,
                                                      bitmapInfo: self.cgImage!.bitmapInfo.rawValue)!;
        
        cgValue.concatenate(transform)

        if ( self.imageOrientation == UIImage.Orientation.left ||
             self.imageOrientation == UIImage.Orientation.leftMirrored ||
             self.imageOrientation == UIImage.Orientation.right ||
             self.imageOrientation == UIImage.Orientation.rightMirrored ) {
            cgValue.draw(self.cgImage!, in: CGRect(x: 0,y: 0,width: self.size.height,height: self.size.width))
        } else {
            cgValue.draw(self.cgImage!, in: CGRect(x: 0,y: 0,width: self.size.width,height: self.size.height))
        }

        return UIImage(cgImage: cgValue.makeImage()!)
    }
}
