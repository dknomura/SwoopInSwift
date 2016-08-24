//
//  SPTimeAndDayManager.swift
//  SwoopParkingApp
//
//  Created by Daniel Nomura on 8/11/16.
//  Copyright © 2016 Daniel Nomura. All rights reserved.
//

import Foundation

enum TimeAndDayError : ErrorType {
    case unableToConvertDayString(fromInt:Int)
    case unableToConvertDayInt(fromString:String)
    case unableToConvertTimeInt(fromString:String)
    case noColon(inTimeString:String)
    case unableToCastInt(fromString:String)
    case invalidInput
    case invalidHourInt(hour:Int)
    case invalidMinuteInt(minute:Int)
}

enum TimeFormat : Int {
    case format24Hour = 0
    case format12Hour
}

class SPTimeAndDayManager {
    
    func getCurrentDayHourMinutes() -> (day:Int, hour:Int, min:Int) {
        let date = NSDate()
        if let calendar = NSCalendar(calendarIdentifier: NSCalendarIdentifierGregorian) {
            let hour = calendar.component(.Hour, fromDate: date)
            let minute = calendar.component(.Minute, fromDate: date)
            let day = calendar.component(.Weekday, fromDate: date)
            return (day, hour, minute)
        } else {
            print("Unable to get current day, hour, and minutes, will return (1, 0, 0) respectively")
            return (1, 0, 0)
        }
    }
    // MARK: - Methods to increase/decrease time/day
    func increaseDay(dayString:String) -> String {
        if dayString == "" { return dayString }
        do {
            var dayInt = try getDayNumber(fromDayString: dayString)
            if dayInt == 7 { dayInt = 1 }
            else { dayInt += 1 }
            return try getDayString(fromInt: dayInt)
        } catch {
            print("Error while converting day between Int and String")
        }
        return dayString
    }
    
    func decreaseDay(dayString:String) -> String {
        if dayString == "" {
            return dayString
        }
        do {
            var dayInt = try getDayNumber(fromDayString: dayString)
            if dayInt == 1 {
                dayInt = 7
            } else {
                dayInt -= 1
            }
            return try getDayString(fromInt: dayInt)
        } catch {
            print("Unknown error while converting day between Int and String")
        }
        return dayString
    }
    
    
    
    func increaseTime(timeAndDay:(time:String, day:String), format:TimeFormat) -> (time:String, day:String) {
        if timeAndDay.time == "" {
            return timeAndDay
        }
        do {
            var hourAndMin = try timeInt(fromTimeString: timeAndDay.time, format: format)
            var dayString = timeAndDay.day
            if hourAndMin.min < 30 {
                hourAndMin.min = 30
            } else if hourAndMin.min >= 30 {
                hourAndMin.hour += 1
                hourAndMin.min = 0
            }
            if hourAndMin.hour > 23 {
                hourAndMin.hour = 0
                dayString = increaseDay(dayString)
            }
            return (timeString(fromTime: hourAndMin, format: format), dayString)
        } catch {
            print("Error while getting time tuple from timeString: \(timeAndDay)")
        }
        return timeAndDay
    }
    
    func decreaseTime(timeAndDay:(time:String, day:String), format:TimeFormat) -> (time:String, day:String) {
        if timeAndDay.time == "" {
            return timeAndDay
        }
        do {
            var hourAndMin = try timeInt(fromTimeString: timeAndDay.time, format: format)
            var dayString = timeAndDay.day
            if hourAndMin.min > 30 {
                hourAndMin.min = 30
            } else if hourAndMin.min <= 30 && hourAndMin.min > 0 {
                hourAndMin.min = 0
            } else if hourAndMin.min == 0 {
                hourAndMin.min = 30
                hourAndMin.hour -= 1
            }
            if hourAndMin.hour < 0 {
                hourAndMin.hour = 23
                dayString = decreaseDay(dayString)
            }
            return (timeString(fromTime: hourAndMin, format: format), dayString)
        } catch {
            print("Error while getting time tuple from timeString: \(timeAndDay)")
        }
        return timeAndDay
    }
    
