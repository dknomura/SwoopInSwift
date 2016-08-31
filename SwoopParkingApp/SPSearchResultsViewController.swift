//
//  SPSearchResultsViewController.swift
//  SwoopParkingApp
//
//  Created by Daniel Nomura on 8/30/16.
//  Copyright © 2016 Daniel Nomura. All rights reserved.
//

import Foundation

class SPSearchResultsViewController: UIViewController, UITableViewDelegate, UITableViewDataSource, UISearchBarDelegate {
    
    @IBOutlet weak var searchBar: UISearchBar!
    @IBOutlet weak var searchResultsTableView: UITableView!
    @IBOutlet weak var heightConstraintOfTableView: NSLayoutConstraint!
    @IBOutlet weak var heightConstraintOfSearchBar: NSLayoutConstraint!
    
    var dao: SPDataAccessObject?
    weak var delegate: SPSearchResultsViewControllerDelegate?
    
    var cellReuseIdentifier:String { return "cellReuseIdentifier" }
    var standardHeightOfToolOrSearchBar: CGFloat { return CGFloat(44.0) }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        searchResultsTableView.registerClass(UITableViewCell.self, forCellReuseIdentifier: cellReuseIdentifier)
        if dao == nil {
            print("DAO not passed to search view controller from map view controller")
        }
    }
    
    //MARK: - Search bar
    func searchBarTextDidBeginEditing(searchBar: UISearchBar) {
        if dao?.addressResults.count > 0 {
            showSearchResultsTableView()
        }
    }
    func searchBar(searchBar: UISearchBar, textDidChange searchText: String) {
        if searchBar.text?.characters.count > 0 {
            let googleNetworking = SPGoogleNetworking()
            googleNetworking.delegate = dao
            googleNetworking.autocomplete(searchBar.text!)
        }
    }
    func searchBarSearchButtonClicked(searchBar: UISearchBar) {
        if searchBar.text?.characters.count > 0 {
            let googleNetworking = SPGoogleNetworking()
            googleNetworking.delegate = dao
            googleNetworking.searchAddress(searchBar.text!)
        }
    }
    
    
    //MARK: - TableView Delegate/Datasource
    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard dao != nil else {
            print("DAO not passed to mapViewController, unable to get numberOfRowsInSection")
            return 0
        }
        return dao!.addressResults.count
    }
    func numberOfSectionsInTableView(tableView: UITableView) -> Int { return 1 }
    
    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        var cell = tableView.dequeueReusableCellWithIdentifier(cellReuseIdentifier)
        if cell != nil { cell = UITableViewCell.init(style: .Default, reuseIdentifier: cellReuseIdentifier) }
        cell?.textLabel!.text = dao?.addressResults[indexPath.row].address
        cell?.userInteractionEnabled = true
        return cell!
    }
    func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        guard dao != nil else {
            print("DAO not passed to mapViewController, unable to get search results for results tableview")
            return
        }
        let addressResult = dao!.addressResults[indexPath.row]
        searchBar.text = addressResult.address
        if addressResult.coordinate != nil {
            dao?.searchCoordinate = addressResult.coordinate
            delegate?.searchContainer(toPerformDelegateAction: .presentCoordinate)
        } else {
            let googleNetworking = SPGoogleNetworking()
            googleNetworking.delegate = dao
            googleNetworking.geocode(addressResultWithoutCoordinate: addressResult)
        }
    }
    
    //MARK: - TableView animation
    func showSearchResultsTableView() {
        searchResultsTableView.reloadData()
        let multipler = self.dao?.addressResults.count < 4 ? self.dao!.addressResults.count : 3
        let heightOfTableView = CGFloat(44 * multipler)
        UIView.animateWithDuration(0.2) {
            self.heightConstraintOfTableView.constant = heightOfTableView
            self.view.layoutIfNeeded()
        }
        delegate?.searchContainerDidAdjust(standardHeightOfToolOrSearchBar + heightOfTableView, isTableViewPresent: true)
    }
    func hideSearchResultsTableView() {
        UIView.animateWithDuration(0.2) {
            self.heightConstraintOfTableView.constant = 0
            self.view.layoutIfNeeded()
        }
        delegate?.searchContainerDidAdjust(standardHeightOfToolOrSearchBar , isTableViewPresent:false)
    }
    //MARK: ---SearchBar animation
    func showSearchBar() {
        let height = CGFloat(44)
        UIView.animateWithDuration(0.2, animations: {
            self.heightConstraintOfSearchBar.constant = height
            self.view.layoutIfNeeded()
        })
        delegate?.searchContainerDidAdjust(height, isTableViewPresent: false)
    }
    func hideSearchBar() {
        let height = CGFloat(0)
        UIView.animateWithDuration(0.2, animations: {
            self.heightConstraintOfSearchBar.constant = height
            self.view.layoutIfNeeded()
        })
        delegate?.searchContainerDidAdjust(height, isTableViewPresent: false)
    }
    

}

protocol SPSearchResultsViewControllerDelegate: class {
    func searchContainer(toPerformDelegateAction delegateAction:SPNetworkingDelegateAction)
    func searchContainerDidAdjust(height:CGFloat, isTableViewPresent:Bool)
}