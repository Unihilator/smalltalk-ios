//
//  String+Ext.swift
//  smalltalk
//
//  Created by Mikko Hämäläinen on 13/11/15.
//  Copyright © 2015 Mikko Hämäläinen. All rights reserved.
//

import Foundation

extension String {
	func trim() -> String {
		return self.stringByTrimmingCharactersInSet(NSCharacterSet.whitespaceCharacterSet())
	}
	
	func trimWithNewline() -> String {
		return self.stringByTrimmingCharactersInSet(NSCharacterSet.whitespaceAndNewlineCharacterSet())
	}
}
