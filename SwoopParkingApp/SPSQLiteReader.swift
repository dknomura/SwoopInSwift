//
//  SPSQLiteReader.swift
//  SwoopParkingApp
//
//  Created by Daniel Nomura on 8/5/16.
//  Copyright © 2016 Daniel Nomura. All rights reserved.
//

import Foundation
import CoreLocation

enum SQLError: ErrorType {
    case unableToOpenDB
    case noResults(ErrorMessage:String)
    case invalidQuery(query:String)
}

struct SPSQLiteReader {
    weak var delegate: SPSQLiteReaderDelegate?
    weak var dao:SPDataAccessObject?
    
    var locationColumnsForJoin:[String] {
        return ["l." + kSPLocationNumberSQL, "l." + kSPIdSQL, kSPBoroughSQL, kSPSideOfStreetSQL, kSPStreetSQL, kSPToCrossStreetSQL, kSPFromCrossStreetSQL, kSPFromLatitudeSQL, kSPFromLongitudeSQL, kSPToLatitudeSQL, kSPToLongitudeSQL]
    }
    var signColumns:[String] {
        return [kSPDirectionOfArrowSQL, kSPSignIndexSQL, kSPPositionInFeetSQL, kSPSignContentSQL]
    }
    var columnsForJoinStatment:[String] {
        var columns = locationColumnsForJoin
        for sign in signColumns {
            columns.append(sign)
        }
        return columns
    }
    
    var beginningOfLocationJoinSignsQuery: String {
        var query = "SELECT "
        for column in columnsForJoinStatment {
            query += (column as String) + ", "
        }
        query.removeRange(query.endIndex.advancedBy(-2)..<query.endIndex.advancedBy(-1))
        return query
    }
    
    var dbPath:String { return NSBundle.mainBundle().pathForResource("swoop-sqlite2", ofType: "db")! }
    
    
    // This function is for finding all of the signs and locations within a given coordinate region. The call back passed to the callSQL() function parses all of the signs and location
    func querySignsAndLocations(swCoordinate swCoordinate:CLLocationCoordinate2D, neCoordinate: CLLocationCoordinate2D) {
        var query = beginningOfLocationJoinSignsQuery
        query += "FROM locations l JOIN signs s ON l.id = s.location_id WHERE (from_latitude BETWEEN ? AND ? AND from_longitude BETWEEN ? AND ?) OR (to_latitude BETWEEN ? AND ? AND to_longitude BETWEEN ? AND ?);"
        let values = [NSNumber(double:swCoordinate.latitude), NSNumber(double:neCoordinate.latitude), NSNumber(double:swCoordinate.longitude), NSNumber(double:neCoordinate.longitude), NSNumber(double:swCoordinate.latitude), NSNumber(double:neCoordinate.latitude), NSNumber(double:swCoordinate.longitude), NSNumber(double:neCoordinate.longitude)]
        //        var values: [AnyObject] = columns
        //        for value in whereValues {
        //            values.append(value)
        //        }
        callSQL(query: query, withValues: values, queryType: kSPSQLiteCoordinateQuery, callback: parseSignsAndLocations)
    }
    
    //This function is for finding all of the locations with at least one street cleaning sign that is the only sign in their position (meaning that it is okay to park there any time after street cleaning). The call back passed to the callSQL() function will find locations that have at least one street cleaning sign that is the only sign at that position
    func queryUpcomingStreetCleaningSignsAndLocations(forDayAndTime:SPTimeAndDayInt) {
        //        var query = beginningOfLocationJoinSignsQuery
        //        query +=
        let query = "SELECT l.id, sign_content, position_in_feet, from_latitude, from_longitude FROM locations l INNER JOIN signs s1 ON l.id = s1.location_id WHERE s1.position_in_feet || ' ' || s1.location_id IN ( SELECT s2.position_in_feet || ' ' || s2.location_id FROM signs s2 WHERE s2.sign_content MATCH 'sanitation tues* 12*')"
        //        let query = "SELECT l.id, sign_content, position_in_feet, from_latitude, from_longitude FROM locations l INNER JOIN signs s1 ON l.id = s1.location_id WHERE l.id IN ( SELECT s2.location_id FROM signs s2 WHERE s2.sign_content MATCH 'broom tues* 11*')"
        //        let testQuery = "SELECT location_id from signs WHERE sign_content MATCH 'broom ?'"
        let callback = parseLocationsWithUniqueSignPositions
        callSQL(query: query, withValues: [], queryType: kSPSQLiteTimeAndDayQuery, callback:callback)
    }
    
    private func callSQL(query query:String, withValues values:[AnyObject], queryType:String, callback:(FMResultSet, String) -> Void) {
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
                callback(results, queryType)
            }
        }
    }
    
    private func parseLocationsWithUniqueSignPositions(fromResults results: FMResultSet, queryType:String) {
        var parser = SPParser()
        parser.dao = dao
        let locationResults = parser.parseSQLSignsAndLocationsFromTime(results)
        
        dispatch_async(dispatch_get_main_queue(), {
            self.delegate?.sqlQueryDidFinish(withResults:(queryType, locationResults))
        })
        
    }
    
    private func parseSignsAndLocations(fromResults results: FMResultSet, queryType:String) {
        var parser = SPParser()
        parser.dao = dao
        let locationResults = parser.parseSQLSignsAndLocationsFromCoordinates(results, queryType: queryType)
        dispatch_async(dispatch_get_main_queue(), {
            self.delegate?.sqlQueryDidFinish(withResults:(queryType, locationResults))
        })
    }
    
}

protocol SPSQLiteReaderDelegate: class {
    func sqlQueryDidFinish(withResults results:(queryType: String, locationResults: [SPLocation]))
}
