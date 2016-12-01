//
//  SPTimeAndDayViewController.swift
//  SwoopParkingApp
//
//  Created by Daniel Nomura on 8/18/16.
//  Copyright © 2016 Daniel Nomura. All rights reserved.
//

import Foundation
import DNTimeAndDay

class SPTimeAndDayViewController: UIViewController, UITextViewDelegate, InjectableViewController {
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
    
    var thumbRect: CGRect {
        let trackRect = timeSlider.trackRect(forBounds: timeSlider.bounds)
        return timeSlider.thumbRect(forBounds: timeSlider.bounds, trackRect: trackRect, value: timeSlider.value)
    }
    var centerOfSliderThumb: CGPoint {
        return CGPoint(x: thumbRect.origin.x + thumbRect.size.width/2 + timeSlider.frame.origin.x, y: thumbRect.origin.y + thumbRect.size.height/2 + timeSlider.frame.origin.y - 20)
    }
    
    //MARK: - Setup Methods
    override func viewDidLoad() {
        super.viewDidLoad()
        assertDependencies()
        dao.primaryTimeAndDay.increaseTime()
        setupSlider()
        dao.getStreetCleaningLocationsForPrimaryTimeAndDay()
//        dao.getAllStreetCleaningLocations()
        setupGestures()
    }
    
    
    //MARK: Gestures
    fileprivate func setupGestures() {
        let tapGesture = UITapGestureRecognizer.init(target: self, action: #selector(tapToMoveSliderThumb(_:)))
        timeSliderGestureView.addGestureRecognizer(tapGesture)
        let sliderPanGesture = UIPanGestureRecognizer.init(target: self, action: #selector(panTimeSlider(_:)))
        timeSliderGestureView.addGestureRecognizer(sliderPanGesture)
//        let dayPanGesture = UIPanGestureRecognizer.init(target: self, action: #selector(panToChangeDay(_:)))
//        dayView.addGestureRecognizer(dayPanGesture)
    }
    
//    var pointForDay0:CGFloat = 0
//    var startDay: DNDay = DNDay.mon
//    @objc func panToChangeDay(_ recognizer: UIPanGestureRecognizer) {
//        switch recognizer.state {
//        case .began:
//            pointForDay0 = recognizer.location(in: view).y
//            startDay = dao.primaryTimeAndDay.day
//        case .changed, .ended:
//            let newPanLocation = recognizer.location(in: view).y
//            let panScale = (newPanLocation - pointForDay0) / pointForDay0
//
//            
//            let change = panScale / 10 + 1
//            if recognizer.state == .changed {
//                if change % 8 != 0 { return }
//                startDay.increase(by: change)
//                dayLabel.text = startDay.stringValue(forFormat: DNTimeAndDayFormat.abbrDay())
//                pointForDay0 = newPanLocation
//            } else {
//                dao.primaryTimeAndDay.day.increase(by: change)
//                let tempTime = dao.primaryTimeAndDay
//                adjustTimeSliderToDay()
//                if tempTime != dao.primaryTimeAndDay {
//                    delegate?.timeViewControllerDidChangeTime()
//                }
//            }
//        default:
//            break
//        }
//    }
    
    @objc func panTimeSlider(_ recognizer: UIPanGestureRecognizer) {
        if recognizer.state == .began || recognizer.state == .changed || recognizer.state == .ended {
            adjustTimeSlider(toRecognizer: recognizer)
        }
        if recognizer.state == .ended {
            self.delegate?.timeViewControllerDidChangeTime()
        }
    }
    @objc func tapToMoveSliderThumb(_ recognizer: UIGestureRecognizer) {
        adjustTimeSlider(toRecognizer: recognizer)
        delegate?.timeViewControllerDidChangeTime()
    }
    
    func adjustTimeSlider(toRecognizer recognizer: UIGestureRecognizer) {
        let pointOnSlider = recognizer.location(in: timeSlider)
        let trackRect = timeSlider.trackRect(forBounds: timeSlider.bounds)
        timeSlider.setValue(Float(Int(CGFloat(timeRange.count) * pointOnSlider.x / trackRect.width)), animated: true)
        adjustSliderToTimeChange()
    }
    
    fileprivate func setupSlider() {
        sliderThumbLabel = UILabel.init(frame: CGRect(x: 0, y: 0, width: 55, height: 20))
        sliderThumbLabel!.backgroundColor = UIColor.clear
        sliderThumbLabel!.textAlignment = .center
        sliderThumbLabel.font = UIFont.init(name: "Christopherhand", size: 19)
        view.addSubview(sliderThumbLabel)
        originalThumbWidth = Float(thumbRect.size.width)
        timeSlider.isContinuous = true
        timeSlider.addTarget(self, action: #selector(sliderDidEndSliding(_:)), for: UIControlEvents.touchUpOutside)
        timeSlider.addTarget(self, action: #selector(sliderDidEndSliding(_:)), for: UIControlEvents.touchUpInside)

        timeSlider.minimumValue = 0
        adjustTimeSliderToDay()
    }
    //MARK: - Time and Day change methods
    //MARK: Change Day
    @IBAction func increasePrimaryDay(_ sender: UIButton) {
        changeDay(true)
    }
    @IBAction func decreasePrimaryDay(_ sender: UIButton) {
        changeDay(false)
    }
    fileprivate func changeDay(_ increase:Bool) {
        increase ? dao.primaryTimeAndDay.day.increase(by: 1) : dao.primaryTimeAndDay.day.decrease(by: 1)
        adjustTimeSliderToDay()
        delegate?.timeViewControllerDidChangeTime()
    }
    //MARK: ChangeTime
    //MARK: -- Slider Methods
    @IBAction func changeTime(_ slider: UISlider) {
        adjustSliderToTimeChange()
    }
    @objc func sliderDidEndSliding(_ notification: Notification) {
        delegate?.timeViewControllerDidChangeTime()
    }
    
    func adjustSliderToTimeChange() {
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
        _ = dao.primaryTimeAndDay.adjustTimeToValidStreetCleaningTime()
        timeSlider.maximumValue = Float(timeRange.count - 1)
        if let currentTimeValue = timeRange.index(of: Float(dao.primaryTimeAndDay.time.rawValue)) {
            timeSlider.setValue(Float(currentTimeValue), animated: true)
        }
        sliderThumbLabel.center = centerOfSliderThumb
        dayLabel.text = dao.primaryTimeAndDay.day.stringValue(forFormat: timeAndDayFormat)
        setSliderLabels()
        setNewImage()
    }
    
    fileprivate func setSliderLabels() {
        let minMaxTime = dao.primaryTimeAndDay.day.earliestAndLatestCleaningTime
        minTimeLabel.text = minMaxTime.earliest.stringValue(forFormat: DNTimeAndDayFormat.format12Hour())
        maxTimeLabel.text = minMaxTime.latest.stringValue(forFormat: DNTimeAndDayFormat.format12Hour())
        sliderThumbLabel.text = dao.primaryTimeAndDay.time.stringValue(forFormat: DNTimeAndDayFormat.format12Hour())
    }
    //MARK: Image processing
    let thumbImage: UIImage! = UIImage(named:"smart-car-icon")
    let noParkingImage: UIImage! = UIImage(named:"smart-car-no-parking")
    let unknownParkingImage: UIImage! = UIImage(named:"smart-car-question-mark")
    func setNewImage() {
        guard let locationsCount = (self.dao.locationsForPrimaryTimeAndDay?.count) else {
            timeSlider.setThumbImage(unknownParkingImage, for: UIControlState())
            return
        }
        let newImage: UIImage
        if locationsCount == 0 {
            newImage = noParkingImage
        } else {
            let thumbSizeSide: CGFloat
            if locationsCount < 200 {
                thumbSizeSide = 15
            } else {
                thumbSizeSide = CGFloat((self.originalThumbWidth - 15) * Float(locationsCount) / 2000 + 20)
            }
            newImage = self.imageWith(image: self.thumbImage, scaledToSize: CGSize(width: thumbSizeSide, height: thumbSizeSide))
        }
        self.timeSlider.setThumbImage(newImage, for: UIControlState())
    }
    
    fileprivate func imageWith(image: UIImage, scaledToSize size:CGSize) -> UIImage {
        UIGraphicsBeginImageContextWithOptions(size, false, 0.0)
        image.draw(in: CGRect(x: 0, y: 0, width: size.width, height: size.width))
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
    fileprivate func setTimeRangeForDay() {
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
    func textViewDidBeginEditing(_ textView: UITextView) {
        DispatchQueue.main.async {
            textView.selectAll(nil)
        }
    }
    //MARK: - Injectable Protocol
    
    fileprivate var dao: SPDataAccessObject!
    func inject(dao: SPDataAccessObject, delegate: Any) {
        self.dao = dao
        self.delegate = delegate as? SPTimeViewControllerDelegate
    }
    func assertDependencies() {
        assert(dao != nil)
        assert(delegate != nil)
    }
}

protocol SPTimeViewControllerDelegate: class {
    func timeViewControllerDidChangeTime()
}
