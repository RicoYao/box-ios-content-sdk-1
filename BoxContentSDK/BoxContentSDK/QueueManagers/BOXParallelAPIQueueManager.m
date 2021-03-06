//
//  BOXParallelAPIQueueManager.m
//  BoxContentSDK
//
//  Created on 5/11/13.
//  Copyright (c) 2013 Box. All rights reserved.
//

#import "BOXParallelAPIQueueManager.h"

#import "BOXAPIDataOperation.h"
#import "BOXAPIOAuth2ToJSONOperation.h"
#import "BOXAPIMultipartToJSONOperation.h"
#import "BOXLog.h"

@interface BOXParallelAPIQueueManager ()

@property (atomic, readwrite, assign) BOOL currentAccessTokenHasExpired;

@end

@implementation BOXParallelAPIQueueManager

@synthesize globalQueue = _globalQueue;
@synthesize downloadsQueue = _downloadsQueue;
@synthesize uploadsQueue = _uploadsQueue;

@synthesize currentAccessTokenHasExpired = _currentAccessTokenHasExpired;

- (id)init
{
    self = [self initWithOAuth2Session:nil];
    return self;
}

- (id)initWithOAuth2Session:(BOXOAuth2Session *)OAuth2Session
{
    self = [super initWithOAuth2Session:OAuth2Session];
    if (self != nil)
    {
        _globalQueue = [[NSOperationQueue alloc] init];
        _globalQueue.name = @"BOXSerialAPIQueueManager global queue";
        _globalQueue.maxConcurrentOperationCount = 8;

        _downloadsQueue = [[NSOperationQueue alloc] init];
        _downloadsQueue.name = @"BOXSerialAPIQueueManager download queue";
        _downloadsQueue.maxConcurrentOperationCount = 2;

        _uploadsQueue = [[NSOperationQueue alloc] init];
        _uploadsQueue.name = @"BOXSerialAPIQueueManager upload queue";
        _uploadsQueue.maxConcurrentOperationCount = 2;

        _currentAccessTokenHasExpired = NO;
    }

    return self;
}

- (BOOL)enqueueOperation:(BOXAPIOperation *)operation
{
    // lock on the OAuth2Session, which is the shared resource
    @synchronized(self.OAuth2Session)
    {
        [super enqueueOperation:operation];

        // ensure that OAuth2 operations occur before all other operations
        if ([operation isKindOfClass:[BOXAPIOAuth2ToJSONOperation class]])
        {
            // hold a refernce to the pending OAuth2 operation so it can be added
            // as a dependency to all APIOperations enqueued before it finishes
            [self.enqueuedOAuth2Operations addObject:operation];

            for (NSOperation *enqueuedOperation in self.globalQueue.operations)
            {
                // All API Operations should be dependent on OAuth2 operations EXCEPT other
                // OAuth2 operations. For example, if a client requests 5 subsequent token refreshes,
                // All authenticated operations should depend on these requests resolving, but these
                // requests do not depend on each other
                if (![enqueuedOperation isKindOfClass:[BOXAPIOAuth2ToJSONOperation class]])
                {
                    [self addDependency:operation toOperation:enqueuedOperation];
                }
            }
            for (NSOperation *enqueuedOperation in self.downloadsQueue.operations)
            {
                [self addDependency:operation toOperation:enqueuedOperation];

            }
            for (NSOperation *enqueuedOperation in self.uploadsQueue.operations)
            {
                [self addDependency:operation toOperation:enqueuedOperation];

            }
        }
        else
        {
            // If there are any incomplete OAuth2 operations, add them as dependencies for
            // this newly enqueued operation. OAuth2 operations have the potential to change
            // the access token, which Authenticated operations need in order to complete
            // successfully.
            for (NSOperation *pendingOAuth2Operation in self.enqueuedOAuth2Operations)
            {
                [self addDependency:pendingOAuth2Operation toOperation:operation];
            }
        }

        if ([operation isKindOfClass:[BOXAPIDataOperation class]])
        {
            [self.downloadsQueue addOperation:operation];
            BOXLog(@"enqueued %@ on download queue", operation);
        }
        else if ([operation isKindOfClass:[BOXAPIMultipartToJSONOperation class]])
        {
            [self.uploadsQueue addOperation:operation];
            BOXLog(@"enqueued %@ on upload queue", operation);
        }
        else
        {
            [self.globalQueue addOperation:operation];
            BOXLog(@"enqueued %@ on global queue", operation);
        }

        return YES;
    }
}


@end
