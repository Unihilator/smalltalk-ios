//
//  VideoStore.swift
//  smalltalk
//
//  Created by Mikko Hämäläinen on 19/11/15.
//  Copyright © 2015 Mikko Hämäläinen. All rights reserved.
//

import UIKit

struct VideoStore {
	//Mark the playbackPosition for a video so that we can continue from the same position later on
	static func setPlaybackPosition(position: Float, forVideoId: String) {
		let defaults = NSUserDefaults.standardUserDefaults()
		defaults.setObject(position, forKey: "playbackPos-\(forVideoId)")
	}
	
	//Get the playbackPos for video
	static func playbackPosition(forVideoId: String) -> Float? {
		let defaults = NSUserDefaults.standardUserDefaults()
		return defaults.objectForKey("playbackPos-\(forVideoId)") as? Float
	}
	
	//Clear the playbackPos for video
	static func clearPlaybackPosition(forVideoId: String) {
		let defaults = NSUserDefaults.standardUserDefaults()
		defaults.removeObjectForKey("playbackPos-\(forVideoId)")
	}
}
