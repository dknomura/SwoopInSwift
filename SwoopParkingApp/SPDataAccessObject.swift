//
//  SPDataAccessObject.swift
//  SwoopParkingApp
//
//  Created by Daniel Nomura on 8/9/16.
//  Copyright © 2016 Daniel Nomura. All rights reserved.
//

import Foundation
import GoogleMaps
import DNTimeAndDay

enum DAOError:ErrorType {
    case noDao(forFunction: String)
}

class SPDataAccessObject: NSObject, CLLocationManagerDelegate, SPSQLiteReaderDelegate, SPLambdaManagerDelegate, SPGoogleNetworkingDelegate {
    
    var delegate: SPDataAccessObjectDelegate?
    var sqlReader: SPSQLiteReader = SPSQLiteReader.init()
    
    var locationsForDayAndTime = [SPLocation]()
    var currentMapViewLocations = [SPLocation]()
    var currentLocation: CLLocation?
    let locationManager = CLLocationManager()
    var primaryTimeAndDay: DNTimeAndDay = DNTimeAndDay.currentTimeAndDay()
    var addressResults = [SPGoogleAddressResult]()
    var searchCoordinate: CLLocationCoordinate2D?
    var allLocationsForDayValue = [Double: [SPLocation]]()
    var locationsForPrimaryTimeAndDay: [SPLocation]? {
        return allLocationsForDayValue[primaryTimeAndDay.rawValue]
    }
    //MARK: - Determine if current mapView is within NYC
    
    func isInNYC(mapView:GMSMapView) -> Bool {
        let region = GMSCoordinateBounds.init(region: mapView.projection.visibleRegion())
        if isCoordinateWithinRegion(region.northEast, NECoordinate: maxNYCCoordinate, SWCoordinate: minNYCCoordinate) || isCoordinateWithinRegion(region.southWest, NECoordinate: maxNYCCoordinate, SWCoordinate: minNYCCoordinate) { return true }
        else { return false }
    }
    private func isCoordinateWithinRegion (testCoordinate: CLLocationCoordinate2D, NECoordinate: CLLocationCoordinate2D, SWCoordinate: CLLocationCoordinate2D) -> Bool {
        if testCoordinate.latitude < NECoordinate.latitude && testCoordinate.latitude > SWCoordinate.latitude {
            if testCoordinate.longitude < NECoordinate.longitude && testCoordinate.longitude > SWCoordinate.longitude { return true }
            else { return false }
        } else { return false }
    }
    // MARK: - SQLite methods
    func getAllStreetCleaningLocations() {
        sqlReader.delegate = self
        sqlReader.queryAllStreetCleaningLocations()
    }
    
    func getStreetCleaningLocationsForPrimaryTimeAndDay() {
        sqlReader.delegate = self
        sqlReader.queryStreetCleaningLocations(forTimeAndDay: primaryTimeAndDay)
    }
    
    func getSigns(forCurrentMapView mapView:GMSMapView) {
        let visibleRegionBounds = GMSCoordinateBounds.init(region: mapView.projection.visibleRegion())
        sqlReader.delegate = self
        sqlReader.querySignsAndLocations(swCoordinate: visibleRegionBounds.southWest, neCoordinate: visibleRegionBounds.northEast)
    }
    
