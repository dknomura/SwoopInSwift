//
//  WebViewController.swift
//  SwoopParkingApp
//
//  Created by Daniel Nomura on 11/14/16.
//  Copyright © 2016 Daniel Nomura. All rights reserved.
//

import Foundation

class WebViewController: UIViewController {
    @IBOutlet weak var webView: UIWebView!
    var url: URL!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        webView.loadRequest(URLRequest(url: url))
        webView.scalesPageToFit = true
        webView.scrollView.setContentOffset(CGPoint.zero, animated: false)
    }

    
    @IBAction func navigateBackWebView(_ sender: UIBarButtonItem) {
        webView.goBack()
    }
    @IBAction func navigateForwardWebView(_ sender: Any) {
        webView.goForward()
    }
}
