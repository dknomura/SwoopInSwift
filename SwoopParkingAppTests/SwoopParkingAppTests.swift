//
//  SwoopParkingAppTests.swift
//  SwoopParkingAppTests
//
//  Created by Daniel Nomura on 5/4/16.
//  Copyright © 2016 Daniel Nomura. All rights reserved.
//

import Quick
import Nimble
@testable import SwoopParkingApp

class SwoopParkingAppTests: QuickSpec {
    override func spec() {
        let time = DNTime(hour: 6, min: 30)
        let day = DNDay.Mon
        var timeAndDay = DNTimeAndDay.init(time:time, day: day)
        describe("day value ") {
            it("gives the double value of the day/time", closure: {
                expect(timeAndDay.dayValue).to(equal())
            })
        }
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func testExample() {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct results.
    }
    
    func testPerformanceExample() {
        // This is an example of a performance test case.
        self.measureBlock {
            // Put the code you want to measure the time of here.
        }
    }
    
}
