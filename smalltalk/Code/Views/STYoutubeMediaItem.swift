//
//  STYoutubeMediaItem.swift
//  smalltalk
//
//  Created by Mikko Hämäläinen on 10/11/15.
//  Copyright © 2015 Mikko Hämäläinen. All rights reserved.
//

//
//  STGameMediaItem.swift
//  smalltalk
//
//  Created by Mikko Hämäläinen on 14/10/15.
//  Copyright (c) 2015 Mikko Hämäläinen. All rights reserved.
//

import UIKit
import JSQMessagesViewController
import WebKit
import SwiftyJSON
import SDWebImage

class STYoutubeMediaItem: JSQMediaItem {
	var ytMediaView: ThumbnailedYoutubeView?
	let url: String
	let title: String?
	let channelTitle: String?
	let outgoing: Bool
	
	
	init(url: String, title: String?, channelTitle: String?, outgoing: Bool) {
		self.url = url
		self.title = title
		self.channelTitle = channelTitle
		self.outgoing = outgoing
		super.init(maskAsOutgoing: outgoing)
	}
	
	deinit {
		
	}
	
	//JSQMessageMediaData protocol
	override func mediaView() -> UIView! {
		if self.ytMediaView == nil {
			let (size, videoHeightOfWholeHeight)  = self.displaySize()
			self.ytMediaView = ThumbnailedYoutubeView(url: url, title: title, channelTitle: channelTitle, outgoing: self.outgoing, size: size, videoHeightOfWholeHeight: videoHeightOfWholeHeight)
			JSQMessagesMediaViewBubbleImageMasker.applyBubbleImageMaskToMediaView(self.ytMediaView, isOutgoing:self.outgoing)
		}
		
		return self.ytMediaView
	}
	
	private func displaySize() -> (CGSize, CGFloat) {
		let screenRect: CGRect = UIScreen.mainScreen().bounds
		let width = screenRect.size.width * 0.78
		let videoHeight = width * (9.0/16.0)
		var wholeHeight = videoHeight
		
		if title != nil {
			wholeHeight += videoHeight * 0.2 //More room for title
		}
		
		return (CGSizeMake(width, wholeHeight), videoHeight)
	}
	override func mediaViewDisplaySize() -> CGSize {
		let (size, _) = self.displaySize()
		return size
	}
	
	override func mediaPlaceholderView() -> UIView? {
		return nil //There should never be placeholderview
	}
	
	/*
	override func mediaHash() -> UInt {
	return super.mediaHash()
	}
	*/
	
	/*
	override func isEqual(object: AnyObject?) -> Bool {
	if !super.isEqual(object) {
	return false
	}
	
	let gameItem: STGameMediaItem = object as? STGameMediaItem
	return gameItem.url == self.url //TODO! Compare state & url
	}
	*/
	
	//func
	
	//mark - NSObject
	override var hash: Int {
		get {
			return super.hash ^ self.url.hash
		}
	}
	
	override var description: String {
		get {
			return "\(self.ytMediaView)"
		}
	}
	
	
	//mark - NSCoding
	
	required init(coder aDecoder: NSCoder) {
		fatalError("Not implemented. See JSQPhotoMediaItem")
	}
	
	override func encodeWithCoder(aCoder: NSCoder) {
		fatalError("Not implemented. See JSQPhotoMediaItem")
	}
	
	//mark - NSCopying
	
	override func copyWithZone(zone: NSZone) -> AnyObject {
		fatalError("CopyWithZone. See JSQPhotoMediaItem")
	}
}
