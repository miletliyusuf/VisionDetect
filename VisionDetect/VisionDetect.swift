//
//  VisionDetect.swift
//  VisionDetect
//
//  Created by Yusuf Miletli on 8/21/17.
//  Copyright © 2017 Miletli. All rights reserved.
//

import UIKit
import CoreImage
import AVFoundation
import ImageIO

public protocol VisionDetectDelegate {
    func didNoFaceDetected()
    func didFaceDetected()
    func didSmile()
    func didNotSmile()
    func didBlinked()
    func didNotBlinked()
    func didWinked()
    func didNotWinked()
    func didLeftEyeClosed()
    func didLeftEyeOpened()
    func didRightEyeClosed()
    func didRightEyeOpened()
}

///Makes every method is optional
extension VisionDetectDelegate {
    func didNoFaceDetected() { }
    func didFaceDetected() { }
    func didSmile() { }
    func didNotSmile() { }
    func didBlinked() { }
    func didNotBlinked() { }
    func didWinked() { }
    func didNotWinked() { }
    func didLeftEyeClosed() { }
    func didLeftEyeOpened() { }
    func didRightEyeClosed() { }
    func didRightEyeOpened() { }
}

public enum VisionDetectGestures {
    case face
    case noFace
    case smile
    case noSmile
    case blink
    case noBlink
    case wink
    case noWink
    case leftEyeClosed
    case noLeftEyeClosed
    case rightEyeClosed
    case noRightEyeClosed
}

