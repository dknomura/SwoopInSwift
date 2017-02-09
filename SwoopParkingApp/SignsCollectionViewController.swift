//
//  CityAndStreetToolbar.swift
//  SwoopParkingApp
//
//  Created by Daniel Nomura on 1/10/17.
//  Copyright © 2017 Daniel Nomura. All rights reserved.
//

import Foundation
import UIKit
import DNTimeAndDay

class SignsCollectionViewController: UIViewController, UICollectionViewDelegate, UICollectionViewDataSource, InjectableViewController, ViewControllerWithSliderGestures {
    @IBOutlet weak var collectionView: UICollectionView!
    @IBOutlet weak var slider: UISlider!
    private weak var delegate: SignsCollectionViewControllerDelegate!
    private var dao: SPDataAccessObject!
    @IBOutlet weak var collectionViewSwitch: UISwitch!
    
    @IBOutlet weak var sliderGestureView: UIView!
    @IBOutlet weak var sliderWidthConstraint: NSLayoutConstraint!
    @IBOutlet weak var moreButtonWidthConstraint: NSLayoutConstraint!
    var sliderThumbLabel: UILabel!
    var streetDetailZoom: CGFloat!
    var currentRadius: Double {
        let maxValue = dao.currentCity.maxHorizontalRadius
        let minValue = dao.currentCity.minHorizontalRadius(view: view)
        return ((maxValue - minValue) * Double(slider.value)) + minValue

    }
    private var sliderWidth: CGFloat {
        let maxWidth = view.frame.width - collectionViewSwitch.frame.maxX - 16
        return collectionViewSwitch.isOn ? maxWidth : 0
    }
    private var buttonWidth: CGFloat {
        return collectionViewSwitch.isOn ? 0 : 40
    }
    
    let signCollectionHeaderReuse = "SignsCollectionViewHeader"
    var collapsedSections = Set<Int>()
    
    //MARK: - Lifecycle methods
    override func viewDidLoad() {
        assertDependencies()
        setupSliderThumbLabel()
        registerGesturesForSlider()
        setupSlider()
        setupCollectionView()
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
        if isOn {
            sliderThumbLabel.text = currentRadius.metersToDistanceString(forSystem: .us)
        }
        UIView.animate(withDuration: standardAnimationDuration, animations: {
            self.slider.isHidden = !isOn
            self.sliderThumbLabel.isHidden = !isOn
            self.sliderWidthConstraint.constant = self.sliderWidth
            self.moreButtonWidthConstraint.constant = self.buttonWidth
            self.view.layoutIfNeeded()
        }, completion: { _ in
            self.slider.setValue(1, animated: false)
            self.sliderThumbLabel.center = self.centerOfSliderThumbLabel
            self.adjustSliderToZoomChange()
            if isOn {
                self.collectionView.reloadData()
            }
        })
        NotificationCenter.default.post(name: collectionViewSwitchChangeNotification, object: nil, userInfo: [collectionViewSwitchKey: isOn])
    }
    
    func adjustSliderToZoomChange() {
        if let zoom = self.delegate.signsCollectionViewControllerNeedsMapZoom(switchIsOn: collectionViewSwitch.isOn) {
            let valueForSlider = self.sliderValue(forZoom: zoom)
            slider.setValue(valueForSlider, animated: true)
            sliderThumbLabel.text = currentRadius.metersToDistanceString(forSystem: .us)
        }

    }
    
    fileprivate func sliderValue(forZoom zoom: Float) -> Float {
        let meters = zoom.toWidthInMetersFromGMSZoom(forView: view)
        let maxRadius = dao.currentCity.maxHorizontalRadius
        let minRadius = dao.currentCity.minHorizontalRadius(view: view)
        if meters > maxRadius {
            return 1
        } else if meters < minRadius {
            return 0
        } else {
            return Float(meters / ( maxRadius - minRadius ))
        }
    }
    
