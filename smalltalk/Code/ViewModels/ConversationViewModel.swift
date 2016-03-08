//
//  ConversationViewModel.swift
//  smalltalk
//
//  Created by Mikko Hämäläinen on 24/09/15.
//  Copyright (c) 2015 Mikko Hämäläinen. All rights reserved.
//

import Foundation
import ReactiveCocoa
import JSQMessagesViewController
import XMPPFramework
import CoreData
import TSMessages
import Result
import SwiftyJSON
import SDWebImage
import Toucan

class ConversationViewModel: NSObject {
	var messagesLoadFromDb = true
	let disposer = CompositeDisposable()
	var messages = MutableProperty<[STMessage]>([])
	var reloadMesssage = MutableProperty<Int?>(nil)
	var typing = MutableProperty<String>("") //What the user is typing in the view
	var loadingMoreContent = MutableProperty<Bool>(false)
	var keyboardShown = MutableProperty<Bool>(false)
	var messagesInOtherThreads = MutableProperty<Int>(0)
	
	private unowned var xmppClient: STXMPPClient
	private let chattingWith: STContact
	let currentThread: String
	
	//Chat state notifications
	private var canSendChatStateComposingNotif = true //Can I send composing to chattingWith
	var shouldDisplayChatStateComposingNotif = MutableProperty<Bool>(false) //Can I display chattingWith's composing
	var composingNotifTimeout: Disposable? = nil
	
	//Loading
	let fetchLimit = 15 //This should not be much less than this. We want to load at least a screenful of messages at a time
	var canLoad = true
	
	init(xmpp: STXMPPClient, chattingWith: STContact) {
		self.xmppClient = xmpp
		self.currentThread = ConversationViewModel.threadId([User.username, chattingWith.username])
		self.chattingWith = chattingWith
		super.init()
		self.setupBindings()
		self.loadInitialData()
		//If only the initial first message has been loaded, we load some more
		if messages.value.count == 1 {
			self.loadMore()
		}
		
		//Done like this instead of RAC issues where RAC wouldn't remove the observer even after self had been disposed
		NSNotificationCenter.defaultCenter().addObserver(self, selector: "becameActive:", name: UIApplicationDidBecomeActiveNotification, object: nil)
		NSNotificationCenter.defaultCenter().addObserver(self, selector: "keyboardDidShow:", name: UIKeyboardDidShowNotification, object: nil)
		NSNotificationCenter.defaultCenter().addObserver(self, selector: "keyboardDidHide:", name: UIKeyboardDidHideNotification, object: nil)
	}
	
	deinit {
		self.disposer.dispose()
		NSNotificationCenter.defaultCenter().removeObserver(self)
	}

	func keyboardDidShow(notification: NSNotification) {
		self.keyboardShown.value = true
	}
	
	func keyboardDidHide(notification: NSNotification) {
		self.keyboardShown.value = false
	}
	
	func becameActive(notification: NSNotification) {
		//Make sure that any message that was inputted to db from push message is now loaded immediately to view
		self.loadMore(self.messages.value.count)
	}
	
	func sendMessage(text: String, image: UIImage? = nil) {
		let id = NSUUID().UUIDString
		let msg = STMessage(
			id: id,
			senderId: User.senderId,
			senderDisplayName: User.displayName!,
			date: NSDate(),
			text: text,
			media: image,
            threadId: self.currentThread,
			inConversationWith: self.chattingWith)
		
		doSend(text, msg:msg)
	}
	
	func sendGameMessage(text: String, data: STGameData, deleteOwnOnly: Bool) {
		//Delete messages of this game (only one message per game allowed)
		self.deleteAllPreviousMessagesOfType(data.dataContentType, deleteOwnOnly: deleteOwnOnly)
		let id = NSUUID().UUIDString
		let msgContent = STMessageAttachment(json: data.data, contentType: data.dataContentType)
		let msg = STMessage(
			id: id,
			senderId: User.senderId,
			senderDisplayName: User.displayName!,
			date: NSDate(),
			text: text,
			attachment: msgContent,
            threadId: self.currentThread,
			inConversationWith: self.chattingWith)
		
		doSend(text, msg:msg)
	}
	
	func deleteAllPreviousMessagesOfType(contentType: String, deleteOwnOnly: Bool = false) {
		let archiveIds = deleteLocalMessages(contentType, notId: "", deleteOwnOnly: deleteOwnOnly)
		self.xmppClient.stream.purgeFromMAM(archiveIds.map { (archiveId, _) in return archiveId })
	}
	
