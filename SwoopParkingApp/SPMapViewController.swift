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



class SPMapViewController: UIViewController, CLLocationManagerDelegate, GMSMapViewDelegate, UITextViewDelegate, SPTimeViewControllerDelegate {
    
    @IBOutlet weak var timeAndDayContainerView: UIView!
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!
    @IBOutlet weak var swoopSwitch: UISwitch!
    @IBOutlet weak var mapView: GMSMapView!
    @IBOutlet weak var heightConstraintOfTimeAndDayContainer: NSLayoutConstraint!

    var zoomOutButton = UIButton.init(type:.RoundedRect)

    var currentMapPolylines = [GMSPolyline]()
    var currentGroundOverlays = [GMSGroundOverlay]()
    let timeAndDayManager = SPTimeAndDayManager()
    var timeContainerSegue:String { return "timeContainer" }
    var isInTimeRangeMode = false
    var userControl = false
    var animatingFromCityView = true
    var dao: SPDataAccessObject?
    var initialMapViewCamera: GMSCameraPosition {
        let zoom = SPPolylineManager().initialZoom(forViewWidth: Double(view.frame.width))
        return GMSCameraPosition.cameraWithTarget(CLLocationCoordinate2DMake(40.7193748839769, -73.9289110153913), zoom: zoom)
    }
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setUpMap()
        setObservers()
        dao!.setUpLocationManager()
        setUpButtons()
        setupGestures()
        setupViews()
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    
    override func viewWillDisappear(animated: Bool) {
        super.viewWillDisappear(animated)
        deregisterObservers()
    }
    
    //MARK: - Setup/breakdown methods
    
    private func deregisterObservers() {
        let notificationCenter = NSNotificationCenter.defaultCenter()
        notificationCenter.removeObserver(self, name: kSPSQLiteCoordinateQuery, object: nil)
        notificationCenter.removeObserver(self, name: kSPSQLiteTimeAndDayQuery, object: nil)
        notificationCenter.removeObserver(self, name: kSPSQLiteTimeAndDayLocationsOnlyQuery, object: nil)
    }
    
