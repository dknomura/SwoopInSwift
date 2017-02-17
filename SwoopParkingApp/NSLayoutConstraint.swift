//
//  NSLayoutConstraint.swift
//  SwoopParkingApp
//
//  Created by Daniel Nomura on 2/15/17.
//  Copyright © 2017 Daniel Nomura. All rights reserved.
//

import Foundation

extension NSLayoutConstraint {
    override open var description: String {
        if let id = identifier {
            return "id: \(id), constant: \(constant)"
        } else {
            return "NSLayoutConstraint first item: \(firstAttribute.description), \(firstItem) (\(constant)) second item: \(secondAttribute.description), \(secondItem)"
        }
    }
}
extension NSLayoutAttribute {
    var description: String {
        switch self {
        case .bottom, .bottomMargin: return "bottom"
        case .centerX, .centerXWithinMargins: return "centerX"
        case .centerY, .centerYWithinMargins: return "centerY"
        case .height: return "height"
        case .leading, .leadingMargin: return "leading"
        case .left, .leftMargin: return "left"
        case .notAnAttribute: return "notAnAttribute"
        case .right, .rightMargin:  return "right"
        case .top, .topMargin: return "top"
        case .trailing, .trailingMargin: return "trailing"
        case .width: return "width"
        case .firstBaseline: return "firstBaseline"
        case .lastBaseline: return "lastBaseline"
        }
    }
}
