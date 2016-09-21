//
//  SPTimeAndDayViewController.swift
//  SwoopParkingApp
//
//  Created by Daniel Nomura on 8/18/16.
//  Copyright © 2016 Daniel Nomura. All rights reserved.
//

import Foundation
import DNTimeAndDay

class SPTimeAndDayViewController: UIViewController, UITextViewDelegate {
    
    weak var delegate: SPTimeViewControllerDelegate?
    
    var timeAndDayFormat = DNTimeAndDayFormat.init(time: DNTimeFormat.format12Hour, day: DNDayFormat.abbr)
    var isInTimeRangeMode = false
    var dao: SPDataAccessObject!

    var timeFormatString:String { return timeAndDayFormat.time == .format12Hour ? "12:00" : "24:00" }
    var timeRangeString:String { return isInTimeRangeMode ? "Range" : "Single" }
    
    @IBOutlet weak var primaryDayTextView: UITextView!
    @IBOutlet weak var primaryTimeTextView: UITextView!
    @IBOutlet weak var secondaryDayTextView: UITextView!
    @IBOutlet weak var secondaryTimeTextView: UITextView!
    var primaryTextViews: (day:UITextView, time:UITextView) {
        return (primaryDayTextView, primaryTimeTextView)
    }
    var secondaryTextViews: (day:UITextView, time:UITextView) {
        return (secondaryDayTextView, secondaryTimeTextView)
    }
    @IBOutlet weak var secondaryDayAndTimeView: UIView!
    @IBOutlet weak var timeRangeButton: UIButton!
    @IBOutlet weak var timeFormatButton: UIButton!
    @IBOutlet weak var centerYConstraintForSecondaryTimeDayView: NSLayoutConstraint!
    @IBOutlet weak var centerYConstraintForPrimaryTimeDayView: NSLayoutConstraint!

    override func viewDidLoad() {
        super.viewDidLoad()
        setCurrentDayAndTimeTextViews()
    }
    private func setCurrentDayAndTimeTextViews() {
        primaryDayTextView.text = dao.primaryTimeAndDay.day.stringValue(forFormat: timeAndDayFormat)
        primaryTimeTextView.text = dao.primaryTimeAndDay.time.stringValue(forFormat: timeAndDayFormat)
    }

    //MARK: Time and Day change methods
    @IBAction func decreasePrimaryDay(sender: UIButton) {
        change(day: &dao.primaryTimeAndDay.day, forTextView: primaryDayTextView, increase: false)
    }
    @IBAction func increasePrimaryDay(sender: UIButton) {
        change(day: &dao.primaryTimeAndDay.day, forTextView: primaryDayTextView, increase: true)
    }
    @IBAction func decreaseSecondaryDay(sender: UIButton) {
        change(day: &dao.secondaryTimeAndDay.day, forTextView: secondaryDayTextView, increase: false)
    }
    @IBAction func increaseSecondaryDay(sender: UIButton) {
        change(day: &dao.secondaryTimeAndDay.day, forTextView: secondaryDayTextView, increase: true)
    }
    private func change(inout day day:DNDay, forTextView textView: UITextView, increase: Bool) {
        increase ? day.increase(by: 1) : day.decrease(by: 1)
        textView.text = day.stringValue(forFormat: timeAndDayFormat)
    }
    
