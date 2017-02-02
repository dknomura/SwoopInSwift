//
//  CityAndStreetToolbar.swift
//  SwoopParkingApp
//
//  Created by Daniel Nomura on 1/10/17.
//  Copyright © 2017 Daniel Nomura. All rights reserved.
//

import Foundation
import UIKit

class SignsCollectionViewController: UIViewController, UICollectionViewDelegate, UICollectionViewDataSource, InjectableViewController {
    @IBOutlet weak var collectionView: UICollectionView!
    @IBOutlet weak var radiusSlider: UISlider!
    private weak var delegate: SignsCollectionViewControllerDelegate!
    private var dao: SPDataAccessObject!
    @IBOutlet weak var collectionViewSwitch: UISwitch!
    
    @IBOutlet weak var sliderWidthConstraint: NSLayoutConstraint!
    @IBOutlet weak var moreButtonWidthConstraint: NSLayoutConstraint!
    
    var streetDetailZoom: CGFloat!
    private var sliderWidth: CGFloat {
        let maxWidth = view.frame.width - collectionViewSwitch.frame.maxX - 8
        return collectionViewSwitch.isOn ? maxWidth : 0
    }
    private var buttonWidth: CGFloat {
        return collectionViewSwitch.isOn ? 0 : 40
    }
    
    //MARK: - Lifecycle methods
    override func viewDidLoad() {
        assertDependencies()
    }
    
    //MARK: - IBAction methods
    
    @IBAction func goToMorePage(_ sender: UIButton) {
        if let moreViewController = UIStoryboard.init(name: "More", bundle: nil).instantiateInitialViewController() {
            navigationController?.pushViewController(moreViewController, animated: true)
        }
    }

    @IBAction func toggleCollectionView(_ sender: UISwitch) {
        adjustToToggleChange(isOn: sender.isOn)
    }
    
    func adjustToToggleChange(isOn:Bool){
        UIView.animate(withDuration: standardAnimationDuration) {
            self.radiusSlider.isHidden = !isOn
            self.sliderWidthConstraint.constant = self.sliderWidth
            self.moreButtonWidthConstraint.constant = self.buttonWidth
            self.view.layoutIfNeeded()
        }
        delegate.signsCollectionViewControllerDidToggleCollectionView(on: isOn)

    }
    //MARK: - CollectionView Delegate/Datasource
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return 3
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        return UICollectionViewCell(frame: CGRect.zero)
    }
    
    func inject(dao: SPDataAccessObject, delegate: Any) {
        self.dao = dao
        self.delegate = delegate as? SignsCollectionViewControllerDelegate
    }
    func assertDependencies() {
        assert(dao != nil)
    }
}


protocol SignsCollectionViewControllerDelegate: class {
    func signsCollectionViewControllerDidToggleCollectionView(on: Bool)
}
