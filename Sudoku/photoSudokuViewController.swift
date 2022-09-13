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
    
    private var session: AVCaptureSession?
    private var previewLayer: AVCaptureVideoPreviewLayer?
    var sudokuSolvingWorkItem: DispatchWorkItem?
    
    var check: Bool = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        preparedSession()
        session?.startRunning()
        
    }
    
    @IBAction func shootingAction(_ sender: Any) {
        if check {
            start()
            check = false
        }
        else {
            sudokuSolvingWorkItem = DispatchWorkItem(block: self.sudokuSolvingQueue)
            DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(250), execute: sudokuSolvingWorkItem!)
            stop()
            check = true
        }
    }
    
    func sudokuSolvingQueue() {
        self.recognizeNum(image: refinedView.image!)
    }
    func start(){
        session?.startRunning()
    }
    func stop(){
        session?.stopRunning()
    }
    
    func preparedSession() {
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
            previewLayer?.frame = cameraView.frame
            cameraView.layer.addSublayer(previewLayer!)
        } catch {
            
        }
        
    }
    
    
    // 비디오 프레임이 들어올 때마다 갱신됨
    /*
     참고
     https://developer.apple.com/documentation/avfoundation/avcapturevideodataoutputsamplebufferdelegate/1385775-captureoutput
     */
    func captureOutput(_ output: AVCaptureOutput, didOutput buffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        //기기의 현재 방향에 따라 화면의 방향도 돌려준다.
        connection.videoOrientation = AVCaptureVideoOrientation(rawValue: UIDevice.current.orientation.rawValue) ?? AVCaptureVideoOrientation.portrait
        
        
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
                let r = CGRect(x: 0, y: y, width: w, height: w)
                let imgCrop = img.cgImage?.cropping(to: r)
                let refinedImage = UIImage(cgImage: imgCrop!)
                
                self.toRefinedView(refinedImage)
            }
        }
        //사용했던 픽셀 주소의 고정을 풀고 재사용이 가능하도록 한다.
        CVPixelBufferUnlockBaseAddress(CVimageBuffer, CVPixelBufferLockFlags(rawValue: CVOptionFlags(0)))
    }
    
    func toRefinedView(_ capturedImage: UIImage) {
        if let detectRectangle = wrapper.detectRectangle(capturedImage){
            refinedView.image = detectRectangle[1] as? UIImage
        }
    }
    
    
    func recognizeNum(image: UIImage) {
        // get sudoku number images
        var sudokuArray:[[Int]] = Array(repeating: Array(repeating: 0, count: 9), count: 9)
        if let r2 = wrapper.sliceImages(image, imageSize: 64, cutOffset: 0) {
            // r2[0]는 sudoku 영역을 9x9로 자르고 각각의 이미지를 64x64 크기로 변환한 UIImage array
            // r2[1]은 디버깅 목적의 9x9로 자른 이미지를 다시 하나에 합쳐 놓은 이미지(제대로 잘렸는지 보기 위한 용도)
            let numImages = r2[0] as! NSArray
            for i in 0..<numImages.count {
                let numimg = numImages[i]
                let col = i % 9
                let row = Int(i / 9)
                let img = numimg as! UIImage
                if let r3 = wrapper.getNumImage(img, imageSize: 64) {
                    // r3[0]는 64x64 크기의 이미지 내에 숫자가 있으면 true, 없으면 false 이다
                    let numExist = (r3[0] as! NSNumber).boolValue
                    if numExist == true {
                        // 숫자가 존재 하는 경우 처리
                        guard let buf = img.UIImageToPixelBuffer() else { return }
                        
                        let model = model_64()
                        guard let pred = try? model.prediction(x: buf) else {
                            break
                        }
                        let length = pred.y.count
                        let doublePtr =  pred.y.dataPointer.bindMemory(to: Double.self, capacity: length)
                        let doubleBuffer = UnsafeBufferPointer(start: doublePtr, count: length)
                        let output = Array(doubleBuffer)
                        let maxVal = output.max()
                        let maxIdx = output.firstIndex(of: maxVal!)
                        
                        sudokuArray[row][col] = maxIdx ?? 0
                    } else {
                        sudokuArray[row][col] = 0
                    }
                } else {
                    sudokuArray[row][col] = 0
                }
            }
            // sudoku 풀이
            
            var solvedSudokuArray = sudokuArray
            
            _ = sudokuCalcuation(&solvedSudokuArray, 0, 0);
            
            // 풀어진 sudoku 표시
            showNum(solvedSudokuArray, sudokuArray, image)
            
            
        }
    }
    
    
    func showNum(_ sudoku: [[Int]], _ solSudoku: [[Int]], _ image: UIImage) {
        UIGraphicsBeginImageContext(refinedView.bounds.size)
        image.draw(in: CGRect(origin: CGPoint.zero, size: refinedView.bounds.size))
        let dx = refinedView.bounds.size.width / 9
        let dy = refinedView.bounds.size.height / 9
        let w = Int(dx)
        let h = Int(dy)
        for row in 0..<9 {
            let y = Int(CGFloat(row) * dy)
            for col in 0..<9 {
                let x = Int(CGFloat(col) * dx)
                var c: UIColor = UIColor(red: 210/255, green: 31/255, blue: 0/255, alpha: 100)
                var fsz: CGFloat = 28
                //인식했던 숫자가 있는 경우 표현하지 않는다.
                if (solSudoku[row][col] != 0) {
                    c = UIColor(red: 210/255, green: 31/255, blue: 81/255, alpha: 0)
                    fsz = 24
                }
                let num = String(sudoku[row][col])
                let textFontAttributes = [
                    NSAttributedString.Key.font: UIFont(name: "Arial", size: fsz)!,
                    NSAttributedString.Key.foregroundColor: c,
                ] as [NSAttributedString.Key : Any]
                let sz = num.size(withAttributes: textFontAttributes)
                let rect: CGRect = CGRect(x: x + Int((dx - sz.width) / 2), y: y + Int((dy - sz.height) / 2), width: w, height: h)
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
    
}

//UIImage에 UIImage를 픽셀버퍼 타입으로 변환시키는 function 추가
extension UIImage {
    func UIImageToPixelBuffer() -> CVPixelBuffer? {
        
        let width = Int(self.size.width)
        let height = Int(self.size.height)
        
        let attrs = [kCVPixelBufferCGImageCompatibilityKey: kCFBooleanTrue, kCVPixelBufferCGBitmapContextCompatibilityKey: kCFBooleanTrue] as CFDictionary
        var pixelBuffer: CVPixelBuffer?
        let status = CVPixelBufferCreate(kCFAllocatorDefault, width, height, kCVPixelFormatType_32ARGB, attrs, &pixelBuffer)
        guard status == kCVReturnSuccess else {
            return nil
        }
        
        CVPixelBufferLockBaseAddress(pixelBuffer!, CVPixelBufferLockFlags(rawValue: 0))
        let pixelData = CVPixelBufferGetBaseAddress(pixelBuffer!)
        
        let rgbColorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(data: pixelData, width: width, height: height, bitsPerComponent: 8, bytesPerRow: CVPixelBufferGetBytesPerRow(pixelBuffer!), space: rgbColorSpace, bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue) else {
            return nil
        }
        
        context.translateBy(x: 0, y: CGFloat(height))
        context.scaleBy(x: 1.0, y: -1.0)
        
        UIGraphicsPushContext(context)
        self.draw(in: CGRect(x: 0, y: 0, width: width, height: height))
        UIGraphicsPopContext()
        CVPixelBufferUnlockBaseAddress(pixelBuffer!, CVPixelBufferLockFlags(rawValue: 0))
        
        return pixelBuffer
    }
}
