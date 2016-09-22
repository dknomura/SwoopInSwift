//
//  SPSearchResultsViewController.swift
//  SwoopParkingApp
//
//  Created by Daniel Nomura on 8/30/16.
//  Copyright © 2016 Daniel Nomura. All rights reserved.
//

import Foundation

class SPSearchResultsViewController: UIViewController, UITableViewDelegate, UITableViewDataSource, UISearchBarDelegate, SPInjectable {
    
    @IBOutlet weak var searchBar: UISearchBar!
    @IBOutlet weak var searchResultsTableView: UITableView!
    @IBOutlet weak var heightConstraintOfTableView: NSLayoutConstraint!
    @IBOutlet weak var heightConstraintOfSearchBar: NSLayoutConstraint!
    
    weak var delegate: SPSearchResultsViewControllerDelegate?
    
    var cellReuseIdentifier:String { return "searchResultsCellIdentifier" }
    var standardHeightOfToolOrSearchBar: CGFloat { return CGFloat(44.0) }
    
    //MARK: Injectable protocol
    private var dao: SPDataAccessObject!
    func inject(dao: SPDataAccessObject) {
        self.dao = dao
    }
    func assertDependencies() {
        assert(dao != nil)
    }
    
    //MARK: Setup ViewController
    override func viewDidLoad() {
        super.viewDidLoad()
        searchResultsTableView.registerClass(UITableViewCell.self, forCellReuseIdentifier: cellReuseIdentifier)
        searchResultsTableView.userInteractionEnabled = true
        assertDependencies()
    }
    
    //MARK: - Search bar
    func searchBarTextDidBeginEditing(searchBar: UISearchBar) {
        if searchBar.text?.characters.count == 0 {
            hideSearchResultsTableView()
        } else if dao.addressResults.count > 0 {
            showSearchResultsTableView()
        }
    }
    func searchBar(searchBar: UISearchBar, textDidChange searchText: String) {
        if searchBar.text?.characters.count > 0 {
            let googleNetworking = SPGoogleNetworking()
            googleNetworking.delegate = dao
            googleNetworking.autocomplete(searchBar.text!)
        } else if searchBar.text?.characters.count == 0 {
            hideSearchResultsTableView()
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
        return dao.addressResults.count
    }
    func numberOfSectionsInTableView(tableView: UITableView) -> Int { return 1 }
    
    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        var cell = tableView.dequeueReusableCellWithIdentifier(cellReuseIdentifier)
        if cell != nil { cell = UITableViewCell.init(style: .Default, reuseIdentifier: cellReuseIdentifier) }
        cell?.textLabel!.text = dao.addressResults[indexPath.row].address
        cell?.userInteractionEnabled = true
        return cell!
    }
    func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        let addressResult = dao.addressResults[indexPath.row]
        searchBar.text = addressResult.address
        if addressResult.coordinate != nil {
            dao.searchCoordinate = addressResult.coordinate
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
        let multipler = self.dao.addressResults.count < 4 ? self.dao.addressResults.count : 3
        let heightOfTableView = standardHeightOfToolOrSearchBar * CGFloat(multipler)
        if delegate!.searchContainerHeightShouldAdjust(standardHeightOfToolOrSearchBar + heightOfTableView, isTableViewPresent: true, isSearchBarPresent: true) {
            UIView.animateWithDuration(standardAnimationDuration) {
                self.heightConstraintOfTableView.constant = heightOfTableView
                self.view.layoutIfNeeded()
            }

        }
    }
    func hideSearchResultsTableView() {
        if delegate!.searchContainerHeightShouldAdjust(standardHeightOfToolOrSearchBar, isTableViewPresent: false, isSearchBarPresent: true) {
            UIView.animateWithDuration(standardAnimationDuration) {
                self.heightConstraintOfTableView.constant = 0
                self.view.layoutIfNeeded()
            }
        }
    }
    //MARK: - SearchBar animation
    func showSearchBar() {
        let height = standardHeightOfToolOrSearchBar
        if delegate!.searchContainerHeightShouldAdjust(height, isTableViewPresent: false, isSearchBarPresent: true) {
            UIView.animateWithDuration(standardAnimationDuration, animations: {
                self.heightConstraintOfSearchBar.constant = height
                self.view.layoutIfNeeded()
            })
        }
    }
    func hideSearchBar() {
        let height = CGFloat(0)
        if delegate!.searchContainerHeightShouldAdjust(height, isTableViewPresent: false, isSearchBarPresent: false) {
            UIView.animateWithDuration(standardAnimationDuration, animations: {
                self.heightConstraintOfSearchBar.constant = height
                self.view.layoutIfNeeded()
            })
        }
        searchBar.resignFirstResponder()
    }
}

protocol SPSearchResultsViewControllerDelegate: class {
    func searchContainer(toPerformDelegateAction delegateAction:SPNetworkingDelegateAction)
    func searchContainerHeightShouldAdjust(height:CGFloat, isTableViewPresent:Bool, isSearchBarPresent:Bool) -> Bool
}