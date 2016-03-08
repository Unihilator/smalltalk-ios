//
//  XMPPStream.swift
//  smalltalk
//
//  Created by Mikko Hämäläinen on 16/09/15.
//  Copyright (c) 2015 Mikko Hämäläinen. All rights reserved.
//

import Foundation
import XMPPFramework
import Reachability
import ReactiveCocoa

//https://github.com/ChatSecure/ChatSecure-iOS/blob/develop/ChatSecure/Classes/Controllers/XMPP/OTRXMPPManager.m
class STXMPPStream: NSObject, XMPPRosterDelegate, XMPPvCardTempModuleDelegate, XMPPvCardAvatarDelegate, XMPPMessageCarbonsDelegate, XMPPStreamManagementDelegate {
	enum XMPPError: Int {
		case AuthFailed = -1
		case Disconnected = -2
	}
	
	private let stream: XMPPStream
	private let xmppHandlingQ: dispatch_queue_t = dispatch_queue_create("XMPP Handling", nil)
	private var password: String!
	private var reachability: Reachability!
	
	private var reconnect: XMPPReconnect!
	private var deliveryReceipts: XMPPMessageDeliveryReceipts!
	private var xmppRoster: XMPPRoster!
	private var xmppVCardTemp: XMPPvCardTempModule!
	private var xmppVCardAvatar: XMPPvCardAvatarModule!
	private var messageCarbons: XMPPMessageCarbons!
	private var streamManagement: XMPPStreamManagement!
	private var xmppMessageArchivingModule: XMPPMAMArchiving!
	
	var xmppMessageArchivingCoreDataStorage: XMPPMAMArchivingCoreDataStorage!
	
	//https://github.com/ohwutup/ProximityManager/blob/master/ProximityManager/Managers/LocationManager.swift
	//We don't use Event<Bool, NSError> because changes in connection status are not Signal Errors that should
	//behave like exceptions skipping and terminating operators https://github.com/ReactiveCocoa/ReactiveCocoa/blob/master/Documentation/DesignGuidelines.md
	var connectionStatus: Signal<(Bool, NSError?), NSError>
	private var connectionStatusObserver: Observer<(Bool, NSError?), NSError>
	var incomingMessages: Signal<XMPPMessage, NoError>
	private var incomingMessagesObserver: Observer<XMPPMessage, NoError>
	var incomingReceipts: Signal<(String, STMessage.DeliveryStatus), NoError>
	private var incomingReceiptsObserver: Observer<(String, STMessage.DeliveryStatus), NoError>
	var incomingVCards: Signal<(username: String, vcard: XMPPvCardTemp), NoError>
	private var incomingVCardsObserver: Observer<(username: String, vcard: XMPPvCardTemp), NoError>
	var sentMessages: Signal<XMPPMessage, NoError>
	private var sentMessagesObserver: Observer<XMPPMessage, NoError>
	
	//Pending sent messages
	private var pendingMessages: [String: (Observer<Bool, NSError>, XMPPMessage)] = [:] //String : (Observer, Message)
	//Pending archive requests
	private var pendingArchiveFetches: [String: (Observer<(String?, String), NSError>, String)] = [:] //String : (Observer, ContactId)

    //Buffer for messages that should be sent on reconnect
    private var outboundMessageBuffer: [DDXMLElement] = []
    
	let connected = MutableProperty<Bool>(false)

	override init() {
		self.stream = XMPPStream()
		//Create the signal we will communicate connectionstatus over
		(self.connectionStatus, self.connectionStatusObserver) = Signal<(Bool, NSError?), NSError>.pipe()
		(self.incomingMessages, self.incomingMessagesObserver) = Signal<XMPPMessage, NoError>.pipe()
		(self.incomingReceipts, self.incomingReceiptsObserver) = Signal<(String, STMessage.DeliveryStatus), NoError>.pipe()
		(self.incomingVCards, self.incomingVCardsObserver) = Signal<(username: String, vcard: XMPPvCardTemp), NoError>.pipe()
		(self.sentMessages, self.sentMessagesObserver) = Signal<XMPPMessage, NoError>.pipe()
		super.init()

		/*
		//This is how you can observe application going to background (and send unavailable)
		//https://github.com/s0mmer/TodaysReactiveMenu/blob/master/TodaysReactiveMenu/ViewModel/TodaysMenuViewModel.swift
		let inactive = NSNotificationCenter.defaultCenter().rac_addObserverForName(UIApplicationWillResignActiveNotification, object: nil).toSignalProducer()
		|> ignoreError
		|> map { _ in
		false
		}
*/
	}
	