    // MARK: - SQLite and Lambda delegate methods
    func sqlQueryDidFinish(withResults results: FMResultSet, queryType: SPSQLLocationQueryTypes) {
        if queryType == .getLocationsForCurrentMapView{
            currentMapViewLocations = locations(fromResults: results, queryType: queryType)
        } else if queryType == .getAllLocationsWithUniqueCleaningSign {
            allLocationsForDayValue = locationsForDayValue(fromResults:results, queryType: queryType)
        } else if queryType == .getLocationsForTimeAndDay {
            allLocationsForDayValue[primaryTimeAndDay.rawValue] = locations(fromResults: results, queryType: queryType)
        }
        dispatch_async(dispatch_get_main_queue()) {
            self.delegate?.dataAccessObject(self, didSetLocationsForQueryType: queryType)
        }
    }
    private func locations(fromResults results: FMResultSet, queryType: SPSQLLocationQueryTypes) -> [SPLocation]{
        var locationResults = [SPLocation]()
        results.next()
        while results.hasAnotherRow() {
            locationResults.append(SPLocation.init(sqlResultSet: results, queryType: queryType))
        }
        return locationResults
    }
    private func locationsForDayValue(fromResults results: FMResultSet, queryType: SPSQLLocationQueryTypes) -> [Double: [SPLocation]] {
        var locationResults = [Double: [SPLocation]]()
        results.next()
        while results.hasAnotherRow() {
            let location = SPLocation.init(sqlResultSet: results, queryType: queryType)
            let keys: [Double] = dayValues(forLocation: location)
            for key in keys  {
                if locationResults[key] == nil { locationResults[key] = [SPLocation]() }
                locationResults[key]?.append(location)
            }
        }
        return locationResults
    }
    private func dayValues(forLocation location:SPLocation) -> [Double] {
        var returnDoubles = [Double]()
        let tags = location.signContentTag?.characters.split{$0 == " "}.map(String.init)
        for tag in tags! {
            if tag.containsString("HOUR") { continue }
            var mRange = tag.rangeOfString("AM")
            if mRange == nil {
                mRange = tag.rangeOfString("PM")
                if mRange == nil { continue }
            }
            let timeString = tag.substringWithRange(tag.startIndex..<mRange!.endIndex)
            let dayString = tag.substringWithRange(mRange!.endIndex..<tag.endIndex)
            guard let timeAndDay = DNTimeAndDay.init(dayString: dayString, timeString: timeString) else {
                print("Error creating time and day object for location: \(location.locationNumber)/\(location.id)")
                continue
            }
            returnDoubles.append(timeAndDay.rawValue)
        }
        return returnDoubles
    }
    func lambdaFunctionDidFinish(withResponse responseDict: NSDictionary) {
//        guard responseDict["status"] as? String == "Success" else {
//            print("error with lambda function, \(responseDict["lambdaFunction"]), call: \(responseDict["response"])")
//            return
//        }
//        
//        //NEED TO CHANGE SERVER RESPONSE TO HAVE "lambdaFunction" MATCH "getLocationsForCurrentMapView" or the enum stringValue
//        if responseDict["lambdaFunction"] as? String == SPSQLLocationQueryTypes.getLocationsForCurrentMapView.rawValue,
//            let data = responseDict["response"] as? NSArray {
//            currentMapViewLocations = SPParser().parseLambdaSignsAndLocationsFromCoordinates(data)
//            delegate?.dataAccessObject(self, didSetLocations: currentMapViewLocations, forQueryType: .getLocationsForCurrentMapView)
//        }
    }
    
    
    //MARK: - CoreLocation methods and delegate methods
    func setUpLocationManager() {
        locationManager.delegate = self
        locationManager.distanceFilter = kCLDistanceFilterNone
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.requestAlwaysAuthorization()
        locationManager.requestWhenInUseAuthorization()
        locationManager.startUpdatingLocation()
    }
    
    // MARK: - CLManager delegate
    
    func locationManager(manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        currentLocation = locations.last!
        if (locations.count == 0) { return }
    }
    
    //MARK: - Networking Delegate methods
    //MARK: ---Google networking delegate
    func googleNetworking(googleNetwork: SPGoogleNetworking, didFinishWithResponse response: SPGoogleObject, delegateAction: SPNetworkingDelegateAction) {
        if delegateAction == .presentAutocompleteResults {
            setAddressResultsForTableView(fromResponse: response)
        } else if delegateAction == .presentCoordinate {
            searchCoordinate = response.googleAPIResponse?.placeIDCoordinate
            delegate?.dataAccessObject(self, didSetSearchCoordinate: searchCoordinate!)
        } else if delegateAction == .presentAddress {
            if response.googleAPIResponse?.addressResults?.count == 1 {
                searchCoordinate = response.googleAPIResponse?.addressResults?[0].coordinate
                delegate?.dataAccessObject(self, didSetSearchCoordinate: searchCoordinate!)
            } else {
                setAddressResultsForTableView(fromResponse: response)
            }
        }
    }
    
    private func setAddressResultsForTableView(fromResponse response:SPGoogleObject) {
        if response.googleAPIResponse?.addressResults != nil {
            addressResults = (response.googleAPIResponse?.addressResults)!
            delegate?.dataAccessObject(self, didUpdateAddressResults: addressResults)
        }
    }
}

protocol SPDataAccessObjectDelegate: class {
    //For SQL calls
    func dataAccessObject(dao: SPDataAccessObject, didSetLocationsForQueryType:SPSQLLocationQueryTypes)
    
    //For google API calls
    func dataAccessObject(dao: SPDataAccessObject, didSetSearchCoordinate coordinate:CLLocationCoordinate2D)
    func dataAccessObject(dao: SPDataAccessObject, didUpdateAddressResults:[SPGoogleAddressResult])
    
}