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



class SPMapViewController: UIViewController, CLLocationManagerDelegate, GMSMapViewDelegate, UITextViewDelegate, SPTimeViewControllerDelegate, UIGestureRecognizerDelegate, UITableViewDelegate, UITableViewDataSource, UISearchBarDelegate, SPGoogleNetworkingDelegate {
    @IBOutlet weak var timeAndDayContainerView: UIView!
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!
    @IBOutlet weak var swoopSwitch: UISwitch!
    @IBOutlet weak var mapView: GMSMapView!
    @IBOutlet weak var searchBar: UISearchBar!
    @IBOutlet weak var searchResultsTableView: UITableView!
    @IBOutlet weak var heightConstraintsOfSearchTableView: NSLayoutConstraint!
    @IBOutlet weak var searchBarHeight: NSLayoutConstraint!
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
    var cellReuseIdentifier:String { return "cellReuseIdentifier" }
    
    var isSearchTableViewPresent = false
    var isInTimeRangeMode = false
    var userControl = false
    var animatingFromCityView = true
    var toolbarsPresent = true
    var isKeyboardPresent = false
    var isPinchZooming = false
    var searchBarPresent = false
    
    var dao: SPDataAccessObject?
    var standardHeightOfToolOrSearchBar: CGFloat { return CGFloat(44.0) }
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
        setupOtherViews()
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
    @objc private func currentLocationsByTimeAndDaySet(notification:NSNotification) {
        getNewHeatMapOverlays()
        activityIndicator.stopAnimating()
    }
    @objc private func keyboardDidHide() { isKeyboardPresent = false }
    @objc private func keyboardDidShow() { isKeyboardPresent = true }
    
    //MARK: --Gesture

