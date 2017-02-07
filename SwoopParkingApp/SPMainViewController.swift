    	//
//  SPMainViewController.swift
//  SwoopParkingApp
//
//  Created by Daniel Nomura on 10/5/16.
//  Copyright © 2016 Daniel Nomura. All rights reserved.
//

import Foundation
import GoogleMaps
import DNTimeAndDay

class SPMainViewController: UIViewController, UIGestureRecognizerDelegate, SPDataAccessObjectDelegate, SPSearchResultsViewControllerDelegate, SPMapViewControllerDelegate, SPTimeViewControllerDelegate, SignsCollectionViewControllerDelegate, InjectableViewController {
    @IBOutlet weak var timeAndDayContainerView: UIView!
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!

    @IBOutlet weak var heightConstraintOfSearchContainer: NSLayoutConstraint!
    @IBOutlet weak var heightConstraintOfTimeAndDayContainer: NSLayoutConstraint!
    @IBOutlet weak var heightConstraintOfToolbar: NSLayoutConstraint!
    @IBOutlet weak var waitingLabel: UILabel!
    @IBOutlet weak var searchContainerView: UIView!
    @IBOutlet weak var signCollectionContainerView: UIView!
    
    @IBOutlet weak var constraintOfToolbarToBottom: NSLayoutConstraint!
    @IBOutlet weak var greyOutMapView: UIView!

    private var searchContainerSegue: String { return "searchContainer" }
    private var timeContainerSegue:String { return "timeContainer" }
    private var mapContainerSegue: String { return "mapContainer" }
    private var collectionViewContainerSegue: String { return "collectionViewController" }
    
    private var waitingText:String { return "Finding street cleaning locations and rendering map..." }

    private var isSearchTableViewPresent = false
    private var toolbarsPresent = true
    private var isKeyboardPresent = false
    private var isSearchBarPresent = false
    private var shouldTapShowSearchBar = false
    private var didGetLocations = false
    private var isSwitchOn = false
    fileprivate var shouldGetCurrentLocations: Bool {
        return mapViewController.mapView.camera.zoom < zoomToSwitchOverlays
    }

    var timeAndDayViewController: SPTimeAndDayViewController!
    var searchViewController: SPSearchResultsViewController!
    var mapViewController: SPMapViewController!
    var collectionViewToolbar: SignsCollectionViewController!
    
