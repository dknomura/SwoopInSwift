//
//  ViewController.swift
//  SwoopParkingApp
//
//  Created by Daniel Nomura on 5/4/16.
//  Copyright © 2016 Daniel Nomura. All rights reserved.
//

import UIKit
import GoogleMaps

class SPMapViewController: UIViewController, CLLocationManagerDelegate, GMSMapViewDelegate, UIGestureRecognizerDelegate, SPSignInfoOverlayDelegate, SPInjectable {
    
    weak var delegate: SPMapViewControllerDelegate?
    @IBOutlet weak var mapView: GMSMapView!
    var zoomOutButton = UIButton.init(type:.RoundedRect)
    
    var initialMapViewCamera: GMSCameraPosition {
        return GMSCameraPosition.cameraWithTarget(CLLocationCoordinate2DMake(40.7193748839769, -73.9289110153913), zoom: initialZoom)
    }
    var currentGroundOverlays = [GMSGroundOverlay]()
    var currentMapPolylines = [GMSPolyline]()
    
    var userControl = false
    var animatingFromCityView = true
    var isPinchZooming = false
    var isZoomingIn = false
    
    var zoomToSwitchOverlays: Float { return streetZoom - 1.5 }
    var streetZoom: Float { return 16.0 }
    var initialZoom: Float {
        return mapView.initialStreetCleaningZoom(forCity: .NYC)
    }
    //MARK: - Override methods
    override func viewDidLoad() {
        super.viewDidLoad()
        setUpMap()
        setUpButtons()
        setupGestures()
        assertDependencies()
        dao.setUpLocationManager()
    }
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    override func viewWillDisappear(animated: Bool) {
        super.viewWillDisappear(animated)
        NSNotificationCenter.defaultCenter().removeObserver(self)
    }    
    //MARK: - Setup/breakdown methods
    //MARK: --Gestures
    private func setupGestures() {
    }
    @objc func zoomToDoubleTapOnMap(gesture:UITapGestureRecognizer) {
        let pointOnMap = gesture.locationInView(mapView)
        var doubleTapZoom: Float
        if mapView.camera.zoom < zoomToSwitchOverlays - 1{
            doubleTapZoom = zoomToSwitchOverlays
        } else if mapView.camera.zoom < streetZoom {
            doubleTapZoom = streetZoom
            delegate?.mapViewControllerDidZoom(switchOn: true, shouldGetOverlay: false)
        } else {
            doubleTapZoom = mapView.camera.zoom + 1
        }
        let camera = GMSCameraPosition.cameraWithTarget(mapView.projection.coordinateForPoint(pointOnMap), zoom: doubleTapZoom)
        isZoomingIn = true
        animateMap(toCameraPosition: camera, duration: 0.8)
    }
    @objc func zoomOutDoubleTouchTapOnMap(gesture:UITapGestureRecognizer) {
        zoomMap(toZoom: mapView.camera.zoom - 1.5)
    }
    var scale:CGFloat = 0
    @objc func pinchZoom(gesture:UIPinchGestureRecognizer) {
        if gesture.state == .Began { scale = gesture.scale }
        if gesture.state == .Changed {
            let zoomScale = ((gesture.scale - scale) / scale)
            let zoom = Float( zoomScale / 10 + 1) * mapView.camera.zoom
            let coordinate = mapView.projection.coordinateForPoint(gesture.locationInView(mapView))
            zoomMap(toCoordinate: coordinate, zoom: zoom)
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
        if let currentCoordinate = dao.currentLocation?.coordinate {
            let camera = GMSCameraPosition.cameraWithTarget(currentCoordinate, zoom: streetZoom)
            zoomMap(toCamera: camera)
        }
    }
    
    
    //MARK: - Animations
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
        let turnSwitchOn: Bool? = mapView.camera.zoom < zoomToSwitchOverlays ? false : nil
        delegate?.mapViewControllerDidZoom(switchOn: turnSwitchOn, shouldGetOverlay: true)
        if mapView.camera.zoom <= initialZoom + 1 {
            zoomOutButton.hidden = true
        } else {
            zoomOutButton.hidden = false
        }
    }
    func zoomMap(toCoordinate coordinate:CLLocationCoordinate2D?, zoom:Float) {
        if coordinate != nil {
            let camera = GMSCameraPosition.cameraWithTarget(coordinate!, zoom: zoom)
            zoomMap(toCamera: camera)
        } else {
            print("Cannot zoom, nil coordinate")
        }
    }
    func zoomMap(toCamera camera:GMSCameraPosition) {
        mapView.animateToCameraPosition(camera)
        delegate?.mapViewControllerIsZooming()
    }
    func zoomMap(toZoom zoom:Float) {
        mapView.animateToZoom(zoom)
        delegate?.mapViewControllerIsZooming()
    }
    
    //MARK: -----Draw on map methods
    func getSignsForCurrentMapView() {
        if mapView.camera.zoom >= streetZoom && dao.isInNYC(mapView) {
            delegate?.mapViewControllerShouldSearchStreetCleaning(mapView)
        }
    }
    func getNewHeatMapOverlays() {
        hide(mapOverlayViews: currentGroundOverlays)
        guard dao.locationsForPrimaryTimeAndDay != nil else { return }
        currentGroundOverlays = SPGroundOverlayManager().groundOverlays(forMap: mapView, forLocations: dao.locationsForPrimaryTimeAndDay!)
        show(mapOverlayViews: currentGroundOverlays, shouldHideOtherOverlay: true)
    }
    func getNewPolylines() {
        if self.currentMapPolylines.count > 0 { self.hide(mapOverlayViews: self.currentMapPolylines) }
        var polylineManager = SPPolylineManager()
        polylineManager.inject(dao)
        self.currentMapPolylines = polylineManager.polylines(forCurrentLocations: dao.currentMapViewLocations, zoom: Double(self.mapView.camera.zoom))
        if self.currentMapPolylines.count > 0 &&  self.mapView.camera.zoom >= self.streetZoom {
            self.show(mapOverlayViews: self.currentMapPolylines, shouldHideOtherOverlay: true)
        }
        delegate?.mapViewControllerFinishedDrawingPolylines()
    }
    
