//
//  WebViewProtocol.swift
//  smalltalk
//
//  Created by Mikko Hämäläinen on 28/10/15.
//  Copyright © 2015 Mikko Hämäläinen. All rights reserved.
//

import UIKit
import SwiftyJSON
import WebKit

class WebViewModel: NSObject, WKNavigationDelegate {
	private let gameType: String
	var gameData: JSON?
	private var outgoingView: Bool
	private var completionCallback: ((Bool) -> Void)!
	private var initialLoad = true
	
	init(gameType: String, data: JSON?, outgoingView: Bool) {
		self.gameType = gameType
		self.gameData = data
		self.outgoingView = outgoingView
	}
	
	deinit {

	}
	
	func loadWebView(webView: WKWebView, urlConnDelegate: NSURLConnectionDelegate, completion: (Bool) -> Void) {
		let strUrl = Configuration.games[self.gameType]!.url
		let url = NSURL(string:strUrl)
		let req = NSURLRequest(URL: url!, cachePolicy: NSURLRequestCachePolicy.UseProtocolCachePolicy, timeoutInterval: 60)
		var _ = NSURLConnection(request: req, delegate: urlConnDelegate)!
		self.completionCallback = completion
		webView.navigationDelegate = self
		//Make sure we're in main thread
		dispatch_async(dispatch_get_main_queue()) {
			[weak webView] in
				webView?.loadRequest(req)!
		}
	}
	
	func webView(webView: WKWebView, didFinishNavigation navigation: WKNavigation!) {
		NSLog("webView didFinishNavigation")
		if initialLoad {
			var stateStr: String = "undefined"
			var updateStateStr: String = "undefined"
			let outgoingStr = self.outgoingView ? "true" : "false"
			if gameData != nil {
				stateStr = gameData!["state"].stringValue
				stateStr = "\"\(stateStr)\""
				//UpdatedState is javascript
				let updateState = gameData!["updateState"]
				if let jsonStr = updateState.rawString(NSUTF8StringEncoding, options: NSJSONWritingOptions(rawValue: 0)) {
					updateStateStr = jsonStr
				}
			}

			let js = String(format: "applicationStart(%@, %@, %@);", stateStr, updateStateStr, outgoingStr)
			webView.evaluateJavaScript(js, completionHandler: {
				[weak self] (result: AnyObject?, error: NSError?) -> Void in
				if error != nil {
					NSLog("evaluateJavaScript Error \(error)")
					self?.completionCallback(false)
				} else {
					self?.completionCallback(true)
				}
			})
		}
		
		initialLoad = false
	}
	
	func webView(webView: WKWebView, didFailNavigation navigation: WKNavigation!, withError error: NSError) {
		NSLog("%s. With Error %@", __FUNCTION__, error)
		completionCallback(false)
	}
	
	//mark - NSObject
	override var hash: Int {
		get {
			return super.hash ^ self.gameData!.rawString()!.hash
		}
	}
}

