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
    @IBOutlet weak var heightConstraintOfSignsCollectionViewContainer: NSLayoutConstraint!
    @IBOutlet weak var waitingLabel: UILabel!
    @IBOutlet weak var searchContainerView: UIView!
    @IBOutlet weak var signCollectionViewContainer: UIView!
    @IBOutlet weak var mapViewContainer: UIView!
    @IBOutlet weak var panCollectionViewControllerView: UIView!
    
    @IBOutlet weak var heightConstraintOfBorderView: NSLayoutConstraint!
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
    var signsCollectionViewController: SignsCollectionViewController!
    
    var heightOfTimeContainer: CGFloat { return CGFloat(60.0) }
    var heightOfBorderView: CGFloat { return CGFloat(8) }
    private var bottomToolbarHeight: CGFloat {
        return isSwitchOn ? standardHeightOfToolOrSearchBar + self.signsCollectionViewController.slider.frame.height : standardHeightOfToolOrSearchBar
    }

    
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
            signsCollectionViewController = segue.destination as? SignsCollectionViewController
        default: return
        }
    }
    
    //MARK: - Setup/breakdown methods
    //MARK: --NotificationCenter
    fileprivate func setObservers() {
        let notificationCenter = NotificationCenter.default
        notificationCenter.addObserver(self, selector: #selector(keyboardDidHide), name: NSNotification.Name.UIKeyboardDidHide, object: nil)
        notificationCenter.addObserver(self, selector: #selector(keyboardDidShow), name: NSNotification.Name.UIKeyboardDidShow, object: nil)
        notificationCenter.addObserver(self, selector: #selector(orientationDidChange), name: Notification.Name.UIDeviceOrientationDidChange, object: nil)
    }
    @objc fileprivate func keyboardDidHide(notification: Notification) {
        isKeyboardPresent = false
    }
    @objc fileprivate func keyboardDidShow(notification: Notification) {
        isKeyboardPresent = true
    }
    @objc fileprivate func orientationDidChange(notification: Notification) {
        UIView.animate(withDuration: standardAnimationDuration, animations: {
            if self.isSwitchOn {
                self.heightConstraintOfSignsCollectionViewContainer.constant = self.view.frame.height / 2
                self.signsCollectionViewController.adjustToToggleChange(isOn: self.isSwitchOn)
                self.adjustHeightOfSignsCollectionContainerToSearchResults()
            }
            self.timeAndDayViewController.sliderThumbLabel.center = self.timeAndDayViewController.centerOfSliderThumbLabel
            self.view.layoutIfNeeded()
        })
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
        
        let panResizeGesture = UIPanGestureRecognizer(target: self, action: #selector(handlePanToResize))
        panCollectionViewControllerView.addGestureRecognizer(panResizeGesture)

        singleTapGesture.require(toFail: doubleTapZoomGesture)
    }
    
    var originalHeight: CGFloat = 0
    @objc fileprivate func handlePanToResize(recognizer: UIPanGestureRecognizer) {
        guard signsCollectionViewController.collectionViewSwitch.isOn else { return }
        switch recognizer.state {
        case .began:
            originalHeight = heightConstraintOfSignsCollectionViewContainer.constant
        case .changed, .ended:
            let translation = recognizer.translation(in: recognizer.view)
            let minHeight = standardHeightOfToolOrSearchBar + signsCollectionViewController.slider.frame.height
            let maxHeight = view.frame.height - mapViewContainer.frame.minY - 1
            var newHeight = originalHeight - translation.y
            if newHeight > maxHeight {
                newHeight = maxHeight
            } else if newHeight < minHeight {
                newHeight = minHeight
            }
            heightConstraintOfSignsCollectionViewContainer.constant = newHeight
            view.layoutIfNeeded()
        default: break
        }
    }
    
    @objc fileprivate func singleTapHandler(_ gesture: UITapGestureRecognizer) {
        // When the marker is tapped an info view comes up, so that tap need to be ignored in this handler
        guard !mapViewController.cancelTapGesture else {
            mapViewController.cancelTapGesture = false
            return
        }
        if isSearchTableViewPresent {
            searchViewController.hideSearchResultsTableView()
        }
        if isKeyboardPresent {
            view.endEditing(true)
            _ = tapWillHideSelectedMarkerInfoWindow()
            return
        }
        if shouldCancelTapOnMapViewIcons(gesture: gesture) {
            return
        }
        if tapWillHideSelectedMarkerInfoWindow() {
            return
        }
        if mapViewController.areMarkersPresent {
            mapViewController.hideMarkers()
        }
        if isSwitchOn {
            setCenter(toTapRecognizer: gesture)
            return
        }

        adjustToolbarsToTap()
    }
    
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        if touch.view != nil {
            let viewsToCancelTouch: [UIView?] = [mapViewController.zoomOutButton, mapViewController.myLocationButton, searchContainerView,  timeAndDayContainerView, mapViewController.currentInfoWindow, mapViewController.signMarker?.iconView, mapViewController.searchMarker?.iconView, signCollectionViewContainer, signCollectionViewContainer]
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
        if tapLocation.y > mapViewContainer.frame.maxY { return }
        let coordinate = mapViewController.mapView.projection.coordinate(for: tapLocation)
        mapViewController.mapView.animate(toLocation: coordinate)
    }
    fileprivate func shouldCancelTapOnMapViewIcons(gesture: UIGestureRecognizer) -> Bool {
        let signMarkerFrame = mapViewController.signMarker?.iconView?.frame,
        searchMarkerFrame = mapViewController.searchMarker?.iconView?.frame,
        infoWindowFrame = mapViewController.currentInfoWindow?.frame
        let rects = [signMarkerFrame, searchMarkerFrame, infoWindowFrame]
        for rect in rects {
            guard let isGestureInRect = rect?.contains(gesture.location(in: mapViewController.mapView)) else { continue }
            if isGestureInRect{
                return true
            }
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
    
    private func tapWillHideSelectedMarkerInfoWindow() -> Bool {
        if let _ = mapViewController.currentInfoWindow {
            mapViewController.mapView.selectedMarker = nil
            mapViewController.currentInfoWindow = nil
            return true
        } else {
            return false
        }
    }
    //MARK: Other Views
    private func setupViews() {
        showHideSearchBar(shouldShow: true, makeFirstResponder: false)
        Timer.scheduledTimer(timeInterval: 2.3, target: self, selector: #selector(hideSearchBarAfterLaunch), userInfo: nil, repeats: false)
        
        searchContainerView.isUserInteractionEnabled = true
        activityIndicator.hidesWhenStopped = true
        showWaitingView(withLabel: waitingText, isStreetView: false)
        signsCollectionViewController.collectionViewSwitch.setOn(isSwitchOn, animated: true)
        signsCollectionViewController.adjustToToggleChange(isOn: isSwitchOn)
    }
    @objc fileprivate func hideSearchBarAfterLaunch() {
        if searchViewController.searchBar.isFirstResponder || isSwitchOn { return }
        showHideSearchBar(shouldShow: false, makeFirstResponder: false)
    }
    //MARK: Button methods
    
    @IBAction func setToCurrentTime(_ sender: UIBarButtonItem) {
        if !toolbarsPresent {
            showHideToolbars(true)
        }
        timeAndDayViewController.adjustToCurrentTime()
    }

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
        if shouldShow{
            timeAndDayContainerView.isHidden = !shouldShow
        }
        UIView.animate(withDuration: standardAnimationDuration, animations: {
            self.heightConstraintOfTimeAndDayContainer.constant = shouldShow ? self.heightOfTimeContainer : 0
            self.heightConstraintOfBorderView.constant = shouldShow ? self.heightOfBorderView : 0
            self.timeAndDayContainerView.isHidden = !shouldShow
            self.view.layoutIfNeeded()
        })
    }
    
    fileprivate func showHideToolbars(_ shouldShow:Bool) {
        UIView.animate(withDuration: standardAnimationDuration, animations: {
            self.heightConstraintOfTimeAndDayContainer.constant = shouldShow ? self.heightOfTimeContainer : 0
            self.heightConstraintOfBorderView.constant = shouldShow ? self.heightOfBorderView : 0
            let heightOfSignsCollectionViewContainer = shouldShow ? self.bottomToolbarHeight : 0
            self.heightConstraintOfSignsCollectionViewContainer.constant = heightOfSignsCollectionViewContainer
            let sliderThumbCenter = self.timeAndDayViewController.centerOfSliderThumbLabel
            self.timeAndDayContainerView.isHidden = !shouldShow
            self.timeAndDayViewController.sliderThumbLabel.center = shouldShow ? CGPoint(x: sliderThumbCenter.x, y: sliderThumbCenter.y + 35) : CGPoint(x: sliderThumbCenter.x, y: sliderThumbCenter.y - 20)
            self.view.layoutIfNeeded()
        })
        toolbarsPresent = shouldShow
    }
    
    fileprivate func clearScreenForMapZoom() {
        if isSearchTableViewPresent {
            searchViewController!.hideSearchResultsTableView()
        }
        if isKeyboardPresent && !isSwitchOn { view.endEditing(true) }
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
        case .getLocationsForTimeAndDay:
            mapViewController.getNewHeatMapOverlays()
            timeAndDayViewController.setNewSliderThumbImage()
            hideWaitingView()
        default: break
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
        mapViewController.adjustOverlayToZoom()
    }
    
    //MARK: -----Search container controller delegate
    func searchContainer(toPerformDelegateAction delegateAction: SPNetworkingDelegateAction, withInfo: String?) {
        if delegateAction == .presentCoordinate {
            zoomAndSetMapMarker()
        } else if delegateAction == .presentCurrentLocation {
            if let currentLocation = dao.currentLocation?.coordinate {
                mapViewController.mapView.animate(toLocation: currentLocation)
            }
        }
        searchViewController.hideSearchResultsTableView()
    }
    
    func searchContainerHeightShouldAdjust(_ height: CGFloat, tableViewPresent: Bool, searchBarPresent: Bool) -> Bool {
        UIView.animate(withDuration: standardAnimationDuration, animations: {
            self.heightConstraintOfSearchContainer.constant = height
            self.adjustHeightOfSignsCollectionContainerToSearchResults()
            self.view.layoutIfNeeded()
        })
        self.isSearchTableViewPresent = tableViewPresent
        self.isSearchBarPresent = searchBarPresent
        if self.isSearchTableViewPresent {
            if signsCollectionViewController.collectionViewSwitch.isOn {
                showHideTimeAndDayView(shouldShow: false)
            } else {
                showHideToolbars(false)
            }
        }
        return true
    }
    private func adjustHeightOfSignsCollectionContainerToSearchResults() {
        let searchContainerMaxY = searchContainerView.frame.minY + heightConstraintOfSearchContainer.constant
        if searchContainerMaxY > signCollectionViewContainer.frame.minY {
            let newHeight = view.frame.height - searchContainerMaxY
            self.heightConstraintOfSignsCollectionViewContainer.constant = newHeight
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
        signsCollectionViewController.adjustSliderToZoomChange()
        clearScreenForMapZoom()
    }
    func mapViewControllerDidIdleAt(coordinate: CLLocationCoordinate2D, zoom: Float) {
        dao.searchCoordinate = coordinate        
        searchViewController.searchBar.placeholder = "(\(coordinate.latitude), \(coordinate.longitude))"
        if isSwitchOn {
            dao.locationCountsForTimeAndDay.removeAll(keepingCapacity: true)
            let days = signsCollectionViewController.uncollapsedSections.flatMap { return DNDay(rawValue: $0) }
            dao.setCountOfStreetCleaningTimes(forDays: days, at: coordinate, radius: mapViewController.mapView.currentRadius, completion: { [unowned self] in
                let indexSet = IndexSet(self.signsCollectionViewController.uncollapsedSections)
                self.signsCollectionViewController.collectionView.reloadSections(indexSet)
//                self.signsCollectionViewController.hideWaitingView()
            })
//            signsCollectionViewController.showWaitingView()
        }
    }
    
    func mapViewControllerShouldSearchStreetCleaning(_ mapView: GMSMapView) -> Bool {
        showWaitingView(withLabel: waitingText, isStreetView: false)
        dao.setSigns(forCurrentMapView: mapView)
        return shouldGetCurrentLocations
    }
    
    func mapViewControllerShouldSearchLocationsForTimeAndDay() {
        activityIndicator.startAnimating()
        dao.setStreetCleaningLocationsForPrimaryTimeAndDay()
    }
    
    func mapViewControllerDidChangeMap(coordinate: CLLocationCoordinate2D, zoom: Float) {
        dao.currentRadius = mapViewController.mapView.currentRadius
        signsCollectionViewController.adjustSliderToZoomChange()
    }
    
    //MARK: - <SignsCollectionViewControllerDelegate>
    var signsCollectionViewControllerNeedsCurrentRadius: Double {
        return mapViewController.mapView.currentRadius
    }
    
    func signsCollectionViewControllerDidStartQuery() {
        showWaitingView(withLabel: "", isStreetView: false)
    }
    
    func signsCollectionViewControllerDidFinishQuery() {
        hideWaitingView()
    }

    func signsCollectionViewControllerDidChangeRadius(radius: Double) {
        let zoom = radius.toZoomFromWidthInMeters(forView: mapViewController.mapView)
        mapViewController.mapView.animate(toZoom: zoom)
    }
    func signsCollectionViewControllerDidSelect(timeAndDay: DNTimeAndDay) {
        signsCollectionViewController.collectionViewSwitch.setOn(false, animated: true)
        dao.primaryTimeAndDay = timeAndDay
        signsCollectionViewController.adjustToToggleChange(isOn: false, completion: { [unowned self] in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8, execute: {
                self.timeAndDayViewController.adjustTimeSliderToDay()
                self.mapViewController.adjustOverlayToZoom()
                UIView.animate(withDuration: standardAnimationDuration, animations: { 
                    self.timeAndDayViewController.dayView.backgroundColor = UIColor.green
                    self.timeAndDayViewController.sliderThumbLabel.backgroundColor = UIColor.green
                }, completion: { _ in
                    self.timeAndDayViewController.dayView.backgroundColor = UIColor.clear
                    self.timeAndDayViewController.sliderThumbLabel.backgroundColor = UIColor.clear
                })
            })
        })
    }
    func signsCollectionViewController(didTurnSwitchOn isOn: Bool) {
        mapViewController.isCollectionViewSwitchOn = isOn
        mapViewController.crosshairImageView.isHidden = !isOn
        searchViewController.isSwitchOn = isOn
        isSwitchOn = isOn
        let maxHeight = view.frame.height / 2
        let toolbarHeight = isSwitchOn ? maxHeight : bottomToolbarHeight
        showHideTimeAndDayView(shouldShow: !isSwitchOn)
        showHideSearchBar(shouldShow: isSwitchOn, makeFirstResponder: false)
        UIView.animate(withDuration: standardAnimationDuration, animations: {
            self.heightConstraintOfSignsCollectionViewContainer.constant = toolbarHeight
            self.view.layoutIfNeeded()
        })
        if isOn {
            if let coordinate = dao.searchCoordinate {
                searchViewController.searchBar.text = ""
                searchViewController.searchBar.placeholder = "(\(coordinate.latitude)), (\(coordinate.longitude))"
            }
        } else {
            searchViewController.searchBar.placeholder = "Location"
        }
    }

    //MARK: - Injectable protocol
    fileprivate var dao: SPDataAccessObject!
    func inject(dao: SPDataAccessObject, delegate: Any) {
        self.dao = dao
    }
    func assertDependencies() {
        assert(dao != nil)
    }
    
    //MARK: - UIStateRestoring Protocol
    override func encodeRestorableState(with coder: NSCoder) {
        super.encodeRestorableState(with: coder)
        coder.encode(mapViewController.mapView.camera.zoom, forKey: SPRestoreCoderKeys.zoom)
        let centerCoordinates = mapViewController.mapView.camera.target
        coder.encode(centerCoordinates.latitude, forKey: SPRestoreCoderKeys.centerLat)
        coder.encode(centerCoordinates.longitude, forKey: SPRestoreCoderKeys.centerLong)
        coder.encode(searchViewController.searchBar.text, forKey: SPRestoreCoderKeys.searchText)
        coder.encodeCInt(Int32(dao.primaryTimeAndDay.day.rawValue), forKey: SPRestoreCoderKeys.day)
        coder.encodeCInt(Int32(dao.primaryTimeAndDay.time.hour), forKey: SPRestoreCoderKeys.hour)
        coder.encodeCInt(Int32(dao.primaryTimeAndDay.time.min), forKey: SPRestoreCoderKeys.min)
        coder.encode(isSwitchOn, forKey: SPRestoreCoderKeys.isSwitchOn)
    }
    
    override func decodeRestorableState(with coder: NSCoder) {
        super.decodeRestorableState(with: coder)
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
        
        let isSwitchOn = coder.decodeBool(forKey: SPRestoreCoderKeys.isSwitchOn)
        self.isSwitchOn = isSwitchOn
        signsCollectionViewController.collectionViewSwitch.setOn(isSwitchOn, animated: true)
        signsCollectionViewController.adjustToToggleChange(isOn: isSwitchOn)
        showWaitingView(withLabel: "", isStreetView: false)
    }
    
    override func applicationFinishedRestoringState() {
        guard let _ = mapViewController.restoredCamera else { return }
        mapViewController.mapView.camera = mapViewController.restoredCamera!
        mapViewController.adjustOverlayToZoom()
        timeAndDayViewController.adjustTimeSliderToDay()
        timeAndDayViewController.adjustSliderToTimeChange()
    }

}
