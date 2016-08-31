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
    @IBOutlet weak var swoopSwitch: UISwitch!
    @IBOutlet weak var mapView: GMSMapView!
    @IBOutlet weak var blurView: UIVisualEffectView!
    @IBOutlet weak var waitingLabel: UILabel!
    
    @IBOutlet weak var heightConstraintOfSearchContainer: NSLayoutConstraint!
    @IBOutlet weak var heightConstraintOfTimeAndDayContainer: NSLayoutConstraint!
    @IBOutlet weak var heightConstraintOfToolbar: NSLayoutConstraint!
    
    var zoomOutButton = UIButton.init(type:.RoundedRect)
    var initialMapViewCamera: GMSCameraPosition {
        return GMSCameraPosition.cameraWithTarget(CLLocationCoordinate2DMake(40.7193748839769, -73.9289110153913), zoom: initialZoom)
    }
    
    var currentMapPolylines = [GMSPolyline]()
    var currentGroundOverlays = [GMSGroundOverlay]()
    let timeAndDayManager = SPTimeAndDayManager()
    
    var searchContainerSegue: String { return "searchContainer" }
    var timeContainerSegue:String { return "timeContainer" }
    
    var isSearchTableViewPresent = false
    var isInTimeRangeMode = false
    var userControl = false
    var animatingFromCityView = true
    var toolbarsPresent = true
    var isKeyboardPresent = false
    var isPinchZooming = false
    var searchBarPresent = false
    var isZoomingIn = false
    
    var dao: SPDataAccessObject?
    var timeAndDayViewController: SPTimeAndDayViewController?
    var searchContainerViewController: SPSearchResultsViewController?
    
    var standardHeightOfToolOrSearchBar: CGFloat { return CGFloat(44.0) }
    var heightOfTimeContainerWhenInRangeMode: CGFloat { return CGFloat(70.0) }
    
    var waitingTextForCurrentMapViewLocations:String { return "Finding parking locations for current map view" }
    var waitingTextForTimeAndDateLocations:String {
        if isInTimeRangeMode {
            return "Finding parking locations between \(dao!.primaryTimeAndDayString!.time), \(dao!.primaryTimeAndDayString!.day) and \(dao!.secondaryTimeAndDayString!.time), \(dao!.secondaryTimeAndDayString!.day)"

        } else {
            return "Finding parking locations for \(dao?.primaryTimeAndDayString!.time), \(dao?.primaryTimeAndDayString?.day)"

        }
    }

    var zoomToSwitchOverlays: Float { return 14.5 }
    var streetZoom: Float { return 15.0 }
    var initialZoom: Float {
        return SPPolylineManager().initialZoom(forViewHeight: Double(mapView.frame.height))
    }
    
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
        dao!.setUpLocationManager()
        dao?.delegate = self
        setupInitialPrompt()
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
        notificationCenter.addObserver(self, selector: #selector(keyboardDidHide), name: UIKeyboardDidHideNotification, object: nil)
        notificationCenter.addObserver(self, selector: #selector(keyboardDidShow), name: UIKeyboardDidShowNotification, object: nil)
    }
    private func deregisterObservers() {
        let notificationCenter = NSNotificationCenter.defaultCenter()
        notificationCenter.removeObserver(self, name: UIKeyboardDidShowNotification, object: nil)
        notificationCenter.removeObserver(self, name: UIKeyboardDidHideNotification, object: nil)
    }
    @objc private func keyboardDidHide() { isKeyboardPresent = false }
    @objc private func keyboardDidShow() { isKeyboardPresent = true }
    
    //MARK: --Gesture

    private func setupGestures() {
//        hideKeyboardWhenTapAround()
        
        let singleTapGesture = UITapGestureRecognizer.init(target: self, action: #selector(singleTapHandler(_:)))
        singleTapGesture.numberOfTapsRequired = 1
        singleTapGesture.delegate = self
        singleTapGesture.cancelsTouchesInView = true
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
        tripleTapZoomGesture.delegate = self
        mapView.addGestureRecognizer(tripleTapZoomGesture)
        
        singleTapGesture.requireGestureRecognizerToFail(tripleTapZoomGesture)
        singleTapGesture.requireGestureRecognizerToFail(doubleTapZoomGesture)
        doubleTapZoomGesture.requireGestureRecognizerToFail(tripleTapZoomGesture)
        
        let pinchGesture = UIPinchGestureRecognizer.init(target: self, action: #selector(pinchZoom(_:)))
        pinchGesture.cancelsTouchesInView = false
        mapView.addGestureRecognizer(pinchGesture)
        
    }
    
    @objc private func zoomToDoubleTapOnMap(gesture:UITapGestureRecognizer) {
        let pointOnMap = gesture.locationInView(mapView)
        let camera = GMSCameraPosition.cameraWithTarget(mapView.projection.coordinateForPoint(pointOnMap), zoom: mapView.camera.zoom + 1)
        isZoomingIn = true
        mapView.animateToCameraPosition(camera)
    }
    
    @objc private func zoomOutDoubleTouchTapOnMap(gesture:UITapGestureRecognizer) {
        mapView.animateToZoom(mapView.camera.zoom - 1.5)
    }
    
    @objc private func zoomToTripleTapOnMap(gesture: UITapGestureRecognizer) {
        if mapView.camera.zoom < streetZoom {
            let pointOnMap = gesture.locationInView(mapView)
            let camera = GMSCameraPosition.cameraWithTarget(mapView.projection.coordinateForPoint(pointOnMap), zoom: streetZoom)
            isZoomingIn = true
            animateMap(toCameraPosition: camera, duration: 0.8)
            turnSwoopOn()
        } else {
            // Maybe add zoomout feature
        }
    }
    
    @objc private func singleTapHandler(gesture: UITapGestureRecognizer) {
        if isSearchTableViewPresent {
            searchContainerViewController!.hideSearchResultsTableView()
        }
        if isKeyboardPresent { view.endEditing(true) }
        else {
            if toolbarsPresent {
                if searchBarPresent { searchContainerViewController!.hideSearchBar() }
                UIView.animateWithDuration(0.3, animations: {
                    self.heightConstraintOfTimeAndDayContainer.constant = 0
                    self.heightConstraintOfToolbar.constant = 0
                    self.view.layoutIfNeeded()
                })
            } else {
                if searchBarPresent { searchContainerViewController!.showSearchBar() }
                UIView.animateWithDuration(0.3, animations: {
                    if self.isInTimeRangeMode { self.heightConstraintOfTimeAndDayContainer.constant = self.heightOfTimeContainerWhenInRangeMode }
                    else { self.heightConstraintOfTimeAndDayContainer.constant = self.standardHeightOfToolOrSearchBar }
                    self.heightConstraintOfToolbar.constant = self.standardHeightOfToolOrSearchBar
                    self.view.layoutIfNeeded()
                })

            }
            toolbarsPresent = !toolbarsPresent
        }
    }
    
    var scale:CGFloat = 0
    @objc private func pinchZoom(gesture:UIPinchGestureRecognizer) {
        if gesture.state == .Began { scale = gesture.scale }
        if gesture.state == .Changed {
            let zoomScale = ((gesture.scale - scale) / scale)
            let zoom = Float( zoomScale / 10 + 1) * mapView.camera.zoom
            mapView.animateToZoom(zoom)
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
        mapView.settings.tiltGestures = false
        mapView.delegate = self
        mapView.settings.consumesGesturesInView = false
    }
    
    
    func setupOtherViews() {
        heightConstraintOfSearchContainer.constant = 0
        view.layoutIfNeeded()
//        activityIndicator.startAnimating()
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
    
    //MARK: ---Initial prompt
    private func setupInitialPrompt() {
        blurView.hidden = true
        showBlurView(withLabel: waitingTextForTimeAndDateLocations)
        let alertController = UIAlertController.init(title: nil, message: "Where would you like to start looking for parking?", preferredStyle: .ActionSheet)
        let goToUserLocationAction = UIAlertAction.init(title: "My location", style: .Default, handler: nil)
        let goToSearchLocationAction = UIAlertAction.init(title: "Find a location", style: .Default) { (alertAction) in
            self.toggleSearchBar()
            self.searchContainerViewController?.searchBar.becomeFirstResponder()
        }
        let waitAction = UIAlertAction.init(title: "It's okay", style: .Default, handler: nil)
        alertController.addAction(goToUserLocationAction)
        alertController.addAction(goToSearchLocationAction)
        alertController.addAction(waitAction)
//        presentViewController(alertController, animated: true, completion: nil)
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
        adjustViewsToZoom()
        getSignsForCurrentMapView()
        if isZoomingIn { isZoomingIn = false }
        if isPinchZooming && currentMapPolylines.count > 0 { isPinchZooming = false }
    }
    
    func mapView(mapView: GMSMapView, didChangeCameraPosition position: GMSCameraPosition) {
        if (isPinchZooming && position.zoom < 15) || (isPinchZooming && swoopSwitch.on){
            getNewHeatMapOverlays()
        }
        if isZoomingIn {
            adjustViewsToZoom()
            getSignsForCurrentMapView()
        }
    }
    
    func mapView(mapView: GMSMapView, willMove gesture: Bool) {
        if (gesture) { userControl = true }
        else { userControl = false }
    }
    
    
    //MARK: - View animation methods
    //MARK: ---Searchbar animation
    @IBAction func showSearchBarButtonPressed(sender: UIBarButtonItem) {
        toggleSearchBar()
    }
    private func toggleSearchBar() {
        if !toolbarsPresent && !searchBarPresent { searchContainerViewController!.showSearchBar() }
        else if !searchBarPresent { searchContainerViewController!.showSearchBar() }
        else if searchBarPresent { searchContainerViewController!.hideSearchBar() }
        searchBarPresent = !searchBarPresent
    }
    //MARK: ---Blur View animation
    private func showBlurView(withLabel labelText:String) {
        UIView.animateWithDuration(0.2) { 
            self.waitingLabel.hidden = false
        }
        activityIndicator.startAnimating()
        waitingLabel.text = labelText
    }
    private func hideBlurView() {
        UIView.animateWithDuration(0.2) { 
            self.waitingLabel.hidden = true
        }
        activityIndicator.stopAnimating()
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
        if mapView.camera.zoom < zoomToSwitchOverlays { getNewHeatMapOverlays() }
        else { show(mapOverlayViews: currentMapPolylines, shouldHideOtherOverlay: true) }
        if mapView.camera.zoom <= initialZoom + 1 { zoomOutButton.hidden = true }
        else { zoomOutButton.hidden = false }
    }
    
    private func zoomMap(toCoordinate coordinate:CLLocationCoordinate2D?, zoom:Float) {
        if coordinate != nil {
            let camera = GMSCameraPosition.cameraWithTarget(coordinate!, zoom: zoom)
            mapView.animateToCameraPosition(camera)
            if isSearchTableViewPresent {
                searchContainerViewController!.hideSearchResultsTableView()
            }
            if isKeyboardPresent { view.endEditing(true) }
        } else {
            print("Cannot zoom, nil coordinate")
        }
    }
    
    //MARK: - Draw on map methods
    
    private func getSignsForCurrentMapView() {
        guard dao != nil else {
            print("DAO not passed to mapViewController, unable to check if isInNYC to getSignsForCurrentMapView")
            return
        }
        if mapView.camera.zoom >= zoomToSwitchOverlays && dao!.isInNYC(mapView) {
            showBlurView(withLabel: waitingTextForCurrentMapViewLocations)
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
            for view in views {  view.map = mapView }
            if shouldHideOtherOverlay {
                if MapOverlayType() is GMSPolyline { hide(mapOverlayViews: currentGroundOverlays) }
                else if MapOverlayType() is GMSGroundOverlay { hide(mapOverlayViews: currentMapPolylines) }
            }
        }
    }
    //MARK: - Methods that interact with view controllers
    //MARK: --Time and Day Container Controller delegate
    func timeViewControllerDidTapTimeRangeButton(isInRangeMode: Bool) {
        if isInRangeMode {
            UIView.animateWithDuration(0.3, animations: { 
                self.heightConstraintOfTimeAndDayContainer.constant = self.standardHeightOfToolOrSearchBar
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
    //MARK: --Search container controller delegate
    func searchContainer(toPerformDelegateAction delegateAction: SPNetworkingDelegateAction) {
        if delegateAction == .presentCoordinate { zoomMap(toCoordinate: dao?.searchCoordinate, zoom: 15) }
    }
    func searchContainerDidAdjust(height: CGFloat, isTableViewPresent: Bool) {
        UIView.animateWithDuration(0.2) { 
            self.heightConstraintOfSearchContainer.constant = height
            self.view.layoutIfNeeded()
        }
        self.isSearchTableViewPresent = isTableViewPresent
    }
    
    //MARK: --DAO delegate
    func dataAccessObject(dao: SPDataAccessObject, didUpdateAddressResults: [SPGoogleAddressResult]) {
        searchContainerViewController?.showSearchResultsTableView()
    }
    
    func dataAccessObject(dao: SPDataAccessObject, didSetSearchCoordinate coordinate: CLLocationCoordinate2D) {
        zoomMap(toCoordinate: coordinate, zoom: 15)
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
        hideBlurView()
    }
    
    //MARK: --Prepare for segue
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
}
