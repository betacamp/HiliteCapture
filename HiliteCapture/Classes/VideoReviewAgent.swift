import Foundation
import HiliteCore

public class VideoReviewAgent {
    var capturedVideo:CapturedVideo!
    let delegate: VideoReviewAgentDelegate?
    
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
