//
//  ViewController.swift
//  SwoopParkingApp
//
//  Created by Daniel Nomura on 5/4/16.
//  Copyright © 2016 Daniel Nomura. All rights reserved.
//

import UIKit
import GoogleMaps

class SPMapViewController: UIViewController, CLLocationManagerDelegate, GMSMapViewDelegate, UIGestureRecognizerDelegate, InjectableViewController {
    
    weak var delegate: SPMapViewControllerDelegate?
    @IBOutlet weak var mapView: GMSMapView!
    var zoomOutButton = UIButton.init(type:.roundedRect)
    var myLocationButton = UIButton(type: .roundedRect)
    
    var initialMapViewCamera: GMSCameraPosition {
        return GMSCameraPosition.camera(withTarget: CLLocationCoordinate2DMake(40.7193748839769, -73.9289110153913), zoom: initialZoom)
    }
    var currentGroundOverlays = [GMSGroundOverlay]()
    var currentMapPolylines = [GMSPolyline]()
    
    var userControl = false
    var animatingFromCityView = true
    var isPinchZooming = false
    var isZoomingIn = false
    var cancelTapGesture = false
    
    var isCollectionViewSwitchOn = false
    
    var initialZoom: Float {
        return dao.currentCity.initialStreetCleaningZoom(forMapView: mapView)
    }
    var restoredCamera: GMSCameraPosition?
    
    var signMarker: GMSMarker?
    var searchMarker: GMSMarker?
    fileprivate var lastSelectedMarkerKVO: AnyObject?
    var endCoordinateBeforeLocationRequest:CLLocationCoordinate2D?
    fileprivate var dao: SPDataAccessObject!
    var isMarkerSelected: Bool {
        return mapView.selectedMarker != nil
    }
    var areMarkersPresent: Bool {
        return signMarker?.map != nil || searchMarker?.map != nil
    }
    
    var currentInfoWindow: SPSignInfoOverlay?

    //MARK: - Override methods
    override func viewDidLoad() {
        super.viewDidLoad()
        setUpMap()
        setUpButtons()
        assertDependencies()
        setupObservers()
        dao.setUpLocationManager()
    }
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        NotificationCenter.default.removeObserver(self)
    }
