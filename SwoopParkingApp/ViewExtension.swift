//
//  ViewExtension.swift
//  SwoopParkingApp
//
//  Created by Daniel Nomura on 2/9/17.
//  Copyright © 2017 Daniel Nomura. All rights reserved.
//

import Foundation

extension UIView {
    func createBorder(width: CGFloat = 1.5, cornerRadius: CGFloat = 7, color: CGColor = UIColor.blue.cgColor) {
        layer.borderWidth = width
        layer.cornerRadius = cornerRadius
        layer.borderColor = color
    }
    
    func hideBorder() {
        layer.borderColor = UIColor.clear.cgColor
    }
}
