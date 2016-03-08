//
//  Platform.swift
//  smalltalk
//
//  Created by Mikko Hämäläinen on 23/09/15.
//  Copyright (c) 2015 Mikko Hämäläinen. All rights reserved.
//

struct Platform {
	static let isSimulator: Bool = {
		var isSim = false
		#if (arch(i386) || arch(x86_64)) && os(iOS) //Running in simulator
			isSim = true
		#endif
		return isSim
	}()
}
