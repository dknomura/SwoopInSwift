//
//  SPSignAndLocationModel.swift
//  SwoopParkingApp
//
//  Created by Daniel Nomura on 8/24/16.
//  Copyright © 2016 Daniel Nomura. All rights reserved.
//

import Foundation


struct SPSign {
    var signIndex: Int?
    var positionInFeet: Double?
    var directionOfArrow: String?
    var signContent: String?
    var isUniqueStreetCleaningSign:Bool?
}

struct SPLocation {
    var id: Int?
    var borough: String?
    var locationNumber: String?
    var street: String?
    var fromCrossStreet: String?
    var toCrossStreet: String?
    var sideOfStreet: String?
    //    var sortedCoordinate: CLLocationCoordinate2D?
    var fromCoordinate: CLLocationCoordinate2D?
    var toCoordinate: CLLocationCoordinate2D?
    var signs: [SPSign]?
    var snappedPoints: [SPSnappedPoint]?
    var hasUniqueStreetCleaningSign: Bool?
}

struct SPSnappedPoint {
    var coordinate: CLLocationCoordinate2D?
    var originalIndex: NSInteger?
    var placeID: String?
}