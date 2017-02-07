//
//  SPNumericalConstants.swift
//  SwoopParkingApp
//
//  Created by Daniel Nomura on 2/6/17.
//  Copyright © 2017 Daniel Nomura. All rights reserved.
//

import Foundation
import GoogleMaps

//MARK: - Standard UI
var standardAnimationDuration:Double { return 0.2 }
var standardHeightOfToolOrSearchBar: CGFloat { return CGFloat(44.0) }


//MARK - MapView 
var zoomToSwitchOverlays: Float { return streetZoom - 2.5 }
var streetZoom: Float { return 16 }
let worldMeters = 40075000.0

//MARK: - Global enums
enum SPCity: String {
    case NYC
    case Chicago
    case Denver
    case LA
    var coordinateNE: CLLocationCoordinate2D {
        switch self {
        case .NYC: return CLLocationCoordinate2DMake(40.91295931663856, -73.70059684703173)
        case .Denver, .LA, .Chicago: return CLLocationCoordinate2D()
        }
    }
    var coordinateSW: CLLocationCoordinate2D {
        switch self {
        case .NYC:
            return CLLocationCoordinate2DMake(40.49785967315467, -74.25453161899142)
        case .Denver, .LA, .Chicago: return CLLocationCoordinate2D()
        }
    }
    
    //Radius in meters
    func minHorizontalRadius(view:UIView) -> Double {
        let localMeters = zoomToSwitchOverlays.toWidthInMetersFromGMSZoom(forView: view)
        return localMeters / 2
    }
    
    var maxHorizontalRadius: Double {
        let location1 = CLLocation(latitude: 0, longitude: coordinateNE.longitude)
        let location2 = CLLocation(latitude: 0, longitude: coordinateSW.longitude)
        return location1.distance(from: location2) / 2
    }
    var maxDiagonalRadius: Double {
        let location1 = CLLocation(latitude: coordinateNE.latitude, longitude: coordinateNE.longitude)
        let location2 = CLLocation(latitude: coordinateSW.latitude, longitude: coordinateSW.longitude)
        return location1.distance(from: location2) / 2
    }
    
    func initialStreetCleaningZoom(forMapView mapView: GMSMapView) -> Float {
        // https://developers.google.com/maps/documentation/ios-sdk/views#zoom
        // "at zoom level N, the width of the world is approximately 256 * 2^N, i.e., at zoom level 2, the whole world is approximately 1024 points wide"
        
        // world width points = local points * world width meters / local meters
        // 2 ^ N = world width points / 256
        // N = log2(world width points / 256)
        // local points = map width
        let localMeters = maxHorizontalRadius * 2
        return localMeters.toZoomFromWidthInMeters(forView: mapView)
    }
}

