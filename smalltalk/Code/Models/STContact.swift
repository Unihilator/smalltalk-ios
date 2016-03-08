//
//  Contact.swift
//  smalltalk
//
//  Created by Mikko Hämäläinen on 20/10/15.
//  Copyright (c) 2015 Mikko Hämäläinen. All rights reserved.
//

import UIKit

class STContact: NSObject {
	let username: String
	let displayName: String
	
	init(username: String, displayName: String) {
		self.username = username
		self.displayName = displayName
	}
	
	static func contactWith(username: String, xmppClient: STXMPPClient) -> STContact {
		if username == User.username {
			return STContact(username: username, displayName: User.displayName!)
		}
		
		if let vcard = xmppClient.stream!.fetchVCard(username) {
			return STContact(username: username, displayName: vcard.nickname)
		}
		
		return STContact(username: username, displayName: "Unknown nick \(username)")
	}
	
	override var description: String {
		get {
			return "\(super.description): \(username) \(displayName)"
		}
	}
	
	override func isEqual(object: AnyObject?) -> Bool {
		if let rhs = object as? STContact {
			return username == rhs.username
		}
		
		return false
	}
}