	func hasMessagesOfType(contentType: String) -> Bool {
		let context: NSManagedObjectContext? = self.xmppClient.stream.xmppMessageArchivingCoreDataStorage.mainThreadManagedObjectContext
		let messageEntity: NSEntityDescription? = NSEntityDescription.entityForName(self.xmppClient.stream.xmppMessageArchivingCoreDataStorage.messageEntityName, inManagedObjectContext: context!)
		
		let fetchRequest = NSFetchRequest()
		let predicate: NSPredicate = NSPredicate(format: "contentType == %@ and thread == %@", contentType, self.currentThread)
		fetchRequest.predicate = predicate
		fetchRequest.entity = messageEntity
		fetchRequest.returnsObjectsAsFaults = false
		do {
			let fetchResults = try context!.executeFetchRequest(fetchRequest) as! [XMPPMAMArchivingMessageCoreDataObject]
			return fetchResults.count > 0
		} catch {
			assert(false, "Coredata executeFetchRequest error \(error)")
		}
		
		return false
	}
	
	//Text is sent as a separate param because msg might be a media message without text
	private func doSend(text: String, msg: STMessage) {
		messagesLoadFromDb = false
		self.messages.value.append(msg)
		self.xmppClient.sendMessage(msg.id, text: text, to: self.chattingWith.username, thread: self.currentThread, content: msg.attachment)
		self.canSendChatStateComposingNotif = true //Can be shown again as new message is written
		
		if (msg.isMediaMessage && msg.attachment?.contentType == STMessageAttachment.imageContentType) {
			self.uploadMedia(((msg.media) as! JSQPhotoMediaItem).image!, attachmentDesc: msg.attachment!)
		}
	}
	
	private func setupBindings() {
		self.setupMessageReceiveBindings()
		self.setupMessagesInOtherThreadsBindings()
		self.setupMessageReceiptsBindings()
		self.setupMessageDownloadBindings()
		self.setupReceiveChatStateBindings()
		self.setupSendChatStateBindings()
	}
	
	private func setupMessageReceiveBindings() {
		//Monitor for incoming messages
		self.disposer.addDisposable(
			self.xmppClient.stream.incomingMessages
				.toSignalProducer()
				.filter {
					[unowned self] (msg: XMPPMessage) -> Bool in //Keep this type info, otherwise compilation slows down alot!
					return msg.body() != nil && msg.thread() == self.currentThread
				}
				.observeOn(UIScheduler()) //Must become before fromNetworkMessage because STMessage constructs views in STGameMediaItem
				.map {
					[unowned self] msg in
					return STMessage.fromNetworkMessage(msg, inConversationWith: self.chattingWith)
				}
				.start {
					[unowned self] event in
					switch event {
					case let .Next(msg):
						if !self.isDuplicate(msg) {
							//There can be only one message of each type present
							if (msg.isGameMediaMessage) {
								//TODO! Test cases where this might fail when the game comes as a push message
								//push written to DB but not in messages? Add id check to deleteLocalMessages?
								//Add assert that deleteLocalMessages assetIds are different from msg.archiveId
								let deletedIds = self.deleteLocalMessages(msg.attachment!.contentType, notId: msg.id)
								for (_, deletedId) in deletedIds {
									assert(msg.id != deletedId, "Non-duplicate message deleted self from archive")
								}
							}
						
							self.messagesLoadFromDb = false
							self.messages.value.append(msg)
						}
						
						//Actual message received, don't display the typing indicator anymore.
						//NOTE! This should be done always even if the message has been marked as duplicate
						//This can happen when the message has previously been received through the push service
						//Message A from push service -> come online -> composing notification from offline storage -> Message A again from offline storage (marked as duplicate)
						self.shouldDisplayChatStateComposingNotif.value = false
					default:
						break
					}
			}
		)
	}
	
	private func setupMessagesInOtherThreadsBindings() {
		//Monitor for incoming messages in other threads
		self.disposer.addDisposable(
			self.xmppClient.stream.incomingMessages
				.toSignalProducer()
				.filter {
					[unowned self] (msg: XMPPMessage) -> Bool in //Keep this type info, otherwise compilation slows down alot!
					return msg.body() != nil && msg.thread() != self.currentThread
				}
				.observeOn(UIScheduler()) //Must become before fromNetworkMessage because STMessage constructs views in STGameMediaItem
				.start {
					[unowned self] event in
					switch event {
					case .Next:
						self.messagesInOtherThreads.value += 1
					default:
						break
					}
			}
		)
	}
	