	deinit {
		self.sendOrBufferElement(XMPPPresence(type: "unavailable"))
		self.cleanUp()
	}
	
	func disconnect() {
		self.stream.disconnect()
		self.cleanUp()
		self.connected.value = false
	}
	
	func cleanUp()
	{
		self.stream.removeDelegate(self)
		self.xmppRoster.removeDelegate(self)
		self.xmppVCardTemp.removeDelegate(self)
		self.xmppVCardAvatar.removeDelegate(self)
		self.messageCarbons.removeDelegate(self)
		self.streamManagement.removeDelegate(self)
		self.xmppMessageArchivingModule.removeDelegate(self)
		self.reconnect.deactivate()
		self.deliveryReceipts.deactivate()
		self.xmppRoster.deactivate()
		self.xmppVCardTemp.deactivate()
		self.xmppVCardAvatar.deactivate()
		self.messageCarbons.deactivate()
		self.streamManagement.deactivate()
		self.xmppMessageArchivingModule.deactivate()
	}
	
	//http://stackoverflow.com/questions/17876421/xmppframework-tls-ssl-connection-with-openfire
	//http://stackoverflow.com/questions/23775801/xmpp-connection-time-optimization
	func connectToHost(host: String, port: UInt16, username: String, password: String) {
		assert(self.reconnect == nil, "Method connectToHost invoked multiple times")
		NSLog("connectToHost \(host) \(username) \(password)")
		self.setupReachability(host)
		self.password = password
		self.stream.addDelegate(self, delegateQueue: xmppHandlingQ) //All operations happen in background thread
		self.stream.hostName = host
		self.stream.hostPort = port
		self.stream.myJID = XMPPJID.jidWithUser(username, domain: "smalltalk.com", resource: "app")
		self.stream.keepAliveInterval = 30
		//https://github.com/robbiehanson/XMPPFramework/blob/master/Extensions/XEP-0198/XMPPStreamManagement.h
		
		self.stream.startTLSPolicy = XMPPStreamStartTLSPolicy.Required

		self.reconnect = XMPPReconnect(dispatchQueue: xmppHandlingQ)
		self.reconnect.reconnectTimerInterval = NSTimeInterval(10 + Int(arc4random_uniform(15))) //If reconnect fails, the next test is in 10-25 seconds (random value so that we don't get a thundering herd problem)
		self.reconnect.activate(self.stream)
		
		//TODO! May have to have XMPPCapabilities enabled or undefine (see XMPPMessageDeliveryReceipts.m) _XMPP_CAPABILITIES_H
		//http://stackoverflow.com/questions/25887754/cant-get-message-delivery-receipt-in-xmpp
		self.deliveryReceipts = XMPPMessageDeliveryReceipts()
		self.deliveryReceipts.autoSendMessageDeliveryReceipts = true
		self.deliveryReceipts.autoSendMessageDeliveryRequests = true
		self.deliveryReceipts.activate(self.stream)
		
		//https://github.com/robbiehanson/XMPPFramework/wiki/XMPP_CoreData
		//https://github.com/yapstudios/YapDatabase - Another option
		let coredataRosterStorage: XMPPRosterCoreDataStorage = XMPPRosterCoreDataStorage(databaseFilename: "XMPPRoster-\(username).sqlite", storeOptions: nil)
		self.xmppRoster = XMPPRoster(rosterStorage: coredataRosterStorage, dispatchQueue: xmppHandlingQ)
		self.xmppRoster.autoFetchRoster = true
		self.xmppRoster.autoClearAllUsersAndResources = false
		self.xmppRoster.autoAcceptKnownPresenceSubscriptionRequests = true
		self.xmppRoster.activate(self.stream)
		self.xmppRoster.addDelegate(self, delegateQueue: xmppHandlingQ)

		// The XMPPRoster will automatically integrate with XMPPvCardAvatarModule to cache roster photos in the roster.
		let coredataVCardStorage: XMPPvCardCoreDataStorage = XMPPvCardCoreDataStorage(databaseFilename: "VCard-\(username).sqlite", storeOptions: nil)
		self.xmppVCardTemp = XMPPvCardTempModule(withvCardStorage: coredataVCardStorage, dispatchQueue: xmppHandlingQ)
		self.xmppVCardAvatar = XMPPvCardAvatarModule(withvCardTempModule: self.xmppVCardTemp, dispatchQueue: xmppHandlingQ)
		self.xmppVCardTemp.activate(self.stream)
		self.xmppVCardTemp.addDelegate(self, delegateQueue: xmppHandlingQ)
		self.xmppVCardAvatar.activate(self.stream)
		self.xmppVCardAvatar.addDelegate(self, delegateQueue: xmppHandlingQ)
		
		// Message Carbons
		self.messageCarbons = XMPPMessageCarbons(dispatchQueue: xmppHandlingQ)
		self.messageCarbons.activate(self.stream)
		self.messageCarbons.addDelegate(self, delegateQueue: xmppHandlingQ)
		
		//Stream management
		let coredataStreamManagementStorage: XMPPStreamManagementStorage = XMPPStreamManagementMemoryStorage()
		self.streamManagement = XMPPStreamManagement(storage: coredataStreamManagementStorage, dispatchQueue: xmppHandlingQ)
		self.streamManagement.automaticallyRequestAcksAfterStanzaCount(1, orTimeout: 60)
		self.streamManagement.automaticallySendAcksAfterStanzaCount(1, orTimeout: 60)
		self.streamManagement.autoResume = true
		self.streamManagement.activate(self.stream)
		self.streamManagement.addDelegate(self, delegateQueue: xmppHandlingQ)

		//MAM
		self.xmppMessageArchivingCoreDataStorage = XMPPMAMArchivingCoreDataStorage(databaseFilename: "Messages-\(username).sqlite", storeOptions: nil)
		self.xmppMessageArchivingModule = XMPPMAMArchiving(messageArchivingStorage: xmppMessageArchivingCoreDataStorage, dispatchQueue: xmppHandlingQ) //[[XMPPMessageArchiving alloc]initWithMessageArchivingStorage:xmppMessageArchivingCoreDataStorage];
		self.xmppMessageArchivingModule.activate(self.stream)
		self.xmppMessageArchivingModule.addDelegate(self, delegateQueue: xmppHandlingQ)
		
		//Last activity - http://www.xmpp.org/extensions/xep-0012.html
		
        self.setupBindings()
        
		//TODO Move this to async queue?
		do {
			try self.stream.connectWithTimeout(15)
		} catch {
			NSLog("XMPP error connecting \(error)")
			self.connectionStatusObserver.sendFailed(error as NSError) //NSError(domain: "Smalltalk", code: -1, userInfo: [NSLocalizedDescriptionKey : "Error \(error) occurred"]))
		}
	}
    
