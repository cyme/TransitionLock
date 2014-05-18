//
//  UIViewController+TransitionLock.m
//
//  Copyright (c) 2014 Cyril Meurillon. All rights reserved.
//

#import "UIViewController+TransitionLock.h"
#import "NSObject+MySwizzle.h"
#import "BlockCondition.h"
#import <objc/runtime.h>


@interface UIViewController(TransitionLockPrivate)

@property NSString                      *transitionSegueIdentifier;
@property (nonatomic, strong) void      (^transitionTemporaryCompletionBlock)();
@property (nonatomic, strong) void      (^transitionCompletionBlock)();

@end


@implementation UIViewController(TransitionLock)

// getter method for the (read-only) transitionBlocks "class property" that mimics:
// @property (readonly) NSMutableArray  *transitionBlocks

+ (NSMutableArray *)transitionBlocks
{
    static NSMutableArray       *transitionBlocks;
    static dispatch_once_t      onceToken;
    
    // check if transitionBlocks needs to be initialized
    
    if (!transitionBlocks)
        
        // initialize transitions in a thread-safe manner
        
        dispatch_once(&onceToken, ^() {
            transitionBlocks = [NSMutableArray array];
        });
    return transitionBlocks;
}

// getter method for the (read-only) transitionCompleted "class property" that mimics:
// @property (readonly) BlockCondition  *transitionCompleted

+ (BlockCondition *)transitionCompleted
{
    static BlockCondition       *transitionCompleted;
    static dispatch_once_t      onceToken;
    
    // check if transitionCompleted needs to be initialized
    
    if (!transitionCompleted)
        
        // initialize transitionCompleted in a thread-safe manner
        
        dispatch_once(&onceToken, ^() {
            transitionCompleted = [BlockCondition blockCondition];
        });
    return transitionCompleted;
}

//  asynchronous initiation of a transition

+ (void)serializeTransitionWithBlock:(void(^)())transitionBlock
{
    // add the transition block at the end of the block queue
    
    [self.transitionBlocks addObject:transitionBlock];
    
    // if no other blocks are in the queue, there are no ongoing transition.
    // in that case, execute the block immediately
    
    if ([self.transitionBlocks count] == 1) {
        transitionBlock();
        return;
    }
}

// signal the completion of a transition that was initiated asynchronously

+ (void)transitionComplete
{
    void                            (^block)();

    // remove our block from the block queue
    
    [self.transitionBlocks removeObjectAtIndex:0];
    
    // if no other transition blocks are waiting in the queue, nothing more to do
    
    if ([self.transitionBlocks count] == 0)
        return;
    
    // execute the next block waiting in the queue.
    // the block is executed asynchronously on the main thread to be extra safe
    // as UIKit may not consider the transition complete until after -viewDidAppear returns.
    
    block = self.transitionBlocks[0];
    dispatch_async(dispatch_get_main_queue(), ^() {
        block();
    });
}

// synchronous initiation of a transition

+ (BOOL)tryTransition
{
    __weak typeof(self)             weakSelf = self;

    // if another block already waits in the block queue, a transition is ongoing.
    // the initiation failed. we returned FALSE.
    
    if ([self.transitionBlocks count] > 0)
        return FALSE;
    
    // no other transition is ongoing. we can initiate our transition.
    // reset the transitionCompleted condition before we use it
    
    [self.transitionCompleted reset];
    
    // initiates the transition. the transition block will be executed immediately.
    
    [self serializeTransitionWithBlock:^() {
        
        // execute the block below when the transitionCompleted condition is set
        // this effectively invokes the block when +endTransition is called
        
        [weakSelf.transitionCompleted waitInBackgroundWithBlock:^() {
            
            // we signal the end of the transition
            
            [weakSelf transitionComplete];
        }];
    }];
    
    // return success
    
    return TRUE;
}

// signal the end of a transition that was initiated synchronously

+ (void)endTransition
{
    // we set the transitionCompleted condition, which will release the block in +tryCondition
    
    [self.transitionCompleted broadcast];
}

// performSegueWithIdentifier:sender:completion: accepts an additional completion block

- (void)performSegueWithIdentifier:(NSString*)identifier sender:(id)sender completion:(void(^)())block
{
    // let's remember the segue identifier and block passed
    
    self.transitionSegueIdentifier = identifier;
    self.transitionTemporaryCompletionBlock = block;

    // call -performSegueWithIdentifier:sender:
    
    [self performSegueWithIdentifier:identifier sender:sender];
}

