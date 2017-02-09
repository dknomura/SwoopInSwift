//
//  CLLocationCoordinate2DExtension.swift
//  SwoopParkingApp
//
//  Created by Daniel Nomura on 2/8/17.
//  Copyright © 2017 Daniel Nomura. All rights reserved.
//

import Foundation

extension CLLocationCoordinate2D: Comparable {
    func isCoordinateWithinRegion (NECoordinate: CLLocationCoordinate2D, SWCoordinate: CLLocationCoordinate2D) -> Bool {
        if latitude < NECoordinate.latitude && latitude > SWCoordinate.latitude {
            if longitude < NECoordinate.longitude && longitude > SWCoordinate.longitude { return true }
            else { return false }
        } else { return false }
    }
    func isIn(city:SPCity) -> Bool {
        return isCoordinateWithinRegion(NECoordinate: city.coordinateNE, SWCoordinate: city.coordinateSW)
    }
    
    func swNECorners(withRadius radius: Double) -> (sw: CLLocationCoordinate2D, ne: CLLocationCoordinate2D) {
        let swBearing = Double.pi + (Double.pi / 4)
        let neBearing = Double.pi / 4
        let swCoordinate = coordinate(distance: radius, bearing: swBearing)
        let neCoordinate = coordinate(distance: radius, bearing: neBearing)
        return (swCoordinate, neCoordinate)
    }
    
    func coordinate(distance: Double, bearing: Double) -> CLLocationCoordinate2D{
        //Bearing must be in radians
        
        // Then you can find the displaced coordinates of the path
        //        var φ2 = Math.asin( Math.sin(φ1)*Math.cos(d/R) +
        //          Math.cos(φ1)*Math.sin(d/R)*Math.cos(brng) );
        //        var λ2 = λ1 + Math.atan2(Math.sin(brng)*Math.sin(d/R)*
        //          Math.cos(φ1), Math.cos(d/R)-Math.sin(φ1)*Math.sin(φ2));
        //
        // Angular distance = distance / radius of earth
        let latitude = self.latitude.toRadiansFromDegrees
        let longitude = self.longitude.toRadiansFromDegrees
        let angularDistance = distance / 6371000
        let newLat = asin(sin(latitude) * cos(angularDistance) + cos(latitude) * sin(angularDistance) * cos(bearing))
        let newLong = longitude + atan2(sin(bearing) * sin(angularDistance) * cos(latitude), cos(angularDistance) - sin(latitude) * sin(newLat))
        return CLLocationCoordinate2D(latitude: newLat.toDegreesFromRadians, longitude: newLong.toDegreesFromRadians)
    }
}
public func ==(lhs:CLLocationCoordinate2D, rhs:CLLocationCoordinate2D) -> Bool {
    return lhs.latitude == rhs.latitude &&
        lhs.longitude == rhs.longitude
}
public func >=(lhs:CLLocationCoordinate2D, rhs:CLLocationCoordinate2D) -> Bool {
    return lhs.latitude >= rhs.latitude &&
        lhs.longitude >= rhs.longitude
}
public func <=(lhs:CLLocationCoordinate2D, rhs:CLLocationCoordinate2D) -> Bool {
    return lhs.latitude <= rhs.latitude &&
        lhs.longitude <= rhs.longitude
}
public func <(lhs:CLLocationCoordinate2D, rhs:CLLocationCoordinate2D) -> Bool {
    return lhs.latitude < rhs.latitude &&
        lhs.longitude < rhs.longitude
}
public func >(lhs:CLLocationCoordinate2D, rhs:CLLocationCoordinate2D) -> Bool {
    return lhs.latitude > rhs.latitude &&
        lhs.longitude > rhs.longitude
}

