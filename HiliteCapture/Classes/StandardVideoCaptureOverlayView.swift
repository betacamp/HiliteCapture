import Foundation
import UIKit
import HiliteUI
import HiliteCore

open class StandardVideoCaptureOverlayView: UIControl, VideoCaptureOverlayView, TaskView {
    let textView = HLTextView(frame: CGRect.zero)
    let recipientNameLabel = HLLabel()
    let customerNameLabel = HLLabel()
    let cancelButton = Button()
    let topBarView = HLView()
    public var delegate: VideoCaptureOverlayViewDelegate?

    public init(delegate: VideoCaptureOverlayViewDelegate?) {
        super.init(frame: CGRect.zero)
        
        self.delegate = delegate
        
        self.backgroundColor = HLColor.black.withAlphaComponent(0.6)

        topBarView.backgroundColor = HLColor.black
        topBarView.translatesAutoresizingMaskIntoConstraints = false
        self.addSubview(topBarView)
        
        cancelButton.backgroundColor = HLColor.black
        cancelButton.addTarget(self, action: #selector(StandardVideoCaptureOverlayView.didTapCancelButton(_:)), for: UIControlEvents.touchUpInside)
        cancelButton.setImage(AssetManager.closeButtonImage()?.withRenderingMode(UIImageRenderingMode.alwaysTemplate), for: UIControlState())
        cancelButton.tintColor = HLColor.gray
        cancelButton.translatesAutoresizingMaskIntoConstraints = false
        topBarView.addSubview(cancelButton)
        
        recipientNameLabel.font = HLFont.applicationFontCondensedBoldItalic(28)
        recipientNameLabel.adjustsFontSizeToFitWidth = true
        recipientNameLabel.minimumScaleFactor = 0.75
        recipientNameLabel.textColor = HLColor.green
        recipientNameLabel.textAlignment = .center
        recipientNameLabel.translatesAutoresizingMaskIntoConstraints = false
        topBarView.addSubview(self.recipientNameLabel)
        
        customerNameLabel.font = HLFont.applicationFontCondensedItalic(26)
        customerNameLabel.adjustsFontSizeToFitWidth = true
        customerNameLabel.minimumScaleFactor = 0.75
        customerNameLabel.textColor = HLColor.white
        customerNameLabel.translatesAutoresizingMaskIntoConstraints = false
        self.addSubview(self.customerNameLabel)
        
        textView.textColor = HLColor.white
        textView.isEditable = false
        textView.backgroundColor = HLColor.clear
        textView.isScrollEnabled = true
        textView.textAlignment = NSTextAlignment.justified
        textView.font = customerNameLabel.font
        textView.translatesAutoresizingMaskIntoConstraints = false
        self.addSubview(self.textView)
        
        let padding:CGFloat = 10.0
        
        topBarView.attachHeight(64)
            .attachLeftToLeftOfView(self, offset: 0)
            .attachRightToRightOfView(self, offset: 0)
            .attachTopToTopOfView(self, offset: 0)
            .addConstraintsToView(self)
        
        cancelButton.attachHeight(36)
            .attachWidth(36)
            .attachLeftToLeftOfView(topBarView, offset: 14)
            .attachCenterYToCenterYOfView(self.topBarView, offset: 0)
            .addConstraintsToView(topBarView)
        
        recipientNameLabel.attachTopToTopOfView(topBarView, offset: 0)
            .attachLeftToRightOfView(self.cancelButton, offset: padding)
            .attachRightToRightOfView(topBarView, offset: -58)
            .attachBottomToBottomOfView(topBarView, offset: 0)
            .addConstraintsToView(self)
        
        let textPadding:CGFloat = 45.0

        customerNameLabel.attachHeight(30.0)
            .attachLeftToLeftOfView(self, offset: textPadding)
            .attachRightToRightOfView(self, offset: -textPadding)
            .attachTopToBottomOfView(recipientNameLabel, offset: 25)
            .addConstraintsToView(self)
        
        textView.attachTopToBottomOfView(customerNameLabel, offset: padding)
            .attachLeftToLeftOfView(customerNameLabel, offset: 0)
            .attachRightToRightOfView(customerNameLabel, offset: 0)
            .attachBottomToBottomOfView(self, offset: -padding)
            .addConstraintsToView(self)
    }
    
    
    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    open func setIsRecording(_ isRecording: Bool) {
        let color = isRecording ? HLColor.recordingTextColor() : HLColor.white
        
        textView.textColor = color
    }
    
    open func configureWithTask(_ task: Task?) {
        if let unwrappedTask = task {
            self.textView.text = unwrappedTask.teleprompterText()
//            if let recipient = unwrappedTask.recipient() {
//                recipientNameLabel.text = "AYO, \(recipient.displayName())!".uppercased()
//            }
//            if let customer = unwrappedTask.purchaser() {
//                customerNameLabel.text = "From: \(customer.displayName())".uppercased()
//            }
        }
    }
    
    // MARK: - Actions
    open func didTapCancelButton(_ sender: AnyObject?) {
        delegate?.videoCaptureOverlayViewDidTapCancelButton(self)
    }
}
