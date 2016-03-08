//
//  SearchViewDetailTableViewCell.swift
//  smalltalk
//
//  Created by Mikko Hämäläinen on 18/11/15.
//  Copyright © 2015 Mikko Hämäläinen. All rights reserved.
//

import UIKit
import SnapKit
import ReactiveCocoa
import Result
import ChameleonFramework

class SearchViewDetailTableViewCell: UITableViewCell {
	var searchDetails: UILabel!
	var subscribeButton: UIButton!
	var unsubscribeButton: UIButton!
	var viewModel: SubscriptionViewModel?
	
	override init(style: UITableViewCellStyle, reuseIdentifier: String?) {
		super.init(style: style, reuseIdentifier: reuseIdentifier)
		self.searchDetails = UILabel(frame: CGRectZero)
		self.searchDetails.adjustsFontSizeToFitWidth = true
		self.addSubview(self.searchDetails)
		self.searchDetails!.snp_makeConstraints { make in
			make.bottom.equalTo(self.snp_bottom).offset(-10)
			make.right.equalTo(self.snp_right).offset(-10)
		}
		
		self.subscribeButton = UIButton(frame: CGRectZero)
		self.addSubview(subscribeButton)
		subscribeButton.enabled = false
		subscribeButton.backgroundColor = UIColor.whiteColor()
		subscribeButton.layer.cornerRadius = 5
		subscribeButton.setTitleColor(UIColor.lightGrayColor(), forState: UIControlState.Disabled)
		subscribeButton.setTitleColor(UIColor.whiteColor(), forState: UIControlState.Normal)
		subscribeButton.setTitle("Loading...", forState: UIControlState.Disabled)
		subscribeButton.setTitle("Subscribe", forState: UIControlState.Normal)
		subscribeButton.titleLabel!.font = UIFont.boldSystemFontOfSize(UIFont.systemFontSize())
		subscribeButton.snp_makeConstraints { (make) -> Void in
			make.width.equalTo(self).multipliedBy(0.6)
			make.height.equalTo(self).multipliedBy(0.30)
			make.centerX.equalTo(self)
			make.centerY.equalTo(self)
		}
		subscribeButton.addTarget(self, action: "subscribePressed:", forControlEvents: UIControlEvents.TouchUpInside)
		
		self.unsubscribeButton = UIButton(frame: CGRectZero)
		self.addSubview(unsubscribeButton)
		unsubscribeButton.hidden = true
		unsubscribeButton.enabled = false
		unsubscribeButton.backgroundColor = FlatGreen()
		unsubscribeButton.layer.cornerRadius = 5
		unsubscribeButton.setTitleColor(UIColor.whiteColor(), forState: UIControlState.Disabled)
		unsubscribeButton.setTitleColor(UIColor.whiteColor(), forState: UIControlState.Normal)
		unsubscribeButton.setTitle("Unsubscribing...", forState: UIControlState.Disabled)
		unsubscribeButton.setTitle("Unsubscribe", forState: UIControlState.Normal)
		unsubscribeButton.titleLabel!.font = UIFont.boldSystemFontOfSize(UIFont.systemFontSize())
		unsubscribeButton.snp_makeConstraints { (make) -> Void in
			make.width.equalTo(self).multipliedBy(0.6)
			make.height.equalTo(self).multipliedBy(0.30)
			make.centerX.equalTo(self)
			make.centerY.equalTo(self)
		}
		unsubscribeButton.addTarget(self, action: "unsubscribePressed:", forControlEvents: UIControlEvents.TouchUpInside)
	}
	
	required init?(coder aDecoder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}
	
	override func awakeFromNib() {
		super.awakeFromNib()
		// Initialization code
	}
	
	func searchDetails(result: YoutubeSearchResult, searchViewModel: SearchViewModel) {
		self.setSubscriberCount(result)
		self.viewModel = SubscriptionViewModel(searchResult: result, threadId: searchViewModel.currentThreadId, inConversationWith: searchViewModel.inConversationWith)
		self.setupBindings(searchViewModel)
		self.viewModel!.fetchDetails()
	}
	
