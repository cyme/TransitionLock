# Transitions are tricky

### Transitions can collide  

When multiple `UIViewController` are visible on the screen, such as is often the case on the iPad, things can get complicated. Controllers may act on themselves and/or on each other. For example:
- a `UIButton` in a view may cause its controller to present a new `UIViewController` (e.g. "edit contact” button in the Address Book App).
- a `UIButton` in the master view controller of a `UISplitViewController` may cause a new `UIViewController` to be presented and/or an existing controller to be dismissed in the detail view controller (e.g. "add a contact" in the Address Book app).

This is a challenge for the developer because:
- Presentations and dismissals of `UIViewController` are often animated, which creates transient states during which the main UI thread continues to respond to touch events, timers and other programmatic events.
- UIKit does not serialize animated presentations and dismissals (collectively called "transitions”). It is a programming error to present or dismiss a `UIViewController` while another transition is taking place on the presenting or dismissing `UIViewController` (an exception is thrown).


### UIKit offers little help

While UIKit offers limited protection by preventing "active" `UIViewController` from generating or processing events, the overall task of coordinating between transitions remains the responsibility of the developer. The complexity of that quickly increases as the number of controllers and interactions grow.

The current solution for developers is to manually track transitions. The app must remember it enters a transition when it calls one of transition-inducing methods:

    performSegueWithIdentifier:sender:
    presentViewController:animated:completion:
    dismissViewControllerAnimated:completion:
    pushViewController:animated:
    ...
    
It knows the transition is over when the callback `viewDidAppear:` or `viewDidDisappear:` is invoked on respectively the presented or dismissing `UIViewController` (the destination controller). In the case of initiating a transition with a `UIStoryboardSegue` an additional step is needed to identify the destination controller in `prepareForSegue:sender:`.  

This solution has significant drawbacks:
- The transition state machine is fairly complex, scattered across multiple methods and classes, and difficult to maintain as the app UI evolves.
- The logic becomes even more complex if transitions cannot be dropped and have to be deferred when a conflict is detected.

# A Simple Solution  


### TransitionLock

TransitionLock is a `UIViewController` category that introduces a simple framework to help developer synchronize transitions.

    @interface UIViewController(TransitionLock)
    + (BOOL)startTransition;
    + (void)endTransition;
    + (void)serializeTransitionWithBlock:(void(^)())transitionBlock;
    + (void)transitionComplete;
    @end



### Synchronous and Asynchronous Approaches

The framework offers two approaches:

- **Synchronous approach**  
The app calls `startTransition` before initiating a transition. If another transition is ongoing, the calls fails and returns `FALSE`. The caller knows then it is not safe to start the transition. When dealing with touch events such as buttons, selections, etc., it often is an adequate response to drop the event when the application is busy responding to a another user event. When the app is done with the transition, it calls `endTransition`.
- ** Asynchronous approach**  
When the app cannot gracefully fail and drop the transition, another approach is available. In those situations, the app calls `serializeTransitionWithBlock:` and passes a block to be executed when no other transition is taking place. The app can execute the transition in the block, and then call `transitionComplete` when it is done. When `serializeTransitionWithBlock:` is called multiple times consecutively, the transition blocks are guaranteed to be executed in the same order their respective `serializeTransitionWithBlock:` was called.

The penalty paid for using the more potent asynchronous approach is slight increased code complexity. The controller hierarchy is not guaranteed to be unchanged when the block is invoked. For example, the controller we intended to dismiss or use for a presentation may have disappeared.

### More completion blocks
Some transition-inducing methods, notably `performSegueWithIdentifier:sender:` are not offering completion blocks. This greatly reduces the usability of the TransitionLock library, as transition completion blocks is where we would naturally call `endTransition` and `transitionComplete` . We've remedied this shortcoming by providing the missing methods.

```
@interface UIViewController(TransitionLock)
- (void)performSegueWithIdentifier:(NSString *)identifier sender:(id)sender completion:(void(^)())completion;
@end
```
```
@interface UINavigationController(TransitionLock)
- (void)pushViewController:(UIViewController *)viewController animated:(BOOL)animated completion:(void(^)())completion;
- (NSArray *)popToRootViewControllerAnimated:(BOOL)animated completion:(void(^)())completion;
- (NSArray *)popToViewController:(UIViewController *)viewController animated:(BOOL)animated completion:(void(^)())completion;
- (UIViewController *)popViewControllerAnimated:(BOOL)animated completion:(void(^)())completion;
@end
```

# Usage Examples

### Using the synchronous approach

```
// this is the implementation of a view controller
// the action method for our button needs to perform a segue, e.g. to present a new controller
// In this case we find it acceptable for the button event to be dropped if another transition
// is taking place.

- (IBAction)myButtonAction:(id)sender
{
	if (![UIViewController startTransition])
		return;
	[self performSegueWithIdentifier:@"mySegue" sender:self completion:^() {
		[UIViewController endTransition];
	}];
}
```

### Using the asynchronous approach

```
// this is the implementation of a view controller
// the fire method for a NSTimer wants to dismiss a view controller that was presented earlier
// In this example we cannot gracefully fail if another transition is taking place.
// Therefore we need to use the asynchronous approach.

- (void)timerFireMethod:(NSTimer *)timer
{
	__weak typeof(self)     weakSelf = self;

	...
	[UIViewController serializeTransitionWithBlock:^() {

		// check if the presented view controller is still present.
		// note the test will also evaluate to FALSE if self has been
		// dismissed and deallocated as weakSelf will be nil.

		if (weakSelf.presentedViewController)
			[weakSelf dismissViewControllerAnimated:YES completion:^() {
				[UIViewController transitionComplete];
			}];
		else
			[UIViewController transitionComplete];
	}];
}
```

# Getting Started

To build [TransitionLock](http://github.com/cyme/transitionlock), you will also need [BlockCondition](http://github.com/cyme/blockcondition) and [Swizzle](http://github.com/cyme/swizzle). Clone those 3 repositories, and add the following files to your project:


> NSObject+MySwizzle.h  
> NSObject+MySwizzle.m  
> BlockCondition.h  
> BlockCondition.m  
> UIViewController+TransitionLock.h  
> UIViewController+TransitionLock.m  
> UINavigationController+TransitionLock.h  
> UINavigationController+TransitionLock.m  


Then `#import "UIViewController+TransitionLock.h"` and optionally `#import "UINavigationController+TransitionLock.h"` and start playing!