    private func setupBindings() {
        //Wait for the connection to be established and send messages that have been buffered
        self.connected.producer
		.filter { $0 == true }
		.start {
			event in
			switch event {
			case .Next:
                NSLog("Send buffered messages")
                for message in self.outboundMessageBuffer {
                    self.sendOrBufferElement(message)
                }
                
                self.outboundMessageBuffer = []
			default:
				assert(false, "self.connected.producer default")
			}
		}
    }
	
	func sendUnavailable()
	{
		self.sendOrBufferElement(XMPPPresence(type: "unavailable"))
	}
	
	func sendAvailable()
	{
		self.sendOrBufferElement(XMPPPresence(type: "available"))
	}
	
	//mark - xmppStream setup
	func xmppStream(sender: XMPPStream, willSecureWithSettings settings: NSMutableDictionary) {
		NSLog("willSecureWithSettings")
	}
	
	/*
	* This is only called if the stream is secured with settings that include:
	* - GCDAsyncSocketManuallyEvaluateTrust == YES
	* That is, if a delegate implements xmppStream:willSecureWithSettings:, and plugs in that key/value pair.
	*/
	func xmppStream(sender: XMPPStream, didReceiveTrust trust: SecTrustRef, completionHandler handler: (Bool) -> (Void)) {
		NSLog("didReceiveTrust")
		
		////http://stackoverflow.com/questions/24298917/xmppframework-connect-via-ssl-on-openfire
		/* Custom validation for your certificate on server should be performed */
		handler(true) // // After this line, SSL connection will be established
	}

	func xmppStreamDidSecure(sender: XMPPStream) {
		NSLog("xmppStreamDidSecure")

	}

	func xmppStreamDidConnect(sender: XMPPStream) {
		NSLog("xmppStremDidConnect Main Thread? \(NSThread.isMainThread())")
		do {
			try self.stream.authenticateWithPassword(self.password)
		} catch {
			NSLog("XMPP authentication error \(error)")
			self.connectionStatusObserver.sendFailed(error as NSError)
		}
	}
	
