//
//  SettingsViewController.swift
//  SwoopParkingApp
//
//  Created by Daniel Nomura on 11/13/16.
//  Copyright © 2016 Daniel Nomura. All rights reserved.
//

import Foundation
import StoreKit

class MoreViewController: UIViewController, SKProductsRequestDelegate, SKPaymentTransactionObserver {
    @IBOutlet weak var textView: UITextView!
    @IBOutlet weak var howItWorksButton: UIButton!
    @IBOutlet weak var tipsButton: UIButton!
    @IBOutlet weak var disclaimerButton: UIButton!
    @IBOutlet weak var reviewButton: UIButton!
    @IBOutlet weak var donateButton: UIButton!
    @IBOutlet weak var holidaysButton: UIButton!
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!
    var allButtons: [UIButton] {
        return [howItWorksButton, tipsButton, disclaimerButton, reviewButton, donateButton, holidaysButton]
    }
    let donationProductID = "com.dnom.SwoopParkingApp.Donation"
    let userDefaultsDonationKey = "donated"
    var allDonationOptions: [SKProduct]?
    var purchasedDonation: SKProduct?
    
    fileprivate var cancelAction: UIAlertAction { return UIAlertAction(title: "Cancel", style: .cancel, handler: nil) }
    
    //MARK: - Override methods
    override func viewDidLoad() {
        super.viewDidLoad()
        for button in allButtons {
            button.createBorder()
        }
        SKPaymentQueue.default().add(self)
    }
    
    
    //MARK: - Button methods
    
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
        goToAppStoreReview()
    }

    @IBAction func openDonate(_ sender: UIButton) {
        if SKPaymentQueue.canMakePayments() {
            let productIDs = ["", "99", "199", "399", "499", "1999"].map{ return donationProductID + $0 }
            let productsRequest = SKProductsRequest(productIdentifiers: Set(productIDs))
            productsRequest.delegate = self
            productsRequest.start()
            activityIndicator.startAnimating()
        } else {
            print("Can't make purchases")
        }
    }

    //MARK: - Products Request Delegate
    
    func productsRequest(_ request: SKProductsRequest, didReceive response: SKProductsResponse) {
        allDonationOptions = response.products
    }
    func requestDidFinish(_ request: SKRequest) {
        guard let _ = allDonationOptions else { return }
        allDonationOptions = allDonationOptions?.sorted { return $0.0.price.compare($0.1.price) == .orderedAscending }
        let actionController = UIAlertController(title: "Donate?", message: "Honestly surprised you clicked this far", preferredStyle: .actionSheet)
        for donation in allDonationOptions! {
            let action = UIAlertAction(title: "$" + donation.price.stringValue + ". \(donation.localizedTitle)", style: .default, handler: { [unowned self] _ in
                self.purchase(donation: donation)
                self.purchasedDonation = donation
                
                let nestedAlertController = UIAlertController(title: "Thank you!", message: "\(donation.localizedDescription)", preferredStyle: .alert)
                nestedAlertController.addAction(UIAlertAction(title: "Review too?", style: .default, handler: { [unowned self] _ in self.goToAppStoreReview() }))
                nestedAlertController.addAction(UIAlertAction(title: "Done", style: .default, handler: nil))
                nestedAlertController.addAction(self.cancelAction)
                self.present(nestedAlertController, animated: true, completion: nil)
            })
            actionController.addAction(action)
        }
        actionController.addAction(cancelAction)
        present(actionController, animated: true, completion: nil)
        activityIndicator.stopAnimating()
    }
    func request(_ request: SKRequest, didFailWithError error: Error) {
        showPurchaseErrorAlert(withMessage: error.localizedDescription)
    }
    
    //MARK: - Payment observer methods
    func paymentQueue(_ queue: SKPaymentQueue, updatedTransactions transactions: [SKPaymentTransaction]) {
        for transaction in transactions {
            print("Transaction state: \(transaction.transactionState.rawValue)")
            let defaults = UserDefaults.standard
            switch transaction.transactionState {
            case .purchased:
                SKPaymentQueue.default().finishTransaction(transaction)
                defaults.set(defaults.integer(forKey: userDefaultsDonationKey) + 1, forKey: userDefaultsDonationKey)
            case .failed:
                showPurchaseErrorAlert(withMessage: "Unable to make purchase")
                SKPaymentQueue.default().finishTransaction(transaction)
            default: break
            }
        }
    }
    
    //MARK: - Private methods 
    
    fileprivate func goToAppStoreReview() {
        guard let url = URL(string:"https://itunes.apple.com/us/app/swoopparking/id1165457062?ls=1&mt=8") else { return }
        if #available(iOS 10.0, *) {
            UIApplication.shared.open(url, completionHandler: { if !$0 { print("Error: Could not open \(url.absoluteString)") }})
        } else {
            UIApplication.shared.openURL(url)
        }
        
    }
    fileprivate func purchase(donation product: SKProduct) {
        let payment = SKPayment(product: product)
        SKPaymentQueue.default().add(payment)
    }
    
    fileprivate func showPurchaseErrorAlert(withMessage message: String) {
        let alertController = UIAlertController(title: "Error with purchase", message: message, preferredStyle: .alert)
        alertController.addAction(UIAlertAction(title: "Ok", style: .default, handler: nil))
        present(alertController, animated: true, completion: nil)
        
    }

}
