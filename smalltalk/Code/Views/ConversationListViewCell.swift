//
//  ConversationListViewCell.swift
//  smalltalk
//
//  Created by Mikko Hämäläinen on 19/11/15.
//  Copyright © 2015 Mikko Hämäläinen. All rights reserved.
//

import UIKit
import SnapKit
import ChameleonFramework
import JSQMessagesViewController
import SwiftDate

class ConversationListViewCell: UITableViewCell {
	var avatar: UIImageView!
	var inConversationWith: UILabel!
	var messageText: UILabel!
	var dateText: UILabel!
	
	override init(style: UITableViewCellStyle, reuseIdentifier: String?) {
		super.init(style: style, reuseIdentifier: reuseIdentifier)
		let diameter = 60.0
		self.avatar = UIImageView(frame: CGRectZero)
		self.addSubview(avatar)
		self.avatar!.snp_makeConstraints { make in
			make.centerY.equalTo(self)
			make.left.equalTo(self).offset(15)
			make.size.equalTo(diameter)
		}
		
		self.dateText = UILabel(frame: CGRectZero)
		self.addSubview(self.dateText)
		self.dateText!.snp_makeConstraints { make in
			make.top.equalTo(self.avatar.snp_top).offset(12)
			make.right.equalTo(self).offset(-10)
		}
	
		self.inConversationWith = UILabel(frame: CGRectZero)
		self.addSubview(self.inConversationWith)
		self.inConversationWith!.snp_makeConstraints { make in
			make.top.equalTo(self.avatar.snp_top).offset(10)
			make.left.equalTo(self.avatar.snp_right).offset(15)
			make.right.equalTo(self).offset(-30)
		}
		
		self.messageText = UILabel(frame: CGRectZero)
		self.messageText.numberOfLines = 1
		self.addSubview(self.messageText)
		self.messageText!.snp_makeConstraints { make in
			make.top.equalTo(self.inConversationWith.snp_bottom).offset(3)
			make.left.equalTo(self.inConversationWith)
			make.right.equalTo(self).offset(-10)
		}
		
		//Bottom hairline
		let hairline = UIView(frame: CGRectZero)
		hairline.backgroundColor = UIColor.lightGrayColor().lightenByPercentage(0.1)
		self.addSubview(hairline)
		hairline.snp_makeConstraints { make in
			make.bottom.equalTo(self.avatar.snp_bottom).offset(7)
			make.left.equalTo(self.messageText)
			make.width.equalTo(self)
			make.height.equalTo(1)
		}
		
		self.initialFontsAndColors()
	}
	
	private func initialFontsAndColors() {
		let app = UIApplication.sharedApplication().delegate as! AppDelegate
		self.dateText.textColor = UIColor.grayColor()
		self.dateText.font = UIFont.systemFontOfSize(self.inConversationWith.font.pointSize - 2)
		self.inConversationWith.font = UIFont.systemFontOfSize(self.inConversationWith.font.pointSize)
		self.inConversationWith.textColor = app.darkColor
		self.messageText.font = UIFont.systemFontOfSize(self.inConversationWith.font.pointSize - 2)
		self.messageText.textColor = UIColor.grayColor()
	}
	
	required init?(coder aDecoder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}
	
	override func awakeFromNib() {
		super.awakeFromNib()
		// Initialization code
	}
	
	func setMessage(latestMsg: STMessage) {
		let avatarId = "list-\(latestMsg.senderId)"
		if AvatarUtils.avatars[avatarId] == nil {
			AvatarUtils.setupAvatarImage(avatarId, displayName: latestMsg.senderDisplayName, fontSize: UIFont.systemFontSize())
		}
		
		self.avatar.image = AvatarUtils.avatars[avatarId]!.avatarImage
		self.inConversationWith.text = latestMsg.inConversationWith.displayName
		self.messageText.text = latestMsg.shortDisplayText
		if latestMsg.senderId == User.senderId {
			self.messageText.text = "You: \(self.messageText.text!)"
		}
		self.dateText.text = latestMsg.date.toRelativeString(NSDate(), abbreviated: true, maxUnits:1)
		
		let latestSeenStored = LatestSeenStore.latestSeenInThread(latestMsg.threadId)
		//latestMsg may have slightly different NSDate (some milliseconds) than latestSeenStoredDate even thought it is the same
		//message. This is because there are two instances of this message: one created by ConversationsViewModel and one by 
		//ConversationsListViewModel. They may have a bit different timestamp when the User is the sender as the NSDate is generated
		//in STMessage.fromNetworkMessage (the message itself doesn't have a timestamp in this case as it is User's message)
		if latestSeenStored == nil || ((latestSeenStored!.id != latestMsg.id) && (latestSeenStored!.date < latestMsg.date)) {
			self.dateText.font = UIFont.boldSystemFontOfSize(self.dateText.font.pointSize)
			self.inConversationWith.font = UIFont.boldSystemFontOfSize(self.inConversationWith.font.pointSize)
			self.messageText.font = UIFont.boldSystemFontOfSize(self.messageText.font.pointSize)
			let app = UIApplication.sharedApplication().delegate as! AppDelegate
			self.messageText.textColor = app.darkColor
			self.dateText.textColor = app.highlightColor
		} else {
			self.initialFontsAndColors()
		}
	}
}

