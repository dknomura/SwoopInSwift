//
//  SPSignAndLocationManager.swift
//  SwoopParkingApp
//
//  Created by Daniel Nomura on 5/10/16.
//  Copyright © 2016 Daniel Nomura. All rights reserved.
//

import Foundation
import CoreLocation
import GoogleMaps
import AWSLambda
import DNTimeAndDay

struct SPParser {
    
    //MARK: Injectable protocol
    fileprivate var dao: SPDataAccessObject!
    mutating func inject(_ dao: SPDataAccessObject) {
        self.dao = dao
    }
    func assertDependencies() {
        assert(dao != nil)
    }
    
    //MARK: - Parse sign and location from SQLite
    func parseSQL(fromResponse response: SPSQLResponse) {
        assertDependencies()
        guard let results = response.results else { return }
        switch response.queryType {
        case .getLocationsForTimeAndDay:
            dao.allLocationsForDayValue[dao.primaryTimeAndDay.rawValue] = locationsWithTags(fromResults: results)
        case .getLocationsForCurrentMapView:
            dao.currentMapViewLocations = locationsWithSigns(fromResults: results)
        case .getLocationCountsForRadius: break
        default: break
        }
    }
    
    fileprivate func locationCountForTimeAndDay(fromResults results: FMResultSet, timeAndDayParameter: DNTimeAndDay) -> [DNDay: [DNTime: Int]]? {
        var locationCountForTimeAndDay: [DNDay: [DNTime:Int]]?
        while results.next() {
            guard let sqlTagString = results.string(forColumn: kSPSignContentTagSQL) else { return nil }
            let tags = sqlTagString.components(separatedBy: " ")
            for tag in tags{
                guard let timeAndDay = DNTimeAndDay(sqlTag: tag) else { continue }
                if timeAndDay == timeAndDayParameter {
                    let count = results.int(forColumn: "count(*)")
                    locationCountForTimeAndDay = [timeAndDay.day : [timeAndDay.time : Int(count)]]
                    break
                } else {
                    continue
                }
            }
        }
        return locationCountForTimeAndDay
    }
    
    fileprivate func locationsForDayValue(fromResults results: FMResultSet) -> [Double: [SPLocation]] {
        var locationResults = [Double: [SPLocation]]()
        while results.next() {
            let location = locationWithTags(fromResults: results, includeTag: true)
            let keys: [Double] = dayValues(forLocation: location)
            for key in keys {
                if locationResults[key] == nil {
                    locationResults[key] = [SPLocation]()
                }
                locationResults[key]?.append(location)
            }
        }
        return locationResults
    }
    
    fileprivate func dayValues(forLocation location:SPLocation) -> [Double] {
        var returnDoubles = [Double]()
        let tags = location.signContentTag?.characters.split{$0 == " "}.map(String.init)
        for tag in tags! {
            if tag.contains("HOUR") { continue }
            var mRange = tag.range(of: "AM")
            if mRange == nil {
                mRange = tag.range(of: "PM")
                if mRange == nil { continue }
            }
            let timeString = tag.substring(with: tag.startIndex..<mRange!.upperBound)
            let dayString = tag.substring(with: mRange!.upperBound..<tag.endIndex)
            guard let timeAndDay = DNTimeAndDay.init(dayString: dayString, timeString: timeString) else {
                print("Error creating time and day object for location: \(location.locationNumber)/\(location.id)")
                continue
            }
            returnDoubles.append(timeAndDay.rawValue)
        }
        return returnDoubles
    }

    
    fileprivate func locationsWithTags(fromResults results: FMResultSet) -> [SPLocation] {
        var returnLocations = [SPLocation]()
        while results.next() {
            returnLocations.append(locationWithTags(fromResults: results, includeTag: true))
        }
        return returnLocations
    }
    
