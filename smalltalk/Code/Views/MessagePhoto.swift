//
//  MessagePhoto.swift
//  smalltalk
//
//  Created by Mikko Hämäläinen on 21/10/15.
//  Copyright (c) 2015 Mikko Hämäläinen. All rights reserved.
//

import UIKit
import NYTPhotoViewer

class MessagePhoto: NSObject, NYTPhoto {
	var image: UIImage?
	var placeholderImage: UIImage?
	let attributedCaptionTitle = NSAttributedString(string: "", attributes: [NSForegroundColorAttributeName: UIColor.grayColor()])
	let attributedCaptionSummary = NSAttributedString(string: "", attributes: [NSForegroundColorAttributeName: UIColor.grayColor()])
	let attributedCaptionCredit = NSAttributedString(string: "", attributes: [NSForegroundColorAttributeName: UIColor.darkGrayColor()])
	
	init(image: UIImage?) {
		self.image = image
		super.init()
	}
}