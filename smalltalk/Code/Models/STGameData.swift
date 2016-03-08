//
//  STGameData.swift
//  smalltalk
//
//  Created by Mikko Hämäläinen on 14/10/15.
//  Copyright (c) 2015 Mikko Hämäläinen. All rights reserved.
//

import UIKit
import SwiftyJSON

class STGameData: NSObject {
	var data: JSON
	var dataContentType: String

	init(gameData: NSDictionary, type: String) {
		self.data = JSON(gameData)
		self.data["gameType"].string = type
		self.dataContentType = STGameData.contentTypeForGameType(type)
	}
	
	static func contentTypeForGameType(type: String) -> String {
		return "application/smalltalk-game+\(type)"
	}
}
