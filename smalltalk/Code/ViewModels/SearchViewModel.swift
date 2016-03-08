//
//  SearchViewModel.swift
//  smalltalk
//
//  Created by Mikko Hämäläinen on 13/11/15.
//  Copyright © 2015 Mikko Hämäläinen. All rights reserved.
//

import Foundation
import ReactiveCocoa
import CoreData
import TSMessages
import Result
import SwiftyJSON

class SearchViewModel: NSObject {
	var typing = MutableProperty<String>("") //What the user is typing in the view
	let disposer = CompositeDisposable()
	let searchResults = MutableProperty<[(YoutubeSearchResult, Bool)]>([])
    let currentThreadId: String
    let inConversationWith: STContact
	let subscribeSucceeded = MutableProperty<String?>(nil)
	let subscribeFailed = MutableProperty<String?>(nil)

    init(threadId: String, inConversationWith: STContact) {
        self.currentThreadId = threadId
        self.inConversationWith = inConversationWith
		super.init()
		self.setupBindings()
	}
	
	deinit {
		self.disposer.dispose()
	}
	
	func needDetails(result: YoutubeSearchResult, atIndex: Int) {
		if self.searchResults.value.count > atIndex + 1 {
			let (_, detailView) = self.searchResults.value[atIndex + 1]
			//There's already a detail view visible
			if detailView {
				self.searchResults.value.removeAtIndex(atIndex + 1)
			} else {
				self.searchResults.value.insert((result, true), atIndex: atIndex + 1)
			}
		} else {
			self.searchResults.value.append((result, true))
		}
	}
	
	private func setupBindings() {
		setupSlashCommandBindings()
	}
	
	private func setupSlashCommandBindings() {
		//We do a /command
		self.disposer.addDisposable(
			self.typing.producer
				.map {
					[unowned self] (value: String) in
					return value.trimWithNewline().lowercaseString
				}
				.skipRepeats()
				.filter {
					[unowned self] (typedString: String) in
					//Related to the /command syntax. Don't send chat notifications on slash commands
					return typedString.characters.first != nil && typedString.characters.first ==  "/"
				}
				.throttle(1.0, onScheduler: QueueScheduler.mainQueueScheduler) //Atleast 1000ms must be waited before we send the check the command
				.start {
					[unowned self] event in
					switch event {
					case let .Next(typedCommand):
						if typedCommand.containsString("/youtube ") {
							//Remove the /youtube part
							let ytSearchQuery = typedCommand.stringByReplacingOccurrencesOfString("/youtube ", withString: "")
							if ytSearchQuery.characters.count >= 2 {
								self.youtubeSearch(ytSearchQuery)
									.start {
										[unowned self] event in
										switch event {
										case let .Next(result):
											NSLog("Youtube search \(result)")
											if (result.value != nil) {
												let json = result.value as! JSON
												let items = json["items"].arrayValue
												self.searchResults.value = items.map { return (YoutubeSearchResult(json: $0), false) }
											}
										case let .Failed(error):
											NSLog("Youtube search failed \(error)")
										default:
											break
										}
								}
							}
						}
					default:
						break
					}
			}
		)
	}
	
	private func youtubeSearch(youtubeSearch: String) -> SignalProducer<Result<Any, NSError>, NSError> {
        /*
        The q parameter specifies the query term to search for. Your request can also use the Boolean NOT (-) and OR (|) operators to exclude videos or to find videos that are associated with one of several search terms. For example, to search for videos matching either "boating" or "sailing", set the q parameter value to boating|sailing. Similarly, to search for videos matching either "boating" or "sailing" but not "fishing", set the q parameter value to boating|sailing -fishing. Note that the pipe character must be URL-escaped when it is sent in your API request. The URL-escaped value for the pipe character is %7C. (string)
        */
		let escapedString: String = youtubeSearch.stringByAddingPercentEncodingWithAllowedCharacters(NSCharacterSet.URLQueryAllowedCharacterSet())!
        return STHttp.get("https://www.googleapis.com/youtube/v3/search?q=\(escapedString)&key=\(Configuration.youtubeApiKey)&type=channel&part=id,snippet")
	}
}
