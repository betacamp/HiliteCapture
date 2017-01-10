//
//  Extensions.swift
//  Pods
//
//  Created by Preston Pope on 1/6/17.
//
//

import Foundation
import HiliteUI

extension Int {
    var degreesToRadians: CGFloat {
        return CGFloat(self) * CGFloat(M_PI) / CGFloat(180.0)
    }
}

extension AssetManager {
    public class func redoButtonImage() -> UIImage? { return nil }
    public class func closeButtonImage() -> UIImage? { return nil }
    public class func nextButtonImage() -> UIImage? { return nil }
    public class func toggleCameraImage() -> UIImage? { return nil }
    public class func importFromCameraRollImage() -> UIImage? { return nil }
}
