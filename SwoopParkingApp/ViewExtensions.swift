//
//  ViewExtensions.swift
//  SwoopParkingApp
//
//  Created by Daniel Nomura on 11/14/16.
//  Copyright © 2016 Daniel Nomura. All rights reserved.
//

import Foundation


extension UIView {
    func createBorder(width: CGFloat = 1.5, cornerRadius: CGFloat = 7, color: CGColor = UIColor.blue.cgColor) {
        layer.borderWidth = width
        layer.cornerRadius = cornerRadius
        layer.borderColor = color
    }
}
