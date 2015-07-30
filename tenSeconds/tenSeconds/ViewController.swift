//
//  ViewController.swift
//  tenSeconds
//
//  Created by Jeet Shah on 6/19/15.
//  Copyright (c) 2015 Jeet Shah. All rights reserved.
//

import UIKit
import Foundation
import CoreMedia
import AVFoundation
import AssetsLibrary
import MediaPlayer
import CoreAudio
import CoreFoundation

class ViewController: UIViewController, AVCaptureFileOutputRecordingDelegate, UIGestureRecognizerDelegate {

    var captureSession: AVCaptureSession?
    var videoCaptureDevice: AVCaptureDevice?
    var audioCaptureDevice: AVCaptureDevice?
    var videoInputDevice: AVCaptureDeviceInput?
    var audioInputDevice: AVCaptureDeviceInput?
    var previewLayer: AVCaptureVideoPreviewLayer?
    var movieFileOutput: AVCaptureMovieFileOutput?
    var outputPath = NSTemporaryDirectory() as String
    var totalSeconds: Float64 = 10.00
    var framesPerSecond:Int32 = 30
    var maxDuration: CMTime?
    var toggleCameraSwitch: UIButton = UIButton()
    var progressBar: UIView = UIView()
    var nextButton: UIButton = UIButton()
    var trimInput: UITextField = UITextField()
    var cameraView: UIView = UIView()
    var videoAssets = [AVAsset]()
    var assetURLs = [String]()
    var progressBarTimer: NSTimer?
    var incInterval: NSTimeInterval = 0.05
    var timer: NSTimer?
    var stopRecording: Bool = false
    var remainingTime : NSTimeInterval = 10.0
    var oldX: CGFloat = 0
    var appendix: Int32 = 1
    var defaultTrimDuration: Int = 10
    

