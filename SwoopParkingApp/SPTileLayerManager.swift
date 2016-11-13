//
//  SPPolygonManager.swift
//  SwoopParkingApp
//
//  Created by Daniel Nomura on 8/3/16.
//  Copyright © 2016 Daniel Nomura. All rights reserved.
//

import Foundation
import GoogleMaps
import UIKit

class SPTileLayerManager: GMSTileLayer {
    
    
    
    //    let maxNYCCoordinate = CLLocationCoordinate2DMake(40.91295931663856, -73.70059684703173)
    //    let minNYCCoordinate = CLLocationCoordinate2DMake(40.49785967315467, -74.25453161899142)
    //     dLat = 0.41509964348, dLong = 0.55393477196

    //https://developers.google.com/maps/documentation/ios-sdk/tiles
    // n x n, tiles for world. where n = 2 ^ zoom 
    // 2 ^ 10.6233 = 1577.36410238, 1577.36410238 x 1577.36410238. 360/1577.36410238 = 0.22822885309 degrees x 0.087890625 degrees
    override func requestTileFor(x: UInt, y: UInt, zoom: UInt, receiver: GMSTileReceiver) {
        
    }
}
