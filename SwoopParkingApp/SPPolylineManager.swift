//
//  SPPolyLineManager.swift
//  SwoopParkingApp
//
//  Created by Daniel Nomura on 7/11/16.
//  Copyright © 2016 Daniel Nomura. All rights reserved.
//

import Foundation
import GoogleMaps
import CoreLocation

protocol SPPolylineManagerDelegate {
    func polylineManagerDidSet(tappablePolyline polyline: GMSPolyline, withSign: SPSign)
}

struct SPPolylineManager: SPInjectable {
    var delegate: SPPolylineManagerDelegate?
    fileprivate var dao: SPDataAccessObject!
    mutating func inject(_ dao: SPDataAccessObject) {
        self.dao = dao
    }
    func assertDependencies() {
        assert(dao != nil)
    }
    
    enum PolylineError: Error {
        case notEnoughPoints
        case unableToRotate(geographicalBearing: Double) //Bearing must be between pi and -pi.
        case noPath(forPolyline:GMSPolyline)
        case invalidSideOfStreet // side of street must be N/S/E/W or North/South/East/West, case insensitive
        case unknownErrorPolylineDisplacement
    }
    
    
    //MARK: - Polyline creation
    func polylines(forCurrentLocations currentLocations: [SPLocation], zoom: Double) -> [GMSPolyline] {
        assertDependencies()
        var returnArray = [GMSPolyline]()
        //Meters to separate the two sides of the road
        let metersToDisplacePolyline = metersToDisplace(byPoints: 1.8, zoom: zoom)
        dao.signForPathCoordinates.removeAll()
        for location in currentLocations {
            guard let fromCoordinate = location.fromCoordinate,
                let toCoordinate = location.toCoordinate,
                let sideOfStreet = location.sideOfStreet,
                let signs = location.signs else { continue }
            let path = gmsPath(forCoordinate1: fromCoordinate, coordinate2: toCoordinate)
            guard let deltaCoordinates = try? latLngDifference(forPath: path, xMeters: metersToDisplacePolyline, sideOfStreet: sideOfStreet) else {
                continue
            }
            var previousCoordinate = fromCoordinate
            var i = 0
            repeat {
                let pathCoordinate1 = previousCoordinate
                var pathCoordinate2: CLLocationCoordinate2D
                let sign: SPSign?
                if signs.count != 0 {
                    sign = signs[i]
                    guard sign!.positionInFeet != nil else { continue }
                    let positionInMeters = meters(fromFeet: sign!.positionInFeet!)
                    // The position in feet from the database is a few meters off, so the last sign.positionInFeet will be substituted with the calculated street distance
                    if i == signs.count - 1 {
                        pathCoordinate2 = toCoordinate
                    } else {
                        pathCoordinate2 = coordinateOnLine(fromCoordinate, toCoordinate: toCoordinate, positionInMeters: positionInMeters)
                    }
                    previousCoordinate = pathCoordinate2
                } else {
                    sign = nil
                    pathCoordinate2 = toCoordinate
                }
                let path = gmsPath(forCoordinate1: pathCoordinate1, coordinate2: pathCoordinate2)
//                print("Path for location # \(location.locationNumber): from coordinate \(pathCoordinate1), to coordinate \(pathCoordinate2)")
                returnArray.append(setupPolyline(path, deltaCoordinates: deltaCoordinates!, forSign: sign))
                i += 1
            } while i < signs.count
        }
        return returnArray
    }
    
    // MARK: Polyline Color
    
    var greenCoordinates = [(fromCoordinate: CLLocationCoordinate2D, toCoordinate: CLLocationCoordinate2D)]()
    fileprivate func setupPolyline(_ path: GMSPath, deltaCoordinates:CLLocationCoordinate2D, forSign sign: SPSign?) -> GMSPolyline {
        let displacedPath = path.pathOffset(byLatitude: deltaCoordinates.latitude, longitude: deltaCoordinates.longitude)
        let polyline = GMSPolyline(path: displacedPath)
        if sign == nil {
            polyline.strokeColor = UIColor.red
        } else {
            assertDependencies()
            if isStreetCleaningSign(sign!.signContent!) {
//                greenCoordinates.append((path.coordinateAtIndex(0), path.coordinateAtIndex(path.count() - 1)))
                polyline.strokeColor = UIColor.green
                polyline.isTappable = true
                dao.signForPathCoordinates[SPPolylineManager.hashedString(forPolyline:polyline)] = sign
            } else {
                polyline.strokeColor = UIColor.red
            }
        }
        polyline.strokeWidth = 2.5
        return polyline
    }
    enum SPSignTypes:String {
        case streetCleaning, meteredParking
        var identifier:String {
            switch self {
            case .streetCleaning: return "BROOM"
            case .meteredParking: return "HOUR"
            }
        }
    }
    
