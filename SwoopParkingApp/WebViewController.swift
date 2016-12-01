//
//  WebViewController.swift
//  SwoopParkingApp
//
//  Created by Daniel Nomura on 11/14/16.
//  Copyright © 2016 Daniel Nomura. All rights reserved.
//

import Foundation

class WebViewController: UIViewController, UIWebViewDelegate {
    @IBOutlet weak var webView: UIWebView!
    var url: URL!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        webView.loadRequest(URLRequest(url: url))
        webView.scalesPageToFit = true
        webView.delegate = self
    }

    
    @IBAction func navigateBackWebView(_ sender: UIBarButtonItem) {
        webView.goBack()
    }
    @IBAction func navigateForwardWebView(_ sender: Any) {
        webView.goForward()
    }
    
    func webViewDidFinishLoad(_ webView: UIWebView) {
//        webView.scrollView.contentOffset = CGPoint.zero
        webView.scrollView.scrollRectToVisible(CGRect(x: 0, y: webView.frame.height, width: 1, height: 1), animated: false)
    }
}
