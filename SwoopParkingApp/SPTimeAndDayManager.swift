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
    case noStreetParkingForDay(day:String, nextValidTime:SPTimeAndDayString)
    case noStreetParkingForTimeAndDay(time:SPTimeAndDayString, nextValidTime:SPTimeAndDayString)
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
}

enum SPHour: Int {
    case hour0 = 0, hour1, hour2, hour3, hour4, hour5, hour6, hour7, hour8, hour9, hour10, hour11, hour12, hour13, hour14, hour15,hour16, hour17, hour18, hour19, hour20, hour21, hour22, hour23
    var allValues: [SPHour] { return [hour0, hour1, hour2, hour3, hour4, hour5, hour6, hour7, hour8, hour9, hour10, hour11, hour12, hour13, hour14, hour15,hour16, hour17, hour18, hour19, hour20, hour21, hour22, hour23] }
}
enum SPMin: Int {
    case min0 = 0, min30 = 30
}

struct SPTimeAndDay {
    var stringValue: SPTimeAndDayString?
    var intValue: SPTimeAndDayInt?
    var format: SPTimeFormat?
}

struct SPTimeAndDayString {
    var time: String
    var day: String
}
struct SPTimeAndDayInt {
    var time: SPTimeInt
    var day: Int
}

struct SPTimeInt {
    var hour: Int
    var min: Int
}


class SPTimeAndDayManager {
    
    func getCurrentDayHourMinutes() -> SPTimeAndDayInt {
        let date = NSDate()
        if let calendar = NSCalendar(calendarIdentifier: NSCalendarIdentifierGregorian) {
            let hour = calendar.component(.Hour, fromDate: date)
            let minute = calendar.component(.Minute, fromDate: date)
            let day = calendar.component(.Weekday, fromDate: date)
            return SPTimeAndDayInt.init(time: SPTimeInt.init(hour: hour, min: minute), day: day)
        } else {
            print("Unable to get current day, hour, and minutes, will return (1, 0, 0) respectively")
            return SPTimeAndDayInt.init(time: SPTimeInt.init(hour: 0, min: 0), day: 1)
        }
    }
    // MARK: - Methods to increase/decrease time/day
    func increaseDay(dayString:String) -> String {
        if dayString == "" { return dayString }
        do {
            var dayInt = try getDayInt(fromDayString: dayString)
            increaseDayInt(&dayInt)
            if !isValid(dayInt) {
                increaseDayInt(&dayInt)
            }
            return try getDayString(fromInt: dayInt)
        } catch {
            print("Error while converting day between Int and String")
        }
        return dayString
    }
    private func increaseDayInt(inout dayInt:Int) {
        if dayInt == 7 {
            dayInt = 1
        } else { dayInt += 1 }
    }
    
    func decreaseDay(dayString:String) -> String {
        if dayString == "" {
            return dayString
        }
        do {
            var dayInt = try getDayInt(fromDayString: dayString)
            decreaseDayInt(&dayInt)
            if !isValid(dayInt) {
                decreaseDayInt(&dayInt)
            }
            return try getDayString(fromInt: dayInt)
        } catch {
            print("Unknown error while converting day between Int and String")
        }
        return dayString
    }
    private func decreaseDayInt(inout dayInt:Int) {
        if dayInt == 1 {
            dayInt = 7
        } else { dayInt -= 1 }
    }
    
    
    func increaseTime(timeAndDayString:SPTimeAndDayString, format:SPTimeFormat) -> SPTimeAndDayString {
        if timeAndDayString.time == "" {
            return timeAndDayString
        }
        var timeAndDayInt = getTimeAndDayInt(fromString: timeAndDayString, format: format)
        increaseTimeAndDayInt(&timeAndDayInt)
        return nextValidTimeAndDay(fromTimeAndDayInt: timeAndDayInt, format: format)
    }
    
