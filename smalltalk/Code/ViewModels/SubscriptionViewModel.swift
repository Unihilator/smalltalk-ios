//
//  SubscriptionViewModel.swift
//  smalltalk
//
//  Created by Mikko Hämäläinen on 18/11/15.
//  Copyright © 2015 Mikko Hämäläinen. All rights reserved.
//

import Foundation
import ReactiveCocoa
import CoreData
import TSMessages
import Result
import SwiftyJSON

class SubscriptionViewModel: NSObject {
	let disposer = CompositeDisposable()
	let detailResult = MutableProperty<YoutubeSearchResult?>(nil)
	let alreadySubscribedResult = MutableProperty<Bool>(true)
	let currentThreadId: String
	let inConversationWith: STContact
	let searchResult: YoutubeSearchResult
	let subscribeSucceeded = MutableProperty<String?>(nil)
	let subscribeFailed = MutableProperty<String?>(nil)
	let unsubscribeSucceeded = MutableProperty<String?>(nil)
	let unsubscribeFailed = MutableProperty<String?>(nil)
	
	init(searchResult: YoutubeSearchResult, threadId: String, inConversationWith: STContact) {
		self.currentThreadId = threadId
		self.inConversationWith = inConversationWith
		self.searchResult = searchResult
		super.init()
	}
	
	deinit {
		self.disposer.dispose()
	}
	
	func subscribe() {
		let data = [
			"channelId" : self.searchResult.id,
			"threadId" : self.currentThreadId,
			"participants" : [
				User.username,
				self.inConversationWith.username
			]
		]
		
		self.subscribeChannel(data as [NSObject : AnyObject])
			.start {
				[unowned self] event in
				switch event {
				case let .Next(result):
					NSLog("Subscribe to channel succeeded! \(result)")
					self.subscribeSucceeded.value = "Subscribed to \(self.searchResult.title)"
				case let .Failed(error):
					NSLog("Subscribe to channel failed! %@", error)
					self.subscribeFailed.value = "Already subscribed to \(self.searchResult.title)"
				default:
					break
				}
		}
	}
	
	func unsubscribe() {
		let data = [
			"channelId" : self.searchResult.id,
			"threadId" : self.currentThreadId,
			"participants" : [
				User.username,
				self.inConversationWith.username
			]
		]
		
		self.unsubscribeChannel(data as [NSObject : AnyObject])
			.start {
				[unowned self] event in
				switch event {
				case let .Next(result):
					NSLog("UnSubscribe to channel succeeded! \(result)")
					self.unsubscribeSucceeded.value = "Unsubscribed from \(self.searchResult.title)"
				case let .Failed(error):
					NSLog("Unsubscribe to channel failed! %@", error)
					self.unsubscribeFailed.value = "Already Unsubscribed from \(self.searchResult.title)"
				default:
					break
				}
		}
	}
	
	func fetchDetails() {
		//Youtube details
		self.disposer.addDisposable(
			self.channelDetails()
				.start {
					[unowned self] event in
					switch event {
					case let .Next(result):
						NSLog("Youtube details \(result)")
						if (result.value != nil) {
							let json = result.value as! JSON
							let item = json["items"].arrayValue[0]
							self.detailResult.value = YoutubeSearchResult(json: item)
						}
					case let .Failed(error):
						NSLog("Youtube search failed \(error)")
					default:
						break
					}
			}
		)
		
		//Subscription details
		self.disposer.addDisposable(
			self.getSubscriptionStatus()
				.start {
					[unowned self] event in
					switch event {
					case let .Next(result):
						NSLog("Subscribe to channel succeeded! \(result)")
						let json = result.value as! JSON
						self.alreadySubscribedResult.value = json["status"].boolValue
					case let .Failed(error):
						NSLog("Subscribe to channel failed! %@", error)
					default:
						break
					}
			}
		)
	}
	
	private func channelDetails() -> SignalProducer<Result<Any, NSError>, NSError> {
		return STHttp.get("https://www.googleapis.com/youtube/v3/channels?id=\(self.searchResult.id)&key=\(Configuration.youtubeApiKey)&part=id,snippet,statistics")
	}
	
	private func subscribeChannel(data: [NSObject: AnyObject]) -> SignalProducer<Result<Any, NSError>, NSError> {
		return STHttp.post("\(Configuration.subscribeApi)/subscribe/new", data: data)
	}
	
	private func unsubscribeChannel(data: [NSObject: AnyObject]) -> SignalProducer<Result<Any, NSError>, NSError> {
		return STHttp.post("\(Configuration.subscribeApi)/subscribe/delete", data: data)
	}
	
	private func getSubscriptionStatus() -> SignalProducer<Result<Any, NSError>, NSError> {
		return STHttp.get("\(Configuration.subscribeApi)/subscribe/get?user=\(User.username)&channelId=\(self.searchResult.id)&threadId=\(self.currentThreadId)")
	}
}
