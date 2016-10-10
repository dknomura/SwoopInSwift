//
//  SPGoogleNetworkingObject.swift
//  SwoopParkingApp
//
//  Created by Daniel Nomura on 10/7/16.
//  Copyright © 2016 Daniel Nomura. All rights reserved.
//

import Foundation

struct SPGoogleObject {
    var googleAPIResponse: SPGoogleAPIResponse?
    var googleStatusCode: SPGoogleStatusCodes?
    var delegateAction: SPNetworkingDelegateAction?
    var error: NSError?
}
struct SPGoogleAPIResponse{
    var addressResults: [SPGoogleAddressResult]?
    var placeIDCoordinate: CLLocationCoordinate2D?
    var formattedAddress: String?
}
struct SPGoogleAddressResult {
    var address:String
    var placeID:String
    var coordinate:CLLocationCoordinate2D?
}

struct SPGoogleCoordinateAndInfo {
    var coordinate: CLLocationCoordinate2D?
    var info: String?
}

enum SPNetworkingDelegateAction {
    case presentCoordinate
    case presentAutocompleteResults
    case presentAddress
    case presentNetworkingError
    case presentLocalError
}

enum SPGoogleStatusCodes:String {
    case OK, ZERO_RESULTS, OVER_QUERY_LIMIT, INVALID_REQUEST, UNKNOWN_ERROR, NOT_FOUND, REQUEST_DENIED
    static let allValues = [OK, ZERO_RESULTS, OVER_QUERY_LIMIT, INVALID_REQUEST, UNKNOWN_ERROR, NOT_FOUND, REQUEST_DENIED]
}

