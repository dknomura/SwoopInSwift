//
//  MapViewExtensions.swift
//  SwoopParkingApp
//
//  Created by Daniel Nomura on 2/1/17.
//  Copyright © 2017 Daniel Nomura. All rights reserved.
//

import Foundation
import GoogleMaps

extension GMSMapView {
    //MARK: - Determine if current mapView is within NYC
    
    func isIn(city:SPCity) -> Bool {
        let region = GMSCoordinateBounds.init(region: self.projection.visibleRegion())
        if region.northEast.isCoordinateWithinRegion(NECoordinate: city.maxCoordinate, SWCoordinate: city.minCoordinate) || region.southWest.isCoordinateWithinRegion(NECoordinate: city.maxCoordinate, SWCoordinate: city.minCoordinate) || city.maxCoordinate.isCoordinateWithinRegion(NECoordinate: region.northEast, SWCoordinate: region.southWest) || city.minCoordinate.isCoordinateWithinRegion(NECoordinate: region.northEast, SWCoordinate: region.southWest){
           return true
        } else {
            return false
        }
    }
    
}

extension CLLocationCoordinate2D {
    func isCoordinateWithinRegion (NECoordinate: CLLocationCoordinate2D, SWCoordinate: CLLocationCoordinate2D) -> Bool {
        if latitude < NECoordinate.latitude && latitude > SWCoordinate.latitude {
            if longitude < NECoordinate.longitude && longitude > SWCoordinate.longitude { return true }
            else { return false }
        } else { return false }
    }

}