	func subscribePressed(sender: UIButton) {
		self.viewModel?.subscribe()
		subscribeButton.setTitle("Subscribing...", forState: UIControlState.Disabled)
		subscribeButton.setTitleColor(UIColor.whiteColor(), forState: UIControlState.Disabled)
		subscribeButton.backgroundColor = UIColor.flatGreenColor()
		subscribeButton.enabled = false
	}
	
	func unsubscribePressed(sender: UIButton) {
		self.viewModel?.unsubscribe()
		unsubscribeButton.enabled = false
	}
	
	private func setSubscriberCount(result: YoutubeSearchResult) {
		let subscribersCount = "\(result.subscriberCount) subscribers"
		let detailsString: NSMutableAttributedString = NSMutableAttributedString(string:subscribersCount)
		detailsString.addAttribute(NSForegroundColorAttributeName, value: UIColor.lightGrayColor(), range: NSMakeRange(0, subscribersCount.characters.count))
		detailsString.addAttribute(NSFontAttributeName, value: UIFont.systemFontOfSize(UIFont.smallSystemFontSize()), range: NSMakeRange(0, subscribersCount.characters.count))
		self.searchDetails?.attributedText = detailsString
	}
	
	private func setSubscribeButtonStatus(subscribedAlready: Bool) {
		subscribeButton.enabled = !subscribedAlready
		subscribeButton.hidden = subscribedAlready
		if subscribeButton.enabled {
			let app = UIApplication.sharedApplication().delegate as! AppDelegate
			subscribeButton.backgroundColor = app.globalColor
		}
		
		unsubscribeButton.enabled = subscribedAlready
		unsubscribeButton.hidden = !subscribedAlready
	}
	
	private func setupBindings(searchViewModel: SearchViewModel) {
		self.setupDetailsFetchedBindings()
		self.setupSubscribedFetchedBindings()
		self.setupSubscriptionStatusBindings(searchViewModel)
	}
	
	private func setupDetailsFetchedBindings() {
		self.viewModel!.disposer.addDisposable(
			self.viewModel!.detailResult.producer
				.skip(1) //Ignore the initial nil value
				.observeOn(UIScheduler())
				.start {
					[unowned self] event in
					switch event {
					case let .Next(searchResult):
						self.setSubscriberCount(searchResult!)
					default:
						break
					}
			}
		)
	}
	
	private func setupSubscribedFetchedBindings() {
		self.viewModel!.disposer.addDisposable(
			self.viewModel!.alreadySubscribedResult.producer
				.skip(1) //Ignore the initial nil value
				.observeOn(UIScheduler())
				.start {
					[unowned self] event in
					switch event {
					case let .Next(subscribedAlready):
						self.setSubscribeButtonStatus(subscribedAlready)
					default:
						break
					}
			}
		)
	}

	private func setupSubscriptionStatusBindings(searchViewModel: SearchViewModel) {
		self.viewModel!.disposer.addDisposable(
			self.viewModel!.subscribeSucceeded.producer
				.skip(1) //Ignore the initial nil value
				.start {
					[unowned self] event in
					switch event {
					case let .Next(msgToSend):
						self.setSubscribeButtonStatus(true)
						searchViewModel.subscribeSucceeded.value = msgToSend
					default:
						break
					}
			}
		)
		
		self.viewModel!.disposer.addDisposable(
			self.viewModel!.subscribeFailed.producer
				.skip(1) //Ignore the initial nil value
				.start {
					[unowned self] event in
					switch event {
					case let .Next(msgToShow):
						searchViewModel.subscribeFailed.value = msgToShow
					default:
						break
					}
			}
		)
		
		self.viewModel!.disposer.addDisposable(
			self.viewModel!.unsubscribeSucceeded.producer
				.skip(1) //Ignore the initial nil value
				.start {
					[unowned self] event in
					switch event {
					case let .Next(msgToSend):
						self.setSubscribeButtonStatus(false)
						searchViewModel.subscribeSucceeded.value = msgToSend
					default:
						break
					}
			}
		)
		
		self.viewModel!.disposer.addDisposable(
			self.viewModel!.unsubscribeFailed.producer
				.skip(1) //Ignore the initial nil value
				.start {
					[unowned self] event in
					switch event {
					case let .Next(msgToShow):
						searchViewModel.subscribeFailed.value = msgToShow
					default:
						break
					}
			}
		)
	}
}
