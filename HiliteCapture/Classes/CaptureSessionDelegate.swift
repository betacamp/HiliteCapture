import Foundation
import HiliteCore

public protocol CaptureSessionDelegate {
    func captureSessionDidUpdateCaptureTimeToTimeInSeconds(_ seconds: Float64)
    func captureSessionDidStartCapturing()
    func captureSessionDidStopCapturing()
    func captureSessionDidFinishCapturingVideo(_ capturedVideo: CapturedVideo)
}
