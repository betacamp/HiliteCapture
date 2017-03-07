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
