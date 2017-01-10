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

class SPMainViewController: UIViewController, UIGestureRecognizerDelegate, SPDataAccessObjectDelegate, SPSearchResultsViewControllerDelegate, SPMapViewControllerDelegate, SPTimeViewControllerDelegate, InjectableViewController {
    @IBOutlet weak var timeAndDayContainerView: UIView!
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!
    @IBOutlet weak var streetViewSwitch: UISwitch!

    @IBOutlet weak var heightConstraintOfSearchContainer: NSLayoutConstraint!
    @IBOutlet weak var heightConstraintOfTimeAndDayContainer: NSLayoutConstraint!
    @IBOutlet weak var heightConstraintOfToolbar: NSLayoutConstraint!
    @IBOutlet weak var waitingLabel: UILabel!
    @IBOutlet weak var searchContainerView: UIView!
    @IBOutlet weak var switchLabel: UIButton!
    
    @IBOutlet weak var greyOutMapView: UIView!
    @IBOutlet weak var bottomToolbar: UIToolbar!

    var searchContainerSegue: String { return "searchContainer" }
    var timeContainerSegue:String { return "timeContainer" }
    var mapContainerSegue: String { return "mapContainer" }
    var switchLabelText: String { return streetViewSwitch.isOn ? "Street" : "City" }
    var waitingText:String { return "Finding street cleaning locations and rendering map..." }

    var isSearchTableViewPresent = false
    var toolbarsPresent = true
    var isKeyboardPresent = false
    var isSearchBarPresent = false
    var shouldTapShowSearchBar = false
    var didGetLocations = false
    
    fileprivate enum ChildViewController: String {
        case timeAndDay, map, search
        var segue: String {
            switch self {
            case .timeAndDay: return "timeContainer"
            case .map: return "mapContainer"
            case .search: return "searchContainer"
            }
        }
    }
    var timeAndDayViewController: SPTimeAndDayViewController!
    var searchViewController: SPSearchResultsViewController!
    var mapViewController: SPMapViewController!
    