	func xmppStreamDidDisconnect(sender: XMPPStream, withError error: NSError?) {
		NSLog("xmppStreamDidDisconnect \(error)")
		var e = error
		if (error == nil) {
			e = NSError(domain: "smalltalk.xmpp", code: XMPPError.Disconnected.rawValue, userInfo: [NSLocalizedDescriptionKey : "Connection timeout"])
		}
		
		self.connectionStatusObserver.sendFailed(e!)
		self.connected.value = false
	}
	
	func xmppStreamDidAuthenticate(sender: XMPPStream) {
		NSLog("xmppStreamDidAuthenticate Main Thread? \(NSThread.isMainThread())")
		self.connectionStatusObserver.sendNext((true, nil))
		self.connected.value = true
        self.sendOrBufferElement(XMPPPresence(type: "available"))
		//Turn on stream management
		self.streamManagement.enableStreamManagementWithResumption(true, maxTimeout: 600)
	}
	
	func xmppStream(sender: XMPPStream, didNotAuthenticate auth:DDXMLElement) {
		NSLog("Did not authenticate \(auth)")
		self.connectionStatusObserver.sendFailed(NSError(domain: "smalltalk.xmpp", code: XMPPError.AuthFailed.rawValue as Int, userInfo: ["info" : auth]))
		self.connected.value = false
	}
	
	//mark - message sending & receiving
	
	func xmppStream(sender: XMPPStream, didReceiveMessage message:XMPPMessage) {
		NSLog("didReceiveMessage %@", message)
		var receipt: NSArray? = nil
		do {
			 receipt = try message.nodesForXPath("/*[local-name()='message']/*[local-name()='receipt']")
		} catch {
			assert(false, "XPath parse failed \(error)")
		}
		
		if receipt != nil && receipt!.count > 0 {
			//Read receipt
			NSLog("SOME? receipt received. Handle!")
			assert(false, "SOME? receipt received. Handle!")
		} else if message.hasReceiptResponse() {
			//Received
			let messageId = message.receiptResponseID()
			self.incomingReceiptsObserver.sendNext((messageId, STMessage.DeliveryStatus.Delivered))
			self.xmppMessageArchivingCoreDataStorage.markMessageDeliveryStatus(STMessage.DeliveryStatus.Delivered, forMessage: messageId)
		} else {
			//We don't pass messages from archive to incomingMessagesObserver (only new messages go there)
			//they are written to local DB and read from there when needed
			let wasMsgFromArchive = self.storeAchiveResult(sender, message: message)
			if !wasMsgFromArchive {
				self.incomingMessagesObserver.sendNext(message)
			}
		}
	}
	
	//Handle push notification message payload as if it was received from the network so that it is immediately visible in UI when user comes back
	//it is at that point received from offline storage as well
	func receiveMessageFromPushNotification(messageStr: String) {
		CLS_LOG_SWIFT("STXMPPStream: receiveMessageFromPushNotification %@", [messageStr])
		do {
			//Remove the lang attribute that is not used and causes the DDXML parser to crash
			let pattern = "xml:lang='.*?'"
			let regex: NSRegularExpression = try NSRegularExpression(pattern: pattern, options: NSRegularExpressionOptions.CaseInsensitive)
			let modString = regex.stringByReplacingMatchesInString(messageStr, options: .WithTransparentBounds, range: NSMakeRange(0, messageStr.characters.count), withTemplate: "")
			CLS_LOG_SWIFT("STXMPPStream: modString after stringByReplacingMatchesInString %@", [modString])
			let message = try XMPPMessage(XMLString: modString)
			//Archive and receive
			CLS_LOG_SWIFT("STXMPPStream: messageParsed")
			self.xmppMessageArchivingCoreDataStorage.archiveMessage(message, outgoing: isOutgoingMsg(message), xmppStream: stream)
			CLS_LOG_SWIFT("STXMPPStream: archiveMessage done")
			self.xmppStream(stream, didReceiveMessage: message)
			CLS_LOG_SWIFT("STXMPPStream: didReceiveMessage done")
		} catch {
			CLS_LOG_SWIFT("STXMPPStream: failed to do regex or parse as XML %@", [error as NSError])
			assert(false, "\(error) failed to do regex or parse as XML")
		}
	}
	