	private func setupMessageReceiptsBindings() {
		//Monitor for incoming receipt and mark messages
		self.disposer.addDisposable(
			self.xmppClient.stream.incomingReceipts
				.toSignalProducer()
				.observeOn(UIScheduler())
				.start {
					[unowned self] event in
					switch event {
					case let .Next(messageId, deliveryStatus):
						let index = self.messages.value.indexOf {
							message in
							return message.id == messageId
						}
					
						if index != nil {
							let message = self.messages.value[index!]
							message.deliveryStatus = deliveryStatus
							self.reloadMsgView(message)
						}
					default:
						break
				}
			}
		)
	}
	
	private func setupMessageDownloadBindings() {
		//Observe messages array and download messages that are media messages but don't have data yet
		self.disposer.addDisposable(
			self.messages.producer
				.uncollect()
				.filter {
					[unowned self] (message: STMessage) in
					return message.isMediaMessage &&
						message.attachment != nil &&
						message.attachment!.contentType == STMessageAttachment.imageContentType &&
						message.attachment!.json != nil &&
						((message.media) as! JSQPhotoMediaItem).image == nil
				}
				.flatMap(FlattenStrategy.Merge, transform: {
					[unowned self] message in
					return self.downloadMedia(message)
					//We want to catch errors so that this pipeline doesn't terminate on download errors
					.flatMapError { error in
						return SignalProducer { observer, disposable in
							let eResult = Result<(UIImage, String), NSError>(error: error)
							observer.sendNext(eResult)
							observer.sendCompleted()
						}
					}
					.map {
						result in
						(result, message)
					}
				})
				.observeOn(UIScheduler())
				.start {
					[unowned self] event in
					switch event {
					case let .Next(next):
						let (result, message) = next
						if (result.value != nil) {
							let (image, _) = result.value!
							let mediaItem: JSQPhotoMediaItem = (message.media) as! JSQPhotoMediaItem
							//We get two images from the pipe: thumbnail and the actual image. Assign the thumbnail (the first image)
							if mediaItem.image == nil {
								mediaItem.image = image
								self.reloadMsgView(message)
							}
						} else {
							NSLog("Error occurred while downloading media %@", result.error!)
						}
					default:
						break
					}
			}
			
		)
	}
	
	private func setupReceiveChatStateBindings() {
		//Did we receive a incoming composingChatState
		self.disposer.addDisposable(
			self.xmppClient.stream.incomingMessages
				.toSignalProducer()
				.filter {
					[unowned self] (msg: XMPPMessage) -> Bool in
					return msg.thread() == self.currentThread && msg.hasComposingChatState()
				}
				.map {
					[unowned self] (msg: XMPPMessage) -> Bool in
					return true
				}
				.observeOn(UIScheduler())
				.start {
					[unowned self] event in
					switch event {
					case let .Next(value):
						self.shouldDisplayChatStateComposingNotif.value = value
					default:
						break
					}
			}
		)
		
		//Remove composingIndicator if "paused" is received
		self.disposer.addDisposable(
			self.xmppClient.stream.incomingMessages
				.toSignalProducer()
				.filter {
					[unowned self] (msg: XMPPMessage) -> Bool in
					return msg.thread() == self.currentThread && msg.hasPausedChatState()
				}
				.map {
					[unowned self] (msg: XMPPMessage) -> Bool in
					return false
				}
				.observeOn(UIScheduler())
				.start {
					[unowned self] event in
					switch event {
					case let .Next(value):
						self.shouldDisplayChatStateComposingNotif.value = value
					default:
						break
					}
			}
		)
		
		//Timeout the shouldDisplayChatStateComposingNotif after 30 seconds
		self.disposer.addDisposable(
			self.shouldDisplayChatStateComposingNotif.producer
				.start {
					[unowned self] event in
					switch event {
					case let .Next(enabled):
						self.cancelComposingTimer() //Want to cancel any current timer in whether the enabled is true or false
						if enabled { //ChatState composing has been setup
							//Setup a new timer to disable typing indicator after 30 seconds
							self.composingNotifTimeout = UIScheduler().toRACScheduler().scheduleAfter(NSDate().dateByAddingTimeInterval(45)) {
								self.shouldDisplayChatStateComposingNotif.value = false
							}
							self.disposer.addDisposable(self.composingNotifTimeout)
						}
					default:
						break
					}
			}
		)
	}
	
