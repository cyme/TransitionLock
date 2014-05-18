//
//  UINavigationController+TransitionLock.m
//
//  Copyright (c) 2014 Cyril Meurillon. All rights reserved.
//

// we provide 2 implementations for this category
// one uses the UITransitionCoordinator class introduced in iOS7. the other doesn't.

#define USE_TRANSITIONCOORDINATOR   1


#import "UINavigationController+TransitionLock.h"
#if !USE_TRANSITIONCOORDINATOR
#import "NSObject+MySwizzle.h"
#import <objc/runtime.h>
#endif

#if !USE_TRANSITIONCOORDINATOR

@interface UINavigationController (TransitionPrivate)

@property (nonatomic, strong) void      (^navigationTransitionCompletionBlock)();

@end

#endif


@implementation UINavigationController (Transition)

// pushViewController with a completion block

- (void)pushViewController:(UIViewController *)viewController animated:(BOOL)animated completion:(void(^)())completion
{
#if USE_TRANSITIONCOORDINATOR
    
    // the implementation that leverages UITransitionCoordinator is straightforward:
    // initiate the transition, obtain a coordinator object for the transition, register a completion block for it
    
    id<UIViewControllerTransitionCoordinator>       coordinator;
    
    [self pushViewController:viewController animated:animated];
    coordinator = [self transitionCoordinator];
    if (!coordinator)
        return;
    [coordinator animateAlongsideTransition:nil completion:^(id<UIViewControllerTransitionCoordinatorContext> context) {
        completion();
    }];
#else
    
    // the "classic" implementation simply remembers the completion block and calls the regular implementation
    
    self.navigationTransitionCompletionBlock = completion;
    [self pushViewController:viewController animated:animated];
#endif
}

// popToRootViewControllerAnimated with a completion block

- (NSArray *)popToRootViewControllerAnimated:(BOOL)animated completion:(void(^)())completion
{
#if USE_TRANSITIONCOORDINATOR
    
    // the implementation that leverages UITransitionCoordinator is straightforward:
    // initiate the transition, obtain a coordinator object for the transition, register a completion block for it
    
    id<UIViewControllerTransitionCoordinator>       coordinator;
    NSArray                                         *result;
    
    result = [self popToRootViewControllerAnimated:animated];
    if (!result || ([result count] == 0))
        return result;
    coordinator = [self transitionCoordinator];
    assert(coordinator);
    [coordinator animateAlongsideTransition:nil completion:^(id<UIViewControllerTransitionCoordinatorContext> context) {
        completion();
    }];
    return result;
#else
    
    // the "classic" implementation simply remembers the completion block and calls the regular implementation
    
    NSArray                                         *result;

    result = [self popToRootViewControllerAnimated:animated];
    if (!result || ([result count] == 0))
        return result;
    self.navigationTransitionCompletionBlock = completion;
    return result;
#endif
}

// popToViewController with a completion block

- (NSArray *)popToViewController:(UIViewController *)viewController animated:(BOOL)animated completion:(void(^)())completion
{
#if USE_TRANSITIONCOORDINATOR
    
    // the implementation that leverages UITransitionCoordinator is straightforward:
    // initiate the transition, obtain a coordinator object for the transition, register a completion block for it
    
    id<UIViewControllerTransitionCoordinator>       coordinator;
    NSArray                                         *result;
    
    result = [self popToViewController:viewController animated:animated];
    if (!result || ([result count] == 0))
        return result;
    coordinator = [self transitionCoordinator];
    assert(coordinator);
    [coordinator animateAlongsideTransition:nil completion:^(id<UIViewControllerTransitionCoordinatorContext> context) {
        completion();
    }];
    return result;
#else
    
    // the "classic" implementation simply remembers the completion block and calls the regular implementation
    
    NSArray                                         *result;

    result = [self popToRootViewControllerAnimated:animated];
    if (!result || ([result count] == 0))
        return result;
    self.navigationTransitionCompletionBlock = completion;
    return result;
#endif
}

// popViewControllerAnimated with a completion block

