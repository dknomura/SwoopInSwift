//
//  SPTimeAndDayManager.swift
//  SwoopParkingApp
//
//  Created by Daniel Nomura on 8/11/16.
//  Copyright © 2016 Daniel Nomura. All rights reserved.
//

import Foundation
import DNTimeAndDay

extension DNTime: DNComparableTimeUnit {
    public init?(rawValue: Double) {
        let hour = Int(rawValue)
        let min = Int((rawValue - Double(hour)) * 60)
        if hour >= 0 && hour < 24 && min >= 0 && min < 60 {
            self.init(hour:hour, min:min)
        } else {
            return nil
        }
    }
    public var rawValue: Double {
        var hour = Double(self.hour)
        var min = Double(self.min)
        min = min / 60
        if min > 0 && hour == 24 {
            hour = 0
        }
        return hour + min
    }
}

extension DNTimeAndDay: DNComparableTimeUnit {
    //MARK: Comparable time unit protocol
    public init?(rawValue: Double) {
        let dayValue = Int(rawValue)
        let timeValue = (rawValue - Double(dayValue)) * 24
        if let day = DNDay.init(rawValue: dayValue),
            time = DNTime.init(rawValue: timeValue) {
            self.init(day: day, time: time)
        } else {
            return nil
        }
    }
    public var rawValue: Double {
        var day = Double(self.day.rawValue)
        var time = timeValue
        time /= 24
        if time > 0 && day == 7 {
            day = 0
        }
        return day + time
    }
    
    var timeValue: Double {
        return self.time.rawValue
    }

    //MARK: Aligning timeAndDay with street cleaning parameters/restrictions
    func isValidStreetCleaningTime() -> Bool {
        switch (day.rawValue, time.hour, time.min) {
        case (_, _, let min) where min != 0 || min != 30: return false
        case (let day, let hour, _) where day == 7 && (hour >= 6 && hour <= 9): return true
        case (let day, let hour, let min) where hour == 19 && min == 0 && (day == 3 || day == 6): return true
        case (_, let hour, _) where hour <= 14 && hour >= 3 : return true
        default:
            return false
        }
    }
    mutating func adjustTimeToValidStreetCleaningTime() -> Bool {
        let cleaningHour = day.earliestAndLatestCleaningTime
        var didChangeTime = true
        if time >= cleaningHour.latest {
            time = cleaningHour.latest
        } else if time <= cleaningHour.earliest {
            time = cleaningHour.earliest
        } else {
            didChangeTime = false
        }
        return didChangeTime
    }
    func isInGapTime() -> Bool {
        if (day == .Tues || day == .Fri) && (timeValue > 14 && timeValue < 19) {
            return true
        } else {
            return false
        }        
    }
    static var gapTime: String {
        return "Tues and Fri from 2:30PM to 7:30PM"
    }
    
    // MARK: timeAndDay for SQL
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
    func stringForSQLTagQuery() -> String {
        return "\(stringTupleForSQLQuery().time)\(stringTupleForSQLQuery().day)"
    }
}

extension DNDay {
    static var allValues: [DNDay] {
        return [Sun, Mon, Tues, Wed, Thurs, Fri, Sat]
    }
    var earliestAndLatestCleaningTime: (earliest:DNTime, latest:DNTime) {
        var latestCleaningHour = 14.0
        var earliestCleaningHour = 3.0
        switch self {
        case .Sun:
            latestCleaningHour = 9.5
            earliestCleaningHour = 6
        case .Tues, .Fri:
            latestCleaningHour = 19
        case .Sat:
            latestCleaningHour = 13
        default:
            break
        }
        return (DNTime.init(rawValue: earliestCleaningHour)!, DNTime.init(rawValue: latestCleaningHour)!)
    }

}

extension DNTimeAndDayFormat {
    static func format12Hour() -> DNTimeAndDayFormat {
        return DNTimeAndDayFormat.init(time: .format12Hour, day: .abbr)
    }
    static func format24Hour() -> DNTimeAndDayFormat {
        return DNTimeAndDayFormat.init(time: .format24Hour, day: .abbr)
    }
    static func abbrDay() -> DNTimeAndDayFormat {
        return DNTimeAndDayFormat.init(time: .format12Hour, day: .abbr)
    }
    static func fullDay() -> DNTimeAndDayFormat {
        return DNTimeAndDayFormat.init(time: .format12Hour, day: .full)
    }
}

public protocol DNComparableTimeUnit: Comparable, Equatable {
    var rawValue: Double { get }
    init?(rawValue:Double)
}
public func ==<TimeUnit:DNComparableTimeUnit>(lhs:TimeUnit, rhs:TimeUnit) -> Bool {
    return lhs.rawValue == rhs.rawValue
}
public func >=<TimeUnit:DNComparableTimeUnit>(lhs:TimeUnit, rhs:TimeUnit) -> Bool {
    return lhs.rawValue >= rhs.rawValue
}
public func <=<TimeUnit:DNComparableTimeUnit>(lhs:TimeUnit, rhs:TimeUnit) -> Bool {
    return lhs.rawValue <= rhs.rawValue
}
public func ><TimeUnit:DNComparableTimeUnit>(lhs:TimeUnit, rhs:TimeUnit) -> Bool {
    return lhs.rawValue > rhs.rawValue
}
public func <<TimeUnit:DNComparableTimeUnit>(lhs:TimeUnit, rhs:TimeUnit) -> Bool {
    return lhs.rawValue < rhs.rawValue
}

