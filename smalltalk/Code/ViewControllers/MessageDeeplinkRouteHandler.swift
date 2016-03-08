//
//  MessageDeeplinkRouteHandler.swift
//  smalltalk
//
//  Created by Mikko Hämäläinen on 14/10/15.
//  Copyright (c) 2015 Mikko Hämäläinen. All rights reserved.
//

import Foundation
import DeepLinkKit

class MessageDeeplinkRouteHandler: DPLRouteHandler {
	override func targetViewController() -> UIViewController! {
		//if let storyboard = UIApplication.sharedApplication().keyWindow?.rootViewController?.storyboard {
		//	return storyboard.instantiateViewControllerWithIdentifier("detail") as! MessageDeeplinkRouteHandler
		//}
		
		return UIViewController()
	}
}