    fileprivate func isStreetCleaningSign(_ signContent: String) -> Bool {
        if signContent.range(of: SPSignTypes.meteredParking.identifier) != nil { return false }
        
        let stringTuple = dao.primaryTimeAndDay.stringTupleForSQLQuery
        guard let endOfStreetCleaning = endTime(ofSign: signContent) else { return false }
        if endOfStreetCleaning.range(of: stringTuple.time) != nil && signContent.range(of: stringTuple.day) != nil {
            return true
        }
        return false
    }
    
    fileprivate func endTime(ofSign signContent: String) -> String? {
        let rangeOfTimeSeparator: Range<String.Index>
        if let toRange = signContent.range(of: "TO") {
            rangeOfTimeSeparator = toRange
        } else if let dashRange = signContent.range(of: "-") {
            rangeOfTimeSeparator = dashRange
        } else {
            return nil
        }
        let afterTo = signContent.substring(from: rangeOfTimeSeparator.upperBound)
        var timeString: String? = nil
        if let startOfEndTime = afterTo.rangeOfCharacter(from: CharacterSet.decimalDigits),
            let endOfEndTime = afterTo.range(of: "M") {
            guard startOfEndTime.lowerBound < endOfEndTime.lowerBound else { return nil }
            guard afterTo.distance(from: startOfEndTime.lowerBound, to: endOfEndTime.upperBound) < 10 else { return nil }
            timeString = afterTo.substring(with: Range(uncheckedBounds: (lower: startOfEndTime.lowerBound, upper: endOfEndTime.upperBound)))
        }
        return timeString
    }
    
    static func hashedString(forPolyline polyline: GMSPolyline) -> String {
        guard let path = polyline.path else { return "" }
        return hashedString(forPath: path)
    }
    static func hashedString(forPath path:GMSPath) -> String {
        var latValue: Double = 0
        var longValue: Double = 0
        for i in 0..<path.count() {
            let coordinate = path.coordinate(at: i)
            latValue += coordinate.latitude
            longValue += coordinate.longitude
        }
        latValue /= Double(path.count())
        longValue /= Double(path.count())
        return "\(latValue) \(longValue)"
    }
    static func coordinate(fromHashedString hashString: String) -> CLLocationCoordinate2D? {
        let coordinateStrings = hashString.characters.split{  $0 == " " }.map(String.init)
        if let lat = Double(coordinateStrings[0]),
            let long = Double(coordinateStrings[1]){
            return CLLocationCoordinate2D.init(latitude: lat, longitude: long)
        }
        return nil
    }
    static func coordinate(fromPolyline polyline: GMSPolyline) -> CLLocationCoordinate2D? {
        let hashString = hashedString(forPolyline: polyline)
        return coordinate(fromHashedString: hashString)
    }
    
    
    fileprivate func gmsPath(forCoordinate1 coordinate1: CLLocationCoordinate2D, coordinate2: CLLocationCoordinate2D) -> GMSMutablePath {
        let path = GMSMutablePath()
        path.add(coordinate1)
        path.add(coordinate2)
        return path
    }
    
    // MARK: Methods to find coordinates on path
    fileprivate func coordinateOnLine(_ fromCoordinate: CLLocationCoordinate2D, toCoordinate: CLLocationCoordinate2D, positionInMeters: Double) ->CLLocationCoordinate2D {
        let totalDistance = distanceInMetersBetween(coordinate1: fromCoordinate, coordinate2: toCoordinate)
        
        //  For some reason, some of the signs.positionInFeet are longer than the street, so the lines extend beyond the street intersection, so return the intersection coordinate if positionInFeet > totalDistance
        if positionInMeters > totalDistance {
            return toCoordinate
        }
        let latitude = fromCoordinate.latitude + (toCoordinate.latitude - fromCoordinate.latitude) * (positionInMeters / totalDistance)
        let longitude = fromCoordinate.longitude + (toCoordinate.longitude - fromCoordinate.longitude) * (positionInMeters / totalDistance)
        return CLLocationCoordinate2DMake(latitude, longitude)
    }
    
