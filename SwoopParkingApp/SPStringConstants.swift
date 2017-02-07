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


let kSPGoogleMapsKey = "AIzaSyCGKTmya_bbd5_S9hJOzO9eKf4pDckrffQ"

//MARK: - NotificationCenter names
let kSPSearchTableViewDataSourceDidChange = "SearchTableViewDataSourceDidChange"
let collectionViewSwitchChangeNotification = Notification.Name("collectionViewSwitchChangeNotification")
let collectionViewSwitchKey = "isSwitchOn"
//MARK: NSUserDefaults keys
let kSPDidAllowLocationServices = "didAllowLocationServices"

//MARK: - Enums
//MARK: SQL query types
enum SPSQLLocationQueryTypes: String {
    case getAllLocationsWithUniqueCleaningSign
    case getLocationsForCurrentMapView
    case getLocationsForTimeAndDay
    case getLocationCountForTimeAndDay
    case getLocationCountsForRadius
}

//MARK: Measurement systems
enum SystemOfMeasurement: String {
    case metric
    case us
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

