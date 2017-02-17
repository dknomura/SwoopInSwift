//
//  HowItWorksViewController.swift
//  SwoopParkingApp
//
//  Created by Daniel Nomura on 2/17/17.
//  Copyright © 2017 Daniel Nomura. All rights reserved.
//

import Foundation

class HowItWorksViewController: UIViewController, UITextViewDelegate, WebViewPresenter {
    
    @IBOutlet weak var firstTextView: UITextView!
    @IBOutlet weak var secondTextView: UITextView!
    
    override func viewDidLoad() {
        firstTextView.delegate = self
        secondTextView.delegate = self
    }
    
    func textView(_ textView: UITextView, shouldInteractWith URL: URL, in characterRange: NSRange) -> Bool {
        presentWebView(withUrl: URL)
        return false
    }
}
