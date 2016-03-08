//
//  LoginViewController.m
//  smalltalk
//
//  Created by Mikko Hämäläinen on 21/09/15.
//  Copyright (c) 2015 Mikko Hämäläinen. All rights reserved.
//

import UIKit
import DigitsKit
import ChameleonFramework
import SnapKit
import ReactiveCocoa
import Result
import TSMessages
import PhoneNumberKit
import SwiftyJSON

class LoginViewController: UIViewController, UITextFieldDelegate {
	var loginSequenceCompleted = MutableProperty<Bool>(false)
	
	//Test user data
	var testUserButton: UIButton!
	var testUserText: UITextField!
	//End
	
	var label: UILabel!
	
	override func viewDidLoad() {
		super.viewDidLoad()
		self.view.backgroundColor = FlatWhite()
		//ComplementaryFlatColorOf(color)
		//ContrastColor(backgroundColor, isFlat)

		//Check out these values from LaunchScreen.xib
		self.label = UILabel(frame: CGRect(x: 0, y: 0, width: 55, height: 15))
		self.label.text = "smalltalk"
		self.label.font = UIFont.boldSystemFontOfSize(22)
		self.label.textColor = FlatRed()
		
		self.view.addSubview(self.label)
		self.label.snp_makeConstraints { (make) -> Void in
			make.centerX.equalTo(self.view)
			make.centerY.equalTo(self.view.snp_bottom).multipliedBy(0.25).offset(1)
		}
		
		let digitsAppearance = DGTAppearance()
		digitsAppearance.backgroundColor = FlatWhite()
		digitsAppearance.accentColor = FlatRed()
		
		let authenticateButton = UIButton(frame: CGRectMake(0, 0, 0, 0))
		self.view.addSubview(authenticateButton)
		authenticateButton.enabled = true
		authenticateButton.layer.cornerRadius = 5
		authenticateButton.backgroundColor = UIColor.whiteColor()
		authenticateButton.setTitleColor(FlatWhite(), forState: .Normal)
		authenticateButton.setTitle("Sign up", forState: UIControlState.Normal)
		authenticateButton.titleLabel!.font = UIFont.boldSystemFontOfSize(UIFont.systemFontSize())
		authenticateButton.backgroundColor = FlatRed()
		authenticateButton.snp_makeConstraints { (make) -> Void in
			make.width.equalTo(self.view).multipliedBy(0.75)
			make.height.equalTo(self.view).multipliedBy(0.06)
			make.centerX.equalTo(self.view)
			make.bottom.equalTo(self.view).multipliedBy(0.80)
		}
		authenticateButton.addTarget(self, action: "digitsAuth:", forControlEvents: UIControlEvents.TouchUpInside)
		
		//Test user functionality
		if Configuration.showTestUser {
			self.testUserButton = UIButton(frame: CGRectMake(0, 0, 100, 100))
			testUserButton.enabled = true
			testUserButton.backgroundColor = UIColor.whiteColor()
			testUserButton.setTitleColor(UIColor.blueColor(), forState: .Normal)
			testUserButton.setTitle("Make a test user", forState: UIControlState.Normal)
			self.view.addSubview(self.testUserButton)
			testUserButton.snp_makeConstraints { make in
				make.size.equalTo(authenticateButton)
				make.centerX.equalTo(self.view)
				make.top.equalTo(authenticateButton.snp_bottom).offset(10)
			}
			self.testUserButton.addTarget(self, action: "testUserButton:", forControlEvents: UIControlEvents.TouchUpInside)
			
			self.testUserText = UITextField(frame: CGRectZero)
			self.testUserText.enabled = false
			self.testUserText.backgroundColor = UIColor.whiteColor()
			self.testUserText.alpha = 0.0
			self.testUserText.borderStyle = UITextBorderStyle.Line
			self.testUserText.autocapitalizationType = UITextAutocapitalizationType.None
			self.testUserText.autocorrectionType = UITextAutocorrectionType.No
			self.view.addSubview(self.testUserText)
			testUserText.snp_makeConstraints { make in
				make.size.equalTo(testUserButton)
				make.centerX.equalTo(self.view)
				make.top.equalTo(self.view.snp_top).offset(30)
			}
			self.testUserText.delegate = self
		}
		//End test user
	}
	
