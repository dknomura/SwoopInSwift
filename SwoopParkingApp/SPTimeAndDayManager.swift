//
//  SPTimeAndDayManager.swift
//  SwoopParkingApp
//
//  Created by Daniel Nomura on 8/11/16.
//  Copyright © 2016 Daniel Nomura. All rights reserved.
//

import Foundation

enum SPTimeAndDayError : ErrorType {
    case unableToConvertDayString(fromInt:Int)
    case unableToConvertDayInt(fromString:String)
    case unableToConvertTimeInt(fromString:String)
    case noColon(inTimeString:String)
    case unableToCastInt(fromString:String)
    case invalidInput
    case invalidHourInt(hour:Int)
    case invalidMinuteInt(minute:Int)
    case noStreetParkingForDay(day:String, nextValidTime:SPTimeAndDay)
    case noStreetParkingForTimeAndDay(time:SPTimeAndDay, nextValidTime:SPTimeAndDay)
}
enum SPTimeFormat : Int {
    case format24Hour = 0
    case format12Hour
}
enum SPDay: Int{
    case Sun = 1, Mon, Tues, Wed, Thurs, Fri, Sat
    var stringValue: String {
        switch self {
        case .Sun: return "Sun"
        case .Mon: return "Mon"
        case .Tues: return "Tues"
        case .Wed: return "Wed"
        case .Thurs: return "Thurs"
        case .Fri: return "Fri"
        case .Sat: return "Sat"
        }
    }
    var allValues: [SPDay] { return [Sun, Mon, Tues, Wed, Thurs, Fri, Sat] }
    enum DayError: ErrorType {
        case invalidString(String)
    }
    func increaseDay() {
        var dayInt = self.rawValue
        if dayInt == 7 {
            dayInt = 1
        } else {
            dayInt += 1
        }
        self = SPDay.init(rawValue: dayInt)
    }
    func decreaseDay() {
        var dayInt = self.rawValue
        if dayInt == 1 {
            dayInt = 7
        } else {
            dayInt -= 1
        }
        self = SPDay.init(rawValue: dayInt)
    }
    init?(stringValue:String) {
        let lowerCase = stringValue.lowercaseString
        let rawValue: Int
        switch lowerCase {
        case "su", "sun", "sund", "sunda", "sunday", "7":
            rawValue = 1
        case "m", "mo", "mon", "mond", "monda", "monday", "1":
            rawValue = 2
        case "t", "tu", "tue", "tues", "tuesday", "2":
            rawValue = 3
        case "w", "we", "wed", "wedn", "wedne",  "wednes", "wednesday", "3":
            rawValue = 4
        case "th", "thu", "thur", "thurs", "thursday", "4":
            rawValue = 5
        case "f", "fr", "fri", "frid", "friday", "5":
            rawValue = 6
        case "s", "sa", "sat", "satu", "satur", "saturday", "6":
            rawValue = 7
        default:
            return nil
        }
        self.init(rawValue: rawValue)
    }
}

enum SPHour: Int {
    case hour0 = 0, hour1, hour2, hour3, hour4, hour5, hour6, hour7, hour8, hour9, hour10, hour11, hour12, hour13, hour14, hour15, hour16, hour17, hour18, hour19, hour20, hour21, hour22, hour23
}
struct SPTimeInt {
    var hour: Int
    var min: Int
    init?(hour: Int, min:Int) {
        if (hour >= 0 && hour < 24) && (min >= 0 && min < 60) {
            self.hour = hour
            self.min = min
        } else {
            print("Hour, \(hour), and min, \(min), are not valid, should be between 0-23 and 0-60 respectively")
            return nil
        }
    }
}
struct SPTime {
    var intValue: SPTimeInt
    var stringValue: String
    var format: SPTimeFormat
    enum SPAmPm: String{
        case am, pm
    }
}

extension SPTime {
    func increaseTime() {
        var timeInt = self.intValue
        if timeInt.min <= 30 {
            timeInt.min = 30
        } else if timeInt.min > 30 {
            timeInt.min = 0
            if timeInt.hour < 24 {
                timeInt.hour += 1
            } else {
                timeInt.hour = 0
            }
        }
        self = SPTime.init(timeInt: timeInt, format: self.format)
    }
    func decreaseTime() {
        var timeInt = self.intValue
        if timeInt.min >= 30 {
            timeInt.min = 30
        } else if timeInt.min < 30 {
            timeInt.min = 0
            if timeInt.hour > 0 {
                timeInt.hour -= 1
            } else {
                timeInt = 24
            }
        }
        self = SPTime.init(timeInt: timeInt, format: self.format)
    }

    init?(timeInt:SPTimeInt, format:SPTimeFormat) {
        let minString: String
        let hourString: String
        var hour = timeInt.hour
        var amPM = ""
        if format == SPTimeFormat.format12Hour {
            if hour == 0 {
                hour = 12
                amPM = "am"
            } else if hour < 12 {
                amPM = "am"
            } else if hour == 12 {
                amPM = "pm"
            }else if hour > 12 && hour < 24 {
                hour -= 12
                amPM = "pm"
            }
            hourString = String(hour)
        } else {
            if hour < 10 {
                hourString = "0" + String(hour)
            } else {
                hourString = String(hour)
            }
        }
        if timeInt.min < 10 {
            minString = "0" + String(timeInt.min)
        } else {
            minString = String(timeInt.min)
        }
        let timeString = hourString + ":" + minString + amPM
        self.init(intValue:timeInt, stringValue: timeString, format: format)
    }
    
