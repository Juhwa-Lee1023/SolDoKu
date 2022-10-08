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
    
    @IBOutlet weak var refinedViewLabel: UILabel!
    @IBOutlet weak var cameraViewLabel: UILabel!
    @IBOutlet weak var cameraView: UIImageView!
    @IBOutlet weak var refinedView: UIImageView!
    @IBOutlet weak var shooting: UIButton!
    @IBOutlet weak var loadingView: UIView!
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!
    
    private var period: Int = 0 // 30프레임마다 숫자 인식을 하기위한 변수 선언
    private var particleLayer = CAShapeLayer()
    private var particlePath = UIBezierPath()
    private var session: AVCaptureSession?
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var count: Int = 0
    private var sudokuSolvingWorkItem: DispatchWorkItem?
    private var ignoreSolve: Bool = false
    private let bounds = UIScreen.main.bounds
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.navigationController?.navigationBar.tintColor = .black
        hideIndicator()
        preparedSession()
        session?.startRunning()
        shooting.layer.cornerRadius = 10
        setButton()
        refinedView.image = UIImage(named: "sudoku")
        setLayout()
        addRefinedViewAction()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if !self.CameraAuth() {
            self.AuthSettingOpen(AuthString: "Camera")
        }
    }
    
    @IBAction func shootingAction(_ sender: Any) {
        if shooting.titleLabel?.text == "Shoot Again" {
            refinedView.image = UIImage(named: "sudoku")
            cameraStart()
            shooting.setTitle("Shooting Sudoku", for: .normal)
        } else {
            sudokuSolvingWorkItem = DispatchWorkItem(block: sudokuSolvingQueue)
            DispatchQueue.main.async(execute: sudokuSolvingWorkItem!)
            cameraStop()
            shooting.setTitle("Shoot Again", for: .normal)
        }
    }
    
    @objc func imageTapped(sender: UITapGestureRecognizer) {
        if shooting.titleLabel?.text == "Shoot Again" {
            refinedView.image = UIImage(named: "sudoku")
            session?.startRunning()
            shooting.setTitle("Shooting Sudoku", for: .normal)
        }
        else {
            let sessionStatus = session?.isRunning ?? false
            if sessionStatus {
                cameraViewLabel.isHidden = true
                session?.stopRunning()
            } else {
                refinedView.image = UIImage(named: "sudoku")
                session?.startRunning()
            }
        }
    }
    
    private func addRefinedViewAction() {
        let tapGR = UITapGestureRecognizer(target: self, action: #selector(self.imageTapped))
        refinedView.addGestureRecognizer(tapGR)
        refinedView.isUserInteractionEnabled = true
    }
    private func setLayout() {
        if ((bounds.width / bounds.height) <= 9/19) {
            cameraView.snp.makeConstraints() { make in
                make.centerX.equalToSuperview()
                make.top.equalTo(self.view.safeAreaLayoutGuide).offset(1)
                make.leading.equalTo(self.view).offset(bounds.width * 0.075)
                make.trailing.equalTo(self.view).offset(-(bounds.width * 0.075))
                make.size.width.height.equalTo(bounds.width * 0.85)
            }
            
            refinedView.snp.makeConstraints() { make in
                make.centerX.equalToSuperview()
                make.top.equalTo(cameraView.snp.bottom).offset(3)
                make.leading.equalTo(self.view).offset(bounds.width * 0.075)
                make.trailing.equalTo(self.view).offset(-(bounds.width * 0.075))
                make.size.width.height.equalTo(bounds.width * 0.85)
            }
            
            loadingView.snp.makeConstraints() { make in
                make.centerX.equalToSuperview()
                make.top.equalTo(cameraView.snp.bottom).offset(3)
                make.leading.equalTo(self.view).offset(bounds.width * 0.075)
                make.trailing.equalTo(self.view).offset(-(bounds.width * 0.075))
                make.size.width.height.equalTo(bounds.width * 0.85)
            }
            
            activityIndicator.snp.makeConstraints() { make in
                make.centerX.equalToSuperview()
                make.top.equalTo(loadingView.snp.top).offset(loadingView.frame.height * 0.45)
            }
            
            cameraViewLabel.snp.makeConstraints() { make in
                make.centerX.equalToSuperview()
                make.top.equalTo(cameraView.snp.top).offset(loadingView.frame.height * 0.45)
            }
            
            refinedViewLabel.snp.makeConstraints() { make in
                make.centerX.equalToSuperview()
                make.top.equalTo(refinedView.snp.top).offset(refinedView.frame.height * 0.7)
            }
            
            shooting.snp.makeConstraints() { make in
                make.centerX.equalToSuperview()
                make.top.equalTo(refinedView.snp.bottom).offset(5)
                make.leading.equalTo(self.view).offset(bounds.width * 0.075)
                make.trailing.equalTo(self.view).offset(-(bounds.width * 0.075))
                make.size.width.equalTo(bounds.width * 0.85)
                make.size.height.equalTo(bounds.width * 0.85 * 1/7)
            }
        } else {
            cameraView.snp.makeConstraints() { make in
                make.centerX.equalToSuperview()
                make.top.equalTo(self.view.safeAreaLayoutGuide).offset(1)
                make.leading.equalTo(self.view).offset(bounds.width * 0.125)
                make.trailing.equalTo(self.view).offset(-(bounds.width * 0.125))
                make.size.width.height.equalTo(bounds.width * 0.75)
            }
            
            refinedView.snp.makeConstraints() { make in
                make.centerX.equalToSuperview()
                make.top.equalTo(cameraView.snp.bottom).offset(3)
                make.leading.equalTo(self.view).offset(bounds.width * 0.125)
                make.trailing.equalTo(self.view).offset(-(bounds.width * 0.125))
                make.size.width.height.equalTo(bounds.width * 0.75)
            }
            
            loadingView.snp.makeConstraints() { make in
                make.centerX.equalToSuperview()
                make.top.equalTo(cameraView.snp.bottom).offset(3)
                make.leading.equalTo(self.view).offset(bounds.width * 0.125)
                make.trailing.equalTo(self.view).offset(-(bounds.width * 0.125))
                make.size.width.height.equalTo(bounds.width * 0.75)
            }
            
            activityIndicator.snp.makeConstraints() { make in
                make.centerX.equalToSuperview()
                make.top.equalTo(loadingView.snp.top).offset(loadingView.frame.height * 0.45)
            }
            
            cameraViewLabel.snp.makeConstraints() { make in
                make.centerX.equalToSuperview()
                make.top.equalTo(cameraView.snp.top).offset(loadingView.frame.height * 0.45)
            }
            
            refinedViewLabel.snp.makeConstraints() { make in
                make.centerX.equalToSuperview()
                make.top.equalTo(refinedView.snp.top).offset(refinedView.frame.height * 0.7)
            }
            
            shooting.snp.makeConstraints() { make in
                make.centerX.equalToSuperview()
                make.top.equalTo(refinedView.snp.bottom).offset(5)
                make.leading.equalTo(self.view).offset(bounds.width * 0.125)
                make.trailing.equalTo(self.view).offset(-(bounds.width * 0.125))
                make.size.width.height.equalTo(bounds.width * 0.75)
                make.size.height.equalTo(bounds.width * 0.75 * 1/7)
            }
        }
    }
    
    private func setButton() {
        shooting.setTitle("Shooting Sudoku", for: .normal)
        shooting.layer.cornerRadius = 10
        shooting.backgroundColor = UIColor.sudokuColor(.sudokuDeepButton)
        shooting.titleLabel?.textColor = .white
        shooting.titleLabel?.font = .boldSystemFont(ofSize: 30)
        shooting.titleLabel?.minimumScaleFactor = 0.5
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
        cameraViewLabel.isHidden = true
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
        // 인식된 영역이 너무 작을 경우 숫자 인식을 하지 않기 위한 변수 선언
        var valueX: Float = 0
        var valueY: Float = 0
        var valueX2: Float = 0
        var valueY2: Float = 0
        
        if let detectRect = wrapper.detectRect(capturedImage){
            let cg: [CGPoint] = detectRect as! [CGPoint] // OpenCV로 인식한 스도쿠 영역의 좌표
            valueX = Float(cg[0].x - cg[3].x)
            valueY = Float(cg[0].y - cg[1].y)
            valueX2 = Float(cg[1].x - cg[2].x)
            valueY2 = Float(cg[2].y - cg[3].y)
            drawRectangle(rect: cg)
            cameraView.layer.addSublayer(particleLayer)
        }
        period += 1
        
        // 30프레임마다 영역의 크기가 일정 이상일때 숫자 인식 모델을 통해 숫자 인식
        if period >= 30 && abs(valueX) > 100 && abs(valueY) > 100 && abs(valueX2) > 100 && abs(valueY2) > 100 {
            if let detectRectangle = wrapper.detectRectangle(capturedImage) {
                recognizePresentNum(image: detectRectangle[1] as! UIImage)
            }
            period = 0
        }
        
    }
    
    func drawRectangle(rect: [CGPoint]) {
        // 카메라에서 인식한 좌표와 인식한 영역을 그리는 곳의 좌표가 달라서 좌표를 계산하기 위한 변수 선언
        let widthSize = cameraView.bounds.width / UIScreen.main.bounds.width
        let widthHeight = cameraView.bounds.height / UIScreen.main.bounds.height
        let framesize = widthSize / widthHeight
        
        particleLayer.fillColor = UIColor.clear.cgColor
        particleLayer.strokeColor = UIColor.red.cgColor
        particleLayer.lineWidth = 5
        particlePath.removeAllPoints()
        
        particlePath.move(to: CGPoint(x: rect[0].x / framesize, y: rect[0].y / framesize))
        particlePath.addLine(to: CGPoint(x: rect[1].x / framesize, y: rect[1].y / framesize))
        particlePath.addLine(to: CGPoint(x: rect[2].x / framesize, y: rect[2].y / framesize))
        particlePath.addLine(to: CGPoint(x: rect[3].x / framesize, y: rect[3].y / framesize))
        particlePath.close()
        
        particleLayer.path = particlePath.cgPath
        
    }
    
    private func recognizePresentNum(image: UIImage) {
        // get sudoku number images
        var sudokuArray:[[Int]] = Array(repeating: Array(repeating: 0, count: 9), count: 9)
        if let UIImgaeSliceArr = wrapper.sliceImages(image, imageSize: 64, cutOffset: 0) {
            let numImages = UIImgaeSliceArr[0] as! NSArray
            for i in 0..<numImages.count {
                let numImg = numImages[i]
                let col = i % 9
                let row = Int(i / 9)
                let img = numImg as! UIImage
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
        }
        guard let image = UIImage(named: "sudoku") else { return }
        showPresentNum(sudokuArray, image)
    }
    
    private func recognizeNum(image: UIImage) {
        // get sudoku number images
        var sudokuArray:[[Int]] = Array(repeating: Array(repeating: 0, count: 9), count: 9)
        var sudokuNumbersCount: Int = 0
        if let UIImgaeSliceArr = wrapper.sliceImages(image, imageSize: 64, cutOffset: 0) {
            let numImages = UIImgaeSliceArr[0] as! NSArray
            for i in 0..<numImages.count {
                let numImg = numImages[i]
                let col = i % 9
                let row = Int(i / 9)
                let img = numImg as! UIImage
                if let sliceNumImage = wrapper.getNumImage(img, imageSize: 64) {
                    // 이미지 내에 숫자가 있으면 true, 없으면 false 이다
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
                    let alert = UIAlertController(title: "Really want to Solve?", message: "Sudoku Solve requires more than 17 numbers.", preferredStyle: .alert)
                    let yes = UIAlertAction(title: "Yes", style: .default) { _ in
                        self.hideIndicator()
                        self.ignoreSolve.toggle()
                        self.recognizeNum(image: image)
                    }
                    let no = UIAlertAction(title: "No", style: .destructive) { _ in
                        self.hideIndicator()
                        self.shooting.setTitle("Shooting Sudoku", for: .normal)
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
            solveShowNum(solvedSudokuArray, sudokuArray, image)
            ignoreSolve.toggle()
        }
    }
    
    private func showPresentNum(_ sudoku: [[Int]], _ image: UIImage) {
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
                var fontColor: UIColor = UIColor.black
                let fontSize: CGFloat = 28
                //인식했던 숫자가 있는 경우 표현하지 않는다.
                if (sudoku[row][col] == 0) {
                    fontColor = UIColor.sudokuColor(.sudokuEmpty)
                }
                let num = String(sudoku[row][col])
                let textFontAttributes = [
                    NSAttributedString.Key.font: UIFont(name: "System Font", size: fontSize)!,
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
    
    private func solveShowNum(_ sudoku: [[Int]], _ solSudoku: [[Int]], _ image: UIImage) {
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
                    NSAttributedString.Key.font: UIFont(name: "System Font", size: fontSize)!,
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

