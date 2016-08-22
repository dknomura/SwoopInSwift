//
//  SPDataAccessObject.swift
//  SwoopParkingApp
//
//  Created by Daniel Nomura on 8/9/16.
//  Copyright © 2016 Daniel Nomura. All rights reserved.
//

import Foundation
import GoogleMaps

class SPDataAccessObject: NSObject, CLLocationManagerDelegate, SPSQLiteReaderDelegate, SPLambdaManagerDelegate {

    var locationsForDayAndTime = [SPLocation]()
    var currentMapViewLocations = [SPLocation]()
    var currentLocation: CLLocation?
    var streetCleaningLocations = [SPLocation]()
    var currentDayAndTimeInt: (day:Int, hour:Int, min:Int) { return SPTimeAndDayManager().getCurrentDayHourMinutes() }
    let locationManager = CLLocationManager()
    var primaryTimeAndDayString: (time:String, day:String)?
    var secondaryTimeAndDayString: (time:String, day:String)?
    
    
    
    func isInNYC(mapView:GMSMapView) -> Bool {
        return SPSignAndLocationManager().isVisibleRegionWithinNYC(GMSCoordinateBounds(region: mapView.projection.visibleRegion()))
    }
    
    // MARK: - SQLite methods
    
    func getUpcomingStreetCleaningSigns() {
        var sqliteReader = SPSQLiteReader()
        sqliteReader.delegate = self
//        sqliteReader.getAllSignsAndLocations()
        sqliteReader.queryUpcomingStreetCleaningSignsAndLocations(currentDayAndTimeInt)
    }


    func getSigns(forCurrentMapView mapView:GMSMapView) {
        let visibleRegionBounds = GMSCoordinateBounds.init(region: mapView.projection.visibleRegion())
        
        var sqlReader = SPSQLiteReader()
        sqlReader.delegate = self
        sqlReader.querySignsAndLocations(swCoordinate: visibleRegionBounds.southWest, neCoordinate: visibleRegionBounds.northEast)

        // hit the swoop button to find the current map center and zoom
//        print("center coordinate = (\((northEastCoordinate.latitude + southWestCoordinate.latitude) / 2), \((northEastCoordinate.longitude + southWestCoordinate.longitude) / 2)) zoom: \(mapView.camera.zoom)")
    }
        
    // MARK: - SQLite and Lambda delegate methods
    func sqlQueryDidFinish(withResults results: (queryType: String, locationResults: [SPLocation])) {
        if results.queryType == kSPSQLiteCoordinateQuery {
            currentMapViewLocations = results.locationResults
        } else if results.queryType == kSPSQLiteTimeAndDayQuery {
            locationsForDayAndTime = results.locationResults
        }
        NSNotificationCenter.defaultCenter().postNotificationName(results.queryType, object: nil)
    }
    
    func lambdaFunctionDidFinish(withResponse responseDict: NSDictionary) {
        guard responseDict["status"] as? String == "Success" else {
            print("error with lambda function, \(responseDict["lambdaFunction"]), call: \(responseDict["response"])")
            return
        }
        if responseDict["lambdaFunction"] as? String ==  kSPLambdaGetSignsAndLocationsForCoordinates,
            let data = responseDict["response"] as? NSArray {
            currentMapViewLocations = SPSignAndLocationManager().parseLambdaSignsAndLocationsFromCoordinates(data)
            NSNotificationCenter.defaultCenter().postNotificationName(kSPSQLiteCoordinateQuery, object: nil)
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
        if (locations.count == 0) {
            return
        }
    }
}