//
//  SPSignAndLocationModel.swift
//  SwoopParkingApp
//
//  Created by Daniel Nomura on 8/24/16.
//  Copyright © 2016 Daniel Nomura. All rights reserved.
//

import Foundation


struct SPSign {
    var positionInFeet: Double?
    var directionOfArrow: String?
    var signContent: String?
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
    var signContentTag: String?
    
    init(locationNumber: String?, id:Int?, sideOfStreet:String?, fromCoordinate:CLLocationCoordinate2D?, toCoordinate:CLLocationCoordinate2D?, signs:[SPSign]?, signContentTag: String?) {
        self.locationNumber = locationNumber
        self.id = id
        self.sideOfStreet = sideOfStreet
        self.fromCoordinate = fromCoordinate
        self.toCoordinate = toCoordinate
        self.signs = signs
        self.signContentTag = signContentTag
    }
    
    init(id:Int?, fromCoordinate:CLLocationCoordinate2D?, signContentTag:String?) {
        self.init(locationNumber: nil,id:id, sideOfStreet:nil, fromCoordinate:fromCoordinate, toCoordinate:nil, signs:nil, signContentTag: signContentTag)
    }
    init(locationNumber:String?, fromCoordinate:CLLocationCoordinate2D?, signContentTag:String?) {
        self.init(locationNumber: locationNumber, id:nil, sideOfStreet:nil, fromCoordinate:fromCoordinate, toCoordinate:nil, signs:nil, signContentTag: signContentTag)
    }
    
    init(sqlResultSet results:FMResultSet, queryType: SPSQLLocationQueryTypes) {
        let fromLat = results.doubleForColumn(kSPFromLatitudeSQL)
        let fromLong = results.doubleForColumn(kSPFromLongitudeSQL)
        let fromCoordinate = CLLocationCoordinate2D.init(latitude: fromLat, longitude: fromLong)
        var loc = SPLocation.init(locationNumber: results.stringForColumn(kSPLocationNumberSQL), fromCoordinate: fromCoordinate, signContentTag: results.stringForColumn(kSPSignContentTagSQL))
        if queryType == .getAllLocationsWithUniqueCleaningSign || queryType == .getLocationsForTimeAndDay {
            while results.stringForColumn(kSPLocationNumberSQL) == loc.locationNumber {
                results.next()
            }
        }else if queryType == .getLocationsForCurrentMapView {
            let toLat = results.doubleForColumn(kSPToLatitudeSQL)
            let toLong = results.doubleForColumn(kSPToLongitudeSQL)
            loc.toCoordinate = CLLocationCoordinate2D.init(latitude: toLat, longitude: toLong)
            loc.sideOfStreet = results.stringForColumn(kSPSideOfStreetSQL)
            loc.signs = [SPSign]()
            while results.stringForColumn(kSPLocationNumberSQL) == loc.locationNumber {
                results.next()
                let signContent = results.stringForColumn(kSPSignContentSQL)
                let positionInFeet = results.doubleForColumn(kSPPositionInFeetSQL)
                let directionOfArrow = results.stringForColumn(kSPDirectionOfArrowSQL)
                loc.signs!.append(SPSign.init(positionInFeet: positionInFeet, directionOfArrow: directionOfArrow, signContent: signContent))
            }
        }
        self.init(location: loc)
    }
    
    init(location: SPLocation) {
        self.init(locationNumber:location.locationNumber, id: location.id, sideOfStreet:location.sideOfStreet, fromCoordinate:location.fromCoordinate, toCoordinate:location.toCoordinate, signs:location.signs, signContentTag: location.signContentTag)
    }
}

struct SPSnappedPoint {
    var coordinate: CLLocationCoordinate2D?
    var originalIndex: NSInteger?
    var placeID: String?
}