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

class SignsCollectionViewController: UIViewController, UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout, InjectableViewController, ViewControllerWithSliderGestures {
    @IBOutlet weak var collectionView: UICollectionView!
    @IBOutlet weak var slider: UISlider!
    @IBOutlet weak var collectionViewSwitch: UISwitch!
    @IBOutlet weak var sliderGestureView: UIView!
    @IBOutlet weak var sliderThumbLabel: UILabel!
    @IBOutlet weak var panResizeIndicator: UILabel!
    @IBOutlet weak var waitingView: UIView!
    @IBOutlet weak var activityView: UIActivityIndicatorView!
    
    private var streetDetailZoom: CGFloat!
    private let numberOfSections = 8
    private let collectionViewCellSize = CGSize(width: 70, height: 70)
    private let signCollectionHeaderReuse = "SignsCollectionViewHeader"
    private let signsCollectionViewCellReuse = "SignsCollectionViewCell"
    private weak var delegate: SignsCollectionViewControllerDelegate!
    private var dao: SPDataAccessObject!
    fileprivate var collapsedSections = Set<Int>()
    var uncollapsedSections: [Int] {
        var uncollapsed = [Int]()
        for i in 0..<numberOfSections {
            if !collapsedSections.contains(i) {
                uncollapsed.append(i)
            }
        }
        return uncollapsed
    }
    //MARK: - Lifecycle methods
    override func viewDidLoad() {
        assertDependencies()
        addGestures()
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
    
    func adjustToToggleChange(isOn:Bool, completion: (() -> Void)? = nil){
        if isOn {
            dao.currentRadius = delegate.signsCollectionViewControllerNeedsCurrentRadius
            adjustSliderToZoomChange()
        }
        UIView.animate(withDuration: standardAnimationDuration, animations: {
            self.panResizeIndicator.isHidden = !isOn
            self.sliderThumbLabel.isHidden = !isOn
            self.slider.isHidden = !isOn
            self.sliderGestureView.isHidden = !isOn
            self.collectionView.isHidden = !isOn
        }, completion: { _ in
            completion?()
        })
        delegate.signsCollectionViewController(didTurnSwitchOn: isOn)
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
    }
    fileprivate func adjustSlider(toRecognizer recognizer: UIGestureRecognizer) {
        let pointOnSlider = recognizer.location(in: slider)
        let trackRect = slider.trackRect(forBounds: slider.bounds)
        let sliderValue = Float(pointOnSlider.x / trackRect.width)
        slider.setValue(sliderValue, animated: true)
        adjustToSliderValueChange()
    }
    
    fileprivate func adjustToSliderValueChange() {
        let maxRadius = dao.currentCity.maxHorizontalRadius
        let minRadius = dao.currentCity.minHorizontalRadius(view: view)
        dao.currentRadius = ((maxRadius - minRadius) * Double(slider.value)) + minRadius
        delegate.signsCollectionViewControllerDidChangeRadius(radius: dao.currentRadius)
        sliderThumbLabel.text = dao.currentRadius.metersToDistanceString(forSystem: .us)
    }
    

    func adjustSliderToZoomChange() {
        let maxRadius = dao.currentCity.maxHorizontalRadius
        let minRadius = dao.currentCity.minHorizontalRadius(view: view)
        var sliderValue: Float
        if dao.currentRadius > maxRadius {
            sliderValue = 1
            dao.currentRadius = maxRadius
        } else if dao.currentRadius < minRadius {
            sliderValue = 0
            dao.currentRadius = minRadius
        } else {
            sliderValue = Float(dao.currentRadius / ( maxRadius - minRadius ))
        }
        slider.setValue(sliderValue, animated: true)
        sliderThumbLabel.text = dao.currentRadius.metersToDistanceString(forSystem: .us)
    }
    
    //MARK: - WaitingView Methods
    func showWaitingView() {
        waitingView.isHidden = false
        activityView.startAnimating()
    }
    func hideWaitingView() {
        waitingView.isHidden = true
        activityView.stopAnimating()
    }
    
    //MARK: - Protocols
    //MARK: <CollectionView Delegate/Datasource>
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return numberOfSections
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        if let day = DNDay(rawValue: section),
            let locationsForTime =  dao.locationCountsForTimeAndDay[day] {
            return collapsedSections.contains(section) ? 0 : locationsForTime.count
        } else {
            return 0
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        return collectionViewCellSize
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        if let cell = collectionView.dequeueReusableCell(withReuseIdentifier: signsCollectionViewCellReuse, for: indexPath) as? SignsCollectionViewCell,
            let timeAndDay = getTimeAndDay(fromIndexPath: indexPath){
            if let count = dao.locationCountsForTimeAndDay[timeAndDay.day]?[timeAndDay.time] {
                cell.timeLabel.text = timeAndDay.time.stringValue(forFormat: .format12Hour)
                cell.badgeCountLabel.text = "\(count)"
                cell.badgeCountLabel.createBorder(color: UIColor.black.cgColor)
                cell.createBorder(color: UIColor.black.cgColor)
                return cell
            }
        }
        return collectionView.dequeueReusableCell(withReuseIdentifier: signsCollectionViewCellReuse, for: indexPath)
    }
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        if let timeAndDay = getTimeAndDay(fromIndexPath: indexPath) {
            delegate.signsCollectionViewControllerDidSelect(timeAndDay: timeAndDay)
        }
    }
    
