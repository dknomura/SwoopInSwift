//
//  SPTimeAndDayViewController.swift
//  SwoopParkingApp
//
//  Created by Daniel Nomura on 8/18/16.
//  Copyright © 2016 Daniel Nomura. All rights reserved.
//

import Foundation



class SPTimeAndDayViewController: UIViewController, UITextViewDelegate {
    
    weak var delegate: SPTimeViewControllerDelegate?
    
    var timeFormat = SPTimeFormat.format24Hour
    var isInTimeRangeMode = false
    var dao: SPDataAccessObject?
    let timeAndDayManager = SPTimeAndDayManager()
    
    var format12HrString:String { return "12:00" }
    var format24HrString:String { return "24:00" }
    var timeRangeString:String { return "Range" }
    var singleTimeString:String { return "Single" }
    
    @IBOutlet weak var primaryDayTextView: UITextView!
    @IBOutlet weak var primaryTimeTextView: UITextView!
    @IBOutlet weak var secondaryDayTextView: UITextView!
    @IBOutlet weak var secondaryTimeTextView: UITextView!
    @IBOutlet weak var secondaryDayAndTimeView: UIView!
    @IBOutlet weak var timeRangeButton: UIButton!
    @IBOutlet weak var timeFormatButton: UIButton!
    @IBOutlet weak var centerYConstraintForSecondaryTimeDayView: NSLayoutConstraint!
    @IBOutlet weak var centerYConstraintForPrimaryTimeDayView: NSLayoutConstraint!

    override func viewDidLoad() {
        super.viewDidLoad()
        setCurrentDayAndTimeLabels()
    }
    
    
    //MARK: Time and Day change methods
    @IBAction func decreasePrimaryDay(sender: UIButton) { changeDay(forTextView:primaryDayTextView, function:timeAndDayManager.decreaseDay) }
    @IBAction func increasePrimaryDay(sender: UIButton) { changeDay(forTextView:primaryDayTextView, function: timeAndDayManager.increaseDay) }
    @IBAction func decreaseSecondaryDay(sender: UIButton) { changeDay(forTextView: secondaryDayTextView, function: timeAndDayManager.decreaseDay) }
    @IBAction func increaseSecondaryDay(sender: UIButton) { changeDay(forTextView: secondaryDayTextView, function: timeAndDayManager.increaseDay) }
    private func changeDay(forTextView dayTextView:UITextView, function:(String)->String) {
        dayTextView.text = function(dayTextView.text)
        guard dao != nil else {
            print("DAO not passed to TimeAndDayViewController, unable to set timeAndDayString in changeDay")
            return
        }
        if dayTextView === primaryDayTextView { dao!.primaryTimeAndDayString!.day = dayTextView.text }
        else if dayTextView === secondaryDayTextView { dao!.secondaryTimeAndDayString!.day = dayTextView.text }
    }
    
    @IBAction func decreasePrimaryTime(sender: UIButton) { changeTime(forTimeView: primaryTimeTextView, dayView: primaryDayTextView, function: timeAndDayManager.decreaseTime) }
    @IBAction func increasePrimaryTime(sender: UIButton) { changeTime(forTimeView: primaryTimeTextView, dayView: primaryDayTextView, function: timeAndDayManager.increaseTime) }
    @IBAction func decreaseSecondaryTime(sender: UIButton) { changeTime(forTimeView: secondaryTimeTextView, dayView: secondaryDayTextView, function: timeAndDayManager.decreaseTime) }
    @IBAction func increaseSecondaryTime(sender: UIButton) { changeTime(forTimeView: secondaryTimeTextView, dayView: secondaryDayTextView, function: timeAndDayManager.increaseTime) }
    
    private func changeTime(forTimeView timeView:UITextView, dayView:UITextView, function: (SPTimeAndDayString, SPTimeFormat) -> SPTimeAndDayString) {
        let timeAndDay = function(SPTimeAndDayString(time:timeView.text, day:dayView.text), timeFormat)
        timeView.text = timeAndDay.time
        if dayView.text != timeAndDay.day { dayView.text = timeAndDay.day }
        guard dao != nil else {
            print("DAO not passed to TimeAndDayViewController, unable to set timeAndDayString in changeTime")
            return
        }
        if dayView === primaryDayTextView && timeView == primaryTimeTextView { dao!.primaryTimeAndDayString = timeAndDay }
        else if dayView === secondaryDayTextView && timeView === secondaryTimeTextView { dao!.secondaryTimeAndDayString = timeAndDay }
    }
    
    
    private func setCurrentDayAndTimeLabels() {
        guard dao != nil else {
            print("DAO not passed to TimeAndDayViewController, unable to setCurrentDayAndTimeLabels")
            return
        }
        primaryDayTextView.text = dao!.dayString(fromInt: dao!.currentDayAndTimeInt.day)
        primaryTimeTextView.text = timeAndDayManager.timeString(fromTime: (dao!.currentDayAndTimeInt.time), format: timeFormat)
        dao!.primaryTimeAndDayString = SPTimeAndDayString(time: primaryTimeTextView.text, day: primaryDayTextView.text)
    }

    
    //MARK: Time and day accessory button methods
    
    
    @IBAction func searchSignsByTime(sender: UIButton) {
    }
    
