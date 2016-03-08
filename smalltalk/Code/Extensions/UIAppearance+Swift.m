//
//  UIAppearance+Swift.m
//  smalltalk
//
//  Created by Mikko Hämäläinen on 02/11/15.
//  Copyright © 2015 Mikko Hämäläinen. All rights reserved.
//

#import "UIAppearance+Swift.h"

@implementation UIView (UIViewAppearance_Swift)
+ (instancetype)my_appearanceWhenContainedIn:(Class<UIAppearanceContainer>)containerClass {
	return [self appearanceWhenContainedIn:containerClass, nil];
}
@end

@implementation UIBarButtonItem (UIViewAppearance_Swift)
+ (instancetype)my_appearanceWhenContainedIn:(Class<UIAppearanceContainer>)containerClass {
	return [self appearanceWhenContainedIn:containerClass, nil];
}
@end