    fileprivate func meters(fromFeet feet: Double) -> Double {
        return feet / 3.28084
    }
    
    fileprivate func feet(fromMeters meters: Double) -> Double {
        return meters * 3.28084
    }
    
    fileprivate func distanceInMetersBetween(coordinate1:CLLocationCoordinate2D, coordinate2:CLLocationCoordinate2D) -> Double {
        let fromLocation = CLLocation.init(latitude: coordinate1.latitude, longitude: coordinate1.longitude)
        let toLocation = CLLocation.init(latitude: coordinate2.latitude, longitude: coordinate2.longitude)
        return fromLocation.distance(from: toLocation)
    }
    
    
    
    //MARK: - Polyline displacement
    
    
    // For multiple polylines will return displaced polylines
    func displace(polylines: [GMSPolyline], xMeters meters:Double, sideOfStreet:String) -> [GMSPolyline] {
        var returnArray = [GMSPolyline]()
        
        for polyline in polylines {
            do {
                returnArray.append(try displacedPolyline(originalPolyline: polyline, xMeters: meters, sideOfStreet: sideOfStreet))
            } catch PolylineError.notEnoughPoints {
                print("Not enough points on path to make a line")
                continue
            } catch PolylineError.unableToRotate(let bearing) {
                print("Unable to rotate geographical bearing \(bearing). Bearing is not between pi and -pi")
                continue
            } catch PolylineError.noPath(let polyline) {
                print("No path for polyline: \(polyline)")
                continue
            } catch PolylineError.invalidSideOfStreet {
                print("Invalid side of street, must be N/S/E/W or North/South/East/West, case insensitive")
                continue
            } catch {
                print("Unknown polyline displacement error.. Sorry!")
            }
        }
        return returnArray
    }
    
    // For displacing a single polyline
    func displacedPolyline(originalPolyline polyline:GMSPolyline, xMeters meters:Double, sideOfStreet:String) throws -> GMSPolyline {
        guard var path = polyline.path else {
            throw PolylineError.noPath(forPolyline: polyline)
        }
        
        if let offset = try latLngDifference(forPath: path, xMeters: meters, sideOfStreet:sideOfStreet) {
            path = path.pathOffset(byLatitude: offset.latitude, longitude: offset.longitude)
        }
        
        let polyline = GMSPolyline(path: path)
        return polyline
    }
    
    fileprivate func bearing(_ fromCoordinate: CLLocationCoordinate2D, toCoordinate: CLLocationCoordinate2D) -> Double {
        let long1 = degreesToRadians(fromCoordinate.longitude)
        let lat1 = degreesToRadians(fromCoordinate.latitude)
        let long2 = degreesToRadians(toCoordinate.longitude)
        let lat2 = degreesToRadians(toCoordinate.latitude)
        return bearing(lat1, long1: long1, lat2: lat2, long2: long2)
    }
    fileprivate func bearing(_ lat1: Double, long1: Double, lat2:Double, long2:Double) -> Double {
        //	φ2 = asin( sin φ1 ⋅ cos δ + cos φ1 ⋅ sin δ ⋅ cos θ )
        //  λ2 = λ1 + atan2( sin θ ⋅ sin δ ⋅ cos φ1, cos δ − sin φ1 ⋅ sin φ2 )
        
        // Above formula to find bearing breaks down to
        //    var y = Math.sin(λ2-λ1) * Math.cos(φ2);
        //    var x = Math.cos(φ1)*Math.sin(φ2) -
        //            Math.sin(φ1)*Math.cos(φ2)*Math.cos(λ2-λ1);
        //    var brng = Math.atan2(y, x).toDegrees();
        
        let y = sin(long2 - long1) * cos(lat2)
        let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(long2 - long1)
        return atan2(y, x)
    }
    
