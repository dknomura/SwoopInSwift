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
    
    func upcomingStreetCleaningQuery(forDayAndTime dayAndTime:(day:Int, hour:Int, minute:Int)) {
        let parameters = ["hour": dayAndTime.hour, "day": dayAndTime.day]
        
        invoke(kSPLambdaGetSignsAndLocationsForTimeAndDay, parameters: parameters)
    }
    
    func signsAndLocationsQuery(fromCoordinateNE: CLLocationCoordinate2D, coordinateSW: CLLocationCoordinate2D) {
        
        let parameters = ["northEastLatitude": fromCoordinateNE.latitude, "northEastLongitude": fromCoordinateNE.longitude, "southWestLatitude": coordinateSW.latitude, "southWestLongitude": coordinateSW.longitude]
        
        invoke(kSPLambdaGetSignsAndLocationsForCoordinates, parameters: parameters)
    }

    private func invoke(lambdaFunction: String, parameters:NSDictionary) {
        let lambdaInvoker = AWSLambdaInvoker.defaultLambdaInvoker()
        let date = NSDate()
        lambdaInvoker.invokeFunction(lambdaFunction, JSONObject: parameters) { (response, error) in
            let timeLapse = date.timeIntervalSinceNow
            print("Time lapse for \(lambdaFunction): \(timeLapse)")

            if (error != nil) {
                print("Error invoking lambda function \(lambdaFunction) \n\(error?.userInfo)\n\(error?.localizedDescription)")
            }
            else if response != nil {
                dispatch_async(dispatch_get_main_queue(), {
                    guard let responseDict = response as? NSDictionary else {
                        print("Response isn't a dictionary")
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


