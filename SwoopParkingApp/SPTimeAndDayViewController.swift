//
//  SPTimeAndDayViewController.swift
//  SwoopParkingApp
//
//  Created by Daniel Nomura on 8/18/16.
//  Copyright © 2016 Daniel Nomura. All rights reserved.
//

import Foundation
import DNTimeAndDay

class SPTimeAndDayViewController: UIViewController, UITextViewDelegate, SPInjectable {
    var timeAndDayFormat = DNTimeAndDayFormat.init(time: DNTimeFormat.format12Hour, day: DNDayFormat.abbr)
    @IBOutlet weak var timeAndDayContainer: UIView!
//    @IBOutlet weak var primaryDayTextView: UITextView!
    
    @IBOutlet weak var dayLabel: UILabel!
    @IBOutlet weak var heightConstraintOfBorderView: NSLayoutConstraint!
    var borderViewHeight: CGFloat = 8.0
    weak var delegate: SPTimeViewControllerDelegate?
    @IBOutlet weak var timeSlider: UISlider!
    @IBOutlet weak var minTimeLabel: UILabel!
    @IBOutlet weak var maxTimeLabel: UILabel!
    var sliderThumbLabel: UILabel!
    
    //MARK: - Setup Methods
    override func viewDidLoad() {
        super.viewDidLoad()
        dao.primaryTimeAndDay.increaseTime()
        assertDependencies()
        setupSlider()
        dao.getStreetCleaningLocationsForPrimaryTimeAndDay()
        dao.getAllStreetCleaningLocations()
    }
    
    var thumbRect: CGRect {
        let trackRect = timeSlider.trackRectForBounds(timeSlider.bounds)
        return timeSlider.thumbRectForBounds(timeSlider.bounds, trackRect: trackRect, value: timeSlider.value)
    }
    var centerOfSliderThumb: CGPoint {
        return CGPointMake(thumbRect.origin.x + thumbRect.size.width/2 + timeSlider.frame.origin.x, thumbRect.origin.y + thumbRect.size.height/2 + timeSlider.frame.origin.y + 30)
    }
    private func setupSlider() {
        sliderThumbLabel = UILabel.init(frame: CGRectMake(0, 0, 55, 20))
        sliderThumbLabel.center = centerOfSliderThumb
        sliderThumbLabel!.backgroundColor = UIColor.clearColor()
        sliderThumbLabel!.textAlignment = .Center
        sliderThumbLabel.font = UIFont.systemFontOfSize(12)
        view.addSubview(sliderThumbLabel)
        timeSlider.continuous = true
        timeSlider.minimumValue = 0
        adjustTimeSliderToDay()
    }
    //MARK: - Time and Day change methods
    //MARK: Change Day
    @IBAction func increasePrimaryDay(sender: UIButton) {
        changeDay(true)
    }
    @IBAction func decreasePrimaryDay(sender: UIButton) {
        changeDay(false)
    }
    private func changeDay(increase:Bool) {
        increase ? dao.primaryTimeAndDay.day.increase(by: 1) : dao.primaryTimeAndDay.day.decrease(by: 1)
        adjustTimeSliderToDay()
        delegate?.timeViewControllerDidChangeTime()
    }
    //MARK: ChangeTime
    //MARK: -- Slider Methods
    @IBAction func changeTime(slider: UISlider) {
        sliderThumbLabel.center = centerOfSliderThumb
        let sliderValue = Int(slider.value)
        if let newTime = DNTime.init(rawValue: Double(timeRange[sliderValue])) {
            dao.primaryTimeAndDay.time = newTime
        }
        sliderThumbLabel.text = dao.primaryTimeAndDay.time.stringValue(forFormat: DNTimeAndDayFormat.format12Hour())
        delegate?.timeViewControllerDidChangeTime()
    }
    
    func adjustTimeSliderToDay() {
        setTimeRangeForDay()
        dao.primaryTimeAndDay.adjustTimeToValidStreetCleaningTime()
        timeSlider.maximumValue = Float(timeRange.count - 1)
        if let currentTimeValue = timeRange.indexOf(Float(dao.primaryTimeAndDay.time.rawValue)) {
            timeSlider.value = Float(currentTimeValue)
        }
        sliderThumbLabel.center = centerOfSliderThumb
        dayLabel.text = dao.primaryTimeAndDay.day.stringValue(forFormat: timeAndDayFormat)
        setSliderLabels()
    }
    
    var timeRange: [Float]!
    private func setTimeRangeForDay() {
        let maxMinTime = dao.primaryTimeAndDay.earliestAndLatestCleaningTime()
        var minTime = maxMinTime.earliest
        var returnRange = [Float]()
        while minTime <= maxMinTime.latest {
            returnRange.append(Float(minTime.rawValue))
            minTime.increase(by: 30)
        }
        timeRange = returnRange
    }
    
    private func setSliderLabels() {
        let minMaxTime = dao.primaryTimeAndDay.earliestAndLatestCleaningTime()
        minTimeLabel.text = minMaxTime.earliest.stringValue(forFormat: DNTimeAndDayFormat.format12Hour())
        maxTimeLabel.text = minMaxTime.latest.stringValue(forFormat: DNTimeAndDayFormat.format12Hour())
        sliderThumbLabel.text = dao.primaryTimeAndDay.time.stringValue(forFormat: DNTimeAndDayFormat.format12Hour())
    }

    //MARK: - TextView delegate
    func textViewDidBeginEditing(textView: UITextView) {
        dispatch_async(dispatch_get_main_queue()) {
            textView.selectAll(nil)
        }
    }
    
//    func textViewDidEndEditing(textView: UITextView) {
//        if textView === primaryDayTextView {
//        }
//    }
    //MARK: - Injectable Protocol
    
    private var dao: SPDataAccessObject!
    func inject(dao: SPDataAccessObject) {
        self.dao = dao
    }
    func assertDependencies() {
        assert(dao != nil)
    }
}

protocol SPTimeViewControllerDelegate: class {
    func timeViewControllerDidChangeTime()
}