    func hide(mapOverlayViews views:[GMSOverlay]) {
        for view in views { view.map = nil }
    }
    func show<MapOverlayType: GMSOverlay>(mapOverlayViews views:[MapOverlayType], shouldHideOtherOverlay:Bool) {
        if views.count > 0 {
            for view in views {  view.map = mapView }
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
    
    //MARK: GMSMarker methods
    var signMarker: GMSMarker?
    func mapView(mapView: GMSMapView, didTapOverlay overlay: GMSOverlay) {
        if let polyline = overlay as? GMSPolyline {
            guard let coordinate = SPPolylineManager.coordinate(fromPolyline: polyline) else { return }
            if signMarker != nil { signMarker?.map = nil }
            print("Hashed string: \(SPPolylineManager.hashedString(forPolyline: polyline)), sign value: \(dao.signForPathCoordinates[SPPolylineManager.hashedString(forPolyline: polyline)])")
            guard let sign: SPSign = dao.signForPathCoordinates[SPPolylineManager.hashedString(forPolyline: polyline)] else { return }
            signMarker = marker(withUserData: sign.signContent, atCoordinate: coordinate)
            mapView.selectedMarker = signMarker
        }
    }
    var searchMarker: GMSMarker?
    func setSearchMarker(withUserData userData:String, atCoordinate coordinate: CLLocationCoordinate2D) {
        if searchMarker != nil { searchMarker?.map = nil }
        searchMarker = marker(withUserData: userData, atCoordinate: coordinate)
    }
    func marker(withUserData userData: String, atCoordinate coordinate: CLLocationCoordinate2D) -> GMSMarker {
        let marker = GMSMarker.init(position: coordinate)
        marker.map = mapView
        marker.userData = userData
        return marker
    }
    
    func hideMarkerInfoWindow() {
        if isMarkerSelected {
            mapView.selectedMarker = nil
        }
    }
    func hideMarkers() {
        signMarker?.map = nil
        searchMarker?.map = nil
    }
    var isMarkerSelected: Bool {
        return mapView.selectedMarker === signMarker || mapView.selectedMarker === searchMarker
    }
    
    var currentInfoWindow: SPSignInfoOverlay?
    func mapView(mapView: GMSMapView, markerInfoWindow marker: GMSMarker) -> UIView? {
        if marker === signMarker || marker === searchMarker {
            guard let displayString = marker.userData as? String else { return nil }
            guard let infoWindow = NSBundle.mainBundle().loadNibNamed("SPSignInfoOverlay", owner: self, options: nil)[0] as? SPSignInfoOverlay else { return nil }
            infoWindow.delegate = self
            infoWindow.destinationCoordinate = marker.position
            infoWindow.signContentTextView.text = displayString
            currentInfoWindow = infoWindow
            return infoWindow
        }
        return nil
    }
    
    //MARK: Sign overlay delegate methods
    
    func signInfoViewDidTapDirectionsButton(toCoordinate coordinate:CLLocationCoordinate2D){
        alertControllerForDirections(forCoordinate: coordinate)
    }
    
    private func alertControllerForDirections(forCoordinate coordinate: CLLocationCoordinate2D) {
        if mapOptions.count == 0 { return }
        let startCoordinate = dao.currentLocation?.coordinate
        let startAddress = "\(startCoordinate!.latitude),\(startCoordinate!.longitude)"
        let endAddress = "\(coordinate.latitude),\(coordinate.longitude)"
        let alertController = UIAlertController.init(title: "Get Directions", message: nil, preferredStyle: .ActionSheet)
        for map in mapOptions {
            let parameters: String
            switch map {
            case .Apple:
                parameters = "?daddr=\(endAddress)&dirflg=d"
            case .Google: parameters = "?saddr=\(startAddress)&daddr=\(endAddress)&directionsmode=driving"
            case .Waze: parameters = "?ll=\(endAddress)&navigate=yes"
            }
            guard let mapURL = NSURL(string: map.scheme + parameters) else {continue}
            let action = UIAlertAction.init(title: map.rawValue, style: .Default, handler: { (_) in
                UIApplication.sharedApplication().openURL(mapURL)
            })
            alertController.addAction(action)
        }
        alertController.addAction(UIAlertAction.init(title: "Cancel", style: .Destructive, handler: nil))
        presentViewController(alertController, animated: true, completion: nil)
    }
    private var mapOptions: [SPMapApp] {
        var mapOptions = [SPMapApp]()
        for map in SPMapApp.allMaps {
            guard let scheme = NSURL(string:map.scheme) else { continue }
            if UIApplication.sharedApplication().canOpenURL(scheme) {
                mapOptions.append(map)
            }
        }
        return mapOptions
    }
    
    //MARK: Injectable protocol
    private var dao: SPDataAccessObject!
    func inject(dao: SPDataAccessObject) {
        self.dao = dao
    }
    func assertDependencies() {
        assert(dao != nil)
    }
}

protocol SPMapViewControllerDelegate: class {
    func mapViewControllerIsZooming()
    func mapViewControllerShouldSearchStreetCleaning(mapView: GMSMapView) -> Bool
    func mapViewControllerDidZoom(switchOn on: Bool?, shouldGetOverlay: Bool)
    func mapViewControllerFinishedDrawingPolylines()
}
