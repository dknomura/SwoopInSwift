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

enum DAOError:Error {
    case noDao(forFunction: String)
}

class SPDataAccessObject: NSObject, CLLocationManagerDelegate, SPSQLiteReaderDelegate, SPLambdaManagerDelegate, SPGoogleNetworkingDelegate, UIStateRestoring {
    var delegate: SPDataAccessObjectDelegate?
    var sqlReader: SPSQLiteReader!
    
    var locationsForDayAndTime = [SPLocation]()
    var currentMapViewLocations = [SPLocation]()
    var currentLocation: CLLocation?
    let locationManager = CLLocationManager()
    var primaryTimeAndDay = DNTimeAndDay.currentTimeAndDay()
    var addressResults = [SPGoogleAddressResult]()
    var googleSearchObject = SPGoogleCoordinateAndInfo()
    var searchCoordinate: CLLocationCoordinate2D?
    var allLocationsForDayValue = [Double: [SPLocation]]()
    var locationsForPrimaryTimeAndDay: [SPLocation]? {
        return allLocationsForDayValue[primaryTimeAndDay.rawValue]
    }
    var signForPathCoordinates = [String: SPSign]()
    //MARK: - Determine if current mapView is within NYC
    
    func isInNYC(_ mapView:GMSMapView) -> Bool {
        let region = GMSCoordinateBounds.init(region: mapView.projection.visibleRegion())
        if isCoordinateWithinRegion(region.northEast, NECoordinate: maxNYCCoordinate, SWCoordinate: minNYCCoordinate) || isCoordinateWithinRegion(region.southWest, NECoordinate: maxNYCCoordinate, SWCoordinate: minNYCCoordinate) { return true }
        else { return false }
    }
    fileprivate func isCoordinateWithinRegion (_ testCoordinate: CLLocationCoordinate2D, NECoordinate: CLLocationCoordinate2D, SWCoordinate: CLLocationCoordinate2D) -> Bool {
        if testCoordinate.latitude < NECoordinate.latitude && testCoordinate.latitude > SWCoordinate.latitude {
            if testCoordinate.longitude < NECoordinate.longitude && testCoordinate.longitude > SWCoordinate.longitude { return true }
            else { return false }
        } else { return false }
    }
    // MARK: - SQLite methods
    func getAllStreetCleaningLocations() {
        sqlReader.queryAllStreetCleaningLocations()
    }
    
    func getStreetCleaningLocationsForPrimaryTimeAndDay() {
        sqlReader.queryStreetCleaningLocations(forTimeAndDay: primaryTimeAndDay)
    }
        
    func getSigns(forCurrentMapView mapView:GMSMapView) {
        let visibleRegionBounds = GMSCoordinateBounds.init(region: mapView.projection.visibleRegion())
        sqlReader.querySignsAndLocations(swCoordinate: visibleRegionBounds.southWest, neCoordinate: visibleRegionBounds.northEast)
    }
    
    // MARK: - SQLite and Lambda delegate methods
    func sqlQueryDidFinish(withResponse response: SPSQLResponse) {
        var parser = SPParser()
        parser.inject(self)
        parser.parseSQL(fromResults: response.results!, queryType: response.queryType)
//            locationCountForDayValue[response.timeAndDay!.rawValue] = Int(response.results!.intForColumn("count(*)"))
        DispatchQueue.main.async {
            self.delegate?.dataAccessObject(self, didSetLocationsForQueryType: response.queryType)
        }
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
        locationManager.startUpdatingLocation()
    }
    // MARK: - CLManager delegate
    var isFirstLocationAfterAuthorization = false
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if (locations.count == 0) { return }
        currentLocation = locations.last!
        if isFirstLocationAfterAuthorization {
            isFirstLocationAfterAuthorization = false
            delegate?.dataAccessObjectDidAllowLocationServicesAndSetCurrentLocation()
        }
    }
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        if status == .authorizedWhenInUse {
            if !UserDefaults.standard.bool(forKey: kSPDidAllowLocationServices) {
                UserDefaults.standard.set(true, forKey: kSPDidAllowLocationServices)
                isFirstLocationAfterAuthorization = true
            }
        }
    }
    
    //MARK: - Networking Delegate methods
    //MARK: ---Google networking delegate
    func googleNetworking(_ googleNetwork: SPGoogleNetworking, didFinishWithResponse response: SPGoogleObject, delegateAction: SPNetworkingDelegateAction) {
        switch delegateAction {
        case .presentAutocompleteResults:
            setAddressResultsForTableView(fromResponse: response)
        case .presentCoordinate:
            googleSearchObject.coordinate = response.googleAPIResponse?.placeIDCoordinate
            googleSearchObject.info = response.googleAPIResponse?.formattedAddress
            delegate?.dataAccessObject(self, didSetGoogleSearchObject: googleSearchObject)
        case .presentAddress:
            if response.googleAPIResponse?.addressResults?.count == 1 {
                googleSearchObject.coordinate = response.googleAPIResponse?.addressResults?[0].coordinate
                googleSearchObject.info = response.googleAPIResponse?.addressResults?[0].address
                delegate?.dataAccessObject(self, didSetGoogleSearchObject: googleSearchObject)
            } else {
                setAddressResultsForTableView(fromResponse: response)
            }
        default: break
        }
    }
    
    fileprivate func setAddressResultsForTableView(fromResponse response:SPGoogleObject) {
        if response.googleAPIResponse?.addressResults != nil {
            addressResults = (response.googleAPIResponse?.addressResults)!
            delegate?.dataAccessObject(self, didUpdateAddressResults: addressResults)
        }
    }
}
protocol SPDataAccessObjectDelegate: class {
    //For SQL calls
    func dataAccessObject(_ dao: SPDataAccessObject, didSetLocationsForQueryType:SPSQLLocationQueryTypes)
    
    //For google API calls
    func dataAccessObject(_ dao: SPDataAccessObject, didSetGoogleSearchObject googleSearchObject:SPGoogleCoordinateAndInfo)
    func dataAccessObject(_ dao: SPDataAccessObject, didUpdateAddressResults:[SPGoogleAddressResult])
    func dataAccessObjectDidAllowLocationServicesAndSetCurrentLocation()
}
