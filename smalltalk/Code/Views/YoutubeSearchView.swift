//
//  YoutubeSearchView.swift
//  smalltalk
//
//  Created by Mikko Hämäläinen on 13/11/15.
//  Copyright © 2015 Mikko Hämäläinen. All rights reserved.
//

import UIKit
import ReactiveCocoa

class YoutubeSearchView: UITableView, UITableViewDelegate, UITableViewDataSource {
	//var superFrame: CGRect
	weak var viewModel: SearchViewModel?
	private let searchCellIdentifier = "YoutubeSearchViewCell"
	private let detailCellIdentifier = "YoutubeDetailViewCell"
	
	init(frame: CGRect, viewModel: SearchViewModel) {
		//self.superFrame = frame
		self.viewModel = viewModel
		super.init(frame: frame, style: .Plain)
		self.separatorStyle = UITableViewCellSeparatorStyle.None
		self.translatesAutoresizingMaskIntoConstraints = false
		self.scrollsToTop = false
		self.dataSource = self
		self.delegate = self
		
		//Top hairline
		var rect: CGRect = CGRectZero
		rect.size = CGSizeMake(CGRectGetWidth(frame), 0.5)
		let hairline = UIView(frame: rect)
		hairline.autoresizingMask = UIViewAutoresizing.FlexibleWidth
		hairline.backgroundColor = self.separatorColor
		self.addSubview(hairline)
		
		self.registerClass(SearchViewTableViewCell.self, forCellReuseIdentifier: searchCellIdentifier)
		self.registerClass(SearchViewDetailTableViewCell.self, forCellReuseIdentifier: detailCellIdentifier)

		self.setupBindings()
	}

	required init?(coder aDecoder: NSCoder) {
	    fatalError("init(coder:) has not been implemented")
	}
	
	private func setupBindings() {
		self.setupSearchResultsBindings()
	}
	
	private func setupSearchResultsBindings() {
		self.viewModel!.disposer.addDisposable(
			self.viewModel!.searchResults.producer
				.observeOn(UIScheduler())
				.start {
					[weak self] event in
					switch event {
					case .Next:
						self?.reloadData()
					default:
						break
					}
			}
		)
	}
	
	//mark - UITableViewDataSource Methods
	func numberOfSectionsInTableView(tableView: UITableView) -> Int {
		return 1
	}
	
	func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
		return self.viewModel!.searchResults.value.count
	}
	
	func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
		let (result, detailView) = self.viewModel!.searchResults.value[indexPath.row]
		
		if !detailView {
			let searchResultCell = tableView.dequeueReusableCellWithIdentifier(searchCellIdentifier, forIndexPath: indexPath) as! SearchViewTableViewCell
			searchResultCell.searchResult(result)
			return searchResultCell
		} else {
			let searchDetailsCell = tableView.dequeueReusableCellWithIdentifier(detailCellIdentifier, forIndexPath: indexPath) as! SearchViewDetailTableViewCell
			searchDetailsCell.searchDetails(result, searchViewModel: self.viewModel!)
			return searchDetailsCell
		}
	}
	
	func tableView(tableView: UITableView, heightForRowAtIndexPath indexPath: NSIndexPath) -> CGFloat {
		return CGFloat(80)
	}
	
	//mark - UITableViewDelegate Methods
	func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        let (result, detailView) = self.viewModel!.searchResults.value[indexPath.row]
		if !detailView {
			self.viewModel?.needDetails(result, atIndex: indexPath.row)
		} 
	}
}
