//
//  ProfileViewController.swift
//  smalltalk
//
//  Created by Mikko Hämäläinen on 20/10/15.
//  Copyright (c) 2015 Mikko Hämäläinen. All rights reserved.
//

import UIKit

class ProfileViewController: UIViewController, UITextFieldDelegate {

	var label: UILabel!
	var usernameField: UITextField!
	
    override func viewDidLoad() {
        super.viewDidLoad()
		
		self.usernameField = UITextField(frame: CGRectZero)
		self.view.addSubview(self.usernameField)
		//self.usernameField.backgroundColor = UIColor.whiteColor()
		self.usernameField.placeholder = "Please choose a nick"
		self.usernameField.borderStyle = UITextBorderStyle.RoundedRect
		self.usernameField.autocorrectionType = UITextAutocorrectionType.No
		usernameField.snp_makeConstraints { make in
			make.width.equalTo(self.view).multipliedBy(0.75)
			make.height.equalTo(self.view).multipliedBy(0.06)
			make.centerX.equalTo(self.view)
			make.bottom.equalTo(self.view).multipliedBy(0.20)
		}
		self.usernameField.delegate = self
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
	
	func textFieldShouldReturn(textField: UITextField) -> Bool {   //delegate method
		textField.resignFirstResponder()
		self.usernameField.enabled = false
		let displayName = self.usernameField.text!.stringByTrimmingCharactersInSet(NSCharacterSet.whitespaceCharacterSet())
		let stream = STXMPPClient.sharedInstance?.stream
		stream!.updateVCard(displayName)
		User.displayName = displayName
		self.dismissViewControllerAnimated(true, completion: nil)
		return true
	}
}
