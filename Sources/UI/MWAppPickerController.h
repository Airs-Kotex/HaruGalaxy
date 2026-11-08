// SPDX-License-Identifier: Apache-2.0
#import <UIKit/UIKit.h>
#import "../Platform/MWApplicationCatalog.h"
@interface MWAppPickerController : UITableViewController
@property(nonatomic,copy) void (^selectionHandler)(MWApplication *application);
@end

