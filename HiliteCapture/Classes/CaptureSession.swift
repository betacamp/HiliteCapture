import Foundation
import AVFoundation
import HiliteCore

public protocol CaptureSession: Suspendable {
    var previewLayer: AVCaptureVideoPreviewLayer! { get }
    var maxRecordTimeInSeconds: TimeInterval { get }
    var isCapturing: Bool { get }
    var capturedDuration: CMTime! { get }

    func hasBegunCapturing() -> Bool

    func startRunning()
    func stopRunning()

    func startCapturingWithCapturedVideo(_ capturedVideo: CapturedVideo?)
    func stopCapturing()
    
    func isCompleted() -> Bool
    func isFailed() -> Bool
    func reset()
    func finishUp()
    func cleanup()

    func toggleCamera()

    func isFrontCameraSupported() -> Bool
}
