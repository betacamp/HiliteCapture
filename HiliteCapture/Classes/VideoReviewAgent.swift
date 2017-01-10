import Foundation
import HiliteCore

public class VideoReviewAgent {
    public var capturedVideo:CapturedVideo!
    public let delegate: VideoReviewAgentDelegate?
    
    public init(capturedVideo: CapturedVideo, delegate: VideoReviewAgentDelegate) {
        self.delegate = delegate
        self.capturedVideo = capturedVideo
    }
    
    public func discardVideo(_ onDiscard: @escaping ()->()) {
        Logger.logm()
        
        delegate?.videoReviewAgent(self, didDiscardVideoWithDiscardedBlock: onDiscard)
    }
    public func acceptVideo() {
        Logger.logm()
        delegate?.videoReviewAgentDidAcceptVideo(self)
    }
}