    fileprivate func latLngDifference(forPath path:GMSPath, xMeters meters:Double, sideOfStreet:String) throws -> CLLocationCoordinate2D? {
        // http://www.movable-type.co.uk/scripts/latlong.html
        // first find the bearing
        // θ = atan2( sin Δλ ⋅ cos φ2 , cos φ1 ⋅ sin φ2 − sin φ1 ⋅ cos φ2 ⋅ cos Δλ )
        if path.count() < 2 {
            throw PolylineError.notEnoughPoints
        }
        
        let fromCoordinate = path.coordinate(at: 0)
        let long1 = degreesToRadians(fromCoordinate.longitude)
        let lat1 = degreesToRadians(fromCoordinate.latitude)
        let toCoordinate = path.coordinate(at: path.count() - 1)
        let long2 = degreesToRadians(toCoordinate.longitude)
        let lat2 = degreesToRadians(toCoordinate.latitude)
        
        var bearings = bearing(lat1, long1: long1, lat2: lat2, long2: long2)
        if bearings.isNaN {
            
        }
        let side = try normalize(sideOfStreet: sideOfStreet)
        try rotate(bearing: &bearings, direction: side)
        
        // Then you can find the displaced coordinates of the path
        //        var φ2 = Math.asin( Math.sin(φ1)*Math.cos(d/R) +
        //          Math.cos(φ1)*Math.sin(d/R)*Math.cos(brng) );
        //        var λ2 = λ1 + Math.atan2(Math.sin(brng)*Math.sin(d/R)*
        //          Math.cos(φ1), Math.cos(d/R)-Math.sin(φ1)*Math.sin(φ2));
        //
        // Angular distance = distance / radius of earth
        let angularDistance = meters / 6371000
        let newLat = asin(sin(lat1) * cos(angularDistance) + cos(lat1) * sin(angularDistance) * cos(bearings))
        let newLong = long1 + atan2(sin(bearings) * sin(angularDistance) * cos(lat1), cos(angularDistance) - sin(lat1) * sin(newLat))
        
        // Uncomment to print the actual distance, and the margin of error between the actual and expected distance
        //        let fromLocation = CLLocation(latitude: fromCoordinate.latitude, longitude: fromCoordinate.longitude)
        //        let toLocation = CLLocation(latitude:radiansToDegrees(newLat), longitude:radiansToDegrees(newLong))
        //        let distance = fromLocation.distanceFromLocation(toLocation)
        //        print("distance is: \(distance), margin of error: \((distance - meters) / meters)")
        
        
        return CLLocationCoordinate2DMake(radiansToDegrees(newLat) - fromCoordinate.latitude, radiansToDegrees(newLong) - fromCoordinate.longitude)
    }
    
    fileprivate func rotate(bearing:inout Double, direction: String) throws {
        //MARK: Bearing calculation
        switch true {
            // "switch true"; if the case statements are true
        case (bearing > 0 && bearing < M_PI_2) || bearing == M_PI_2:
            switch direction {
            case "N", "W":
                bearing -= M_PI_2
            case "S", "E":
                bearing += M_PI_2
            default: break
            }
        case (bearing < 0 && bearing > -M_PI_2) || bearing == 0:
            switch direction {
            case "N", "E":
                bearing += M_PI_2
            case "S", "W":
                bearing -= M_PI_2
            default: break
            }
        case (bearing > M_PI_2 && bearing < M_PI) || bearing == M_PI, bearing == -M_PI:
            switch direction {
            case "N", "E":
                bearing -= M_PI_2
            case "S", "W":
                bearing += M_PI_2
            default: break
            }
        case (bearing < -M_PI_2 && bearing > -M_PI || bearing == -M_PI_2):
            switch direction {
            case "N", "W":
                bearing += M_PI_2
            case "S", "E":
                bearing -= M_PI_2
            default: break
            }
        default: throw PolylineError.unableToRotate(geographicalBearing: bearing)
        }
    }
    
    fileprivate func degreesToRadians(_ degrees:Double) -> Double {
        return degrees * M_PI  / 180
    }
    
    fileprivate func radiansToDegrees(_ radians:Double) -> Double {
        return radians * 180 / M_PI
    }
    
    fileprivate func normalize(sideOfStreet:String) throws -> String {
        let sideString = sideOfStreet.lowercased()
        switch sideString {
        case "n", "north":
            return "N"
        case "e", "east":
            return "E"
        case "s", "south":
            return "S"
        case "w", "west":
            return "W"
        default:
            throw PolylineError.invalidSideOfStreet
        }
    }
    
    // MARK: - Displacement and stroke width in relation to zoom
    func metersToDisplace(byPoints points:Double, zoom:Double) -> Double {
        // https://developers.google.com/maps/documentation/ios-sdk/views#zoom
        // "at zoom level N, the width of the world is approximately 256 * 2^N, i.e., at zoom level 2, the whole world is approximately 1024 points wide"
        // So taking the proportions local points / world width points = local meters / world width meters
        // local meters = local points * world width meters / world width points
        
        let worldMeters = 40075000.0
        let worldPoints = 256.0 * pow(2.0, zoom)
        let meters = points * worldMeters / worldPoints
        return meters
    }
}