- (UIViewController *)popViewControllerAnimated:(BOOL)animated completion:(void(^)())completion
{
#if USE_TRANSITIONCOORDINATOR
    
    // the implementation that leverages UITransitionCoordinator is straightforward:
    // initiate the transition, obtain a coordinator object for the transition, register a completion block for it
    
    id<UIViewControllerTransitionCoordinator>       coordinator;
    UIViewController                                *result;
    
    result = [self popViewControllerAnimated:animated];
    if (!result)
        return nil;
    coordinator = [self transitionCoordinator];
    assert(coordinator);
    [coordinator animateAlongsideTransition:nil completion:^(id<UIViewControllerTransitionCoordinatorContext> context) {
        completion();
    }];
    return result;
#else
    
    // the "classic" implementation simply remembers the completion block and calls the regular implementation
    
    UIViewController                                *result;

    result = [self popViewControllerAnimated:animated];
    if (!result)
        return nil;
    self.navigationTransitionCompletionBlock = completion;
    return result;
#endif
}


#if !USE_TRANSITIONCOORDINATOR

// below are the accessors for all the properties we've defined in this category.
// the properties are backed by associated objects

static char navigationTransitionCompletionBlockKey;

- (void(^)())navigationTransitionCompletionBlock {
    return objc_getAssociatedObject(self, &navigationTransitionCompletionBlockKey);
}

- (void)setNavigationTransitionCompletionBlock:(void (^)())navigationTransitionCompletionBlock {
    objc_setAssociatedObject(self, &navigationTransitionCompletionBlockKey, navigationTransitionCompletionBlock, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

#endif

@end

#if !USE_TRANSITIONCOORDINATOR


// the sole purpose of this class is to define a default implementation for certain methods

@interface NSObject (TransitionLock)

- (void)navigationController:(UINavigationController *)navigationController didShowViewController:(UIViewController *)viewController animated:(BOOL)animated;
- (void)_navigationController:(UINavigationController *)navigationController didShowViewController:(UIViewController *)viewController animated:(BOOL)animated;

@end

@implementation NSObject (TransitionLock)


// default implementation for navigationController:didShowViewController:animated:

- (void)navigationController:(UINavigationController *)navigationController didShowViewController:(UIViewController *)viewController animated:(BOOL)animated {

    // default implementation for navigationController:didShowViewController:animated: for navigation controller delegate that do not implement the method
    // do nothing
}

// alternate implementation for navigationController:didShowViewController:animated:
// this is where we catch the completion of the transitions

- (void)_navigationController:(UINavigationController *)navigationController didShowViewController:(UIViewController *)viewController animated:(BOOL)animated {
    
    // if a completion block was specified, invoke it
    
    if (navigationController.navigationTransitionCompletionBlock) {
        navigationController.navigationTransitionCompletionBlock();
        navigationController.navigationTransitionCompletionBlock = nil;
    }
    
    // invoke the original implementation
    
    [self _navigationController:navigationController didShowViewController:viewController animated:animated];
}

// implement a +load function in this category to handle the class swizzling.
// it is safe to implement a +load function in a category. All the +load functions defined for a class and its
// categories will be called.

+ (void)load {
    
    // no release pool is provided at the time +load is called, therefore create one
    
    @autoreleasepool {
        NSArray     *conformingClasses;
        
        // obtain the list of all classes conforming to the UINavigationControllerDelegate protocol
        
        conformingClasses = [NSObject classesConformingToProtocol:@protocol(UINavigationControllerDelegate)];
        
        // for all such classes, provide a default implementation for navigationController:didShowViewController:animated:
        // if none was defined, then swizzle that method
        
        for(Class class in conformingClasses) {
            if (![class implements:@selector(navigationController:didShowViewController:animated:)])
                [class addMethod:@selector(navigationController:didShowViewController:animated:)];
            [class addMethod:@selector(_navigationController:didShowViewController:animated:)];
            [class swizzle:@selector(navigationController:didShowViewController:animated:)
                      with:@selector(_navigationController:didShowViewController:animated:)];
        }
    }
}
@end

#endif