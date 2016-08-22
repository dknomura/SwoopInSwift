//
//  SignAndLocationObjects.swift
//  SwoopParkingApp
//
//  Created by Daniel Nomura on 5/11/16.
//  Copyright © 2016 Daniel Nomura. All rights reserved.
//

import Foundation
import CoreLocation


class SPSign {
    var borough: String?
    var locationNumber: String?
    var signIndex: NSInteger?
    var positionInFeet: NSInteger?
    var directionOfArrow: String?
    var signContent: String?
    var signType: String?
}

class SPLocation {
    var borough: String?
    var locationNumber: String?
    var street: String?
    var fromCrossStreet: String?
    var toCrossStreet: String?
    var sortedCoordinate: CLLocationCoordinate2D?
    var fromCoordinate: CLLocationCoordinate2D?
    var toCoordinate: CLLocationCoordinate2D?
    var snappedPoints: [SPSnappedPoint]?
}

class SPSnappedPoint {
    var coordinate: CLLocationCoordinate2D?
    var originalIndex: NSInteger?
    var placeID: String?
}
