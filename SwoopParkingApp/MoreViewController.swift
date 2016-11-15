//
//  SettingsViewController.swift
//  SwoopParkingApp
//
//  Created by Daniel Nomura on 11/13/16.
//  Copyright © 2016 Daniel Nomura. All rights reserved.
//

import Foundation

class MoreViewController: UIViewController {
    @IBOutlet weak var textView: UITextView!
    @IBOutlet weak var howItWorksButton: UIButton!
    @IBOutlet weak var tipsButton: UIButton!
    @IBOutlet weak var disclaimerButton: UIButton!
    @IBOutlet weak var reviewButton: UIButton!
    @IBOutlet weak var donateButton: UIButton!
    @IBOutlet weak var holidaysButton: UIButton!
    var allButtons: [UIButton] {
        return [howItWorksButton, tipsButton, disclaimerButton, reviewButton, donateButton, holidaysButton]
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        for button in allButtons {
            button.createBorder()
        }
        textView.setContentOffset(CGPoint.zero, animated: false)
    }
    @IBAction func openAppInstructions(_ sender: UIButton) {
        if let documentName = sender.titleLabel?.text,
            let pdfPath = Bundle.main.path(forResource: documentName, ofType: "pdf")
            {
                guard let webViewController = storyboard?.instantiateViewController(withIdentifier: "webViewController") as? WebViewController else { return }
                webViewController.title = documentName
            webViewController.url = URL(fileURLWithPath: pdfPath)
                navigationController?.pushViewController(webViewController, animated: true)
            
        }
    }
    @IBAction func openReview(_ sender: UIButton) {
    }
    @IBAction func openDonate(_ sender: UIButton) {
    }
}
