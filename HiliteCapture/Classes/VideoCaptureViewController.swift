import Foundation
import UIKit
import AVFoundation
import CoreMedia
import MobileCoreServices
import HiliteCore
import HiliteUI

let minimumCaptureDuration: Float64 = 3.0
var maximumRecordTimeInSeconds: Float = 20

open class VideoCaptureViewController: PortraitViewController, CaptureSessionDelegate, VideoReviewAgentDelegate, VideoCaptureOverlayViewDelegate, Suspendable, UINavigationControllerDelegate {

    public var captureSession:CaptureSession?
    public var captureAgent:VideoCaptureAgent?
    public var capturePreviewLayer:AVCaptureVideoPreviewLayer?
    let recordButton = RecordProgressButton()
    let redoButton = Button()
    var reviewButton:Button!
    var videoReviewView:InlineVideoReviewView!
    var videoCaptureOverlayView: StandardVideoCaptureOverlayView?
    var minimumRecordTimer: Timer?
    var stopCaptureRequested = false
    let userCapabilitiesAgent = UserCapabilitiesAgent()
    var toggleCameraButton:Button!
    var importFromCameraRollButton:Button!

    public var taskAgent: TaskAgent?

    override open func viewDidLoad() {
        super.viewDidLoad()
        
        maximumRecordTimeInSeconds = userCapabilitiesAgent.maxRecordTimeInSeconds()
        
        print(maximumRecordTimeInSeconds)
        
        backgroundImageView.isHidden = true
        
        configureCaptureSession()

        let redoButtonSize = CGSize(width: 70, height: 46)
        
        redoButton.translatesAutoresizingMaskIntoConstraints = false
        redoButton.setTitle("START OVER", for: UIControlState())
        redoButton.setTitleColor(HLColor.green, for: UIControlState())
        redoButton.titleLabel?.font = HLFont.applicationFontCondensedBoldItalic(14)
        redoButton.titleEdgeInsets = UIEdgeInsetsMake(36, -(redoButtonSize.width*2.0) - 10, 0, -redoButtonSize.width)
        redoButton.setImage(AssetManager.redoButtonImage(), for: UIControlState())
        redoButton.imageView?.contentMode = .scaleAspectFit
        redoButton.imageEdgeInsets = UIEdgeInsetsMake(-5, 0, 12, 0)
        redoButton.addTarget(self, action: #selector(VideoCaptureViewController.didTapRedoButton(_:)), for: UIControlEvents.touchUpInside)
        self.view.addSubview(redoButton)
        
        recordButton.translatesAutoresizingMaskIntoConstraints = false
        recordButton.addTarget(self, action: #selector(VideoCaptureViewController.didTapRecordButton(_:)), for: UIControlEvents.touchDown)
        recordButton.addTarget(self, action: #selector(VideoCaptureViewController.didTapStopButton(_:)), for: UIControlEvents.touchUpInside)
        recordButton.addTarget(self, action: #selector(VideoCaptureViewController.didTapStopButton(_:)), for: UIControlEvents.touchUpOutside)
        self.view.addSubview(recordButton)

        reviewButton = Button()
        reviewButton.setTitle("NEXT", for: UIControlState())
        reviewButton.setTitleColor(HLColor.green, for: UIControlState())
        reviewButton.titleLabel?.font = HLFont.applicationFontCondensedBoldItalic(14)
        reviewButton.titleEdgeInsets = UIEdgeInsetsMake(36, -(redoButtonSize.width*2.0) - 17, 0, -redoButtonSize.width)
        reviewButton.isHidden = true
        reviewButton.translatesAutoresizingMaskIntoConstraints = false
        reviewButton.setImage(AssetManager.nextButtonImage(), for: UIControlState())
        reviewButton.imageView?.contentMode = .scaleAspectFit
        reviewButton.imageEdgeInsets = UIEdgeInsetsMake(-5, 0, 12, 0)
        reviewButton.addTarget(self, action: #selector(VideoCaptureViewController.didTapReviewButton(_:)), for: UIControlEvents.touchUpInside)
        self.view.addSubview(reviewButton)

        configureCaptureOverlay()
        
        toggleCameraButton = Button()
        toggleCameraButton.tintColor = HLColor.white
        toggleCameraButton.setImage(AssetManager.toggleCameraImage()?.withRenderingMode(.alwaysTemplate), for: .normal)
        toggleCameraButton.addTarget(self, action: #selector(VideoCaptureViewController.didTapToggleButton), for: .touchUpInside)
        toggleCameraButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(toggleCameraButton)
        
        importFromCameraRollButton = Button()
        importFromCameraRollButton.translatesAutoresizingMaskIntoConstraints = false
        importFromCameraRollButton.tintColor = HLColor.white
        importFromCameraRollButton.setImage(AssetManager.importFromCameraRollImage()?.withRenderingMode(.alwaysTemplate), for: .normal)
        importFromCameraRollButton.addTarget(self, action: #selector(VideoCaptureViewController.didTapImportFromCameraRollButton), for: .touchUpInside)
        view.addSubview(importFromCameraRollButton)
        
        redoButton.attachRightToLeftOfView(recordButton, offset: -20)
        .attachHeight(redoButtonSize.height)
        .attachCenterYToCenterYOfView(recordButton, offset: 0)
        .attachWidth(redoButtonSize.width)
        .addConstraintsToView(self.view)
        
        recordButton.attachWidth(88)
        .attachCenterXToView(self.view)
        .attachHeight(88)
        .attachBottomToBottomOfView(self.view, offset: -10.0)
        .addConstraintsToView(self.view)

        reviewButton.attachWidth(redoButtonSize.width)
        .attachLeftToRightOfView(recordButton, offset: 16.0)
        .attachCenterYToCenterYOfView(recordButton, offset: 0)
        .attachHeight(redoButtonSize.height)
        .addConstraintsToView(self.view)
        
        toggleCameraButton.attachWidth(60)
        .attachHeight(44)
        .attachRightToRightOfView(videoCaptureOverlayView, offset: -5)
        .attachTopToTopOfView(view, offset: 10)
        .addConstraintsToView(view)
        
        importFromCameraRollButton.attachCenterYToCenterYOfView(toggleCameraButton, offset: 0)
        .attachWidthToWidthOfView(toggleCameraButton, multiplier: 1)
        .attachHeightToHeightOfView(toggleCameraButton)
        .attachRightToLeftOfView(toggleCameraButton, offset: -10)
        .addConstraintsToView(view)
        
        updateUI()
    }
    
    open func didTapImportFromCameraRollButton(_ sender: AnyObject?) {
        if UIImagePickerController.isSourceTypeAvailable(.photoLibrary) {
            
            let imagePicker = UIImagePickerController()
            imagePicker.delegate = self
            imagePicker.sourceType = .photoLibrary
            imagePicker.mediaTypes = [kUTTypeMovie as String]
            imagePicker.allowsEditing = true
            
            present(imagePicker, animated: true, completion: nil)
            
        } else {
            let alert = Alert.error("oops!", message: "Hilite needs access to you photo library first!")
            present(alert, animated: true, completion: nil)
        }
    }
    
    open func didTapToggleButton(_ sender: AnyObject?) {
        captureSession?.toggleCamera()
    }
    
    open func configureCaptureOverlay() {
        if let overlay = videoCaptureOverlayView {
            overlay.removeFromSuperview()
        }
        videoCaptureOverlayView = StandardVideoCaptureOverlayView(delegate: self)
        
        guard let videoCaptureOverlayView = videoCaptureOverlayView else { return }
        
        videoCaptureOverlayView.translatesAutoresizingMaskIntoConstraints = false
//        self.view.insertSubview(videoCaptureOverlayView!, aboveSubview: reviewButton)
        view.addSubview(videoCaptureOverlayView)

        videoCaptureOverlayView.attachLeftToLeftOfView(self.view, offset: 0)
            .attachTopToTopOfView(self.view, offset: 0)
            .attachRightToRightOfView(self.view, offset: 0)
            .attachBottomToTopOfView(self.recordButton, offset: -15.0)
            .addConstraintsToView(self.view)
        
    }  
    
    override open func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        captureSession?.startRunning()
        updateUI()
        updateOverlay()
    }
    
    override open func viewDidLayoutSubviews() {
        capturePreviewLayer?.frame = self.view.bounds
    }
    
    override open var prefersStatusBarHidden : Bool {
        return true
    }
    
    open func updateOverlay() {
        if let unwrappedTaskAgent = taskAgent {
            videoCaptureOverlayView?.configureWithTask(unwrappedTaskAgent.getTask()!)
        }
    }
    
    open func configureCaptureSession() {
        if let session = captureSession {
            if (session.isCompleted() || session.isFailed()) {
                captureSession = StopAndGoCaptureSession(delegate: self, maxRecordTimeInSeconds: Double(maximumRecordTimeInSeconds))
            }
        }
        captureSession = captureSession ?? StopAndGoCaptureSession(delegate: self, maxRecordTimeInSeconds: Double(maximumRecordTimeInSeconds))
        if let session = captureSession {
            if let previewLayer = capturePreviewLayer {
                previewLayer.removeFromSuperlayer()
            }
            capturePreviewLayer = session.previewLayer
            if let previewLayer = capturePreviewLayer {
                self.view.layer.insertSublayer(previewLayer, at: 0)
            }
        }
    }
    
    open func updateUI() {
        DispatchQueue.main.async { [weak self] in
            
            guard let weakSelf = self else { return }
            guard let captureSession = weakSelf.captureSession else { return }
            
            weakSelf.toggleCameraButton.isHidden = captureSession.isCapturing
            
            let nothingToReview = captureSession.isCapturing || !captureSession.hasBegunCapturing()
            weakSelf.redoButton.isHidden = nothingToReview
            weakSelf.reviewButton.isHidden = nothingToReview
        }
    }

    open func reset() {
        self.recordButton.progress = 0.0
        self.captureSession?.reset()
        self.configureCaptureSession()
        self.captureSession?.startRunning()
        self.updateUI()
    }
    
    // MARK: - Actions
    open func didTapRedoButton(_ sender: AnyObject?) {
        Logger.logm()
        self.present(Alert.confirm("Redo?", message: "Are you sure you want to start over?", onConfirm: { [weak self] () -> () in
            self?.captureSession?.stopRunning()
            self?.captureSession = nil
            self?.reset()
            self?.updateOverlay()
        }), animated: true) { () -> Void in }
    }
    
    open func didTapRecordButton(_ sender: UIButton!) {
        if (minimumRecordTimer != nil) { return; }
        stopCaptureRequested = false
        if let session = captureSession {
            session.startCapturingWithCapturedVideo(nil)
            recordButton.isEnabled = false
            minimumRecordTimer = Timer.scheduledTimer(timeInterval: 0.75, target: self, selector: #selector(VideoCaptureViewController.minimumRecordTimerDidFire(_:)), userInfo: nil, repeats: false)
            updateUI()
            self.videoCaptureOverlayView?.setIsRecording(true)
        }
    }

    open func didTapStopButton(_ sender: UIButton!) {
        stopCaptureRequested = true
        if (minimumRecordTimer == nil) {
            stopCapturing()
            self.videoCaptureOverlayView?.setIsRecording(false)
        }
    }

    open func minimumRecordTimerDidFire(_ timer: Timer!) {
        Logger.logm()
        recordButton.isEnabled = true
        minimumRecordTimer?.invalidate()
        minimumRecordTimer = nil
        if (stopCaptureRequested == true) {
            stopCapturing()
        }
    }

    open func stopCapturing() {
        if let session = captureSession {
            session.stopCapturing()
            stopCaptureRequested = false
            updateUI()
        }
    }

    open func didTapCancelButton(_ sender: UIButton!) {
        let exitBlock = {
            ()->() in
            self.captureSession!.stopRunning()
            self.captureSession = nil
            self.dismiss(animated: true, completion: nil)
        }
        if (captureSession!.hasBegunCapturing()) {
            let alertController = UIAlertController(title: "Are you sure?", message: "You'll lose everything you've recorded so far!", preferredStyle: UIAlertControllerStyle.alert)
            
            let okAction = UIAlertAction(title: "Yes, I'll leave", style: UIAlertActionStyle.default, handler: { (alertAction) -> Void in
                exitBlock()
            })
            let cancelAction = UIAlertAction(title: "No, let's stay", style: UIAlertActionStyle.cancel, handler: nil)
            
            alertController.addAction(okAction)
            alertController.addAction(cancelAction)
            
            self.present(alertController, animated: true, completion: nil)
        } else {
            exitBlock()
        }
    }

    open func didTapReviewButton(_ sender: UIButton!) {
        if let session = captureSession {
            ensureMinimumCaptureLength(CMTimeGetSeconds(session.capturedDuration),
                longEnough: { ()->Void in
                    session.stopRunning()
                    session.finishUp()
                }, notLongEnough: { [weak self] ()->Void in
                    let alert = Alert.info("Oops!", message: "Your video isn't long enough. Please record at least 5 seconds, thanks!")
                    self?.present(alert, animated: true, completion: nil)
                })
        }
    }
    
    open func ensureMinimumCaptureLength(_ length: Float64, longEnough: ()->Void, notLongEnough: ()->Void) {
        if (length >= minimumCaptureDuration) {
            longEnough()
        } else {
            notLongEnough()
        }
    }

    // MARK: CaptureSessionDelegate methods
    open func captureSessionDidUpdateCaptureTimeToTimeInSeconds(_ seconds: Float64) {
        DispatchQueue.main.async(execute: { [weak self] () -> Void in
            guard let weakSelf = self else { return }
            
            let maxCaptureTime = weakSelf.captureSession!.maxRecordTimeInSeconds
            let progress = Float (seconds) / Float (maxCaptureTime)
                
            weakSelf.recordButton.progress = CGFloat(progress)
        })
    }
    open func captureSessionDidStartCapturing() {
        updateUI()
    }
    open func captureSessionDidStopCapturing() {
        updateUI()
    }
    open func captureSessionDidFinishCapturingVideo(_ capturedVideo: CapturedVideo) {
        updateUI()

        let videoReviewAgent = VideoReviewAgent(capturedVideo: capturedVideo, delegate: self)
        
        videoReviewView = InlineVideoReviewView(agent: videoReviewAgent)
        videoReviewView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(videoReviewView)
        
        videoReviewView.attachToBoundsOfView(self.view).addConstraintsToView(self.view)
    }
    
    // MARK: - VideoReviewAgentDelegate methods
    open func videoReviewAgentDidAcceptVideo(_ agent: VideoReviewAgent) {
        Logger.logm()

        let userId = ApplicationPreferencesBackedUserSession().userId()
        self.dismiss(animated: true) {
            ()->Void in
            self.captureAgent?.finishCapturingWithCapturedVideo(agent.capturedVideo, userId: userId!)
            self.captureSession = nil
            return ()
        }
    }
    
    open func videoReviewAgent(_ agent: VideoReviewAgent, didDiscardVideoWithDiscardedBlock discardBlock: @escaping ()->()) {
        Logger.logm()
        let alert = Alert.confirm("re-do?", message: "are you sure you want to re-do this video?") { [weak self] () -> () in
            discardBlock()
            self?.videoReviewView.removeFromSuperview()
            self?.reset()
        }
        self.present(alert, animated: true, completion: nil)
    }
    
    // MARK: - VideoCaptureOverlayViewDelegate methods
    open func videoCaptureOverlayViewDidTapCancelButton(_ overlayView: VideoCaptureOverlayView?) {
        self.didTapCancelButton(nil)
    }
    // MARK: - Suspendable
    open func suspend() {
        self.captureSession?.suspend()
    }
    open func resume() {
        self.captureSession?.resume()
    }
    
}

extension VideoCaptureViewController: UIImagePickerControllerDelegate {
    public func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String : Any]) {
        
        guard let url = info[UIImagePickerControllerMediaURL] as? URL else { return }
        
        let capturedVideo = FileBackedCapturedVideo(fileUrl: url)
        
        picker.presentingViewController?.dismiss(animated: true, completion: { [weak self] in
            self?.captureSessionDidFinishCapturingVideo(capturedVideo)

        })
    }
}