    var equalTextViews: Bool {
        return primaryDayTextView.text == secondaryDayTextView.text && primaryTimeTextView.text == secondaryTimeTextView.text
    }
    @IBAction func decreasePrimaryTime(sender: UIButton) {
        change(time: &dao.primaryTimeAndDay, forTextViews: primaryTextViews, increase: false)
    }
    @IBAction func increasePrimaryTime(sender: UIButton) {
        change(time: &dao.primaryTimeAndDay, forTextViews: primaryTextViews, increase: true)
    }
    @IBAction func decreaseSecondaryTime(sender: UIButton) {
        change(time: &dao.secondaryTimeAndDay, forTextViews: secondaryTextViews, increase: false)
    }
    @IBAction func increaseSecondaryTime(sender: UIButton) {
        change(time: &dao.secondaryTimeAndDay, forTextViews: secondaryTextViews, increase: true)
    }
    private func change(inout time timeAndDay:DNTimeAndDay, forTextViews textViews:(day:UITextView, time:UITextView), increase: Bool) {
        increase ? timeAndDay.increaseTime() : timeAndDay.decreaseTime()
        textViews.time.text = timeAndDay.time.stringValue(forFormat: timeAndDayFormat)
        if textViews.day != timeAndDay.day.stringValue(forFormat: timeAndDayFormat) {
            textViews.day.text = timeAndDay.day.stringValue(forFormat: timeAndDayFormat)
        }
    }
    //MARK: Time and day accessory button methods
    @IBAction func searchSignsByTime(sender: UIButton) {
        
    }
    @IBAction func toggleTimeFormat(sender: UIButton) {
        if timeAndDayFormat.time == .format24Hour {
            timeAndDayFormat.time = .format12Hour
            timeFormatButton.setTitle(timeFormatString, forState: .Normal)
        } else if timeAndDayFormat.time == .format12Hour {
            timeAndDayFormat.time = .format24Hour
            timeFormatButton.setTitle(timeFormatString, forState: .Normal)
        }
        primaryTimeTextView.text = dao.primaryTimeAndDay.time.stringValue(forFormat: timeAndDayFormat)
        secondaryTimeTextView.text = dao.secondaryTimeAndDay.time.stringValue(forFormat: timeAndDayFormat)
    }
    @IBAction func toggleTimeRange(sender: UIButton) {
        delegate?.timeViewControllerDidTapTimeRangeButton(isInTimeRangeMode)
        if !isInTimeRangeMode {
            timeRangeButton.setTitle(timeRangeString, forState: .Normal)
            setSecondaryTimeAndDay()
            UIView.animateWithDuration(standardAnimationDuration, animations: {
                self.secondaryDayAndTimeView.hidden = false
                self.centerYConstraintForPrimaryTimeDayView.constant = -15
                self.centerYConstraintForSecondaryTimeDayView.constant = 15
                self.view.layoutIfNeeded()
            })
            
            
        } else if isInTimeRangeMode {
            timeRangeButton.setTitle(timeRangeString, forState: .Normal)
            UIView.animateWithDuration(standardAnimationDuration, animations: {
                self.centerYConstraintForPrimaryTimeDayView.constant = 0
                self.centerYConstraintForSecondaryTimeDayView.constant = 0
                self.view.layoutIfNeeded()
                }, completion: { (complete) in
                    self.secondaryDayAndTimeView.hidden = true
            })
        }
        isInTimeRangeMode = !isInTimeRangeMode
    }
    
    private func setSecondaryTimeAndDay() {
        if let day = DNDay.init(stringValue: primaryDayTextView.text),
            time = DNTime(stringValue: primaryTimeTextView.text) {
            dao.secondaryTimeAndDay = DNTimeAndDay.init(day: day, time: time)
            change(time: &dao.secondaryTimeAndDay, forTextViews: secondaryTextViews, increase: true)
        } else {
            secondaryDayTextView.text = primaryDayTextView.text
            secondaryTimeTextView.text = primaryTimeTextView.text
        }
    }
    //MARK: - TextView delegate
    func textViewDidBeginEditing(textView: UITextView) {
        dispatch_async(dispatch_get_main_queue()) {
            textView.selectAll(nil)
        }
    }
    
    func textViewDidEndEditing(textView: UITextView) {
        if textView === primaryTimeTextView {
            handle(DNTime.init(stringValue: textView.text), timeAndDay: &dao.primaryTimeAndDay, forTextView: textView)
        } else if textView === primaryDayTextView {
            handle(DNDay.init(stringValue: textView.text), timeAndDay: &dao.primaryTimeAndDay, forTextView: textView)
        } else if textView === secondaryTimeTextView {
            handle(DNTime.init(stringValue: textView.text), timeAndDay: &dao.secondaryTimeAndDay, forTextView: textView)
        } else if textView === secondaryDayTextView {
            handle(DNDay.init(stringValue: textView.text), timeAndDay: &dao.secondaryTimeAndDay, forTextView: textView)
        }
    }
    private func handle(timeUnit:DNTimeUnit?, inout timeAndDay: DNTimeAndDay, forTextView textView: UITextView) {
        if timeUnit != nil {
            textView.text = timeUnit!.stringValue(forFormat: timeAndDayFormat)
            if let day = timeUnit as? DNDay {
                timeAndDay.day = day
            } else if let time = timeUnit as? DNTime {
                timeAndDay.time = time
            }
        } else {
            setLastValidTimeUnit(forTextView: textView, timeAndDay: &timeAndDay)
            showRedError(forTextView: textView)
        }
    }
    
    private func setLastValidTimeUnit(forTextView textView: UITextView, inout timeAndDay:DNTimeAndDay) {
        if textView === primaryTimeTextView || textView === secondaryTimeTextView {
            textView.text = timeAndDay.time.stringValue(forFormat: timeAndDayFormat)
        } else if textView === primaryDayTextView || textView === secondaryDayTextView {
            textView.text = timeAndDay.day.stringValue(forFormat: timeAndDayFormat)
        }
    }
    
    private func showRedError(forTextView textView: UITextView) {
        UIView.animateWithDuration(standardAnimationDuration, animations: {
            textView.backgroundColor = UIColor.redColor()
            }, completion: { (complete) in
                textView.backgroundColor = UIColor.whiteColor()
        })
    }
}

protocol SPTimeViewControllerDelegate: class {
    func timeViewControllerDidTapTimeRangeButton(isInRangeMode:Bool)
}