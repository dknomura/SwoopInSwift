//
//  SPProtocols.swift
//  SwoopParkingApp
//
//  Created by Daniel Nomura on 9/22/16.
//  Copyright © 2016 Daniel Nomura. All rights reserved.
//

import Foundation


protocol SPInjectable {
    associatedtype T
    func inject(_: T)
    func assertDependencies()
}