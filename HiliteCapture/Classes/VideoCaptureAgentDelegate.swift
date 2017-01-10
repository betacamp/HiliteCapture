import Foundation
import HiliteCore

public protocol VideoCaptureAgentDelegate {
    func videoCaptureAgent(_ agent:VideoCaptureAgent, finishedWithCapturedVideo:CapturedVideo, task: Task, userId: UserId)
}