    fileprivate func locationWithTags(fromResults results: FMResultSet, includeTag: Bool) -> SPLocation {
        let fromLat = results.double(forColumn: kSPFromLatitudeSQL)
        let fromLong = results.double(forColumn: kSPFromLongitudeSQL)
        let fromCoordinate = CLLocationCoordinate2D.init(latitude: fromLat, longitude: fromLong)
        let tag = includeTag ? results.string(forColumn: kSPSignContentTagSQL) : nil
        return SPLocation.init(locationNumber: results.string(forColumn: kSPLocationNumberSQL), fromCoordinate: fromCoordinate, signContentTag: tag)
        
    }
    fileprivate func locationsWithSigns(fromResults results: FMResultSet) -> [SPLocation] {
        var returnLocations = [SPLocation]()
        var location = SPLocation.init(locationNumber: nil, fromCoordinate: nil, signContentTag: nil)
        while results.next() {
            if results.string(forColumn: kSPLocationNumberSQL) != location.locationNumber {
                if location.locationNumber != nil {
                    returnLocations.append(location)
                }
                location = locationWithTags(fromResults: results, includeTag: true)
                let toLat = results.double(forColumn: kSPToLatitudeSQL)
                let toLong = results.double(forColumn: kSPToLongitudeSQL)
                location.toCoordinate =  CLLocationCoordinate2D.init(latitude: toLat, longitude: toLong)
                location.sideOfStreet = results.string(forColumn: kSPSideOfStreetSQL)
                location.signs = [SPSign]()
            }
            
            let sign = SPSign.init(positionInFeet: results.double(forColumn: kSPPositionInFeetSQL), directionOfArrow: results.string(forColumn: kSPDirectionOfArrowSQL), signContent: results.string(forColumn: kSPSignContentSQL))
            location.signs?.append(sign)
        }
        return returnLocations
    }
//
//    //MARK: - Parse sign and location objects
//    //MARK: ---Lambda
//    func parseLambdaSignsAndLocationsFromCoordinates(response:NSArray) -> [SPLocation] {
//        var returnArray = [SPLocation]()
//        for i in 0 ..< response.count {
//            var location = SPLocation()
//            if let locDictionary = response[i] as? NSDictionary {
//                location.borough = locDictionary[kSPBoroughJSON] as? String
//                location.locationNumber = locDictionary[kSPlocationNumberJSON] as? String
//                location.sideOfStreet = locDictionary[kSPSideOfStreetJSON] as? String
//                location.street = locDictionary[kSPStreetJSON] as? String
//                location.fromCrossStreet = locDictionary[kSPFromCrossStreetJSON] as? String
//                location.toCrossStreet = locDictionary[kSPToCrossStreetJSON] as? String
//                
//                if let fromLat = locDictionary[kSPFromLatitudeJSON] as? CLLocationDegrees,
//                    let fromLong = locDictionary[kSPFromLongitudeJSON] as? CLLocationDegrees {
//                    location.fromCoordinate = CLLocationCoordinate2DMake(fromLat, fromLong)
//                }
//                
//                if let toLat = locDictionary[kSPToLatitudeJSON] as? CLLocationDegrees,
//                    let toLong = locDictionary[kSPToLongitudeJSON] as? CLLocationDegrees{
//                    location.toCoordinate = CLLocationCoordinate2DMake(toLat, toLong)
//                }
//                
//                if let signsResponse = locDictionary[kSPSignsJSON] as? NSArray {
//                    location.signs = [SPSign]()
//                    for j in 0 ..< signsResponse.count{
//                        if let signDictionary = signsResponse[j] as? NSDictionary{
//                            var sign = SPSign()
//                            sign.signIndex = signDictionary[kSPSignIndexJSON] as? NSInteger
//                            sign.positionInFeet = signDictionary[kSPPositionInFeetJSON] as? Double
//                            sign.signContent = signDictionary[kSPSignContentJSON] as? String
//                            sign.directionOfArrow = signDictionary[kSPDirectionOfArrowJSON] as? String
//                            location.signs?.append(sign)
//                        }
//                    }
//                    location.signs?.sortInPlace({$0.signIndex < $1.signIndex})
//                }
//                returnArray.append(location)
//            }
//        }
//        return returnArray
//    }
//    
    