	func digitsAuth(sender: AnyObject?) {
		let appearance = DGTAppearance()
		appearance.labelFont = UIFont(name: "HelveticaNeue-Bold", size: 16)
		appearance.bodyFont = UIFont(name: "HelveticaNeue-Italic", size: 16)
		appearance.accentColor = FlatRed()
		appearance.backgroundColor = FlatWhite()
		
		let configuration = DGTAuthenticationConfiguration(accountFields: .DefaultOptionMask)
		configuration.appearance = appearance
		Digits.sharedInstance().authenticateWithViewController(nil, configuration: configuration, completion: {
			(session: DGTSession!, error: NSError!) in
			if (session == nil) {
				//TODO Dismiss this view controller and start from beginning
				self.loginSequenceCompleted.value = true
			} else {
				let digits = Digits.sharedInstance()
				let oauthSigning = DGTOAuthSigning(authConfig:digits.authConfig, authSession:digits.session())
				var authHeaders: [NSObject: AnyObject] = oauthSigning.OAuthEchoHeadersToVerifyCredentials()
				
				do {
					let phoneNumber = try PhoneNumber(rawNumber:session.phoneNumber)
					let countryCode = "+\(String(phoneNumber.countryCode))"
					authHeaders["countryCode"] = countryCode
				}
				catch {
					print("Phone number parse error")
				}
				
				self.postToDigits(authHeaders)
					.observeOn(UIScheduler())
					.start {
						event in
						switch event {
						case let .Next(result):
							if (result.value != nil) {
								self.saveUserData(result.value as! JSON)
								self.loginSequenceCompleted.value  = true
							}
						
						case let .Failed(error):
							NSLog("Post to digits error %@", error)
                            TSMessage.showNotificationInViewController(self, title: "Authentication error", subtitle: error.localizedDescription , type: TSMessageNotificationType.Error)
						default:
							break
						}
				}
			}
		})
	}
	
	private func saveUserData(data: JSON) {
		User.loggedInWith(data)
	}
	
	private func postToDigits(authHeaders: [NSObject: AnyObject]) -> SignalProducer<Result<Any, NSError>, NSError> {
		return STHttp.post("\(Configuration.mainApi)/users/new", data: authHeaders)
	}
	
	//Test user functionality
	func testUserButton(sender: AnyObject?) {
		self.testUserButton.enabled = false
		UIView.animateWithDuration(0.1, delay: 0.5, options: UIViewAnimationOptions.CurveEaseOut, animations: {
			self.testUserButton.alpha = 0.0
			},
			completion: {
				finished in
				self.testUserText.enabled = true
				self.testUserText.alpha = 1.0
		})
	}
	
	func textFieldShouldReturn(textField: UITextField) -> Bool {   //delegate method
		textField.resignFirstResponder()
		self.testUserText.enabled = false
		UIView.animateWithDuration(0.1, delay: 0.5, options: UIViewAnimationOptions.CurveEaseOut, animations: {
			self.testUserText.alpha = 0.0
			}, completion: nil)
		let data = ["user": textField.text!]
		self.postTestUser(data)
			.observeOn(UIScheduler())
			.start {
				event in
				switch event {
				case let .Next(result):
					if (result.value != nil) {
						self.saveUserData(result.value as! JSON)
						self.loginSequenceCompleted.value = true
					}
				case let .Failed(error):
					TSMessage.showNotificationInViewController(self, title: "Authentication error", subtitle: "\(error.code) \(error.localizedDescription)" , type: TSMessageNotificationType.Error)
					self.testUserText.enabled = true
					self.testUserText.alpha = 1.0
				default:
					break
			}
		}
		
		return true
	}
	
	private func postTestUser(data: [NSObject: AnyObject]) -> SignalProducer<Result<Any, NSError>, NSError> {
		return STHttp.post("\(Configuration.mainApi)/users/test", data: data)
	}
}


