//
//  SPConstants.swift
//  SwoopParkingApp
//
//  Created by Daniel Nomura on 5/4/16.
//  Copyright © 2016 Daniel Nomura. All rights reserved.
//

import Foundation
import GoogleMaps

//MARK: - In app purchase
public let InAppDonationProduct = "com.dnom.SwoopParkingApp.Donation"


//MARK: - Standard UI 
var standardAnimationDuration:Double { return 0.2 }
var standardHeightOfToolOrSearchBar: CGFloat { return CGFloat(44.0) }


let kSPGoogleMapsKey = "AIzaSyCGKTmya_bbd5_S9hJOzO9eKf4pDckrffQ"

//MARK: - NotificationCenter names
let kSPSearchTableViewDataSourceDidChange = "SearchTableViewDataSourceDidChange"

//MARK: NSUserDefaults keys
let kSPDidAllowLocationServices = "didAllowLocationServices"


//MARK: - Global enums
enum SPCity: String {
    case NYC
    case Chicago
    case Denver
    case LA
    var maxCoordinate: CLLocationCoordinate2D {
        switch self {
        case .NYC: return CLLocationCoordinate2DMake(40.91295931663856, -73.70059684703173)
        case .Denver, .LA, .Chicago: return CLLocationCoordinate2D()
        }
    }
    var minCoordinate: CLLocationCoordinate2D {
        switch self {
        case .NYC:
            return CLLocationCoordinate2DMake(40.49785967315467, -74.25453161899142)
        case .Denver, .LA, .Chicago: return CLLocationCoordinate2D()
        }
    }

    //Radius in meters
    var maxHorizontalRadius: Double {
        let location1 = CLLocation(latitude: 0, longitude: maxCoordinate.longitude)
        let location2 = CLLocation(latitude: 0, longitude: minCoordinate.longitude)
        return location1.distance(from: location2) / 2
    }
    var maxDiagnoalRadius: Double {
        let location1 = CLLocation(latitude: maxCoordinate.latitude, longitude: maxCoordinate.longitude)
        let location2 = CLLocation(latitude: minCoordinate.latitude, longitude: minCoordinate.longitude)
        return location1.distance(from: location2) / 2
    }
    
    func initialStreetCleaningZoom(forMapView mapView: GMSMapView) -> Float {
        // https://developers.google.com/maps/documentation/ios-sdk/views#zoom
        // "at zoom level N, the width of the world is approximately 256 * 2^N, i.e., at zoom level 2, the whole world is approximately 1024 points wide"

        // world width points = local points * world width meters / local meters
        // 2 ^ N = world width points / 256
        // N = log2(world width points / 256)
        // local points = map width
        // Local Meters: for NYC = 27425.3366774176
        
        let localMeters: Double = maxHorizontalRadius * 2
        let worldMeters = 40075000.0
        let localPoints = Double(mapView.bounds.width)
        let worldPoints = localPoints * worldMeters / localMeters
        let zoom = log2(worldPoints / 256.0)
        return Float(zoom)
    }
}


//MARK: SQL query types
enum SPSQLLocationQueryTypes: String {
    case getAllLocationsWithUniqueCleaningSign
    case getLocationsForCurrentMapView
    case getLocationsForTimeAndDay
//    case getLocationCountForTimeAndDay
}

struct SPRestoreCoderKeys {
    static let hour = "hour"
    static let min = "min"
    static let day = "day"
    static let zoom = "zoom"
    static let centerLat = "centerLat"
    static let centerLong = "centerLong"
    static let searchText = "searchText"
}


// location SQL columns
let kSPIdSQL = "id"
let kSPBoroughSQL = "borough"
let kSPLocationNumberSQL = "location_number"
let kSPSideOfStreetSQL = "side_of_street"
let kSPStreetSQL = "street"
let kSPToCrossStreetSQL = "to_cross_street"
let kSPFromCrossStreetSQL = "from_cross_street"
let kSPFromLatitudeSQL = "from_latitude"
let kSPFromLongitudeSQL = "from_longitude"
let kSPToLatitudeSQL = "to_latitude"
let kSPToLongitudeSQL = "to_longitude"
let kSPSignContentTagSQL = "sign_content_tag"
let kSPHasUniqueCleaningSignSQL = "has_unique_cleaning_sign"
let kSPHasMeteredParkingSQL = "has_metered_parking"

// sign SQL columns
let kSPLocationIdSQL = "location_id"
let kSPDirectionOfArrowSQL = "direction_of_arrow"
let kSPSignIndexSQL = "sign_index"
let kSPPositionInFeetSQL = "position_in_feet"
let kSPSignContentSQL = "sign_content"
let kSPSignTypeSQL = "sign_type"


//MARK: Sign and Location Constants
//Location JSON properties/dictionary keys for lambda response
let kSPSignsJSON = "signs"
let kSPSignIndexJSON = "signIndex"
let kSPPositionInFeetJSON = "positionInFeet"
let kSPDirectionOfArrowJSON = "directionOfArrow"
let kSPSignContentJSON = "signContent"
let kSPSignTypeJSON = "signType"
let kSPBoroughJSON = "borough"
let kSPlocationNumberJSON = "locationNumber"


//Sign JSON properties/dictionary keys
let kSPStreetJSON = "street"
let kSPFromCrossStreetJSON = "fromCrossStreet"
let kSPToCrossStreetJSON = "toCrossStreet"
let kSPSideOfStreetJSON = "sideOfStreet"
let kSPFromLatitudeJSON = "fromLatitude"
let kSPFromLongitudeJSON = "fromLongitude"
let kSPToLatitudeJSON = "toLatitude"
let kSPToLongitudeJSON = "toLongitude"
let kSPSnappedPointsJSON = "snappedPoints"

