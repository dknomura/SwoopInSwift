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
    
    init(id:Int?, sideOfStreet:String?, fromCoordinate:CLLocationCoordinate2D?, toCoordinate:CLLocationCoordinate2D?, signs:[SPSign]?, signContentTag: String?) {
        self.id = id
        self.sideOfStreet = sideOfStreet
        self.fromCoordinate = fromCoordinate
        self.toCoordinate = toCoordinate
        self.signs = signs
        self.signContentTag = signContentTag
    }
    
    init(id:Int?, fromCoordinate:CLLocationCoordinate2D?, signContentTag:String?) {
        self.init(id:id, sideOfStreet:nil, fromCoordinate:fromCoordinate, toCoordinate:nil, signs:nil, signContentTag: signContentTag)
    }
    
    init(sqlResultSet results:FMResultSet, queryType: SPSQLLocationQueryTypes) {
        let locID = Int(results.intForColumn(kSPIdSQL))
        let signContentTag = results.stringForColumn(kSPSignContentTagSQL)
        let fromLat = results.doubleForColumn(kSPFromLatitudeSQL)
        let fromLong = results.doubleForColumn(kSPFromLongitudeSQL)
        let fromCoordinate = CLLocationCoordinate2D.init(latitude: fromLat, longitude: fromLong)
        if queryType == .getLocationsForTimeAndDay {
            while Int(results.intForColumn(kSPIdSQL)) == locID {
                results.next()
            }
            self.init(id:locID, fromCoordinate: fromCoordinate, signContentTag: signContentTag)
        } else {
            let toLat = results.doubleForColumn(kSPToLatitudeSQL)
            let toLong = results.doubleForColumn(kSPToLongitudeSQL)
            let toCoordinate = CLLocationCoordinate2D.init(latitude: toLat, longitude: toLong)
            let sideOfStreet = results.stringForColumn(kSPSideOfStreetSQL)
            var signs = [SPSign]()
            while Int(results.intForColumn(kSPIdSQL)) == locID {
                let signContent = results.stringForColumn(kSPSignContentSQL)
                let positionInFeet = results.doubleForColumn(kSPPositionInFeetSQL)
                let directionOfArrow = results.stringForColumn(kSPDirectionOfArrowSQL)
                signs.append(SPSign.init(positionInFeet: positionInFeet, directionOfArrow: directionOfArrow, signContent: signContent))
                results.next()
            }
            self.init(id:locID, sideOfStreet:sideOfStreet, fromCoordinate:fromCoordinate, toCoordinate:toCoordinate, signs:signs, signContentTag: signContentTag)
        }
    }
}

struct SPSnappedPoint {
    var coordinate: CLLocationCoordinate2D?
    var originalIndex: NSInteger?
    var placeID: String?
}