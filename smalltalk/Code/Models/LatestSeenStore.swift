//
//  LatestSeenStore.swift
//  smalltalk
//
//  Created by Mikko Hämäläinen on 20/11/15.
//  Copyright © 2015 Mikko Hämäläinen. All rights reserved.
//

import UIKit

struct LatestSeenStore {
	//Mark what is the oldest message in thread so that we know what message to use as the before key in MAM archive get
	static func setLatestSeenInThread(date: NSDate, msgId: String, forThread: String) {
		let stored  = LatestSeenStore.latestSeenInThread(forThread)
		if stored == nil || stored!.date < date {
			let defaults = NSUserDefaults.standardUserDefaults()
			let dict = ["date": date, "id": msgId]
			defaults.setObject(dict, forKey: "latestSeenInThread-\(forThread)")
		}
	}
	
	//Get the oldest message archiveId in thread
	static func latestSeenInThread(forThread: String) -> (date: NSDate, id: String)? {
		let defaults = NSUserDefaults.standardUserDefaults()
		if let ret = defaults.objectForKey("latestSeenInThread-\(forThread)") as? Dictionary<String, AnyObject> {
			let date: NSDate = ret["date"] as! NSDate
			let id: String = ret["id"] as! String
			
			return (date: date, id: id)
		}
		
		return nil
	}
	
	//Note! User.logOut deletes all data from this DB as well
}
