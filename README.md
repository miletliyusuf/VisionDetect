![VisionDetector](https://preview.ibb.co/hpJGK5/Vision_Detector_Logo.png)
> Short blurb about what your product does.

[![Swift Version][swift-image]][swift-url]
[![Build Status][travis-image]][travis-url]
[![License][license-image]][license-url]
[![Carthage compatible](https://img.shields.io/badge/Carthage-compatible-4BC51D.svg?style=flat)](https://github.com/Carthage/Carthage)
[![CocoaPods Compatible](https://img.shields.io/cocoapods/v/EZSwiftExtensions.svg)](https://img.shields.io/cocoapods/v/LFAlertController.svg)  
[![Platform](https://img.shields.io/cocoapods/p/LFAlertController.svg?style=flat)](http://cocoapods.org/pods/LFAlertController)
[![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen.svg?style=flat-square)](http://makeapullrequest.com)

One to two paragraph statement about your product and what it does.

## Delegate Methods

``` swift
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
```

## Requirements

- iOS 8.0+
- Xcode 7.3

## Installation

#### CocoaPods
You can use [CocoaPods](http://cocoapods.org/) to install `VisionDetector` by adding it to your `Podfile`:

```ruby
platform :ios, '8.0'
use_frameworks!
pod 'VisionDetector'
```

To get the full benefits import `VisionDetector` wherever you import UIKit

``` swift
import VisionDetector
```
#### Carthage
Create a `Cartfile` that lists the framework and run `carthage update`. Follow the [instructions](https://github.com/Carthage/Carthage#if-youre-building-for-ios) to add `$(SRCROOT)/Carthage/Build/iOS/VisionDetector.framework` to an iOS project.

```
github "miletliyusuf/VisionDetector"
```
#### Manually
1. Download and drop ```VisionDetector.swift``` in your project.  
2. Congratulations!  

## Usage example

```swift
import VisionDetector

class YourViewController: UIViewController {

    @IBOutlet weak var imageView:UIImageView!

    var vDetector:VisionDetector!
    
    override func viewDidLoad() {
        super.viewDidLoad()

        vDetector = VisageDetector(cameraPosition: Visage.CameraDevice.FaceTimeCamera, optimizeFor: Visage.DetectorAccuracy.HigherPerformance)
        vDetector.delegate = self
        vDetector.onlyFireNotificatonOnStatusChange = false
        vDetector.beginFaceDetection()
        
        self.view.addSubview(visage.visageCameraView)
    }
}

extension YourViewController: VisageDelegate {
    func didLeftEyeClosed() {
        self.vDetectorv.takeAPicture(completionHandler: { (image) in
            self.imageView.image = image
            self.vDetector.endFaceDetection()
            self.vDetector.visageCameraView.removeFromSuperview()
        })
    }
}

```

## Contribute

We would love you for the contribution to **VisionDetector**, check the ``LICENSE`` file for more info.

## Meta

Yusuf Miletli – [@ysfmltli](https://twitter.com/ysfmltli) – miletliyusuf@gmail.com

Distributed under the MIT license. See ``LICENSE`` for more information.

[https://github.com/miletliyusuf/VisionDetector](https://github.com/miletliyusuf/)

[swift-image]:https://img.shields.io/badge/swift-3.0-orange.svg
[swift-url]: https://swift.org/
[license-image]: https://img.shields.io/badge/License-MIT-blue.svg
[license-url]: LICENSE
[travis-image]: https://img.shields.io/travis/dbader/node-datadog-metrics/master.svg?style=flat-square
[travis-url]: https://travis-ci.org/dbader/node-datadog-metrics
[codebeat-image]: https://codebeat.co/badges/c19b47ea-2f9d-45df-8458-b2d952fe9dad
[codebeat-url]: https://codebeat.co/projects/github-com-vsouza-awesomeios-com
[logo.png]: https://ibb.co/h5jCsQ