    @IBAction func toggleTimeFormat(sender: UIButton) {
        if timeFormat == .format24Hour {
            timeFormat = .format12Hour
            timeFormatButton.setTitle(format24HrString, forState: .Normal)
        } else if timeFormat == .format12Hour {
            timeFormat = .format24Hour
            timeFormatButton.setTitle(format12HrString, forState: .Normal)
        }
        primaryTimeTextView.text = timeAndDayManager.convertTimeString(primaryTimeTextView.text, toFormat: timeFormat)
        secondaryTimeTextView.text = timeAndDayManager.convertTimeString(secondaryTimeTextView.text, toFormat: timeFormat)
    }

    @IBAction func toggleTimeRange(sender: UIButton) {
        delegate?.timeViewControllerDidTapTimeRangeButton(isInTimeRangeMode)
        if !isInTimeRangeMode {
            isInTimeRangeMode = !isInTimeRangeMode
            timeRangeButton.setTitle(singleTimeString, forState: .Normal)
            secondaryDayTextView.text = primaryDayTextView.text
            secondaryTimeTextView.text = primaryTimeTextView.text
            guard dao != nil else {
                print("DAO not passed to TimeAndDayViewController, unable to set secondaryTimeAndDayString in toggleTimeRange")
                return
            }
            dao!.secondaryTimeAndDayString = SPTimeAndDayString(time: secondaryTimeTextView.text, day:secondaryDayTextView.text)
            
            UIView.animateWithDuration(0.3, animations: {
                self.secondaryDayAndTimeView.hidden = false
                self.centerYConstraintForPrimaryTimeDayView.constant = -15
                self.centerYConstraintForSecondaryTimeDayView.constant = 15
                self.view.layoutIfNeeded()
            })
            
            
        } else if isInTimeRangeMode {
            isInTimeRangeMode = !isInTimeRangeMode
            timeRangeButton.setTitle(timeRangeString, forState: .Normal)
            UIView.animateWithDuration(0.3, animations: {
                self.centerYConstraintForPrimaryTimeDayView.constant = 0
                self.centerYConstraintForSecondaryTimeDayView.constant = 0
                self.view.layoutIfNeeded()
                }, completion: { (complete) in
                    self.secondaryDayAndTimeView.hidden = true
            })
        }
    }
    //MARK: - TextView delegate
    func textViewDidBeginEditing(textView: UITextView) { dispatch_async(dispatch_get_main_queue()) { 
        textView.selectAll(nil) } }
    
    func textViewDidEndEditing(textView: UITextView) {
        guard dao != nil else {
            print("DAO not passed to TimeAndDayViewController, unable to get/set timeAndDayStrings in textViewDidEndEditing")
            return
        }
        do {
            if textView === primaryDayTextView || textView === secondaryDayTextView {
                textView.text = try SPTimeAndDayManager().dayString(fromTextInput: textView.text)
                if textView == primaryDayTextView { dao!.primaryTimeAndDayString!.day = textView.text }
                else { dao!.secondaryTimeAndDayString!.day = textView.text }
            } else if textView === primaryTimeTextView || textView === secondaryTimeTextView {
                textView.text = try SPTimeAndDayManager().timeString(fromTextInput: textView.text, format:timeFormat)
                if textView == primaryTimeTextView { dao!.primaryTimeAndDayString!.time = textView.text }
                else { dao!.secondaryTimeAndDayString!.time = textView.text }
            }
        } catch {
            if textView === primaryTimeTextView { textView.text = dao!.primaryTimeAndDayString!.time }
            else if textView === primaryDayTextView { textView.text = dao!.primaryTimeAndDayString!.day }
            else if textView === secondaryTimeTextView { textView.text = dao!.secondaryTimeAndDayString!.time }
            else if textView === secondaryDayTextView { textView.text = dao!.secondaryTimeAndDayString!.day }
        }
    }
}

protocol SPTimeViewControllerDelegate: class {
    func timeViewControllerDidTapTimeRangeButton(isInRangeMode:Bool)
}