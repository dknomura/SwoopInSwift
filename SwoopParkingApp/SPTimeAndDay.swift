//
//  SPTimeAndDayManager.swift
//  SwoopParkingApp
//
//  Created by Daniel Nomura on 8/11/16.
//  Copyright © 2016 Daniel Nomura. All rights reserved.
//

import Foundation
import DNTimeAndDay

extension DNTimeAndDay {
    func nextStreetCleaningTimeAndDay() -> DNTimeAndDay {
        var returnTimeAndDay = self
        if returnTimeAndDay.time.hour < 15 && returnTimeAndDay.time.hour > 2 {
            if returnTimeAndDay.time.hour == 14 && returnTimeAndDay.time.min == 30 {
                returnTimeAndDay.time.hour = 19
                returnTimeAndDay.time.min = 0
            }
        } else if returnTimeAndDay.time.hour < 19 {
            returnTimeAndDay.time.hour = 19
            returnTimeAndDay.time.min = 0
        } else if returnTimeAndDay.time.hour == 19 && returnTimeAndDay.time.min == 0 {
        } else {
            returnTimeAndDay.time.hour = 3
            returnTimeAndDay.time.min = 0
            returnTimeAndDay.day.increase(days: 1)
        }
        if returnTimeAndDay.day.rawValue == 1 {
            returnTimeAndDay.day.increase(days: 1)
        }
        return DNTimeAndDay.init(day: returnTimeAndDay.day, time: returnTimeAndDay.time)
    }
    
    func previousStreetCleaningTimeAndDay() -> DNTimeAndDay {
        var returnTimeAndDay = self
        if returnTimeAndDay.time.hour > 19 && (returnTimeAndDay.day.rawValue != 1 || returnTimeAndDay.day.rawValue != 7) {
            returnTimeAndDay.time.hour = 19
            returnTimeAndDay.time.min = 0
        } else if returnTimeAndDay.time.hour > 14 || (returnTimeAndDay.time.hour == 14 && returnTimeAndDay.time.min == 30) {
            returnTimeAndDay.time.hour = 14
            returnTimeAndDay.time.min = 0
        } else if returnTimeAndDay.time.hour < 3 {
            returnTimeAndDay.day.decrease(days:1)
            if returnTimeAndDay.day.rawValue == 7 {
                returnTimeAndDay.time.hour = 13
                returnTimeAndDay.time.min = 0
            } else {
                returnTimeAndDay.time.hour = 19
                returnTimeAndDay.time.min = 0
            }
        }
        if returnTimeAndDay.day.rawValue == 1 {
            returnTimeAndDay.day.decrease(days: 1)
            returnTimeAndDay.time.hour = 13
            returnTimeAndDay.time.min = 0
        }
        return DNTimeAndDay.init(day: returnTimeAndDay.day, time: returnTimeAndDay.time)
    }
}

