//
//  ViewController.swift
//  SwoopParkingApp
//
//  Created by Daniel Nomura on 5/4/16.
//  Copyright © 2016 Daniel Nomura. All rights reserved.
//

import UIKit
import GoogleMaps
import AWSLambda

class SPMapViewController: UIViewController, CLLocationManagerDelegate, GMSMapViewDelegate, UITextViewDelegate{

    var currentMapPolylines = [GMSPolyline]()
    var currentGroundOverlays = [GMSGroundOverlay]()
    var timeFormat = TimeFormat.format24Hour
    
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!
    @IBOutlet weak var timeRangeButton: UIButton!
    @IBOutlet weak var timeFormatButton: UIButton!
    @IBOutlet weak var swoopSwitch: UISwitch!
    @IBOutlet weak var mapView: GMSMapView!
    @IBOutlet weak var primaryDayTextView: UITextView!
    @IBOutlet weak var primaryTimeTextView: UITextView!
    @IBOutlet weak var secondaryDayTextView: UITextView!
    @IBOutlet weak var secondaryTimeTextView: UITextView!
    @IBOutlet weak var heightConstraintOfTimeAndDayContainer: NSLayoutConstraint!
    @IBOutlet weak var secondaryDayAndTimeView: UIView!
    @IBOutlet weak var centerYConstraintForSecondaryTimeDayView: NSLayoutConstraint!
    @IBOutlet weak var centerYConstraintForPrimaryTimeDayView: NSLayoutConstraint!
    var zoomOutButton = UIButton.init(type:.RoundedRect)

    var isInTimeRangeMode = false
    var userControl = false
    
    let dao = SPDataAccessObject()
    
    var format12HrString:String { return "12:00" }
    var format24HrString:String { return "24:00" }
    var timeRangeString:String { return "Range" }
    var singleTimeString:String { return "Single" }
    var initialMapViewCamera: GMSCameraPosition {
        return GMSCameraPosition.cameraWithTarget(CLLocationCoordinate2DMake(40.7193748839769, -73.9289110153913), zoom: 11.3119)
    }