//    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
//        func defaultReturn() { super.observeValue(forKeyPath: keyPath, of: object, change: change, context: context) }
//        guard keyPath != nil && change != nil else {
//            defaultReturn()
//            return
//        }
//        switch keyPath! {
//        case kvoSelectedMarkerKeyPath:
//            let newSelectedMarker = change![NSKeyValueChangeKey.newKey]
//            if !(newSelectedMarker is GMSMarker) && lastSelectedMarkerKVO is GMSMarker {
//                cancelTapGesture = true
//            }
//            lastSelectedMarkerKVO = newSelectedMarker as AnyObject?
//        default:
//            defaultReturn()
//        }
//    }
    

    //MARK: - Setup/breakdown methods
    //MARK: --Gestures
    @objc func zoomToDoubleTapOnMap(_ gesture:UITapGestureRecognizer) {
        let pointOnMap = gesture.location(in: mapView)
        var doubleTapZoom: Float
        if mapView.camera.zoom < zoomToSwitchOverlays - 1{
            doubleTapZoom = zoomToSwitchOverlays
        } else if mapView.camera.zoom < streetZoom {
            doubleTapZoom = streetZoom
        } else {
            doubleTapZoom = mapView.camera.zoom + 1
        }
        let camera = GMSCameraPosition.camera(withTarget: mapView.projection.coordinate(for: pointOnMap), zoom: doubleTapZoom)
        isZoomingIn = true
        animateMap(toCameraPosition: camera, duration: 0.8)
//        delegate?.mapViewControllerDidAdjustToDoubleTap()
    }
    @objc func zoomOutDoubleTouchTapOnMap(_ gesture:UITapGestureRecognizer) {
        zoomMap(toZoom: mapView.camera.zoom - 1.5)
    }
    var scale:CGFloat = 0
    @objc func pinchZoom(_ gesture:UIPinchGestureRecognizer) {
        if gesture.state == .began { scale = gesture.scale }
        if gesture.state == .changed {
            let zoomScale = ((gesture.scale - scale) / scale)
            let zoom = Float( zoomScale / 10 + 1) * mapView.camera.zoom
            let coordinate = mapView.projection.coordinate(for: gesture.location(in: mapView))
            zoomMap(toCoordinate: coordinate, zoom: zoom)
        } else { return }
        isPinchZooming = true
    }
    
    @objc func longPressZoom(_ gesture: UILongPressGestureRecognizer) {
        if mapView.camera.zoom < streetZoom {
            let pointOnMap = gesture.location(in: mapView)
            let camera = GMSCameraPosition.camera(withTarget: mapView.projection.coordinate(for: pointOnMap), zoom: streetZoom)
            isZoomingIn = true
            animateMap(toCameraPosition: camera, duration: 0.7)
        }
    }
    
    //MARK: --Observers
    fileprivate func setupObservers() {
        NotificationCenter.default.addObserver(self, selector: #selector(signsCollectionViewControllerDidToggleCollectionView(notification:)), name: collectionViewSwitchChangeNotification, object: nil)
    }
    
    
    //MARK: Notification methods
    func signsCollectionViewControllerDidToggleCollectionView(notification: Notification) {
        if let isOn = notification.userInfo?[collectionViewSwitchKey] as? Bool {
            isCollectionViewSwitchOn = isOn
        }
    }

    
    //MARK: --Views
    fileprivate func setUpMap() {
        mapView.camera = restoredCamera != nil ? restoredCamera! : initialMapViewCamera
        mapView.settings.rotateGestures = false
        mapView.settings.zoomGestures = false
        mapView.settings.tiltGestures = false
        mapView.delegate = self
        mapView.settings.consumesGesturesInView = false
        if UserDefaults.standard.bool(forKey: kSPDidAllowLocationServices) {
            mapView.isMyLocationEnabled = true

        }
    }
    
    fileprivate func setUpButtons() {
        zoomOutButton.setTitle("Zoom to", for: UIControlState())
        zoomOutButton.titleLabel?.font = UIFont(name: "Christopherhand", size: 25)
        let buttonSize = zoomOutButton.intrinsicContentSize
        zoomOutButton.frame = CGRect(x:8, y:8, width: buttonSize.width, height: buttonSize.height)
        zoomOutButton.backgroundColor = UIColor.white
        zoomOutButton.alpha = 0.8
        zoomOutButton.isHidden = true
        zoomOutButton.addTarget(self, action: #selector(zoomOut(_:)), for: .touchUpInside)
        mapView.addSubview(zoomOutButton)
        
        guard let locationImage = UIImage.init(named: "location-icon") else { return }
        myLocationButton.imageView?.contentMode = .scaleAspectFit
        myLocationButton.setImage(locationImage, for: .normal)
        myLocationButton.translatesAutoresizingMaskIntoConstraints = false
        myLocationButton.addTarget(self, action: #selector(moveCameraToUserLocation), for: .touchUpInside)
        mapView.addSubview(myLocationButton)
        let rightConstraint = NSLayoutConstraint(item: mapView, attribute: .rightMargin, relatedBy: .equal, toItem: myLocationButton, attribute: .right, multiplier: 1, constant: 8)
        let bottomConstraint = NSLayoutConstraint(item: mapView, attribute: .bottomMargin, relatedBy: .equal, toItem: myLocationButton, attribute: .bottom, multiplier: 1, constant: 8)
        let heightConstraint = NSLayoutConstraint(item: myLocationButton, attribute: .height, relatedBy: .equal, toItem: nil, attribute: .notAnAttribute, multiplier: 1, constant: 40)
        let widthConstraint = NSLayoutConstraint(item: myLocationButton, attribute: .width, relatedBy: .equal, toItem: nil, attribute: .notAnAttribute, multiplier: 1, constant: 40)
        NSLayoutConstraint.activate([rightConstraint, bottomConstraint, heightConstraint, widthConstraint])
    }
    
    //MARK: - Button Methods
    //MARK: -- Other buttons
    @objc fileprivate func zoomOut(_ sender:UIButton) {
        mapView.animate(to: initialMapViewCamera)
    }
    @objc fileprivate func moveCameraToUserLocation() {
        goToUserLocation()
    }
    fileprivate func goToUserLocation() {
        if UserDefaults.standard.bool(forKey: kSPDidAllowLocationServices) {
            if let currentCoordinate = dao.currentLocation?.coordinate {
                let zoomTo = isCollectionViewSwitchOn ? zoomToSwitchOverlays : streetZoom
                let camera = GMSCameraPosition.camera(withTarget: currentCoordinate, zoom: zoomTo)
                animateMap(toCameraPosition: camera, duration: 0.6)
            }
        } else {
            dao.locationManager.requestWhenInUseAuthorization()
        }

    }
    
    //MARK: - Animations
    // MARK: --Map animation methods
    fileprivate func animateMap(toCameraPosition cameraPosition:GMSCameraPosition, duration:Float) {
        CATransaction.begin()
        CATransaction.setCompletionBlock { 
            self.adjustViewsToZoom()
        }
        CATransaction.setValue(duration, forKey: kCATransactionAnimationDuration)
        zoomMap(toCamera: cameraPosition)
        CATransaction.commit()
    }
    
    func adjustViewsToZoom() {
        if mapView.camera.zoom >= streetZoom {
            guard mapView.isIn(city: dao.currentCity) else {
                print("Current mapview is not in nyc, \(mapView)")
                return
            }
            _ = delegate?.mapViewControllerShouldSearchStreetCleaning(mapView)
        } else {
            if dao.locationsForPrimaryTimeAndDay == nil {
                delegate?.mapViewControllerShouldSearchLocationsForTimeAndDay()
            } else {
                getNewHeatMapOverlays()
            }
        }
        if mapView.camera.zoom > initialZoom ||
            mapView.camera.zoom < initialZoom - 1 ||
            !mapView.isIn(city: dao.currentCity) {
            zoomOutButton.isHidden = false
        } else {
            zoomOutButton.isHidden = true
        }
    }
    func zoomMap(toCoordinate coordinate:CLLocationCoordinate2D?, zoom:Float) {
        if coordinate != nil {
            let camera = GMSCameraPosition.camera(withTarget: coordinate!, zoom: zoom)
            zoomMap(toCamera: camera)
        } else {
            print("Cannot zoom, nil coordinate")
        }
    }
    func zoomMap(toCamera camera:GMSCameraPosition) {
        mapView.animate(to: camera)
        delegate?.mapViewControllerIsZooming()
    }
    func zoomMap(toZoom zoom:Float) {
        mapView.animate(toZoom: zoom)
        delegate?.mapViewControllerIsZooming()
    }
    
    //MARK: -----Draw on map methods
    func getNewHeatMapOverlays() {
        hide(mapOverlayViews: currentGroundOverlays)
        guard dao.locationsForPrimaryTimeAndDay != nil else { return }
        currentGroundOverlays = SPGroundOverlayManager().groundOverlays(forMap: mapView, forLocations: dao.locationsForPrimaryTimeAndDay!)
        show(mapOverlayViews: currentGroundOverlays, shouldHideOtherOverlay: true)
    }
    func getNewPolylines() {
        if dao.currentMapViewLocations.count == 0 {
            delegate?.mapViewControllerDidFinishDrawingPolylines()
            return
        }
        if currentMapPolylines.count > 0 { hide(mapOverlayViews: currentMapPolylines) }
        var polylineManager = SPPolylineManager()
        polylineManager.inject(dao)
        currentMapPolylines = polylineManager.polylines(forCurrentLocations: dao.currentMapViewLocations, zoom: Double(mapView.camera.zoom))
        if currentMapPolylines.count > 0 &&  mapView.camera.zoom >= streetZoom {
            show(mapOverlayViews: currentMapPolylines, shouldHideOtherOverlay: true)
        }
    }
    
    func hide(mapOverlayViews views:[GMSOverlay]) {
        for view in views { view.map = nil }
    }
    func show<MapOverlayType: GMSOverlay>(mapOverlayViews views:[MapOverlayType], shouldHideOtherOverlay:Bool) {
        if views.count > 0 {
            CATransaction.begin()
            CATransaction.setCompletionBlock({ [unowned self] in
                self.delegate?.mapViewControllerDidFinishDrawingPolylines()
            })
            for view in views {
                view.map = mapView
            }
            CATransaction.commit()
            if shouldHideOtherOverlay {
                if MapOverlayType() is GMSPolyline { hide(mapOverlayViews: currentGroundOverlays) }
                else if MapOverlayType() is GMSGroundOverlay { hide(mapOverlayViews: currentMapPolylines) }
            }
        }
    }
    
    // MARK: - Delegate Methods
    //MARK: --MapView delegate
    func mapView(_ mapView: GMSMapView, idleAt position: GMSCameraPosition) {
        adjustViewsToZoom()
        if isZoomingIn { isZoomingIn = false }
        if isPinchZooming && currentMapPolylines.count > 0 { isPinchZooming = false }
    }
    func mapView(_ mapView: GMSMapView, didChange position: GMSCameraPosition) {
        if (isPinchZooming || isZoomingIn){
            adjustViewsToZoom()
        }
    }
    func mapView(_ mapView: GMSMapView, willMove gesture: Bool) {
        if (gesture) { userControl = true }
        else { userControl = false }
    }
    
    //MARK: ----Methods for GMSMarker
    func mapView(_ mapView: GMSMapView, didTap overlay: GMSOverlay) {
        if let polyline = overlay as? GMSPolyline {
            guard let coordinate = SPPolylineManager.coordinate(fromPolyline: polyline) else { return }
            if signMarker != nil { signMarker?.map = nil }
            guard let sign: SPSign = dao.signForPathCoordinates[SPPolylineManager.hashedString(forPolyline: polyline)] else { return }
            signMarker = marker(withUserData: sign.markerContent, atCoordinate: coordinate)
            mapView.selectedMarker = signMarker
        }
    }
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
    
    func hideMarkers() {
        if signMarker?.map != nil {
            signMarker?.map = nil
        }
        if searchMarker?.map != nil {
            searchMarker?.map = nil
        }
    }
    func mapView(_ mapView: GMSMapView, markerInfoWindow marker: GMSMarker) -> UIView? {
        if marker === signMarker || marker === searchMarker {
            guard let displayString = marker.userData as? String else { return nil }
            guard let infoWindow = Bundle.main.loadNibNamed("SPSignInfoOverlay", owner: self, options: nil)?[0] as? SPSignInfoOverlay else { return nil }
            infoWindow.destinationCoordinate = marker.position
            infoWindow.signContentLabel.text = displayString
            currentInfoWindow = infoWindow
            cancelTapGesture = true
            if marker == searchMarker {
                infoWindow.signImage.image = nil
                infoWindow.signImageWidth.constant = 0
                infoWindow.layoutIfNeeded()
            }
            return infoWindow
        }
        return nil
    }
    
    func mapView(_ mapView: GMSMapView, didTapInfoWindowOf marker: GMSMarker) {
        if UserDefaults.standard.bool(forKey: kSPDidAllowLocationServices) {
            presentAlertControllerForDirections(forCoordinate: marker.position)
        } else {
            dao.locationManager.requestWhenInUseAuthorization()
            mapView.isMyLocationEnabled = true
            endCoordinateBeforeLocationRequest = marker.position
        }
    }

    
    //MARK: - Open map app
    func presentAlertControllerForDirections(forCoordinate coordinate: CLLocationCoordinate2D) {
        if SPMapApp.appsForThisDevice.count == 0 { return }
        guard let startCoordinate = dao.currentLocation?.coordinate else { return }
        let startAddress = "\(startCoordinate.latitude),\(startCoordinate.longitude)"
        let endAddress = "\(coordinate.latitude),\(coordinate.longitude)"
        let alertController = UIAlertController.init(title: "Get Directions", message: nil, preferredStyle: .actionSheet)
        for mapApp in SPMapApp.appsForThisDevice {
            let parameters: String
            switch mapApp {
            case .Apple:
                parameters = "?saddr=\(startAddress)&daddr=\(endAddress)&dirflg=d"
            case .Google: parameters = "?saddr=\(startAddress)&daddr=\(endAddress)&directionsmode=driving"
            case .Waze: parameters = "?ll=\(endAddress)&navigate=yes"
            }
            guard let mapURL = URL(string: mapApp.scheme + parameters) else {continue}
            let action = UIAlertAction.init(title: mapApp.rawValue, style: .default, handler: { (_) in
                UIApplication.shared.openURL(mapURL)
            })
            alertController.addAction(action)
        }
        if alertController.actions.count == 0 { return }
        alertController.addAction(UIAlertAction.init(title: "Cancel", style: .destructive, handler: nil))
        present(alertController, animated: true, completion: nil)
    }
    enum SPMapApp: String {
        case Google
        case Apple
        case Waze
        var scheme: String {
            switch self {
            case .Google: return "comgooglemaps://"
            case .Apple: return "http://maps.apple.com/"
            case .Waze: return "waze://"
            }
        }
        static var allMaps: [SPMapApp] {
            return [Google, Apple, Waze]
        }
        static var appsForThisDevice: [SPMapApp] {
            var mapOptions = [SPMapApp]()
            for mapApp in SPMapApp.allMaps {
                guard let scheme = URL(string:mapApp.scheme) else { continue }
                if UIApplication.shared.canOpenURL(scheme) {
                    mapOptions.append(mapApp)
                }
            }
            return mapOptions
        }
    }

    
    //MARK: Injectable protocol
    func inject(dao: SPDataAccessObject, delegate: Any) {
        self.dao = dao
        self.delegate = delegate as? SPMapViewControllerDelegate
    }
    func assertDependencies() {
        assert(dao != nil)
    }
}

protocol SPMapViewControllerDelegate: class {
    func mapViewControllerIsZooming()
    func mapViewControllerShouldSearchStreetCleaning(_ mapView: GMSMapView) -> Bool
    func mapViewControllerDidFinishDrawingPolylines()
    func mapViewControllerShouldSearchLocationsForTimeAndDay()
}


