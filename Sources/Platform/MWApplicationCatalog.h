// SPDX-License-Identifier: Apache-2.0
#import <UIKit/UIKit.h>
@interface MWApplication : NSObject
@property(nonatomic,copy) NSString *bundleIdentifier;
@property(nonatomic,copy) NSString *name;
@property(nonatomic,readonly) UIImage *icon;
@end

@interface MWApplicationCatalog : NSObject
+ (NSArray<MWApplication *> *)applicationsWithError:(NSError **)error;
@end

