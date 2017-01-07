import Foundation
import AVFoundation
import CoreMedia
import HiliteCore

class StopAndGoCaptureSession: NSObject, CaptureSession, AVCaptureVideoDataOutputSampleBufferDelegate, AVCaptureAudioDataOutputSampleBufferDelegate {
    let captureDevice = CaptureDevice()
    let captureSession = AVCaptureSession()
    var previewLayer: AVCaptureVideoPreviewLayer!
    let videoCaptureDataOutput = AVCaptureVideoDataOutput()
    let audioCaptureDataOutput = AVCaptureAudioDataOutput()
    let dataOutputQueue = DispatchQueue(label: "com.birdtree.CaptureDataOutputQueue", attributes: [])

    var videoConnection: AVCaptureConnection!
    var audioConnection: AVCaptureConnection!
    
    var delegate: CaptureSessionDelegate?
    var progressTimer:Timer!
    var maxRecordTimeInSeconds: TimeInterval = 120
    var numberOfTimesRecorded: UInt!
    var offset: CMTime?
    var audioOffset: CMTime?
    var capturedDuration: CMTime!
    var currentSessionTime: CMTime!
    var currentSessionAudioTime: CMTime!
    var sessionStartTime = kCMTimeInvalid
    var capturedVideo: CapturedVideo?
    var assetWriter: AVAssetWriter!
    var assetWriterVideoInput: AVAssetWriterInput?
    var assetWriterAudioInput: AVAssetWriterInput?
    var isCapturing: Bool
    var firstFrameWrittenTime: CMTime?
    var lastWrittenFrameTime: CMTime?
    var lastWrittenAudioFrameTime: CMTime?
    var captureRequested:Bool = false
    var completionRequested: Bool = false
    var canWriteAudio: Bool = false
    var lastPresentationTime = kCMTimeZero          // keeping track of latest presentation frame, not written frame
    var lastAudioPresentationTime = kCMTimeZero          // keeping track of latest presentation frame, not written frame
    var pixelBufferAdaptor: AVAssetWriterInputPixelBufferAdaptor?
    var lastWrittenFrameDuration = kCMTimeZero
    
    var currentCameraInputDevice: AVCaptureDeviceInput?
    
    init(delegate: CaptureSessionDelegate?, maxRecordTimeInSeconds: TimeInterval) {
        isCapturing = false
        
        self.delegate = delegate
        
        self.maxRecordTimeInSeconds = maxRecordTimeInSeconds

        super.init()

        capturedDuration = kCMTimeZero
        
        captureSession.sessionPreset = AVCaptureSessionPreset640x480
        
        cleanup()

        captureSession.beginConfiguration()
        
        configureCaptureDataOutput()
        
        configureInputs()
        
        captureSession.commitConfiguration()
        
        configureConnections()

        previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer.videoGravity = AVLayerVideoGravityResizeAspectFill

    }

    func configureConnections() {
        videoConnection = videoCaptureDataOutput.connection(withMediaType: AVMediaTypeVideo)
        videoConnection.videoOrientation = AVCaptureVideoOrientation.portrait
        
        audioConnection = audioCaptureDataOutput.connection(withMediaType: AVMediaTypeAudio)
    }
    
    func isCompleted() -> Bool {
        return assetWriter.status == AVAssetWriterStatus.completed
    }
    func isFailed() -> Bool {
        return assetWriter.status == AVAssetWriterStatus.failed
    }
    
    func configureInputs() {
        addFrontFacingCameraInput()
        
        if (captureSession.canAddInput(captureDevice.audioInput)) {
            captureSession.addInput(captureDevice.audioInput)
        } else {
            Logger.loge("could not add audio input")
        }
        if (captureSession.canAddOutput(videoCaptureDataOutput)) {
            captureSession.addOutput(videoCaptureDataOutput)
        } else {
            Logger.loge("could not add video output")
        }
        if (captureSession.canAddOutput(audioCaptureDataOutput)) {
            captureSession.addOutput(audioCaptureDataOutput)
        } else {
            Logger.loge("could not add audio output")
        }
    }

    func configureCaptureDataOutput() {
        videoCaptureDataOutput.videoSettings = nil //[kCVPixelBufferPixelFormatTypeKey: kCVPixelFormatType_32BGRA]
        videoCaptureDataOutput.setSampleBufferDelegate(self, queue: dataOutputQueue)
        
        audioCaptureDataOutput.setSampleBufferDelegate(self, queue: dataOutputQueue)
    }
    
