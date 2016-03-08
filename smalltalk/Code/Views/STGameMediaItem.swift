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

class STGameMediaItem: JSQMediaItem {
	var webMediaView: ThumbnailedWebView?
	var messageId: String
	var data: JSON
	var outgoing: Bool
	
	init(messageId: String, data: JSON, outgoing: Bool) {
		self.messageId = messageId
		self.data = data
		self.outgoing = outgoing
		super.init(maskAsOutgoing: outgoing)
	}
	
	deinit {
		
	}

	//JSQMessageMediaData protocol
	override func mediaView() -> UIView! {
		if self.webMediaView == nil {
			let size: CGSize  = self.mediaViewDisplaySize()
			self.webMediaView = ThumbnailedWebView(messageId: messageId, data: data, outgoing: outgoing, size: size)
		}
		
		return self.webMediaView
	}
	
	override func mediaViewDisplaySize() -> CGSize {
		let screenRect: CGRect = UIScreen.mainScreen().bounds
		let width = screenRect.size.width * 0.78
		let height = width * 1 //Chess is square so we don't have this any higher, other games would benefit if they had more space
		return CGSizeMake(width, height)
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
			return self.data.rawString()!.hash
		}
	}
	
	override var description: String {
		get {
			return "\(self.webMediaView)"
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