    private func getTimeAndDay(fromIndexPath indexPath: IndexPath) -> DNTimeAndDay? {
        if let day = DNDay(rawValue: indexPath.section),
            let timesDictionary = dao.locationCountsForTimeAndDay[day] {
            let times = sortedTimes(fromTimesDictionary: timesDictionary)
            return DNTimeAndDay(day: day, time: times[indexPath.row])
        } else {
            return nil
        }
    }
    
    private func sortedTimes(fromTimesDictionary timesDictionary: [DNTime: Int]) -> [DNTime] {
        let times = Array(timesDictionary.keys)
        let timesArray = times.sorted { $0 < $1 }
        return timesArray
    }
    
    func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
        
        let section = indexPath.section
        if section == 0 {
            if let header = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: signCollectionHeaderReuse, for: indexPath) as? SignsCollectionViewHeader {
                header.headerButton.setTitle("Select a time and day", for: .normal)
                header.headerButton.backgroundColor = backgroundColor(forSection: section)
                header.headerButton.titleLabel?.font = UIFont(name: "Christopherhand", size: 25)
                header.headerButton.setTitleColor(UIColor.white, for: .normal)
                header.headerButton.tag = section
                return header
            }
        }
        if kind == UICollectionElementKindSectionHeader {
            if let header = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: signCollectionHeaderReuse, for: indexPath) as? SignsCollectionViewHeader,
                let day = DNDay(rawValue: section) {
                
                if dao.locationCountsForTimeAndDay[day] == nil {
                    collapsedSections.insert(section)
                }
                header.headerButton.setTitle(day.stringValue(forFormat: .fullDay), for: .normal)
                header.headerButton.backgroundColor = backgroundColor(forSection: section)
                header.headerButton.addTarget(self, action: #selector(sectionButtonTouchedUpInside), for: .touchUpInside)
                header.headerButton.titleLabel?.font = UIFont(name: "Christopherhand", size: 25)
                header.headerButton.setTitleColor(UIColor.white, for: .normal)
                header.headerButton.tag = section
                return header
            }
        }
        return collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: signCollectionHeaderReuse, for: indexPath)
