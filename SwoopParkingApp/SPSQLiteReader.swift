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

enum SPSQLError: Error {
    case unableToOpenDB
    case noResults(ErrorMessage:String)
    case invalidQuery(query:String)
}

struct SPSQLiteReader {
    weak var delegate: SPSQLiteReaderDelegate?
    init(delegate: SPSQLiteReaderDelegate){
        self.delegate = delegate
    }
    var databasePath : String {
        return Bundle.main.path(forResource: "swoop-sqlite-with-tag-table", ofType: "db")!
    }
    func querySignsAndLocations(swCoordinate:CLLocationCoordinate2D, neCoordinate: CLLocationCoordinate2D) {
        let query = "SELECT location_number, side_of_street, from_latitude, from_longitude, to_latitude, to_longitude, sign_content, direction_of_arrow, position_in_feet FROM locations l JOIN signs s ON l.id = s.location_id WHERE (from_latitude BETWEEN ? AND ? AND from_longitude BETWEEN ? AND ?) OR (to_latitude BETWEEN ? AND ? AND to_longitude BETWEEN ? AND ?);"
        let values = [NSNumber(value: swCoordinate.latitude as Double),
                      NSNumber(value: neCoordinate.latitude as Double),
                      NSNumber(value: swCoordinate.longitude as Double),
                      NSNumber(value: neCoordinate.longitude as Double),
                      NSNumber(value: swCoordinate.latitude as Double),
                      NSNumber(value: neCoordinate.latitude as Double),
                      NSNumber(value: swCoordinate.longitude as Double),
                      NSNumber(value: neCoordinate.longitude as Double)]
        callSQL(query: query, withValues: values, responseObject: SPSQLResponse.init(queryType: .getLocationsForCurrentMapView))
    }
    
    func queryStreetCleaningLocations(forTimeAndDay timeAndDay: DNTimeAndDay) {
        let query = "SELECT location_number, tag, from_latitude, from_longitude FROM locations l JOIN location_tags t on l.id = t.location_id WHERE tag = '\(timeAndDay.stringForSQLTagQuery)'"
        callSQL(query: query, withValues: [], responseObject: SPSQLResponse.init(queryType: .getLocationsForTimeAndDay))
    }
    
//    func queryLocationCount(forTimeAndDay timeAndDay: DNTimeAndDay) {
//        var query = "SELECT COUNT(*) FROM locations WHERE sign_content_tag LIKE '%\(timeAndDay.stringForSQLTagQuery())%'"
//        adjust(&query, forTimeAndDay: timeAndDay)
//        var response = SPSQLResponse.init(queryType: .getLocationCountForTimeAndDay)
//        response.timeAndDay = timeAndDay
//        callSQL(query: query, withValues: [], responseObject: response)
//    }
    func queryLocationCounts(forMultipleDays days: [DNDay], swCoordinate: CLLocationCoordinate2D, neCoordinate: CLLocationCoordinate2D) {
        if days.count == 0 { return }
        var query = "SELECT tag, COUNT(*) FROM locations l JOIN location_tags t on l.id = t.location_id WHERE (from_latitude BETWEEN ? AND ? AND from_longitude BETWEEN ? AND ?) "
        for day in days {
            query += "AND tag like '%\(day.stringValue(forFormat: .abbrDay))' "
        }
        query += "GROUP BY tag"
        let values = [NSNumber(value: swCoordinate.latitude as Double),
                      NSNumber(value: neCoordinate.latitude as Double),
                      NSNumber(value: swCoordinate.longitude as Double),
                      NSNumber(value: neCoordinate.longitude as Double)]
        callSQL(query: query, withValues: values, responseObject: SPSQLResponse(queryType: .getLocationCountsForDays))
    }
        
    //Call with initialized response object so that 
    fileprivate func callSQL(query:String, withValues values:[AnyObject], responseObject:SPSQLResponse) {
        DispatchQueue.global(qos: DispatchQoS.QoSClass.utility).async {
            var response = responseObject
            response.query = query
            let database = FMDatabase.init(path: self.databasePath)
            if !(database?.open())! {
                print("Unable to open database")
                return
            }
            defer {
                database?.close()
            }
            //Turn on foreign keys
            let pragmaStatement = "PRAGMA foreign_keys = 1;"
            if !(database?.executeUpdate(pragmaStatement, withArgumentsIn: []))! {
                print("Error with SQLite pragma statment: \(database?.lastErrorMessage())")
            }
            let results = database?.executeQuery(query, withArgumentsIn: values)
            if results == nil {
                response.error = database?.lastErrorMessage()
                print("Error with query: \(query)\n\(database?.lastErrorMessage())")
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
