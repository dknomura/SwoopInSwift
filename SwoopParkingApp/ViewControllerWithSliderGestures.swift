//
//  ViewControllerWithSliderGestures.swift
//  SwoopParkingApp
//
//  Created by Daniel Nomura on 2/6/17.
//  Copyright © 2017 Daniel Nomura. All rights reserved.
//

import Foundation

@objc protocol ViewControllerWithSliderGestures {
    weak var sliderGestureView: UIView! { get set }
    weak var slider: UISlider! { get set }
    var sliderThumbLabel: UILabel! { get set }
    func panSlider(_ recognizer: UIPanGestureRecognizer)
    func tapToMoveSliderThumb(_ recognizer: UIGestureRecognizer)
}

extension ViewControllerWithSliderGestures where Self: UIViewController {
    var thumbRect: CGRect {
        let trackRect = slider.trackRect(forBounds: slider.bounds)
        return slider.thumbRect(forBounds: slider.bounds, trackRect: trackRect, value: slider.value)
    }
    var centerOfSliderThumbLabel: CGPoint {
        return CGPoint(x: thumbRect.origin.x + thumbRect.size.width/2 + slider.frame.origin.x, y: thumbRect.origin.y + thumbRect.size.height/2 + slider.frame.origin.y - 20)
    }
    func registerGesturesForSlider() {
        let tapGesture = UITapGestureRecognizer.init(target: self, action: #selector(tapToMoveSliderThumb(_:)))
        sliderGestureView.addGestureRecognizer(tapGesture)
        let sliderPanGesture = UIPanGestureRecognizer.init(target: self, action: #selector(panSlider(_:)))
        sliderGestureView.addGestureRecognizer(sliderPanGesture)
    }
    
    func setupSliderThumbLabel() {
        sliderThumbLabel = UILabel.init(frame: CGRect(x: 0, y: 0, width: 55, height: 20))
        sliderThumbLabel!.backgroundColor = UIColor.clear
        sliderThumbLabel!.textAlignment = .center
        sliderThumbLabel.font = UIFont.init(name: "Christopherhand", size: 19)
        view.addSubview(sliderThumbLabel)
    }
}
