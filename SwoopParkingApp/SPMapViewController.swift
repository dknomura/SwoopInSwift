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



class SPMapViewController: UIViewController, CLLocationManagerDelegate, GMSMapViewDelegate, UITextViewDelegate, SPTimeViewControllerDelegate, UIGestureRecognizerDelegate {
    @IBOutlet weak var timeAndDayContainerView: UIView!
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!
    @IBOutlet weak var swoopSwitch: UISwitch!
    @IBOutlet weak var mapView: GMSMapView!
    @IBOutlet weak var heightConstraintOfTimeAndDayContainer: NSLayoutConstraint!
    @IBOutlet weak var heightConstraintOfToolbar: NSLayoutConstraint!
    var zoomOutButton = UIButton.init(type:.RoundedRect)
    var initialMapViewCamera: GMSCameraPosition {
        return GMSCameraPosition.cameraWithTarget(CLLocationCoordinate2DMake(40.7193748839769, -73.9289110153913), zoom: initialZoom)
    }
    
    var currentMapPolylines = [GMSPolyline]()
    var currentGroundOverlays = [GMSGroundOverlay]()
    let timeAndDayManager = SPTimeAndDayManager()
    var timeContainerSegue:String { return "timeContainer" }
    
    var isInTimeRangeMode = false
    var userControl = false
    var animatingFromCityView = true
    var toolbarsHidden = false
    var isKeyboardPresent = false
    var isPinchZooming = false
    
    var dao: SPDataAccessObject?
    var heightOfToolbar: CGFloat { return CGFloat(44.0) }
    var heightOfTimeContainerWhenInRangeMode: CGFloat { return CGFloat(70.0) }

    var streetZoom: Float { return 15.0 }
    var initialZoom: Float {
        return SPPolylineManager().initialZoom(forViewHeight: Double(mapView.frame.height))
    }
    var zoomLevelToSwitchOverlayType: Float { return 14.0 }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setUpMap()
        setObservers()
        setUpButtons()
        setupGestures()
        setupViews()
        guard dao != nil else {
            print("DAO not passed to mapViewController, unable to setupLocationManager")
            return
        }
        dao!.setUpLocationManager()
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    
    override func viewWillDisappear(animated: Bool) {
        super.viewWillDisappear(animated)
        deregisterObservers()
    }
    
    //MARK: - Setup/breakdown methods
    
    //MARK: --NotificationCenter
    
