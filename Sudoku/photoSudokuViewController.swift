//
//  photoSudokuViewController.swift
//  Sudoku
//
//  Created by 이주화 on 2022/09/06.
//

import UIKit
import AVFoundation
import Vision

final class photoSudokuViewController: UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate {
    
    @IBOutlet weak var cameraView: UIImageView!
    @IBOutlet weak var refinedView: UIImageView!
    
    private var session: AVCaptureSession?
    private var previewLayer: AVCaptureVideoPreviewLayer?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        preparedSession()
        session?.startRunning()
        
    }
    
    func preparedSession() {
        let camera = AVCaptureDevice.default(.builtInUltraWideCamera, for: .video, position: .back)
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
        
        guard let frame = CMSampleBufferGetImageBuffer(buffer) else {
            debugPrint("unable to get image from sample buffer")
            return
        }
        
        self.detectRectangle(in: frame)
    }
    
    func toRefinedView(_ capturedImage: UIImage) {
        refinedView.image = capturedImage
    }
    
    func detectRectangle(in image: CVPixelBuffer) {
       
        let request = VNDetectRectanglesRequest(completionHandler: { (request: VNRequest, error: Error?) in
            DispatchQueue.main.async {
                
                guard let results = request.results as? [VNRectangleObservation] else { return }
                
                
                guard let rect = results.first else{return}
                
                self.refinedView.contentMode = .scaleAspectFit
                self.refinedView.image = self.imageExtraction(rect, from: image)
            }
        })
        
        
        request.minimumAspectRatio = VNAspectRatio(0.3)
        request.maximumAspectRatio = VNAspectRatio(0.9)
        request.minimumSize = Float(0.3)
        request.maximumObservations = 1
        
        
        let imageRequestHandler = VNImageRequestHandler(cvPixelBuffer: image, options: [:])
        try? imageRequestHandler.perform([request])
    }
    
    func imageExtraction(_ observation: VNRectangleObservation, from buffer: CVImageBuffer) -> UIImage {
        var ciImage = CIImage(cvImageBuffer: buffer)
        
        let topLeft = observation.topLeft.scaled(to: ciImage.extent.size)
        let topRight = observation.topRight.scaled(to: ciImage.extent.size)
        let bottomLeft = observation.bottomLeft.scaled(to: ciImage.extent.size)
        let bottomRight = observation.bottomRight.scaled(to: ciImage.extent.size)
        
        
        ciImage = ciImage.applyingFilter("CIPerspectiveCorrection", parameters: [
            "inputTopLeft": CIVector(cgPoint: topLeft),
            "inputTopRight": CIVector(cgPoint: topRight),
            "inputBottomLeft": CIVector(cgPoint: bottomLeft),
            "inputBottomRight": CIVector(cgPoint: bottomRight),
        ])
        
        let context = CIContext()
        let cgImage = context.createCGImage(ciImage, from: ciImage.extent)
        let output = UIImage(cgImage: cgImage!)
        
        
        return output
    }
    
    /*
     https://stijnoomes.com/access-camera-pixels-with-av-foundation/
     참고
     */
    
    
    
}

extension CGPoint {
    func scaled(to size: CGSize) -> CGPoint {
        return CGPoint(x: self.x * size.width,
                       y: self.y * size.height)
    }
}

