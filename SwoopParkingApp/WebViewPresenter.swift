//
//  WebViewPresenter.swift
//  SwoopParkingApp
//
//  Created by Daniel Nomura on 2/17/17.
//  Copyright © 2017 Daniel Nomura. All rights reserved.
//

import Foundation

protocol WebViewPresenter {
    func presentWebView(withUrl: URL?)
}

extension WebViewPresenter where Self: UIViewController {
    func presentWebView(withUrl: URL?) {
        guard let webViewController = storyboard?.instantiateViewController(withIdentifier: "webViewController") as? WebViewController,
            let url = withUrl else {
            showWebPageError()
            return
        }        
        webViewController.url = url
        navigationController?.pushViewController(webViewController, animated: true)
    }
    
    func showWebPageError() {
        let alertController = UIAlertController(title: "Unable to open webpage", message: nil, preferredStyle: .alert)
        let confirmation = UIAlertAction(title: "Okay", style: .default, handler: nil)
        alertController.addAction(confirmation)
        present(alertController, animated: true, completion: nil)
    }

}
