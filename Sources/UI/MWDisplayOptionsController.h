// SPDX-License-Identifier: Apache-2.0
#import <UIKit/UIKit.h>
@interface MWDisplayOptionsController : UITableViewController
@property(nonatomic,copy) NSArray<NSDictionary *> *windows;
@property(nonatomic,copy) void (^selectionHandler)(NSString *bundle,BOOL compatible);
@end
