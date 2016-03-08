//
//  MAMSync.swift
//  smalltalk
//
//  Created by Mikko Hämäläinen on 29/09/15.
//  Copyright (c) 2015 Mikko Hämäläinen. All rights reserved.
//

struct MAMSync {
	enum OldestMessageType: Int {
		case LocalCache = 1
		case Server = 2
	}
	
	//Mark what is the oldest message in thread so that we know what message to use as the before key in MAM archive get
	static func setOldestArchiveIdInThread(archiveId: String, forThread: String) {
		let defaults = NSUserDefaults.standardUserDefaults()
		defaults.setObject(archiveId, forKey: "archiveId-\(forThread)")
	}
	
	//Get the oldest message archiveId in thread
	static func oldestArchiveIdInThread(forThread: String) -> String? {
		let defaults = NSUserDefaults.standardUserDefaults()
		return defaults.objectForKey("archiveId-\(forThread)") as? String
	}
	
	//We mark a thread noting that all the messages from it have been received
	static func setMamSynced(forThread: String) {
		let defaults = NSUserDefaults.standardUserDefaults()
		defaults.setObject(true, forKey: "mamSynced-\(forThread)")
	}

	static func mamSynced(forThread: String) -> Bool? {
		let defaults = NSUserDefaults.standardUserDefaults()
		return defaults.objectForKey("mamSynced-\(forThread)") as? Bool
	}
	
	//Note! User.logOut deletes all data from this DB as well
}
