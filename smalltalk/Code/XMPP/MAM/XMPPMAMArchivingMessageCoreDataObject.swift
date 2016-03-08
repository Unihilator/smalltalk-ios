//
//  XMPPMAMArchivingMessageCoreDataObject.swift
//  smalltalk
//
//  Created by Mikko Hämäläinen on 01/10/15.
//  Copyright (c) 2015 Mikko Hämäläinen. All rights reserved.
//

import XMPPFramework
import SwiftyJSON

class XMPPMAMArchivingMessageCoreDataObject: XMPPMessageArchiving_Message_CoreDataObject {
	@NSManaged var id: String
	@NSManaged var senderId: String
	@NSManaged var archiveId: String?
	@NSManaged var contentType: String?
	@NSManaged var contentDataStr: String?
	@NSManaged var deliveryStatus: NSNumber
	
	var content: STMessageAttachment? {
		if contentDataStr != nil {
			return STMessageAttachment(contentStr: contentDataStr!, contentType: contentType!)
		}
		
		return nil
	}
}

