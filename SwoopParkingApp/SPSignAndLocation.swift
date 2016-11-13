//
//  SPSignAndLocationModel.swift
//  SwoopParkingApp
//
//  Created by Daniel Nomura on 8/24/16.
//  Copyright © 2016 Daniel Nomura. All rights reserved.
//

import Foundation


struct SPSign {
    var positionInFeet: Double!
    var directionOfArrow: String!
    var signContent: String! {
        didSet {
            setMarkerContent()
        }
    }
    init(positionInFeet: Double?, directionOfArrow:String?, signContent:String?) {
        self.positionInFeet = positionInFeet
        self.directionOfArrow = directionOfArrow
        self.signContent = signContent
        setMarkerContent()
    }
    var markerContent: String!
    mutating func setMarkerContent() {
        guard let symbolRange = signContent.range(of: "BOL)") else { return }
        let cleaningTime = signContent.substring(from: symbolRange.upperBound).localizedCapitalized
        markerContent = "Street cleaning " + cleaningTime + " Tap for directions"
    }
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
        let fromLat = results.double(forColumn: kSPFromLatitudeSQL)
        let fromLong = results.double(forColumn: kSPFromLongitudeSQL)
        let fromCoordinate = CLLocationCoordinate2D.init(latitude: fromLat, longitude: fromLong)
        var loc = SPLocation.init(locationNumber: results.string(forColumn: kSPLocationNumberSQL), fromCoordinate: fromCoordinate, signContentTag: results.string(forColumn: kSPSignContentTagSQL))
        if queryType == .getAllLocationsWithUniqueCleaningSign || queryType == .getLocationsForTimeAndDay {
            while results.string(forColumn: kSPLocationNumberSQL) == loc.locationNumber {
                results.next()
            }
        }else if queryType == .getLocationsForCurrentMapView {
            let toLat = results.double(forColumn: kSPToLatitudeSQL)
            let toLong = results.double(forColumn: kSPToLongitudeSQL)
            loc.toCoordinate = CLLocationCoordinate2D.init(latitude: toLat, longitude: toLong)
            loc.sideOfStreet = results.string(forColumn: kSPSideOfStreetSQL)
            loc.signs = [SPSign]()
            while results.string(forColumn: kSPLocationNumberSQL) == loc.locationNumber {
                results.next()
                let signContent = results.string(forColumn: kSPSignContentSQL)
                let positionInFeet = results.double(forColumn: kSPPositionInFeetSQL)
                let directionOfArrow = results.string(forColumn: kSPDirectionOfArrowSQL)
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
