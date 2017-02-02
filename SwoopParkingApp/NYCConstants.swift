//
//  NYCConstants.swift
//  SwoopParkingApp
//
//  Created by Daniel Nomura on 2/1/17.
//  Copyright © 2017 Daniel Nomura. All rights reserved.
//

import Foundation

//MARK: Max min coordinates
var maxNYCCoordinate: CLLocationCoordinate2D { return CLLocationCoordinate2DMake(40.91295931663856, -73.70059684703173) }
var minNYCCoordinate: CLLocationCoordinate2D { return CLLocationCoordinate2DMake(40.49785967315467, -74.25453161899142) }
var maxNYCRadius: Double {
    let location1 = CLLocation.init(latitude: 0, longitude: maxNYCCoordinate.longitude)
    let location2 = CLLocation.init(latitude: 0, longitude: minNYCCoordinate.longitude)
    return location1.distance(from: location2)
}
