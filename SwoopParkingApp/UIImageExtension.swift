//
//  UIImageExtension.swift
//  SwoopParkingApp
//
//  Created by Daniel Nomura on 2/6/17.
//  Copyright © 2017 Daniel Nomura. All rights reserved.
//

import Foundation

extension UIImage {
    static func imageWith(image: UIImage, scaledToSize size:CGSize) -> UIImage {
        UIGraphicsBeginImageContextWithOptions(size, false, 0.0)
        image.draw(in: CGRect(x: 0, y: 0, width: size.width, height: size.width))
        let returnImage: UIImage
        if let newImage = UIGraphicsGetImageFromCurrentImageContext() {
            returnImage = newImage
        } else {
            returnImage = image
        }
        UIGraphicsEndImageContext()
        return returnImage
    }
}
