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

struct SPSignAndLocationManager {
    //MARK: - Parse lambda response and create sign and location structs
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
                            sign.signType = signDictionary[kSPSignTypeJSON] as? String
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
    
    //MARK: - Determine if current mapView is within NYC
    let maxNYCCoordinate = CLLocationCoordinate2DMake(40.91295931663856, -73.70059684703173)
    let minNYCCoordinate = CLLocationCoordinate2DMake(40.49785967315467, -74.25453161899142)

    func isVisibleRegionWithinNYC (region: GMSCoordinateBounds) -> Bool {
        if isCoordinateWithinRegion(region.northEast, NECoordinate: maxNYCCoordinate, SWCoordinate: minNYCCoordinate) || isCoordinateWithinRegion(region.southWest, NECoordinate: maxNYCCoordinate, SWCoordinate: minNYCCoordinate) {
            return true
        } else {
            return false
        }
    }
    
    private func isCoordinateWithinRegion (testCoordinate: CLLocationCoordinate2D, NECoordinate: CLLocationCoordinate2D, SWCoordinate: CLLocationCoordinate2D) -> Bool {
        if testCoordinate.latitude < NECoordinate.latitude && testCoordinate.latitude > SWCoordinate.latitude {
            if testCoordinate.longitude < NECoordinate.longitude && testCoordinate.longitude > SWCoordinate.longitude {
                return true
            } else {
                return false
            }
        } else {
            return false
        }
    }
    //MARK: Sign and Location Constants
    //Location JSON properties/dictionary keys
    let kSPSignsJSON = "signs"
    let kSPSignIndexJSON = "signIndex"
    let kSPPositionInFeetJSON = "positionInFeet"
    let kSPDirectionOfArrowJSON = "directionOfArrow"
    let kSPSignContentJSON = "signContent"
    let kSPSignTypeJSON = "signType"
    let kSPBoroughJSON = "borough"
    let kSPlocationNumberJSON = "locationNumber"
    
    
    //Sign JSON properties/dictionary keys
    let kSPStreetJSON = "street"
    let kSPFromCrossStreetJSON = "fromCrossStreet"
    let kSPToCrossStreetJSON = "toCrossStreet"
    let kSPSideOfStreetJSON = "sideOfStreet"
    let kSPFromLatitudeJSON = "fromLatitude"
    let kSPFromLongitudeJSON = "fromLongitude"
    let kSPToLatitudeJSON = "toLatitude"
    let kSPToLongitudeJSON = "toLongitude"
    let kSPSnappedPointsJSON = "snappedPoints"

}


struct SPSign {
    var values: NSMutableDictionary?
    var signIndex: Int?
    var positionInFeet: Double?
    var directionOfArrow: String?
    var signContent: String?
    var signType: String?
}

struct SPLocation {
    var id: Int?
    var values: NSMutableDictionary?
    var borough: String?
    var locationNumber: String?
    var street: String?
    var fromCrossStreet: String?
    var toCrossStreet: String?
    var sideOfStreet: String?
//    var sortedCoordinate: CLLocationCoordinate2D?
    var fromCoordinate: CLLocationCoordinate2D?
    var toCoordinate: CLLocationCoordinate2D?
    var signs: [SPSign]?
    var snappedPoints: [SPSnappedPoint]?
    var isGoodStreetCleaning: Bool?
}

struct SPSnappedPoint {
    var coordinate: CLLocationCoordinate2D?
    var originalIndex: NSInteger?
    var placeID: String?
}



//Snapped point prop/dict key
let kSPLocation = "location"
let kSPLatitude = "latitude"
let kSPLongitude = "longitude"
let kSPOriginalIndex = "originalIndex"
let kSPPlaceID = "placeId"

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
