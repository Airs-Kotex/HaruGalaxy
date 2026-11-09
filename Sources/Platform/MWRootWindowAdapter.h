// SPDX-License-Identifier: Apache-2.0
#import <UIKit/UIKit.h>
typedef NS_ENUM(NSInteger, MWRootAttachmentResult) {
    MWRootAttachmentPending, MWRootAttachmentReady, MWRootAttachmentUnsupported
};
@interface MWRootWindowAdapter : NSObject
@property(nonatomic,weak) UIWindow *overlayWindow;
- (BOOL)prepareWithError:(NSError **)error;
- (MWRootAttachmentResult)attachToRootView:(id)root error:(NSError **)error;
- (void)refresh;
- (void)detach;
@end
