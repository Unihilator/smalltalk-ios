//
//  XMPPMessage+Ext.swift
//  smalltalk
//
//  Created by Mikko Hämäläinen on 02/10/15.
//  Copyright (c) 2015 Mikko Hämäläinen. All rights reserved.
//

import XMPPFramework

extension XMPPMessage {
	func id() -> String! {
		return self.attributeStringValueForName("id")
	}
	
	func date() -> NSDate? {
		if self.isForwardedStanza() {
			return self.forwardedStanzaDelayedDeliveryDate()
		}
		
		return self.delayedDeliveryDate()
	}
	
	func content() -> STMessageAttachment? {
		if let contentE = self.elementForName("content") {
			let contentType = contentE.attributeStringValueForName("content-type")
			return STMessageAttachment(contentStr: contentE.stringValue(), contentType: contentType)
		}
		
		return nil
	}
	
	func archiveId() -> String? {
		if let archived = self.elementForName("archived") {
			return archived.attributeStringValueForName("id")
		}
		
		return nil
	}
}
