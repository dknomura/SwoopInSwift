//
//  SPSignInfoOverlay.swift
//  SwoopParkingApp
//
//  Created by Daniel Nomura on 10/7/16.
//  Copyright © 2016 Daniel Nomura. All rights reserved.
//

import Foundation


class SPSignInfoOverlay: UIView, UITextViewDelegate {
    
    @IBOutlet weak var signContentLabel: UILabel!
    var destinationCoordinate: CLLocationCoordinate2D?
}
