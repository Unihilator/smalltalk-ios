//
//  YoutubeSearchResult.swift
//  smalltalk
//
//  Created by Mikko Hämäläinen on 13/11/15.
//  Copyright © 2015 Mikko Hämäläinen. All rights reserved.
//

import UIKit
import SwiftyJSON

struct YoutubeSearchResult {
	let id: String
	let title: String
	let desc: String
	let imageUrl: String
	let subscriberCount: Int

	init(json: JSON) {
		self.id = json["id"]["channelId"].stringValue
		self.title = json["snippet"]["title"].stringValue.trimWithNewline()
		self.desc = 	json["snippet"]["description"].stringValue.trimWithNewline()

		self.imageUrl = json["snippet"]["thumbnails"]["default"]["url"].stringValue
		self.subscriberCount = json["statistics"]["subscriberCount"].intValue
	}
}