    private func increaseTimeAndDayInt(inout timeAndDayInt:SPTimeAndDayInt) {
        if timeAndDayInt.time.min < 30 {
            timeAndDayInt.time.min = 30
        } else if timeAndDayInt.time.min >= 30 {
            timeAndDayInt.time.hour += 1
            timeAndDayInt.time.min = 0
        }
        if timeAndDayInt.time.hour > 23 {
            timeAndDayInt.time.hour = 0
            increaseDayInt(&timeAndDayInt.day)
        }
    }
    
    
    func decreaseTime(timeAndDay:SPTimeAndDayString, format:SPTimeFormat) -> SPTimeAndDayString {
        if timeAndDay.time == "" {
            return timeAndDay
        }
        var timeAndDayInt = getTimeAndDayInt(fromString: timeAndDay, format: format)
        decreaseTimeAndDayInt(&timeAndDayInt)
        return previousValidTimeAndDay(fromTimeAndDayInt: timeAndDayInt, format: format)
    }
    
    private func decreaseTimeAndDayInt(inout timeAndDayInt:SPTimeAndDayInt) {
        if timeAndDayInt.time.min > 30 {
            timeAndDayInt.time.min = 30
        } else if timeAndDayInt.time.min <= 30 && timeAndDayInt.time.min > 0 {
            timeAndDayInt.time.min = 0
        } else if timeAndDayInt.time.min == 0 {
            timeAndDayInt.time.min = 30
            timeAndDayInt.time.hour -= 1
        }
        if timeAndDayInt.time.hour < 0 {
            timeAndDayInt.time.hour = 23
            decreaseDayInt(&timeAndDayInt.day)
        }
    }
    
    //MARK: - Next valid time string
    
    func nextValidTimeAndDay(timeAndDayString:SPTimeAndDayString, format:SPTimeFormat) -> SPTimeAndDayString {
        let timeAndDayInt = getTimeAndDayInt(fromString: timeAndDayString, format: format)
        return nextValidTimeAndDay(fromTimeAndDayInt: timeAndDayInt, format: format)
    }
    
    func nextValidTimeAndDay(fromTimeAndDayInt timeAndDayInt:SPTimeAndDayInt, format:SPTimeFormat) -> SPTimeAndDayString {
        var returnTimeAndDayInt = timeAndDayInt
        if returnTimeAndDayInt.time.hour < 15 && returnTimeAndDayInt.time.hour > 2 {
            if returnTimeAndDayInt.time.hour == 14 && returnTimeAndDayInt.time.min == 30 {
                returnTimeAndDayInt.time.hour = 19
                returnTimeAndDayInt.time.min = 0
            }
        } else if returnTimeAndDayInt.time.hour < 19 {
            returnTimeAndDayInt.time.hour = 19
            returnTimeAndDayInt.time.min = 0
        } else if returnTimeAndDayInt.time.hour == 19 && returnTimeAndDayInt.time.min == 0 {
        } else {
            returnTimeAndDayInt.time.hour = 3
            returnTimeAndDayInt.time.min = 0
            increaseDayInt(&returnTimeAndDayInt.day)
        }
        if returnTimeAndDayInt.day == 1 {
            returnTimeAndDayInt.day += 1
        }
        return getTimeAndDayString(fromTimeAndDay: returnTimeAndDayInt, format: format)
    }
    
    
    func previousValidTimeAndDay(timeAndDayString:SPTimeAndDayString, format:SPTimeFormat) -> SPTimeAndDayString {
        let timeAndDayInt = getTimeAndDayInt(fromString: timeAndDayString, format: format)
        return previousValidTimeAndDay(fromTimeAndDayInt: timeAndDayInt, format: format)
    }
    
