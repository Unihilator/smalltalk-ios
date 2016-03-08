//
//  LaunchScreen.swift
//  smalltalk
//
//  Created by Mikko Hämäläinen on 29/10/15.
//  Copyright © 2015 Mikko Hämäläinen. All rights reserved.
//

import UIKit
import ChameleonFramework
import SnapKit

class LaunchScreen: UIView {
	let label: UILabel
	
	init() {
		//Check out these values from LaunchScreen.xib
		self.label = UILabel(frame: CGRect(x: 0, y: 0, width: 55, height: 15))
		self.label.text = "smalltalk"
		self.label.font = UIFont.boldSystemFontOfSize(12)
		self.label.textColor = UIColor.whiteColor()
		
		super.init(frame: UIScreen.mainScreen().bounds)
		self.addSubview(self.label)
		self.backgroundColor = FlatRed()
        self.opaque = true
		self.label.snp_makeConstraints { (make) -> Void in
			make.centerX.equalTo(self)
			make.centerY.equalTo(self.snp_bottom).multipliedBy(0.4).offset(1)
		}
	}

	required init?(coder aDecoder: NSCoder) {
	    fatalError("init(coder:) has not been implemented")
	}

	func animate(completionHandler: () -> Void) {
		let animationDuration: Double = 0.6
		let shrinkDuration: Double  = animationDuration * 0.3
		let growDuration: Double = animationDuration * 0.7

		UIView.animateWithDuration(NSTimeInterval(shrinkDuration), delay: 0, usingSpringWithDamping: 0.7, initialSpringVelocity: 10, options: .CurveEaseInOut,
			animations: {
				[unowned self] in
				let scaleTransform: CGAffineTransform = CGAffineTransformMakeScale(0.5, 0.5)
				self.label.transform = scaleTransform
			},
			completion: {
				[unowned self] finished in
				UIView.animateWithDuration(NSTimeInterval(growDuration),
					animations: {
						[unowned self] in
						let scaleTransform: CGAffineTransform = CGAffineTransformMakeScale(20, 20)
						self.label.transform = scaleTransform
						self.alpha = 0
					},
					completion: {
						[unowned self] finished in
						self.removeFromSuperview()
						completionHandler()
						
				})
			}
		)
	}
}
