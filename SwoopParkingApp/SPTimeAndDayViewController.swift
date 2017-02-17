//
//  SPTimeAndDayViewController.swift
//  SwoopParkingApp
//
//  Created by Daniel Nomura on 8/18/16.
//  Copyright © 2016 Daniel Nomura. All rights reserved.
//

import Foundation
import DNTimeAndDay

class SPTimeAndDayViewController: UIViewController, UITextViewDelegate, InjectableViewController, ViewControllerWithSliderGestures {
    var timeAndDayFormat = DNTimeAndDayFormat.init(time: DNTimeFormat.format12Hour, day: DNDayFormat.abbr)
    @IBOutlet weak var timeAndDayContainer: UIView!
    @IBOutlet weak var dayView: UIView!
    @IBOutlet weak var sliderGestureView: UIView!
    @IBOutlet weak var dayLabel: UILabel!
    @IBOutlet weak var slider: UISlider!
    @IBOutlet weak var minTimeLabel: UILabel!
    @IBOutlet weak var maxTimeLabel: UILabel!
    
    weak var delegate: SPTimeViewControllerDelegate?
    
    var sliderThumbLabel: UILabel!
    var originalThumbWidth: Float!
    
    //MARK: - Setup Methods
    override func viewDidLoad() {
        super.viewDidLoad()
        assertDependencies()
        dao.primaryTimeAndDay.increaseTime()
        setupSlider()
        setupGestures()
    }
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        sliderThumbLabel.center = centerOfSliderThumbLabel
    }
    //MARK: Gestures
    fileprivate func setupGestures() {
        registerGesturesForSlider()
        let dayPanGesture = UIPanGestureRecognizer.init(target: self, action: #selector(panToChangeDay(_:)))
        dayView.addGestureRecognizer(dayPanGesture)
    }
    
    var pointForDay0:CGFloat = 0
    var startDay: DNDay = DNDay.mon
    @objc func panToChangeDay(_ recognizer: UIPanGestureRecognizer) {
        switch recognizer.state {
        case .began:
            pointForDay0 = recognizer.location(in: view).y
            startDay = dao.primaryTimeAndDay.day
        case .changed, .ended:
            let newPanLocation = recognizer.location(in: view).y
            let change = Int((newPanLocation - pointForDay0) / 40)
            if recognizer.state == .changed {
                if change == 0 { return }
                let originalStartDay = startDay
                startDay.increase(by: change)
                dayLabel.text = startDay.stringValue(forFormat: DNTimeAndDayFormat.abbrDay)
                startDay = originalStartDay
            } else {
                dao.primaryTimeAndDay.day.increase(by: change)
                adjustTimeSliderToDay()
                delegate?.timeViewControllerDidChangeTime()
            }
        default:
            break
        }
    }
    
    @objc func panSlider(_ recognizer: UIPanGestureRecognizer) {
        if recognizer.state == .began || recognizer.state == .changed || recognizer.state == .ended {
            adjustTimeSlider(toRecognizer: recognizer)
            self.delegate?.timeViewControllerDidChangeTime()
        }
    }
    @objc func tapToMoveSliderThumb(_ recognizer: UIGestureRecognizer) {
        adjustTimeSlider(toRecognizer: recognizer)
        delegate?.timeViewControllerDidChangeTime()
    }
    
    fileprivate func adjustTimeSlider(toRecognizer recognizer: UIGestureRecognizer) {
        let pointOnSlider = recognizer.location(in: slider)
        let trackRect = slider.trackRect(forBounds: slider.bounds)
        slider.setValue(Float(Int(CGFloat(timeRange.count) * pointOnSlider.x / trackRect.width)), animated: true)
        adjustSliderToTimeChange()
    }
    
    fileprivate func setupSlider() {
        setupSliderThumbLabel()
        originalThumbWidth = Float(thumbRect.size.width)
        slider.isContinuous = true

        slider.minimumValue = 0
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
    
    func adjustToCurrentTime() {
        dao.primaryTimeAndDay = DNTimeAndDay.currentTimeAndDay()
        dao.primaryTimeAndDay.increaseTime()
        adjustTimeSliderToDay()
    }
    
    func adjustSliderToTimeChange() {
        sliderThumbLabel.center = centerOfSliderThumbLabel
        let sliderValue = Int(slider.value)
        if let newTime = DNTime.init(rawValue: Double(timeRange[sliderValue])) {
            dao.primaryTimeAndDay.time = newTime
        }
        setNewSliderThumbImage()
        sliderThumbLabel.text = dao.primaryTimeAndDay.time.stringValue(forFormat: .format12Hour)
    }
    func adjustTimeSliderToDay() {
        setTimeRangeOnSliderForDay()
        dao.primaryTimeAndDay.adjustTimeToValidStreetCleaningTime(forCity: dao.currentCity)
        slider.maximumValue = Float(timeRange.count - 1)
        if let currentTimeValue = timeRange.index(of: Float(dao.primaryTimeAndDay.time.rawValue)) {
            slider.setValue(Float(currentTimeValue), animated: false)
        }
        sliderThumbLabel.center = centerOfSliderThumbLabel
        dayLabel.text = dao.primaryTimeAndDay.day.stringValue(forFormat: timeAndDayFormat)
        setSliderMaxMinLabels()
        setNewSliderThumbImage()
    }
    
    fileprivate func setSliderMaxMinLabels() {
        let minMaxTime = dao.primaryTimeAndDay.day.earliestAndLatestCleaningTime(forCity: dao.currentCity)
        minTimeLabel.text = minMaxTime.earliest.stringValue(forFormat: DNTimeAndDayFormat.format12Hour)
        maxTimeLabel.text = minMaxTime.latest.stringValue(forFormat: DNTimeAndDayFormat.format12Hour)
        let currentTime = dao.primaryTimeAndDay.time.stringValue(forFormat: DNTimeAndDayFormat.format12Hour)
        sliderThumbLabel.text = currentTime
    }
    //MARK: Image processing
    let parkingImage: UIImage! = UIImage(named:"smart-car-icon")
    let noParkingImage: UIImage! = UIImage(named:"smart-car-no-parking")
    let unknownParkingImage: UIImage! = UIImage(named:"smart-car-question-mark")
    func setNewSliderThumbImage() {
        guard let locationsCount = (self.dao.locationsForPrimaryTimeAndDay?.count) else {
            slider.setThumbImage(unknownParkingImage, for: .normal)
            return
        }
        let newImage: UIImage
        if locationsCount == 0 {
            newImage = noParkingImage
        } else {
            let thumbSizeSide = locationsCount < 200 ? 15 : CGFloat((self.originalThumbWidth - 15) * Float(locationsCount) / 2000 + 20)
            newImage = UIImage.imageWith(image: self.parkingImage, scaledToSize: CGSize(width: thumbSizeSide, height: thumbSizeSide))
        }
        self.slider.setThumbImage(newImage, for: .normal)
    }
    
    var timeRange: [Float]!
    fileprivate func setTimeRangeOnSliderForDay() {
        let maxMinTime = dao.primaryTimeAndDay.day.earliestAndLatestCleaningTime(forCity: dao.currentCity)
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
