import UIKit
import ReactiveCocoa
import TSMessages

class FirstViewController: UIViewController  {
    var logInViewController: LoginViewController!
	var xmppClient: STXMPPClient?
	var loginSequenceCompleted = MutableProperty<Bool>(false)
	let launch = LaunchScreen()
	var launchAnimated = MutableProperty<Bool>(false)

    override func viewDidLoad() {
        super.viewDidLoad()
		self.navigationController?.navigationBarHidden = true
		self.view.addSubview(launch)
		/* wait a beat before animating in */
		dispatch_after(dispatch_time(DISPATCH_TIME_NOW, Int64(0.1 * Double(NSEC_PER_SEC))), dispatch_get_main_queue(), {
			[unowned self] in
			self.launch.animate {
				[unowned self] in
				self.launchAnimated.value = true
                self.navigationController?.navigationBarHidden = false
				UIApplication.sharedApplication().statusBarHidden = false
			}
		})
	}
	
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)
		
		//Do a login only if we have animated ready
		self.launchAnimated.producer
			.filter { $0 == true }
			.start {
				event in
				switch event {
				case .Next:
					//No user logged in
					if (!User.isLoggedIn()) {
						self.logInViewController = LoginViewController()
						self.logInViewController.loginSequenceCompleted = self.loginSequenceCompleted
						self.presentViewController(self.logInViewController,  animated: false, completion:nil)
						//self.navigationController!.pushViewController(self.logInViewController, animated: false)
						
						self.loginSequenceCompleted.producer
							.skip(1) //We don't care about the initial value
							.start {
								event in
								switch event {
								case let .Next(next):
									if (next) {
										self.dismissViewControllerAnimated(true, completion: nil)
									}
								default:
									break
								}
						}
					} else {
						self.loginXMPP()
						self.presentConversationListViewController()
					}
				default: break
				}
		}
    }
    
    // MARK - XMPP Authentication Methods
    
    func loginXMPP() {
		xmppClient = STXMPPClient.clientForHost(Configuration.chatServer, port: 5222, user: User.username, password: User.token)
		self.xmppClient!.connectionStatus!.observeOn(UIScheduler()).observe {
			event in
			switch event {
			case let .Failed(error):
				NSLog("FirstViewController: Connection error \(error)")
				TSMessage.showNotificationInViewController(self, title: "XMPP connection error", subtitle: error.localizedDescription , type: TSMessageNotificationType.Error)
				if let xmppError = STXMPPStream.XMPPError(rawValue: error.code) {
					if xmppError == STXMPPStream.XMPPError.AuthFailed {
						User.logOut()
						self.navigationController!.popToRootViewControllerAnimated(true)
					}
				}
			case let .Next(event):
				let (connected, _) = event
				if !connected {
					//TODO Could not connect, inform
				}
			default:
				break
			}
		}
	}
	
    // MARK - Present ATLPConversationListController
    
    func presentConversationListViewController() {
        self.enablePushes()
		let controller: ConversationsListViewController = ConversationsListViewController(xmpp: self.xmppClient!)
        self.navigationController!.pushViewController(controller, animated: false)
    }
	
	func enablePushes() {
		let notificationSettings: UIUserNotificationSettings = UIUserNotificationSettings(forTypes: [.Alert, .Badge, .Sound], categories: nil)
		UIApplication.sharedApplication().registerUserNotificationSettings(notificationSettings)
		UIApplication.sharedApplication().registerForRemoteNotifications()
	}
}

