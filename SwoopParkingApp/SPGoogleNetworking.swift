//
//  SPGoogleNetworking.swift
//  SwoopParkingApp
//
//  Created by Daniel Nomura on 8/29/16.
//  Copyright © 2016 Daniel Nomura. All rights reserved.
//

import Foundation

struct SPGoogleResponse {
    var googleAPIResponse: SPGoogleAPIResponse?
    var googleStatusCode: SPGoogleStatusCodes?
    var delegateAction: SPNetworkingDelegateAction?
    var error: NSError?
}
struct SPGoogleAPIResponse{
    var addressResults: [SPGoogleAddressResult]?
    var placeIDCoordinate: CLLocationCoordinate2D?
}
struct SPGoogleAddressResult{
    var address:String
    var placeID:String
    var coordinate:CLLocationCoordinate2D?
}


enum SPNetworkingDelegateAction {
    case presentCoordinate
    case presentAutocompleteResults
    case presentAddress
    case presentNetworkingError
    case presentLocalError
}

enum SPGoogleStatusCodes:String {
    case OK, ZERO_RESULTS, OVER_QUERY_LIMIT, INVALID_REQUEST, UNKNOWN_ERROR, NOT_FOUND, REQUEST_DENIED
    static let allValues = [OK, ZERO_RESULTS, OVER_QUERY_LIMIT, INVALID_REQUEST, UNKNOWN_ERROR, NOT_FOUND, REQUEST_DENIED]
}


class SPGoogleNetworking {
    let googlePlacesAPIKey = "AIzaSyCHTQ_3E4We3iwfp8miz15Nm6Un6oYBCmk"
    let googleGeocodingAPIKey = "AIzaSyA1mzaCuwm88uF1LSlkHvxzwQoTMm-ZptY"
    var centerLat: Double { return 40.7054094949 }
    var centerLong: Double { return -73.977564233 }
    var searchRadius: Double { return 42280 }
    

    
    weak var delegate: SPGoogleNetworkingDelegate?

    func autocomplete(inputText:String) {
        let urlString = "https://maps.googleapis.com/maps/api/place/autocomplete/json?input=\(inputText)&location=\(centerLat),\(centerLong)&radius=\(searchRadius)&key=\(googlePlacesAPIKey)"
        startURLGetSession(withURLString: urlString, delegateAction: .presentAutocompleteResults)
    }
    
    func geocode(addressResultWithoutCoordinate addressResult:SPGoogleAddressResult) {
        let queryString = "https://maps.googleapis.com/maps/api/place/details/json?placeid=\(addressResult.placeID)&key=\(googlePlacesAPIKey)"
        startURLGetSession(withURLString: queryString, delegateAction: .presentCoordinate)
    }
    
    func searchAddress(address:String) {
        let queryString = "https://maps.googleapis.com/maps/api/geocode/json?address=\(address)&bounds=\(minNYCCoordinate.latitude),\(minNYCCoordinate.longitude)|\(maxNYCCoordinate.latitude),\(maxNYCCoordinate.longitude)&key=\(googleGeocodingAPIKey)"
        startURLGetSession(withURLString: queryString, delegateAction: .presentAddress)
    }

    
    private func startURLGetSession(withURLString urlString:String, delegateAction:SPNetworkingDelegateAction) {
        guard let encodedURLString = urlString.stringByAddingPercentEncodingWithAllowedCharacters(NSCharacterSet.URLQueryAllowedCharacterSet()) else {
            print("Unable to make encoded URL string from \(urlString)")
            return
        }
        guard let url = NSURL.init(string: encodedURLString) else {
            print("Unable to make NSURL object from string: \(encodedURLString)")
            return
        }
        let request = NSURLRequest.init(URL: url)
        let session = NSURLSession.sharedSession()
        let datatask = session.dataTaskWithRequest(request) { (data, response, error) in
            if error != nil { print("Error with google API request: \(error!.localizedDescription)\n\(error!.userInfo)") }
            else if data != nil {
                do {
                    if let responseDict: NSDictionary = try NSJSONSerialization.JSONObjectWithData(data!, options:NSJSONReadingOptions.AllowFragments) as? NSDictionary {
                        var returnResponse = SPGoogleResponse()
                        let statusCodeString = responseDict["status"] as? String
                        returnResponse.googleStatusCode = self.statusCode(fromString: statusCodeString)
                        if returnResponse.googleStatusCode == SPGoogleStatusCodes.OK {
                            SPParser().parseGoogleAPIResponse(responseDict, delegateAction: delegateAction, returnResponse: &returnResponse)
                            dispatch_async(dispatch_get_main_queue(), {
                                self.delegate?.googleNetworking(self, didFinishWithResponse: returnResponse, delegateAction: delegateAction)
                            })
                        } else {
                            print("Networking error: \(returnResponse.googleStatusCode)")
                            dispatch_async(dispatch_get_main_queue(), {
                                self.delegate?.googleNetworking(self, didFinishWithResponse: returnResponse, delegateAction: .presentNetworkingError)
                            })
                        }
                    } else { print("Unable to create NSDictionary from response data") }
                }catch {
                    print("Unable to serialize JSON object from data")
                }
            }
        }
        datatask.resume()
    }
    
    private func statusCode(fromString codeString:String?) -> SPGoogleStatusCodes {
        for code in SPGoogleStatusCodes.allValues {
            if code.rawValue == codeString {
                return code
            }
        }
        return .UNKNOWN_ERROR
    }
}

protocol SPGoogleNetworkingDelegate: class {
    func googleNetworking(googleNetwork:SPGoogleNetworking, didFinishWithResponse response:SPGoogleResponse, delegateAction:SPNetworkingDelegateAction)
}