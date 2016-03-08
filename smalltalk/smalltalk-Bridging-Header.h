//
//  smalltalk-Bridging-Header.h
//  smalltalk
//
//  Created by Mikko Hämäläinen on 30/08/15.
//  Copyright (c) 2015 Mikko Hämäläinen. All rights reserved.
//

#ifndef smalltalk_smalltalk_Bridging_Header_h
#define smalltalk_smalltalk_Bridging_Header_h

#import "UIAppearance+Swift.h"

//Since we're using use_frameworks! in our Podfile, Pods are imported as frameworks
//and they are used with 'import Parse' style
//If there is no Framework for the Pod under Pods/Frameworks, add the header here
#import <XMPPFramework/XMPPFramework.h> 
#import <Reachability/Reachability.h>
#import <XMPPFramework/DDXML.h>
#import <TSMessages/TSMessage.h>
#import <JSQMessagesViewController/JSQMessages.h>
#import <OpenUDID/OpenUDID.h>
#import <DeepLinkKit/DeepLinkKit.h>
#import <NYTPhotoViewer/NYTPhoto.h>
#import <NYTPhotoViewer/NYTPhotosViewController.h>
//#import <LogglyLogger/LogglyLogger.h>




#endif
