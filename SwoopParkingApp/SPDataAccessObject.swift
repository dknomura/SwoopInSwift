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
    var locationCountsForTimeAndDay = [DNDay: [DNTime: Int]]()
    var locationsCountsForDays = [DNDay: Int]()
    var expectedNumberOfCounts = 0
    var numberOfCounts = 0
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
    var isFirstLocationAfterAuthorization = false
    var date = Date()
    
    var currentCity: SPCity = .NYC

    // MARK: - SQLite methods
    func setStreetCleaningLocationsForPrimaryTimeAndDay() {
        sqlReader.queryStreetCleaningLocations(forTimeAndDay: primaryTimeAndDay)
    }
    
    func setCountOfStreetCleaningTimes(forDay day: DNDay, at coordinate: CLLocationCoordinate2D, radius: Double) {
        let corners = coordinate.swNECorners(withRadius: radius)
        sqlReader.queryLocationCounts(forDay: day, swCoordinate: corners.sw, neCoordinate: corners.ne)
    }
    
    func setCountOfStreetCleaningLocationsForAllDays(at coordinate: CLLocationCoordinate2D, radius: Double) {
        let corners = coordinate.swNECorners(withRadius: radius)
        
    }
    
    func setSigns(forCurrentMapView mapView:GMSMapView) {
        let visibleRegionBounds = GMSCoordinateBounds.init(region: mapView.projection.visibleRegion())
        print("Coordainte: \(visibleRegionBounds.northEast), \(visibleRegionBounds.southWest)")
        sqlReader.querySignsAndLocations(swCoordinate: visibleRegionBounds.southWest, neCoordinate: visibleRegionBounds.northEast)
    }
    
    // MARK: - SQLite and Lambda delegate methods
    func sqlQueryDidFinish(withResponse response: SPSQLResponse) {
        var parser = SPParser()
        parser.inject(self)
        guard response.results != nil else { return }
        parser.parseSQL(fromResponse: response)
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
            searchCoordinate = response.googleAPIResponse?.placeIDCoordinate
            googleSearchObject.info = response.googleAPIResponse?.formattedAddress
            delegate?.dataAccessObject(self, didSetGoogleSearchObject: googleSearchObject)
        case .presentAddress:
            if response.googleAPIResponse?.addressResults?.count == 1 {
                googleSearchObject.coordinate = response.googleAPIResponse?.addressResults?[0].coordinate
                searchCoordinate = googleSearchObject.coordinate
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
