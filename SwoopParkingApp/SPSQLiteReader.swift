//
//  SPSQLiteReader.swift
//  SwoopParkingApp
//
//  Created by Daniel Nomura on 8/5/16.
//  Copyright © 2016 Daniel Nomura. All rights reserved.
//

import Foundation
import CoreLocation

struct SPSQLiteReader {
    
    enum SQLError: ErrorType {
        case unableToOpenDB
        case noResults(ErrorMessage:String)
    }
    
    weak var delegate: SPSQLiteReaderDelegate?
    
    var locationColumns:[String] {
        return ["l." + kSPLocationNumberSQL, "l." + kSPIdSQL, kSPBoroughSQL, kSPSideOfStreetSQL, kSPStreetSQL, kSPToCrossStreetSQL, kSPFromCrossStreetSQL, kSPFromLatitudeSQL, kSPFromLongitudeSQL, kSPToLatitudeSQL, kSPToLongitudeSQL]
    }
    var signColumns:[String] {
        return [kSPDirectionOfArrowSQL, kSPSignIndexSQL, kSPPositionInFeetSQL, kSPSignContentSQL]
    }
    var columns:[String] {
        var columns = locationColumns
        for sign in signColumns {
            columns.append(sign)
        }
        return columns
    }
    
    var beginningOfLocationJoinSignsQuery: String {
        var query = "SELECT "
        for column in columns {
            query += (column as String) + ", "
        }
        query.removeRange(query.endIndex.advancedBy(-2)..<query.endIndex.advancedBy(-1))
        return query
    }
    
    let dbPath = NSBundle.mainBundle().pathForResource("swoop-sqlite", ofType: "db")
    
    
//    func getAllSignsAndLocations() {
//        let query = beginningOfLocationJoinSignsQuery + "FROM locations l JOIN signs s ON l.id = s.location_id;"
//        callSQL(query:query, withValues:[], queryType:kSPSQLiteCoordinateQuery, callback:parseSignsAndLocations)
//    }
    
    
// This function is for finding all of the signs and locations within a given coordinate region. The call back passed to the callSQL() function parses all of the signs and location
    func querySignsAndLocations(swCoordinate swCoordinate:CLLocationCoordinate2D, neCoordinate: CLLocationCoordinate2D) {
        var query = beginningOfLocationJoinSignsQuery
//        query += "FROM locations l JOIN signs s ON l.id = s.location_id WHERE (from_latitude BETWEEN ? AND ? AND from_longitude BETWEEN ? AND ?) OR (to_latitude BETWEEN ? AND ? AND to_longitude BETWEEN ? AND ?) OR ((from_latitude + to_latitude) / 2 BETWEEN ? AND ? AND (from_longitude + to_longitude) / 2 BETWEEN ? AND ?);"
        query += "FROM locations l JOIN signs s ON l.id = s.location_id WHERE (from_latitude BETWEEN ? AND ? AND from_longitude BETWEEN ? AND ?) OR (to_latitude BETWEEN ? AND ? AND to_longitude BETWEEN ? AND ?);"
        let values = [NSNumber(double:swCoordinate.latitude), NSNumber(double:neCoordinate.latitude), NSNumber(double:swCoordinate.longitude), NSNumber(double:neCoordinate.longitude), NSNumber(double:swCoordinate.latitude), NSNumber(double:neCoordinate.latitude), NSNumber(double:swCoordinate.longitude), NSNumber(double:neCoordinate.longitude)]
//        var values: [AnyObject] = columns
//        for value in whereValues {
//            values.append(value)
//        }
        callSQL(query: query, withValues: values, queryType: kSPSQLiteCoordinateQuery, callback: parseSignsAndLocations)
    }
    
