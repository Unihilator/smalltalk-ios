//
//  UIImage+Ext.swift
//  smalltalk
//
//  Created by Mikko Hämäläinen on 02/11/15.
//  Copyright © 2015 Mikko Hämäläinen. All rights reserved.
//

import UIKit

extension UIImage {
	
	static func imageForView(view: UIView, opaque: Bool = false) -> UIImage? {
		let bounds = view.bounds
		assert(CGRectGetWidth(bounds) > 0, "Zero width for view")
		assert(CGRectGetHeight(bounds) > 0, "Zero height for view")

		UIGraphicsBeginImageContextWithOptions(bounds.size, opaque, 0)
		view.layoutIfNeeded()
		let success = view.drawViewHierarchyInRect(view.bounds, afterScreenUpdates: true)
		if success {
			let snapshot = UIGraphicsGetImageFromCurrentImageContext()
			UIGraphicsEndImageContext()
			return snapshot
		}
		
		return nil
	}

	static func imageForLayer(layer: CALayer) -> UIImage {
		let bounds = layer.bounds
		assert(CGRectGetWidth(bounds) > 0, "Zero width for view")
		assert(CGRectGetHeight(bounds) > 0, "Zero height for view")
		
		UIGraphicsBeginImageContextWithOptions(bounds.size, false, 0)
		let context = UIGraphicsGetCurrentContext()
		assert(context != nil, "Could not generate context for layer")
		CGContextSaveGState(context)
		layer.layoutIfNeeded()
		layer.renderInContext(context!)
		CGContextRestoreGState(context)
		let snapshot = UIGraphicsGetImageFromCurrentImageContext();
		UIGraphicsEndImageContext();
		return snapshot;
	}
	
	func getPixelColor(pos: CGPoint) -> UIColor {
		let pixelData = CGDataProviderCopyData(CGImageGetDataProvider(self.CGImage))
		let data: UnsafePointer<UInt8> = CFDataGetBytePtr(pixelData)
		let pixelInfo: Int = ((Int(self.size.width) * Int(pos.y)) + Int(pos.x)) * 4
		
		let r = CGFloat(data[pixelInfo]) / CGFloat(255.0)
		let g = CGFloat(data[pixelInfo+1]) / CGFloat(255.0)
		let b = CGFloat(data[pixelInfo+2]) / CGFloat(255.0)
		let a = CGFloat(data[pixelInfo+3]) / CGFloat(255.0)
		
		return UIColor(red: r, green: g, blue: b, alpha: a)
	}
	
	//Go image pixel by pixel and report if every pixel is the same
	func isSingleColorImage() -> Bool {
		let pixelData = CGDataProviderCopyData(CGImageGetDataProvider(self.CGImage))
		let data: UnsafePointer<UInt8> = CFDataGetBytePtr(pixelData)
		
		let firstPixel: Int = 0
		let rP = UInt32(data[firstPixel])
		let gP = UInt32(data[firstPixel+1])
		let bP = UInt32(data[firstPixel+2])
		let aP = UInt32(data[firstPixel+3])
		var previousColor: UInt32 = (rP << 24) + (gP << 16) + (bP << 8) + aP

		let height = Int(self.size.height)
		let width = Int(self.size.width)
		for var y = 0; y < height; y++ {
			for var x = 0; x < width; x++ {
				let currentPixelInfo: Int = ((height * y) + x) * 4
				let r = UInt32(data[currentPixelInfo])
				let g = UInt32(data[currentPixelInfo+1])
				let b = UInt32(data[currentPixelInfo+2])
				let a = UInt32(data[currentPixelInfo+3])
				let currentColor: UInt32 = (r << 24) + (g << 16) + (b << 8) + a
				
				if currentColor != previousColor {
					return false
				}
				
				previousColor = currentColor
			}
		}
		
		return true
	}
}
