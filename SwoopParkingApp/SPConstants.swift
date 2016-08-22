//
//  SPConstants.swift
//  SwoopParkingApp
//
//  Created by Daniel Nomura on 5/4/16.
//  Copyright © 2016 Daniel Nomura. All rights reserved.
//

import Foundation
let kSPGoogleMapsKey = "AIzaSyCGKTmya_bbd5_S9hJOzO9eKf4pDckrffQ"
//MARK: Lambda function name constants

let kSPLambdaGetSignsAndLocationsForTimeAndDay = "GetSignsAndLocationsForTimeAndDay"
let kSPLambdaGetSignsAndLocationsForCoordinates = "GetSignsAndLocationsForCoordinates"


//MARK: SQL query types and column names
// query type - used for delegate method control flow and for NSNotificationCenter names
let kSPSQLiteCoordinateQuery = "SQLiteCoordinateQuery"
let kSPSQLiteTimeAndDayQuery = "SQLiteTimeAndDayQuery"
let kSPSQLiteTimeAndDayLocationsOnlyQuery = "SQLiteTimeAndDayLocationsOnlyQuery"

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

// sign SQL columns
let kSPLocationIdSQL = "location_id"
let kSPDirectionOfArrowSQL = "direction_of_arrow"
let kSPSignIndexSQL = "sign_index"
let kSPPositionInFeetSQL = "position_in_feet"
let kSPSignContentSQL = "sign_content"
let kSPSignTypeSQL = "sign_type"