    private func setupGestures() {
        hideKeyboardWhenTapAround()
        let touchGesture = UITapGestureRecognizer.init(target: self, action: #selector(zoomToTapOnMap(_:)))
        touchGesture.numberOfTapsRequired = 2
        mapView.addGestureRecognizer(touchGesture)
    }
    @objc private func zoomToTapOnMap(gesture:UITapGestureRecognizer) {
        if mapView.camera.zoom < 15 {
            let pointOnMap = gesture.locationInView(mapView)
            print("Gesture selector touch location: \(pointOnMap). coordinate: \(mapView.projection.coordinateForPoint(pointOnMap))")
            let camera = GMSCameraPosition.cameraWithTarget(mapView.projection.coordinateForPoint(pointOnMap), zoom: 15.0)
            mapView.animateToCameraPosition(camera)
            turnSwoopOn()
        }
    }
    
    override func touchesEnded(touches: Set<UITouch>, withEvent event: UIEvent?) {
        for touch in touches {
            print("view delegate touch location: \(touch.locationInView(mapView))")
        }
    }
    
    private func setUpMap() {
        mapView.camera = initialMapViewCamera
        mapView.myLocationEnabled = true
        mapView.settings.myLocationButton = true
        mapView.settings.rotateGestures = false
        mapView.delegate = self
        mapView.settings.consumesGesturesInView = false
    }
    
    private func setObservers() {
        let notificationCenter = NSNotificationCenter.defaultCenter()
        notificationCenter.addObserver(self, selector: #selector(currentLocationsByCoordinateSet), name: kSPSQLiteCoordinateQuery, object: nil)
        notificationCenter.addObserver(self, selector: #selector(currentLocationsByTimeAndDaySet), name: kSPSQLiteTimeAndDayQuery, object: nil)
        notificationCenter.addObserver(self, selector: #selector(currentLocationsByTimeAndDaySet), name: kSPSQLiteTimeAndDayLocationsOnlyQuery, object: nil)
    }
    
    func setupViews() {
        activityIndicator.startAnimating()
        activityIndicator.hidesWhenStopped = true
    }
    
    private func setUpButtons() {
        zoomOutButton.setTitle("Zoom Out", forState: .Normal)
        let buttonSize = zoomOutButton.intrinsicContentSize()
        zoomOutButton.frame = CGRectMake(mapView.bounds.origin.x + 8.0, mapView.bounds.origin.y + 8, buttonSize.width, buttonSize.height)
        zoomOutButton.backgroundColor = UIColor.whiteColor()
        zoomOutButton.hidden = true
        zoomOutButton.addTarget(self, action: #selector(zoomOut), forControlEvents: .TouchUpInside)
        mapView.addSubview(zoomOutButton)
    }
    
    // MARK: - Notification Methods
    @objc private func currentLocationsByCoordinateSet(notification:NSNotification) {
        if currentMapPolylines.count > 0 {
            hide(mapOverlayViews: currentMapPolylines)
        }
//        let date = NSDate()
        currentMapPolylines = SPPolylineManager().polylines(forCurrentLocations: dao!.currentMapViewLocations, zoom: Double(mapView.camera.zoom))
//        print("Time lapse to initialize polylines: \(date.timeIntervalSinceNow)")

        if currentMapPolylines.count > 0 && mapView.camera.zoom >= 15 {
            hide(mapOverlayViews: currentGroundOverlays)
            show(mapOverlayViews: currentMapPolylines)
        }
        zoomOutButton.hidden = false
        activityIndicator.stopAnimating()
    }
    
    @objc private func currentLocationsByTimeAndDaySet(notification:NSNotification) {
        getNewHeatMapOverlays()
        activityIndicator.stopAnimating()
    }
    
    private func getNewHeatMapOverlays() {
        hide(mapOverlayViews: currentGroundOverlays)
        currentGroundOverlays =  SPGroundOverlayManager().groundOverlays(forMap: mapView, forLocations: dao!.locationsForDayAndTime)
        show(mapOverlayViews: currentGroundOverlays)
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
        if swoopSwitch.on && mapView.camera.zoom >= 15 && dao!.isInNYC(mapView) {
            activityIndicator.startAnimating()
            dao!.getSigns(forCurrentMapView: mapView)
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
    
    private func moveCameraToUserLocation() {
        guard dao != nil else { print("No ")) }
        if let currentCoordinate = dao!.currentLocation?.coordinate {
            let camera = GMSCameraPosition.cameraWithTarget(currentCoordinate, zoom: 15)
            mapView.animateToCameraPosition(camera)
        }
    }
    
    // MARK: - MapView delegate
    func mapView(mapView: GMSMapView, idleAtCameraPosition position: GMSCameraPosition) {
        if mapView.camera.zoom < 15 {
            hide(mapOverlayViews: currentMapPolylines)
            show(mapOverlayViews: currentGroundOverlays)
            if mapView.camera.zoom < 13 {
                zoomOutButton.hidden = true
                getNewHeatMapOverlays()
            }
            if mapView.camera.zoom < 12 { animatingFromCityView = true }
        } else {
            getSignsForCurrentMapView()
        }
    }
    
    func mapView(mapView: GMSMapView, didChangeCameraPosition position: GMSCameraPosition) {
        if animatingFromCityView{
            if mapView.camera.zoom < 15 {
                hide(mapOverlayViews: currentMapPolylines)
                show(mapOverlayViews: currentGroundOverlays)
                if mapView.camera.zoom < 13 { zoomOutButton.hidden = true }
                
            } else {
                getSignsForCurrentMapView()
                animatingFromCityView = false
            }
        }
    }
    
    func mapView(mapView: GMSMapView, willMove gesture: Bool) {
        if (gesture) { userControl = true }
        else { userControl = false }
    }
    
    //MARK: - Hide/Show GMSPolyline/GroundOverLays
    private func hide<MapOverlayType: GMSOverlay>(mapOverlayViews views:[MapOverlayType]) {
        for view in views { view.map = nil }
    }
    private func show<MapOverlayType: GMSOverlay>(mapOverlayViews views:[MapOverlayType]) {
        if views.count > 0 {
//            let date = NSDate()
            for view in views {  view.map = mapView }
//            print("Time lapse for drawing overlays: \(date.timeIntervalSinceNow)")
        }
    }

    //MARK: - Methods that interact with time and day controller
    
    //MARK: Time and Day Container Controller delegate
    func timeViewControllerDidTapTimeRangeButton(isInRangeMode: Bool) {
        if isInRangeMode {
            UIView.animateWithDuration(0.3, animations: { 
                self.heightConstraintOfTimeAndDayContainer.constant = 44
                self.view.layoutIfNeeded()
            })
        } else {
            UIView.animateWithDuration(0.3, animations: { 
                self.heightConstraintOfTimeAndDayContainer.constant = 74
                self.view.layoutIfNeeded()
            })
        }
    }
    
    //MARK: Prepare for segue
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        if segue.identifier == timeContainerSegue {
            guard let timeContainerViewController = segue.destinationViewController as? SPTimeAndDayViewController else {
                print("Destination ViewController is not time and day container controller. It is \(segue.destinationViewController)")
                return
            }
            timeContainerViewController.dao = dao
            timeContainerViewController.delegate = self
        }
    }
}
