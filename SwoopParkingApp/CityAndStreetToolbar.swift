//
//  CityAndStreetToolbar.swift
//  SwoopParkingApp
//
//  Created by Daniel Nomura on 1/10/17.
//  Copyright © 2017 Daniel Nomura. All rights reserved.
//

import Foundation
import UIKit

class CityAndStreetToolbar: UIViewController, UICollectionViewDelegate, UICollectionViewDataSource {
    @IBOutlet weak var moreButton: UIButton!
    
    
    @IBOutlet weak var collectionView: UICollectionView!
    @IBOutlet weak var segmentControl: UISegmentedControl!
    
    @IBAction func goToMorePage(_ sender: UIButton) {
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
    //MARK: --Swoop toggle
}