    func setNextValidTime(time:(day: Int, hour:Int, min:Int), format:TimeFormat) -> (day:String, time:String) {
        var min: Int
        var hour: Int
        var dayString = try! getDayString(fromInt:time.day)
        
        if time.min > 30 {
            hour = time.hour + 1
            min = 0
        } else {
            hour = time.hour
            min = 30
        }
        if hour < 14 {
            if hour > 0 && hour < 3 {
                hour = 3
                min = 0
            }
        } else if hour < 19 {
            hour = 7
            min = 0
        } else {
            hour = 3
            min = 0
            dayString = increaseDay(dayString)
        }
        return (dayString, timeString(fromTime: (hour, min), format: format))
    }
    
    //MARK: Methods to convert time/day to string/int
    func timeString(fromTime time: (hour:Int, min:Int), format:TimeFormat) -> String {
        let minString: String
        let hourString: String
        var hour = time.hour
        var amPM = ""
        
        if format == TimeFormat.format12Hour {
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
    
    
    func convertTimeString(time:String, toFormat format:TimeFormat) -> String {
        do{
            let time = try timeInt(fromTimeString: time, format: format)
            return timeString(fromTime: time, format: format)
        } catch{
            print("Unable to convert string '\(time)' to int")
        }
        return time
    }
    
    func timeInt(fromTimeString timeString:String, format:TimeFormat) throws -> (hour:Int, min:Int) {
        if let colonRange = timeString.rangeOfString(":") {
            let hourString = timeString.substringWithRange(timeString.startIndex..<colonRange.startIndex)
            let minuteString = timeString.substringWithRange(colonRange.endIndex..<colonRange.endIndex.advancedBy(2))
            guard var hour = Int(hourString) else {
                throw TimeAndDayError.unableToCastInt(fromString: hourString)
            }
            guard let minute = Int(minuteString) else {
                throw TimeAndDayError.unableToCastInt(fromString: minuteString)
            }
            
            let amPM = timeString.substringWithRange(timeString.endIndex.advancedBy(-2)..<timeString.endIndex)
            if amPM == "PM" && hour < 12{
                hour += 12
            } else if amPM == "AM" && hour == 12{
                hour = 0
            }
            return (hour, minute)
        } else {
            print("There is no colon in timeString: \(timeString)")
            throw TimeAndDayError.noColon(inTimeString: timeString)
        }
    }
    
    private func hourAndMinTuple(fromTimeString timeString: String) throws -> (hour:Int, min: Int) {
        if let colonRange = timeString.rangeOfString(":") {
            let hourString = timeString.substringWithRange(timeString.startIndex..<colonRange.startIndex)
            let minuteString = timeString.substringWithRange(colonRange.endIndex..<colonRange.endIndex.advancedBy(2))
            guard let hour = Int(hourString) else {
                throw TimeAndDayError.unableToCastInt(fromString: hourString)
            }
            guard let minute = Int(minuteString) else {
                throw TimeAndDayError.unableToCastInt(fromString: minuteString)
            }
            return (hour, minute)
        } else {
            print("There is no colon in timeString: \(timeString)")
            throw TimeAndDayError.noColon(inTimeString: timeString)
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
            throw TimeAndDayError.unableToConvertDayString(fromInt: fromInt)
        }
    }
    
    func getDayNumber(fromDayString dayString:String) throws -> Int {
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
            throw TimeAndDayError.unableToConvertDayInt(fromString: dayString)
        }
    }
    
    // MARK: - Convert text input to valid text
    
    func dayString(fromTextInput input:String) throws -> String {
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
            throw TimeAndDayError.invalidInput
        }
    }
    
