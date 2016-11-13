//
//  SPHeatMapManager.swift
//  SwoopParkingApp
//
//  Created by Daniel Nomura on 8/8/16.
//  Copyright © 2016 Daniel Nomura. All rights reserved.
//

import Foundation
import GoogleMaps
import UIKit


class SPGroundOverlayManager {
    // https://developers.google.com/maps/documentation/ios-sdk/views#zoom
    // "at zoom level N, the width of the world is approximately 256 * 2^N, i.e., at zoom level 2, the whole world is approximately 1024 points wide"
    
    func groundOverlays(forMap map:GMSMapView, forLocations locations:[SPLocation]) -> [GMSGroundOverlay] {
        let points = cgPoints(forMap: map, forLocations: locations)
        var groundOverlays = [GMSGroundOverlay]()
        
        let heatMap = LFHeatMap.heatMap(with: map.bounds, boost: 0.1, points: points, weights: nil)
        let groundOverlay = GMSGroundOverlay.init(bounds: GMSCoordinateBounds.init(region: map.projection.visibleRegion()), icon: heatMap)
        groundOverlay.isTappable = true
        groundOverlays.append(groundOverlay)
        return groundOverlays
    }
    
    fileprivate func cgPoints(forMap map:GMSMapView, forLocations locations:[SPLocation]) -> [NSValue] {
        
        var points = [NSValue]()
        for location in locations {
            guard let fromCoordinate = location.fromCoordinate else {
                print("Missing coordinate for location: \(location.locationNumber)")
                continue
            }
            let pointOnMap = NSValue(cgPoint:map.projection.point(for: fromCoordinate))
            points.append(pointOnMap)
        }
        return points
    }
    
}

