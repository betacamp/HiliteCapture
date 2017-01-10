import Foundation
import HiliteCore

public class VideoCaptureAgent {
    public let delegate: VideoCaptureAgentDelegate?
    let task: Task!
    
    public init(delegate: VideoCaptureAgentDelegate?, task: Task) {
        self.delegate = delegate
        self.task = task
    }
    
    public func finishCapturingWithCapturedVideo(_ capturedVideo: CapturedVideo, userId: UserId) {
        delegate?.videoCaptureAgent(self, finishedWithCapturedVideo:capturedVideo, task: task, userId: userId)
    }
    
}