// this is an alternate implementation of -prepareForSegue:sender:
// UIViewControllers and all its subclasses that override the method use this implementation

- (void)_transitionPrepareForSegue:(UIStoryboardSegue *)segue sender:(id) sender
{
    void                        (^block)();
    UIViewController            *destinationController;

    // if the segue is not the same that was passed to -performSegueWithIdentifier:sender:completion,
    // execute the original implementation of -prepareForSegue:sender: and return
    
    if (![segue.identifier isEqualToString:self.transitionSegueIdentifier]) {
        [self _transitionPrepareForSegue:segue sender:sender];
        return;
    }

    // this is the segue that was passed to -performSegueWithIdentifier:sender:completion
    // keep a reference to the block in the destination view controller of the segue
    // the destination view controller will call -viewDidAppear: when the transition is completed
    
    block = self.transitionTemporaryCompletionBlock;
    self.transitionTemporaryCompletionBlock = nil;
    self.transitionSegueIdentifier = nil;
    
    destinationController = segue.destinationViewController;
    destinationController.transitionCompletionBlock = block;
    
    // call original implementation of -prepareForSegue:sender:
    
    [self _transitionPrepareForSegue:segue sender:sender];
}

// this is an alternate implementation of -viewDidAppear:
// this is where we catch the end of the transition

- (void)_transitionViewDidAppear:(BOOL)animated
{
    void                        (^block)();
    
    // call original implementation
    
    [self _transitionViewDidAppear:animated];
    
    // invoke the completion block that we remembered from the call to -prepareForSegue:sender:
    
    block = self.transitionCompletionBlock;
    if (block) {
        self.transitionCompletionBlock = nil;
        block();
    }
}


// implement a +load function in this category to handle the class swizzling.
// it is safe to implement a +load function in a category. All the +load functions defined for a class and its
// categories will be called.

+ (void)load
{
    // we don't have a release pool yet, so we need to create one

    @autoreleasepool {
        NSArray     *subClasses;

        // swizzle the -viewDidAppear method for UIViewController
        // we only need to swizzle the implementation in UIViewController as any override in a subclass calls
        // the super implementation
        
        [UIViewController swizzle:@selector(viewDidAppear:) with:@selector(_transitionViewDidAppear:)];

        // we are now going to swizzle the -prepareForSegue:sender: method of any subclass of UIViewController
        // that implements it.
        
        subClasses = [UIViewController subClasses];

        // for all subclasses, add a method for the alternate implementation of -prepareForSegue:sender:
        // then swizzle
        
        for(Class class in subClasses) {
            if ([class implements:@selector(prepareForSegue:sender:)]) {
                [class addMethod:@selector(_transitionPrepareForSegue:sender:)];
                [class swizzle:@selector(prepareForSegue:sender:) with:@selector(_transitionPrepareForSegue:sender:)];
            }
        }
        
        // finally, swizzle -prepareForSegue:sender: for UIViewController itself
        
        assert([UIViewController implements:@selector(prepareForSegue:sender:)]);
        [UIViewController swizzle:@selector(prepareForSegue:sender:) with:@selector(_transitionPrepareForSegue:sender:)];
    }
}


// below are the accessors for all the properties we've defined in this category.
// the properties are backed by associated objects

static char transitionSegueIdentifierKey;

- (NSString *)transitionSegueIdentifier
{
    return objc_getAssociatedObject(self, &transitionSegueIdentifierKey);
}

- (void)setTransitionSegueIdentifier:(NSString *)transitionSegueIdentifier
{
    objc_setAssociatedObject(self, &transitionSegueIdentifierKey, transitionSegueIdentifier, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

static char transitionTemporaryCompletionBlockKey;

- (void(^)())transitionTemporaryCompletionBlock
{
    return objc_getAssociatedObject(self, &transitionTemporaryCompletionBlockKey);
}

- (void)setTransitionTemporaryCompletionBlock:(void (^)())transitionTemporaryCompletionBlock
{
    objc_setAssociatedObject(self, &transitionTemporaryCompletionBlockKey, transitionTemporaryCompletionBlock, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

static char transitionCompletionBlockKey;

- (void(^)())transitionCompletionBlock
{
    return objc_getAssociatedObject(self, &transitionCompletionBlockKey);
}

- (void)setTransitionCompletionBlock:(void (^)())transitionCompletionBlock
{
    objc_setAssociatedObject(self, &transitionCompletionBlockKey, transitionCompletionBlock, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

@end
