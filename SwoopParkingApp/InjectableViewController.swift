//
//  InjectableViewController.swift
//  SwoopParkingApp
//
//  Created by Daniel Nomura on 11/12/16.
//  Copyright © 2016 Daniel Nomura. All rights reserved.
//

import Foundation

protocol InjectableViewController {
    func inject(dao: SPDataAccessObject, delegate: Any)
    func assertDependencies()
}

extension InjectableViewController where Self: UIViewController {}
