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



class SPMapViewController: UIViewController, CLLocationManagerDelegate, GMSMapViewDelegate, UITextViewDelegate, SPTimeViewControllerDelegate, UIGestureRecognizerDelegate, SPDataAccessObjectDelegate, SPSearchResultsViewControllerDelegate {
    @IBOutlet weak var timeAndDayContainerView: UIView!
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!
    @IBOutlet weak var streetViewSwitch: UISwitch!
    @IBOutlet weak var mapView: GMSMapView!
    @IBOutlet weak var waitingLabel: UILabel!
    @IBOutlet weak var searchContainerView: UIView!
    @IBOutlet weak var switchLabel: UIButton!
    @IBOutlet weak var greyOutMapView: UIView!
    @IBOutlet weak var bottomToolbar: UIToolbar!
    
    @IBOutlet weak var heightConstraintOfSearchContainer: NSLayoutConstraint!
    @IBOutlet weak var heightConstraintOfTimeAndDayContainer: NSLayoutConstraint!
    @IBOutlet weak var heightConstraintOfToolbar: NSLayoutConstraint!
    
    var zoomOutButton = UIButton.init(type:.RoundedRect)
    var initialMapViewCamera: GMSCameraPosition {
        return GMSCameraPosition.cameraWithTarget(CLLocationCoordinate2DMake(40.7193748839769, -73.9289110153913), zoom: initialZoom)
    }
    
    var currentMapPolylines = [GMSPolyline]()
    var currentGroundOverlays = [GMSGroundOverlay]()
    
    var searchContainerSegue: String { return "searchContainer" }
    var timeContainerSegue:String { return "timeContainer" }
    var switchLabelCity:String { return "City" }
    var switchLabelStreet: String { return "Street" }
    var waitingText:String { return "Finding street cleaning locations..." }
    
    var isSearchTableViewPresent = false
    var isInTimeRangeMode = false
    var userControl = false
    var animatingFromCityView = true
    var toolbarsPresent = true
    var isKeyboardPresent = false
    var isPinchZooming = false
    var isSearchBarPresent = false
    var isZoomingIn = false
    
    var dao: SPDataAccessObject?
    var timeAndDayViewController: SPTimeAndDayViewController?
    var searchContainerViewController: SPSearchResultsViewController?
    
    var standardHeightOfToolOrSearchBar: CGFloat { return CGFloat(44.0) }
    var heightOfTimeContainerWhenInRangeMode: CGFloat { return CGFloat(70.0) }
    
    var zoomToSwitchOverlays: Float { return streetZoom - 0.5 }
    var streetZoom: Float { return 16.0 }
    var initialZoom: Float {
        return SPPolylineManager().initialZoom(forViewHeight: Double(mapView.frame.height))
    }

