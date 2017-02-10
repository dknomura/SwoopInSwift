//
//  SPLambdaManager.swift
//  SwoopParkingApp
//
//  Created by Daniel Nomura on 7/7/16.
//  Copyright © 2016 Daniel Nomura. All rights reserved.
//

import Foundation
import AWSLambda
import CoreLocation

struct SPLambdaManager {
    weak var delegate: SPLambdaManagerDelegate?
    //MARK: TO DO 
    // Change lambda function names to match SPSQLLocationQueryType.rawValues
    func upcomingStreetCleaningQuery(forDayAndTime dayAndTime:(day:Int, hour:Int, minute:Int)) {
        _ = ["hour": dayAndTime.hour, "day": dayAndTime.day]
//        invoke(.getAllLocationsWithUniqueCleaningSign, parameters: parameters as NSDictionary)
    }
    
    func signsAndLocationsQuery(_ fromCoordinateNE: CLLocationCoordinate2D, coordinateSW: CLLocationCoordinate2D) {
        
        let parameters = ["northEastLatitude": fromCoordinateNE.latitude, "northEastLongitude": fromCoordinateNE.longitude, "southWestLatitude": coordinateSW.latitude, "southWestLongitude": coordinateSW.longitude]
        invoke(.getLocationsForCurrentMapView, parameters: parameters as NSDictionary)
    }
    
    fileprivate func invoke(_ lambdaFunction: SPSQLLocationQueryTypes, parameters:NSDictionary) {
        let lambdaInvoker = AWSLambdaInvoker.default()
        let date = Date()
        lambdaInvoker.invokeFunction(lambdaFunction.rawValue, jsonObject: parameters) { (response, error) in
            let timeLapse = date.timeIntervalSinceNow
            print("Time lapse for \(lambdaFunction): \(timeLapse)")
            
            if (error != nil) {
                print("Error invoking lambda function \(lambdaFunction) \n\(error?.localizedDescription)")
            }
            else if response != nil {
                DispatchQueue.main.async(execute: {
                    guard let responseDict = response as? NSDictionary else {
                        print("Response isn't a dictionary, for lambda funcion: \(lambdaFunction)")
                        return
                    }
                    self.delegate?.lambdaFunctionDidFinish(withResponse: responseDict)
                })
            }
        }
    }
}

protocol SPLambdaManagerDelegate: class {
    func lambdaFunctionDidFinish(withResponse responseDict:NSDictionary)
}


