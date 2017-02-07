//
//  DoubleExtension.swift
//  SwoopParkingApp
//
//  Created by Daniel Nomura on 2/6/17.
//  Copyright © 2017 Daniel Nomura. All rights reserved.
//

import Foundation

extension Double {
    func metersToDistanceString(forSystem system: SystemOfMeasurement) -> String {
        switch system {
        case .metric:
            if self < 1000 && self > -1000 {
                return String(format: "%.2f m", self)
            } else {
                let kilometers = self / 1000
                return String(format: "%.2f km", kilometers)
            }
        case .us:
            return String(format: "%.2f mi", self.toMiles)
        }
    }
    var toMiles: Double {
        return self / 1609.344
    }
    
    func toZoomFromWidthInMeters(forView view: UIView) -> Float {
        // https://developers.google.com/maps/documentation/ios-sdk/views#zoom
        // "at zoom level N, the width of the world is approximately 256 * 2^N, i.e., at zoom level 2, the whole world is approximately 1024 points wide"
        // world width points = local points * world width meters / local meters
        // 2 ^ N = world width points / 256
        // N = log2(world width points / 256)
        // local points = map width
        let localPoints = Double(view.bounds.width)
        //Self must be a value in meters
        let worldPoints = localPoints * worldMeters / self
        let zoom = log2(worldPoints / 256.0)
        return Float(zoom)
    }
}

extension Float {
    func toWidthInMetersFromGMSZoom(forView view: UIView) -> Double {
        // https://developers.google.com/maps/documentation/ios-sdk/views#zoom
        // "at zoom level N, the width of the world is approximately 256 * 2^N, i.e., at zoom level 2, the whole world is approximately 1024 points wide"
        //Using proportions localMeters / worldMeters = localPoints / worldPoints
        //worldPoints = (2 ^ zoom) * 256
        //localMeters = worldMeters * (localPoints / worldPoints)
        let localPointWidth = Double(view.bounds.width)
        //Self must be zoom for GMSCameraPosition
        let worldPointWidth = Double(pow(2, self) * 256)
        let localMeters = (localPointWidth / worldPointWidth) * worldMeters
        return localMeters
    }
}