    //MARK: - Protocols
    //MARK: <CollectionView Delegate/Datasource>
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 7
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        if let day = DNDay(rawValue: section + 1),
            let locationsForTime =  dao.locationCountsForTimeAndDay[day] {
            return locationsForTime.count
        } else {
            return 0
        }
    }    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        return UICollectionViewCell(frame: CGRect.zero)
    }
    func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
        if kind == UICollectionElementKindSectionHeader {
            if let header = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: signCollectionHeaderReuse, for: indexPath) as? SignsCollectionViewHeader,
                let day = DNDay(rawValue: indexPath.section + 1) {
                header.headerButton.setTitle(day.stringValue(forFormat: .fullDay), for: .normal)
                let backgroundColor = collapsedSections.contains(indexPath.section) ? UIColor.lightGray : UIColor.darkGray
                header.headerButton.backgroundColor = backgroundColor
                header.headerButton.addTarget(self, action: #selector(sectionButtonTouchedUpInside), for: .touchUpInside)
                header.headerButton.titleLabel?.font = UIFont(name: "Christopherhand", size: 25)
                header.headerButton.titleLabel?.textColor = UIColor.white
                header.tag = indexPath.section
                return header
            }
        }
        return collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: signCollectionHeaderReuse, for: indexPath)
    }
    
    @objc func sectionButtonTouchedUpInside(sender: UIButton) {
        let section = sender.tag
        guard let day = DNDay(rawValue: section + 1) else { return }
        if !collapsedSections.contains(section) {
            var indexPaths = [IndexPath]()

            guard let locationCountsForTime = dao.locationCountsForTimeAndDay[day] else { return }
            for i in 0..<locationCountsForTime.count {
                indexPaths.append(IndexPath(row: i, section: section))
            }
            
            collectionView.performBatchUpdates({ _ in
                self.collectionView.deleteItems(at: indexPaths)
            }, completion: nil )
            
            collapsedSections.insert(section)
        } else {
            if dao.locationCountsForTimeAndDay[day] == nil {
                
            }
            collapsedSections.remove(section)
        }
        sender.backgroundColor = collapsedSections.contains(section) ? UIColor.lightGray : UIColor.darkGray

    }
    
    //MARK: <InjectableViewController>
    
    func inject(dao: SPDataAccessObject, delegate: Any) {
        self.dao = dao
        self.delegate = delegate as? SignsCollectionViewControllerDelegate
    }
    func assertDependencies() {
        assert(dao != nil)
    }
    
    //MARK: UISlider methods
    @IBAction func sliderValueChanged(_ sender: Any) {
        adjustToSliderValueChange()
    }
    
    func tapToMoveSliderThumb(_ recognizer: UIGestureRecognizer) {
        adjustSlider(toRecognizer: recognizer)
    }
    func panSlider(_ recognizer: UIPanGestureRecognizer) {
        if recognizer.state == .began || recognizer.state == .changed || recognizer.state == .ended {
            adjustSlider(toRecognizer: recognizer)
        }
        if recognizer.state == .ended {
            
        }
    }
    fileprivate func adjustSlider(toRecognizer recognizer: UIGestureRecognizer) {
        let pointOnSlider = recognizer.location(in: slider)
        let trackRect = slider.trackRect(forBounds: slider.bounds)
        let sliderValue = Float(pointOnSlider.x / trackRect.width)
        slider.setValue(sliderValue, animated: true)
        adjustToSliderValueChange()
    }
    
    fileprivate func adjustToSliderValueChange() {
        delegate.signsCollectionViewControllerDidChangeRadius(radius: currentRadius)
        sliderThumbLabel.text = currentRadius.metersToDistanceString(forSystem: .us)
    }
    
    //MARK: Fileprivate methods
    fileprivate func setupSlider() {
        setupSliderThumbLabel()
        if let radiusImage = UIImage(named: "radius") {
            let scaledImage = UIImage.imageWith(image: radiusImage, scaledToSize: CGSize(width: 40, height: 40))
            slider.setThumbImage(scaledImage, for: .normal)
        }
    }
    fileprivate func setupCollectionView() {
        collectionView.register(UINib.init(nibName: signCollectionHeaderReuse, bundle: nil), forSupplementaryViewOfKind: UICollectionElementKindSectionHeader, withReuseIdentifier: signCollectionHeaderReuse)
        if let flow = collectionView.collectionViewLayout as? UICollectionViewFlowLayout {
            flow.headerReferenceSize = CGSize(width: collectionView.frame.width, height: 30)
        }
        for i in 0..<7 {
            collapsedSections.insert(i)
        }
    }
}


protocol SignsCollectionViewControllerDelegate: class {
    func signsCollectionViewControllerNeedsMapZoom(switchIsOn: Bool) -> Float?
    func signsCollectionViewControllerDidChangeRadius(radius: Double)
}
