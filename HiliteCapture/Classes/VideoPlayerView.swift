import Foundation
import UIKit
import AVFoundation
import HiliteCore
import HiliteUI

public class VideoPlayerView: UIView {
    var playerLayer: AVPlayerLayer?
    
    public init() {
        super.init(frame: CGRect.zero)
        
        self.backgroundColor = HLColor.clear
    }
    
    public func addPlayerLayer(_ playerLayer: AVPlayerLayer!) {
        self.playerLayer = playerLayer
        self.layer.addSublayer(self.playerLayer!)
    }
    
    override open func layoutSubviews() {
        super.layoutSubviews()
        
        self.playerLayer?.frame = self.bounds
    }

    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
