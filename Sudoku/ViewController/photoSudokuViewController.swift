//
//  photoSudokuViewController.swift
//  Sudoku
//
//  Created by 이주화 on 2022/09/06.
//

import UIKit
import AVFoundation
import CoreML
import Vision

final class photoSudokuViewController: UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate {
    
    @IBOutlet weak var cameraView: UIImageView!
    @IBOutlet weak var refinedView: UIImageView!
    @IBOutlet weak var shooting: UIButton!
    @IBOutlet weak var loadingView: UIView!
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!
    
    private var session: AVCaptureSession?
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var count: Int = 0
    private var sudokuSolvingWorkItem: DispatchWorkItem?
    private var check: Bool = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.navigationController?.navigationBar.tintColor = .black
        hideIndicator()
        preparedSession()
        session?.startRunning()
        shooting.layer.cornerRadius = 10
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if !self.CameraAuth() {
            self.AuthSettingOpen(AuthString: "Camera")
        }
    }
    
    @IBAction func shootingAction(_ sender: Any) {
        if check {
            cameraStart()
            check = false
        }
        else {
            sudokuSolvingWorkItem = DispatchWorkItem(block: sudokuSolvingQueue)
            DispatchQueue.main.async(execute: sudokuSolvingWorkItem!)
            cameraStop()
            check = true
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
        self.recognizeNum(image: refinedView.image!)
    }
    
    private func cameraStart(){
        session?.startRunning()
    }
    
    private func cameraStop(){
        session?.stopRunning()
        showIndicator()
    }
    
    private func preparedSession() {
        let camera = AVCaptureDevice.default(for: AVMediaType.video)
        do {
            let cameraInput = try AVCaptureDeviceInput(device: camera!)
            
            session = AVCaptureSession()
            session?.sessionPreset = AVCaptureSession.Preset.hd1280x720
            //해상도 지정
            session?.addInput(cameraInput)
            
            let videoOutput = AVCaptureVideoDataOutput()
            /*
             https://developer.apple.com/documentation/avfoundation/avcapturevideodataoutput
             */
            
            //픽셀버퍼 핸들링을 용이하게 하기위해 BGRA타입으로 변환
            videoOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as AnyHashable as! String: NSNumber(value: kCVPixelFormatType_32BGRA)]
            
            let sessionQueue = DispatchQueue(label: "camera")
            videoOutput.setSampleBufferDelegate(self, queue: sessionQueue)
            session?.addOutput(videoOutput)
            
            previewLayer = AVCaptureVideoPreviewLayer(session: session!)
            
            previewLayer?.videoGravity = AVLayerVideoGravity.resizeAspectFill
            previewLayer?.connection?.videoOrientation = AVCaptureVideoOrientation.portrait
            previewLayer?.frame = cameraView.bounds
            cameraView.layer.addSublayer(previewLayer!)
        } catch {
            
        }
        
    }
    
    // 비디오 프레임이 들어올 때마다 갱신됨
    /*
     참고
     https://developer.apple.com/documentation/avfoundation/avcapturevideodataoutputsamplebufferdelegate/1385775-captureoutput
     */
    internal func captureOutput(_ output: AVCaptureOutput, didOutput buffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        //기기의 현재 방향에 따라 화면의 방향도 돌려준다.
        connection.videoOrientation = AVCaptureVideoOrientation.portrait
        
        
        /*
         https://developer.apple.com/documentation/coremedia/1489236-cmsamplebuffergetimagebuffer
         */
        //CMSampleBuffer를 CVImageBuffer로 변환시켜준다.
        guard let CVimageBuffer = CMSampleBufferGetImageBuffer(buffer) else {
            return
        }
        
        /*
         CVPixelBufferLockBaseAddress:
         https://developer.apple.com/documentation/corevideo/1457128-cvpixelbufferlockbaseaddress
         픽셀의 주소를 고정시켜준다.
         */
        CVPixelBufferLockBaseAddress(CVimageBuffer, CVPixelBufferLockFlags(rawValue: CVOptionFlags(0)))
        //이미지의 넓이 구하기
        let width = CVPixelBufferGetWidth(CVimageBuffer)
        let height = CVPixelBufferGetHeight(CVimageBuffer)
        
        //이미지에서 사용되는 각각의 Component가 사용하는 비트 수 선언
        let bitsPerComponent = 8
        
        //이미지의 row에 있는 바이트를 구한다.
        let bytesRow = CVPixelBufferGetBytesPerRow(CVimageBuffer)
        
        //이미지의 주소값을 구한다.
        guard let imageAddress = CVPixelBufferGetBaseAddress(CVimageBuffer) else {
            return
        }
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        
        //비트 연산자 or 을 이용해 비트를 정리한다.
        let bitmap = CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue
        let context = CGContext(data: imageAddress, width: width, height: height, bitsPerComponent: bitsPerComponent, bytesPerRow: bytesRow, space:  colorSpace, bitmapInfo: bitmap)
        if let newContext = context {
            let frame = newContext.makeImage()
            DispatchQueue.main.async {
                let img = UIImage(cgImage: frame!)
                // crop
                let w = img.size.width
                let y = (img.size.height - w) / 2
                let rect = CGRect(x: 0, y: y, width: w, height: w)
                let imgCrop = img.cgImage?.cropping(to: rect)
                let refinedImage = UIImage(cgImage: imgCrop!)
                self.toRefinedView(refinedImage)
            }
        }
        //사용했던 픽셀 주소의 고정을 풀고 재사용이 가능하도록 한다.
        CVPixelBufferUnlockBaseAddress(CVimageBuffer, CVPixelBufferLockFlags(rawValue: CVOptionFlags(0)))
    }
    
    private func toRefinedView(_ capturedImage: UIImage) {
        if let detectRectangle = wrapper.detectRectangle(capturedImage){
            refinedView.image = detectRectangle[1] as? UIImage
        }
    }
    
    private func recognizeNum(image: UIImage) {
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
            let successCheck = sudokuCalculation(&solvedSudokuArray, 0, 0, &count)
            if !successCheck {
                let alert = UIAlertController(title: "Fail.", message: "Take a Picture Again.", preferredStyle: .alert)
                let yes = UIAlertAction(title: "Yes", style: .default, handler: nil)
                alert.addAction(yes)
                present(alert, animated: true, completion: nil)
                session?.startRunning()
                hideIndicator()
                return
            }
            hideIndicator()
            // 풀어진 sudoku 표시
            showNum(solvedSudokuArray, sudokuArray, image)
        }
    }
    
    private func showNum(_ sudoku: [[Int]], _ solSudoku: [[Int]], _ image: UIImage) {
        UIGraphicsBeginImageContext(refinedView.bounds.size)
        image.draw(in: CGRect(origin: CGPoint.zero, size: refinedView.bounds.size))
        let cutViewWidth = refinedView.bounds.size.width / 9
        let cutViewHeight = refinedView.bounds.size.height / 9
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
        refinedView.image = newImage
    }
    
    
    /*
     https://stijnoomes.com/access-camera-pixels-with-av-foundation/
     참고
     */
    
    func CameraAuth() -> Bool {
        return AVCaptureDevice.authorizationStatus(for: .video) == AVAuthorizationStatus.authorized
    }
    
    private func AuthSettingOpen(AuthString: String) {
        if !CameraAuth(){
            if let AppName = Bundle.main.infoDictionary!["CFBundleName"] as? String {
                let message = "If didn't allow the camera permission, \r\n Would like to go to the Setting Screen?"
                let alert = UIAlertController(title: "Setting", message: message, preferredStyle: .alert)
                
                let cancle = UIAlertAction(title: "Cancel", style: .default) { _ in }
                let confirm = UIAlertAction(title: "Confirm", style: .default) { (UIAlertAction) in
                    UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!)
                }
                alert.addAction(cancle)
                alert.addAction(confirm)
                
                self.present(alert, animated: true, completion: nil)
            }
        }
    }
}
    