    var standardHeightOfToolOrSearchBar: CGFloat { return CGFloat(44.0) }
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
            guard timeAndDayViewController != nil else {
                print("Destination ViewController for segue \(segue.identifier) is not a TimeAndDay view controller. It is \(segue.destination)")
                return
            }
        case searchContainerSegue:
            searchViewController = segue.destination as? SPSearchResultsViewController
            guard searchViewController != nil else {
                print("Destination ViewController for segue \(segue.identifier) is not a Search results view controller. It is \(segue.destination)")
                return
            }
        case mapContainerSegue:
            mapViewController = segue.destination as? SPMapViewController
            guard let _ = mapViewController else {
                print("Destination ViewController for segue \(segue.identifier) is not a Map view controller. It is \(segue.destination)")
                return
            }
        default: return
        }
    }
    
    //MARK: - Setup/breakdown methods
    //MARK: --NotificationCenter
    fileprivate func setObservers() {
        let notificationCenter = NotificationCenter.default
        notificationCenter.addObserver(self, selector: #selector(keyboardDidHide), name: NSNotification.Name.UIKeyboardDidHide, object: nil)
        notificationCenter.addObserver(self, selector: #selector(keyboardDidShow), name: NSNotification.Name.UIKeyboardDidShow, object: nil)
    }
    @objc fileprivate func keyboardDidHide() { isKeyboardPresent = false }
    @objc fileprivate func keyboardDidShow() { isKeyboardPresent = true }
    
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
        guard !mapViewController.cancelTapGesture else {
            mapViewController.cancelTapGesture = false
            return
        }
        if isSearchTableViewPresent {
            searchViewController.hideSearchResultsTableView()
        }
        if isKeyboardPresent {
            view.endEditing(true)
            return
        }
//        let tapLocation = gesture.location(in: mapViewController.mapView)
//        if timeAndDayContainerView.frame.contains(tapLocation) || bottomToolbar.frame.contains(tapLocation) { return }
        let signMarkerFrame = mapViewController.signMarker?.iconView?.frame,
            searchMarkerFrame = mapViewController.searchMarker?.iconView?.frame,
            infoWindowFrame = mapViewController.currentInfoWindow?.frame
        let rects = [signMarkerFrame, searchMarkerFrame, infoWindowFrame]
        for rect in rects {
            if rect == nil { continue }
            if rect!.contains(gesture.location(in: mapViewController.mapView)) { return }
        }
        if mapViewController.areMarkersPresent {
            mapViewController.hideMarkers()
        }
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

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        if touch.view != nil {
            let viewsToCancelTouch: [UIView?] = [mapViewController.zoomOutButton, mapViewController.myLocationButton, searchContainerView, bottomToolbar, timeAndDayContainerView, mapViewController.currentInfoWindow, mapViewController.signMarker?.iconView, mapViewController.searchMarker?.iconView]
            for untappableView in viewsToCancelTouch {
                if untappableView == nil { continue }
                if touch.view!.isDescendant(of: untappableView!) {
                    return false
                }
            }
        }
        return true
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

    //MARK: --Swoop toggle
    @IBAction func toggleOverlaySwitch(_ sender: UISwitch) {
        if sender.isOn {
            showHideSearchBar(shouldShow: true, makeFirstResponder: true)
            turnStreetSwitch(on: false, shouldGetOverlays: false)
        } else {
            mapViewController.zoomMap(toCamera: mapViewController.initialMapViewCamera)

        }
//        if mapViewController.mapView.camera.zoom <= mapViewController.zoomToSwitchOverlays {
//            if !sender.isOn { return }
//            mapViewController.zoomMap(toZoom: mapViewController.streetZoom)
//        } else {
//            if sender.isOn { return }
//            mapViewController.zoomMap(toZoom: mapViewController.zoomToSwitchOverlays)
//        }
    }
    fileprivate func turnStreetSwitch(on: Bool?, shouldGetOverlays: Bool) {
        if on != nil {
            streetViewSwitch.setOn(on!, animated: true)
        }
        switchLabel.setTitle(switchLabelText, for: UIControlState())
        if shouldGetOverlays {
            mapViewController.getSignsForCurrentMapView()
        }
        print("Switch is \(streetViewSwitch.isOn)")
    }
    //MARK: --Searchbar toggle
    @IBAction func showSearchBarButtonPressed(_ sender: UIBarButtonItem) {
        showHideSearchBar(shouldShow: !isSearchBarPresent, makeFirstResponder: !isSearchBarPresent)
    }
    func showHideSearchBar(shouldShow show: Bool, makeFirstResponder: Bool) {
        show ? searchViewController.showSearchBar(makeFirstResponder: makeFirstResponder) : searchViewController.hideSearchBar()
        shouldTapShowSearchBar = show
    }
    
    //MARK: Button methods
    
    @IBAction func setToCurrentTime(_ sender: UIBarButtonItem) {
        if !toolbarsPresent {
            showHideToolbars(true)
        }
        timeAndDayViewController.adjustToCurrentTime()
    }
    
    
    //MARK: - Animation methods
    fileprivate func showHideToolbars(_ shouldShow:Bool) {
        UIView.animate(withDuration: standardAnimationDuration, animations: {
            self.heightConstraintOfTimeAndDayContainer.constant = shouldShow ? self.heightOfTimeContainer : 0
            self.timeAndDayViewController.heightConstraintOfBorderView.constant = shouldShow ? self.timeAndDayViewController.borderViewHeight : 0
            self.heightConstraintOfToolbar.constant = shouldShow ? self.standardHeightOfToolOrSearchBar : 0
            let sliderThumbCenter = self.timeAndDayViewController.centerOfSliderThumb
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
            if !streetViewSwitch.isOn {
                mapViewController.getNewHeatMapOverlays()
            }
            if queryType == .getAllLocationsWithUniqueCleaningSign {
                bottomToolbar.backgroundColor = UIColor.red
            } else {
                timeAndDayViewController.setNewImage()
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
    
    func dataAccessObjectDidUpdateCurrentLocation() {
    }
    //MARK: -- Methods that interact with child view controllers
    //MARK: -----Time and Day Container Controller delegate
    func timeViewControllerDidChangeTime() {
        if streetViewSwitch.isOn {
            mapViewController.getSignsForCurrentMapView()
        }
        if dao.locationsForPrimaryTimeAndDay == nil {
            dao.getStreetCleaningLocationsForPrimaryTimeAndDay()
            activityIndicator.startAnimating()
        } else {
            mapViewController.getNewHeatMapOverlays()
        }
    }
    
    //MARK: -----Search container controller delegate
    func searchContainer(toPerformDelegateAction delegateAction: SPNetworkingDelegateAction, withInfo: String) {
        if delegateAction == .presentCoordinate {
            zoomAndSetMapMarker()
        }
    }
    
    //TODO: Call method to show collection view in bottom toolbar
    func zoomAndSetMapMarker() {
        if dao.googleSearchObject.coordinate == nil { return }
        mapViewController.zoomMap(toCoordinate: dao.googleSearchObject.coordinate!, zoom: mapViewController.zoomToSwitchOverlays)
        if dao.googleSearchObject.info == nil { return }
        mapViewController.setSearchMarker(withUserData: dao.googleSearchObject.info!, atCoordinate: dao.googleSearchObject.coordinate!)
        turnStreetSwitch(on: true, shouldGetOverlays: true)
    }
    func searchContainerHeightShouldAdjust(_ height: CGFloat, tableViewPresent: Bool, searchBarPresent: Bool) -> Bool {
        UIView.animate(withDuration: standardAnimationDuration, animations: {
            self.heightConstraintOfSearchContainer.constant = height
            self.view.layoutIfNeeded()
        }) 
        self.isSearchTableViewPresent = tableViewPresent
        self.isSearchBarPresent = searchBarPresent
        if self.isSearchTableViewPresent {
            showHideToolbars(false)
        }
        return true
    }

    //MARK: --- Map Container Controller delegate
    func mapViewControllerDidFinishDrawingPolylines() {
        hideWaitingView()
    }
    func mapViewControllerIsZooming() {
        clearScreenForMapZoom()
    }
    func mapViewControllerShouldSearchStreetCleaning(_ mapView: GMSMapView) -> Bool {
        if streetViewSwitch.isOn {
            showWaitingView(withLabel: waitingText, isStreetView: false)
            dao.getSigns(forCurrentMapView: mapView)
        }
        return streetViewSwitch.isOn
    }
    func mapViewControllerDidZoom(switchOn on: Bool?, shouldGetOverlay: Bool) {
        turnStreetSwitch(on: on, shouldGetOverlays: shouldGetOverlay)
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
        let shouldTurnSwitchOn = (mapViewController.restoredCamera?.zoom)! >= mapViewController.zoomToSwitchOverlays
        dao.getStreetCleaningLocationsForPrimaryTimeAndDay()
        turnStreetSwitch(on: shouldTurnSwitchOn, shouldGetOverlays: false)
        mapViewController.adjustViewsToZoom()
        timeAndDayViewController.adjustTimeSliderToDay()
        timeAndDayViewController.adjustSliderToTimeChange()
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