    init?(userInputValue timeString:String) {
        let lowerCaseStringValue = timeString.lowercaseString
        let periodRange = lowerCaseStringValue.rangeOfString(".")
        let colonRange = lowerCaseStringValue.rangeOfString(":")
        let pRange = lowerCaseStringValue.rangeOfString("p")
        let aRange = lowerCaseStringValue.rangeOfString("a")
        var amOrPM: SPAmPm?
        var hour, min:Int?
        // If minute value exists, then there is either '.' or ':'. The minute value will be multipled by the minute scale and if '.' the minute will need to be multiplied by 0.6
        var minuteScale: Double = 1.0
        // If there is no delimiter ('.' or ':') then we will only have an hour value, which will be to the endIndex of the string
        var delimiterStartIndex = lowerCaseStringValue.endIndex
        var delimiterEndIndex = lowerCaseStringValue.endIndex
        // Similarly, if there is no 'a' or 'p', then the minute value will be to the endIndex of the string
        var apIndex = lowerCaseStringValue.endIndex
        var format: SPTimeFormat = .format12Hour
        if aRange != nil {
            apIndex = aRange!.startIndex
            amOrPM = .am
        } else if pRange != nil {
            apIndex = pRange!.startIndex
            amOrPM = .pm
        } else { format = .format24Hour }
        if periodRange != nil {
            if colonRange != nil {
                print("Colon and period both present in \(lowerCaseStringValue)")
                return nil
            }
            delimiterStartIndex = periodRange!.startIndex
            delimiterEndIndex = periodRange!.endIndex
            if delimiterEndIndex.distanceTo(apIndex) == 2 {
                minuteScale = 0.6
            } else if delimiterEndIndex.distanceTo(apIndex) == 1 {
                minuteScale = 6
            }
            
        } else if colonRange != nil {
            delimiterStartIndex = colonRange!.startIndex
            delimiterEndIndex = colonRange!.endIndex
        } else {
            if amOrPM != nil {
                delimiterStartIndex = apIndex
                delimiterEndIndex = apIndex
            }
        }
        hour = Int(lowerCaseStringValue.substringWithRange(lowerCaseStringValue.startIndex..<delimiterStartIndex))
        if delimiterEndIndex < apIndex {
            let tempMinString = lowerCaseStringValue.substringWithRange(delimiterEndIndex..<apIndex)
            if let tempMin = Double(tempMinString) {
                min = Int(tempMin * minuteScale)
            } else {
                print("Substring \(tempMinString) from \(delimiterStartIndex) to \(apIndex) in String: \(lowerCaseStringValue), is not a number")
                return nil
            }
        } else {
            min = 0
        }
        SPTime.adjustHourInput(&hour, amOrPM: amOrPM)
        guard min != nil && hour != nil else {
            print("No hour and/or min in \(lowerCaseStringValue). hour: \(hour) min: \(min)")
            return nil
        }
        if let timeInt = SPTimeInt.init(hour: hour!, min: min!) {
            print("Initializing SPTime with TimeInt: \(timeInt.hour), \(timeInt.min), stringValue: \(lowerCaseStringValue), and format: \(format)")
            self.init(intValue:timeInt, format: format)
        } else { return nil }
    }
    static private func adjustHourInput(inout hour:Int?, amOrPM:SPAmPm?) {
        guard hour != nil else { return }
        var upperBound, lowerBound:Int
        if amOrPM != nil {
            upperBound = 12
            lowerBound = 1
        } else {
            upperBound = 23
            lowerBound = 0
        }
        if hour < lowerBound || hour > upperBound {
            print("Hour \(hour), is not valid, not in between \(lowerBound) and \(upperBound). AM/PM: \(amOrPM)")
            hour = nil
        }
        if amOrPM != nil {
            if amOrPM == .am {
                if hour == 12 {
                    hour = 0
                }
            } else if amOrPM == .pm {
                if hour < 12 {
                    hour = 12 + hour!
                }
            }
        }
    }
}

//enum SPHour: Int { "Hour, Optional(18), and min, Optional(0), are not valid, should be between 0-23 and 0-60 respectively\n"
//    case hour0 = 0, hour1, hour2, hour3, hour4, hour5, hour6, hour7, hour8, hour9, hour10, hour11, hour12, hour13, hour14, hour15,hour16, hour17, hour18, hour19, hour20, hour21, hour22, hour23
//    var allValues: [SPHour] { return [hour0, hour1, hour2, hour3, hour4, hour5, hour6, hour7, hour8, hour9, hour10, hour11, hour12, hour13, hour14, hour15,hour16, hour17, hour18, hour19, hour20, hour21, hour22, hour23] }
//}

