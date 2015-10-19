//
//  BOXCommentRequest.h
//  BoxContentSDK
//

#import "BOXRequest.h"

@interface BOXCommentRequest : BOXRequest

@property (nonatomic, readwrite, assign) BOOL requestAllItemFields;
@property (nonatomic, readwrite, strong) NSURL *sharedLinkURL;
@property (nonatomic, readwrite, strong) NSString *sharedLinkPassword; // Only required if the shared link is password-protected

- (instancetype)initWithCommentID:(NSString *)commentID;
- (void)performRequestWithCompletion:(BOXCommentBlock)completionBlock;
- (void)performRequestWithCached:(BOXCommentBlock)cacheBlock
                       refreshed:(BOXCommentBlock)refreshBlock;

@end
