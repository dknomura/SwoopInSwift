//
//  SPSearchResultsViewController.swift
//  SwoopParkingApp
//
//  Created by Daniel Nomura on 8/30/16.
//  Copyright © 2016 Daniel Nomura. All rights reserved.
//

import Foundation

class SPSearchResultsViewController: UIViewController, UITableViewDelegate, UITableViewDataSource, UISearchBarDelegate, InjectableViewController {
    
    @IBOutlet weak var searchBar: UISearchBar!
    @IBOutlet weak var searchResultsTableView: UITableView!
    @IBOutlet weak var heightConstraintOfTableView: NSLayoutConstraint!
    @IBOutlet weak var heightConstraintOfSearchBar: NSLayoutConstraint!
    fileprivate var dao: SPDataAccessObject!
    weak var delegate: SPSearchResultsViewControllerDelegate?
    var isSwitchOn = false
    
    var cellReuseIdentifier:String { return "searchResultsCellIdentifier" }
    var standardHeightOfToolOrSearchBar: CGFloat { return CGFloat(44.0) }
    var numberOfRows: Int {
        return dao.currentLocation == nil ? dao.addressResults.count : dao.addressResults.count + 1
    }
    
    //MARK: - View life cycle methods
    override func viewDidLoad() {
        super.viewDidLoad()
        searchResultsTableView.register(UITableViewCell.self, forCellReuseIdentifier: cellReuseIdentifier)
        searchResultsTableView.isUserInteractionEnabled = true
        assertDependencies()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        NotificationCenter.default.removeObserver(self)
    }
    
    //MARK: - Search bar
    func searchBarTextDidBeginEditing(_ searchBar: UISearchBar) {
        showSearchResultsTableView()
    }
    
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        if (searchBar.text?.characters.count)! > 0 {
            var googleNetworking = SPGoogleNetworking()
            googleNetworking.delegate = dao
            googleNetworking.autocomplete(searchBar.text!)
        } else if searchBar.text?.characters.count == 0 {
            hideSearchResultsTableView()
        }
    }
 
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        if (searchBar.text?.characters.count)! > 0 {
            var googleNetworking = SPGoogleNetworking()
            googleNetworking.delegate = dao
            googleNetworking.searchAddress(searchBar.text!, city: dao.currentCity)
        }
    }
    
    
    //MARK: - TableView Delegate/Datasource
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return numberOfRows
    }
    func numberOfSections(in tableView: UITableView) -> Int { return 1 }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        var cell = tableView.dequeueReusableCell(withIdentifier: cellReuseIdentifier)
        if cell != nil { cell = UITableViewCell.init(style: .default, reuseIdentifier: cellReuseIdentifier) }
        if indexPath.row == 0 && dao.currentLocation != nil {
            cell?.textLabel?.text = "My Location"
        } else {
            let row = dao.currentLocation != nil ? indexPath.row - 1 : indexPath.row
            cell?.textLabel?.text = dao.addressResults[row].address
        }
        cell?.isUserInteractionEnabled = true
        return cell!
    }
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if indexPath.row == 0 && dao.currentLocation != nil {
            dao.searchCoordinate = dao.currentLocation?.coordinate
            searchBar.text = "(\(dao.searchCoordinate?.longitude)), (\(dao.searchCoordinate?.latitude))"
            delegate?.searchContainer(toPerformDelegateAction: .presentCoordinate, withInfo: nil)
            return
        }
        let row = dao.currentLocation != nil ? indexPath.row - 1 : indexPath.row

        let addressResult = dao.addressResults[row]
        searchBar.text = addressResult.address
        if addressResult.coordinate != nil {
            dao.googleSearchObject.coordinate = addressResult.coordinate
            dao.googleSearchObject.info = addressResult.address
            delegate?.searchContainer(toPerformDelegateAction: .presentCoordinate, withInfo: addressResult.address)
        } else {
            var googleNetworking = SPGoogleNetworking()
            googleNetworking.delegate = dao
            googleNetworking.geocode(addressResultWithoutCoordinate: addressResult)
        }
    }
    
    //MARK: - TableView animation
    func showSearchResultsTableView() {
        searchResultsTableView.reloadData()
        let multipler = numberOfRows < 4 ? numberOfRows : 3
        let heightOfTableView = standardHeightOfToolOrSearchBar * CGFloat(multipler)
        if delegate!.searchContainerHeightShouldAdjust(standardHeightOfToolOrSearchBar + heightOfTableView, tableViewPresent: true, searchBarPresent: true) {
            UIView.animate(withDuration: standardAnimationDuration, animations: {
                self.heightConstraintOfTableView.constant = heightOfTableView
                self.view.layoutIfNeeded()
            }) 
        }
    }
    func hideSearchResultsTableView() {
        if delegate!.searchContainerHeightShouldAdjust(standardHeightOfToolOrSearchBar, tableViewPresent: false, searchBarPresent: true) {
            UIView.animate(withDuration: standardAnimationDuration, animations: {
                self.heightConstraintOfTableView.constant = 0
                self.view.layoutIfNeeded()
            }) 
        }
    }
    //MARK: - SearchBar animation
    func showSearchBar(makeFirstResponder: Bool) {
        let height = standardHeightOfToolOrSearchBar
        if delegate!.searchContainerHeightShouldAdjust(height, tableViewPresent: false, searchBarPresent: true) {
            UIView.animate(withDuration: standardAnimationDuration, animations: {
                self.heightConstraintOfSearchBar.constant = height
                self.view.layoutIfNeeded()
            })
        }
        if makeFirstResponder {
            searchBar.becomeFirstResponder()
        }
    }
    func hideSearchBar() {
        let height = CGFloat(0)
        if delegate!.searchContainerHeightShouldAdjust(height, tableViewPresent: false, searchBarPresent: false) {
            UIView.animate(withDuration: standardAnimationDuration, animations: {
                self.heightConstraintOfSearchBar.constant = height
                self.view.layoutIfNeeded()
                if self.heightConstraintOfTableView.constant > 0 {
                    self.hideSearchResultsTableView()
                }
            })
        }
        searchBar.resignFirstResponder()
    }
    
    //MARK: Injectable protocol
    func inject(dao: SPDataAccessObject, delegate: Any) {
        self.dao = dao
        self.delegate = delegate as? SPSearchResultsViewControllerDelegate
    }
    func assertDependencies() {
        assert(dao != nil)
    }

}

protocol SPSearchResultsViewControllerDelegate: class {
    func searchContainer(toPerformDelegateAction delegateAction:SPNetworkingDelegateAction, withInfo: String?)
    func searchContainerHeightShouldAdjust(_ height:CGFloat, tableViewPresent:Bool, searchBarPresent:Bool) -> Bool
}