//
//        
//        
//        let defaultHeader = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: signCollectionHeaderReuse, for: indexPath)
//        guard kind == UICollectionElementKindSectionHeader else { return defaultHeader }
//        guard let header = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: signCollectionHeaderReuse, for: indexPath) as? SignsCollectionViewHeader else { return defaultHeader }
//        let section = indexPath.section
//        header.headerButton.backgroundColor = backgroundColor(forSection: section)
//        header.headerButton.titleLabel?.font = UIFont(name: "Christopherhand", size: 25)
//        header.headerButton.setTitleColor(UIColor.white, for: .normal)
//        header.headerButton.tag = section
//        //Title headers
//        if section == 0 {
//            header.headerButton.setTitle("Select a time and day", for: .normal)
//        } else {
//        //Day headers
//            guard let day = DNDay(rawValue: section) else { return defaultHeader }
//            if dao.locationCountsForTimeAndDay[day] == nil {
//                collapsedSections.insert(section)
//            }
//            header.headerButton.addTarget(self, action: #selector(sectionButtonTouchedUpInside), for: .touchUpInside)
//            header.headerButton.setTitle(day.stringValue(forFormat: .fullDay), for: .normal)
//            print("day: \(day). title: \(header.headerButton.currentTitle). background color: \(header.headerButton.backgroundColor)")
//        }
//        return header
    }
    
    @objc func sectionButtonTouchedUpInside(sender: UIButton) {
        let section = sender.tag
        if section == 0 { return }
        if !collapsedSections.contains(section) {
            collapsedSections.insert(section)
            guard let indexPathsToDelete = indexPaths(forSection: section) else { return }
            collectionView.performBatchUpdates({ _ in
                self.collectionView.deleteItems(at: indexPathsToDelete)
            }, completion: nil)
        } else {
            collapsedSections.remove(section)
            guard let day = DNDay(rawValue: section) else { return }
            dao.currentRadius = delegate.signsCollectionViewControllerNeedsCurrentRadius
            dao.setCountOfStreetCleaningTimes(forDays: [day], at: dao.searchCoordinate!, radius: dao.currentRadius, completion: { [unowned self] in
                self.delegate.signsCollectionViewControllerDidFinishQuery()
                guard let indexPathsToAdd = self.indexPaths(forSection: section) else { return }
                self.collectionView.performBatchUpdates({ _ in
                    self.collectionView.insertItems(at: indexPathsToAdd)
                }, completion: nil)
//                self.hideWaitingView()
            })
//            showWaitingView()
            delegate.signsCollectionViewControllerDidStartQuery()
            
        }
        sender.backgroundColor = self.backgroundColor(forSection: section)
    }
    
    fileprivate func indexPaths(forSection section: Int) -> [IndexPath]? {
        guard let day = DNDay(rawValue: section),
            let locationCountsForTime = dao.locationCountsForTimeAndDay[day]  else { return nil }
        var indexPaths = [IndexPath]()
        for i in 0..<locationCountsForTime.count {
            indexPaths.append(IndexPath(row: i, section: section))
        }
        return indexPaths
    }

    fileprivate func backgroundColor(forSection section:Int) -> UIColor {
        return collapsedSections.contains(section) ? UIColor.swoopRed : UIColor.red
    }
    
    //MARK: <InjectableViewController>
    
    func inject(dao: SPDataAccessObject, delegate: Any) {
        self.dao = dao
        self.delegate = delegate as? SignsCollectionViewControllerDelegate
    }
    func assertDependencies() {
        assert(dao != nil)
    }
    
    //MARK: Fileprivate methods
    fileprivate func addGestures() {
        registerGesturesForSlider()
    }
    
    fileprivate func setupSlider() {
        if let radiusImage = UIImage(named: "radius") {
            let scaledImage = UIImage.imageWith(image: radiusImage, scaledToSize: CGSize(width: 40, height: 40))
            slider.setThumbImage(scaledImage, for: .normal)
        }
        adjustSliderToZoomChange()
    }
    fileprivate func setupCollectionView() {
        collectionView.register(UINib.init(nibName: signCollectionHeaderReuse, bundle: nil), forSupplementaryViewOfKind: UICollectionElementKindSectionHeader, withReuseIdentifier: signCollectionHeaderReuse)
        collectionView.register(UINib.init(nibName: signsCollectionViewCellReuse, bundle: nil), forCellWithReuseIdentifier: signsCollectionViewCellReuse)
        if let flow = collectionView.collectionViewLayout as? UICollectionViewFlowLayout {
            flow.headerReferenceSize = CGSize(width: collectionView.frame.width, height: 30)
            if #available(iOS 9.0, *) {
                flow.sectionHeadersPinToVisibleBounds = true
            } 
        }
        for i in 1...numberOfSections {
            collapsedSections.insert(i)
        }
    }
}


protocol SignsCollectionViewControllerDelegate: class {
    func signsCollectionViewController(didTurnSwitchOn isOn: Bool)
    func signsCollectionViewControllerDidStartQuery()
    func signsCollectionViewControllerDidFinishQuery()
    var signsCollectionViewControllerNeedsCurrentRadius: Double { get }
    func signsCollectionViewControllerDidChangeRadius(radius: Double)
    func signsCollectionViewControllerDidSelect(timeAndDay: DNTimeAndDay)
}
