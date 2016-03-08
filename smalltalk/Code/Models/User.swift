//
//  User.swift
//  smalltalk
//
//  Created by Mikko Hämäläinen on 23/09/15.
//  Copyright (c) 2015 Mikko Hämäläinen. All rights reserved.
//

import UIKit
import DigitsKit
import SwiftyJSON

struct User {
	static var username: String {
		get {
			return NSUserDefaults.standardUserDefaults().objectForKey("username") as! String
		}
	}
	
	static var token: String {
		get {
			return NSUserDefaults.standardUserDefaults().objectForKey("token") as! String
		}
	}
	
	static var senderId: String {
		get {
			return User.username
		}
	}
	
	static var displayName: String? {
		get {
			return NSUserDefaults.standardUserDefaults().objectForKey("displayName") as? String
		}
		
		set(value) {
			NSUserDefaults.standardUserDefaults().setObject(value, forKey: "displayName")
		}
	}

	static var initialConversationsSyncNeeded: Bool {
		get {
			//Only do this if this was not a new user (may have conversations from previous logins)
			let newUser = NSUserDefaults.standardUserDefaults().objectForKey("new") as? Bool
			let syncNeeded = NSUserDefaults.standardUserDefaults().objectForKey("initialConversationsSyncNeeded") as? Bool
			return ((newUser == nil || newUser == false) && (syncNeeded == nil || syncNeeded == true))
		}
		
		set(value) {
			NSUserDefaults.standardUserDefaults().setBool(value, forKey: "initialConversationsSyncNeeded")
		}
	}
	
	static func loggedInWith(data: JSON) {
		let defaults = NSUserDefaults.standardUserDefaults()
		defaults.setValuesForKeysWithDictionary(data.dictionaryObject!)
	}
	
	static func isLoggedIn() -> Bool {
		return NSUserDefaults.standardUserDefaults().objectForKey("username") != nil
	}
	
	static func logOut() {
		Digits.sharedInstance().logOut()
		STXMPPClient.sharedInstance?.disconnect()
		let appDomain = NSBundle.mainBundle().bundleIdentifier
		NSUserDefaults.standardUserDefaults().removePersistentDomainForName(appDomain!)
	}
}
