//
//  Utils.swift
//  smalltalk
//
//  Created by Mikko Hämäläinen on 24/09/15.
//  Copyright © 2015 Mikko Hämäläinen. All rights reserved.
//

import Foundation

func statusBarHeight() -> CGFloat {
	let statusBarSize: CGSize = UIApplication.sharedApplication().statusBarFrame.size
	return CGFloat(min(Float(statusBarSize.width), Float(statusBarSize.height)))
}

func navigationBarHeight() -> CGFloat {
	return CGFloat(44.0)
}

