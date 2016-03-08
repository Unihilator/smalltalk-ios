//
//  XMPPMAMArchiving.swift
//  smalltalk
//
//  Created by Mikko Hämäläinen on 01/10/15.
//  Copyright (c) 2015 Mikko Hämäläinen. All rights reserved.
//

import Foundation
import XMPPFramework

class XMPPMAMArchiving: XMPPMessageArchiving {
	override init(messageArchivingStorage storage: XMPPMessageArchivingStorage!, dispatchQueue queue: dispatch_queue_t!) {
		super.init(messageArchivingStorage: storage, dispatchQueue: queue)
		self.clientSideMessageArchivingOnly = true //NOTE! This refers to old style XEP-0136 archiving NOT MAM style server archiving
		(storage as! XMPPMessageArchivingCoreDataStorage).messageEntityName = "XMPPMAMArchivingMessageCoreDataObject"
		(storage as! XMPPMessageArchivingCoreDataStorage).contactEntityName = "XMPPMAMArchivingContactCoreDataObject"
	}
}
