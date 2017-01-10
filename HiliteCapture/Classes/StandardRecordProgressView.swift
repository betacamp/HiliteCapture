import Foundation
import UIKit
import HiliteUI
import HiliteCore

fileprivate let bgColor = HLColor.lightGray.withAlphaComponent(0.6)

class StandardRecordProgressView: UIView, RecordProgressView {
    var progress: Float = 0.0 {
        didSet {
            DispatchQueue.main.async(execute: { [weak self] () -> Void in
                self?.setNeedsDisplay()
            })
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        self.backgroundColor = bgColor
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func draw(_ rect: CGRect) {
        super.draw(rect)

        let width = self.bounds.size.width * CGFloat (self.progress)
        
        let progressPath = UIBezierPath(rect: CGRect(x: 0, y: 0, width: CGFloat (width), height: self.bounds.size.height))
        HLColor.yellow.setFill()
        progressPath.fill()

        let outlinePath = UIBezierPath(rect: self.bounds)
        bgColor.setStroke()
        outlinePath.stroke()
    }
}