	private func setupSendChatStateBindings() {
		//Should we send a chat state composing notification of our own
		self.disposer.addDisposable(
			self.typing.producer
				.filter {
					[unowned self] (typedString: String) in
					//Related to the /command syntax. Don't send chat notifications on slash commands
					return typedString.characters.first == nil ||
						(typedString.characters.first != nil && typedString.characters.first !=  "/")
				}
				.filter {
					[unowned self] _ in
					return self.canSendChatStateComposingNotif == true
				}
				.filter {
					[unowned self] (typedString: String) -> Bool in
					typedString.characters.count > 0
				}
				.on {
					[unowned self] _ in
					self.canSendChatStateComposingNotif = false
				}
				.start {
					[unowned self] event in
					switch event {
					case .Next:
						self.xmppClient.sendChatState("composing", to: self.chattingWith.username, thread: self.currentThread)
					default:
						break
					}
			}
		)
		
		//Disable composingIndicator if have erased our text
		self.disposer.addDisposable(
			self.typing.producer
				.filter {
					[unowned self] _ in
					return self.canSendChatStateComposingNotif == false //We've sent a composing notification
				}
				.filter {
					[unowned self] (typedString: String) -> Bool in
					typedString.characters.count == 0
				}
				.on {
					[unowned self] _ in
					self.canSendChatStateComposingNotif = true
				}
				.start {
					[unowned self] event in
					switch event {
					case .Next:
						self.xmppClient.sendChatState("paused", to: self.chattingWith.username, thread: self.currentThread)
					default:
						break
					}
			}
		)
	}
	
	private func cancelComposingTimer() {
		self.composingNotifTimeout?.dispose()
		self.composingNotifTimeout = nil
	}
	
	func loadMore(count: Int? = nil) {
		if !canLoad || messages.value.count < 1 {
			//Load is in progress
			self.loadingMoreContent.value = false
			return
		}
		
		self.loadingMoreContent.value = true
		canLoad = false
		
		let context: NSManagedObjectContext? = self.xmppClient.stream.xmppMessageArchivingCoreDataStorage.mainThreadManagedObjectContext
		let messageEntity: NSEntityDescription? = NSEntityDescription.entityForName(self.xmppClient.stream.xmppMessageArchivingCoreDataStorage.messageEntityName, inManagedObjectContext: context!)
		let sortDescriptor: NSSortDescriptor = NSSortDescriptor(key: "timestamp", ascending: false)
		
		let fetchRequest = NSFetchRequest()
		let latestDisplayedMessage = messages.value[0]
		let predicate: NSPredicate = NSPredicate(format: "(thread == %@) AND (timestamp < %@)", self.currentThread, latestDisplayedMessage.date)
		fetchRequest.predicate = predicate
		fetchRequest.entity = messageEntity
		fetchRequest.fetchLimit = count != nil ? count! : self.fetchLimit //Should not be smaller than this so that we get a screenful of messages
		fetchRequest.sortDescriptors = [sortDescriptor]
		do {
			let fetchResults = try context!.executeFetchRequest(fetchRequest) as! [XMPPMAMArchivingMessageCoreDataObject]
			if (fetchResults.count > 0) {
				let jsqMessages = fetchResults.map({
					xmppMsg in
					return STMessage.fromStoredMessage(xmppMsg, inConversationWith: self.chattingWith)
				})
				
				var copy = self.messages.value
				for jsqMessage in jsqMessages {
					copy.insert(jsqMessage, atIndex: 0)
				}
				
				//Insert as a single block
				messagesLoadFromDb = true
				messages.value = copy
				self.canLoad = true
			} else {
				let mamSynced = MAMSync.mamSynced(ConversationViewModel.threadId([User.senderId, self.chattingWith.username]))
				if mamSynced != nil {
					NSLog("MAM has been fully synced")
					self.canLoad = false //No need to attempt more loads
					self.loadingMoreContent.value = false
					return
				}
				
				let oldestMessageId = MAMSync.oldestArchiveIdInThread(self.currentThread)
				if oldestMessageId == nil {
					NSLog("Thread has no MAM messages")
					self.canLoad = false //No need to attempt more loads
					self.loadingMoreContent.value = false
					return
				}
				
				//No more messages in coredata, try to load from server
				self.xmppClient.stream.archiveFetcher(self.chattingWith.username, num: self.fetchLimit, before: oldestMessageId)
					.observeOn(UIScheduler())
					.start {
						[weak self] event in
						if self != nil {
							switch event {
							case let .Next(next):
								let (archiveId, _) = next
								self!.canLoad = true
								if (archiveId != nil) {
									MAMSync.setOldestArchiveIdInThread(archiveId!, forThread: ConversationViewModel.threadId([User.senderId, self!.chattingWith.username]))
									//Messages are now in archive, load!
									self!.loadMore()
								} else {
									//Whole MAM has been synced
									MAMSync.setMamSynced(ConversationViewModel.threadId([User.senderId, self!.chattingWith.username]))
									self!.loadingMoreContent.value = false
								}
							default:
								break
							}
						}
				}
			}
		} catch {
			assert(false, "Coredata executeFetchRequest error \(error)")
			self.loadingMoreContent.value = false
			return
		}
	}
	
