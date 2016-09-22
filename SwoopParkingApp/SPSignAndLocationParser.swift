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

struct SPParser {
    
    //MARK: Injectable protocol
    private var dao: SPDataAccessObject!
    mutating func inject(dao: SPDataAccessObject) {
        self.dao = dao
    }
    func assertDependencies() {
        assert(dao != nil)
    }

    //MARK: - Parse sign and location objects
    //MARK: ---Lambda
    func parseLambdaSignsAndLocationsFromCoordinates(response:NSArray) -> [SPLocation] {
        var returnArray = [SPLocation]()
        for i in 0 ..< response.count {
            var location = SPLocation()
            if let locDictionary = response[i] as? NSDictionary {
                location.borough = locDictionary[kSPBoroughJSON] as? String
                location.locationNumber = locDictionary[kSPlocationNumberJSON] as? String
                location.sideOfStreet = locDictionary[kSPSideOfStreetJSON] as? String
                location.street = locDictionary[kSPStreetJSON] as? String
                location.fromCrossStreet = locDictionary[kSPFromCrossStreetJSON] as? String
                location.toCrossStreet = locDictionary[kSPToCrossStreetJSON] as? String
                
                if let fromLat = locDictionary[kSPFromLatitudeJSON] as? CLLocationDegrees,
                    let fromLong = locDictionary[kSPFromLongitudeJSON] as? CLLocationDegrees {
                    location.fromCoordinate = CLLocationCoordinate2DMake(fromLat, fromLong)
                }
                
                if let toLat = locDictionary[kSPToLatitudeJSON] as? CLLocationDegrees,
                    let toLong = locDictionary[kSPToLongitudeJSON] as? CLLocationDegrees{
                    location.toCoordinate = CLLocationCoordinate2DMake(toLat, toLong)
                }
                
                if let signsResponse = locDictionary[kSPSignsJSON] as? NSArray {
                    location.signs = [SPSign]()
                    for j in 0 ..< signsResponse.count{
                        if let signDictionary = signsResponse[j] as? NSDictionary{
                            var sign = SPSign()
                            sign.signIndex = signDictionary[kSPSignIndexJSON] as? NSInteger
                            sign.positionInFeet = signDictionary[kSPPositionInFeetJSON] as? Double
                            sign.signContent = signDictionary[kSPSignContentJSON] as? String
                            sign.directionOfArrow = signDictionary[kSPDirectionOfArrowJSON] as? String
                            location.signs?.append(sign)
                        }
                    }
                    location.signs?.sortInPlace({$0.signIndex < $1.signIndex})
                }
                returnArray.append(location)
            }
        }
        return returnArray
    }
    
    //MARK: ---SQL
    
