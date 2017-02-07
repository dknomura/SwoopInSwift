//
//  CityAndStreetToolbar.swift
//  SwoopParkingApp
//
//  Created by Daniel Nomura on 1/10/17.
//  Copyright © 2017 Daniel Nomura. All rights reserved.
//

import Foundation
import UIKit

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
    
    
    //MARK: - Lifecycle methods
    override func viewDidLoad() {
        assertDependencies()
        setupSliderThumbLabel()
        registerGesturesForSlider()
        setupSlider()
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
        return 1
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return 3
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        return UICollectionViewCell(frame: CGRect.zero)
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
}


protocol SignsCollectionViewControllerDelegate: class {
    func signsCollectionViewControllerNeedsMapZoom(switchIsOn: Bool) -> Float?
    func signsCollectionViewControllerDidChangeRadius(radius: Double)
}