    var heightOfTimeContainer: CGFloat { return CGFloat(70.0) }

    
    //MARK: - Override methods
    override func viewDidLoad() {
        super.viewDidLoad()
        assertDependencies()
        setObservers()
        setupGestures()
        setupViews()
    }
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        NotificationCenter.default.removeObserver(self)
    }
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // To do: Make a protocol to make a interface for child view controllers to abstract a method to set the delegate and dao for the child view controllers
        guard let destinationViewController = segue.destination as? InjectableViewController else { return }
        destinationViewController.inject(dao: dao, delegate: self)
        guard segue.identifier != nil else { return }
        switch segue.identifier! {
        case timeContainerSegue:
            timeAndDayViewController = segue.destination as? SPTimeAndDayViewController
        case searchContainerSegue:
            searchViewController = segue.destination as? SPSearchResultsViewController
        case mapContainerSegue:
            mapViewController = segue.destination as? SPMapViewController
        case collectionViewContainerSegue:
            collectionViewToolbar = segue.destination as? SignsCollectionViewController
        default: return
        }
    }
    
    //MARK: - Setup/breakdown methods
    //MARK: --NotificationCenter
    fileprivate func setObservers() {
        let notificationCenter = NotificationCenter.default
        notificationCenter.addObserver(self, selector: #selector(keyboardDidHide), name: NSNotification.Name.UIKeyboardDidHide, object: nil)
        notificationCenter.addObserver(self, selector: #selector(keyboardDidShow), name: NSNotification.Name.UIKeyboardDidShow, object: nil)
        notificationCenter.addObserver(self, selector: #selector(signsCollectionViewControllerDidToggleCollectionView(notification:)), name: collectionViewSwitchChangeNotification, object: nil)
    }
    @objc fileprivate func keyboardDidHide(notification: Notification) {
        isKeyboardPresent = false
        self.constraintOfToolbarToBottom.constant = 0
        self.view.layoutIfNeeded()
    }
    @objc fileprivate func keyboardDidShow(notification: Notification) {
        isKeyboardPresent = true
        if collectionViewToolbar.collectionViewSwitch.isOn {
            guard let keyboardFrame = notification.userInfo?[UIKeyboardFrameBeginUserInfoKey] as? CGRect else { return }
            self.constraintOfToolbarToBottom.constant = keyboardFrame.height
            self.view.layoutIfNeeded()
        }
    }
    
    //MARK: --Gestures
    fileprivate func setupGestures() {
        let singleTapGesture = UITapGestureRecognizer.init(target: self, action: #selector(singleTapHandler(_:)))
        singleTapGesture.numberOfTapsRequired = 1
        singleTapGesture.delegate = self
        singleTapGesture.cancelsTouchesInView = false
        view.addGestureRecognizer(singleTapGesture)
        
        let doubleTapZoomGesture = UITapGestureRecognizer.init(target: mapViewController, action: #selector(mapViewController.zoomToDoubleTapOnMap(_:)))
        doubleTapZoomGesture.numberOfTapsRequired = 2
        mapViewController.mapView.addGestureRecognizer(doubleTapZoomGesture)
        
        let doubleTouchTapZoomGesture = UITapGestureRecognizer.init(target: mapViewController, action: #selector(mapViewController.zoomOutDoubleTouchTapOnMap(_:)))
        doubleTouchTapZoomGesture.numberOfTapsRequired = 2
        doubleTouchTapZoomGesture.numberOfTouchesRequired = 2
        mapViewController.mapView.addGestureRecognizer(doubleTouchTapZoomGesture)
        
        let pinchGesture = UIPinchGestureRecognizer.init(target: mapViewController, action: #selector(mapViewController.pinchZoom(_:)))
        pinchGesture.cancelsTouchesInView = false
        mapViewController.mapView.addGestureRecognizer(pinchGesture)
        
        let longPress = UILongPressGestureRecognizer.init(target: mapViewController, action: #selector(mapViewController.longPressZoom(_:)))
        longPress.minimumPressDuration = 0.3
        longPress.allowableMovement = 2
        mapViewController.mapView.addGestureRecognizer(longPress)

        singleTapGesture.require(toFail: doubleTapZoomGesture)
    }
    
    
    
    @objc fileprivate func singleTapHandler(_ gesture: UITapGestureRecognizer) {
        // When the marker is tapped an info view comes up, so that tap need to be ignored in this handler
        guard !mapViewController.cancelTapGesture else {
            mapViewController.cancelTapGesture = false
            return
        }
        
        if collectionViewToolbar.collectionViewSwitch.isOn {
            
            return
        }
        
        if isSearchTableViewPresent {
            searchViewController.hideSearchResultsTableView()
        }
        if isKeyboardPresent {
            view.endEditing(true)
            return
        }
        
        if shouldCancelTapOnMapViewIcons(gesture: gesture) {
            return
        }
        
        if mapViewController.areMarkersPresent {
            mapViewController.hideMarkers()
        }
        adjustToolbarsToTap()
    }
    
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        if touch.view != nil {
            let viewsToCancelTouch: [UIView?] = [mapViewController.zoomOutButton, mapViewController.myLocationButton, searchContainerView,  timeAndDayContainerView, mapViewController.currentInfoWindow, mapViewController.signMarker?.iconView, mapViewController.searchMarker?.iconView, signCollectionContainerView]
            for untappableView in viewsToCancelTouch {
                if untappableView == nil { continue }
                if touch.view!.isDescendant(of: untappableView!) {
                    return false
                }
            }
        }
        return true
    }
    
    fileprivate func setCenter(toTapRecognizer tap: UIGestureRecognizer) {
        let tapLocation = tap.location(in: mapViewController.mapView)
        let coordinate = mapViewController.mapView.projection.coordinate(for: tapLocation)
        mapViewController.mapView.animate(toLocation: coordinate)
        searchViewController.searchBar.text = "(\(coordinate.longitude)), (\(coordinate.latitude))"
    }
    fileprivate func shouldCancelTapOnMapViewIcons(gesture: UIGestureRecognizer) -> Bool {
        let signMarkerFrame = mapViewController.signMarker?.iconView?.frame,
        searchMarkerFrame = mapViewController.searchMarker?.iconView?.frame,
        infoWindowFrame = mapViewController.currentInfoWindow?.frame
        let rects = [signMarkerFrame, searchMarkerFrame, infoWindowFrame]
        for rect in rects {
            if rect == nil { continue }
            if rect!.contains(gesture.location(in: mapViewController.mapView)) { return true }
        }
        return false
    }
    
    fileprivate func adjustToolbarsToTap(){
        if toolbarsPresent {
            if isSearchBarPresent {
                searchViewController.hideSearchBar()
            }
            showHideToolbars(false)
        } else {
            if !isSearchBarPresent && shouldTapShowSearchBar {
                searchViewController.showSearchBar(makeFirstResponder: false)
            }
            showHideToolbars(true)
        }
    }
    //MARK: Other Views
    func setupViews() {
        showHideSearchBar(shouldShow: true, makeFirstResponder: false)
        Timer.scheduledTimer(timeInterval: 2.3, target: self, selector: #selector(hideSearchBarAfterLaunch), userInfo: nil, repeats: false)
        
        searchContainerView.isUserInteractionEnabled = true
        activityIndicator.hidesWhenStopped = true
        showWaitingView(withLabel: waitingText, isStreetView: false)
    }
    @objc fileprivate func hideSearchBarAfterLaunch() {
        if searchViewController.searchBar.isFirstResponder { return }
        showHideSearchBar(shouldShow: false, makeFirstResponder: false)
    }
    //MARK: Button methods
    
    @IBAction func setToCurrentTime(_ sender: UIBarButtonItem) {
        if !toolbarsPresent {
            showHideToolbars(true)
        }
        timeAndDayViewController.adjustToCurrentTime()
    }


    //MARK: --Swoop toggle
    //MARK: --Searchbar toggle
    @IBAction func showSearchBarButtonPressed(_ sender: UIBarButtonItem) {
        showHideSearchBar(shouldShow: !isSearchBarPresent, makeFirstResponder: !isSearchBarPresent)
    }
    func showHideSearchBar(shouldShow show: Bool, makeFirstResponder: Bool) {
        show ? searchViewController.showSearchBar(makeFirstResponder: makeFirstResponder) : searchViewController.hideSearchBar()
        shouldTapShowSearchBar = show
    }
    
    
    
    //MARK: - Animation methods
    fileprivate func showHideTimeAndDayView(shouldShow: Bool) {
        UIView.animate(withDuration: standardAnimationDuration) { 
            self.heightConstraintOfTimeAndDayContainer.constant = shouldShow ? self.heightOfTimeContainer : 0
            self.timeAndDayViewController.heightConstraintOfBorderView.constant = shouldShow ? self.timeAndDayViewController.borderViewHeight : 0
            self.view.layoutIfNeeded()
        }
    }
    
    fileprivate func showHideToolbars(_ shouldShow:Bool) {
        UIView.animate(withDuration: standardAnimationDuration, animations: {
            self.heightConstraintOfTimeAndDayContainer.constant = shouldShow ? self.heightOfTimeContainer : 0
            self.timeAndDayViewController.heightConstraintOfBorderView.constant = shouldShow ? self.timeAndDayViewController.borderViewHeight : 0
            self.heightConstraintOfToolbar.constant = shouldShow ? standardHeightOfToolOrSearchBar : 0
            let sliderThumbCenter = self.timeAndDayViewController.centerOfSliderThumbLabel
            self.timeAndDayViewController.sliderThumbLabel.center = shouldShow ? CGPoint(x: sliderThumbCenter.x, y: sliderThumbCenter.y + 35) : CGPoint(x: sliderThumbCenter.x, y: sliderThumbCenter.y - 20)
            self.view.layoutIfNeeded()
        })
        toolbarsPresent = shouldShow
    }
    fileprivate func clearScreenForMapZoom() {
        if isSearchTableViewPresent {
            searchViewController!.hideSearchResultsTableView()
        }
        if isKeyboardPresent { view.endEditing(true) }
        if mapViewController.isMarkerSelected {        }
    }
    
    //MARK: --Blur View animation
    fileprivate func showWaitingView(withLabel labelText:String, isStreetView:Bool) {
        if !isStreetView {
            greyOutMapView.isHidden = false
            greyOutMapView.alpha = 0.3
        }
        activityIndicator.startAnimating()
        waitingLabel.isHidden = false
        waitingLabel.text = labelText
    }
    fileprivate func hideWaitingView() {
        greyOutMapView.isHidden = true
        waitingLabel.isHidden = true
        activityIndicator.stopAnimating()
    }

    //MARK: - Delegate Methods
    //MARK: -- DAO
    func dataAccessObject(_ dao: SPDataAccessObject, didUpdateAddressResults: [SPGoogleAddressResult]) {
        searchViewController?.showSearchResultsTableView()
    }
    func dataAccessObject(_ dao: SPDataAccessObject, didSetGoogleSearchObject googleSearchObject: SPGoogleCoordinateAndInfo) {
        zoomAndSetMapMarker()
    }
    func dataAccessObject(_ dao: SPDataAccessObject, didSetLocationsForQueryType queryType: SPSQLLocationQueryTypes) {
        switch queryType {
        case .getLocationsForCurrentMapView:
            mapViewController.getNewPolylines()
        case .getAllLocationsWithUniqueCleaningSign, .getLocationsForTimeAndDay:
            mapViewController.getNewHeatMapOverlays()
            if queryType == .getLocationsForTimeAndDay {
                timeAndDayViewController.setNewSliderThumbImage()
            }
            hideWaitingView()
        }
    }

    func dataAccessObjectDidAllowLocationServicesAndSetCurrentLocation() {
        if let endCoordinate = mapViewController.endCoordinateBeforeLocationRequest {
            mapViewController.presentAlertControllerForDirections(forCoordinate: endCoordinate)
            mapViewController.mapView.isMyLocationEnabled = true
        }
    }
    //MARK: -- Methods that interact with child view controllers
    //MARK: -----Time and Day Container Controller delegate
    func timeViewControllerDidChangeTime() {
        mapViewController.adjustViewsToZoom()
    }
    
    //MARK: -----Search container controller delegate
    func searchContainer(toPerformDelegateAction delegateAction: SPNetworkingDelegateAction, withInfo: String?) {
        if delegateAction == .presentCoordinate {
            if withInfo == nil {
                moveMapViewTargetToSearchCoordinate()
            } else {
                zoomAndSetMapMarker()
            }
        }
    }
    func searchContainerHeightShouldAdjust(_ height: CGFloat, tableViewPresent: Bool, searchBarPresent: Bool) -> Bool {
        UIView.animate(withDuration: standardAnimationDuration, animations: {
            self.heightConstraintOfSearchContainer.constant = height
            self.view.layoutIfNeeded()
        })
        self.isSearchTableViewPresent = tableViewPresent
        self.isSearchBarPresent = searchBarPresent
        if self.isSearchTableViewPresent {
            if collectionViewToolbar.collectionViewSwitch.isOn {
                showHideTimeAndDayView(shouldShow: false)
            } else {
                showHideToolbars(false)
            }
        }
        return true
    }
    
    fileprivate func moveMapViewTargetToSearchCoordinate() {
        if let coordinate = dao.searchCoordinate {
            mapViewController.mapView.animate(toLocation: coordinate)
            
        }
    }

    fileprivate func zoomAndSetMapMarker() {
        if dao.googleSearchObject.coordinate == nil { return }
        mapViewController.zoomMap(toCoordinate: dao.googleSearchObject.coordinate!, zoom: zoomToSwitchOverlays)
        if dao.googleSearchObject.info == nil { return }
        mapViewController.setSearchMarker(withUserData: dao.googleSearchObject.info!, atCoordinate: dao.googleSearchObject.coordinate!)
    }

    //MARK: --- Map Container Controller delegate
    func mapViewControllerDidFinishDrawingPolylines() {
        hideWaitingView()
    }
    func mapViewControllerIsZooming() {
        collectionViewToolbar.adjustSliderToZoomChange()
        clearScreenForMapZoom()
    }
    func mapViewControllerShouldSearchStreetCleaning(_ mapView: GMSMapView) -> Bool {
        showWaitingView(withLabel: waitingText, isStreetView: false)
        dao.getSigns(forCurrentMapView: mapView)
        return shouldGetCurrentLocations
    }
    
    func mapViewControllerShouldSearchLocationsForTimeAndDay() {
        activityIndicator.startAnimating()
        dao.getStreetCleaningLocationsForPrimaryTimeAndDay()
    }
        
    //MARK: - UIStateRestoring Protocol
    override func encodeRestorableState(with coder: NSCoder) {
        coder.encode(mapViewController.mapView.camera.zoom, forKey: SPRestoreCoderKeys.zoom)
        let centerCoordinates = mapViewController.mapView.camera.target
        coder.encode(centerCoordinates.latitude, forKey: SPRestoreCoderKeys.centerLat)
        coder.encode(centerCoordinates.longitude, forKey: SPRestoreCoderKeys.centerLong)
        coder.encode(searchViewController.searchBar.text, forKey: SPRestoreCoderKeys.searchText)
        coder.encodeCInt(Int32(dao.primaryTimeAndDay.day.rawValue), forKey: SPRestoreCoderKeys.day)
        coder.encodeCInt(Int32(dao.primaryTimeAndDay.time.hour), forKey: SPRestoreCoderKeys.hour)
        coder.encodeCInt(Int32(dao.primaryTimeAndDay.time.min), forKey: SPRestoreCoderKeys.min)
        super.encodeRestorableState(with: coder)
    }
    override func decodeRestorableState(with coder: NSCoder) {
        let zoom = coder.decodeFloat(forKey: SPRestoreCoderKeys.zoom),
            centerLat = coder.decodeDouble(forKey: SPRestoreCoderKeys.centerLat),
            centerLong = coder.decodeDouble(forKey: SPRestoreCoderKeys.centerLong)
        mapViewController.restoredCamera = GMSCameraPosition.camera(withLatitude: centerLat, longitude: centerLong, zoom: zoom)
        
        let hour = coder.decodeInteger(forKey: SPRestoreCoderKeys.hour),
            min = coder.decodeInteger(forKey: SPRestoreCoderKeys.min),
            day = coder.decodeInteger(forKey: SPRestoreCoderKeys.day)
        if let restoredTimeAndDay = DNTimeAndDay.init(dayInt: day, hourInt: hour, minInt:min) {
            dao.primaryTimeAndDay = restoredTimeAndDay
        }
        searchViewController.searchBar.text = coder.decodeObject(forKey: SPRestoreCoderKeys.searchText) as? String
        super.decodeRestorableState(with: coder)
    }
    override func applicationFinishedRestoringState() {
        guard let _ = mapViewController.restoredCamera else { return }
        mapViewController.mapView.camera = mapViewController.restoredCamera!
        dao.getStreetCleaningLocationsForPrimaryTimeAndDay()
        mapViewController.adjustViewsToZoom()
        timeAndDayViewController.adjustTimeSliderToDay()
        timeAndDayViewController.adjustSliderToTimeChange()
    }
    
    //MARK: - Signs View Controller delegate
    
    
    func signsCollectionViewControllerDidToggleCollectionView(notification: Notification) {
        guard let isOn = notification.userInfo?[collectionViewSwitchKey] as? Bool else { return }
        isSwitchOn = isOn
        let maxHeight = view.frame.height - timeAndDayContainerView.frame.maxY
        let toolbarHeight = isSwitchOn ? maxHeight : standardHeightOfToolOrSearchBar
        showHideTimeAndDayView(shouldShow: !isSwitchOn)

        guard isSwitchOn else {
            showHideSearchBar(shouldShow: false, makeFirstResponder: false)
            return
        }
        if let coordinate = dao.searchCoordinate {
            UIView.animate(withDuration: standardAnimationDuration, animations: {
                self.heightConstraintOfToolbar.constant = toolbarHeight
                self.view.layoutIfNeeded()
            })
            //TODO: todo1 Get locationCounts from db and set up collection view
        } else {
            showHideSearchBar(shouldShow: isSwitchOn, makeFirstResponder: true)
        }
    }
    
    func signsCollectionViewControllerNeedsMapZoom(switchIsOn: Bool) -> Float? {
        return switchIsOn ? mapViewController.mapView.camera.zoom : nil
    }
    func signsCollectionViewControllerDidChangeRadius(radius: Double) {
        let zoom = radius.toZoomFromWidthInMeters(forView: mapViewController.mapView)
        mapViewController.mapView.animate(toZoom: zoom)
        mapViewController.isZoomingIn = true
    }
    
    //MARK: - Injectable protocol
    fileprivate var dao: SPDataAccessObject!
    func inject(dao: SPDataAccessObject, delegate: Any) {
        self.dao = dao
    }
    func assertDependencies() {
        assert(dao != nil)
    }
}
