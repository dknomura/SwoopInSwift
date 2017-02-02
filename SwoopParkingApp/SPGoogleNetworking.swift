//
//  SPGoogleNetworking.swift
//  SwoopParkingApp
//
//  Created by Daniel Nomura on 8/29/16.
//  Copyright © 2016 Daniel Nomura. All rights reserved.
//

import Foundation

struct SPGoogleNetworking {
    let googlePlacesAPIKey = "AIzaSyCHTQ_3E4We3iwfp8miz15Nm6Un6oYBCmk"
    let googleGeocodingAPIKey = "AIzaSyA1mzaCuwm88uF1LSlkHvxzwQoTMm-ZptY"
    var centerLat: Double { return 40.7054094949 }
    var centerLong: Double { return -73.977564233 }
    var searchRadius: Double { return 42280 }
    

    
    weak var delegate: SPGoogleNetworkingDelegate?

    func autocomplete(_ inputText:String) {
        let urlString = "https://maps.googleapis.com/maps/api/place/autocomplete/json?input=\(inputText)&location=\(centerLat),\(centerLong)&radius=\(searchRadius)&key=\(googlePlacesAPIKey)"
        startURLGetSession(withURLString: urlString, delegateAction: .presentAutocompleteResults)
    }
    
    func geocode(addressResultWithoutCoordinate addressResult:SPGoogleAddressResult) {
        let queryString = "https://maps.googleapis.com/maps/api/place/details/json?placeid=\(addressResult.placeID)&key=\(googlePlacesAPIKey)"
        startURLGetSession(withURLString: queryString, delegateAction: .presentCoordinate)
    }
    
    func searchAddress(_ address:String, city: SPCity) {
        let queryString = "https://maps.googleapis.com/maps/api/geocode/json?address=\(address)&bounds=\(city.minCoordinate.latitude),\(city.minCoordinate.longitude)|\(city.maxCoordinate.latitude),\(city.maxCoordinate.longitude)&key=\(googleGeocodingAPIKey)"
        startURLGetSession(withURLString: queryString, delegateAction: .presentAddress)
    }

    
    fileprivate func startURLGetSession(withURLString urlString:String, delegateAction:SPNetworkingDelegateAction) {
        guard let encodedURLString = urlString.addingPercentEncoding(withAllowedCharacters: CharacterSet.urlQueryAllowed) else {
            print("Unable to make encoded URL string from \(urlString)")
            return
        }
        guard let url = URL.init(string: encodedURLString) else {
            print("Unable to make NSURL object from string: \(encodedURLString)")
            return
        }
        let request = URLRequest.init(url: url)
        let session = URLSession.shared
        let datatask = session.dataTask(with: request, completionHandler: { (data, response, error) in
            if error != nil { print("Error with google API request: \(error!.localizedDescription)\n\(error!._userInfo)") }
            else if data != nil {
                do {
                    if let responseDict: NSDictionary = try JSONSerialization.jsonObject(with: data!, options:JSONSerialization.ReadingOptions.allowFragments) as? NSDictionary {
                        var returnResponse = SPGoogleObject()
                        let statusCodeString = responseDict["status"] as? String
                        returnResponse.googleStatusCode = self.statusCode(fromString: statusCodeString)
                        if returnResponse.googleStatusCode == SPGoogleStatusCodes.OK {
                            SPParser().parseGoogleAPIResponse(responseDict, delegateAction: delegateAction, returnResponse: &returnResponse)
                            DispatchQueue.main.async(execute: {
                                self.delegate?.googleNetworking(self, didFinishWithResponse: returnResponse, delegateAction: delegateAction)
                            })
                        } else {
                            print("Networking error: \(returnResponse.googleStatusCode)")
                            DispatchQueue.main.async(execute: {
                                self.delegate?.googleNetworking(self, didFinishWithResponse: returnResponse, delegateAction: .presentNetworkingError)
                            })
                        }
                    } else { print("Unable to create NSDictionary from response data") }
                }catch {
                    print("Unable to serialize JSON object from data")
                }
            }
        }) 
        datatask.resume()
    }
    
    fileprivate func statusCode(fromString codeString:String?) -> SPGoogleStatusCodes {
        for code in SPGoogleStatusCodes.allValues {
            if code.rawValue == codeString {
                return code
            }
        }
        return .UNKNOWN_ERROR
    }
}

protocol SPGoogleNetworkingDelegate: class {
    func googleNetworking(_ googleNetwork:SPGoogleNetworking, didFinishWithResponse response:SPGoogleObject, delegateAction:SPNetworkingDelegateAction)
}
