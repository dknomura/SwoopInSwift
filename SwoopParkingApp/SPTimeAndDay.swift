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
    func isValidStreetCleaningTime() -> Bool {
        switch (day.rawValue, time.hour, time.min) {
        case (let day, let hour, _) where day == 7 && (hour >= 6 && hour <= 9): return true
        case (let day, let hour, _) where hour == 19 && (day == 3 || day == 6): return true
        case (_, let hour, _) where hour <= 14 && hour >= 3 : return true
        case (_, _, let min) where min == 0 || min == 30: return true
        default:
            return false
        }
//        if day.rawValue == 7 && (time.hour >= 6 && time.hour <= 9) { return true }
//        if time.hour == 19 && (day.rawValue == 3 || day.rawValue == 6) { return true }
//        if time.hour > 14 || time.hour < 3 { return false }
//        if time.min != 0 || time.min != 30 { return false }
//        return true
    }
    
    private func earliestAndLatestCleaningHour(day: DNDay) -> (earliest:Int, latest:Int) {
        var latestCleaningHour = 14
        var earliestCleaningHour = 3
        switch day {
        case .Sun:
            latestCleaningHour = 9
            earliestCleaningHour = 6
        case .Tues, .Fri:
            latestCleaningHour = 19
        case .Sat:
            latestCleaningHour = 13
        default:
            break
        }
        return (earliestCleaningHour, latestCleaningHour)
    }
    
    func nextStreetCleaningTimeAndDay() -> DNTimeAndDay {
        var returnTimeAndDay = self
        var cleaningHour = earliestAndLatestCleaningHour(returnTimeAndDay.day)
        returnTimeAndDay.dayInterval = 1
        returnTimeAndDay.minuteInterval = 30
        
        if returnTimeAndDay.time.hour >= cleaningHour.latest {
            returnTimeAndDay.increaseDay()
            cleaningHour = earliestAndLatestCleaningHour(returnTimeAndDay.day)
            returnTimeAndDay.time.hour = cleaningHour.earliest
        } else if returnTimeAndDay.time.hour < cleaningHour.earliest {
            returnTimeAndDay.time.hour = cleaningHour.earliest
        } else {
            returnTimeAndDay.increaseTime()
        }        
        return returnTimeAndDay
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
            returnTimeAndDay.day.decrease(by:1)
            if returnTimeAndDay.day.rawValue == 7 {
                returnTimeAndDay.time.hour = 13
                returnTimeAndDay.time.min = 0
            } else {
                returnTimeAndDay.time.hour = 19
                returnTimeAndDay.time.min = 0
            }
        }
        if returnTimeAndDay.day.rawValue == 1 {
            returnTimeAndDay.day.decrease(by: 1)
            returnTimeAndDay.time.hour = 13
            returnTimeAndDay.time.min = 0
        }
        return DNTimeAndDay.init(day: returnTimeAndDay.day, time: returnTimeAndDay.time)
    }
    
    func stringTupleForSQLQuery() -> (time: String, day: String) {
        var returnTuple: (time: String, day:String)
        let timeAndDayFormat = DNTimeAndDayFormat(time: .format12Hour, day: .abbr)
        returnTuple.day = day.stringValue(forFormat: timeAndDayFormat).uppercaseString
        returnTuple.time = time.stringValue(forFormat: timeAndDayFormat).uppercaseString
        if let removeRange = returnTuple.time.rangeOfString(":00") {
            returnTuple.time.removeRange(removeRange)
        }
        return returnTuple
    }
}

