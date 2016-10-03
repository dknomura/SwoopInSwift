//
//  TimeAndDayExtensionUnitTest.swift
//  SwoopParkingApp
//
//  Created by Daniel Nomura on 10/2/16.
//  Copyright © 2016 Daniel Nomura. All rights reserved.
//

import Foundation
import Nimble
import Quick
@testable import DNTimeAndDay

class SPTimeAndDayUnitTest: QuickSpec {
    override func spec() {
        let time = DNTime(hour: 6, min: 30)
        let day = DNDay.Mon
        var timeAndDay = DNTimeAndDay.init(time:time, day: day)
        describe("day value ") {
            it("gives the double value of the day/time", closure: {
                
            })
        }
    }
}