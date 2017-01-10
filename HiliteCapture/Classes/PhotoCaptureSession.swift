import Foundation
import AVFoundation

open class PhotoCaptureSession {
    let captureSession = AVCaptureSession()
    public let captureOutput = AVCaptureStillImageOutput()
    let captureDevice = CaptureDevice()
    public var videoCaptureDevice: AVCaptureDevice?
    public var captureDeviceInput: AVCaptureDeviceInput?
    public var capturePreviewLayer: AVCaptureVideoPreviewLayer?
    
    public init() {
        captureSession.beginConfiguration()
        
        captureSession.sessionPreset = AVCaptureSessionPresetHigh
        let videoDevices = captureDevice.videoDevices()
        
        for device:AVCaptureDevice in videoDevices {
            if (device.position == AVCaptureDevicePosition.front) {
                videoCaptureDevice = device
                break
            }
        }

        do {
            captureDeviceInput = try AVCaptureDeviceInput(device: self.videoCaptureDevice)
        } catch {
            print("COULD NOT CREATE VIDEO CAPTURE DEVICE INPUT")
            return
        }
        
        if (captureSession.canAddInput(captureDeviceInput)) {
            captureSession.addInput(captureDeviceInput)
        }
        
        captureOutput.outputSettings = [AVVideoCodecKey: AVVideoCodecJPEG]
        if (captureSession.canAddOutput(captureOutput)) {
            captureSession.addOutput(captureOutput)
        }
        
        captureSession.commitConfiguration()

        capturePreviewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
    }
    
    public func startRunningWithNoCameraAvailable(_ noCameraAvailable: ()->()) {
        if (videoCaptureDevice == nil) {
            noCameraAvailable()
        } else {
            self.startRunning()
        }
    }
    
    public func startRunning() {
        if (captureSession.isRunning) { return }
        captureSession.startRunning()
    }
    
    public func stopRunning() {
        if (!captureSession.isRunning) { return }
        captureSession.stopRunning()
    }
    
    public func captureWithSuccess(_ success: @escaping (UIImage!)->(), error: @escaping (NSError?)->()) {
        var videoConnection: AVCaptureConnection?
        for connection in self.captureOutput.connections {
            for port in (connection as AnyObject).inputPorts! {
                if ((port as AnyObject).mediaType == AVMediaTypeVideo) {
                    videoConnection = connection as? AVCaptureConnection
                    break
                }
            }
            if (videoConnection != nil) { break }
        }
        
        if let c = videoConnection {
            c.videoOrientation = AVCaptureVideoOrientation.portrait
            captureOutput.captureStillImageAsynchronously(from: c, completionHandler: { (sampleBuffer, err) -> Void in
                if (err != nil) {
                    error(err as NSError?)
                } else {
                    let imageData = AVCaptureStillImageOutput.jpegStillImageNSDataRepresentation(sampleBuffer)
                    let ciImage = CIImage(data: imageData!)

                    let uiImage = UIImage(ciImage: ciImage!)
                    let size = uiImage.size

                    let transformedImage = ciImage!.applying(CGAffineTransform(rotationAngle: -90.degreesToRadians))
                    let translatedImage = transformedImage.applying(CGAffineTransform(translationX: 0, y: size.width))
                    
                    let coreContext = CIContext(eaglContext: EAGLContext(api: EAGLRenderingAPI.openGLES2))
                    
                    let cgImage = coreContext.createCGImage(translatedImage, from: CGRect(x: 0, y: 0, width: uiImage.size.height, height: uiImage.size.width))
                    
                    success(UIImage(cgImage: cgImage!))
                }
            })
        } else {
            print("could not find a video connection!", terminator: "")
        }
    }
}