open class VisionDetect: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    
    public var delegate:VisionDetectDelegate? = nil
    
    public enum DetectorAccuracy {
        case BatterySaving
        case HigherPerformance
    }
    
    public enum CameraDevice {
        case ISightCamera
        case FaceTimeCamera
    }
    
    public var onlyFireNotificatonOnStatusChange : Bool = true
    public var visageCameraView : UIView = UIView()
    
    //Private properties of the detected face that can be accessed (read-only) by other classes.
    private(set) var faceDetected : Bool?
    private(set) var faceBounds : CGRect?
    private(set) var faceAngle : CGFloat?
    private(set) var faceAngleDifference : CGFloat?
    private(set) var leftEyePosition : CGPoint?
    private(set) var rightEyePosition : CGPoint?
    
    private(set) var mouthPosition : CGPoint?
    private(set) var hasSmile : Bool?
    private(set) var isBlinking : Bool?
    private(set) var isWinking : Bool?
    private(set) var leftEyeClosed : Bool?
    private(set) var rightEyeClosed : Bool?
    
    //Private variables that cannot be accessed by other classes in any way.
    private var faceDetector : CIDetector?
    private var videoDataOutput : AVCaptureVideoDataOutput?
    private var videoDataOutputQueue : DispatchQueue?
    private var cameraPreviewLayer : AVCaptureVideoPreviewLayer?
    private var captureSession : AVCaptureSession = AVCaptureSession()
    private let notificationCenter : NotificationCenter = NotificationCenter.default
    private var currentOrientation : Int?
    private let stillImageOutput = AVCaptureStillImageOutput()
    private var detectedGestures:[VisionDetectGestures] = []
    
    public init(cameraPosition : CameraDevice, optimizeFor : DetectorAccuracy) {
        super.init()
        
        currentOrientation = convertOrientation(deviceOrientation: UIDevice.current.orientation)
        
        switch cameraPosition {
        case .FaceTimeCamera : self.captureSetup(position: AVCaptureDevicePosition.front)
        case .ISightCamera : self.captureSetup(position: AVCaptureDevicePosition.back)
        }
        
        var faceDetectorOptions : [String : AnyObject]?
        
        switch optimizeFor {
        case .BatterySaving : faceDetectorOptions = [CIDetectorAccuracy : CIDetectorAccuracyLow as AnyObject]
        case .HigherPerformance : faceDetectorOptions = [CIDetectorAccuracy : CIDetectorAccuracyHigh as AnyObject]
        }
        
        self.faceDetector = CIDetector(ofType: CIDetectorTypeFace, context: nil, options: faceDetectorOptions)
    }
    
    //MARK: SETUP OF VIDEOCAPTURE
    public func beginFaceDetection() {
        self.captureSession.startRunning()
        self.setupSaveToCameraRoll()
    }
    
    public func endFaceDetection() {
        self.captureSession.stopRunning()
    }
    
    public func setupSaveToCameraRoll() {
        if captureSession.canAddOutput(stillImageOutput) {
            captureSession.addOutput(stillImageOutput)
        }
    }
    
    public func saveToCamera() {
        if let videoConnection = stillImageOutput.connection(withMediaType: AVMediaTypeVideo) {
            stillImageOutput.captureStillImageAsynchronously(from: videoConnection) {
                (imageDataSampleBuffer, error) -> Void in
                let imageData = AVCaptureStillImageOutput.jpegStillImageNSDataRepresentation(imageDataSampleBuffer)
                UIImageWriteToSavedPhotosAlbum(UIImage(data: imageData!)!, nil, nil, nil)
            }
        }
    }
    
    public func getGestures(from image:UIImage) -> [VisionDetectGestures] {
        self.captureOutput(takenImage: image)
        return self.detectedGestures
    }
    
    public func takeAPicture(completionHandler: @escaping (_ image:UIImage) -> ()) {
        if let videoConnection = stillImageOutput.connection(withMediaType: AVMediaTypeVideo) {
            
            stillImageOutput.captureStillImageAsynchronously(from: videoConnection) {
                (imageDataSampleBuffer, error) -> Void in
                let imageData = AVCaptureStillImageOutput.jpegStillImageNSDataRepresentation(imageDataSampleBuffer)
                let image = UIImage(data: imageData!)
                completionHandler(image!)
            }
        }
    }
    
    private func captureSetup (position : AVCaptureDevicePosition) {
        var captureError : NSError?
        var captureDevice : AVCaptureDevice!
        
        for testedDevice in AVCaptureDevice.devices(withMediaType: AVMediaTypeVideo){
            if ((testedDevice as AnyObject).position == position) {
                captureDevice = testedDevice as! AVCaptureDevice
            }
        }
        
        if (captureDevice == nil) {
            captureDevice = AVCaptureDevice.defaultDevice(withMediaType: AVMediaTypeVideo)
        }
        
        var deviceInput : AVCaptureDeviceInput?
        do {
            deviceInput = try AVCaptureDeviceInput(device: captureDevice)
        } catch let error as NSError {
            captureError = error
            deviceInput = nil
        }
        captureSession.sessionPreset = AVCaptureSessionPresetHigh
        
        if (captureError == nil) {
            if (captureSession.canAddInput(deviceInput)) {
                captureSession.addInput(deviceInput)
            }
            
            self.videoDataOutput = AVCaptureVideoDataOutput()
            self.videoDataOutput!.videoSettings = [kCVPixelBufferPixelFormatTypeKey as AnyHashable: Int(kCVPixelFormatType_32BGRA)]
            self.videoDataOutput!.alwaysDiscardsLateVideoFrames = true
            self.videoDataOutputQueue = DispatchQueue(label:"VideoDataOutputQueue")
            self.videoDataOutput!.setSampleBufferDelegate(self, queue: self.videoDataOutputQueue!)
            
            if (captureSession.canAddOutput(self.videoDataOutput)) {
                captureSession.addOutput(self.videoDataOutput)
            }
        }
        
        visageCameraView.frame = UIScreen.main.bounds
        
        let previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer?.frame = UIScreen.main.bounds
        previewLayer?.videoGravity = AVLayerVideoGravityResizeAspectFill
        visageCameraView.layer.addSublayer(previewLayer!)
    }
    
    private func addItemToGestureArray(item:VisionDetectGestures) {
        if !self.detectedGestures.contains(item) {
            self.detectedGestures.append(item)
        }
    }
    
    var options : [String : AnyObject]?
    
    //MARK: CAPTURE-OUTPUT/ANALYSIS OF FACIAL-FEATURES
    public func captureOutput(_ captureOutput: AVCaptureOutput? = nil, didOutputSampleBuffer sampleBuffer: CMSampleBuffer? = nil, from connection: AVCaptureConnection? = nil,takenImage: UIImage? = nil) {
        var sourceImage = CIImage.init()
        if takenImage == nil {
            let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer!)
            let opaqueBuffer = Unmanaged<CVImageBuffer>.passUnretained(imageBuffer!).toOpaque()
            let pixelBuffer = Unmanaged<CVPixelBuffer>.fromOpaque(opaqueBuffer).takeUnretainedValue()
            sourceImage = CIImage(cvPixelBuffer: pixelBuffer, options: nil)
        }
        else {
            sourceImage = (takenImage?.ciImage)!
        }
        
        
        options = [CIDetectorSmile : true as AnyObject, CIDetectorEyeBlink: true as AnyObject, CIDetectorImageOrientation : 6 as AnyObject]
        
        let features = self.faceDetector!.features(in: sourceImage, options: options)
        
        if (features.count != 0) {
            
            if (onlyFireNotificatonOnStatusChange == true) {
                if (self.faceDetected == false) {
                    self.delegate?.didFaceDetected()
                    self.addItemToGestureArray(item: .face)
                }
            } else {
                self.delegate?.didFaceDetected()
                self.addItemToGestureArray(item: .face)
            }
            
            self.faceDetected = true
            
            for feature in features as! [CIFaceFeature] {
                faceBounds = feature.bounds
                
                if (feature.hasFaceAngle) {
                    
                    if (faceAngle != nil) {
                        faceAngleDifference = CGFloat(feature.faceAngle) - faceAngle!
                    } else {
                        faceAngleDifference = CGFloat(feature.faceAngle)
                    }
                    
                    faceAngle = CGFloat(feature.faceAngle)
                }
                
                if (feature.hasLeftEyePosition) {
                    leftEyePosition = feature.leftEyePosition
                }
                
                if (feature.hasRightEyePosition) {
                    rightEyePosition = feature.rightEyePosition
                }
                
                if (feature.hasMouthPosition) {
                    mouthPosition = feature.mouthPosition
                }
                
                if (feature.hasSmile) {
                    if (onlyFireNotificatonOnStatusChange == true) {
                        if (self.hasSmile == false) {
                            self.delegate?.didSmile()
                            self.addItemToGestureArray(item: .smile)
                        }
                    } else {
                        self.delegate?.didSmile()
                        self.addItemToGestureArray(item: .smile)
                    }
                    
                    hasSmile = feature.hasSmile
                    
                } else {
                    if (onlyFireNotificatonOnStatusChange == true) {
                        if (self.hasSmile == true) {
                            self.delegate?.didNotSmile()
                            self.addItemToGestureArray(item: .noSmile)
                        }
                    } else {
                        self.delegate?.didNotSmile()
                        self.addItemToGestureArray(item: .noSmile)
                    }
                    
                    hasSmile = feature.hasSmile
                }
                
                if (feature.leftEyeClosed || feature.rightEyeClosed) {
                    if (onlyFireNotificatonOnStatusChange == true) {
                        if (self.isWinking == false) {
                            self.delegate?.didWinked()
                            self.addItemToGestureArray(item: .wink)
                        }
                    } else {
                        self.delegate?.didWinked()
                        self.addItemToGestureArray(item: .wink)
                    }
                    
                    isWinking = true
                    
                    if (feature.leftEyeClosed) {
                        if (onlyFireNotificatonOnStatusChange == true) {
                            if (self.leftEyeClosed == false) {
                                self.delegate?.didLeftEyeClosed()
                                self.addItemToGestureArray(item: .leftEyeClosed)
                            }
                        } else {
                            self.delegate?.didLeftEyeClosed()
                            self.addItemToGestureArray(item: .leftEyeClosed)
                        }
                        
                        leftEyeClosed = feature.leftEyeClosed
                    }
                    if (feature.rightEyeClosed) {
                        if (onlyFireNotificatonOnStatusChange == true) {
                            if (self.rightEyeClosed == false) {
                                self.delegate?.didRightEyeClosed()
                                self.addItemToGestureArray(item: .rightEyeClosed)
                            }
                        } else {
                            self.delegate?.didRightEyeClosed()
                            self.addItemToGestureArray(item: .rightEyeClosed)
                        }
                        
                        rightEyeClosed = feature.rightEyeClosed
                    }
                    if (feature.leftEyeClosed && feature.rightEyeClosed) {
                        if (onlyFireNotificatonOnStatusChange == true) {
                            if (self.isBlinking == false) {
                                self.delegate?.didBlinked()
                                self.addItemToGestureArray(item: .blink)
                            }
                        } else {
                            self.delegate?.didBlinked()
                            self.addItemToGestureArray(item: .blink)
                        }
                        
                        isBlinking = true
                    }
                } else {
                    
                    if (onlyFireNotificatonOnStatusChange == true) {
                        if (self.isBlinking == true) {
                            self.delegate?.didNotBlinked()
                            self.addItemToGestureArray(item: .noBlink)
                        }
                        if (self.isWinking == true) {
                            self.delegate?.didNotWinked()
                            self.addItemToGestureArray(item: .noWink)
                        }
                        if (self.leftEyeClosed == true) {
                            self.delegate?.didLeftEyeOpened()
                            self.addItemToGestureArray(item: .noLeftEyeClosed)
                        }
                        if (self.rightEyeClosed == true) {
                            self.delegate?.didRightEyeOpened()
                            self.addItemToGestureArray(item: .noRightEyeClosed)
                        }
                    } else {
                        self.delegate?.didNotBlinked()
                        self.addItemToGestureArray(item: .noBlink)
                        self.delegate?.didNotWinked()
                        self.addItemToGestureArray(item: .noWink)
                        self.delegate?.didLeftEyeOpened()
                        self.addItemToGestureArray(item: .noLeftEyeClosed)
                        self.delegate?.didRightEyeOpened()
                        self.addItemToGestureArray(item: .noRightEyeClosed)
                    }
                    
                    isBlinking = false
                    isWinking = false
                    leftEyeClosed = feature.leftEyeClosed
                    rightEyeClosed = feature.rightEyeClosed
                }
            }
        } else {
            if (onlyFireNotificatonOnStatusChange == true) {
                if (self.faceDetected == true) {
                    self.delegate?.didNoFaceDetected()
                    self.addItemToGestureArray(item: .noFace)
                }
            } else {
                self.delegate?.didNoFaceDetected()
                self.addItemToGestureArray(item: .noFace)
            }
            
            self.faceDetected = false
        }
    }
    
    //TODO: 🚧 HELPER TO CONVERT BETWEEN UIDEVICEORIENTATION AND CIDETECTORORIENTATION 🚧
    private func convertOrientation(deviceOrientation: UIDeviceOrientation) -> Int {
        var orientation: Int = 0
        switch deviceOrientation {
        case .portrait:
            orientation = 6
        case .portraitUpsideDown:
            orientation = 2
        case .landscapeLeft:
            orientation = 3
        case .landscapeRight:
            orientation = 4
        default : orientation = 1
        }
        return orientation
    }
}