    func toggleCamera() {
        captureSession.beginConfiguration()
        
        if let inputDevice = currentCameraInputDevice {
            if (inputDevice == captureDevice.frontFacingCameraInput) {
                addBackFacingCameraInput()
            } else {
                addFrontFacingCameraInput()
            }
        } else {
            addFrontFacingCameraInput()
        }
        
        videoConnection = videoCaptureDataOutput.connection(withMediaType: AVMediaTypeVideo)
        videoConnection.videoOrientation = AVCaptureVideoOrientation.portrait

        captureSession.commitConfiguration()
    }
    
    func addBackFacingCameraInput() {
        if let inputDevice = currentCameraInputDevice {
            if (inputDevice == captureDevice.backFacingCameraInput) { return; }
        }
        
        if (captureDevice.isFrontFacingCameraSupported()) {
            captureSession.removeInput(captureDevice.frontFacingCameraInput)
        }
        if (captureSession.canAddInput(captureDevice.backFacingCameraInput)) {
            captureSession.addInput(captureDevice.backFacingCameraInput)
            currentCameraInputDevice = captureDevice.backFacingCameraInput
        } else {
            Logger.loge("could not add back facing camera input")
        }
    }
    
    func addFrontFacingCameraInput() {
        if let inputDevice = currentCameraInputDevice {
            if (inputDevice == captureDevice.frontFacingCameraInput) { return; }
        }
        
        if (captureDevice.isBackFacingCameraSupported()) {
            captureSession.removeInput(captureDevice.backFacingCameraInput)
        }
        
        if (captureSession.canAddInput(captureDevice.frontFacingCameraInput)) {
            captureSession.addInput(captureDevice.frontFacingCameraInput)
            currentCameraInputDevice = captureDevice.frontFacingCameraInput
        } else {
            Logger.loge("could not add front facing camera input")
        }
    }
    
    func configureAssetWriter() {
        var error: NSError?
        self.capturedVideo = StandardCapturedVideo()
        do {
            assetWriter = try AVAssetWriter(outputURL: capturedVideo!.fileUrlToMOV! as URL, fileType: AVFileTypeMPEG4)
        } catch let error1 as NSError {
            error = error1
            assetWriter = nil
        }
        if (error != nil) {
            Logger.loge(error!.localizedDescription)
        }
    }
    