    func previousValidTimeAndDay(fromTimeAndDayInt timeAndDayInt:SPTimeAndDayInt, format:SPTimeFormat) -> SPTimeAndDayString {
        var returnTimeAndDayInt = timeAndDayInt
        if returnTimeAndDayInt.time.hour > 19 && (returnTimeAndDayInt.day != 1 || returnTimeAndDayInt.day != 7) {
            returnTimeAndDayInt.time.hour = 19
            returnTimeAndDayInt.time.min = 0
        } else if returnTimeAndDayInt.time.hour > 14 || (returnTimeAndDayInt.time.hour == 14 && returnTimeAndDayInt.time.min == 30) {
            returnTimeAndDayInt.time.hour = 14
            returnTimeAndDayInt.time.min = 0
        } else if returnTimeAndDayInt.time.hour < 3 {
            decreaseDayInt(&returnTimeAndDayInt.day)
            if returnTimeAndDayInt.day == 7 {
                returnTimeAndDayInt.time.hour = 13
                returnTimeAndDayInt.time.min = 0
            } else {
                returnTimeAndDayInt.time.hour = 19
                returnTimeAndDayInt.time.min = 0
            }
        }
        if returnTimeAndDayInt.day == 1 {
            returnTimeAndDayInt.day = 7
            returnTimeAndDayInt.time.hour = 13
            returnTimeAndDayInt.time.min = 0
        }
        return getTimeAndDayString(fromTimeAndDay: returnTimeAndDayInt, format: format)
    }
    
    //MARK: - Determine if valid swoop string
    
    func isValid(dayString dayString:String) -> Bool {
        if dayString == "Sun" {
            return false
        } else { return true }
    }
    
    func isValid(dayInt:Int) -> Bool {
        if dayInt == 1 {
            return false
        } else { return true }
    }
    
    func isValid(timeString timeString:String, format:SPTimeFormat) -> Bool {
        do{
            let timeInt = try getTimeInt(fromTimeString: timeString, format: format)
            switch timeInt.hour {
            case 3..<15:
                if timeInt.hour == 15 && timeInt.min == 30 {
                    return false
                } else { return true }
            case 19:
                if timeInt.min == 30 {
                    return false
                } else { return true }
            default:
                return false
            }
        } catch {
            return false
        }
    }
    
    //MARK: - Methods to convert time/day to string/int
    func getTimeAndDayString(fromTimeAndDay timeAndDayInt: SPTimeAndDayInt, format:SPTimeFormat) -> SPTimeAndDayString {
        var timeAndDayString: SPTimeAndDayString
        if format == .format12Hour {
            timeAndDayString = SPTimeAndDayString.init(time: "12:00AM", day: "Mon")
        } else {
            timeAndDayString = SPTimeAndDayString.init(time: "00:00", day: "Mon")
        }
        do{
            timeAndDayString.time = getTimeString(fromTime: timeAndDayInt.time, format: format)
            timeAndDayString.day = try getDayString(fromInt: timeAndDayInt.day)
        } catch {
            print("Unable to get string from \(timeAndDayInt), will return '00:00' '")
        }
        return timeAndDayString
    }
    func getTimeAndDayInt(fromString timeAndDayString:SPTimeAndDayString, format:SPTimeFormat) -> SPTimeAndDayInt {
        var timeAndDayInt = SPTimeAndDayInt.init(time: SPTimeInt.init(hour: 0, min: 0), day: 1)
        do {
            timeAndDayInt.time = try getTimeInt(fromTimeString: timeAndDayString.time, format: format)
            timeAndDayInt.day = try getDayInt(fromDayString: timeAndDayString.day)
        } catch {
            print("Unable to get int from \(timeAndDayString), will return 0, 0, 1 for hour, min, and day")
        }
        return timeAndDayInt
    }
    
    
    func getTimeString(fromTime time: SPTimeInt, format:SPTimeFormat) -> String {
        let minString: String
        let hourString: String
        var hour = time.hour
        var amPM = ""
        
        if format == SPTimeFormat.format12Hour {
            if hour == 0 {
                hour = 12
                amPM = "AM"
            } else if hour < 12 {
                amPM = "AM"
            } else if hour == 12 {
                amPM = "PM"
            }else if hour > 12 {
                hour -= 12
                amPM = "PM"
            }
            hourString = String(hour)
        } else {
            if hour < 10 {
                hourString = "0" + String(hour)
            } else {
                hourString = String(hour)
            }
        }
        if time.min < 10 {
            minString = "0" + String(time.min)
        } else {
            minString = String(time.min)
        }
        return hourString + ":" + minString + amPM
    }
    
    
    func convertTimeString(time:String, toFormat format:SPTimeFormat) -> String {
        do{
            let time = try getTimeInt(fromTimeString: time, format: format)
            return getTimeString(fromTime: time, format: format)
        } catch{
            print("Unable to convert string '\(time)' to int")
        }
        return time
    }
    