    private func setObservers() {
        let notificationCenter = NSNotificationCenter.defaultCenter()
        notificationCenter.addObserver(self, selector: #selector(currentLocationsByCoordinateSet), name: kSPSQLiteCoordinateQuery, object: nil)
        notificationCenter.addObserver(self, selector: #selector(currentLocationsByTimeAndDaySet), name: kSPSQLiteTimeAndDayQuery, object: nil)
        notificationCenter.addObserver(self, selector: #selector(currentLocationsByTimeAndDaySet), name: kSPSQLiteTimeAndDayLocationsOnlyQuery, object: nil)
        notificationCenter.addObserver(self, selector: #selector(keyboardDidHide), name: UIKeyboardDidHideNotification, object: nil)
        notificationCenter.addObserver(self, selector: #selector(keyboardDidShow), name: UIKeyboardDidShowNotification, object: nil)
    }
    private func deregisterObservers() {
        let notificationCenter = NSNotificationCenter.defaultCenter()
        notificationCenter.removeObserver(self, name: kSPSQLiteCoordinateQuery, object: nil)
        notificationCenter.removeObserver(self, name: kSPSQLiteTimeAndDayQuery, object: nil)
        notificationCenter.removeObserver(self, name: kSPSQLiteTimeAndDayLocationsOnlyQuery, object: nil)
        notificationCenter.removeObserver(self, name: UIKeyboardDidShowNotification, object: nil)
        notificationCenter.removeObserver(self, name: UIKeyboardDidHideNotification, object: nil)
    }
    

    // MARK: ----Notification Methods
    @objc private func currentLocationsByCoordinateSet(notification:NSNotification) {
        if currentMapPolylines.count > 0 { hide(mapOverlayViews: currentMapPolylines) }
        guard dao != nil else {
            print("DAO not passed to mapViewController, unable to get currentMapViewLocations for currentMapPolylines")
            return
        }
        let date = NSDate()
        currentMapPolylines = SPPolylineManager().polylines(forCurrentLocations: dao!.currentMapViewLocations, zoom: Double(mapView.camera.zoom))
        print("Time to initialize polylines: \(date.timeIntervalSinceNow)")
        
        if currentMapPolylines.count > 0 && mapView.camera.zoom >= streetZoom {
            show(mapOverlayViews: currentMapPolylines, shouldHideOtherOverlay: true)
        }
        activityIndicator.stopAnimating()
    }
    
    @objc private func keyboardDidHide() { isKeyboardPresent = false }
    @objc private func keyboardDidShow() { isKeyboardPresent = true }
    
    @objc private func currentLocationsByTimeAndDaySet(notification:NSNotification) {
        getNewHeatMapOverlays()
        activityIndicator.stopAnimating()
    }
    
    //MARK: --Gesture

    private func setupGestures() {
        hideKeyboardWhenTapAround()
        
        let singleTapHideToolbarsGesture = UITapGestureRecognizer.init(target: self, action: #selector(tapToToogleToolbarHideOrHideKeyboard(_:)))
        singleTapHideToolbarsGesture.numberOfTapsRequired = 1
        singleTapHideToolbarsGesture.delegate = self
        mapView.addGestureRecognizer(singleTapHideToolbarsGesture)
        
        let doubleTapZoomGesture = UITapGestureRecognizer.init(target: self, action: #selector(zoomToDoubleTapOnMap(_:)))
        doubleTapZoomGesture.numberOfTapsRequired = 2
        mapView.addGestureRecognizer(doubleTapZoomGesture)
        
        let tripleTapZoomGesture = UITapGestureRecognizer.init(target: self, action: #selector(zoomToTripleTapOnMap(_:)))
        tripleTapZoomGesture.numberOfTapsRequired = 3
        tripleTapZoomGesture.delegate = self
        mapView.addGestureRecognizer(tripleTapZoomGesture)

        singleTapHideToolbarsGesture.requireGestureRecognizerToFail(tripleTapZoomGesture)
        singleTapHideToolbarsGesture.requireGestureRecognizerToFail(doubleTapZoomGesture)
        doubleTapZoomGesture.requireGestureRecognizerToFail(tripleTapZoomGesture)
        
        let pinchGesture = UIPinchGestureRecognizer.init(target: self, action: #selector(pinchZoom(_:)))
        mapView.addGestureRecognizer(pinchGesture)
        
    }
    
    @objc private func zoomToDoubleTapOnMap(gesture:UITapGestureRecognizer) {
        let pointOnMap = gesture.locationInView(mapView)
        let camera = GMSCameraPosition.cameraWithTarget(mapView.projection.coordinateForPoint(pointOnMap), zoom: mapView.camera.zoom + 1)
        mapView.animateToCameraPosition(camera)
    }
    
    @objc private func zoomToTripleTapOnMap(gesture: UITapGestureRecognizer) {
        if mapView.camera.zoom < streetZoom {
            let pointOnMap = gesture.locationInView(mapView)
            let camera = GMSCameraPosition.cameraWithTarget(mapView.projection.coordinateForPoint(pointOnMap), zoom: streetZoom)
            mapView.animateToCameraPosition(camera)
            turnSwoopOn()
        } else {
        
        }
    }
    
    @objc private func tapToToogleToolbarHideOrHideKeyboard(gesture: UITapGestureRecognizer) {
        if isKeyboardPresent { view.endEditing(true) }
        else {
            if toolbarsHidden {
                UIView.animateWithDuration(0.2, animations: {
                    if self.isInTimeRangeMode { self.heightConstraintOfTimeAndDayContainer.constant = self.heightOfTimeContainerWhenInRangeMode }
                    else { self.heightConstraintOfTimeAndDayContainer.constant = self.heightOfToolbar }
                    self.heightConstraintOfToolbar.constant = self.heightOfToolbar
                    self.view.layoutIfNeeded()
                })
                toolbarsHidden = false
            } else {
                UIView.animateWithDuration(0.2, animations: {
                    self.heightConstraintOfTimeAndDayContainer.constant = 0
                    self.heightConstraintOfToolbar.constant = 0
                    self.view.layoutIfNeeded()
                })
                toolbarsHidden = true
            }
        }
    }
    
    var scale:CGFloat = 0
    @objc private func pinchZoom(gesture:UIPinchGestureRecognizer) {
        if gesture.state == .Began { scale = gesture.scale }
        if gesture.state == .Changed {
            let zoomScale = ((gesture.scale - scale) / scale)
            let zoom: Float
            if zoomScale > 0 {
                zoom = Float( zoomScale / 20 + 1) * mapView.camera.zoom
            } else { zoom = Float( zoomScale / 10 + 1) * mapView.camera.zoom }
            mapView.animateToZoom(zoom)
//            if zoomScale > 1 {
//                let pointOfGesture = gesture.locationInView(mapView)
//                let coordinateOfGesture = mapView.projection.coordinateForPoint(pointOfGesture)
//                let camera = GMSCameraPosition.cameraWithTarget(coordinateOfGesture, zoom: zoom)
//                mapView.animateToCameraPosition(camera)
//            } else { mapView.animateToZoom(zoom) }
        } else { return }
        isPinchZooming = true
    }
    
    //MARK: --Views
    private func setUpMap() {
        mapView.camera = initialMapViewCamera
        mapView.myLocationEnabled = true
        mapView.settings.myLocationButton = true
        mapView.settings.rotateGestures = false
        mapView.settings.zoomGestures = false
        mapView.delegate = self
        mapView.settings.consumesGesturesInView = false
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
    
    //    MARK: - Button Methods
    
    //MARK: --Swoop toggle
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
    
    //MARK: --Other buttons
    @objc private func zoomOut(sender:UIButton) {
        mapView.animateToCameraPosition(initialMapViewCamera)
        show(mapOverlayViews: currentGroundOverlays, shouldHideOtherOverlay: true)
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
//        guard dao != nil else { print("No ")) }
        guard dao != nil else {
            print("DAO not passed to mapViewController, unable to get currentLocation to moveCameraToUserLocation")
            return
        }
        if let currentCoordinate = dao!.currentLocation?.coordinate {
            let camera = GMSCameraPosition.cameraWithTarget(currentCoordinate, zoom: streetZoom)
            mapView.animateToCameraPosition(camera)
        }
    }
    
    // MARK: - MapView delegate
    func mapView(mapView: GMSMapView, idleAtCameraPosition position: GMSCameraPosition) {
        if isPinchZooming { isPinchZooming = false }
        adjustViewsToZoom()
        if mapView.camera.zoom < zoomLevelToSwitchOverlayType {
            getNewHeatMapOverlays()
            if mapView.camera.zoom < 12 { animatingFromCityView = true }
        }
        getSignsForCurrentMapView()
    }
    
    func mapView(mapView: GMSMapView, didChangeCameraPosition position: GMSCameraPosition) {
        if isPinchZooming {
            getNewHeatMapOverlays()
        }
//        if animatingFromCityView{
//            if isPinchZooming {
//                adjustViewsToZoom()
//            }
//            if mapView.camera.zoom < zoomLevelToSwitchOverlayType {
//                show(mapOverlayViews: currentGroundOverlays, shouldHideOtherOverlay: true)
//            } else {
//                getSignsForCurrentMapView()
//                animatingFromCityView = false
//            }
//        }
    }
    
    func mapView(mapView: GMSMapView, willMove gesture: Bool) {
        if (gesture) { userControl = true }
        else { userControl = false }
    }
    
    // MARK: - Map animation methods
    
    private func animateMap(toCameraPosition cameraPosition:GMSCameraPosition, duration:Float) {
        CATransaction.begin()
        CATransaction.setCompletionBlock { 
            self.adjustViewsToZoom()
        }
        CATransaction.setValue(duration, forKey: kCATransactionAnimationDuration)
        mapView.animateToCameraPosition(cameraPosition)
        CATransaction.commit()
    }
    
    private func adjustViewsToZoom() {
        if mapView.camera.zoom < zoomLevelToSwitchOverlayType { getNewHeatMapOverlays()
        } else { show(mapOverlayViews: currentMapPolylines, shouldHideOtherOverlay: true) }
        if mapView.camera.zoom <= initialZoom + 1 { zoomOutButton.hidden = true }
        else { zoomOutButton.hidden = false }
    }
    
    private func zoomMap(toCameraPosition camera:GMSCameraPosition) {
        isPinchZooming = true
        mapView.animateToCameraPosition(camera)
    }
    
    //MARK: - Draw on map methods
    
    private func getSignsForCurrentMapView() {
        guard dao != nil else {
            print("DAO not passed to mapViewController, unable to check if isInNYC to getSignsForCurrentMapView")
            return
        }
        if swoopSwitch.on && mapView.camera.zoom >= streetZoom && dao!.isInNYC(mapView) {
            activityIndicator.startAnimating()
            dao!.getSigns(forCurrentMapView: mapView)
        }
    }
    
    private func getNewHeatMapOverlays() {
        hide(mapOverlayViews: currentGroundOverlays)
        guard dao != nil else {
            print("DAO not passed to mapViewController, unable to get locationsForDayAndTime to set currentGroundOverlays")
            return
        }
        currentGroundOverlays =  SPGroundOverlayManager().groundOverlays(forMap: mapView, forLocations: dao!.locationsForDayAndTime)
        show(mapOverlayViews: currentGroundOverlays, shouldHideOtherOverlay: true)
    }
    

    //MARK: --Hide/Show GMSPolyline/GroundOverLays
    private func hide<MapOverlayType: GMSOverlay>(mapOverlayViews views:[MapOverlayType]) {
        for view in views { view.map = nil }
    }
    private func show<MapOverlayType: GMSOverlay>(mapOverlayViews views:[MapOverlayType], shouldHideOtherOverlay:Bool) {
        if views.count > 0 {
//            let date = NSDate()
            for view in views {  view.map = mapView }
//            print("Time lapse for drawing overlays: \(date.timeIntervalSinceNow)")
            if shouldHideOtherOverlay {
                if MapOverlayType() is GMSPolyline { hide(mapOverlayViews: currentGroundOverlays) }
                else if MapOverlayType() is GMSGroundOverlay { hide(mapOverlayViews: currentMapPolylines) }
            }
        }
    }
    //MARK: - Methods that interact with time and day controller
    
    //MARK: --Time and Day Container Controller delegate
    func timeViewControllerDidTapTimeRangeButton(isInRangeMode: Bool) {
        if isInRangeMode {
            UIView.animateWithDuration(0.3, animations: { 
                self.heightConstraintOfTimeAndDayContainer.constant = self.heightOfToolbar
                self.view.layoutIfNeeded()
            })
        } else {
            UIView.animateWithDuration(0.3, animations: {
                self.heightConstraintOfTimeAndDayContainer.constant = self.heightOfTimeContainerWhenInRangeMode
                self.view.layoutIfNeeded()
            })
        }
        isInTimeRangeMode = !isInRangeMode
    }
    
    //MARK: --Prepare for segue
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