	func storeAchiveResult(sender: XMPPStream,  message:XMPPMessage) -> Bool {
		//Have to use the crazy local-name() crap because the message has namespace
		//-> /message/result/forwarded/message
		do {
			let res = try message.nodesForXPath("/*[local-name()='message']/*[local-name()='result']/*[local-name()='forwarded']/*[local-name()='message']")
			if res.count > 0 {
				let xmppMsg = XMPPMessage(fromElement: res[0] as! DDXMLElement)
				let delayQ = try message.nodesForXPath("/*[local-name()='message']/*[local-name()='result']/*[local-name()='forwarded']/*[local-name()='delay']")
				let delay = XMPPMessage(fromElement: delayQ[0] as! DDXMLElement) //The correct from value is in the delay element for some reason
                //From may be null in the actual message for some reason
				xmppMsg.addAttributeWithName("from", stringValue: delay.attributeStringValueForName("from"))
				//Add the delay to the message as well so that it has timestamp
				xmppMsg.addChild(delay.copy() as! DDXMLNode)
                
                //Add the archived to the message so that it is similar to messages coming from network
                let result = message.elementForName("result")
                let archived = DDXMLElement(name: "archived")
                archived.addAttributeWithName("id", stringValue: result.attributeStringValueForName("id"))
                xmppMsg.addChild(archived)
                
				self.xmppMessageArchivingCoreDataStorage.archiveMessage(xmppMsg, outgoing: isOutgoingMsg(xmppMsg), xmppStream: sender)
				return true
			}
		} catch {
			NSLog("MAM Error \(error)")
		}
		
		return false
	}
	
	func isOutgoingMsg(msg: XMPPMessage) -> Bool {
		return msg.from().user == User.senderId
	}
    
    private func sendOrBufferElement(message: DDXMLElement) {
        if self.connected.value {
            self.stream.sendElement(message)
        } else {
            self.outboundMessageBuffer.append(message)
        }
    }
	
	//https://github.com/ReactiveCocoa/ReactiveCocoa/issues/2103
	func messageSender(id: String, body: String, to: String, thread: String, content: STMessageAttachment?) -> SignalProducer<Bool, NSError> {
		let producer: SignalProducer<Bool, NSError> = SignalProducer { [weak self] observer, disposable in
			NSLog("messageSender executed")
			let jid = XMPPJID.jidWithUser(to, domain: "smalltalk.com", resource: "/")
			let message: XMPPMessage = XMPPMessage(type: "chat", to: jid)
			message.addChild(DDXMLNode.elementWithName("body", stringValue: body) as! DDXMLNode)
			message.addThread(thread)
			message.addAttributeWithName("id", stringValue: id)
			//From is not required to send a message but we add it here so that when we handle it in didSendMessage
			//it is available
			message.addAttributeWithName("from", stringValue: self!.stream.myJID.full())
			message.addAttributeWithName("fromName", stringValue: User.displayName!)
			
			if content != nil {
				let contentE = DDXMLElement(name: "content", stringValue: content!.jsonRawString)
				contentE.addAttributeWithName("content-type", stringValue: content!.contentType)
				message.addChild(contentE)
			}
            
            //Save observer so that we can communicate though it when the delegate is called
            self?.pendingMessages[id] = (observer, message)
            self?.sendOrBufferElement(message)
		}
		
		return  producer
	}
	
	func chatStateSender(type: String, to: String, thread: String) -> SignalProducer<Bool, NSError> {
		let producer: SignalProducer<Bool, NSError> = SignalProducer { [weak self] observer, disposable in
			NSLog("chatStateSender executed")
			let jid = XMPPJID.jidWithUser(to, domain: "smalltalk.com", resource: "/")
			let message: XMPPMessage = XMPPMessage(type: "chat", to: jid)
			if type == "composing" {
				message.addComposingChatState()
			} else if type == "paused" {
				message.addPausedChatState()
			}
			message.addThread(thread)
			//From is not required to send a message but we add it here so that when we handle it in didSendMessage
			//it is available
			message.addAttributeWithName("from", stringValue: self!.stream.myJID.full())
			self?.sendOrBufferElement(message)
		}
		
		return  producer
	}
	
	func xmppStream(sender: XMPPStream, didSendMessage message:XMPPMessage) {
		NSLog("didSendMessage %@", message)

	}
	
	func xmppStream(sender: XMPPStream, didFailToSendMessage message:XMPPMessage, error e: NSError) {
		NSLog("didFailToSendMessage %@ %@", message, e)
		//TODO! Do not use message.body() as key!
		let id = message.attributeStringValueForName("id")
		if id != nil, let (pendingObserver, _) = self.pendingMessages[id] {
			pendingObserver.sendFailed(e)
			self.pendingMessages.removeValueForKey(id)
		}
	}
	
	func xmppStream(sender: XMPPStream, didReceiveIQ iq:XMPPIQ) {
		NSLog("didReceiveIQ %@", iq)
		//End of MAM search
		handleMessageArchivedReply(iq)
		handleArchiveQueryResult(iq)
	}
	