    override func viewDidLoad() {
        super.viewDidLoad()
        
        layoutViews()
        captureSession = AVCaptureSession()
        
        //Add Video Input
        addVideoInputs()
        
        //Add Audio Input
        addAudioInputs()
        
        //Add Capture Preview Layer
        addPreviewLayer()
        
        //Add Keyboard Notifications
        addKeyboardNotifications()
        
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), {
           
            captureSession?.startRunning()
            
        })
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    
    func addKeyboardNotifications() {
        
        NSNotificationCenter.defaultCenter().addObserver(self, selector: Selector("keyboardWillShow:"), name:UIKeyboardWillShowNotification, object: nil)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: Selector("keyboardWillHide:"), name:UIKeyboardWillHideNotification, object: nil)

    }
    
    override func touchesBegan(touches: Set<NSObject>, withEvent event: UIEvent) {
    
        self.trimInput.resignFirstResponder()
    }
    
    func keyboardWillShow(notification: NSNotification) {
        
        if let keyboardSize = (notification.userInfo?[UIKeyboardFrameBeginUserInfoKey] as? NSValue)?.CGRectValue() {
            //let contentInsets = UIEdgeInsets(top: 0, left: 0, bottom: keyboardSize.height, right: 0)
            
            var trimViewFrame = self.trimInput.frame
            trimViewFrame.origin.y  = trimViewFrame.origin.y - keyboardSize.height
            self.trimInput.frame = trimViewFrame
            println("keyboard will show notification")
        }
    }

    
    func keyboardWillHide(notification: NSNotification) {
        
        if let keyboardSize = (notification.userInfo?[UIKeyboardFrameBeginUserInfoKey] as? NSValue)?.CGRectValue() {
            //let contentInsets = UIEdgeInsets(top: 0, left: 0, bottom: keyboardSize.height, right: 0)
            
            var trimViewFrame = self.trimInput.frame
            trimViewFrame.origin.y = trimViewFrame.origin.y + keyboardSize.height
            self.trimInput.frame = trimViewFrame
            println("keyboard will hide notification")
        }
        
    }

    func addVideoInputs() {
        
        videoCaptureDevice = AVCaptureDevice.defaultDeviceWithMediaType(AVMediaTypeVideo)
        println("video devices are \(AVCaptureDevice.devicesWithMediaType(AVMediaTypeVideo).count)")
        if let videoDevice = videoCaptureDevice {
            
            videoInputDevice =  AVCaptureDeviceInput(device: videoDevice , error: nil)
            captureSession?.addInput(videoInputDevice)
        
            
        } else {
            
            println("video Device not found!")
        }

    }
    
    func addAudioInputs() {
        
        audioCaptureDevice = AVCaptureDevice.devicesWithMediaType(AVMediaTypeAudio)[0] as? AVCaptureDevice
            
        audioInputDevice =  AVCaptureDeviceInput(device: audioCaptureDevice , error: nil)
            captureSession?.addInput(audioInputDevice)
            println("audio device is \(audioCaptureDevice!.description)")
    }
    
    func addPreviewLayer() {
        
        previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
       // previewLayer?.frame = self.view.frame
        previewLayer?.frame = CGRect(x: 0, y: 0, width: UIScreen.mainScreen().bounds.width, height: UIScreen.mainScreen().bounds.width)
        previewLayer?.videoGravity = AVLayerVideoGravityResizeAspectFill
        //Add Movie File Output
        movieFileOutput = AVCaptureMovieFileOutput()
        maxDuration = CMTimeMakeWithSeconds(totalSeconds, framesPerSecond)
        movieFileOutput?.maxRecordedDuration = maxDuration!
        captureSession?.addOutput(movieFileOutput)
        
        var hasAudio: AVCaptureConnection =  connectionIsActive(movieFileOutput?.connections as! [AVCaptureConnection], mediaType: AVMediaTypeAudio)
        println("has audio \(hasAudio.active)")
        
        
        let recognizer = UILongPressGestureRecognizer(target: self, action:Selector("holdAction:"))
        recognizer.minimumPressDuration = 0.1
        recognizer.delegate = self
        self.view.addGestureRecognizer(recognizer)
        cameraView.frame = self.view.frame
        cameraView.layer.addSublayer(previewLayer)
        self.view.addSubview(cameraView)
        self.view.sendSubviewToBack(cameraView)
        self.view.addSubview(toggleCameraSwitch)
        self.view.addSubview(progressBar)
        self.view.addSubview(nextButton)
        self.view.addSubview(trimInput)
        
    }
    
    func connectionIsActive(connections: [AVCaptureConnection], mediaType: String) -> AVCaptureConnection {
        
        for connection in connections {
            
            for port in connection.inputPorts {
                
                if(port.mediaType  == mediaType) {
                    
                    
                    return connection
                }
            }
            
        }
        
        return connections[0] as AVCaptureConnection
    }
    
    
    func holdAction(recognizer: UILongPressGestureRecognizer) {
        
        
        if recognizer.state == UIGestureRecognizerState.Began {
            
            if(!stopRecording) {
                
                var outputFilePath = outputPath + "output-\(appendix).mov"
                appendix++
                var outputURL = NSURL(fileURLWithPath: outputFilePath)
                let fileManager = NSFileManager.defaultManager()
                if(fileManager.fileExistsAtPath(outputFilePath)) {
                
                    fileManager.removeItemAtPath(outputFilePath, error: nil)
                }
                println("gesture pressed \(outputFilePath) ")
                movieFileOutput?.startRecordingToOutputFileURL(outputURL, recordingDelegate: self)
                
            }
            
        } else if recognizer.state == UIGestureRecognizerState.Ended {
            
            if(!stopRecording) {
                
                timer?.invalidate()
                progressBarTimer?.invalidate()
                movieFileOutput?.stopRecording()
                
            }
        }
    }

    func startTimer() {
        
        timer = NSTimer(timeInterval: remainingTime, target: self, selector: "count", userInfo: nil, repeats:true)
        NSRunLoop.currentRunLoop().addTimer(timer!, forMode: NSDefaultRunLoopMode)
        
    }
    
    func startProgressBarTimer() {
        
        progressBarTimer = NSTimer(timeInterval: incInterval, target: self, selector: "progress", userInfo: nil, repeats: true)
        
        NSRunLoop.currentRunLoop().addTimer(progressBarTimer!, forMode: NSDefaultRunLoopMode)
        
    }
    
    func count() {
        
        stopRecording = true
        println("video recording stopped")
        movieFileOutput?.stopRecording()
        timer?.invalidate()
        progressBarTimer?.invalidate()
        
    }
    
    func progress() {
        
        var progressProportion: CGFloat = CGFloat(incInterval / 10.0)
        let progressInc: UIView = UIView()
        progressInc.backgroundColor = UIColor.redColor()
        let newWidth = progressBar.frame.width * progressProportion
        progressInc.frame = CGRect(x: oldX , y: 0, width: newWidth, height: progressBar.frame.height)
        oldX = oldX + newWidth
        progressBar.addSubview(progressInc)
        
    }

    
    func layoutViews() {
        
        progressBar.frame = CGRect(x: 0, y: 0, width: self.view.bounds.width, height: self.view.bounds.height * 0.1)
        nextButton.frame = CGRect(x: (self.view.frame.maxX - self.view.frame.width * 0.2 - 2), y: progressBar.frame.maxY - progressBar.frame.height * 0.8 - 2, width: progressBar.frame.width * 0.2 , height: progressBar.frame.height * 0.8)
        trimInput.frame = CGRect(x: (self.view.frame.origin.x), y: self.view.frame.maxY - progressBar.frame.height, width: progressBar.frame.width , height: progressBar.frame.height)
        
        progressBar.backgroundColor = UIColor(red: 4, green: 3, blue: 3, alpha: 0.5)
        
        nextButton.setTitle("Next", forState: UIControlState.Normal)
        nextButton.setTitleColor(UIColor.blackColor(), forState: UIControlState.Normal)
        nextButton.addTarget(self, action: "didPressNextButton:", forControlEvents: UIControlEvents.TouchUpInside)
        nextButton.hidden = true
        
        trimInput.backgroundColor = UIColor.blackColor()
        trimInput.attributedPlaceholder = NSAttributedString(string: "  Enter the trim duration in Seconds", attributes: NSDictionary(objectsAndKeys: UIColor.grayColor(), NSForegroundColorAttributeName) as [NSObject : AnyObject])
        trimInput.textColor = UIColor.whiteColor()
        trimInput.layer.borderColor = UIColor.grayColor().CGColor
        trimInput.layer.borderWidth = 2.0
        trimInput.layer.cornerRadius = 6.0
        trimInput.keyboardType = UIKeyboardType.NumberPad
        trimInput.textAlignment = NSTextAlignment.Center
        
        toggleCameraSwitch.frame = CGRect(x: nextButton.frame.origin.x + 15 , y: progressBar.frame.maxY + 10, width: 40, height: 40)
        toggleCameraSwitch.setImage(UIImage(named: "switchCamera"), forState: UIControlState.Normal)
        toggleCameraSwitch.addTarget(self, action: "toggleCamera:", forControlEvents: UIControlEvents.TouchUpInside)
        
    }

    func cameraWithPosition(position: AVCaptureDevicePosition) -> AVCaptureDevice {
        
        var rv: AVCaptureDevice = AVCaptureDevice.defaultDeviceWithMediaType(AVMediaTypeVideo)
        var devices = AVCaptureDevice.devicesWithMediaType(AVMediaTypeVideo)
        for device in devices {
            
            if(device.position == position) {
                
                rv = device as! AVCaptureDevice
            }
            
        }
        println("return device \(rv)")
        return rv
    }
    
    func toggleCamera(sender: UIButton) {
        
        var newInputDevice: AVCaptureDeviceInput = videoInputDevice!
        var position: AVCaptureDevicePosition? = videoInputDevice?.device.position
        var newDevice: AVCaptureDevice?
        var error: NSErrorPointer = NSErrorPointer()
        if(position == AVCaptureDevicePosition.Back) {
            
            newDevice = cameraWithPosition(AVCaptureDevicePosition.Front)
            newInputDevice = AVCaptureDeviceInput.deviceInputWithDevice(newDevice, error: error) as!AVCaptureDeviceInput
            println("toggle \(newDevice)")
                
        } else if(position == AVCaptureDevicePosition.Front) {
            
            newDevice = cameraWithPosition(AVCaptureDevicePosition.Back)
            newInputDevice = AVCaptureDeviceInput.deviceInputWithDevice(newDevice, error: error) as! AVCaptureDeviceInput
            
        }
        
        captureSession?.beginConfiguration()
        captureSession?.removeInput(videoInputDevice)
        captureSession?.addInput(newInputDevice)
        videoInputDevice = newInputDevice
        captureSession?.commitConfiguration()
        UIView.transitionWithView(self.view, duration: 0.5, options: UIViewAnimationOptions.TransitionFlipFromLeft, animations: {}, completion: nil)
        
       
    }
    
    func didPressNextButton(button: UIButton) {
        
        if(videoAssets.count > 0) {
            
            if(!self.trimInput.text.isEmpty) {
                
                var duration = self.trimInput.text.toInt()
                mergeVideos(duration!)
                
            } else {
                
                mergeVideos(defaultTrimDuration)
            }
        }
        
    }
    
    func captureOutput(captureOutput: AVCaptureFileOutput!, didStartRecordingToOutputFileAtURL fileURL: NSURL!, fromConnections connections: [AnyObject]!) {
        
        startProgressBarTimer()
        startTimer()
        nextButton.hidden = true
        trimInput.hidden = true
    }
    
    func captureOutput(captureOutput: AVCaptureFileOutput!, didFinishRecordingToOutputFileAtURL outputFileURL: NSURL!, fromConnections connections: [AnyObject]!, error: NSError!) {
        
        var asset : AVURLAsset = AVURLAsset(URL: outputFileURL, options: nil)
        var duration : NSTimeInterval = 0.0
        duration = CMTimeGetSeconds(asset.duration)
        println("video asset is \(asset)")
        videoAssets.append(asset)
        assetURLs.append(outputFileURL.path!)
        remainingTime = remainingTime - duration
        nextButton.hidden = false
        trimInput.hidden = false

    }
   
    func mergeVideos(var duration: Int) {
      
        if(duration > 10) {
            
            duration = defaultTrimDuration
        }
        
        var composition = AVMutableComposition()
        
        //merging video tracks
        let firstTrack:AVMutableCompositionTrack = composition.addMutableTrackWithMediaType(AVMediaTypeVideo, preferredTrackID: CMPersistentTrackID())
        
        let audioTrack: AVMutableCompositionTrack = composition.addMutableTrackWithMediaType(AVMediaTypeAudio, preferredTrackID: CMPersistentTrackID())
       
        var insertTime: CMTime = kCMTimeZero
        
        
        for asset in videoAssets {
            println(" videos are \(asset)")
            firstTrack.insertTimeRange(CMTimeRangeMake(kCMTimeZero, asset.duration), ofTrack: asset.tracksWithMediaType(AVMediaTypeVideo)[0] as! AVAssetTrack, atTime: insertTime, error: nil)
            audioTrack.insertTimeRange(CMTimeRangeMake(kCMTimeZero, asset.duration), ofTrack: asset.tracksWithMediaType(AVMediaTypeAudio)[0] as! AVAssetTrack, atTime: insertTime, error: nil)
            
            insertTime = CMTimeAdd(insertTime, asset.duration)
            
        }
        firstTrack.preferredTransform = CGAffineTransformMakeRotation(CGFloat(M_PI_2))
        //get path of newly merged video
        let fileManager = NSFileManager.defaultManager()
        let documentsPath : String = NSSearchPathForDirectoriesInDomains(.DocumentDirectory,.UserDomainMask,true)[0] as! String
        let destinationPath: String = documentsPath + "/mergeVideo-\(arc4random()%1000).mov"
        println("video url is \(destinationPath)")
        let videoPath: NSURL = NSURL(fileURLWithPath: destinationPath as String)!
        let exporter: AVAssetExportSession = AVAssetExportSession(asset: composition, presetName:AVAssetExportPresetHighestQuality)
        exporter.outputURL = videoPath
        exporter.outputFileType = AVFileTypeQuickTimeMovie
        exporter.shouldOptimizeForNetworkUse = true
        exporter.timeRange = CMTimeRangeMake(kCMTimeZero, CMTimeMakeWithSeconds(Float64(duration),framesPerSecond))
        exporter.exportAsynchronouslyWithCompletionHandler({
            
            dispatch_async(dispatch_get_main_queue(),{
                
                self.exportDidFinish(exporter)
                
            })
            
        })
        
    }
    
    
    func exportDidFinish(session: AVAssetExportSession) {
        
        println("export did finish")
        var outputURL: NSURL = session.outputURL
        var library: ALAssetsLibrary = ALAssetsLibrary()
        if(library.videoAtPathIsCompatibleWithSavedPhotosAlbum(outputURL)) {
            
            library.writeVideoAtPathToSavedPhotosAlbum(outputURL, completionBlock: {(NSURL, NSError) in
                
                var moviePlayer: MPMoviePlayerViewController? = MPMoviePlayerViewController(contentURL: outputURL)
               if let player = moviePlayer {
                  println("url is \(outputURL)")
                  self.presentMoviePlayerViewControllerAnimated(player)
                  self.reset()
    
                }
                
            })
            
        }
    }
    
    func reset() {
        
        for assetURL in assetURLs {
            
            if(NSFileManager.defaultManager().fileExistsAtPath(assetURL)) {
                
                NSFileManager.defaultManager().removeItemAtPath(assetURL, error: nil)
                println("asset deleted: \(assetURL)")
            }
       }
        
        var subviews = progressBar.subviews
        for subview in subviews {
            
            subview.removeFromSuperview()
        }
        videoAssets.removeAll(keepCapacity: false)
        assetURLs.removeAll(keepCapacity: false)
        appendix = 1
        oldX = 0
        stopRecording = false
        remainingTime = 10.00
    }
    

}

