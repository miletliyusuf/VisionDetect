//
//  VisionDetect.swift
//  VisionDetect
//
//  Created by Yusuf Miletli on 8/21/17.
//  Copyright © 2017 Miletli. All rights reserved.
//

import Foundation
import UIKit
import CoreImage
import AVFoundation
import ImageIO

public protocol VisionDetectDelegate: AnyObject {

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
public extension VisionDetectDelegate {

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

open class VisionDetect: NSObject {

    public weak var delegate: VisionDetectDelegate? = nil

    public enum DetectorAccuracy {
        case BatterySaving
        case HigherPerformance
    }

    public enum CameraDevice {
        case ISightCamera
        case FaceTimeCamera
    }

    public typealias TakenImageStateHandler = ((UIImage) -> Void)
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
    private let stillImageOutput = AVCapturePhotoOutput()
    private var detectedGestures:[VisionDetectGestures] = []
    private var takenImageHandler: TakenImageStateHandler?
    private var takenImage: UIImage? {
        didSet {
            if let image = self.takenImage {
                takenImageHandler?(image)
            }
        }
    }

    public init(cameraPosition: CameraDevice, optimizeFor: DetectorAccuracy) {
        super.init()

        currentOrientation = convertOrientation(deviceOrientation: UIDevice.current.orientation)

        switch cameraPosition {
        case .FaceTimeCamera : self.captureSetup(position: AVCaptureDevice.Position.front)
        case .ISightCamera : self.captureSetup(position: AVCaptureDevice.Position.back)
        }

        var faceDetectorOptions : [String : AnyObject]?

        switch optimizeFor {
        case .BatterySaving : faceDetectorOptions = [CIDetectorAccuracy : CIDetectorAccuracyLow as AnyObject]
        case .HigherPerformance : faceDetectorOptions = [CIDetectorAccuracy : CIDetectorAccuracyHigh as AnyObject]
        }

        self.faceDetector = CIDetector(ofType: CIDetectorTypeFace, context: nil, options: faceDetectorOptions)
    }

    public func addTakenImageChangeHandler(handler: TakenImageStateHandler?) {

        self.takenImageHandler = handler
    }

    //MARK: SETUP OF VIDEOCAPTURE
    public func beginFaceDetection() {
        self.captureSession.startRunning()
        setupSaveToCameraRoll()
    }

    public func endFaceDetection() {
        self.captureSession.stopRunning()
    }

    private func setupSaveToCameraRoll() {
        if captureSession.canAddOutput(stillImageOutput) {
            captureSession.addOutput(stillImageOutput)
        }
    }

    public func saveTakenImageToPhotos() {

        if let image = self.takenImage {
            UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
        }
    }

    public func takeAPicture() {

        if self.stillImageOutput.connection(with: .video) != nil {
            let settings = AVCapturePhotoSettings()
            let previewPixelType = settings.availablePreviewPhotoPixelFormatTypes.first ?? nil
            let previewFormat = [String(kCVPixelBufferPixelFormatTypeKey): previewPixelType,
                                 String(kCVPixelBufferWidthKey): 160,
                                 String(kCVPixelBufferHeightKey): 160]
            settings.previewPhotoFormat = previewFormat as [String : Any]
            self.stillImageOutput.capturePhoto(with: settings, delegate: self)
        }
    }

    private func captureSetup(position: AVCaptureDevice.Position) {
        var captureError: NSError?
        var captureDevice: AVCaptureDevice?

        let devices = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInWideAngleCamera],
            mediaType: .video,
            position: position
        ).devices
        for testedDevice in devices {
            if ((testedDevice as AnyObject).position == position) {
                captureDevice = testedDevice
            }
        }

        if (captureDevice == nil) {
            captureDevice = AVCaptureDevice.default(for: .video)
        }

        var deviceInput : AVCaptureDeviceInput?
        do {
            if let device = captureDevice {
                deviceInput = try AVCaptureDeviceInput(device: device)
            }
        } catch let error as NSError {
            captureError = error
            deviceInput = nil
        }
        captureSession.sessionPreset = .high

        if (captureError == nil) {
            if let input = deviceInput,
                captureSession.canAddInput(input) {
                captureSession.addInput(input)
            }

            self.videoDataOutput = AVCaptureVideoDataOutput()
            self.videoDataOutput?.videoSettings = [
                String(kCVPixelBufferPixelFormatTypeKey): Int(kCVPixelFormatType_32BGRA)
            ]
            self.videoDataOutput?.alwaysDiscardsLateVideoFrames = true
            self.videoDataOutputQueue = DispatchQueue(label: "VideoDataOutputQueue")
            self.videoDataOutput?.setSampleBufferDelegate(self, queue: self.videoDataOutputQueue)

            if let output = self.videoDataOutput,
                captureSession.canAddOutput(output) {
                captureSession.addOutput(output)
            }
        }

        visageCameraView.frame = UIScreen.main.bounds

        let previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer.frame = UIScreen.main.bounds
        previewLayer.videoGravity = .resizeAspectFill
        visageCameraView.layer.addSublayer(previewLayer)
    }

    private func addItemToGestureArray(item:VisionDetectGestures) {
        if !self.detectedGestures.contains(item) {
            self.detectedGestures.append(item)
        }
    }

    var options : [String : AnyObject]?

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

// MARK: - AVCapturePhotoCaptureDelegate

extension VisionDetect: AVCapturePhotoCaptureDelegate {

    public func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {

        if let imageData = photo.fileDataRepresentation(),
            let image = UIImage(data: imageData) {
            self.takenImage = image
        }
    }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate

extension VisionDetect: AVCaptureVideoDataOutputSampleBufferDelegate {

    public func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {

        var sourceImage = CIImage()
        if takenImage == nil {
            let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer)
            let opaqueBuffer = Unmanaged<CVImageBuffer>.passUnretained(imageBuffer!).toOpaque()
            let pixelBuffer = Unmanaged<CVPixelBuffer>.fromOpaque(opaqueBuffer).takeUnretainedValue()
            sourceImage = CIImage(cvPixelBuffer: pixelBuffer, options: nil)
        }
        else {
            if let ciImage = takenImage?.ciImage {
                sourceImage = ciImage
            }
        }

        options = [
            CIDetectorSmile: true as AnyObject,
            CIDetectorEyeBlink: true as AnyObject,
            CIDetectorImageOrientation: 6 as AnyObject
        ]

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
}
