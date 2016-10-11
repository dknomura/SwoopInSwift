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
    @IBOutlet weak var dayView: UIView!
    
    @IBOutlet weak var timeSliderGestureView: UIView!
    @IBOutlet weak var dayLabel: UILabel!
    @IBOutlet weak var heightConstraintOfBorderView: NSLayoutConstraint!
    var borderViewHeight: CGFloat = 8.0
    weak var delegate: SPTimeViewControllerDelegate?
    @IBOutlet weak var timeSlider: UISlider!
    @IBOutlet weak var minTimeLabel: UILabel!
    @IBOutlet weak var maxTimeLabel: UILabel!
    var sliderThumbLabel: UILabel!
    var originalThumbWidth: Float!
    
    //MARK: - Setup Methods
    override func viewDidLoad() {
        super.viewDidLoad()
        dao.primaryTimeAndDay.increaseTime()
        assertDependencies()
        setupSlider()
        dao.getStreetCleaningLocationsForPrimaryTimeAndDay()
        dao.getAllStreetCleaningLocations()
        setupGestures()
    }
    
    
    //MARK: Gestures
    private func setupGestures() {
        let tapGesture = UITapGestureRecognizer.init(target: self, action: #selector(tapToMoveSliderThumb(_:)))
        timeSliderGestureView.addGestureRecognizer(tapGesture)
        let sliderPanGesture = UIPanGestureRecognizer.init(target: self, action: #selector(panTimeSlider(_:)))
        timeSliderGestureView.addGestureRecognizer(sliderPanGesture)
        let dayPanGesture = UIPanGestureRecognizer.init(target: self, action: #selector(panToChangeDay(_:)))
        dayView.addGestureRecognizer(dayPanGesture)
    }
    
    var pointForDay0:CGFloat = 0
    @objc func panToChangeDay(recognizer: UIPanGestureRecognizer) {
        switch recognizer.state {
        case .Began:
            pointForDay0 = recognizer.locationInView(view).y
        case .Changed, .Ended:
            let newPanLocation = recognizer.locationInView(view).y
            let change = Int(newPanLocation * 21 / (view.frame.height - pointForDay0))
            if recognizer.state == .Changed {
                if change % 8 != 0 { return }
                var tempDay = DNDay.init(stringValue: dayLabel.text!)
                tempDay?.increase(by: change)
                dayLabel.text = tempDay?.stringValue(forFormat: DNTimeAndDayFormat.abbrDay())
                pointForDay0 = newPanLocation
            } else {
                dao.primaryTimeAndDay.day.increase(by: change)
                let tempTime = dao.primaryTimeAndDay
                adjustTimeSliderToDay()
                if tempTime != dao.primaryTimeAndDay {
                    delegate?.timeViewControllerDidChangeTime()
                }
            }
        default:
            break
        }
    }
    
    @objc func panTimeSlider(recognizer: UIPanGestureRecognizer) {
        if recognizer.state == .Began || recognizer.state == .Changed || recognizer.state == .Ended {
            adjustTimeSlider(toRecognizer: recognizer)
        }
        if recognizer.state == .Ended {
            self.delegate?.timeViewControllerDidChangeTime()
        }
    }
    @objc func tapToMoveSliderThumb(recognizer: UIGestureRecognizer) {
        adjustTimeSlider(toRecognizer: recognizer)
        delegate?.timeViewControllerDidChangeTime()
    }
    
    func adjustTimeSlider(toRecognizer recognizer: UIGestureRecognizer) {
        let pointOnSlider = recognizer.locationInView(timeSlider)
        let trackRect = timeSlider.trackRectForBounds(timeSlider.bounds)
        timeSlider.setValue(Float(Int(CGFloat(timeRange.count) * pointOnSlider.x / trackRect.width)), animated: true)
        adjustSliderToTimeChange()
    }
    
    
    var thumbRect: CGRect {
        let trackRect = timeSlider.trackRectForBounds(timeSlider.bounds)
        return timeSlider.thumbRectForBounds(timeSlider.bounds, trackRect: trackRect, value: timeSlider.value)
    }
    var centerOfSliderThumb: CGPoint {
        return CGPointMake(thumbRect.origin.x + thumbRect.size.width/2 + timeSlider.frame.origin.x, thumbRect.origin.y + thumbRect.size.height/2 + timeSlider.frame.origin.y - 15)
    }
    private func setupSlider() {
        sliderThumbLabel = UILabel.init(frame: CGRectMake(0, 0, 55, 20))
        sliderThumbLabel!.backgroundColor = UIColor.clearColor()
        sliderThumbLabel!.textAlignment = .Center
        sliderThumbLabel.font = UIFont.systemFontOfSize(12)
        view.addSubview(sliderThumbLabel)
        originalThumbWidth = Float(thumbRect.size.width)
        timeSlider.continuous = true
        timeSlider.addTarget(self, action: #selector(sliderDidEndSliding(_:)), forControlEvents: UIControlEvents.TouchUpOutside)
        timeSlider.addTarget(self, action: #selector(sliderDidEndSliding(_:)), forControlEvents: UIControlEvents.TouchUpInside)

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
        adjustSliderToTimeChange()
    }
    @objc func sliderDidEndSliding(notification: NSNotification) {
        delegate?.timeViewControllerDidChangeTime()
    }
    
    private func adjustSliderToTimeChange() {
        sliderThumbLabel.center = centerOfSliderThumb
        let sliderValue = Int(timeSlider.value)
        if let newTime = DNTime.init(rawValue: Double(timeRange[sliderValue])) {
            if newTime == dao.primaryTimeAndDay.time { return }
            dao.primaryTimeAndDay.time = newTime
        }
        setNewImage()
        sliderThumbLabel.text = dao.primaryTimeAndDay.time.stringValue(forFormat: DNTimeAndDayFormat.format12Hour())
    }
    func adjustTimeSliderToDay() {
        setTimeRangeForDay()
        dao.primaryTimeAndDay.adjustTimeToValidStreetCleaningTime()
        timeSlider.maximumValue = Float(timeRange.count - 1)
        if let currentTimeValue = timeRange.indexOf(Float(dao.primaryTimeAndDay.time.rawValue)) {
            timeSlider.setValue(Float(currentTimeValue), animated: true)
        }
        sliderThumbLabel.center = centerOfSliderThumb
        dayLabel.text = dao.primaryTimeAndDay.day.stringValue(forFormat: timeAndDayFormat)
        setSliderLabels()
        setNewImage()
    }
    
    private func setSliderLabels() {
        let minMaxTime = dao.primaryTimeAndDay.day.earliestAndLatestCleaningTime
        minTimeLabel.text = minMaxTime.earliest.stringValue(forFormat: DNTimeAndDayFormat.format12Hour())
        maxTimeLabel.text = minMaxTime.latest.stringValue(forFormat: DNTimeAndDayFormat.format12Hour())
        sliderThumbLabel.text = dao.primaryTimeAndDay.time.stringValue(forFormat: DNTimeAndDayFormat.format12Hour())
    }
    //MARK: Image processing
    let thumbImage: UIImage! = UIImage(named:"smart-car-icon")
    let noParkingImage: UIImage! = UIImage(named:"smart-car-no-parking")
    let unknownParkingImage: UIImage! = UIImage(named:"smart-car-no-parking")
    func setNewImage() {
        guard let locationsCount = (self.dao.locationsForPrimaryTimeAndDay?.count) else {
            timeSlider.setThumbImage(unknownParkingImage, forState: .Normal)
            return
        }
        let newImage: UIImage
        if locationsCount == 0 {
            newImage = noParkingImage
        } else {
            let thumbSizeSide: CGFloat
            if locationsCount < 200 {
                thumbSizeSide = 10
            } else {
                thumbSizeSide = CGFloat((self.originalThumbWidth - 30) * Float(locationsCount) / 2000 + 20)
            }
            newImage = self.imageWith(image: self.thumbImage, scaledToSize: CGSizeMake(thumbSizeSide, thumbSizeSide))
        }
        self.timeSlider.setThumbImage(newImage, forState: .Normal)
    }
    
    private func imageWith(image image: UIImage, scaledToSize size:CGSize) -> UIImage {
        UIGraphicsBeginImageContextWithOptions(size, false, 0.0)
        image.drawInRect(CGRectMake(0, 0, size.width, size.width))
        let returnImage: UIImage
        if let newImage = UIGraphicsGetImageFromCurrentImageContext() {
            returnImage = newImage
        } else {
            returnImage = thumbImage
        }
        UIGraphicsEndImageContext()
        return returnImage
    }
    
    var timeRange: [Float]!
    private func setTimeRangeForDay() {
        let maxMinTime = dao.primaryTimeAndDay.day.earliestAndLatestCleaningTime
        var minTime = maxMinTime.earliest
        var returnRange = [Float]()
        while minTime <= maxMinTime.latest {
            returnRange.append(Float(minTime.rawValue))
            minTime.increase(by: 30)
        }
        timeRange = returnRange
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