    //This function is for finding all of the locations with at least one street cleaning sign that is the only sign in their position (meaning that it is okay to park there any time after street cleaning). The call back passed to the callSQL() function will find locations that have at least one street cleaning sign that is the only sign at that position
    func queryUpcomingStreetCleaningSignsAndLocations(forDayAndTime:(day:Int, hour:Int, min:Int)) {
//        var query = beginningOfLocationJoinSignsQuery
//        query +=
        let query = "SELECT l.id, sign_content, position_in_feet, from_latitude, from_longitude FROM locations l INNER JOIN signs s1 ON l.id = s1.location_id WHERE s1.position_in_feet || ' ' || s1.location_id IN ( SELECT s2.position_in_feet || ' ' || s2.location_id FROM signs s2 WHERE s2.sign_content MATCH 'broom tues* 11*')"
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
//            do {
//                let pragmaStatement = "PRAGMA foreign_keys = ON;"
//                try database.executeQuery(pragmaStatement, values: [])
//            } catch {
//                print("Error with pragma query: \(error)")
//            }
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
        var locationResults = [SPLocation]()
        var location = SPLocation()
        location.signs = [SPSign]()
        var sign = SPSign()
        var locationCounter = 0
        let totalDate = NSDate()
        
        while results.next() {
            if location.id != Int(results.intForColumn("l." + kSPIdSQL)) {
                if location.id != nil {
//                    locationCounter += 1
//                    locationResults.append(location)

                    location.isGoodStreetCleaning = isUniqueSignPositionIn(location.signs!)
                    if location.isGoodStreetCleaning! {
                        locationCounter += 1
                        locationResults.append(location)
                    }
                }
                location.isGoodStreetCleaning = false
                location.id = Int(results.intForColumn("l." + kSPIdSQL))
                location.fromCoordinate = CLLocationCoordinate2D()
                location.fromCoordinate?.latitude = results.doubleForColumn(kSPFromLatitudeSQL)
                location.fromCoordinate?.longitude = results.doubleForColumn(kSPFromLongitudeSQL)
                location.signs?.removeAll()
            }
            sign.signContent = results.stringForColumn(kSPSignContentSQL)
            sign.positionInFeet = results.doubleForColumn(kSPPositionInFeetSQL)
            location.signs?.append(sign)
//            if sign.positionInFeet != nil {
//                signPositions.append(sign.positionInFeet!)
//            }
        }
        print("Time lapse for location only query: \(totalDate.timeIntervalSinceNow)\nNumber of locations: \(locationCounter)")

        dispatch_async(dispatch_get_main_queue(), {
            self.delegate?.sqlQueryDidFinish(withResults:(queryType, locationResults))
        })

    }
    
    private func isUniqueSignPositionIn(signs:[SPSign]) -> Bool {
        var numberOfSignsAtPosition = [Double:Int]()
        
        for sign in signs {
            if sign.positionInFeet != nil {
                numberOfSignsAtPosition[sign.positionInFeet!] = (numberOfSignsAtPosition[sign.positionInFeet!] ?? 0) + 1
            }
        }
        for (_, value) in numberOfSignsAtPosition {
            if value == 1 {
                return true
            }
        }
        return false
    }
    
    private func parseSignsAndLocations(fromResults results: FMResultSet, queryType:String) {
        var locationResults = [SPLocation]()
        var location = SPLocation()
        
        let totalDate = NSDate()
//        var date = NSDate()
//        var timeLapse: NSTimeInterval

        var signCounter = 0
        
        while results.next() {
            if location.locationNumber != results.stringForColumn("l." + kSPLocationNumberSQL) {
                if location.locationNumber != nil {
                    locationResults.append(location)
                }
                location.id = Int(results.intForColumn("l." + kSPIdSQL))
                location.locationNumber = results.stringForColumn("l." + kSPLocationNumberSQL)
                location.borough = results.stringForColumn(kSPBoroughSQL)
                location.sideOfStreet = results.stringForColumn(kSPSideOfStreetSQL)
                location.street = results.stringForColumn(kSPStreetSQL)
                location.toCrossStreet = results.stringForColumn(kSPToCrossStreetSQL)
                location.fromCrossStreet = results.stringForColumn(kSPFromCrossStreetSQL)
                
                location.fromCoordinate = CLLocationCoordinate2D()
                location.fromCoordinate?.latitude = results.doubleForColumn(kSPFromLatitudeSQL)
                location.fromCoordinate?.longitude = results.doubleForColumn(kSPFromLongitudeSQL)
                
                location.toCoordinate = CLLocationCoordinate2D()
                location.toCoordinate?.latitude = results.doubleForColumn(kSPToLatitudeSQL)
                location.toCoordinate?.longitude = results.doubleForColumn(kSPToLongitudeSQL)
                location.signs = [SPSign]()
            }
            var sign = SPSign()
            sign.signIndex = Int(results.intForColumn(kSPSignIndexSQL))
            sign.directionOfArrow = results.stringForColumn(kSPDirectionOfArrowSQL)
            sign.positionInFeet = results.doubleForColumn(kSPPositionInFeetSQL)
            sign.signContent = results.stringForColumn(kSPSignContentSQL)
            location.signs?.append(sign)
            signCounter += 1
        }
        
        print("Time lapse for query \(queryType): \(totalDate.timeIntervalSinceNow) \nNumber of signs: \(signCounter)")
        
        dispatch_async(dispatch_get_main_queue(), {
            self.delegate?.sqlQueryDidFinish(withResults:(queryType, locationResults))
        })
    }
    
}

protocol SPSQLiteReaderDelegate: class {
    func sqlQueryDidFinish(withResults results:(queryType: String, locationResults: [SPLocation]))
}