    func parseSQLSignsAndLocationsFromCoordinates(results:FMResultSet, queryType:SPSQLLocationQueryTypes) -> [SPLocation] {
        var locationResults = [SPLocation]()
        var location = SPLocation()
        location.signs = [SPSign]()
        let totalDate = NSDate()
        var signCounter = 0
        
        while results.next() {
            if location.locationNumber != results.stringForColumn("l." + kSPLocationNumberSQL) {
                if location.locationNumber != nil {
                    location.signs = markStreetCleaningSignsWithUniquePosition(atLocation: location)
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
        return locationResults
    }
    
    func parseSQLSignsAndLocationsFromTime (results: FMResultSet) -> [SPLocation] {
        var locationResults = [SPLocation]()
        var location = SPLocation()
        location.signs = [SPSign]()
        var signCounter = 0
        let totalDate = NSDate()
        
        while results.next() {
            if location.id != Int(results.intForColumn("l." + kSPIdSQL)) {
                if location.id != nil {
                    location.hasUniqueStreetCleaningSign = isThereUniqueSignPosition(forLocation:location)
                    if location.hasUniqueStreetCleaningSign! {
                        locationResults.append(location)
                    }
                }
                location.hasUniqueStreetCleaningSign = false
                location.id = Int(results.intForColumn("l." + kSPIdSQL))
                location.fromCoordinate = CLLocationCoordinate2D()
                location.fromCoordinate?.latitude = results.doubleForColumn(kSPFromLatitudeSQL)
                location.fromCoordinate?.longitude = results.doubleForColumn(kSPFromLongitudeSQL)
                location.signs?.removeAll()
            }
            var sign = SPSign()
            sign.signContent = results.stringForColumn(kSPSignContentSQL)
            sign.positionInFeet = results.doubleForColumn(kSPPositionInFeetSQL)
            location.signs?.append(sign)
            signCounter += 1

            //            if sign.positionInFeet != nil {
            //                signPositions.append(sign.positionInFeet!)
            //            }
        }
        print("Time lapse for time and day query: \(totalDate.timeIntervalSinceNow)\nNumber of signs: \(signCounter)")
        return locationResults
    }
    
    //MARK: ---Marking unique street cleaning signs
    private func isThereUniqueSignPosition(forLocation location: SPLocation) -> Bool {
        guard let signs = location.signs else { return false }
        let numberOfSignsAtPosition = dictionaryOfNumberOfSignsAtPosition(signs)
        for (_, value) in numberOfSignsAtPosition {
            if value == 1 {
                return true
            }
        }
        return false
    }
    
    private func markStreetCleaningSignsWithUniquePosition(atLocation location:SPLocation) -> [SPSign] {
        guard let signs = location.signs else { return [SPSign]() }
        var returnSigns = [SPSign]()
        let numberOfSignsAtPosition = dictionaryOfNumberOfSignsAtPosition(signs)
        var signsWithUniquePositions = [SPSign]()
        for var sign in signs {
            if sign.positionInFeet != nil {
                if numberOfSignsAtPosition[sign.positionInFeet!] == 1 {
                    signsWithUniquePositions.append(sign)
                } else {
                    sign.isUniqueStreetCleaningSign = false
                    returnSigns.append(sign)
                }
            } else {
                sign.isUniqueStreetCleaningSign = false
                returnSigns.append(sign)
            }
        }
        for var sign in signsWithUniquePositions {
            guard let signContent = sign.signContent?.lowercaseString else {
                print("No sign content for sign \(sign.signIndex) at location: \(location.locationNumber)")
                continue
            }
            assertDependencies()
            let searchedDayAndTime = dao!.formattedTimeAndDayTupleForSQLQuery(forTimeAndDay: dao.primaryTimeAndDay)
            guard signContent.rangeOfString(searchedDayAndTime.day.lowercaseString) != nil  &&
                signContent.rangeOfString(searchedDayAndTime.time.lowercaseString) != nil else {
                    sign.isUniqueStreetCleaningSign = false
                    continue
            }
            if signContent.rangeOfString("sanitation") != nil || signContent.rangeOfString("broom") != nil {
                sign.isUniqueStreetCleaningSign = true
                returnSigns.append(sign)
            } else {
                sign.isUniqueStreetCleaningSign = false
                returnSigns.append(sign)
            }
        }
        return returnSigns.sort({ $0.signIndex < $1.signIndex })
    }
    
    private func dictionaryOfNumberOfSignsAtPosition(signs:[SPSign]) -> [Double: Int] {
        var numberOfSignsAtPosition = [Double:Int]()
        for sign in signs {
            if sign.positionInFeet != nil {
                numberOfSignsAtPosition[sign.positionInFeet!] = (numberOfSignsAtPosition[sign.positionInFeet!] ?? 0) + 1
            }
        }
        return numberOfSignsAtPosition
    }
    
    
    //MARK: - Parse Google API calls
    func parseGoogleAPIResponse(responseDict:NSDictionary, delegateAction:SPNetworkingDelegateAction, inout returnResponse: SPGoogleResponse) {
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
    private func parseGoogleAutocomplete(responseArray:[NSDictionary], inout returnResponse:SPGoogleResponse) {
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
    
    private func parseGoogleAddress(responseDict:[NSDictionary], inout returnResponse:SPGoogleResponse) {
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

    private func parseGooglePlaceID(responseDict:NSDictionary, inout returnResponse:SPGoogleResponse) {
        if let coordinate = coordinate(fromDictionary: responseDict) {
            returnResponse.googleAPIResponse?.placeIDCoordinate = coordinate
        } else {
            print("Unable to get coordinate from \(responseDict)")
        }
    }
    
    private func coordinate(fromDictionary responseDict:NSDictionary) -> CLLocationCoordinate2D? {
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
    private func key(forDelegateAction delegateAction: SPNetworkingDelegateAction) -> String? {
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
    private func isAddressInNYC(address:String) -> Bool {
        //This method checks whether the response contains New York, or one of the 5 boroughs to filter out other results
        //The terms values in the JSON response has an offset and value property, which shows the string position and the string value of the autocomplete prediction.
        let searchTerms = ["manhattan", "brooklyn", "queens", "bronx", "staten island", "new york"]
        for term in searchTerms {
            if address.lowercaseString.rangeOfString(term) != nil{
                return true
            }
        }
        return false
    }
}





// File reading, parsing, and filtering data on local JSON file

//    private enum SPLocationArrayType: String {
//        case FromLat = "FromLat"
//        case ToLat = "ToLat"
//        case FromLong = "FromLong"
//        case ToLong = "ToLong"
//        case SortedByLocationNumber
//    }
//
//    var bronxSigns = Array<SPSign>?()
//    var brooklynSigns = Array<SPSign>?()
//    var manhattanSigns = Array<SPSign>?()
//    var queensSigns = Array<SPSign>?()
//    var statenIslandSigns = Array<SPSign>?()
//
//    var locationsSortedByFromLat = Array<SPLocation>?()
//    var locationsSortedByToLat = Array<SPLocation>?()
//    var locationsSortedByFromLong = Array<SPLocation>?()
//    var locationsSortedByToLong = Array<SPLocation>?()
//
//    private var maxNYCCoordinate: CLLocationCoordinate2D?
//    private var minNYCCoordinate: CLLocationCoordinate2D?
//    private var visibleRegionNECoordinate: CLLocationCoordinate2D?
//    private var visibleRegionSWCoordinate: CLLocationCoordinate2D?
//
//    var visibleRegionBounds: GMSCoordinateBounds?
//
//    var currentLocationsAndSigns = [(location:SPLocation, signs:[SPSign])]()
//    var currentLocations = [SPLocation]()
//    var currentSigns = [SPSign]()
//
//    static let sharedManager = SPSignAndLocationManager()
//
//    //MARK: - Get Master Location and Sign arrays and max/min coordinates
//    func getSignsAndLocations() {
//        dispatch_barrier_sync(concurrentSignAndLocationQueue) {
//            self.bronxSigns = self.loadSignsFor("bronx")
//
//            self.locationsSortedByFromLat = self.getLocationsSortedBy(.FromLat)
//            self.locationsSortedByFromLong = self.getLocationsSortedBy(.FromLong)
//            self.locationsSortedByToLat = self.getLocationsSortedBy(.ToLat)
//            self.locationsSortedByToLong = self.getLocationsSortedBy(.ToLong)
//        }
//        if locationsSortedByFromLat?.count > 0 {
//            minNYCCoordinate = findMinimumNYCCoordinate()
//            maxNYCCoordinate = findMaximumNYCCoordinate()
//        }
//    }
//
//    // Location String should be lower Camelcase to match the file
//    private func loadSignsFor(borough:String) -> [SPSign] {
//        let signPath = NSBundle.mainBundle().pathForResource("\(borough)Signs", ofType: "json")
//        let signData = NSData.init(contentsOfFile: signPath!)
//        var returnArray = [SPSign]()
//
//        let signJSONArray: Array<NSDictionary>?
//        do {
//            signJSONArray = try NSJSONSerialization.JSONObjectWithData(signData!, options: NSJSONReadingOptions.MutableContainers) as? Array<NSDictionary>
//            for sign in signJSONArray! {
//                let signObject = SPSign()
//                signObject.borough = sign.objectForKey(kSPBorough) as? String
//                signObject.locationNumber = sign.objectForKey(kSPlocationNumber) as? String
//                signObject.signIndex = sign.objectForKey(kSPSignIndex) as? NSInteger
//                signObject.positionInFeet = sign.objectForKey(kSPPositionInFeet) as? NSInteger
//                signObject.directionOfArrow = sign.objectForKey(kSPDirectionOfArrow) as? String
//                signObject.signContent = sign.objectForKey(kSPSignContent) as? String
//                signObject.signType = sign.objectForKey(kSPSignType) as? String
//                returnArray.append(signObject)
//            }
//        } catch let error as NSError {
//            print ("Error: \(error.localizedDescription)\n\n\(error.userInfo)")
//        }
//        return returnArray
//    }
//
//    // Like above, the coordinate string should match the fileName, so string should be FromLat, ToLong, etc
//    // Method needs to know the type of array so that the extra coordinate property corresponds to the correct To/FromCoordinate.
//    private func getLocationsSortedBy(arrayType:SPLocationArrayType) -> [SPLocation] {
//        let locationPath = NSBundle.mainBundle().pathForResource("locationsSortedBy\(arrayType)", ofType: "json")
//        print("locationsSortedBy\(arrayType)")
//        let locationData = NSData.init(contentsOfFile: locationPath!)
//        let locationJSONArray:Array<NSDictionary>?
//        var returnArray = [SPLocation]()
//        do {
//            locationJSONArray = try NSJSONSerialization.JSONObjectWithData(locationData!, options: NSJSONReadingOptions.MutableContainers) as? Array<NSDictionary>
//            for location in locationJSONArray! {
//                let locationObject = SPLocation()
//                locationObject.borough = location.objectForKey(kSPBorough) as? String
//                locationObject.locationNumber = location.objectForKey(kSPlocationNumber) as? String
//                locationObject.street = location.objectForKey(kSPStreet) as? String
//                locationObject.fromCrossStreet = location.objectForKey(kSPFromCrossStreet) as? String
//                locationObject.toCrossStreet = location.objectForKey(kSPToCrossStreet) as? String
//
//                if arrayType == SPLocationArrayType.FromLat {
//                    if let latitude = location.objectForKey(kSPFromLatitude) as? Double {
//                        let longitude = (location.objectForKey(kSPFromLongitude) as? Double)!
//                        locationObject.sortedCoordinate = CLLocationCoordinate2D.init(latitude: latitude, longitude: longitude)                    }
//
//                } else if arrayType == SPLocationArrayType.ToLat {
//                    if let latitude = location.objectForKey(kSPToLatitude) as? Double {
//                        let longitude = (location.objectForKey(kSPToLongitude) as? Double)!
//                        locationObject.sortedCoordinate = CLLocationCoordinate2D.init(latitude: latitude, longitude: longitude)
//                    }
//                }
//                if let fromLatitude = location.objectForKey(kSPFromLatitude) as? Double {
//                    let fromLongitude = (location.objectForKey(kSPFromLongitude) as? Double)!
//                    locationObject.fromCoordinate = CLLocationCoordinate2D.init(latitude: fromLatitude, longitude: fromLongitude)
//                }
//
//
//                if let toLatitude = location.objectForKey(kSPToLatitude) as? Double {
//                    let toLongitude = (location.objectForKey(kSPToLongitude) as? Double)!
//                    locationObject.toCoordinate = CLLocationCoordinate2D.init(latitude: toLatitude, longitude: toLongitude)
//                }
//
//                if let snappedPoints = location.objectForKey(kSPSnappedPoints) as? [NSDictionary] {
//                    var points = [SPSnappedPoint]()
//                    for point in snappedPoints {
//                        let snappedPoint = SPSnappedPoint()
//                        let snapLatitude = (point.objectForKey(kSPLocation)!.objectForKey(kSPLatitude) as? Double)!
//                        let snapLongitude = (point.objectForKey(kSPLocation)!.objectForKey(kSPLongitude) as?  Double)!
//                        snappedPoint.coordinate = CLLocationCoordinate2D.init(latitude: snapLatitude, longitude: snapLongitude)
//                        snappedPoint.originalIndex = point.objectForKey(kSPOriginalIndex) as? NSInteger
//                        snappedPoint.placeID = point.objectForKey(kSPPlaceID) as? String
//                        points.append(snappedPoint)
//                    }
//                    locationObject.snappedPoints = points
//                }
//                returnArray.append(locationObject)
//            }
//        } catch let error as NSError {
//            print ("Error: \(error.localizedDescription)\n\n\(error.userInfo)")
//        }
//        return returnArray
//    }
//
//    private func findMinimumNYCCoordinate () -> CLLocationCoordinate2D {
//        var minimumLat: Double?
//        for location in locationsSortedByToLat! {
//            if let minToLat = location.toCoordinate?.latitude {
//                for loc in locationsSortedByFromLat! {
//                    if let minFromLat = loc.fromCoordinate?.latitude {
//                        minimumLat = min(minToLat, minFromLat)
//                        break
//                    }
//                }
//                break
//            }
//        }
//        var minimumLong: Double?
//        for location in locationsSortedByToLong! {
//            if let minToLong = location.toCoordinate?.longitude {
//                for location in locationsSortedByFromLong! {
//                    if let minFromLong = location.fromCoordinate?.longitude {
//                        minimumLong = min(minFromLong, minToLong)
//                        break
//                    }
//                }
//                break
//            }
//        }
//        return CLLocationCoordinate2D.init(latitude: minimumLat!, longitude: minimumLong!)
//    }
//
//    private func findMaximumNYCCoordinate () -> CLLocationCoordinate2D {
//        var maximumLat: Double?
//        for location in locationsSortedByToLat!.reverse() {
//            if let maxToLat = location.toCoordinate?.latitude {
//                for loc in locationsSortedByFromLat!.reverse() {
//                    if let maxFromLat = loc.fromCoordinate?.latitude {
//                        maximumLat = max(maxToLat, maxFromLat)
//                        break
//                    }
//                }
//                break
//            }
//        }
//        var maximumLong: Double?
//        for location in locationsSortedByToLong!.reverse() {
//            if let maxToLong = location.toCoordinate?.longitude {
//                for location in locationsSortedByFromLong!.reverse() {
//                    if let maxFromLong = location.fromCoordinate?.longitude {
//                        maximumLong = max(maxFromLong, maxToLong)
//                        break
//                    }
//                }
//                break
//            }
//        }
//        return CLLocationCoordinate2D.init(latitude: maximumLat!, longitude: maximumLong!)
//
//    }
//
//
//
//    // MARK: - Get the locations and signs within current visible region
//
//    func getCurrentSignsFor(currentVisibleRegion: GMSVisibleRegion) {
//        currentLocations = getLocationsFor(currentVisibleRegion)
//        currentLocationsAndSigns = getCurrentLocationsAndSigns()
//    }
//
//    private func getCurrentLocationsAndSigns() -> [(location:SPLocation, signs:[SPSign])] {
//        var signsByBorough: [SPSign]?
//        var signs = [SPSign]()
//        var signAndLocationsArray = [(location:SPLocation, signs:[SPSign])]()
//
//        for location in currentLocations {
//            var signAndLocations: (location:SPLocation, signs:[SPSign])
//            signAndLocations.location = location
//            switch location.borough! {
//            case "B":
//                signsByBorough = bronxSigns
//            case "K":
//                signsByBorough = brooklynSigns
//            case "M":
//                signsByBorough = manhattanSigns
//            case "Q":
//                signsByBorough = queensSigns
//            case "S":
//                signsByBorough = statenIslandSigns
//            default:
//                break
//            }
//            var lowerIndex = 0
//            var upperIndex = (signsByBorough?.count)! - 1
//            var locationIndex = Int()
//
//            while lowerIndex <= upperIndex {
//                let currentIndex = (lowerIndex + upperIndex) / 2
//                if signsByBorough![currentIndex].locationNumber == location.locationNumber {
//                    locationIndex = currentIndex
//                    break
//                } else if signsByBorough![currentIndex].locationNumber < location.locationNumber{
//                    lowerIndex = currentIndex + 1
//                } else if signsByBorough![currentIndex].locationNumber > location.locationNumber{
//                    upperIndex = currentIndex - 1
//                }
//            }
//            var searchUp = locationIndex
//            var searchDown = locationIndex - 1
//
//            while signsByBorough![searchUp].locationNumber == location.locationNumber || searchUp < signsByBorough?.count {
//                signs.append(signsByBorough![searchUp])
//                searchUp += 1
//                if searchUp >= signsByBorough!.count - 1 {
//                    break
//                }
//            }
//            if searchDown >= 0 {
//                while signsByBorough![searchDown].locationNumber == location.locationNumber || searchDown >= 0 {
//                    signs.append(signsByBorough![searchDown])
//                    searchDown -= 1
//                    if searchDown < 0 {
//                        break
//                    }
//                }
//            }
//
//
//            signAndLocations.signs = signs
//
//            signAndLocationsArray.append(signAndLocations)
//        }
//        return signAndLocationsArray
//    }
//
//    private func getLocationsFor(currentVisibleRegion:GMSVisibleRegion) -> [SPLocation] {
//
//        visibleRegionBounds = GMSCoordinateBounds.init(region: currentVisibleRegion)
//
//        var toLatIndexNE: Int?
//        var fromLatIndexNE: Int?
//        var toLatIndexSW: Int?
//        var fromLatIndexSW: Int?
//
//        let returnLocations = NSMutableSet()
//
//        if isVisibleRegionCoordinateInNYC(visibleRegionBounds!.northEast) || isVisibleRegionCoordinateInNYC(visibleRegionBounds!.southWest) {
//            toLatIndexSW = binarySearchForLocationIndexWithLatitude(visibleRegionBounds!.southWest.latitude, locationArray: locationsSortedByToLat!).greaterIndex
//            toLatIndexNE = binarySearchForLocationIndexWithLatitude(visibleRegionBounds!.northEast.latitude, locationArray: locationsSortedByToLat!).lesserIndex
//
//            fromLatIndexSW = binarySearchForLocationIndexWithLatitude(visibleRegionBounds!.southWest.latitude, locationArray: locationsSortedByFromLat!).greaterIndex
//            fromLatIndexNE = binarySearchForLocationIndexWithLatitude(visibleRegionBounds!.northEast.latitude, locationArray: locationsSortedByFromLat!).lesserIndex
//
//            let date = NSDate()
//            returnLocations.addObjectsFromArray(getLocationsInRange(toLatIndexSW!, upper: toLatIndexNE!, visibleRegion:visibleRegionBounds!, typeOfArray: SPLocationArrayType.ToLat))
//
//            returnLocations.addObjectsFromArray(getLocationsInRange(fromLatIndexSW!, upper: fromLatIndexNE!, visibleRegion:visibleRegionBounds!, typeOfArray: SPLocationArrayType.FromLat))
//            print("Time to find locations in current visible region: \(date.timeIntervalSinceNow)")
//        }
//        return returnLocations.allObjects as! [SPLocation]
//    }
//
//
//    private func isVisibleRegionCoordinateInNYC (coordinate: CLLocationCoordinate2D) -> Bool {
//        return isCoordinateWithinRegion(coordinate, NECoordinate: maxNYCCoordinate!, SWCoordinate: minNYCCoordinate!)
//    }
//    private func isCoordinateWithinRegion (testCoordinate: CLLocationCoordinate2D, NECoordinate: CLLocationCoordinate2D, SWCoordinate: CLLocationCoordinate2D) -> Bool {
//        if testCoordinate.latitude < NECoordinate.latitude && testCoordinate.latitude > SWCoordinate.latitude {
//            if testCoordinate.longitude < NECoordinate.longitude && testCoordinate.longitude > SWCoordinate.longitude {
//                return true
//            } else {
//                return false
//            }
//        } else {
//            return false
//        }
//    }
//
//    private func binarySearchForLocationIndexWithLatitude (latitude: Double, locationArray: Array<SPLocation>) -> (greaterIndex: Int, lesserIndex: Int) {
//        var lowerIndex = 0
//        var upperIndex = locationArray.count - 1
//
//        while upperIndex > lowerIndex {
//            let binaryIndex = (upperIndex + lowerIndex) / 2
//            let value = locationArray[binaryIndex].sortedCoordinate?.latitude
//            if locationArray[lowerIndex].sortedCoordinate?.latitude == latitude {
//                return findClosestGreaterAndLowerValues((lowerIndex, lowerIndex), locationArray: locationArray, latitude: latitude)
//            } else if latitude == value {
//                return findClosestGreaterAndLowerValues((binaryIndex, binaryIndex), locationArray: locationArray, latitude: latitude)
//            } else if locationArray[upperIndex].sortedCoordinate?.latitude == latitude {
//                return findClosestGreaterAndLowerValues((upperIndex, upperIndex), locationArray: locationArray, latitude: latitude)
//            } else if latitude < value {
//                if upperIndex == binaryIndex {
//                    return findClosestGreaterAndLowerValues((upperIndex, lowerIndex), locationArray: locationArray, latitude: latitude)
//                }
//                upperIndex = binaryIndex
//            } else {
//                if lowerIndex == binaryIndex {
//                    return findClosestGreaterAndLowerValues((upperIndex, lowerIndex), locationArray: locationArray, latitude: latitude)
//                }
//                lowerIndex = binaryIndex
//            }
//        }
//        return findClosestGreaterAndLowerValues((upperIndex, lowerIndex), locationArray: locationArray, latitude: latitude)
//    }
//
//    private func findClosestGreaterAndLowerValues (indices: (upper: Int, lower: Int), locationArray: Array<SPLocation>, latitude: Double) -> (greaterIndex: Int, lesserIndex: Int) {
//
//        var tuple = indices
//        while tuple.upper < locationArray.count {
//            if locationArray[tuple.upper].sortedCoordinate?.latitude > latitude {
//                break
//            } else {
//                tuple.upper += 1
//            }
//        }
//        while tuple.lower > 0 {
//            if locationArray[tuple.lower].sortedCoordinate?.latitude < latitude {
//                break
//            } else {
//                tuple.lower += 1
//            }
//        }
//        return (tuple.upper, tuple.lower)
//    }
//
//    private func getLocationsInRange(lower:Int, upper:Int, visibleRegion:GMSCoordinateBounds, typeOfArray:SPLocationArrayType) -> [SPLocation] {
//        var iterateArray = [SPLocation]()
//        if typeOfArray == SPLocationArrayType.FromLat {
//            iterateArray = locationsSortedByFromLat!
//        } else if typeOfArray == SPLocationArrayType.ToLat {
//            iterateArray = locationsSortedByToLat!
//        }
//        var returnArray = [SPLocation]()
//
//        if isVisibleRegionCoordinateInNYC(visibleRegion.northEast) || isVisibleRegionCoordinateInNYC(visibleRegion.southWest){
//            for i in lower...upper {
//                if let sortedCoordinate = iterateArray[i].sortedCoordinate {
//                    if isCoordinateWithinRegion(sortedCoordinate, NECoordinate: visibleRegion.northEast, SWCoordinate: visibleRegion.southWest) {
//                        returnArray.append(iterateArray[i])
//                    }
//                }
//            }
//        }
//
//        return returnArray
//    }
//    //MARK:Manage polylines
//    func getPolylinesFromCurrentLocations() -> [GMSPolyline] {
//        var returnArray = [GMSPolyline]()
//        for signsAndLocations in currentLocationsAndSigns {
//            let path = GMSMutablePath()
//            if let snappedPoints = signsAndLocations.location.snappedPoints {
//                for point in snappedPoints {
//                    path.addCoordinate(point.coordinate!)
//                }
//            } else {
//                if let fromCoordinate = signsAndLocations.location.fromCoordinate {
//                    path.addCoordinate(fromCoordinate)
//                }
//                if let toCoordinate = signsAndLocations.location.toCoordinate {
//                    path.addCoordinate(toCoordinate)
//                }
//            }
//            let polyline = GMSPolyline.init(path: path)
//            returnArray.append(polyline)
//        }
//        return returnArray
//    }
//}
