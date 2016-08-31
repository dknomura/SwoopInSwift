//
//  SPDataAccessObject.swift
//  SwoopParkingApp
//
//  Created by Daniel Nomura on 8/9/16.
//  Copyright © 2016 Daniel Nomura. All rights reserved.
//

import Foundation
import GoogleMaps

enum DAOError:ErrorType {
    case noDao(forFunction: String)
}

class SPDataAccessObject: NSObject, CLLocationManagerDelegate, SPSQLiteReaderDelegate, SPLambdaManagerDelegate, SPGoogleNetworkingDelegate {
    
    var delegate: SPDataAccessObjectDelegate?
    var locationsForDayAndTime = [SPLocation]()
    var currentMapViewLocations = [SPLocation]()
    var currentLocation: CLLocation?
    var streetCleaningLocations = [SPLocation]()
    var currentDayAndTimeInt: SPTimeAndDayInt { return SPTimeAndDayManager().getCurrentDayHourMinutes() }
    let locationManager = CLLocationManager()
    var primaryTimeAndDayString: SPTimeAndDayString?
    var secondaryTimeAndDayString: SPTimeAndDayString?
    var addressResults = [SPGoogleAddressResult]()
    var searchCoordinate: CLLocationCoordinate2D?
    
    //MARK: - Time and Day data access methods
    func dayString(fromInt dayInt:Int) -> String {
        do{
            return try SPTimeAndDayManager().getDayString(fromInt: dayInt)
        } catch {
            print("Day Int \(dayInt) is not between 1 and 7")
            return "Mon"
        }
    }
    
    func dayAndTimeForSQLCall(dayAndTime:SPTimeAndDayString) -> SPTimeAndDayString {
        var time = SPTimeAndDayManager().convertTimeString(dayAndTime.time, toFormat: .format12Hour)
        
        if let removeRange = dayAndTime.time.rangeOfString(":00") {
            time.removeRange(removeRange)
            return SPTimeAndDayString(time: time, day: dayAndTime.day)
        } else {
            return SPTimeAndDayString(time: time, day:dayAndTime.day)
        }
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
    
    func getUpcomingStreetCleaningSigns() {
        var sqliteReader = SPSQLiteReader()
        sqliteReader.delegate = self
        sqliteReader.queryUpcomingStreetCleaningSignsAndLocations(currentDayAndTimeInt)
    }
    
    func getSigns(forCurrentMapView mapView:GMSMapView) {
        let visibleRegionBounds = GMSCoordinateBounds.init(region: mapView.projection.visibleRegion())
        
        var sqlReader = SPSQLiteReader()
        sqlReader.delegate = self
        sqlReader.dao = self
        sqlReader.querySignsAndLocations(swCoordinate: visibleRegionBounds.southWest, neCoordinate: visibleRegionBounds.northEast)
        
        //         hit the swoop button to find the current map center and zoom
    }
    
    // MARK: - SQLite and Lambda delegate methods
    func sqlQueryDidFinish(withResults results: (queryType: SPSQLLocationQueryTypes, locationResults: [SPLocation])) {
        if results.queryType == .getLocationsForCurrentMapView {
            currentMapViewLocations = results.locationResults
        } else if results.queryType == .getLocationsForTimeAndDay {
            locationsForDayAndTime = results.locationResults
        }
        delegate?.dataAccessObject(self, didSetLocations: results.locationResults, forQueryType: results.queryType)
    }
    
    func lambdaFunctionDidFinish(withResponse responseDict: NSDictionary) {
        guard responseDict["status"] as? String == "Success" else {
            print("error with lambda function, \(responseDict["lambdaFunction"]), call: \(responseDict["response"])")
            return
        }
        
        //NEED TO CHANGE SERVER RESPONSE TO HAVE "lambdaFunction" MATCH "getLocationsForCurrentMapView"
        if responseDict["lambdaFunction"] as? String == SPSQLLocationQueryTypes.getLocationsForCurrentMapView.rawValue,
            let data = responseDict["response"] as? NSArray {
            currentMapViewLocations = SPParser().parseLambdaSignsAndLocationsFromCoordinates(data)
            delegate?.dataAccessObject(self, didSetLocations: currentMapViewLocations, forQueryType: .getLocationsForCurrentMapView)
        }
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
    func googleNetworking(googleNetwork: SPGoogleNetworking, didFinishWithResponse response: SPGoogleResponse, delegateAction: SPNetworkingDelegateAction) {
        if delegateAction == .presentAutocompleteResults {
            presentSearchResultsOnTableView(fromResponse: response)
        } else if delegateAction == .presentCoordinate {
            searchCoordinate = response.googleAPIResponse?.placeIDCoordinate
            delegate?.dataAccessObject(self, didSetSearchCoordinate: searchCoordinate!)
        } else if delegateAction == .presentAddress {
            if response.googleAPIResponse?.addressResults?.count == 1 {
                searchCoordinate = response.googleAPIResponse?.addressResults?[0].coordinate
                delegate?.dataAccessObject(self, didSetSearchCoordinate: searchCoordinate!)
            } else {
                presentSearchResultsOnTableView(fromResponse: response)
            }
        }
    }
    
    private func presentSearchResultsOnTableView(fromResponse response:SPGoogleResponse) {
        if response.googleAPIResponse?.addressResults != nil {
            addressResults = (response.googleAPIResponse?.addressResults)!
            delegate?.dataAccessObject(self, didUpdateAddressResults: addressResults)
        }
    }
}

protocol SPDataAccessObjectDelegate: class {
    //For SQL calls
    func dataAccessObject(dao: SPDataAccessObject, didSetLocations locations:[SPLocation], forQueryType:SPSQLLocationQueryTypes)
    
    //For google API calls
    func dataAccessObject(dao: SPDataAccessObject, didSetSearchCoordinate coordinate:CLLocationCoordinate2D)
    func dataAccessObject(dao: SPDataAccessObject, didUpdateAddressResults:[SPGoogleAddressResult])
    
}