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
        if region.northEast.isIn(city: city) ||
            region.southWest.isIn(city: city) ||
            city.coordinateNE.isCoordinateWithinRegion(NECoordinate: region.northEast, SWCoordinate: region.southWest) ||
            city.coordinateSW.isCoordinateWithinRegion(NECoordinate: region.northEast, SWCoordinate: region.southWest){
           return true
        } else {
            return false
        }
    }
    
    var currentRadius: Double {
        let visibleRegion = self.projection.visibleRegion()
        let west = CLLocation(latitude: visibleRegion.nearLeft.latitude, longitude: visibleRegion.nearLeft.longitude)
        let east = CLLocation(latitude: visibleRegion.nearRight.latitude, longitude: visibleRegion.nearRight.longitude)
        return west.distance(from: east) / 2
    }
}