    //MARK: - Parse Google API calls
    func parseGoogleAPIResponse(_ responseDict:NSDictionary, delegateAction:SPNetworkingDelegateAction, returnResponse: inout SPGoogleObject) {
        returnResponse.googleAPIResponse = SPGoogleAPIResponse()
        guard let dictKey = key(forDelegateAction:delegateAction) else {
            print("No key for delegateAction: \(delegateAction)")
            return
        }
        if let responseNextLevel = responseDict[dictKey] as? [NSDictionary] {
            if delegateAction == .presentAutocompleteResults { parseGoogleAutocomplete(responseNextLevel , returnResponse: &returnResponse) }
            else if delegateAction == .presentAddress { parseGoogleAddress(responseNextLevel, returnResponse: &returnResponse) }
        } else if let responseNextLevel = responseDict[dictKey] as? NSDictionary {
            if delegateAction == .presentCoordinate { parseGooglePlaceID(responseNextLevel, returnResponse: &returnResponse) }
        } else { print("No key: \(dictKey) in response dictionary: \(responseDict)") }
        return
    }
    
    //MARK: --Individual API parsers
    fileprivate func parseGoogleAutocomplete(_ responseArray:[NSDictionary], returnResponse:inout SPGoogleObject) {
        var addressResults = [SPGoogleAddressResult]()
        for response in responseArray {
            if let prediction = response["description"] as? String,
                let placeID = response["place_id"] as? String {
                guard isAddressInNYC(prediction) else { continue }
                let result = SPGoogleAddressResult(address: prediction, placeID: placeID, coordinate: nil)
                addressResults.append(result)
            }
        }
        returnResponse.googleAPIResponse?.addressResults = addressResults
    }
    
    fileprivate func parseGoogleAddress(_ responseDict:[NSDictionary], returnResponse:inout SPGoogleObject) {
        var addressResults = [SPGoogleAddressResult]()
        for response in responseDict {
            let addressKey = "formatted_address", placeIDKey = "place_id"
            if let address = response[addressKey] as? String,
                let coordinate = coordinate(fromDictionary: response),
                let placeID = response[placeIDKey] as? String {
                if isAddressInNYC(address) {
                    let result = SPGoogleAddressResult(address: address, placeID: placeID, coordinate: coordinate)
                    addressResults.append(result)
                }
            } else {
                print("Unable to get coordinate or values for keys: \(addressKey), \(placeIDKey), in dictionary: \(response)")
            }
        }
        returnResponse.googleAPIResponse?.addressResults = addressResults
    }

    fileprivate func parseGooglePlaceID(_ responseDict:NSDictionary, returnResponse:inout SPGoogleObject) {
        if let coordinate = coordinate(fromDictionary: responseDict),
            let address = responseDict["formatted_address"] as? String {
            returnResponse.googleAPIResponse?.placeIDCoordinate = coordinate
            returnResponse.googleAPIResponse?.formattedAddress = address
        } else {
            print("Unable to get coordinate from \(responseDict)")
        }
    }
    
    fileprivate func coordinate(fromDictionary responseDict:NSDictionary) -> CLLocationCoordinate2D? {
        var key = "geometry"
        guard let geometryDict = (responseDict[key] as? NSDictionary) else {
            print("No key: \(key) in dict: \(responseDict)")
            return nil
        }
        key = "location"
        guard let coordinateDict = geometryDict[key] as? NSDictionary else {
            print("No key: \(key) in dict: \(geometryDict)")
            return nil
        }
        key = "lat"
        let key2 = "lng"
        if let lat = coordinateDict[key] as? Double ,
            let lng = coordinateDict[key2] as? Double {
            return CLLocationCoordinate2D.init(latitude: lat, longitude: lng)
        } else {
            print("No key \(key) or \(key2) in dict: \(coordinateDict)")
            return nil
        }
    }
    
    //MARK: ---Get JSON key from delegate action
    fileprivate func key(forDelegateAction delegateAction: SPNetworkingDelegateAction) -> String? {
        switch delegateAction {
        case .presentAddress:
            return "results"
        case .presentAutocompleteResults:
            return "predictions"
        case .presentCoordinate:
            return "result"
        default:
            return nil
        }
    }
    fileprivate func isAddressInNYC(_ address:String) -> Bool {
        //This method checks whether the response contains New York, or one of the 5 boroughs to filter out other results
        //The terms values in the JSON response has an offset and value property, which shows the string position and the string value of the autocomplete prediction.
        let searchTerms = ["manhattan", "brooklyn", "queens", "bronx", "staten island", "new york"]
        for term in searchTerms {
            if address.lowercased().range(of: term) != nil{
                return true
            }
        }
        return false
    }
}