	func xmppStream(sender: XMPPStream, didReceivePresence presence:XMPPPresence) {
		NSLog("didReceivePresence %@", presence)
	}

	func xmppStream(sender: XMPPStream, didReceiveError error:DDXMLElement) {
		NSLog("didReceiveError %@", error)
	}
	
	func archiveFetcher(contact: String, num: Int, before: String? = nil) -> SignalProducer<(String?, String), NSError> {
		let producer: SignalProducer<(String?, String), NSError> = SignalProducer { [weak self] observer, disposable in
			let iq: XMPPIQ = XMPPIQ()
			iq.addAttributeWithName("type", stringValue: "get")
			let id = "archive-fetch-\(contact)"
			iq.addAttributeWithName("id", stringValue: id)
			let query: DDXMLElement = DDXMLElement(name: "query", xmlns: "urn:xmpp:mam:tmp")
			query.addAttributeWithName("queryid", stringValue: "archive-fetch-q-\(contact)")
			let with = DDXMLElement(name: "with", stringValue: "\(contact)@smalltalk.com")
			query.addChild(with)
			//http://stackoverflow.com/questions/31828955/xmpp-query-archive-by-latest-messages
			let set: DDXMLElement = DDXMLElement(name: "set", xmlns: "http://jabber.org/protocol/rsm")
			let max: DDXMLElement = DDXMLElement(name: "max", numberValue: num)
			
			var beforeElem: DDXMLElement
			if before != nil {
				beforeElem = DDXMLElement(name: "before", stringValue: before)
			} else {
				beforeElem = DDXMLElement(name: "before") //Fetch the latest
			}
			
			set.addChild(max)
			set.addChild(beforeElem)
			query.addChild(set)
			iq.addChild(query)
			
			self?.pendingArchiveFetches[id] = (observer, contact)
			self?.sendOrBufferElement(iq)
		}
		
		return  producer
	}
	
	func purgeFromMAM(archiveIds : [String]) {
		for archiveId in archiveIds {
			let iq: XMPPIQ = XMPPIQ()
			iq.addAttributeWithName("type", stringValue: "set")
			let id = "archive-purge-\(archiveId)"
			iq.addAttributeWithName("id", stringValue: id)
			let purge: DDXMLElement = DDXMLElement(name: "purge", xmlns: "urn:smalltalk:mam")
			purge.addAttributeWithName("id", stringValue: archiveId)
			iq.addChild(purge)
			NSLog("Send purge \(iq)")
			self.sendOrBufferElement(iq)
		}
	}
	
	//Message has been archived by MAM, we'll update the archive id in local db
	func handleMessageArchivedReply(iq: XMPPIQ) {
		if iq.xmlns() != "urn:smalltalk:archived" {
			return
		}
		
		do {
			let res = try iq.nodesForXPath("/*[local-name()='iq']/*[local-name()='archived']")
			if res.count > 0 {
				let archived = res[0] as! DDXMLElement
				let messageId = archived.attributeStringValueForName("id")
				let archivedId = archived.attributeStringValueForName("archiveId")
				self.xmppMessageArchivingCoreDataStorage.updateArchiveId(messageId, archiveId: archivedId)
			}
		} catch {
			NSLog("handleMessageArchivedReply error \(error)")
		}
	}
	
	func handleArchiveQueryResult(iq: XMPPIQ) {
		do {
			let res = try iq.nodesForXPath("/*[local-name()='iq']/*[local-name()='query']")
			if res.count > 0 {
				let query = res[0] as! DDXMLElement
				if query.xmlns() == "urn:xmpp:mam:tmp" {
					let id = iq.attributeStringValueForName("id")
					if id != nil, let (pendingObserver, contact) = self.pendingArchiveFetches[id] {
						do {
							let archiveQuery = try iq.nodesForXPath("/*[local-name()='iq']/*[local-name()='query']/*[local-name()='set']/*[local-name()='first']")
							if archiveQuery.count > 0 {
								let archiveId = archiveQuery[0] as! DDXMLElement
								pendingObserver.sendNext((archiveId.stringValue(), contact))
							} else {
								pendingObserver.sendNext((nil, contact))
							}
							pendingObserver.sendCompleted()
							self.pendingArchiveFetches.removeValueForKey(id)
						} catch {
							NSLog("MAM query result IQ error \(error)")
						}
					}
				}
			}
		} catch {
			NSLog("MAM query result IQ error \(error)")
		}
	}
	
	//mark - XMPPRosterDelegate

