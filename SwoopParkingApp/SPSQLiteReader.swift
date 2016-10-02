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

enum SQLError: ErrorType {
    case unableToOpenDB
    case noResults(ErrorMessage:String)
    case invalidQuery(query:String)
}

struct SPSQLiteReader {
    weak var delegate: SPSQLiteReaderDelegate?
    //MARK: Injectable protocol
    private var dao: SPDataAccessObject!
    mutating func inject(dao: SPDataAccessObject) {
        self.dao = dao
    }
    func assertDependencies() {
        assert(dao != nil)
    }

    var dbPath:String { return NSBundle.mainBundle().pathForResource("swoop-sqlite-no-FTS", ofType: "db")! }
    
    func querySignsAndLocations(swCoordinate swCoordinate:CLLocationCoordinate2D, neCoordinate: CLLocationCoordinate2D) {
        let query = "SELECT l.id, side_of_street, sign_content_tag, from_latitude, from_longitude, to_latitude, to_longitude, sign_content, direction_of_arrow, position_in_feet FROM locations l JOIN signs s ON l.id = s.location_id WHERE (from_latitude BETWEEN ? AND ? AND from_longitude BETWEEN ? AND ?) OR (to_latitude BETWEEN ? AND ? AND to_longitude BETWEEN ? AND ?);"
        let values = [NSNumber(double:swCoordinate.latitude), NSNumber(double:neCoordinate.latitude), NSNumber(double:swCoordinate.longitude), NSNumber(double:neCoordinate.longitude), NSNumber(double:swCoordinate.latitude), NSNumber(double:neCoordinate.latitude), NSNumber(double:swCoordinate.longitude), NSNumber(double:neCoordinate.longitude)]
        callSQL(query: query, withValues: values, queryType: .getLocationsForCurrentMapView)
    }
    
    func queryUpcomingStreetCleaningSignsAndLocations(shouldSearchRange shouldSearchRange:Bool) {
        //Query with old signs and locations db
//        let query = "SELECT l.id, sign_content, position_in_feet, from_latitude, from_longitude FROM locations l INNER JOIN signs s1 ON l.id = s1.location_id WHERE s1.position_in_feet || ' ' || s1.location_id IN ( SELECT s2.position_in_feet || ' ' || s2.location_id FROM signs s2 WHERE s2.sign_content MATCH 'sanitation tues* 12*')"
        
        //Query for new, locations_with_sign_content
        let timeStringTuple = dao.primaryTimeAndDay.stringTupleForSQLQuery()
        let signContentTag = timeStringTuple.time + timeStringTuple.day
        let query = "SELECT id, sign_content_tag, from_latitude, from_longitude FROM locations WHERE sign_content_tag LIKE '%\(signContentTag)%'"
        callSQL(query: query, withValues: [], queryType: .getLocationsForTimeAndDay)
    }
    
    private func callSQL(query query:String, withValues values:[AnyObject], queryType:SPSQLLocationQueryTypes) {
        dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0)) {
            let database = FMDatabase(path: self.dbPath)
            
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
                print("Error with query: \(query)\n\(database.lastErrorMessage())")
                return
            } else {
                let date = NSDate()
                var locationResults = [SPLocation]()
                results.next()
                while results.hasAnotherRow() {
                    locationResults.append(SPLocation.init(sqlResultSet: results, queryType: queryType))
                }
                print("Time to parse \(queryType.rawValue), \(locationResults.count) locations: \(date.timeIntervalSinceNow)")
                dispatch_async(dispatch_get_main_queue(), {
                    self.delegate?.sqlQueryDidFinish(withResults:(queryType, locationResults))
                })
            }
        }
    }
    
//    private func parseLocationsWithUniqueSignPositions(fromResults results: FMResultSet, queryType:SPSQLLocationQueryTypes) {
//        assertDependencies()
//        var parser = SPParser()
//        parser.inject(dao)
//        let locationResults = parser.parseSQLSignsAndLocationsFromTime(results)
//        
//        dispatch_async(dispatch_get_main_queue(), {
//            self.delegate?.sqlQueryDidFinish(withResults:(queryType, locationResults))
//        })
//        
//    }
//    
//    private func parseSignsAndLocations(fromResults results: FMResultSet, queryType:SPSQLLocationQueryTypes) {
//        assertDependencies()
//        var parser = SPParser()
//        parser.inject(dao)
//        let locationResults = parser.parseSQLSignsAndLocationsFromCoordinates(results, queryType: queryType)
//        dispatch_async(dispatch_get_main_queue(), {
//            self.delegate?.sqlQueryDidFinish(withResults:(queryType, locationResults))
//        })
//    }
    
}

protocol SPSQLiteReaderDelegate: class {
    func sqlQueryDidFinish(withResults results:(queryType: SPSQLLocationQueryTypes, locationResults: [SPLocation]))
}
