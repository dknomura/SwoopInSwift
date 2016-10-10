//
//  SPMainViewController.swift
//  SwoopParkingApp
//
//  Created by Daniel Nomura on 10/5/16.
//  Copyright © 2016 Daniel Nomura. All rights reserved.
//

import Foundation
import GoogleMaps

class SPMainViewController: UIViewController, UIGestureRecognizerDelegate, SPDataAccessObjectDelegate, SPSearchResultsViewControllerDelegate, SPMapViewControllerDelegate, SPTimeViewControllerDelegate{
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
    var switchLabelText: String { return streetViewSwitch.on ? "Street" : "City" }
    var waitingText:String { return "Finding street cleaning locations..." }

    var isSearchTableViewPresent = false
    var toolbarsPresent = true
    var isKeyboardPresent = false
    var isSearchBarPresent = false
    var shouldTapShowSearchBar = false
    var didGetLocations = false
    
    private enum ChildViewController: String {
        case timeAndDay, map, search
        var segue: String {
            switch self {
            case timeAndDay: return "timeContainer"
            case map: return "mapContainer"
            case search: return "searchContainer"
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
        setObservers()
        setupGestures()
        setupViews()
        assertDependencies()
        dao.delegate = self
    }
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    override func viewWillDisappear(animated: Bool) {
        super.viewWillDisappear(animated)
        NSNotificationCenter.defaultCenter().removeObserver(self)
    }
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        guard segue.identifier != nil else { return }
        switch segue.identifier! {
        case timeContainerSegue:
            timeAndDayViewController = segue.destinationViewController as? SPTimeAndDayViewController
            guard timeAndDayViewController != nil else {
                print("Destination ViewController for segue \(segue.identifier) is not a TimeAndDay view controller. It is \(segue.destinationViewController)")
                return
            }
            timeAndDayViewController.inject(dao)
            timeAndDayViewController.delegate = self
        case searchContainerSegue:
            searchViewController = segue.destinationViewController as? SPSearchResultsViewController
            guard searchViewController != nil else {
                print("Destination ViewController for segue \(segue.identifier) is not a Search results view controller. It is \(segue.destinationViewController)")
                return
            }
            searchViewController.inject(dao)
            searchViewController.delegate = self
        case mapContainerSegue:
            mapViewController = segue.destinationViewController as? SPMapViewController
            guard mapViewController != nil else {
                print("Destination ViewController for segue \(segue.identifier) is not a Map view controller. It is \(segue.destinationViewController)")
                return
            }
            mapViewController.inject(dao)
            mapViewController.delegate = self
        default: return
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

        singleTapGesture.requireGestureRecognizerToFail(doubleTapZoomGesture)
    }
    
    @objc private func singleTapHandler(gesture: UITapGestureRecognizer) {
        if isSearchTableViewPresent {
            searchViewController.hideSearchResultsTableView()
        }
        if isKeyboardPresent {
            view.endEditing(true)
            return
        }
        
//        if mapViewController.isMarkerPresent {
//            mapViewController.hideMarkerInfoWindow()
//            return
//        }
        
        if CGRectContainsPoint(timeAndDayContainerView.frame, gesture.locationInView(view)) || CGRectContainsPoint(bottomToolbar.frame, gesture.locationInView(view)) { return }
        if mapViewController.currentInfoWindow != nil {
            if CGRectContainsPoint(mapViewController.currentInfoWindow!.frame, gesture.locationInView(mapViewController.view)) { return }
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

    func gestureRecognizer(gestureRecognizer: UIGestureRecognizer, shouldReceiveTouch touch: UITouch) -> Bool {
        if touch.view != nil {
            let viewsToCancelTouch: [UIView?] = [mapViewController.zoomOutButton, searchContainerView, bottomToolbar, timeAndDayContainerView, mapViewController.currentInfoWindow, mapViewController.signMarker?.iconView, mapViewController.searchMarker?.iconView]
            for untappableView in viewsToCancelTouch {
                if untappableView == nil { continue }
                if touch.view!.isDescendantOfView(untappableView!) { return false }
            }
        }
        return true
    }
    
    //MARK: Other Views
    func setupViews() {
        showHideSearchBar(shouldShow: true, makeFirstResponder: false)
        NSTimer.scheduledTimerWithTimeInterval(2.8, target: self, selector: #selector(hideSearchBarAfterLaunch), userInfo: nil, repeats: false)
        
        searchContainerView.userInteractionEnabled = true
        activityIndicator.hidesWhenStopped = true
        showWaitingView(withLabel: waitingText, isStreetView: false)
    }
    @objc private func hideSearchBarAfterLaunch() {
        if searchViewController.searchBar.isFirstResponder() { return }
        showHideSearchBar(shouldShow: false, makeFirstResponder: false)
    }

    //MARK: --Swoop toggle
    @IBAction func toggleOverlaySwitch(sender: UISwitch) {
        let zoomIsLessThanSwitchOverlay = mapViewController.mapView.camera.zoom < mapViewController.zoomToSwitchOverlays
        let zoomIsGreaterThanStreetLevel = mapViewController.mapView.camera.zoom >= mapViewController.streetZoom
        if zoomIsGreaterThanStreetLevel && !streetViewSwitch.on {
            mapViewController.zoomMap(toZoom: mapViewController.zoomToSwitchOverlays)
        } else if !zoomIsLessThanSwitchOverlay {
            mapViewController.zoomMap(toZoom: mapViewController.streetZoom)
            turnStreetSwitch(on: true, shouldGetOverlays: false)
        }
        else if mapViewController.mapView.camera.zoom < mapViewController.zoomToSwitchOverlays {
            streetViewSwitch.setOn(false, animated: true)
        }
//        turnStreetSwitch(on: nil, shouldGetOverlays: true)
    }
    private func turnStreetSwitch(on on: Bool?, shouldGetOverlays: Bool) {
        if on != nil {
            streetViewSwitch.setOn(on!, animated: true)
        }
        switchLabel.setTitle(switchLabelText, forState: .Normal)
        if shouldGetOverlays {
            streetViewSwitch.on ? mapViewController.getSignsForCurrentMapView() : mapViewController.getNewHeatMapOverlays()
        }
    }
    //MARK: --Searchbar toggle
    @IBAction func showSearchBarButtonPressed(sender: UIBarButtonItem) {
        showHideSearchBar(shouldShow: !isSearchBarPresent, makeFirstResponder: !isSearchBarPresent)
    }
    func showHideSearchBar(shouldShow show: Bool, makeFirstResponder: Bool) {
        show ? searchViewController.showSearchBar(makeFirstResponder: makeFirstResponder) : searchViewController.hideSearchBar()
        shouldTapShowSearchBar = show
    }
    
    //MARK: - Animation methods
    private func showHideToolbars(shouldShow:Bool) {
        UIView.animateWithDuration(standardAnimationDuration, animations: {
            self.heightConstraintOfTimeAndDayContainer.constant = shouldShow ? self.heightOfTimeContainer : 0
            self.timeAndDayViewController.heightConstraintOfBorderView.constant = shouldShow ? self.timeAndDayViewController.borderViewHeight : 0
            self.heightConstraintOfToolbar.constant = shouldShow ? self.standardHeightOfToolOrSearchBar : 0
            let sliderThumbCenter = self.timeAndDayViewController.centerOfSliderThumb
            self.timeAndDayViewController.sliderThumbLabel.center = shouldShow ? sliderThumbCenter : CGPointMake(sliderThumbCenter.x, sliderThumbCenter.y - 20)
            self.view.layoutIfNeeded()
        })
        toolbarsPresent = shouldShow
    }
    private func clearScreenForMapZoom() {
        if isSearchTableViewPresent {
            searchViewController!.hideSearchResultsTableView()
        }
        if isKeyboardPresent { view.endEditing(true) }
    }
    
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

    //MARK: - Delegate Methods
    //MARK: -- DAO
    func dataAccessObject(dao: SPDataAccessObject, didUpdateAddressResults: [SPGoogleAddressResult]) {
        searchViewController?.showSearchResultsTableView()
    }
    func dataAccessObject(dao: SPDataAccessObject, didSetGoogleSearchObject googleSearchObject: SPGoogleCoordinateAndInfo) {
        zoomAndSetMapMarker()
    }
    func dataAccessObject(dao: SPDataAccessObject, didSetLocationsForQueryType queryType: SPSQLLocationQueryTypes) {
        switch queryType {
        case .getLocationsForCurrentMapView:
            mapViewController.getNewPolylines()
        case .getAllLocationsWithUniqueCleaningSign, .getLocationsForTimeAndDay:
            if !streetViewSwitch.on {
                mapViewController.getNewHeatMapOverlays()
            }
            if queryType == .getAllLocationsWithUniqueCleaningSign {
                bottomToolbar.backgroundColor = UIColor.redColor()
            } else {
                timeAndDayViewController.setNewImage()
            }
            hideWaitingView()
        }
    }
    //MARK: -- Methods that interact with child view controllers
    //MARK: -----Time and Day Container Controller delegate
    func timeViewControllerDidChangeTime() {
        if streetViewSwitch.on {
            mapViewController.getSignsForCurrentMapView()
        } else {
            if dao.locationsForPrimaryTimeAndDay == nil {
                dao.getStreetCleaningLocationsForPrimaryTimeAndDay()
                activityIndicator.startAnimating()
            } else {
                mapViewController.getNewHeatMapOverlays()
            }
        }
    }
    
    //MARK: -----Search container controller delegate
    func searchContainer(toPerformDelegateAction delegateAction: SPNetworkingDelegateAction, withInfo: String) {
        if delegateAction == .presentCoordinate {
            zoomAndSetMapMarker()
        }
    }
    
    func zoomAndSetMapMarker() {
        if dao.googleSearchObject.coordinate == nil { return }
        mapViewController.zoomMap(toCoordinate: dao.googleSearchObject.coordinate!, zoom: mapViewController.streetZoom)
        if dao.googleSearchObject.info == nil { return }
        mapViewController.setSearchMarker(withUserData: dao.googleSearchObject.info!, atCoordinate: dao.googleSearchObject.coordinate!)
        turnStreetSwitch(on: true, shouldGetOverlays: true)

    }
    func searchContainerHeightShouldAdjust(height: CGFloat, tableViewPresent: Bool, searchBarPresent: Bool) -> Bool {
        UIView.animateWithDuration(standardAnimationDuration) {
            self.heightConstraintOfSearchContainer.constant = height
            self.view.layoutIfNeeded()
        }
        self.isSearchTableViewPresent = tableViewPresent
        self.isSearchBarPresent = searchBarPresent
        if self.isSearchTableViewPresent {
            showHideToolbars(false)
        }
        return true
    }

    //MARK: --- Map Container Controller delegate
    func mapViewControllerFinishedDrawingPolylines() {
        hideWaitingView()
    }
    func mapViewControllerIsZooming() {
        clearScreenForMapZoom()
    }
    func mapViewControllerShouldSearchStreetCleaning(mapView: GMSMapView) -> Bool {
        if streetViewSwitch.on {
            showWaitingView(withLabel: waitingText, isStreetView: true)
            dao.getSigns(forCurrentMapView: mapView)
        }
        return streetViewSwitch.on
    }
    func mapViewControllerDidZoom(switchOn on: Bool?, shouldGetOverlay: Bool) {
        turnStreetSwitch(on: on, shouldGetOverlays: shouldGetOverlay)
        mapViewController.hideMarkerInfoWindow()

    }
    
    //MARK: - Injectable protocol
    private var dao: SPDataAccessObject!
    func inject(dao: SPDataAccessObject) {
        self.dao = dao
    }
    func assertDependencies() {
        assert(dao != nil)
    }
}