	/**
	* Sent when a presence subscription request is received.
	* That is, another user has added you to their roster,
	* and is requesting permission to receive presence broadcasts that you send.
	*
	* The entire presence packet is provided for proper extensibility.
	* You can use [presence from] to get the JID of the user who sent the request.
	*
	* The methods acceptPresenceSubscriptionRequestFrom: and rejectPresenceSubscriptionRequestFrom: can
	* be used to respond to the request.
	**/
	func xmppRoster(sender: XMPPRoster!, didReceivePresenceSubscriptionRequest presence: XMPPPresence!) {
		NSLog("didReceivePresenceSubscriptionRequest \(presence)")

	}

	/**
	* Sent when a Roster Push is received as specified in Section 2.1.6 of RFC 6121.
	**/
	func xmppRoster(sender: XMPPRoster!, didReceiveRosterPush iq: XMPPIQ!) {
		NSLog("didReceiveRosterPush \(iq)")
	}
	
	/**
	* Sent when the initial roster is received.
	**/
	func xmppRosterDidBeginPopulating(sender: XMPPRoster!, withVersion version: String!) {
		NSLog("xmppRosterDidBeginPopulating \(version)")
	}
	
	/**
	* Sent when the initial roster has been populated into storage.
	**/
	func xmppRosterDidEndPopulating(sender: XMPPRoster!) {
		NSLog("xmppRosterDidEndPopulating")
	}
	
	/**
	* Sent when the roster receives a roster item.
	*
	* Example:
	*
	* <item jid='romeo@example.net' name='Romeo' subscription='both'>
	*   <group>Friends</group>
	* </item>
	**/
	func xmppRoster(sender: XMPPRoster!, didReceiveRosterItem item: DDXMLElement!) {
		NSLog("didReceiveRosterItem \(item)")
	}

	//mark - Vcard
	
	func updateVCard(nickname: String) {
		//Doesn't work in swift2
		//let vcard = XMPPvCardTemp.vCardTemp()
		let vCardTempElement = DDXMLElement(name: "vCard", xmlns: "vcard-temp")
		let vcard = XMPPvCardTemp(fromElement: vCardTempElement)  //XMPPvCardTemp.vCardTempFromElement(vCardTempElement)
		vcard.nickname = nickname
		self.xmppVCardTemp.updateMyvCardTemp(vcard)
	}

	func fetchVCard(user: String) -> XMPPvCardTemp? {
		let jid = XMPPJID.jidWithUser(user, domain: "smalltalk.com", resource: nil)
		return self.xmppVCardTemp.vCardTempForJID(jid, shouldFetch: true)
	}
	
	func xmppvCardTempModule(vCardTempModule: XMPPvCardTempModule!, didReceivevCardTemp vCardTemp: XMPPvCardTemp!, forJID jid: XMPPJID!) {
		NSLog("didReceivevCardTemp \(vCardTemp) \(jid)")
		if jid.user != nil {
			incomingVCardsObserver.sendNext((username: jid.user, vcard: vCardTemp))
		}
	}
	
	func xmppvCardTempModuleDidUpdateMyvCard(vCardTempModule: XMPPvCardTempModule!) {
		NSLog("xmppvCardTempModuleDidUpdateMyvCard")
	}
	
	func xmppvCardTempModule(vCardTempModule: XMPPvCardTempModule!, failedToUpdateMyvCard error: DDXMLElement!) {
		NSLog("xmppvCardTempModule \(error)")
	}
	
	func xmppvCardAvatarModule(vCardTempModule: XMPPvCardAvatarModule!, didReceivePhoto photo: UIImage!, forJID jid: XMPPJID!) {
		NSLog("didReceivePhoto for \(jid)")
	}
	
	//mark - message carbons

	func xmppMessageCarbons(xmppMessageCarbons: XMPPMessageCarbons!, didReceiveMessage message: XMPPMessage!, outgoing isOutgoing: Bool) {
		NSLog("didReceiveMessage for \(message) outgoing? \(isOutgoing)")
	}
	
	func xmppMessageCarbons(xmppMessageCarbons: XMPPMessageCarbons!, willReceiveMessage message: XMPPMessage!, outgoing isOutgoing: Bool) {
		NSLog("willReceiveMessage for \(message) outgoing? \(isOutgoing)")
	}
	
	//mark - stream management
	/**
	* Notifies delegates of the server's response from sending the <enable> stanza.
	**/
	func xmppStreamManagement(sender: XMPPStreamManagement!, wasEnabled enabled: DDXMLElement!) {
		NSLog("xmppStreamManagement wasEnabled \(enabled)")
	}
	
