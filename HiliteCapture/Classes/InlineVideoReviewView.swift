import Foundation
import UIKit
import AVFoundation
import HiliteCore
import HiliteUI

open class InlineVideoReviewView: UIControl {
    public var videoPlayer:AVPlayer!
    public var agent:VideoReviewAgent!
    var playerItem:AVPlayerItem!
    var playerLayer: AVPlayerLayer!
    public let closeButton = Button()
    public let acceptButton = Button()
    
    public let videoPlayerView = VideoPlayerView()

    public init(agent: VideoReviewAgent) {
        super.init(frame: CGRect.zero)

        self.backgroundColor = HLColor.black
        
        self.addTarget(self, action: #selector(InlineVideoReviewView.didTap(_:)), for: UIControlEvents.touchUpInside)
        
        self.agent = agent

        playerItem = AVPlayerItem(url: agent.capturedVideo.fileUrlToMOV! as URL)
        
        videoPlayer = AVPlayer(playerItem: playerItem)
        videoPlayer.actionAtItemEnd = AVPlayerActionAtItemEnd.pause
        
        playerLayer = AVPlayerLayer(player: videoPlayer)
        playerLayer.videoGravity = AVLayerVideoGravityResizeAspectFill

        videoPlayerView.translatesAutoresizingMaskIntoConstraints = false
        videoPlayerView.isUserInteractionEnabled = false
        videoPlayerView.addPlayerLayer(playerLayer)
        self.addSubview(videoPlayerView)
        
        let redoButtonSize = CGSize(width: 70, height: 46)
        
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        closeButton.setTitle("REDO", for: UIControlState())
        closeButton.setTitleColor(HLColor.green, for: UIControlState())
        closeButton.titleLabel?.font = HLFont.applicationFontCondensedBoldItalic(14)
        closeButton.titleEdgeInsets = UIEdgeInsetsMake(36, -(redoButtonSize.width*2.0) - 17, 0, -redoButtonSize.width)
        closeButton.setImage(AssetManager.reviewBackButtonImage(), for: UIControlState())
        closeButton.imageView?.contentMode = .scaleAspectFit
        closeButton.imageEdgeInsets = UIEdgeInsetsMake(-5, 0, 12, 0)
        closeButton.addTarget(self, action: #selector(InlineVideoReviewView.didTapClose(_:)), for: UIControlEvents.touchUpInside)
        self.addSubview(closeButton)
        
        acceptButton.translatesAutoresizingMaskIntoConstraints = false
        acceptButton.setTitle("SEND IT!", for: UIControlState())
        acceptButton.setTitleColor(HLColor.green, for: UIControlState())
        acceptButton.titleLabel?.font = HLFont.applicationFontCondensedBoldItalic(14)
        acceptButton.titleEdgeInsets = UIEdgeInsetsMake(36, -(redoButtonSize.width*2.0) - 17, 0, -redoButtonSize.width)
        acceptButton.setImage(AssetManager.reviewApproveButtonImage(), for: UIControlState())
        acceptButton.imageEdgeInsets = UIEdgeInsetsMake(-5, 0, 12, 0)
        acceptButton.imageView?.contentMode = .scaleAspectFit
        acceptButton.addTarget(self, action: #selector(InlineVideoReviewView.didTapAccept(_:)), for: UIControlEvents.touchUpInside)
        self.addSubview(acceptButton)

        NotificationCenter.default.addObserver(forName: NSNotification.Name.AVPlayerItemDidPlayToEndTime, object: nil, queue: nil) { [weak self] (notification) -> Void in
            self?.videoPlayer.seek(to: kCMTimeZero)
        }
        
        videoPlayerView.attachToBoundsOfView(self)
            .addConstraintsToView(self)
        
        closeButton.attachWidth(redoButtonSize.width)
            .attachHeight(redoButtonSize.height)
            .attachLeftToLeftOfView(self, offset: 30)
            .attachBottomToBottomOfView(self, offset: -30)
            .addConstraintsToView(self)

        acceptButton.attachWidth(redoButtonSize.width)
            .attachHeight(redoButtonSize.height)
            .attachRightToRightOfView(self, offset: -30)
            .attachBottomToBottomOfView(self, offset: -30)
            .addConstraintsToView(self)
    }

    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override open func didMoveToSuperview() {
        super.didMoveToSuperview()
        
        if superview != nil {
            videoPlayer.play()            
        }
    }
    
    override open func willMove(toSuperview newSuperview: UIView?) {
        if newSuperview == nil {
            self.videoPlayer.pause()
        }
    }
    
    override open func layoutSubviews() {
        super.layoutSubviews()
        
        print(videoPlayerView.frame, terminator: "")
    }
    
    open func didTap(_ sender: AnyObject!) {
        if (self.videoPlayer.rate > 0.0) {
            videoPlayer.pause()
        } else {
            videoPlayer.play()
        }
    }
    open func didTapClose(_ sender: AnyObject!) {
        self.videoPlayer.pause()
        agent.discardVideo({ ()->() in
        })
    }
    open func didTapAccept(_ sender: AnyObject!) {
        videoPlayer.pause()
        agent.acceptVideo()
    }
}
