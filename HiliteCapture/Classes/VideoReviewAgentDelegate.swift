import Foundation

public protocol VideoReviewAgentDelegate {
    func videoReviewAgent(_ agent: VideoReviewAgent, didDiscardVideoWithDiscardedBlock: @escaping ()->())
    func videoReviewAgentDidAcceptVideo(_ agent: VideoReviewAgent)
}
