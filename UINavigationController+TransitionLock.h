//
//  UINavigationController+TransitionLock.h
//
//  Copyright (c) 2014 Cyril Meurillon. All rights reserved.
//

#import <UIKit/UIKit.h>

// this category implements variants of existing transition-inducing method that take an additional completion block

@interface UINavigationController (TransitionLock)

- (void)pushViewController:(UIViewController *)viewController animated:(BOOL)animated completion:(void(^)())completion;
- (NSArray *)popToRootViewControllerAnimated:(BOOL)animated completion:(void(^)())completion;
- (NSArray *)popToViewController:(UIViewController *)viewController animated:(BOOL)animated completion:(void(^)())completion;
- (UIViewController *)popViewControllerAnimated:(BOOL)animated completion:(void(^)())completion;

@end