	private func loadInitialData() {
		let context: NSManagedObjectContext? = self.xmppClient.stream.xmppMessageArchivingCoreDataStorage.mainThreadManagedObjectContext
		let messageEntity: NSEntityDescription? = NSEntityDescription.entityForName(self.xmppClient.stream.xmppMessageArchivingCoreDataStorage.messageEntityName, inManagedObjectContext: context!)
		let sortDescriptor: NSSortDescriptor = NSSortDescriptor(key: "timestamp", ascending: false)
		
		let fetchRequest = NSFetchRequest()
		let predicate: NSPredicate = NSPredicate(format: "thread == %@", self.currentThread)
		fetchRequest.predicate = predicate
		fetchRequest.entity = messageEntity
		fetchRequest.fetchLimit = self.fetchLimit //Should not be smaller than this so that we get a screenful of messages
		fetchRequest.sortDescriptors = [sortDescriptor]
		do {
			let fetchResults = try context!.executeFetchRequest(fetchRequest) as! [XMPPMAMArchivingMessageCoreDataObject]
			let jsqMessages = fetchResults.map({
				archivedMessage in
				return STMessage.fromStoredMessage(archivedMessage, inConversationWith: self.chattingWith)
			})
			
			//NOTE! There's some issue with the following lines! If this NSLog(?!?!) line is not here
			//the self.messagesLoadFromDb = true crashes if built with Release build
			NSLog("Loaded messages thread? \(NSThread.isMainThread())")
			self.messagesLoadFromDb = true
			NSLog("Done")
			messages.value = Array(jsqMessages.reverse())
		} catch {
			assert(false, "Coredata executeFetchRequest error \(error)")
		}
	}
	
	private func deleteLocalMessages(contentType: String, notId: String, deleteOwnOnly: Bool = false) -> [(String, String)] {
		deleteLocalMessagesFromCache(contentType, notId: notId, deleteOwnOnly:  deleteOwnOnly)
		return deleteLocalMessagesFromDb(contentType, notId: notId, deleteOwnOnly: deleteOwnOnly)
	}
	
	private func deleteLocalMessagesFromCache(contentType: String, notId: String, deleteOwnOnly: Bool = false) {
		//Delete from messages
		let keep = self.messages.value.filter { message in
			let keepCondition = message.id == notId || message.attachment == nil || message.attachment!.contentType != contentType
			if deleteOwnOnly {
				return keepCondition || (message.attachment!.contentType == contentType && message.senderId != User.senderId)
			} else {
				return keepCondition
			}
		}
		messagesLoadFromDb = true
		messages.value = keep
	}
	
	private func deleteLocalMessagesFromDb(contentType: String, notId: String, deleteOwnOnly: Bool = false) -> [(String, String)] {
		let context: NSManagedObjectContext? = self.xmppClient.stream.xmppMessageArchivingCoreDataStorage.mainThreadManagedObjectContext
		let messageEntity: NSEntityDescription? = NSEntityDescription.entityForName(self.xmppClient.stream.xmppMessageArchivingCoreDataStorage.messageEntityName, inManagedObjectContext: context!)
		
		let fetchRequest = NSFetchRequest()
		let predicate: NSPredicate?
		if deleteOwnOnly {
			predicate = NSPredicate(format: "contentType == %@ and thread == %@ and id != %@ and senderId == %@", contentType, self.currentThread, notId, User.senderId)
		} else {
			predicate = NSPredicate(format: "contentType == %@ and thread == %@ and id != %@", contentType, self.currentThread, notId)
		}
		
		fetchRequest.predicate = predicate
		fetchRequest.entity = messageEntity
		fetchRequest.returnsObjectsAsFaults = false
		do {
			let fetchResults = try context!.executeFetchRequest(fetchRequest) as! [XMPPMAMArchivingMessageCoreDataObject]
			var archiveIds: [(String, String)] = []
			
			if fetchResults.count > 0 {
				//Delete from DB
				for archivedMessage in fetchResults {
					context?.deleteObject(archivedMessage)
					//COMPILER BUG. Can't array append tuples. Have to do it like this
					//var deletedId = [(archivedMessage.archiveId!, archivedMessage.id)]
					//archiveIds += deletedId
					//assert(archiveIds.count > 0, "archiveIds empty")
					
					if archivedMessage.archiveId != nil {
						archiveIds.append((archivedMessage.archiveId!, archivedMessage.id))
					} else {
						NSLog("Message has no archiveId for some reason! %@", archivedMessage)
					}
				}
				do {
					try context!.save()
				} catch {
					assert(false, "Error saving moc in updateArchiveId \(error)")
				}
			}
			
			return archiveIds
		} catch {
			assert(false, "Coredata executeFetchRequest error \(error)")
		}
		
		return []
	}
	
