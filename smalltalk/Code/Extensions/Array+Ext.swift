//
//  Array+Ext.swift
//  smalltalk
//
//  Created by Mikko Hämäläinen on 29/09/15.
//  Copyright (c) 2015 Mikko Hämäläinen. All rights reserved.
//

extension Array {
	func randomItem() -> Element {
		let index = Int(arc4random_uniform(UInt32(self.count)))
		return self[index]
	}
}
