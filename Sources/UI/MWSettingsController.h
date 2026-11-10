// SPDX-License-Identifier: Apache-2.0
#import <UIKit/UIKit.h>
@interface MWSettingsController : UITableViewController
@property(nonatomic) BOOL showParkingSettings;
@property(nonatomic,copy) void (^floatingHandler)(BOOL enabled);
@end

