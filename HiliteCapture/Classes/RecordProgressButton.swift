import Foundation
import UIKit
import GLKit
import HiliteUI

open class RecordProgressButton: UIControl {
    fileprivate var _progress:CGFloat = 0
    
    public var buttonBaseColor:UIColor! = HLColor.recordButtonBaseColor()
    public var buttonTopColor:UIColor! = HLColor.green
    public var progressColor:UIColor! = HLColor.recordButtonProgressColor()
    public var progress:CGFloat {
        get { return self._progress }
        set(newValue) {
            self._progress = newValue
            self.setNeedsDisplay()
        }
    }
    public let textLabel = HLLabel()
    
    override public init(frame: CGRect) {
        super.init(frame: frame)
        self.configure()
    }
    public init() {
        super.init(frame: CGRect.zero)
        self.configure()
    }

    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public func configure() {
        self.backgroundColor = UIColor.clear
        
        textLabel.text = "PRESS/\nHOLD TO\nRECORD"
        textLabel.numberOfLines = 3
        textLabel.font = HLFont.applicationFontCondensedBoldItalic(14)
        textLabel.textAlignment = .center
        textLabel.transform = CGAffineTransform(rotationAngle: CGFloat(GLKMathDegreesToRadians(-7)))
        
        self.addSubview(textLabel)
    }
    
    override open func layoutSubviews() {
        super.layoutSubviews()
        
        textLabel.frame = self.bounds
    }
    
    override open func draw(_ rect: CGRect) {
        super.draw(rect)
        
        // base circle
        let baseCirclePath = UIBezierPath(ovalIn: self.bounds)
        self.buttonBaseColor.setFill()
        baseCirclePath.fill()
        
        let context = UIGraphicsGetCurrentContext()

        // progress wedge
        context?.setFillColor(self.progressColor.cgColor)
        context?.move(to: CGPoint(x: self.bounds.size.width / 2.0, y: self.bounds.size.height / 2.0))
//        CGContextAddLineToPoint(context, self.bounds.size.width / 2.0, 0)
        context?.addArc(center: CGPoint(x: self.bounds.size.width/2.0, y: self.bounds.size.height/2.0), radius: self.bounds.size.width / 2.0, startAngle: CGFloat(GLKMathDegreesToRadians(-90)), endAngle: CGFloat(GLKMathDegreesToRadians(Float(360)*Float(self._progress)) - GLKMathDegreesToRadians(90)), clockwise: false)

        context?.closePath()
        context?.fillPath()
        
        context?.setFillColor(self.buttonTopColor.cgColor)
        context?.setShadow(offset: CGSize(width: 2, height: 2), blur: 5.0, color: HLColor.darkGrayColor().withAlphaComponent(0.7).cgColor)
        
        context?.addEllipse(in: self.bounds.insetBy(dx: 7, dy: 7))
        context?.drawPath(using: CGPathDrawingMode.fill)
        
        
    }
}