    private func setupGestures() {
//        hideKeyboardWhenTapAround()
        
        let singleTapGesture = UITapGestureRecognizer.init(target: self, action: #selector(singleTapHandler(_:)))
        singleTapGesture.numberOfTapsRequired = 1
        singleTapGesture.delegate = self
        singleTapGesture.cancelsTouchesInView = false
        mapView.addGestureRecognizer(singleTapGesture)
        
        let doubleTapZoomGesture = UITapGestureRecognizer.init(target: self, action: #selector(zoomToDoubleTapOnMap(_:)))
        doubleTapZoomGesture.numberOfTapsRequired = 2
        doubleTapZoomGesture.cancelsTouchesInView = false
        mapView.addGestureRecognizer(doubleTapZoomGesture)
        
        let doubleTouchTapZoomGesture = UITapGestureRecognizer.init(target: self, action: #selector(zoomOutDoubleTouchTapOnMap(_:)))
        doubleTouchTapZoomGesture.numberOfTapsRequired = 2
        doubleTouchTapZoomGesture.numberOfTouchesRequired = 2
        doubleTouchTapZoomGesture.cancelsTouchesInView = false
        mapView.addGestureRecognizer(doubleTouchTapZoomGesture)

        
        let tripleTapZoomGesture = UITapGestureRecognizer.init(target: self, action: #selector(zoomToTripleTapOnMap(_:)))
        tripleTapZoomGesture.numberOfTapsRequired = 3
        tripleTapZoomGesture.delegate = self
        tripleTapZoomGesture.cancelsTouchesInView = false
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
        mapView.animateToCameraPosition(camera)
    }
    
    @objc private func zoomOutDoubleTouchTapOnMap(gesture:UITapGestureRecognizer) {
        mapView.animateToZoom(mapView.camera.zoom - 1.5)
    }
    
    @objc private func zoomToTripleTapOnMap(gesture: UITapGestureRecognizer) {
        if mapView.camera.zoom < streetZoom {
            let pointOnMap = gesture.locationInView(mapView)
            let camera = GMSCameraPosition.cameraWithTarget(mapView.projection.coordinateForPoint(pointOnMap), zoom: streetZoom)
            mapView.animateToCameraPosition(camera)
            turnSwoopOn()
        } else {
            // Maybe add zoomout feature
        }
    }
    
    @objc private func singleTapHandler(gesture: UITapGestureRecognizer) {
        if isSearchTableViewPresent {
            hideSearchResultsTableView()
        }
        if isKeyboardPresent { view.endEditing(true) }
        else {
            if toolbarsPresent {
                if searchBarPresent { hideSearchBar() }
                UIView.animateWithDuration(0.3, animations: {
                    self.heightConstraintOfTimeAndDayContainer.constant = 0
                    self.heightConstraintOfToolbar.constant = 0
                    self.view.layoutIfNeeded()
                })
            } else {
                if searchBarPresent { showSearchBar() }
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
        searchBarHeight.constant = 0
        heightConstraintsOfSearchTableView.constant = 0
        view.layoutIfNeeded()
        activityIndicator.startAnimating()
        activityIndicator.hidesWhenStopped = true
        searchResultsTableView.registerClass(UITableViewCell.self, forCellReuseIdentifier: cellReuseIdentifier)
        searchResultsTableView.allowsSelection = true
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
        guard dao != nil else {
            print("DAO not passed to mapViewController, unable to get currentLocation to moveCameraToUserLocation")
            return
        }
        if let currentCoordinate = dao!.currentLocation?.coordinate {
            let camera = GMSCameraPosition.cameraWithTarget(currentCoordinate, zoom: streetZoom)
            mapView.animateToCameraPosition(camera)
        }
    }

    //MARK: - Search methods
    //MARK: -Search bar
    //MARK: ---Delegate
    func searchBarTextDidBeginEditing(searchBar: UISearchBar) {
        if dao?.addressResults.count > 0 { showSearchResultsTableView() }
    }
    func searchBar(searchBar: UISearchBar, textDidChange searchText: String) {
        if searchBar.text?.characters.count > 0 {
            let googleNetworking = SPGoogleNetworking()
            googleNetworking.delegate = self
            googleNetworking.autocomplete(searchBar.text!)
        }
    }
    func searchBarSearchButtonClicked(searchBar: UISearchBar) {
        if searchBar.text?.characters.count > 0 {
            let googleNetworking = SPGoogleNetworking()
            googleNetworking.delegate = self
            googleNetworking.searchAddress(searchBar.text!)
        }
    }
    
    //MARK: ---Animation
    @IBAction func showSearchBarButtonPressed(sender: UIBarButtonItem) {
        toggleSearchBar()
    }
    private func toggleSearchBar() {
        if !toolbarsPresent && !searchBarPresent { showSearchBar() }
        else if !searchBarPresent { showSearchBar() }
        else if searchBarPresent { hideSearchBar() }
        searchBarPresent = !searchBarPresent
    }
    private func showSearchBar() {
        UIView.animateWithDuration(0.3, animations: {
            self.searchBarHeight.constant = self.standardHeightOfToolOrSearchBar
            self.view.layoutIfNeeded()
        })
    }
    private func hideSearchBar() {
        UIView.animateWithDuration(0.3, animations: {
            self.searchBarHeight.constant = 0
            self.view.layoutIfNeeded()
        })
    }
    
    
    //MARK: -TableView Methods
    //MARK: ---Delegate/Datasource
    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard dao != nil else {
            print("DAO not passed to mapViewController, unable to get numberOfRowsInSection")
            return 0
        }
        return dao!.addressResults.count
    }
    func numberOfSectionsInTableView(tableView: UITableView) -> Int { return 1 }
    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        var cell = tableView.dequeueReusableCellWithIdentifier(cellReuseIdentifier)
        if cell != nil { cell = UITableViewCell.init(style: .Default, reuseIdentifier: cellReuseIdentifier) }
        cell?.textLabel!.text = dao?.addressResults[indexPath.row].address
        cell?.userInteractionEnabled = true
        return cell!
    }
    func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        guard dao != nil else {
            print("DAO not passed to mapViewController, unable to get search results for results tableview")
            return
        }
        let addressResult = dao!.addressResults[indexPath.row]
        searchBar.text = addressResult.address
        if addressResult.coordinate != nil {
            zoomMap(toCoordinate: addressResult.coordinate, zoom: 15)
        } else {
            let googleNetworking = SPGoogleNetworking()
            googleNetworking.delegate = self
            googleNetworking.geocode(addressResultWithoutCoordinate: addressResult)
        }
    }
    
    //MARK: ---Animation
    private func showSearchResultsTableView() {
        UIView.animateWithDuration(0.2) {
            let multipler = self.dao?.addressResults.count < 4 ? self.dao!.addressResults.count : 3
            self.heightConstraintsOfSearchTableView.constant = CGFloat(44 * multipler)
            self.view.layoutIfNeeded()
        }
        isSearchTableViewPresent = true
    }
    private func hideSearchResultsTableView() {
        UIView.animateWithDuration(0.2) {
            self.heightConstraintsOfSearchTableView.constant = 0
            self.view.layoutIfNeeded()
        }
        isSearchTableViewPresent = false
    }

    //MARK: - Google networking delegate
    func googleNetworking(googleNetwork: SPGoogleNetworking, didFinishWithResponse response: SPGoogleResponse, delegateAction: SPNetworkingDelegateAction) {
        if delegateAction == .presentAutocompleteResults {
            presentSearchResultsOnTableView(fromResponse: response)
        } else if delegateAction == .presentCoordinate {
            zoomMap(toCoordinate: response.googleAPIResponse?.placeIDCoordinate, zoom: 15)
        } else if delegateAction == .presentAddress {
            if response.googleAPIResponse?.addressResults?.count == 1 {
                zoomMap(toCoordinate: response.googleAPIResponse?.addressResults![0].coordinate, zoom: 15)
            } else {
                presentSearchResultsOnTableView(fromResponse: response)
            }
        }
    }

    private func presentSearchResultsOnTableView(fromResponse response:SPGoogleResponse) {
        if response.googleAPIResponse?.addressResults != nil {
            dao?.addressResults = (response.googleAPIResponse?.addressResults)!
            showSearchResultsTableView()
            searchResultsTableView.reloadData()
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
    
    private func zoomMap(toCoordinate coordinate:CLLocationCoordinate2D?, zoom:Float) {
        if coordinate != nil {
            let camera = GMSCameraPosition.cameraWithTarget(coordinate!, zoom: zoom)
            mapView.animateToCameraPosition(camera)
            if isSearchTableViewPresent {
                hideSearchResultsTableView()
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
        if mapView.camera.zoom >= streetZoom && dao!.isInNYC(mapView) {
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
    //MARK: - Methods that interact with time and day child view controller
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
