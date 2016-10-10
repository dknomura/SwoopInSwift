//
//  SPSignInfoOverlay.swift
//  SwoopParkingApp
//
//  Created by Daniel Nomura on 10/7/16.
//  Copyright © 2016 Daniel Nomura. All rights reserved.
//

import Foundation


class SPSignInfoOverlay: UIView {
    weak var delegate: SPSignInfoOverlayDelegate?
    @IBOutlet weak var signContentTextView: UITextView!
    var destinationCoordinate: CLLocationCoordinate2D?
    @IBAction func getDirections(sender: UIButton) {
        guard destinationCoordinate != nil else { return }
        delegate?.signInfoViewDidTapDirectionsButton(toCoordinate: destinationCoordinate!)
    }
}

protocol SPSignInfoOverlayDelegate: class {
    func signInfoViewDidTapDirectionsButton(toCoordinate coordinate:CLLocationCoordinate2D)
}