    func timeString(fromTextInput input:String, format:TimeFormat) throws -> String {
        return input
        //        let lowerCaseInput = input.lowercaseString
        //        let pTuple = rangeAndDistance(ofString: "p", toEndOfString: lowerCaseInput)
        //        let aTuple = rangeAndDistance(ofString: "a", toEndOfString: lowerCaseInput)
        //        let periodTuple = rangeAndDistance(ofString: ".", toEndOfString: lowerCaseInput)
        //        let colonTuple = rangeAndDistance(ofString: ":", toEndOfString: lowerCaseInput)
        //
        //        let isAMPM: Bool
        //
        //        // First check if there is 'a' or 'p', then check if the a/p is 1 or 2 characters away from the end.
        //        if pTuple.range == nil && aTuple.range == nil { isAMPM = false }
        //        else if pTuple.range != nil && (pTuple.distanceToEnd == 1 || pTuple.distanceToEnd == 0) { isAMPM = true }
        //        else if aTuple.range != nil && (aTuple.distanceToEnd == 1 || aTuple.distanceToEnd == 0) { isAMPM = true }
        //        else {
        //                print("AM/PM range \(pTuple.range) \(aTuple.range) is not at the end of the input string \(lowerCaseInput)")
        //                throw TimeAndDayError.invalidInput
        //        }
        //
        //        var hour = Int(lowerCaseInput.substringToIndex(lowerCaseInput.startIndex.advancedBy(2)))
        //        if hour == nil {
        //            hour = Int(lowerCaseInput.substringToIndex(lowerCaseInput.startIndex.advancedBy(1)))
        //            if hour == nil { throw TimeAndDayError.invalidInput }
        //        }
        //
        //        if isAMPM {
        //            if colonTuple.range == nil && periodTuple.range == nil {
        //                if pTuple.distanceToStart > 2 || aTuple.distanceToStart > 2 { throw TimeAndDayError.invalidInput }
        //                if pTuple.range != nil && hour < 12 { hour! += 12 }
        //                if aTuple.range != nil && hour == 12 { hour! = 0 }
        //                try checkHour(hour!)
        //                return timeString(fromTime: (hour!, 0), format: format)
        //            } else {
        //
        //            }
        //        }
        //        if lowerCaseInput.characters.count < 3 && !isAMPM {
        //            guard let hour = Int(lowerCaseInput) else {
        //                print("Unable to convert \(lowerCaseInput) to time string")
        //                throw TimeAndDayError.invalidInput
        //            }
        //            try checkHour(hour)
        //            return timeString(fromTime: (hour, 0), format: format)
        //        } else if periodTuple.range != nil {
        //            guard let hourInt = Int(lowerCaseInput.substringToIndex(periodTuple.range!.startIndex)) else { throw TimeAndDayError.invalidInput }
        //            let decimalMinute = Int(lowerCaseInput.substringFromIndex(periodTuple.range!.endIndex))
        //            var minInt = 0
        ////            if decimalMinute != nil  {
        ////                minInt =
        ////            }
        //            let periodDistance = periodTuple.range!.endIndex.distanceTo(lowerCaseInput.endIndex)
        //        }
        //
        //
        //        return lowerCaseInput
    }
    
    private func rangeAndDistance(ofString subString:String, toEndOfString testString:String) -> (range:Range<String.CharacterView.Index>?, distanceToStart:Int, distanceToEnd:Int) {
        guard let range = testString.rangeOfString(subString) else { return (nil, 0, 0) }
        let startDistance = testString.startIndex.distanceTo(range.startIndex)
        let endDistance = range.endIndex.distanceTo(testString.endIndex)
        return (range, startDistance, endDistance)
    }
    
    private func checkHour(hour:Int) throws {
        if hour < 0 || hour > 24 {
            print("Hour \(hour), is not valid, not in between 0 and 24")
            throw TimeAndDayError.invalidHourInt(hour: hour)
        }
    }
    private func checkMin(min:Int) throws {
        if min < 0 || min > 60 {
            print("Minute \(min), is not valid, not in between 0 and 60")
            throw TimeAndDayError.invalidMinuteInt(minute: min)
        }
    }
}