    //MARK: - Override methods
    override func viewDidLoad() {
        super.viewDidLoad()
        setUpMap()
        setObservers()
        setUpButtons()
        setupGestures()
        setupOtherViews()
        guard dao != nil else {
            print("DAO not passed to mapViewController, unable to setupLocationManager")
            return
        }
        dao?.setUpLocationManager()
        dao?.delegate = self
    }
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    override func viewWillDisappear(animated: Bool) {
        super.viewWillDisappear(animated)
        NSNotificationCenter.defaultCenter().removeObserver(self)
    }
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        if segue.identifier == timeContainerSegue {
            timeAndDayViewController = segue.destinationViewController as? SPTimeAndDayViewController
            guard timeAndDayViewController != nil else {
                print("Destination ViewController for segue \(segue.identifier) is not time and day container controller. It is \(segue.destinationViewController)")
                return
            }
            timeAndDayViewController!.dao = dao
            timeAndDayViewController!.delegate = self
        } else if segue.identifier == searchContainerSegue {
            searchContainerViewController = segue.destinationViewController as? SPSearchResultsViewController
            guard searchContainerViewController != nil else {
                print("Destination ViewController for segue \(segue.identifier) is not time and day container controller. It is \(segue.destinationViewController)")
                return
            }
            dao?.delegate = self
            searchContainerViewController!.dao = dao
            searchContainerViewController!.delegate = self
        }
    }
    
    //MARK: - Setup/breakdown methods
    //MARK: --NotificationCenter
    private func setObservers() {
        let notificationCenter = NSNotificationCenter.defaultCenter()
        notificationCenter.addObserver(self, selector: #selector(keyboardDidHide), name: UIKeyboardDidHideNotification, object: nil)
        notificationCenter.addObserver(self, selector: #selector(keyboardDidShow), name: UIKeyboardDidShowNotification, object: nil)
    }
    @objc private func keyboardDidHide() { isKeyboardPresent = false }
    @objc private func keyboardDidShow() { isKeyboardPresent = true }
    
    //MARK: --Gestures
    private func setupGestures() {
        let singleTapGesture = UITapGestureRecognizer.init(target: self, action: #selector(singleTapHandler(_:)))
        singleTapGesture.numberOfTapsRequired = 1
        singleTapGesture.delegate = self
        singleTapGesture.cancelsTouchesInView = false
        view.addGestureRecognizer(singleTapGesture)
        
        let doubleTapZoomGesture = UITapGestureRecognizer.init(target: self, action: #selector(zoomToDoubleTapOnMap(_:)))
        doubleTapZoomGesture.numberOfTapsRequired = 2
        mapView.addGestureRecognizer(doubleTapZoomGesture)
        
        let doubleTouchTapZoomGesture = UITapGestureRecognizer.init(target: self, action: #selector(zoomOutDoubleTouchTapOnMap(_:)))
        doubleTouchTapZoomGesture.numberOfTapsRequired = 2
        doubleTouchTapZoomGesture.numberOfTouchesRequired = 2
        mapView.addGestureRecognizer(doubleTouchTapZoomGesture)

        
        let tripleTapZoomGesture = UITapGestureRecognizer.init(target: self, action: #selector(zoomToTripleTapOnMap(_:)))
        tripleTapZoomGesture.numberOfTapsRequired = 3
        mapView.addGestureRecognizer(tripleTapZoomGesture)
        
        singleTapGesture.requireGestureRecognizerToFail(tripleTapZoomGesture)
        singleTapGesture.requireGestureRecognizerToFail(doubleTapZoomGesture)
        doubleTapZoomGesture.requireGestureRecognizerToFail(tripleTapZoomGesture)
        
        let pinchGesture = UIPinchGestureRecognizer.init(target: self, action: #selector(pinchZoom(_:)))
        pinchGesture.cancelsTouchesInView = false
        mapView.addGestureRecognizer(pinchGesture)
    }
    @objc private func singleTapHandler(gesture: UITapGestureRecognizer) {
        if isSearchTableViewPresent {
            searchContainerViewController!.hideSearchResultsTableView()
        }
        if isKeyboardPresent { view.endEditing(true) }
        else {
            if CGRectContainsPoint(timeAndDayContainerView.frame, gesture.locationInView(view)) || CGRectContainsPoint(bottomToolbar.frame, gesture.locationInView(view)) { return }
            
            if toolbarsPresent {
                if isSearchBarPresent {
                    searchContainerViewController!.hideSearchBar()
                    isSearchBarPresent = true
                }
                UIView.animateWithDuration(standardAnimationDuration, animations: {
                    self.heightConstraintOfTimeAndDayContainer.constant = 0
                    self.heightConstraintOfToolbar.constant = 0
                    self.view.layoutIfNeeded()
                })
            } else {
                if isSearchBarPresent {
                    searchContainerViewController!.showSearchBar()
                }
                UIView.animateWithDuration(standardAnimationDuration, animations: {
                    if self.isInTimeRangeMode { self.heightConstraintOfTimeAndDayContainer.constant = self.heightOfTimeContainerWhenInRangeMode }
                    else { self.heightConstraintOfTimeAndDayContainer.constant = self.standardHeightOfToolOrSearchBar }
                    self.heightConstraintOfToolbar.constant = self.standardHeightOfToolOrSearchBar
                    self.view.layoutIfNeeded()
                })
            }
            toolbarsPresent = !toolbarsPresent
        }
    }
    @objc private func zoomToDoubleTapOnMap(gesture:UITapGestureRecognizer) {
        let pointOnMap = gesture.locationInView(mapView)
        let camera = GMSCameraPosition.cameraWithTarget(mapView.projection.coordinateForPoint(pointOnMap), zoom: mapView.camera.zoom + 1)
        isZoomingIn = true
        zoomMap(toCamera: camera)
    }
    @objc private func zoomOutDoubleTouchTapOnMap(gesture:UITapGestureRecognizer) {
        zoomMap(toZoom: mapView.camera.zoom - 1.5)
    }
    @objc private func zoomToTripleTapOnMap(gesture: UITapGestureRecognizer) {
        if mapView.camera.zoom < streetZoom {
            let pointOnMap = gesture.locationInView(mapView)
            let camera = GMSCameraPosition.cameraWithTarget(mapView.projection.coordinateForPoint(pointOnMap), zoom: streetZoom)
            isZoomingIn = true
            animateMap(toCameraPosition: camera, duration: 0.8)
        } else {
            // Maybe add zoomout feature
        }
    }
    var scale:CGFloat = 0
    @objc private func pinchZoom(gesture:UIPinchGestureRecognizer) {
        if gesture.state == .Began { scale = gesture.scale }
        if gesture.state == .Changed {
            let zoomScale = ((gesture.scale - scale) / scale)
            let zoom = Float( zoomScale / 10 + 1) * mapView.camera.zoom
            zoomMap(toZoom: zoom)
        } else { return }
        isPinchZooming = true
    }
    func gestureRecognizer(gestureRecognizer: UIGestureRecognizer, shouldReceiveTouch touch: UITouch) -> Bool {
        if touch.view != nil {
            if touch.view === zoomOutButton || touch.view!.isDescendantOfView(searchContainerView) { return false }
        }
        return true
    }
    
    //MARK: --Views
    private func setUpMap() {
        mapView.camera = initialMapViewCamera
        mapView.myLocationEnabled = true
        mapView.settings.myLocationButton = true
        mapView.settings.rotateGestures = false
        mapView.settings.zoomGestures = false
        mapView.settings.tiltGestures = false
        mapView.delegate = self
        mapView.settings.consumesGesturesInView = false
    }
    func setupOtherViews() {
        heightConstraintOfSearchContainer.constant = 0
        view.layoutIfNeeded()
        searchContainerView.userInteractionEnabled = true
        activityIndicator.hidesWhenStopped = true
        showWaitingView(withLabel: waitingText, isStreetView: false)
    }
    private func setUpButtons() {
        zoomOutButton.setTitle("Zoom Out", forState: .Normal)
        let buttonSize = zoomOutButton.intrinsicContentSize()
        zoomOutButton.frame = CGRectMake(mapView.bounds.origin.x + 8.0, mapView.bounds.origin.y + 8, buttonSize.width, buttonSize.height)
        zoomOutButton.backgroundColor = UIColor.whiteColor()
        zoomOutButton.hidden = true
        zoomOutButton.addTarget(self, action: #selector(zoomOut(_:)), forControlEvents: .TouchUpInside)
        mapView.addSubview(zoomOutButton)
    }
    
    //MARK: - Button Methods
    //MARK: --Swoop toggle
    @IBAction func toggleOverlaySwitch(sender: UISwitch) {
        setOverlayAndLabel()
    }
    private func turnStreetOverlayOn() {
        if !streetViewSwitch.on {
            streetViewSwitch.setOn(true, animated: true)
        }
        setOverlayAndLabel()
    }
    private func turnCityOverlayOn() {
        if streetViewSwitch.on  {
            streetViewSwitch.setOn(false, animated: true)
        }
        setOverlayAndLabel()
    }
    private func setOverlayAndLabel() {
        if streetViewSwitch.on {
            getSignsForCurrentMapView()
            switchLabel.setTitle(switchLabelStreet, forState: .Normal)
        } else {
            getNewHeatMapOverlays()
            switchLabel.setTitle(switchLabelCity, forState: .Normal)
        }
    }
    //MARK: --Searchbar toggle
    @IBAction func showSearchBarButtonPressed(sender: UIBarButtonItem) {
        toggleSearchBar()
    }
    private func toggleSearchBar() {
        if !toolbarsPresent && !isSearchBarPresent {
            searchContainerViewController?.showSearchBar()
        } else if !isSearchBarPresent {
            searchContainerViewController?.showSearchBar()
            searchContainerViewController?.searchBar.becomeFirstResponder()
        } else if isSearchBarPresent {
            searchContainerViewController?.hideSearchBar()
        }
    }
    //MARK: --Other buttons
    @objc private func zoomOut(sender:UIButton) {
        zoomMap(toCamera: initialMapViewCamera)
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
        guard dao != nil else {
            print("DAO not passed to mapViewController, unable to get currentLocation to moveCameraToUserLocation")
            return
        }
        if let currentCoordinate = dao!.currentLocation?.coordinate {
            let camera = GMSCameraPosition.cameraWithTarget(currentCoordinate, zoom: streetZoom)
            zoomMap(toCamera: camera)
        }
    }

    //MARK: - Animation methods

    
    //MARK: --Blur View animation
    private func showWaitingView(withLabel labelText:String, isStreetView:Bool) {
        if !isStreetView {
            greyOutMapView.hidden = false
            greyOutMapView.alpha = 0.3
        }
        activityIndicator.startAnimating()
        waitingLabel.hidden = false
        waitingLabel.text = labelText
    }
    private func hideWaitingView() {
        greyOutMapView.hidden = true
        waitingLabel.hidden = true
        activityIndicator.stopAnimating()
    }
    
    // MARK: --Map animation methods
    private func animateMap(toCameraPosition cameraPosition:GMSCameraPosition, duration:Float) {
        CATransaction.begin()
        CATransaction.setCompletionBlock { 
            self.adjustViewsToZoom()
        }
        CATransaction.setValue(duration, forKey: kCATransactionAnimationDuration)
        zoomMap(toCamera: cameraPosition)
        CATransaction.commit()
    }
    private func adjustViewsToZoom() {
        if mapView.camera.zoom < zoomToSwitchOverlays {
            turnCityOverlayOn()
        } else {
            turnStreetOverlayOn()
        }
        if mapView.camera.zoom <= initialZoom + 1 {
            zoomOutButton.hidden = true
        } else {
            zoomOutButton.hidden = false
        }
    }
    private func zoomMap(toCoordinate coordinate:CLLocationCoordinate2D?, zoom:Float) {
        if coordinate != nil {
            let camera = GMSCameraPosition.cameraWithTarget(coordinate!, zoom: zoom)
            zoomMap(toCamera: camera)
        } else {
            print("Cannot zoom, nil coordinate")
        }
    }
    private func zoomMap(toCamera camera:GMSCameraPosition) {
        mapView.animateToCameraPosition(camera)
        clearScreenForMapZoom()
    }
    private func zoomMap(toZoom zoom:Float) {
        mapView.animateToZoom(zoom)
        clearScreenForMapZoom()
    }
    private func clearScreenForMapZoom() {
        if isSearchTableViewPresent {
            searchContainerViewController!.hideSearchResultsTableView()
        }
        if isKeyboardPresent { view.endEditing(true) }
    }
    
    //MARK: -----Draw on map methods
    private func getSignsForCurrentMapView() {
        guard dao != nil else {
            print("DAO not passed to mapViewController, unable to check if isInNYC to getSignsForCurrentMapView")
            return
        }
        if mapView.camera.zoom >= zoomToSwitchOverlays && dao!.isInNYC(mapView) && streetViewSwitch.on {
            showWaitingView(withLabel: waitingText, isStreetView: true)
            dao!.getSigns(forCurrentMapView: mapView)
        }
    }
    private func getNewHeatMapOverlays() {
        guard dao != nil else {
            print("DAO not passed to mapViewController, unable to get locationsForDayAndTime to set currentGroundOverlays")
            return
        }
        currentGroundOverlays =  SPGroundOverlayManager().groundOverlays(forMap: mapView, forLocations: dao!.locationsForDayAndTime)
        show(mapOverlayViews: currentGroundOverlays, shouldHideOtherOverlay: true)
    }
    private func hide(mapOverlayViews views:[GMSOverlay]) {
        for view in views { view.map = nil }
    }
    private func show<MapOverlayType: GMSOverlay>(mapOverlayViews views:[MapOverlayType], shouldHideOtherOverlay:Bool) {
        if views.count > 0 {
            let date = NSDate()
            for view in views {  view.map = mapView }
            print("Time to draw/hide overlays on map: \(date.timeIntervalSinceNow)")
            if shouldHideOtherOverlay {
                if MapOverlayType() is GMSPolyline { hide(mapOverlayViews: currentGroundOverlays) }
                else if MapOverlayType() is GMSGroundOverlay { hide(mapOverlayViews: currentMapPolylines) }
            }
        }
    }
    
    // MARK: - Delegate Methods
    //MARK: --MapView delegate
    func mapView(mapView: GMSMapView, idleAtCameraPosition position: GMSCameraPosition) {
        adjustViewsToZoom()
        if isZoomingIn { isZoomingIn = false }
        if isPinchZooming && currentMapPolylines.count > 0 { isPinchZooming = false }
    }
    func mapView(mapView: GMSMapView, didChangeCameraPosition position: GMSCameraPosition) {
        if (isPinchZooming || isZoomingIn){
            adjustViewsToZoom()
        }
    }
    func mapView(mapView: GMSMapView, willMove gesture: Bool) {
        if (gesture) { userControl = true }
        else { userControl = false }
    }
    
    //MARK: -----DAO delegate
    func dataAccessObject(dao: SPDataAccessObject, didUpdateAddressResults: [SPGoogleAddressResult]) {
        searchContainerViewController?.showSearchResultsTableView()
    }
    func dataAccessObject(dao: SPDataAccessObject, didSetSearchCoordinate coordinate: CLLocationCoordinate2D) {
        zoomMap(toCoordinate: coordinate, zoom: streetZoom)
    }
    func dataAccessObject(dao: SPDataAccessObject, didSetLocations locations: [SPLocation], forQueryType: SPSQLLocationQueryTypes) {
        if forQueryType == .getLocationsForCurrentMapView {
            if currentMapPolylines.count > 0 { hide(mapOverlayViews: currentMapPolylines) }
            let date = NSDate()
            currentMapPolylines = SPPolylineManager().polylines(forCurrentLocations: dao.currentMapViewLocations, zoom: Double(mapView.camera.zoom))
            print("Time to initialize polylines: \(date.timeIntervalSinceNow)")
            
            if currentMapPolylines.count > 0 && mapView.camera.zoom >= zoomToSwitchOverlays {
                show(mapOverlayViews: currentMapPolylines, shouldHideOtherOverlay: true)
            }
        } else if forQueryType == .getLocationsForTimeAndDay {
            getNewHeatMapOverlays()
        }
        hideWaitingView()
    }

    //MARK: -- Methods that interact with child view controllers
    //MARK: -----Time and Day Container Controller delegate
    func timeViewControllerDidTapTimeRangeButton(isInRangeMode: Bool) {
        if isInRangeMode {
            UIView.animateWithDuration(standardAnimationDuration, animations: {
                self.heightConstraintOfTimeAndDayContainer.constant = self.standardHeightOfToolOrSearchBar
                self.view.layoutIfNeeded()
            })
        } else {
            UIView.animateWithDuration(standardAnimationDuration, animations: {
                self.heightConstraintOfTimeAndDayContainer.constant = self.heightOfTimeContainerWhenInRangeMode
                self.view.layoutIfNeeded()
            })
        }
        isInTimeRangeMode = !isInRangeMode
    }
    //MARK: -----Search container controller delegate
    func searchContainer(toPerformDelegateAction delegateAction: SPNetworkingDelegateAction) {
        if delegateAction == .presentCoordinate {
            zoomMap(toCoordinate: dao?.searchCoordinate, zoom: streetZoom)
        }
    }
    func searchContainerHeightShouldAdjust(height: CGFloat, isTableViewPresent: Bool, isSearchBarPresent: Bool) -> Bool {
        UIView.animateWithDuration(standardAnimationDuration) {
            self.heightConstraintOfSearchContainer.constant = height
            self.view.layoutIfNeeded()
        }
        self.isSearchTableViewPresent = isTableViewPresent
        self.isSearchBarPresent = isSearchBarPresent
        return true
    }
}