    func configureVideoInputForAssetWriter(_ assetWriter: AVAssetWriter, formatDescription: CMFormatDescription) -> Bool {
        var success = false
        DispatchQueue.main.sync(execute: { [weak self] () -> Void in
            if (self?.assetWriterVideoInput != nil) { success = true; return }
            
            let bitsPerPixel:Double = 11 // 4.05 for streaming
//            var dimensions:CMVideoDimensions = CMVideoFormatDescriptionGetDimensions(formatDescription)
            let numPixels = 640 * 480
            
            let bitsPerSecond = (Double(numPixels) * bitsPerPixel)
            
            let compressionProperties = [
                AVVideoAverageBitRateKey: bitsPerSecond,
                AVVideoMaxKeyFrameIntervalDurationKey: 0,
                AVVideoMaxKeyFrameIntervalKey: 30,
                AVVideoProfileLevelKey: AVVideoProfileLevelH264Main32,
                
            ] as [String : Any]
            let videoCompressionSettings = [
                AVVideoCodecKey: AVVideoCodecH264,
                AVVideoWidthKey: 480,
                AVVideoHeightKey: 640,
                AVVideoCompressionPropertiesKey: compressionProperties
            ] as [String : Any]
            
            if (assetWriter.canApply(outputSettings: videoCompressionSettings, forMediaType: AVMediaTypeVideo)) {
                self?.assetWriterVideoInput = AVAssetWriterInput(mediaType: AVMediaTypeVideo, outputSettings: videoCompressionSettings)
                self?.assetWriterVideoInput?.expectsMediaDataInRealTime = true
                self?.assetWriterVideoInput?.transform = CGAffineTransform.identity
                if (assetWriter.canAdd((self?.assetWriterVideoInput)!)) {
                    assetWriter.add((self?.assetWriterVideoInput)!)
                } else {
                    Logger.loge("could not add asset writer video input")
                    success = false
                    return
                }
                
                self?.pixelBufferAdaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: self!.assetWriterVideoInput!, sourcePixelBufferAttributes: nil)
            } else {
                Logger.loge("could not apply video output settings")
                success = false
                return
            }
            
            Logger.logm("configured asset writer video input")
            success = true
        })
        return success
    }
    
    func configureAudioInputForAssetWriter(_ assetWriter: AVAssetWriter, formatDescription: CMFormatDescription) -> Bool {
        var success = false
        DispatchQueue.main.sync(execute: { [weak self] () -> Void in
            if (self?.assetWriterAudioInput != nil) { success = true; return }
            
//            let currentASBD:UnsafePointer<AudioStreamBasicDescription> = CMAudioFormatDescriptionGetStreamBasicDescription(formatDescription)
            
//            var currentChannelLayoutData:NSData = NSData()
            
            let audioSettings = self?.audioCaptureDataOutput.recommendedAudioSettingsForAssetWriter(withOutputFileType: AVFileTypeMPEG4) as! [String: AnyObject]
            
            if (assetWriter.canApply(outputSettings: audioSettings, forMediaType: AVMediaTypeAudio)) {
                self?.assetWriterAudioInput = AVAssetWriterInput(mediaType: AVMediaTypeAudio, outputSettings: audioSettings)
                self?.assetWriterAudioInput?.expectsMediaDataInRealTime = true
                if (assetWriter.canAdd((self?.assetWriterAudioInput)!)) {
                    assetWriter.add((self?.assetWriterAudioInput)!)
                } else {
                    Logger.loge("could not add asset writer audio input");
                    success = false
                    return
                }
            } else {
                Logger.loge("could not apply audio output settings.")
                success = false
                return
            }
            
            Logger.logm("configured asset writer audio input")
            success = true
        })
        return success
    }
    
    func startRunning() {
        if (captureSession.isRunning) { return }
        captureSession.startRunning()
    }
    
    func stopRunning() {
        if (!captureSession.isRunning) { return }
        captureSession.stopRunning()
    }
    
    func startCapturingWithCapturedVideo(_ capturedVideo: CapturedVideo?) {
        objc_sync_enter(self)

        if (self.isCapturing || self.captureRequested) { return; }
        self.captureRequested = true
    
        objc_sync_enter(self)
    }
    
    func stopCapturing() {
        objc_sync_enter(self)

        if (!self.isCapturing || !self.captureRequested) { return }
        self.captureRequested = false

        print("offset:        \(CMTimeGetSeconds(self.offset ?? kCMTimeZero))")
        print("audioOffset:   \(CMTimeGetSeconds(self.audioOffset ?? kCMTimeZero))")
        
        objc_sync_exit(self)
    }
    
    func finishUp() {
        let completionHandler = {
            ()->Void in
            DispatchQueue.main.async { [weak self] in
//                var a:Int   // weird hack to make Xcode stop freaking out
                self?.delegate?.captureSessionDidFinishCapturingVideo(self!.capturedVideo!)
            }
        }
        self.stopCapturing()
        self.stopRunning()
        dataOutputQueue.async { [weak self] in
            if let weakSelf = self {
                if (weakSelf.assetWriter.status == AVAssetWriterStatus.writing || weakSelf.assetWriter.status == AVAssetWriterStatus.unknown) {
                    weakSelf.assetWriter.finishWriting(completionHandler: completionHandler)
                } else {
                    completionHandler()
                }
            }
        }
    }
    
    func captureOutput(_ captureOutput: AVCaptureOutput!, didDrop sampleBuffer: CMSampleBuffer!, from connection: AVCaptureConnection!) {
        Logger.logm("dropped sample")
    }
    
    func startSessionIfNotYetStarted() {
        if self.firstFrameWrittenTime == nil {
            if (assetWriter.status == AVAssetWriterStatus.writing) {
                assetWriter.startSession(atSourceTime: currentSessionTime)
                sessionStartTime = currentSessionTime
            }
        }
    }
    
    func setSessionStartTimeIfNeeded() {
        if (CMTimeCompare(self.sessionStartTime, kCMTimeInvalid) == 0) {
            self.sessionStartTime = self.currentSessionTime
        }
    }
    
    func writeSampleBuffer(_ sampleBuffer: CMSampleBuffer, forMediaType: String, presentationTime: CMTime!, presentationTimeOffset: CMTime?) {
        if (forMediaType != AVMediaTypeAudio && forMediaType != AVMediaTypeVideo) {
            return
        }
        
        let valid:Bool = CMSampleBufferIsValid(sampleBuffer)
        let ready:Bool = CMSampleBufferDataIsReady(sampleBuffer)
        if (!ready || !valid) {
            return
        }
        
        if (!isCapturing || self.assetWriter.status != AVAssetWriterStatus.writing) { return }

        
//        let sampleBufferPresentationTimeStamp = presentationTime
//        let sampleBufferDecodeTimeStamp = CMSampleBufferGetDecodeTimeStamp(sampleBuffer)
        let sampleBufferDuration = CMSampleBufferGetDuration(sampleBuffer) //).isNaN ? kCMTimeZero: CMSampleBufferGetDuration(sampleBuffer)
        
//        println("\(sampleBufferDecodeTimeStamp.isValid)")
        
//        var adjustedPresentationTimeStamp = presentationTime
        
//        if let timeOffset = presentationTimeOffset {
//            //if (forMediaType == AVMediaTypeVideo) {
//                //            adjustedPresentationTimeStamp = CMTimeMaximum(CMTimeMaximum(CMTimeSubtract(CMTimeSubtract(sampleBufferPresentationTimeStamp, timeOffset), CMTimeMake(150, 300)), kCMTimeZero), CMTimeAdd(lastWrittenFrameTime ?? kCMTimeZero, CMTimeMake(1, 30)))
//                //            adjustedPresentationTimeStamp = CMTimeMaximum(CMTimeSubtract(presentationTime, timeOffset), CMTimeAdd(lastWrittenFrameTime ?? kCMTimeZero, kCMTimeZero))
//                
////                adjustedPresentationTimeStamp = CMTimeSubtract(presentationTime, timeOffset)
////                if (CMTimeCompare(adjustedPresentationTimeStamp, lastWrittenFrameTime ?? kCMTimeZero) == 1) {
////                    adjustedPresentationTimeStamp = lastWrittenFrameTime ?? presentationTime
////                }
//            //}
//        }
        
//        var adjustedDecodeTimeStamp = kCMTimeZero
//        if let timeOffset = presentationTimeOffset {
//            if (forMediaType == AVMediaTypeVideo) {
//                //            adjustedPresentationTimeStamp = CMTimeMaximum(CMTimeMaximum(CMTimeSubtract(CMTimeSubtract(sampleBufferPresentationTimeStamp, timeOffset), CMTimeMake(150, 300)), kCMTimeZero), CMTimeAdd(lastWrittenFrameTime ?? kCMTimeZero, CMTimeMake(1, 30)))
//                //            adjustedPresentationTimeStamp = CMTimeMaximum(CMTimeSubtract(presentationTime, timeOffset), CMTimeAdd(lastWrittenFrameTime ?? kCMTimeZero, kCMTimeZero))
//                
//                adjustedPresentationTimeStamp = CMTimeSubtract(presentationTime, timeOffset)
//                if (CMTimeCompare(adjustedPresentationTimeStamp, lastWrittenFrameTime ?? kCMTimeZero) == 1) {
//                    adjustedDecodePresentationTimeStamp = lastWrittenFrameTime ?? presentationTime
//                }
//            }
//            adjustedDecodeTimeStamp = CMTimeSubtract(sampleBufferDecodeTimeStamp, timeOffset)
//        }
        
        var count:CMItemCount = 0
        CMSampleBufferGetSampleTimingInfoArray(sampleBuffer, 0, nil, &count)
        var pInfo = Array<CMSampleTimingInfo>()
        for _ in 0..<count {
            pInfo.append(CMSampleTimingInfo())
        }
        CMSampleBufferGetSampleTimingInfoArray(sampleBuffer, count, &pInfo, &count)
        for i in 0..<count {
            pInfo[i].decodeTimeStamp = CMTimeSubtract(pInfo[i].decodeTimeStamp, presentationTimeOffset ?? kCMTimeZero)
            pInfo[i].presentationTimeStamp = CMTimeSubtract(pInfo[i].presentationTimeStamp, presentationTimeOffset ?? kCMTimeZero)
        }
        
        var adjustedSampleBuffer: CMSampleBuffer?
        var _ = CMSampleBufferCreateCopyWithNewTiming(nil, sampleBuffer, count, &pInfo, &adjustedSampleBuffer)
        
        if adjustedSampleBuffer == nil { return }
        
        if (!self.captureRequested && self.isCapturing) {
            self.isCapturing = false
            self.delegate?.captureSessionDidStopCapturing()
        }
        if (self.completionRequested) {
            DispatchQueue.main.sync(execute: { [weak self] () -> Void in
                self?.finishUp()
            })
            return
        }
        

        capturedDuration = CMTimeSubtract(CMTimeSubtract(currentSessionTime, sessionStartTime), presentationTimeOffset ?? kCMTimeZero)
        
        delegate?.captureSessionDidUpdateCaptureTimeToTimeInSeconds(CMTimeGetSeconds(capturedDuration))

//        println("\(CMTimeGetSeconds(CMTimeSubtract(adjustedPresentationTimeStamp, lastWrittenFrameTime ?? adjustedPresentationTimeStamp)))")
        
        let capturedDurationInSeconds = CMTimeGetSeconds(self.capturedDuration)
        if (TimeInterval(capturedDurationInSeconds) >= self.maxRecordTimeInSeconds) {
            Logger.logm("capturedDurationInSeconds expired")
            self.completionRequested = true
            return
        }
//        println("FRAME TIME: \(CMTimeGetSeconds(adjustedPresentationTimeStamp))")

        if (!self.isCapturing && self.lastWrittenFrameTime == nil) { return }

        if (forMediaType == AVMediaTypeVideo) {
            if let videoInput = assetWriterVideoInput {
                if (videoInput.isReadyForMoreMediaData) {
                    setSessionStartTimeIfNeeded()
                    
                    let firstFrameWritten = self.firstFrameWrittenTime
                    
                    startSessionIfNotYetStarted()
                    
//                    let unretainedValue = unmanagedAdjustedSampleBuffer.takeUnretainedValue()
                    if (!videoInput.append(adjustedSampleBuffer!)) {
                    
//                    var pixelBuffer = UnsafeMutablePointer<Unmanaged<CVPixelBuffer>?>.alloc(1)
//                    let numberBool = NSNumber(bool: true)
//                    let options = [kCVPixelBufferCGImageCompatibilityKey as String!: numberBool] //, kCVPixelBufferCGBitmapContextCompatibilityKey:numberBool]
//                    let result = CVPixelBufferCreate(kCFAllocatorDefault, 480, 640, OSType(kCVPixelFormatType_32BGRA), options, pixelBuffer)
//                    
//                    let movedPixelBuffer = pixelBuffer.move()!
//                    if (!self.pixelBufferAdaptor!.appendPixelBuffer(movedPixelBuffer.takeUnretainedValue(), withPresentationTime: adjustedPresentationTimeStamp)) {
                        Logger.loge("could not append video sample buffer")
                        print("\(self.assetWriter.status.rawValue)")
                        if let error = self.assetWriter.error {
                            print("\(error._code)")
                            print("\(error.localizedDescription)")
                        }
                    } else {
                        if (firstFrameWritten == nil) {
                            Logger.logm("SET firstFrameWrittenTime")
                            firstFrameWrittenTime = presentationTime
                            sessionStartTime = firstFrameWrittenTime!
                        }
//                        lastWrittenFrameTime = adjustedPresentationTimeStamp
                        lastPresentationTime = presentationTime
                        lastWrittenFrameDuration = kCMTimeZero
                        canWriteAudio = true
                    }
//                    movedPixelBuffer.autorelease()
//                    pixelBuffer.destroy()
                } else {
                    Logger.logm("video input not ready for more media data")
                }
            } else {
                print("no assetWriterVideoInput")
            }
        } else if (forMediaType == AVMediaTypeAudio) {
            if let audioInput = assetWriterAudioInput {
//                if (!canWriteAudio) { return }
                if (audioInput.isReadyForMoreMediaData && self.firstFrameWrittenTime != nil) {                        // don't write audio buffers first
                    if (!audioInput.append(adjustedSampleBuffer!)) {
                        Logger.loge("could not append audio sample buffer")
                        print("\(self.assetWriter.status.rawValue)")
                        if let error = self.assetWriter.error {
                            print("\(error._code)")
                            print("\(error.localizedDescription)")
//                            print("\(error.localizedFailureReason)")
                        }
                    } else {
                        lastWrittenAudioFrameTime = CMTimeAdd(CMTimeSubtract(presentationTime, presentationTimeOffset ?? kCMTimeZero), sampleBufferDuration)
                        lastAudioPresentationTime = presentationTime
                        lastWrittenFrameDuration = sampleBufferDuration
                    }
                } else {
                    Logger.logm("audio input not ready for more media data")
                    print(audioInput.isReadyForMoreMediaData)
                }
            }
        }
    }
    
    func captureOutput(_ captureOutput: AVCaptureOutput!, didOutputSampleBuffer sampleBuffer: CMSampleBuffer!, from connection: AVCaptureConnection!) {
        let formatDescription:CMFormatDescription = CMSampleBufferGetFormatDescription(sampleBuffer)!

        currentSessionTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)

        var mediaType:String = ""
        if (connection == videoConnection) {

            mediaType = AVMediaTypeVideo
//            var a:Int   // weird hack to make Xcode stop freaking out
            self.configureVideoInputForAssetWriter(self.assetWriter, formatDescription: formatDescription)
        } else if (connection == audioConnection) {
            currentSessionAudioTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
            mediaType = AVMediaTypeAudio
            self.configureAudioInputForAssetWriter(self.assetWriter, formatDescription: formatDescription)
        }
        
        if (self.captureRequested && !self.isCapturing && mediaType == AVMediaTypeAudio) {
            print("************************ \(mediaType)")
            self.isCapturing = true
            self.delegate?.captureSessionDidStartCapturing()
            
//            if (mediaType == AVMediaTypeVideo) {
            let previousPresentationTime = lastWrittenAudioFrameTime ?? currentSessionTime
            let gapLength = CMTimeSubtract(self.currentSessionTime, lastWrittenAudioFrameTime ?? self.currentSessionTime)
                if let lastFrameTime = self.lastWrittenAudioFrameTime {
                    print("******************* GAP LENGTH: \(gapLength)")
                    //if (mediaType == AVMediaTypeAudio) {
                        let relevantOffset = offset ?? kCMTimeZero //CMTimeMaximum(offset ?? kCMTimeZero, audioOffset ?? kCMTimeZero)
                        let tweakOffset = kCMTimeZero
                        let subtractOffset = CMTimeMake(1, 30)
                        
                        self.offset = gapLength //CMTimeAdd(gapLength, offset ?? kCMTimeZero)
                        //self.offset = CMTimeMaximum(CMTimeSubtract(CMTimeMaximum(self.offset ?? kCMTimeZero, CMTimeAdd(gapLength, relevantOffset)), subtractOffset), kCMTimeZero)

                        
                        self.audioOffset = self.offset
                        print("lastWrittenFrameDuration: \(CMTimeGetSeconds(lastWrittenFrameDuration))")
                        print("lastFrameTime:            \(CMTimeGetSeconds(lastFrameTime))")
                        print("offset:                   \(CMTimeGetSeconds(offset ?? kCMTimeZero))")
                        print("duration:                 \(CMTimeGetSeconds(capturedDuration))")
                    //}
                } else {
                    self.offset = kCMTimeZero
                    print("self.lastWrittenFrameTime == nil")
                }
//            }
//            if (mediaType == AVMediaTypeAudio) {
//                if let lastFrameTime = self.lastWrittenAudioFrameTime {
//                    self.audioOffset = CMTimeMaximum(CMTimeSubtract(CMTimeMaximum(self.audioOffset ?? kCMTimeZero, CMTimeAdd(CMTimeSubtract(self.currentSessionAudioTime, CMTimeMaximum(lastPresentationTime, lastAudioPresentationTime)), CMTimeMaximum(offset ?? kCMTimeZero, audioOffset ?? kCMTimeZero))), CMTimeMake(1, 30)), kCMTimeZero)
//                    var duration = kCMTimeZero
//                    if (mediaType == AVMediaTypeAudio && CMTimeCompare(CMSampleBufferGetDuration(sampleBuffer), kCMTimeInvalid) != 0) {
//                        println("got duration")
//                        duration = CMSampleBufferGetDuration(sampleBuffer)
//                    }
//                    let relevantOffset = self.audioOffset ?? kCMTimeZero
//                    self.audioOffset = offset //CMTimeMaximum(CMTimeAdd(self.offset ?? kCMTimeZero, CMTimeMake(10, 30)), kCMTimeZero)
//                    self.audioOffset = CMTimeMaximum(CMTimeSubtract(self.offset ?? kCMTimeZero, CMTimeSubtract(CMTimeMaximum(lastWrittenAudioFrameTime ?? kCMTimeZero, lastWrittenFrameTime ?? kCMTimeZero), CMTimeMinimum(lastWrittenAudioFrameTime ?? kCMTimeZero, lastWrittenFrameTime ?? kCMTimeZero))), kCMTimeZero)
//                    self.audioOffset = CMTimeMaximum(CMTimeAdd(offset ?? kCMTimeZero, CMTimeSubtract(lastWrittenFrameTime ?? kCMTimeZero, lastWrittenAudioFrameTime ?? kCMTimeZero)), kCMTimeZero) //CMTimeMaximum(CMTimeSubtract(CMTimeMaximum(self.offset ?? kCMTimeZero, CMTimeAdd(gapLength, relevantOffset)), CMTimeMake(1, 30)), kCMTimeZero)
//                    println("lastFrameTime: \(CMTimeGetSeconds(lastFrameTime))")
//                    println("offset:        \(CMTimeGetSeconds(audioOffset ?? kCMTimeZero))")
//                    println("duration:      \(CMTimeGetSeconds(capturedDuration))")
//                } else {
//                    self.audioOffset = kCMTimeZero
//                    println("self.lastWrittenFrameTime == nil")
//                }
//            }
        }
        
        if (assetWriter.status == AVAssetWriterStatus.failed) {
            Logger.loge("asset writer failed")
            if let error = assetWriter.error {
                Logger.loge(error.localizedDescription)
//                Logger.loge(error.localizedFailureReason ?? "")
            }
        }
        if (assetWriter.status == AVAssetWriterStatus.unknown && assetWriter.status != AVAssetWriterStatus.writing && self.assetWriterAudioInput != nil && self.assetWriterVideoInput != nil && TimeInterval(CMTimeGetSeconds(self.capturedDuration)) < self.maxRecordTimeInSeconds && !self.completionRequested) {
            print("************************************* assetWriter.startWriting()")
            if (!assetWriter.startWriting()) {
                Logger.loge(assetWriter.error?.localizedDescription ?? "")
            }
        } else if (assetWriter.status == AVAssetWriterStatus.writing) {
            writeSampleBuffer(sampleBuffer, forMediaType: mediaType, presentationTime: currentSessionTime, presentationTimeOffset: self.offset)
        }
    }
    
    func isFrontCameraSupported() -> Bool {
        return captureDevice.isFrontFacingCameraSupported()
    }
    
    func cleanup() {
        numberOfTimesRecorded = 0

        offset = nil
        audioOffset = nil

        capturedVideo = nil
        
        capturedDuration = kCMTimeZero
        currentSessionTime = kCMTimeZero
        sessionStartTime = kCMTimeInvalid

        lastWrittenFrameTime = nil
        lastWrittenAudioFrameTime = nil
        
        completionRequested = false
        canWriteAudio = false

        lastPresentationTime = kCMTimeZero
        lastAudioPresentationTime = kCMTimeZero
        lastWrittenFrameDuration = kCMTimeZero

        configureAssetWriter()
    }
    
    func reset() {
        numberOfTimesRecorded = 0

        offset = nil
        audioOffset = nil

        capturedVideo = nil

        capturedDuration = kCMTimeZero
        currentSessionTime = kCMTimeZero
        sessionStartTime = kCMTimeInvalid
        
        lastWrittenFrameTime = nil
        lastWrittenAudioFrameTime = nil
        
        completionRequested = false
        canWriteAudio = false
        lastPresentationTime = kCMTimeZero
        lastAudioPresentationTime = kCMTimeZero
        lastWrittenFrameDuration = kCMTimeZero
        
        self.delegate?.captureSessionDidUpdateCaptureTimeToTimeInSeconds(0.0)
    }

    func hasBegunCapturing() -> Bool {
        return CMTimeCompare(capturedDuration, kCMTimeZero) == 1
    }
    
    // MARK: - Suspendable methods
    func suspend() {
        self.captureSession.stopRunning()
    }
    
    func resume() {
        self.captureSession.startRunning()
    }

}


extension CMTime {
    var isValid:Bool { return (flags.intersection(CMTimeFlags.valid)) != [] }
}
