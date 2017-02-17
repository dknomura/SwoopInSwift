//
//  ParkingTipsViewController.swift
//  SwoopParkingApp
//
//  Created by Daniel Nomura on 2/17/17.
//  Copyright © 2017 Daniel Nomura. All rights reserved.
//

import Foundation

class ParkingTipsViewController: UIViewController, UITextViewDelegate, WebViewPresenter {
    
    @IBOutlet weak var textView: UITextView!
    
    override func viewDidLoad() {
        textView.delegate = self
    }
    
    func textView(_ textView: UITextView, shouldInteractWith URL: URL, in characterRange: NSRange) -> Bool {
        presentWebView(withUrl: URL)
        return false
    }
}
