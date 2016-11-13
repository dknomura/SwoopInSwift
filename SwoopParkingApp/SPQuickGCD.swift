//
//  SPQuickGCD.swift
//  SwoopParkingApp
//
//  Created by Daniel Nomura on 5/17/16.
//  Copyright © 2016 Daniel Nomura. All rights reserved.
//

import Foundation

var GlobalMainQueue: DispatchQueue {
    return DispatchQueue.main
}

var GlobalUserInteractiveQueue : DispatchQueue {
    return DispatchQueue.global(qos: DispatchQoS.QoSClass.userInteractive)
}

var GlobalUserInitiatedQueue: DispatchQueue {
    return DispatchQueue.global(qos: DispatchQoS.QoSClass.userInitiated)
}

var GlobalUtilityQueue: DispatchQueue {
    return DispatchQueue.global(qos: DispatchQoS.QoSClass.utility)
}

var GlobalBackgroundQueue: DispatchQueue {
    return DispatchQueue.global(qos: DispatchQoS.QoSClass.background)
}

let concurrentSignDictionaryQueue = DispatchQueue(label: "com.dnom.SwoopParking.daoSignAndCoordinateStringDictionary", attributes: DispatchQueue.Attributes.concurrent)