	private func uploadMedia(media: UIImage, attachmentDesc: STMessageAttachment) {
		let key = ConversationViewModel.mediaKey(attachmentDesc)
		SignalProducer(values: [(media, key)])
			.observeOn(QueueScheduler())
			.flatMap(FlattenStrategy.Merge, transform: {
				[unowned self] (image: UIImage, key: String) -> SignalProducer<(UIImage, String), NSError> in
				return self.scaleImage(image, key:key)
			})
			.flatMap(FlattenStrategy.Merge, transform: {
				[unowned self] (image: UIImage, imageKey: String) -> SignalProducer<Result<Any, NSError>, NSError> in
				return STHttp.putToS3(Configuration.mediaBucket, key: imageKey, image: image)
			})
			.start {
				[unowned self] event in
				switch event {
				case .Next:
					NSLog("PutToS3 success!")
				case .Completed:
					NSLog("PutToS3 completed!")
				case let .Failed(error):
					NSLog("PutToS3 %@", error)
				default:
					break
				}
		}
	}
	
	private func downloadMedia(message: STMessage) -> SignalProducer<Result<(UIImage, String), NSError>, NSError> {
		let key = ConversationViewModel.mediaKey(message.attachment!)
		let thumbKey = ConversationViewModel.thumbnailKey(key)
		return SignalProducer(values: [thumbKey, key])
			.observeOn(QueueScheduler())
			.flatMap(FlattenStrategy.Merge, transform: {
				[unowned self] (key: String) -> SignalProducer<Result<(UIImage, String), NSError>, NSError> in
				return STHttp.getFromS3(Configuration.mediaBucket, key: key)
		})
	}
	
	private func scaleImage(image: UIImage, key: String) -> SignalProducer<(UIImage, String), NSError> {
		return SignalProducer { [unowned self] observer, disposable in
			//https://blog.bufferapp.com/ideal-image-sizes-social-media-posts
			let thumbSize = 256
			let thumbKey = ConversationViewModel.thumbnailKey(key)
			let thumbNail = Toucan(image: image).resize(CGSize(width: thumbSize, height: thumbSize), fitMode: Toucan.Resize.FitMode.Clip).image
			observer.sendNext((thumbNail, thumbKey))
			
			let imageSize = 1024
			let scaledImage = Toucan(image: image).resize(CGSize(width: imageSize, height: imageSize), fitMode: Toucan.Resize.FitMode.Clip).image
			observer.sendNext((scaledImage, key))
			observer.sendCompleted()
		}
	}
	
	static func mediaKey(attachmentDesc: STMessageAttachment) -> String {
		var json: JSON = attachmentDesc.json
		return json["id"].string!
	}
	
	static func thumbnailKey(key: String) -> String {
		return key.stringByReplacingOccurrencesOfString(STMessage.imageExt, withString: "_thumbnail\(STMessage.imageExt)")
	}
	
	private func reloadMsgView(message: STMessage) {
		//Notify the viewController that a message contents have changed and it's collectionView should be reloaded
		let reloadIndex = (messages.value).indexOf(message)
		self.reloadMesssage.value = reloadIndex
	}
	
	private func isDuplicate(message: STMessage) -> Bool {
		let index = self.messages.value.indexOf { (existingMessage: STMessage) -> Bool in
			existingMessage.id == message.id
		}
		
		return index != nil
	}
	
	static func threadId(participants: [String]) -> String {
		return participants.sort { (userId1, userId2) in userId1 < userId2 }.reduce("", combine: {
			(ret, element) in
			if ret == "" {
				return element
			}
			
			return "\(ret)-\(element)"
		})
	}
}
