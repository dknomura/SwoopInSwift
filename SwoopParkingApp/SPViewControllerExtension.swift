//
//  SPViewControllerExtension.swift
//  SwoopParkingApp
//
//  Created by Daniel Nomura on 8/15/16.
//  Copyright © 2016 Daniel Nomura. All rights reserved.
//

import Foundation

protocol SPViewControllerDelegate: class {}

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