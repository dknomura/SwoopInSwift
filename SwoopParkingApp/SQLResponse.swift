//
//  SQLResponse.swift
//  SwoopParkingApp
//
//  Created by Daniel Nomura on 2/8/17.
//  Copyright © 2017 Daniel Nomura. All rights reserved.
//

import Foundation
import DNTimeAndDay

struct SPSQLResponse {
    var results: FMResultSet?
    var queryType: SPSQLLocationQueryTypes
    var timeAndDay: DNTimeAndDay?
    var coordinates: CLLocationCoordinate2D?
    var error: String?
    var query: String?
    var dayParameter: DNDay?
}
extension SPSQLResponse {
    init(queryType: SPSQLLocationQueryTypes, dayParameter: DNDay? = nil) {
        self.init(results: nil, queryType: queryType, timeAndDay: nil, coordinates: nil, error: nil, query: nil, dayParameter: dayParameter)
    }
    init(sqlResponse: SPSQLResponse) {
        self.init(results: sqlResponse.results, queryType: sqlResponse.queryType, timeAndDay: sqlResponse.timeAndDay, coordinates: sqlResponse.coordinates, error: sqlResponse.error, query:nil, dayParameter: sqlResponse.dayParameter)
    }
}
