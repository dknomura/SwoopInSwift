//
//  SPSQLiteReader.swift
//  SwoopParkingApp
//
//  Created by Daniel Nomura on 8/5/16.
//  Copyright © 2016 Daniel Nomura. All rights reserved.
//

import Foundation
import CoreLocation
import DNTimeAndDay

enum SPSQLError: ErrorType {
    case unableToOpenDB
    case noResults(ErrorMessage:String)
    case invalidQuery(query:String)
}

struct SPSQLResponse {
    var results: FMResultSet?
    var queryType: SPSQLLocationQueryTypes
    var timeAndDay: DNTimeAndDay?
    var coordinates: CLLocationCoordinate2D?
    var error: String?
    var query: String?
}
extension SPSQLResponse {
    init(queryType: SPSQLLocationQueryTypes) {
        self.init(results: nil, queryType: queryType, timeAndDay: nil, coordinates: nil, error: nil, query: nil)
    }
    init(sqlResponse: SPSQLResponse) {
        self.init(results: sqlResponse.results, queryType: sqlResponse.queryType, timeAndDay: sqlResponse.timeAndDay, coordinates: sqlResponse.coordinates, error: sqlResponse.error, query:nil)
    }
}

struct SPSQLiteReader {
    weak var delegate: SPSQLiteReaderDelegate?
    var databasePath : String {
        return NSBundle.mainBundle().pathForResource("swoop-sqlite-no-FTS", ofType: "db")!
    }
    func querySignsAndLocations(swCoordinate swCoordinate:CLLocationCoordinate2D, neCoordinate: CLLocationCoordinate2D) {
        let query = "SELECT location_number, side_of_street, sign_content_tag, from_latitude, from_longitude, to_latitude, to_longitude, sign_content, direction_of_arrow, position_in_feet FROM locations l JOIN signs s ON l.id = s.location_id WHERE (from_latitude BETWEEN ? AND ? AND from_longitude BETWEEN ? AND ?) OR (to_latitude BETWEEN ? AND ? AND to_longitude BETWEEN ? AND ?);"
        let values = [NSNumber(double:swCoordinate.latitude), NSNumber(double:neCoordinate.latitude), NSNumber(double:swCoordinate.longitude), NSNumber(double:neCoordinate.longitude), NSNumber(double:swCoordinate.latitude), NSNumber(double:neCoordinate.latitude), NSNumber(double:swCoordinate.longitude), NSNumber(double:neCoordinate.longitude)]
        callSQL(query: query, withValues: values, responseObject: SPSQLResponse.init(queryType: .getLocationsForCurrentMapView))
    }
    
    func queryStreetCleaningLocations(forTimeAndDay timeAndDay: DNTimeAndDay) {
        var query = "SELECT location_number, sign_content_tag, from_latitude, from_longitude FROM locations WHERE sign_content_tag LIKE '%\(timeAndDay.stringForSQLTagQuery())%'"
        adjust(&query, forTimeAndDay: timeAndDay)
        callSQL(query: query, withValues: [], responseObject: SPSQLResponse.init(queryType: .getLocationsForTimeAndDay))
    }
    
//    func queryLocationCount(forTimeAndDay timeAndDay: DNTimeAndDay) {
//        var query = "SELECT COUNT(*) FROM locations WHERE sign_content_tag LIKE '%\(timeAndDay.stringForSQLTagQuery())%'"
//        adjust(&query, forTimeAndDay: timeAndDay)
//        var response = SPSQLResponse.init(queryType: .getLocationCountForTimeAndDay)
//        response.timeAndDay = timeAndDay
//        callSQL(query: query, withValues: [], responseObject: response)
//    }
    private func adjust(inout query: String, forTimeAndDay timeAndDay: DNTimeAndDay) {
        if timeAndDay.time.hour == 14 {
            let dayString = timeAndDay.day.stringValue(forFormat: DNTimeAndDayFormat.abbrDay()).uppercaseString
            var notLike = ""
            if timeAndDay.time.min == 0 {
                notLike = "'%12PM\(dayString)%'"
            }else if timeAndDay.time.hour == 14 && timeAndDay.time.min == 30 {
                notLike = "'%12:30PM\(dayString)%'"
            }
            query += " AND sign_content_tag NOT LIKE \(notLike)"
        }
    }
    
    func queryAllStreetCleaningLocations() {
        //Query with old signs and locations db
//        let query = "SELECT l.id, sign_content, position_in_feet, from_latitude, from_longitude FROM locations l INNER JOIN signs s1 ON l.id = s1.location_id WHERE s1.position_in_feet || ' ' || s1.location_id IN ( SELECT s2.position_in_feet || ' ' || s2.location_id FROM signs s2 WHERE s2.sign_content MATCH 'sanitation tues* 12*')"
        
        //Query for new, locations_with_sign_content
        let query = "SELECT location_number, sign_content_tag, from_latitude, from_longitude FROM locations WHERE has_unique_cleaning_sign = 1"
        callSQL(query: query, withValues: [], responseObject: SPSQLResponse.init(queryType: .getAllLocationsWithUniqueCleaningSign))
    }
    
    private func callSQL(query query:String, withValues values:[AnyObject], responseObject:SPSQLResponse) {
        dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0)) {
            var response = responseObject
            response.query = query
            let database = FMDatabase.init(path: self.databasePath)
            if !database.open() {
                print("Unable to open database")
                return
            }
            defer {
                database.close()
            }
            let pragmaStatement = "PRAGMA foreign_keys = 1;"
            if !database.executeUpdate(pragmaStatement, withArgumentsInArray: []) {
                print("Error with SQLite pragma statment: \(database.lastErrorMessage())")
            }
            let results = database.executeQuery(query, withArgumentsInArray: values)
            if results == nil {
                response.error = database.lastErrorMessage()
                print("Error with query: \(query)\n\(database.lastErrorMessage())")
                return
            } else {
                response.results = results
                self.delegate?.sqlQueryDidFinish(withResponse: response)
            }
        }
    }
}
protocol SPSQLiteReaderDelegate: class {
    func sqlQueryDidFinish(withResponse response: SPSQLResponse)
}
