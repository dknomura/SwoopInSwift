//
//  SPQuickGCD.swift
//  SwoopParkingApp
//
//  Created by Daniel Nomura on 5/17/16.
//  Copyright © 2016 Daniel Nomura. All rights reserved.
//

import Foundation

var GlobalMainQueue: dispatch_queue_t {
    return dispatch_get_main_queue()
}

var GlobalUserInteractiveQueue : dispatch_queue_t {
    return dispatch_get_global_queue(QOS_CLASS_USER_INTERACTIVE, 0)
}

var GlobalUserInitiatedQueue: dispatch_queue_t {
    return dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0)
}

var GlobalUtilityQueue: dispatch_queue_t {
    return dispatch_get_global_queue(QOS_CLASS_UTILITY, 0)
}

var GlobalBackgroundQueue: dispatch_queue_t {
    return dispatch_get_global_queue(QOS_CLASS_BACKGROUND, 0)
}

let concurrentSignAndLocationQueue = dispatch_queue_create("com.dnom.SwoopParking.signAndLocationQueue", DISPATCH_QUEUE_CONCURRENT)