    override func viewDidLoad() {
        super.viewDidLoad()
        setUpMap()
        setObservers()
        dao.setUpLocationManager()
        setCurrentDayAndTimeLabels()
        dao.getUpcomingStreetCleaningSigns()
        setUpButtonsAndViews()
        setupGestures()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    
    //MARK: - Setup methods
    private func setupGestures() {
        hideKeyboardWhenTapAround()
        mapView.settings.consumesGesturesInView = false
        let touchGesture = UITapGestureRecognizer.init(target: self, action: #selector(zoomToTapOnMap(_:)))
        mapView.addGestureRecognizer(touchGesture)
    }
     @objc private func zoomToTapOnMap(gesture:UITapGestureRecognizer) {
        if mapView.camera.zoom < 15 {
            let pointOnMap = gesture.locationInView(mapView)
            let camera = GMSCameraPosition.cameraWithTarget(mapView.projection.coordinateForPoint(pointOnMap), zoom: 15.0)
            mapView.animateToCameraPosition(camera)
            turnSwoopOn()
            zoomOutButton.hidden = false
        }
    }
    
    private func setUpMap() {
        mapView.camera = initialMapViewCamera
        mapView.myLocationEnabled = true
        mapView.settings.myLocationButton = true
        mapView.settings.rotateGestures = false
        mapView.delegate = self
     }
    
    private func setObservers() {
        let notificationCenter = NSNotificationCenter.defaultCenter()
        notificationCenter.addObserver(self, selector: #selector(currentMapViewLocationsSet), name: kSPSQLiteCoordinateQuery, object: nil)
        notificationCenter.addObserver(self, selector: #selector(currentTimeAndDayLocationsDidSet), name: kSPSQLiteTimeAndDayQuery, object: nil)
        notificationCenter.addObserver(self, selector: #selector(currentTimeAndDayLocationsDidSet), name: kSPSQLiteTimeAndDayLocationsOnlyQuery, object: nil)
    }
    
    private func setCurrentDayAndTimeLabels() {
        do{
            primaryDayTextView.text = try timeAndDayManager.getDayString(fromInt: dao.currentDayAndTimeInt.day)
            primaryTimeTextView.text = timeAndDayManager.timeString(fromTime: (dao.currentDayAndTimeInt.hour, dao.currentDayAndTimeInt.min), format: timeFormat)
            dao.primaryTimeAndDayString = (primaryDayTextView.text, primaryTimeTextView.text)
        } catch {
            print("Day \(dao.currentDayAndTimeInt.day) is not between 1 and 7")
        }
    }
    
    private func setUpButtonsAndViews() {
        timeRangeButton.setTitle(timeRangeString, forState: .Normal)
        timeFormatButton.setTitle(format12HrString, forState: .Normal)
        secondaryDayAndTimeView.hidden = true
        zoomOutButton.setTitle("Zoom Out", forState: .Normal)
        let buttonSize = zoomOutButton.intrinsicContentSize()
        zoomOutButton.frame = CGRectMake(mapView.bounds.origin.x + 15.0, mapView.bounds.origin.y + 15, buttonSize.width, buttonSize.height)
        zoomOutButton.hidden = true
        zoomOutButton.addTarget(self, action: #selector(zoomOut), forControlEvents: .TouchUpInside)
        mapView.addSubview(zoomOutButton)
        activityIndicator.hidden = true
    }
    
    // MARK: - Notification Methods
    @objc private func currentMapViewLocationsSet(notification:NSNotification) {
        if currentMapPolylines.count > 0 {
            hide(mapOverlayViews: currentMapPolylines)
        }
        currentMapPolylines = SPPolylineManager().polylines(forCurrentLocations: dao.currentMapViewLocations, zoom: Double(mapView.camera.zoom))
        if currentMapPolylines.count > 0 && mapView.camera.zoom >= 15 {
            hide(mapOverlayViews: currentGroundOverlays)
            show(mapOverlayViews: currentMapPolylines)
            zoomOutButton.hidden = false
        }
    }
    
    @objc private func currentTimeAndDayLocationsDidSet(notification:NSNotification) {
        currentGroundOverlays =  SPGroundOverlayManager().groundOverlays(forMap: mapView, forLocations: dao.locationsForDayAndTime)
        show(mapOverlayViews: currentGroundOverlays)
    }
    
    //MARK: - Hide/Show GMSPolyline/GroundOverLays
    private func hide<MapOverlayType: GMSOverlay>(mapOverlayViews views:[MapOverlayType]) {
        for view in views { view.map = nil }
    }
    private func show<MapOverlayType: GMSOverlay>(mapOverlayViews views:[MapOverlayType]) {
        let date = NSDate()
        for view in views {  view.map = mapView }
        print("Time to draw polylines: \(date.timeIntervalSinceNow)")
    }

//    MARK: - Button Methods

    //MARK: Swoop toggle
    @IBAction func toggleSwoopSwitch(sender: UISwitch) {
        if swoopSwitch.on { getSignsForCurrentMapView() }
    }
    
    @IBAction func toggleSwoopButton(sender: UIButton) {
        toggleSwoop()
    }
    
    private func toggleSwoop() {
        if swoopSwitch.on {
            swoopSwitch.setOn(false, animated: true)
        } else {
            swoopSwitch.setOn(true, animated: true)
            getSignsForCurrentMapView()
        }
    }
    private func turnSwoopOn() {
        if !swoopSwitch.on { swoopSwitch.setOn(true, animated: true) }
        getSignsForCurrentMapView()
    }
    
    private func turnSwoopOff() {
        if swoopSwitch.on  { swoopSwitch.setOn(false, animated: true) }
    }
    
    private func getSignsForCurrentMapView() {
        print("SwoopSwitch.on: \(swoopSwitch.on). Zoom: \(mapView.camera.zoom). isInNYC: \(dao.isInNYC(mapView))")
        if swoopSwitch.on && mapView.camera.zoom >= 15 && dao.isInNYC(mapView) {
            dao.getSigns(forCurrentMapView: mapView)
        }
    }
    
    //MARK: Time and Day change methods
    let timeAndDayManager = SPTimeAndDayManager()
    @IBAction func decreasePrimaryDay(sender: UIButton) { changeDay(forTextView:primaryDayTextView, function:timeAndDayManager.decreaseDay) }
    @IBAction func increasePrimaryDay(sender: UIButton) { changeDay(forTextView:primaryDayTextView, function: timeAndDayManager.increaseDay) }
    @IBAction func decreaseSecondaryDay(sender: UIButton) { changeDay(forTextView: secondaryDayTextView, function: timeAndDayManager.decreaseDay) }
    @IBAction func increaseSecondaryDay(sender: UIButton) { changeDay(forTextView: secondaryDayTextView, function: timeAndDayManager.increaseDay) }
    private func changeDay(forTextView dayTextView:UITextView, function:(String)->String) {
        dayTextView.text = function(dayTextView.text)
        if dayTextView === primaryDayTextView {
            dao.primaryTimeAndDayString!.day = dayTextView.text
        } else if dayTextView === secondaryDayTextView {
            dao.secondaryTimeAndDayString!.day = dayTextView.text
        }
    }
    
    @IBAction func decreasePrimaryTime(sender: UIButton) { changeTime(forTimeView: primaryTimeTextView, dayView: primaryDayTextView, function: timeAndDayManager.decreaseTime) }
    @IBAction func increasePrimaryTime(sender: UIButton) { changeTime(forTimeView: primaryTimeTextView, dayView: primaryDayTextView, function: timeAndDayManager.increaseTime) }
    @IBAction func decreaseSecondaryTime(sender: UIButton) { changeTime(forTimeView: secondaryTimeTextView, dayView: secondaryDayTextView, function: timeAndDayManager.decreaseTime) }
    @IBAction func increaseSecondaryTime(sender: UIButton) { changeTime(forTimeView: secondaryTimeTextView, dayView: secondaryDayTextView, function: timeAndDayManager.increaseTime) }
    
    // --->
    private func changeTime(forTimeView timeView:UITextView, dayView:UITextView, function: ((String, String), TimeFormat) -> (time:String, day:String)) {
        let timeAndDay = function((timeView.text, dayView.text), timeFormat)
        timeView.text = timeAndDay.time
        if dayView.text != timeAndDay.day {
            dayView.text = timeAndDay.day
        }
        if dayView === primaryDayTextView && timeView == primaryTimeTextView {
            dao.primaryTimeAndDayString = timeAndDay
        } else if dayView === secondaryDayTextView && timeView === secondaryTimeTextView {
            dao.secondaryTimeAndDayString = timeAndDay
        }
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
        
        if !isInTimeRangeMode {
            isInTimeRangeMode = !isInTimeRangeMode
            timeRangeButton.setTitle(singleTimeString, forState: .Normal)
            secondaryDayTextView.text = primaryDayTextView.text
            secondaryTimeTextView.text = primaryTimeTextView.text
            dao.secondaryTimeAndDayString = (secondaryDayTextView.text, secondaryTimeTextView.text)

            UIView.animateWithDuration(0.3, animations: {
                self.secondaryDayAndTimeView.hidden = false
                self.heightConstraintOfTimeAndDayContainer.constant = 80
                self.centerYConstraintForPrimaryTimeDayView.constant = -self.heightConstraintOfTimeAndDayContainer.constant / 5
                self.centerYConstraintForSecondaryTimeDayView.constant = self.heightConstraintOfTimeAndDayContainer.constant / 5
                self.view.layoutIfNeeded()
            })
        } else if isInTimeRangeMode {
            isInTimeRangeMode = !isInTimeRangeMode
            timeRangeButton.setTitle(timeRangeString, forState: .Normal)
            UIView.animateWithDuration(0.3, animations: {
                self.heightConstraintOfTimeAndDayContainer.constant = 44
                self.centerYConstraintForPrimaryTimeDayView.constant = 0
                self.centerYConstraintForSecondaryTimeDayView.constant = 0
                self.view.layoutIfNeeded()
                }, completion: { (complete) in
                    self.secondaryDayAndTimeView.hidden = true
            })
        }
    }
    
    @objc private func zoomOut(sender:UIButton) {
        mapView.animateToCameraPosition(initialMapViewCamera)
        zoomOutButton.hidden = true
        show(mapOverlayViews: currentGroundOverlays)
        hide(mapOverlayViews: currentMapPolylines)
    }
    
    @IBAction func centerOnUserLocation(sender: UIButton) {
        userControl = false
        moveCameraToUserLocation()
    }
    
    func didTapMyLocationButtonForMapView(mapView: GMSMapView) -> Bool {
        userControl = false
        return true
    }
    
    func moveCameraToUserLocation() {
        if let currentCoordinate = dao.currentLocation?.coordinate {
            let camera = GMSCameraPosition.cameraWithTarget(currentCoordinate, zoom: 15)
            mapView.animateToCameraPosition(camera)
        }
    }
    
    // MARK: - MapView delegate
    func mapView(mapView: GMSMapView, idleAtCameraPosition position: GMSCameraPosition) {
        if mapView.camera.zoom < 15 {
            hide(mapOverlayViews: currentMapPolylines)
            show(mapOverlayViews: currentGroundOverlays)
            if mapView.camera.zoom < 13 { zoomOutButton.hidden = true }

        } else { getSignsForCurrentMapView() }
    }
    
    func mapView(mapView: GMSMapView, willMove gesture: Bool) {
        if (gesture) {
            userControl = true
        } else {
            userControl = false
        }
    }
    
    //MARK: - TextView delegate
    func textViewDidBeginEditing(textView: UITextView) { textView.selectedRange = NSMakeRange(0, textView.text.characters.count) }
    
    func textViewDidEndEditing(textView: UITextView) {
        do {
            if textView === primaryDayTextView || textView === secondaryDayTextView {
                textView.text = try SPTimeAndDayManager().dayString(fromTextInput: textView.text)
                if textView == primaryDayTextView { dao.primaryTimeAndDayString!.day = textView.text }
                else { dao.secondaryTimeAndDayString!.day = textView.text }
            } else if textView === primaryTimeTextView || textView === secondaryTimeTextView {
                textView.text = try SPTimeAndDayManager().timeString(fromTextInput: textView.text, format:timeFormat)
                if textView == primaryTimeTextView { dao.primaryTimeAndDayString!.time = textView.text }
                else { dao.secondaryTimeAndDayString!.time = textView.text }
            }
        } catch {
            if textView === primaryTimeTextView { textView.text = dao.primaryTimeAndDayString!.time }
            else if textView === primaryDayTextView { textView.text = dao.primaryTimeAndDayString!.day }
            else if textView === secondaryTimeTextView { textView.text = dao.secondaryTimeAndDayString!.time }
            else if textView === secondaryDayTextView { textView.text = dao.secondaryTimeAndDayString!.day }
        }
    }
}
