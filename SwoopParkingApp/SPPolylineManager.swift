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

struct SPPolylineManager {
    
    enum PolylineError: ErrorType {
        case notEnoughPoints
        case unableToRotate(geographicalBearing: Double) //Bearing must be between pi and -pi.
        case noPath(forPolyline:GMSPolyline)
        case invalidSideOfStreet // side of street must be N/S/E/W or North/South/East/West, case insensitive
        case unknownErrorPolylineDisplacement
    }
    
    
    
    func polylines(forCurrentLocations currentLocations: [SPLocation], zoom: Double) -> [GMSPolyline] {
        
        let date = NSDate()
        
        var returnArray = [GMSPolyline]()
        
        //Meters to separate the two sides of the road
        let displacementDistanceInMeters = metersToDisplace(byPoints: 1.8, zoom: zoom)
        
        
        for location in currentLocations {
            guard let fromCoordinate = location.fromCoordinate,
                let toCoordinate = location.toCoordinate else {
                    print("No coordinates for location \(location.locationNumber)")
                    continue
            }
            
            let fromLocation = CLLocation(latitude: fromCoordinate.latitude, longitude: fromCoordinate.longitude)
            let toLocation = CLLocation(latitude: toCoordinate.latitude, longitude: toCoordinate.longitude)
            let distanceInMetersCL = fromLocation.distanceFromLocation(toLocation)
            
            
            guard let signs = location.signs else {
                print("No signs for location \(location.locationNumber)")
                continue
            }
            
            var previousCoordinate = fromCoordinate
            
            for i in 0 ..< signs.count {
                let sign = signs[i]
                
                //Most location's first sign is "Curb line" that is at position 0 ft
                if sign.positionInFeet == 0 {
                    continue
                }
                
                let path = GMSMutablePath()
                
                guard let positionInMeters = distanceInMeters(fromFeet: sign.positionInFeet) else {
                    print("Not enough sign information to draw polyline for sign#\(sign.signIndex) at location #\(location.locationNumber)")
                    continue
                }
                
                let metersDownPath: Double
                
                // The position in feet from the database is a few meters off, so the last sign.positionInFeet will be substituted with the calculated street distance
                if i == signs.count - 1 {
                    metersDownPath = distanceInMetersCL
                } else {
                    metersDownPath = positionInMeters
                }
                let pathCoordinate1 = coordinateOnLine(fromCoordinate, toCoordinate: toCoordinate, positionInMeters: metersDownPath)
                path.addCoordinate(pathCoordinate1)
                let pathCoordinate2 = previousCoordinate
                
                previousCoordinate = pathCoordinate1
                
                path.addCoordinate(pathCoordinate2)
                var polyline = GMSPolyline(path: path)
                do {
                    if let sideOfStreet = location.sideOfStreet {
                        polyline = try displacedPolyline(originalPolyline: polyline, xMeters: displacementDistanceInMeters, sideOfStreet: sideOfStreet)
                    }
                } catch PolylineError.notEnoughPoints {
                    print("Not enough points on path to make a line")
                    continue
                } catch PolylineError.unableToRotate {
                    //                    print("Unable to rotate geographical bearing for sign \(sign.signIndex) at location \(location.locationNumber). \nLocation streets \(location.street) from: \(location.fromCrossStreet) to: \(location.toCrossStreet). \nLocation Coordinates from: \(location.fromCoordinate) to:\(location.toCoordinate). \nBearing is not between pi and -pi")
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
                polyline.strokeColor = self.polylineColor(sign)
                polyline.strokeWidth = 2.5
                
                returnArray.append(polyline)
            }
        }
        
        //        var total = 0.0
        //        for percent in percentChanges {
        //            total += percent
        //        }
        //        print("Avereage percent change: \(total / Double(percentChanges.count))")
        print("Time to initialize polylines: \(date.timeIntervalSinceNow)")
        return returnArray
    }
    
    // MARK: - Methods to find coordinates on path
    private func coordinateOnLine(fromCoordinate: CLLocationCoordinate2D, toCoordinate: CLLocationCoordinate2D, positionInMeters: Double) ->CLLocationCoordinate2D {
        let totalDistance = distanceInMeters(fromCoordinate: fromCoordinate, toCoordinate: toCoordinate)
        
        //         For some reason, some of the signs.positionInFeet are longer than the street, so the lines extend beyond the street intersection, so return the intersection coordinate if positionInFeet > totalDistance
        if positionInMeters > totalDistance {
            //            print("positionInFeet is longer than total distance. Returned toCoordinate")
            return toCoordinate
        }
        
        
        let latitude = fromCoordinate.latitude + (toCoordinate.latitude - fromCoordinate.latitude) * (positionInMeters / totalDistance)
        let longitude = fromCoordinate.longitude + (toCoordinate.longitude - fromCoordinate.longitude) * (positionInMeters / totalDistance)
        return CLLocationCoordinate2DMake(latitude, longitude)
    }
    
    private func distanceInMeters(fromFeet feet: Double?) -> Double? {
        if feet != nil {
            return feet! / 3.28084
        } else {
            return nil
        }
    }
    
    private func distancesInFeet(fromMeters meters: Double) -> Double {
        return meters * 3.28084
    }
    
    private func distanceInMeters(fromCoordinate fromCoordinate:CLLocationCoordinate2D, toCoordinate:CLLocationCoordinate2D) -> Double {
        let fromLocation = CLLocation.init(latitude: fromCoordinate.latitude, longitude: fromCoordinate.longitude)
        let toLocation = CLLocation.init(latitude: toCoordinate.latitude, longitude: toCoordinate.longitude)
        return fromLocation.distanceFromLocation(toLocation)
    }
    
    
    
    //MARK: - Polyline displacement
    
    
    // For multiple polylines will return displaced polylines
    func displace(polylines polylines: [GMSPolyline], xMeters meters:Double, sideOfStreet:String) -> [GMSPolyline] {
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
        
        if let offset = try displacementCoordinate(fromPath: path, xMeters: meters, sideOfStreet:sideOfStreet) {
            path = path.pathOffsetByLatitude(offset.latitude, longitude: offset.longitude)
        }
        
        let polyline = GMSPolyline(path: path)
        polyline.strokeColor = UIColor.greenColor()
        polyline.strokeWidth = 2
        
        return polyline
    }
    
    private func displacementCoordinate(fromPath path:GMSPath, xMeters meters:Double, sideOfStreet:String) throws -> CLLocationCoordinate2D? {
        // http://www.movable-type.co.uk/scripts/latlong.html
        // first find the bearing
        // θ = atan2( sin Δλ ⋅ cos φ2 , cos φ1 ⋅ sin φ2 − sin φ1 ⋅ cos φ2 ⋅ cos Δλ )
        if path.count() < 2 {
            throw PolylineError.notEnoughPoints
        }
        
        let fromCoordinate = path.coordinateAtIndex(0)
        let long1 = degreesToRadians(fromCoordinate.longitude)
        let lat1 = degreesToRadians(fromCoordinate.latitude)
        let toCoordinate = path.coordinateAtIndex(path.count() - 1)
        let long2 = degreesToRadians(toCoordinate.longitude)
        let lat2 = degreesToRadians(toCoordinate.latitude)
        
        //	φ2 = asin( sin φ1 ⋅ cos δ + cos φ1 ⋅ sin δ ⋅ cos θ )
        //  λ2 = λ1 + atan2( sin θ ⋅ sin δ ⋅ cos φ1, cos δ − sin φ1 ⋅ sin φ2 )
        
        // Above formula to find bearing breaks down to
        //    var y = Math.sin(λ2-λ1) * Math.cos(φ2);
        //    var x = Math.cos(φ1)*Math.sin(φ2) -
        //            Math.sin(φ1)*Math.cos(φ2)*Math.cos(λ2-λ1);
        //    var brng = Math.atan2(y, x).toDegrees();
        
        let y = sin(long2 - long1) * cos(lat2)
        let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(long2 - long1)
        var bearing = atan2(y, x)
        
        let side = try normalize(sideOfStreet: sideOfStreet)
        //MARK: Bearing calculation
        switch true {
            // "switch true"; if the case statements are true
            
        case (bearing > 0 && bearing < M_PI_2) || bearing == M_PI_2:
            switch side {
            case "N", "W":
                bearing -= M_PI_2
            case "S", "E":
                bearing += M_PI_2
            default: break
            }
        case (bearing < 0 && bearing > -M_PI_2) || bearing == 0:
            switch side {
            case "N", "E":
                bearing += M_PI_2
            case "S", "W":
                bearing -= M_PI_2
            default: break
            }
        case (bearing > M_PI_2 && bearing < M_PI) || bearing == M_PI, bearing == -M_PI:
            switch side {
            case "N", "E":
                bearing -= M_PI_2
            case "S", "W":
                bearing += M_PI_2
            default: break
            }
        case (bearing < -M_PI_2 && bearing > -M_PI || bearing == -M_PI_2):
            switch side {
            case "N", "W":
                bearing += M_PI_2
            case "S", "E":
                bearing -= M_PI_2
            default: break
            }
            //        case (bearing.isNaN):
            //            let slope = (fromCoordinate.latitude - toCoordinate.latitude) / (fromCoordinate.longitude - toCoordinate.longitude)
            
            
        default: throw PolylineError.unableToRotate(geographicalBearing: bearing)
        }
        
        // Then you can find the displacement of the path
        //        var φ2 = Math.asin( Math.sin(φ1)*Math.cos(d/R) +
        //          Math.cos(φ1)*Math.sin(d/R)*Math.cos(brng) );
        //        var λ2 = λ1 + Math.atan2(Math.sin(brng)*Math.sin(d/R)*
        //          Math.cos(φ1), Math.cos(d/R)-Math.sin(φ1)*Math.sin(φ2));
        //
        // Angular distance = distance / radius of earth
        let angularDistance = meters / 6371000
        let newLat = asin(sin(lat1) * cos(angularDistance) + cos(lat1) * sin(angularDistance) * cos(bearing))
        let newLong = long1 + atan2(sin(bearing) * sin(angularDistance) * cos(lat1), cos(angularDistance) - sin(lat1) * sin(newLat))
        
        //        let fromLocation = CLLocation(latitude: fromCoordinate.latitude, longitude: fromCoordinate.longitude)
        //        let toLocation = CLLocation(latitude:radiansToDegrees(newLat), longitude:radiansToDegrees(newLong))
        //        let distance = fromLocation.distanceFromLocation(toLocation)
        //        print("distance is: \(distance), margin of error: \((distance - meters) / meters)")
        
        
        return CLLocationCoordinate2DMake(radiansToDegrees(newLat) - fromCoordinate.latitude, radiansToDegrees(newLong) - fromCoordinate.longitude)
    }
    
    private func degreesToRadians(degrees:Double) -> Double {
        return degrees * M_PI  / 180
    }
    
    private func radiansToDegrees(radians:Double) -> Double {
        return radians * 180 / M_PI
    }
    
    private func normalize(sideOfStreet sideOfStreet:String) throws -> String {
        let sideString = sideOfStreet.lowercaseString
        
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
    
    
    
    func initialZoom(forViewWidth viewWidth: Double) -> Float {
        // Using the logic above to find zoom, local points / world width point = local meters / world width meters
        // world width points = local points * world width meters / local meters
        // 2 ^ N = world width points / 256
        // N = log2(world width points / 256)
        // local points = map width, local meters = 27425.3366774176
        let localPoints = viewWidth
        let localMeters = 36000.0
        let worldMeters = 40075000.0
        let worldPoints = localPoints * worldMeters / localMeters
        let zoom = log2(worldPoints / 256.0)
        return Float(zoom)
    }
    
    
    // MARK: - Polyline Color
    
    private func polylineColor(fromSign:SPSign) -> UIColor {
        if fromSign.signContent?.rangeOfString("SANITATION BROOM") != nil {
            return UIColor.greenColor()
        }
        return UIColor.redColor()
    }
}
