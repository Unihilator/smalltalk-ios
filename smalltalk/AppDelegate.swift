//
//  AppDelegate.swift
//  smalltalk
//
//  Created by Mikko Hämäläinen on 30/08/15.
//  Copyright (c) 2015 Mikko Hämäläinen. All rights reserved.
//

import UIKit
import XMPPFramework
import Fabric
import Crashlytics
import DigitsKit
import ReactiveCocoa
import OpenUDID
import TSMessages
import DeepLinkKit
import ChameleonFramework
import youtube_ios_player_helper
import Watchdog

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?
	lazy var router: DPLDeepLinkRouter = DPLDeepLinkRouter()
	var globalColor: UIColor?
	var backgroundColor: UIColor?
	var darkColor: UIColor?
	var selfColor: UIColor?
	var highlightColor: UIColor?
	let watchdog = Watchdog(threshold: 0.016) //60 frames a second
	let crashlytics = Crashlytics.sharedInstance()
	
    func application(application: UIApplication, didFinishLaunchingWithOptions launchOptions: [NSObject: AnyObject]?) -> Bool {
		if launchOptions != nil {
			NSLog("Starting with options %@", launchOptions!)
		}

		if User.isLoggedIn() {
			crashlytics.setUserIdentifier(User.username)
			if let displayName = User.displayName {
				crashlytics.setUserName(displayName)
			}
		}
		Fabric.with([crashlytics, Digits.self()])
		// Register a class to a route using object subscripting
		self.router["/messsage/:thread"] = MessageDeeplinkRouteHandler.self
		
		let controller: FirstViewController = FirstViewController()

        // Show View Controller from Main storyboard
        self.window!.rootViewController = UINavigationController(rootViewController: controller)
        self.window!.backgroundColor = UIColor.whiteColor()
		self.window!.rootViewController?.navigationController?.navigationBarHidden = true
		let darkBlue = UIColor(hexString: "2C3E50")
		let red = UIColor(hexString: "E74C3C")
		let light = UIColor(hexString: "ECF0F1")
		let lightBlue = UIColor(hexString: "3498DB")
		let medBlue = UIColor(hexString: "2980B9")
		self.backgroundColor = light
		self.darkColor = darkBlue
		self.selfColor = UIColor.whiteColor()
		self.highlightColor = red
		UIBarButtonItem.appearance().tintColor = lightBlue
		UIBarButtonItem.my_appearanceWhenContainedIn(UISearchBar.self).tintColor = lightBlue
		UIBarButtonItem.my_appearanceWhenContainedIn(UINavigationBar.self).tintColor = lightBlue
		UIBarButtonItem.my_appearanceWhenContainedIn(UIToolbar.self).tintColor = lightBlue
	
		UINavigationBar.appearance().barTintColor = light
		UINavigationBar.appearance().tintColor = lightBlue
		UINavigationBar.appearance().titleTextAttributes = [NSForegroundColorAttributeName: red]
		
		UITableViewCell.appearance().backgroundColor = light
		UICollectionView.appearance().backgroundColor = light
		UIScrollView.appearance().backgroundColor = light
		UITableView.appearance().backgroundColor = light
		self.window!.makeKeyAndVisible()
		
        return true
    }
	
	func application(application: UIApplication, openURL url: NSURL, sourceApplication: String?, annotation: AnyObject) -> Bool {
		self.router.handleURL(url, withCompletion: nil)
		return true
	}

    func applicationWillResignActive(application: UIApplication) {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
    }

    func applicationDidEnterBackground(application: UIApplication) {
        // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
        // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
		STXMPPClient.sharedInstance?.sendUnavailable()
    }

	//Called only when app comes to foreground from sleep
    func applicationWillEnterForeground(application: UIApplication) {
        // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
		STXMPPClient.sharedInstance?.sendAvailable()
    }

	//Called always when app activates (start and coming to foreground)
    func applicationDidBecomeActive(application: UIApplication) {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
		self.clearBadge(application)
	}

    func applicationWillTerminate(application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
    }
	
	func application(application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: NSData) {
		NSLog("didRegisterForRemoteNotificationsWithDeviceToken")
		let characterSet: NSCharacterSet = NSCharacterSet( charactersInString: "<>" )
		let deviceTokenString: String = (deviceToken.description as NSString)
			.stringByTrimmingCharactersInSet(characterSet)
			.stringByReplacingOccurrencesOfString(" ", withString: "") as String
		let data: [String : String] = [
			"username" : User.username,
			"token" : deviceTokenString,
			"deviceid" : OpenUDID.value()
		]
		
		STHttp.post("\(Configuration.pushApi)/push/token", data: data)
			.observeOn(UIScheduler())
			.start {
				event in
				switch event {
				case .Next:
					NSLog("Push sent")
				case let .Failed(error):
					NSLog("Push error %@", error)
					TSMessage.showNotificationWithTitle("Push Error", subtitle: "\(error.code) \(error.localizedDescription)" , type: TSMessageNotificationType.Error)
				default:
					break
				}
		}
	}
	
	//https://developer.apple.com/library/prerelease/ios/documentation/UIKit/Reference/UIApplicationDelegate_Protocol/index.html#//apple_ref/occ/intfm/UIApplicationDelegate/application:didReceiveRemoteNotification:fetchCompletionHandler:
	//If the user opens your app from the system-displayed alert, the system may call this method again when your app is about to enter the foreground 
    //so that you can update your user interface and display information pertaining to the notification.
	func application(application: UIApplication, didReceiveRemoteNotification userInfo: [NSObject : AnyObject], fetchCompletionHandler completionHandler: (UIBackgroundFetchResult) -> Void) {
		let completeMessageStr = userInfo["original"] as! String
		crashlytics.setObjectValue(completeMessageStr, forKey: "pushMessage")
		STXMPPClient.sharedInstance?.receiveMessageFromPushNotification(completeMessageStr)
		completionHandler(.NewData)
	}
	
	//MARK: background uploading handling
	func application(application: UIApplication, handleEventsForBackgroundURLSession identifier: String, completionHandler: () -> Void) {
		NSLog("-- handleEventsForBackgroundURLSession --")
	}
	
	private func clearBadge(application: UIApplication) {
		NSLog("ApplicationState \(application.applicationState)")
		if application.applicationState == UIApplicationState.Background {
			return
		}
		
		//Clear on client side
		let badgeNum = application.applicationIconBadgeNumber
		application.applicationIconBadgeNumber = 0
		
		//Try to clean on server
		if !User.isLoggedIn() || badgeNum == 0 {
			return
		}
		
		let data: [String : String] = [
			"username" : User.username
		]
		STHttp.post("\(Configuration.pushApi)/push/clearbadge", data: data)
			.observeOn(UIScheduler())
			.start {
				event in
				switch event {
				case .Next:
					NSLog("Badge cleared")
				case let .Failed(error):
					NSLog("Badge clear error %@", error)
					TSMessage.showNotificationWithTitle("Badge clear error", subtitle: "\(error.code) \(error.localizedDescription)" , type: TSMessageNotificationType.Error)
				default:
					break
				}
		}
	}
}