    func getTimeInt(fromTimeString timeString:String, format:SPTimeFormat) throws -> SPTimeInt {
        if let colonRange = timeString.rangeOfString(":") {
            let hourString = timeString.substringWithRange(timeString.startIndex..<colonRange.startIndex)
            let minuteString = timeString.substringWithRange(colonRange.endIndex..<colonRange.endIndex.advancedBy(2))
            guard var hour = Int(hourString) else {
                throw SPTimeAndDayError.unableToCastInt(fromString: hourString)
            }
            guard let minute = Int(minuteString) else {
                throw SPTimeAndDayError.unableToCastInt(fromString: minuteString)
            }
            
            let amPM = timeString.substringWithRange(timeString.endIndex.advancedBy(-2)..<timeString.endIndex)
            if amPM == "PM" && hour < 12{
                hour += 12
            } else if amPM == "AM" && hour == 12{
                hour = 0
            }
            return SPTimeInt.init(hour: hour, min: minute)
        } else {
            print("There is no colon in timeString: \(timeString)")
            throw SPTimeAndDayError.noColon(inTimeString: timeString)
        }
    }
    
    func getDayString(fromInt fromInt:Int) throws -> String {
        switch fromInt {
        case 1:
            return "Sun"
        case 2:
            return "Mon"
        case 3:
            return "Tues"
        case 4:
            return "Wed"
        case 5:
            return "Thurs"
        case 6:
            return "Fri"
        case 7:
            return "Sat"
        default:
            print("Unable to convert \(fromInt) to day string")
            throw SPTimeAndDayError.unableToConvertDayString(fromInt: fromInt)
        }
    }
    
    func getDayInt(fromDayString dayString:String) throws -> Int {
        switch dayString {
        case "Sun":
            return 1
        case "Mon":
            return 2
        case "Tues":
            return 3
        case "Wed":
            return 4
        case "Thurs":
            return 5
        case "Fri":
            return 6
        case "Sat":
            return 7
        default:
            print("Unable to convert day \(dayString) to dayInt")
            throw SPTimeAndDayError.unableToConvertDayInt(fromString: dayString)
        }
    }
    
    // MARK: - Convert text input to valid text
    
    func validateDayString(fromTextInput input:String) throws -> String {
        let lowerCase = input.lowercaseString
        switch lowerCase {
        case "su", "sun", "sund", "sunda", "sunday", "7":
            return "Sun"
        case "m", "mo", "mon", "mond", "monda", "monday", "1":
            return "Mon"
        case "t", "tu", "tue", "tues", "tuesday", "2":
            return "Tues"
        case "w", "we", "wed", "wedn", "wedne",  "wednes", "wednesday", "3":
            return "Wed"
        case "th", "thu", "thur", "thurs", "thursday", "4":
            return "Thurs"
        case "f", "fr", "fri", "frid", "friday", "5":
            return "Fri"
        case "s", "sa", "sat", "satu", "satur", "saturday", "6":
            return "Sat"
        default:
            print("Unable to convert \(input) to day string")
            throw SPTimeAndDayError.invalidInput
        }
    }
    
