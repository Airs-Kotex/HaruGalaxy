// SPDX-License-Identifier: Apache-2.0
#import <UIKit/UIKit.h>
#import "../Platform/MWApplicationCatalog.h"
@interface MWAppPickerController : UITableViewController
@property(nonatomic,copy) void (^selectionHandler)(MWApplication *application);
@property(nonatomic,copy) void (^cancellationHandler)(void);
@property(nonatomic,copy) void (^searchFallbackHandler)(NSString *query);
@property(nonatomic,copy) NSString *initialQuery;
@property(nonatomic) BOOL automaticallyFocusSearch;
@end