	func xmppStreamManagement(sender: XMPPStreamManagement!, wasNotEnabled failed: DDXMLElement!) {
		NSLog("xmppStreamManagement wasNotEnabled \(failed)")
	}
	
	/**
	* Notifies delegates that a request <r/> for an ack from the server was sent.
	**/
	func xmppStreamManagementDidRequestAck(sender: XMPPStreamManagement!) {
		NSLog("xmppStreamManagementDidRequestAck")
	}
	
	/**
	* Invoked when an ack is received from the server, and new stanzas have been acked.
	**/
	func xmppStreamManagement(sender: XMPPStreamManagement!, didReceiveAckForStanzaIds stanzaIds: [AnyObject]!) {
		NSLog("xmppStreamManagement didReceiveAckForStanzaIds \(stanzaIds)")
		//TODO message sender's complete should be called here to make sure that the message has reached the server
        
        for id in stanzaIds as! [String] {
            //Message is not necessarily in pendingMessages if it is an automatic system generated message like read receipt
            if let (pendingObserver, pendingMessage) = self.pendingMessages[id] {
                //Message has been sent
                sentMessagesObserver.sendNext(pendingMessage)
                pendingObserver.sendCompleted()
                self.pendingMessages.removeValueForKey(id)
                //Mark deliveryStatus
                self.incomingReceiptsObserver.sendNext((id, STMessage.DeliveryStatus.ServerAck))
                self.xmppMessageArchivingCoreDataStorage.markMessageDeliveryStatus(STMessage.DeliveryStatus.ServerAck, forMessage: id)
            }
        }
	}

	/**
	* It's critically important to understand what an ACK means.
	*
	* Every ACK contains an 'h' attribute, which stands for "handled".
	* To paraphrase XEP-0198 (in client-side terminology):
	*
	*   Acknowledging a previously ­received element indicates that the stanza has been "handled" by the client.
	*   By "handled" we mean that the client has successfully processed the stanza
	*   (including possibly saving the item to the database if needed);
	*   Until a stanza has been affirmed as handled by the client, that stanza is the responsibility of the server
	*   (e.g., to resend it or generate an error if it is never affirmed as handled by the client).
	*
	* This means that if your processing of certain elements includes saving them to a database,
	* then you should not mark those elements as handled until after your database has confirmed the data is on disk.
	*
	* You should note that this is a critical component of any networking app that claims to have "reliable messaging".
	*
	* By default, all elements will be marked as handled as soon as they arrive.
	* You'll want to override the default behavior for important elements that require proper handling by your app.
	* For example, messages that need to be saved to the database.
	* Here's how to do so:
	*
	* - Implement the delegate method xmppStreamManagement:getIsHandled:stanzaId:forReceivedElement:
	*
	*   This method is invoked for all received elements.
	*   You can inspect the element, and if it is important and requires special handling by the app,
	*   then flag the element as NOT handled (overriding the default).
	*   Also assign the element a "stanzaId". This can be anything you want, such as the elementID,
	*   or maybe something more app-specific (e.g. something you already use that's associated with the message).
	*
	* - Handle the important element however you need to
	*
	*   If you're saving something to the database,
	*   then wait until after the database commit has completed successfully.
	*
	* - Notify the module that the element has been handled via the method markHandledStanzaId:
	*
	*   You must pass the stanzaId that you returned from this delegate method.
	*
	*
	* @see markHandledStanzaId:
	**/
	//func xmppStreamManagement(sender: XMPPStreamManagement!, getIsHandled isHandledPtr: UnsafeMutablePointer<ObjCBool>, stanzaId stanzaIdPtr: AutoreleasingUnsafeMutablePointer<AnyObject?>, forReceivedElement element: XMPPElement!) {
	//	NSLog("xmppStreamManagement getIsHandled \(stanzaIdPtr)")
	//	//Here we could make sure that the stanza has been written to DB
	//	sender.markHandledStanzaId(stanzaIdPtr)
	//}

	// Private functions

	private func setupReachability(host: String) {
		self.reachability = Reachability(hostName: host)
		self.reachability.reachableBlock = {
			reachable in
			dispatch_async(dispatch_get_main_queue(), {
				NSLog("REACHABLE! \(reachable)");
				self.reconnect.manualStart() //Manually reconnect on reachability change
			})
		}
		self.reachability.unreachableBlock = {
			reachable in
			dispatch_async(dispatch_get_main_queue(), {
				NSLog("UNREACHABLE! \(reachable)");
			})
		}
		self.reachability.startNotifier()
	}
}