    enum AMOrPM {
        case am, pm
    }
    
//    enum TimeInputRange: String {
//        case period, colon, a, p
//        var allValues: [TimeInputRange] { return [period, colon, a, p] }
//        func rangeValue(forString:String) -> Range<String.CharacterView.Index>? {
//            switch self {
//            case .a:
//                return forString.rangeOfString("a")
//            case .p:
//                return forString.rangeOfString("p")
//            case .period:
//                return forString.rangeOfString(".")
//            case .colon:
//                return forString.rangeOfString(":")
//            }
//        }
//        func allRangeValues(forString:String) -> [TimeInputRange: Range<String.CharacterView.Index>?] {
//            var rangeValues = [TimeInputRange: Range<String.CharacterView.Index>?]()
//            for value in allValues {
//                rangeValues[value] = value.rangeValue(forString)
//            }
//            return rangeValues
//        }
//    }
    
    func validateTimeString(fromTextInput input:String, format:SPTimeFormat) throws -> String {
        let lowerCaseInput = input.lowercaseString
        let periodRange = range(ofSubstring: ".", inString: lowerCaseInput)
        let colonRange = range(ofSubstring: ":", inString: lowerCaseInput)
        let pRange = range(ofSubstring: "p", inString: lowerCaseInput)
        let aRange = range(ofSubstring: "a", inString: lowerCaseInput)
        var amOrPM: AMOrPM?
        
        let timeInt:SPTimeInt
        var hour: Int?, min:Int?
        var minuteScale = 100.0
        var delimiterIndex = lowerCaseInput.endIndex
        var apIndex = lowerCaseInput.endIndex
        if aRange != nil {
            apIndex = aRange!.startIndex
            amOrPM = .am
        } else if pRange != nil {
            apIndex = pRange!.startIndex
            amOrPM = .pm
        }

        if periodRange != nil {
            if colonRange != nil {
                print("Colon and period both present in \(lowerCaseInput)")
                throw SPTimeAndDayError.invalidInput
            }
            minuteScale = 60
            delimiterIndex = periodRange!.startIndex
        } else if colonRange != nil {
             delimiterIndex = colonRange!.startIndex
        } else {
            if amOrPM != nil {
                delimiterIndex = apIndex
            }
        }
        hour = Int(lowerCaseInput.substringWithRange(lowerCaseInput.startIndex..<delimiterIndex))
        var tempMin: Double? = nil
        if delimiterIndex < apIndex {
            tempMin = Double(lowerCaseInput.substringWithRange(delimiterIndex..<apIndex))
        }
        if tempMin != nil {
            if colonRange != nil {
                min = Int(tempMin!)
            } else if periodRange != nil {
                min = Int(tempMin! * minuteScale)
            } 
        } else {
            min = 0
        }

        guard min != nil && hour != nil else {
            print("No hour and/or min in \(lowerCaseInput). hour: \(hour) min: \(min)")
            throw SPTimeAndDayError.invalidInput
        }
        try adjustMinuteInput(&min!)
        try adjustHourInput(&hour!, amOrPM: amOrPM)
        timeInt = SPTimeInt.init(hour: hour!, min: min!)
        return getTimeString(fromTime: timeInt, format: format)
    }
    
    private func range(ofSubstring subString:String, inString testString:String) -> Range<String.CharacterView.Index>? {
        guard let range = testString.rangeOfString(subString) else { return nil }
        return range
    }
    
    private func adjustHourInput(inout hour:Int, amOrPM:AMOrPM?) throws {
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
            throw SPTimeAndDayError.invalidHourInt(hour: hour)
        }
        if amOrPM != nil {
            if amOrPM == .am {
                if hour == 12 {
                    hour = 0
                }
            } else if amOrPM == .pm {
                if hour < 12 {
                    hour += 12
                }
            }
        }
    }
    private func adjustMinuteInput(inout min:Int) throws {
        if min < 0 || min > 59 {
            print("Minute \(min), is not valid, not in between 0 and 59")
            throw SPTimeAndDayError.invalidMinuteInt(minute: min)
        }
        if min < 30 {
            min = 0
        } else if min >= 30 {
            min = 30
        }
    }
}