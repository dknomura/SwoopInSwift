//
//  SPViewControllerExtension.swift
//  SwoopParkingApp
//
//  Created by Daniel Nomura on 8/15/16.
//  Copyright © 2016 Daniel Nomura. All rights reserved.
//

import Foundation
import DNTimeAndDay

extension UIViewController {
    func hideKeyboardWhenTapAround() {
        view.userInteractionEnabled = true
        let tap = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        view.addGestureRecognizer(tap)
    }
    @objc func dismissKeyboard() {
        view.endEditing(true)
    }
}

protocol SPChildViewController {
    associatedtype T
    func inject(dao: SPDataAccessObject, delegate: T)
}

extension SPChildViewController where Self: UIViewController {
    
}
