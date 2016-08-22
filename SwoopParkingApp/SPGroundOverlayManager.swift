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
//        let zoomRatio = CGFloat(pow(2, map.camera.zoom) / pow(2, 15))
//        guard zoomRatio < 1 else {
//            print("Cannot get ground overlays, zoom is greater than 15")
//            throw HeatMapError.zoomGreaterThan15
//        }
//        let numberOfFrameDivisions = Int(pow(2, 15) / pow(2, map.camera.zoom))
//        let remainderOfFrame = CGFloat(pow(2, 15) / pow(2, map.camera.zoom) - Float(numberOfFrameDivisions))
        
        let points = cgPoints(forMap: map, forLocations: locations)
        var groundOverlays = [GMSGroundOverlay]()
        
        let heatMap = LFHeatMap.heatMapWithRect(map.bounds, boost: 0.1, points: points, weights: nil)
        let groundOverlay = GMSGroundOverlay.init(bounds: GMSCoordinateBounds.init(region: map.projection.visibleRegion()), icon: heatMap)
        groundOverlay.tappable = true
        groundOverlays.append(groundOverlay)

        
//        for y in 0...numberOfFrameDivisions {
//            for x in 0...numberOfFrameDivisions {
//                let xOrigin = CGFloat(x) * zoomRatio * map.frame.size.width
//                let yOrigin = CGFloat(y) * zoomRatio * map.frame.size.height
//                var width = zoomRatio * map.frame.width
//                var height = zoomRatio * map.frame.height
//                if y == numberOfFrameDivisions {
//                    height *= remainderOfFrame
//                }
//                if x == numberOfFrameDivisions {
//                    width *= remainderOfFrame
//                }
//                let bounds = CGRectMake(xOrigin, yOrigin, width, height)
//                let heatMap = LFHeatMap.heatMapWithRect(bounds, boost: 0.1, points: points, weights: nil)
//
//                let southWestCoordinate = map.projection.coordinateForPoint(CGPoint(x: bounds.origin.x, y: bounds.origin.y + bounds.size.height))
//                let northEastCoordinate = map.projection.coordinateForPoint(CGPoint(x: bounds.origin.x + bounds.size.width, y:bounds.origin.y))
//                let coordinateBounds = GMSCoordinateBounds.init(coordinate: southWestCoordinate, coordinate: northEastCoordinate)
//                
//                let groundOverlay = GMSGroundOverlay.init(bounds: coordinateBounds, icon: heatMap)
//                groundOverlay.tappable = true
//                groundOverlays.append(groundOverlay)
//            }
//        }
        return groundOverlays
    }
    
    private func cgPoints(forMap map:GMSMapView, forLocations locations:[SPLocation]) -> [NSValue] {
        
        var points = [NSValue]()
        for location in locations {
            guard let fromCoordinate = location.fromCoordinate else {
                print("Missing coordinate for location: \(location.locationNumber)")
                continue
            }
            let pointOnMap = NSValue(CGPoint:map.projection.pointForCoordinate(fromCoordinate))
            points.append(pointOnMap)
        }
        return points
    }
    
//    func centerCoordinate(ofGroundOverlay groundOverlay:GMSGroundOverlay) -> CLLocationCoordinate2D {
//        
//    }
    
}

