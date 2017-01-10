import Foundation
import AVFoundation
import HiliteCore

fileprivate func handleError(_ error: NSError?) {
    if let unwrapped = error {
        Logger.logv(unwrapped)
    }
}

open class CaptureDevice {
    let device = Device()
    var frontFacingCameraInput: AVCaptureDeviceInput?
    var backFacingCameraInput: AVCaptureDeviceInput?
    var audioInput: AVCaptureDeviceInput?
    
    public init() {
        if let fontFacingCamera = CaptureDevice.frontFacingCamera() {
            do {
                self.frontFacingCameraInput = try AVCaptureDeviceInput(device: fontFacingCamera)
            } catch {
                handleError(nil)
            }
        }

        if let backFacingCamera = CaptureDevice.backFacingCamera() {
            do {
                backFacingCameraInput = try AVCaptureDeviceInput(device: backFacingCamera)
            } catch {
                handleError(nil)
            }
        }
        
        if let audioDeviceInput = CaptureDevice.audioDevice() {
            do {
                audioInput = try AVCaptureDeviceInput(device: audioDeviceInput)
            } catch {
                handleError(nil)
            }
        }
    }
    
    public class func frontFacingCamera() -> AVCaptureDevice? {
        return cameraWithPosition(AVCaptureDevicePosition.front)
    }
    
    public class func backFacingCamera() -> AVCaptureDevice? {
        return cameraWithPosition(AVCaptureDevicePosition.back)
    }
    
    public class func cameraWithPosition(_ position: AVCaptureDevicePosition) -> AVCaptureDevice? {
        let devices = AVCaptureDevice.devices(withMediaType: AVMediaTypeVideo) as! Array<AVCaptureDevice>
        for device:AVCaptureDevice in devices {
            if (device.position == position) {
                var error:NSError?
                do {
                    try device.lockForConfiguration()
                } catch let error1 as NSError {
                    error = error1
                }
                
                if let e = error {
                    print("\(e.localizedDescription)")
                }
                
                let format = device.activeFormat
//                for range in (format?.videoSupportedFrameRateRanges)! {
//                    print("\(CMTimeGetSeconds((range as AnyObject).maxDuration ?? kCMTimeZero))")
//                    print("\((range as AnyObject).minFrameRate ?? 0.0)")
//                    println("\(range.minFrameRate!)")
//                }
                
//                device.activeVideoMinFrameDuration = CMTimeMake(1, 30)
//                device.activeVideoMaxFrameDuration = CMTimeMake(1, 30)
                device.unlockForConfiguration()
                return device
            }
        }
        return nil
    }
    
    public func videoDevices() -> [AVCaptureDevice] {
        return AVCaptureDevice.devices(withMediaType: AVMediaTypeVideo) as! [AVCaptureDevice]
    }
    
    public func hasCamera() -> Bool {
        return backFacingCameraInput != nil || frontFacingCameraInput != nil
    }
    
    public class func audioDevice() -> AVCaptureDevice? {
        let devices = AVCaptureDevice.devices(withMediaType: AVMediaTypeAudio)
        if ((devices?.count)! > 0) {
            return devices?[0] as? AVCaptureDevice
        }
        return nil
    }
    
    public func isCameraSupported() -> Bool {
        return hasCamera()
    }
    
    public func isFlashSupported() -> Bool {
        return hasFlashlight()
    }
    
    public func hasFlashlight() -> Bool {
        return hasBackFlashlight() || hasFrontFlashlight()
    }
    
    public func hasBackFlashlight() -> Bool {
        if let camera = CaptureDevice.backFacingCamera() {
            return camera.hasTorch
        }
        return false
    }
    
    public func hasFrontFlashlight() -> Bool {
        if let camera = CaptureDevice.frontFacingCamera() {
            return camera.hasTorch
        }
        return false
    }
    
    public func isFrontFacingCameraSupported() -> Bool {
        return frontFacingCameraInput != nil
    }
    public func isBackFacingCameraSupported() -> Bool {
        return backFacingCameraInput != nil
    }
    
    public class func isAuthorizedForVideo() -> Bool {
        return AVCaptureDevice.authorizationStatus(forMediaType: AVMediaTypeVideo) == AVAuthorizationStatus.authorized
    }
    public class func isAuthorizationDeniedForVideo() -> Bool {
        return AVCaptureDevice.authorizationStatus(forMediaType: AVMediaTypeVideo) == AVAuthorizationStatus.denied
    }
    public class func isAuthorizationDeniedForAudio() -> Bool {
        return AVCaptureDevice.authorizationStatus(forMediaType: AVMediaTypeAudio) == AVAuthorizationStatus.denied
    }
}
