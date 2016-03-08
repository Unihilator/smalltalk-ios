//
//  Configuration.swift
//  smalltalk
//
//  Created by Mikko Hämäläinen on 21/09/15.
//  Copyright (c) 2015 Mikko Hämäläinen. All rights reserved.
//

import UIKit

class Configuration: NSObject {
	static let showTestUser: Bool = true
	
	struct GameConf {
		let url: String
		let players: Int
		let continuous: Bool
		let postHighScore: Bool
		
		init(url: String, players: Int, continuous: Bool, postHighScore: Bool) {
			self.url = url
			self.players = players
			self.continuous = continuous
			self.postHighScore = postHighScore
		}
	}
	
	static let games = [
		"chess" : GameConf(
			url: "",
			players : 2,
			continuous : true,
			postHighScore: false
		),
		"2048" : GameConf(
			url: "",
			players : 1,
			continuous : false,
			postHighScore: true
		)
	]

	static let youtubeApiKey = ""
	static let mediaBucket = "smalltalk-dev-media"

	#if (false && arch(i386) || arch(x86_64)) && os(iOS) //Running in simulator
		static let chatServer = "192.168.99.100"
		static let mainApi = "http://localhost:3000"
		static let pushApi = "http://192.168.99.100:4000/api"
        static let subscribeApi = "http://localhost:4002/api"
	#else
		static let chatServer = ""
		static private let apiServer = "http://\(chatServer)"
		static let mainApi = "\(apiServer)/api"
		static let pushApi = "\(apiServer)/push/api"
        static let subscribeApi = "\(apiServer)/subscribe/api"
	#endif
}
