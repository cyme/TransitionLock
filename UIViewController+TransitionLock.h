//
//  UIViewController+TransitionLock.h
//
//  Copyright (c) 2014 Cyril Meurillon. All rights reserved.
//

#import <UIKit/UIKit.h>


// UIViewController(TransitionLock) implements a simple framework to synchronize between view controller
// transitions

@interface UIViewController(TransitionLock)

// Synchronous approach

// +tryTransition attempts to initiate a transition. It fails and return FALSE if another transition is ongoing.
// It initiates the transition and returns TRUE otherwise.

+ (BOOL)tryTransition;

// +endTransition ends a transition initiated with +tryTransition

+ (void)endTransition;


// Asynchronous approach

// +serializeTransitionWithBlock: initiates a transition and executes the passed block after the transition
// is initiated. If no other transition is ongoing, the transition is initiated immediately and the block
// executed before the call returns. If another transition is ongoing, the transition is initiated at some
// point in the future, when no other transitions are ongoing. The block is executed at that point.

+ (void)serializeTransitionWithBlock:(void(^)())transitionBlock;

// +transitionComplete signals the completion of a transition initiated with +serializeTransitionWithBlock:

+ (void)transitionComplete;


// -performSegueWithIdentifier:sender:completion: is a variant of -performSegueWithIdentifier:sender: that
// takes an additional completion block.

- (void)performSegueWithIdentifier:(NSString *)identifier sender:(id)sender completion:(void(^)())completion;

@end