struct SPTimeAndDay {
    var dayOfWeek: SPDay
    var time: SPTime
    var format: SPTimeFormat
    func increaseTime() {
        self.time.increaseTime()
        if self.time.intValue.hour == 0 {
            self.dayOfWeek.increaseDay()
        }
    }
    func decreaseTime() {
        self.time.decreaseTime()
        if self.time.intValue.hour == 24 {
            self.dayOfWeek.decreaseDay()
        }
    }
    func nextStreetCleaning() -> SPTimeAndDay {
        var returnTimeAndDay = self
        if returnTimeAndDay.time.intValue.hour < 15 && returnTimeAndDay.time.intValue.time.hour > 2 {
            if returnTimeAndDay.time.intValue.time.hour == 14 && returnTimeAndDay.time.intValue.time.min == 30 {
                returnTimeAndDay.time.intValue.hour = 19
                returnTimeAndDay.time.intValue.min = 0
            }
        } else if returnTimeAndDay.time.intValue.hour < 19 {
            returnTimeAndDay.time.intValue.hour = 19
            returnTimeAndDay.time.intValue.min = 0
        } else if returnTimeAndDay.time.intValue.hour == 19 && returnTimeAndDay.time.intValue.min == 0 {
        } else {
            returnTimeAndDay.time.intValue.hour = 3
            returnTimeAndDay.time.intValue.min = 0
            returnTimeAndDay.dayOfWeek.increaseDay()
        }
        if returnTimeAndDay.dayOfWeek.rawValue == 1 {
            returnTimeAndDay.dayOfWeek.increaseDay()
        }
        return SPTimeAndDay.init(dayOfWeek: returnTimeAndDay.dayOfWeek, time: returnTimeAndDay.time, format: returnTimeAndDay.format)
    }
    
    func previousValidTimeAndDay() -> SPTimeAndDay {
        var returnTimeAndDay = self
        if returnTimeAndDay.time.intValue.hour > 19 && (returnTimeAndDay.dayOfWeek.rawValue != 1 || returnTimeAndDay.dayOfWeek.rawValue != 7) {
            returnTimeAndDay.time.intValue.hour = 19
            returnTimeAndDay.time.intValue.min = 0
        } else if returnTimeAndDay.time.intValue.hour > 14 || (returnTimeAndDay.time.intValue.hour == 14 && returnTimeAndDay.time.intValue.min == 30) {
            returnTimeAndDay.time.intValue.hour = 14
            returnTimeAndDay.time.intValue.min = 0
        } else if returnTimeAndDay.time.intValue.hour < 3 {
            returnTimeAndDay.dayOfWeek.decreaseDay()
            if returnTimeAndDay.dayOfWeek.rawValue == 7 {
                returnTimeAndDay.time.intValue.hour = 13
                returnTimeAndDay.time.intValue.min = 0
            } else {
                returnTimeAndDay.time.intValue.hour = 19
                returnTimeAndDay.time.intValue.min = 0
            }
        }
        if returnTimeAndDay.dayOfWeek.rawValue == 1 {
            returnTimeAndDay.dayOfWeek.decreaseDay()
            returnTimeAndDay.time.intValue.hour = 13
            returnTimeAndDay.time.intValue.min = 0
        }
        return SPTimeAndDay.init(dayOfWeek: returnTimeAndDay.dayOfWeek, time: returnTimeAndDay.time, format: returnTimeAndDay.format)
    }
}
extension SPTimeAndDay {
    init?(dayString:String, timeString:String) {
        guard let initDay = SPDay.init(stringValue: dayString) else {
            print("Unable to make day out of string: \(dayString)")
            return nil
        }
        guard let initTime = SPTime.init(userInputValue: timeString) else {
            print("Unable to make time out of string: \(timeString)")
            return nil

        }
        self.init(day:initDay, time: initTime)
    }
    init?(dayInt:Int, hourInt:Int, minInt:Int, format:SPTimeFormat) {
        guard let initDay = SPDay.init(rawValue: dayInt) else {
            print("Unable to make day out of int: \(dayInt)")
            return nil
        }
        guard let timeInt = SPTimeInt.init(hour: hourInt, min: minInt) else {
            print("Unable to make timeInt out of hour: \(hourInt), min: \(minInt)")
            return nil
        }
        guard let initTime = SPTime.init(timeInt:timeInt, format: format) else {
            print("Unable to make time out of string: \(timeString)")
            return nil
            
        }
        self.init(day:initDay, time: initTime)
    }
    init?(currentTimeAndDayWithFormat: SPTimeFormat) {
        let date = NSDate()
        if let calendar = NSCalendar(calendarIdentifier: NSCalendarIdentifierGregorian) {
            let hour = calendar.component(.Hour, fromDate: date)
            let minute = calendar.component(.Minute, fromDate: date)
            let day = calendar.component(.Weekday, fromDate: date)
            return SPTimeAndDay.init(dayInt: day, hourInt: hour, minInt: minute, format: format)
        } else {
            print("Unable to get current day, hour, and/or minutes, will return (2, 12, 0) respectively")
            return SPTimeAndDay.init(dayInt: 2, hourInt: 12, minInt: 0, format: .format12Hour)
        }
    }
}