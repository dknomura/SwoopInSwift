//
//  CityAndStreetToolbar.swift
//  SwoopParkingApp
//
//  Created by Daniel Nomura on 1/10/17.
//  Copyright © 2017 Daniel Nomura. All rights reserved.
//

import Foundation
import UIKit

class CityAndStreetToolbar: UIViewController {
    @IBOutlet weak var cityStreetLabel: UILabel!
    @IBOutlet weak var cityStreetSwitch: UISwitch!
    @IBOutlet weak var radiusTextField: UITextField!
    @IBOutlet weak var moreButton: UIButton!
//
//    
//    var switchLabelText: String { return streetViewSwitch.isOn ? "Street" : "City" }
//
//    
//    @IBAction func goToMorePage(_ sender: UIButton) {
//    }
//
//    
//    //MARK: --Swoop toggle
//    @IBAction func toggleOverlaySwitch(_ sender: UISwitch) {
//        if sender.isOn {
//            showHideSearchBar(shouldShow: true, makeFirstResponder: true)
//            turnStreetSwitch(on: false, shouldGetOverlays: false)
//        } else {
//            mapViewController.zoomMap(toCamera: mapViewController.initialMapViewCamera)
//            
//        }
//        //        if mapViewController.mapView.camera.zoom <= mapViewController.zoomToSwitchOverlays {
//        //            if !sender.isOn { return }
//        //            mapViewController.zoomMap(toZoom: mapViewController.streetZoom)
//        //        } else {
//        //            if sender.isOn { return }
//        //            mapViewController.zoomMap(toZoom: mapViewController.zoomToSwitchOverlays)
//        //        }
//    }
//    func turnStreetSwitch(on: Bool?, shouldGetOverlays: Bool) {
//        if on != nil {
//            streetViewSwitch.setOn(on!, animated: true)
//        }
//        switchLabel.setTitle(switchLabelText, for: .normal)
//        if shouldGetOverlays {
//            mapViewController.getSignsForCurrentMapView()
//        }
//    }
//
//    @IBAction func switchCityStreetMode(_ sender: UISwitch) {
//    }
//
    
}
