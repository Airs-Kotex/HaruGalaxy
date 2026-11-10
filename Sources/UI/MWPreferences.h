// SPDX-License-Identifier: Apache-2.0
#import <UIKit/UIKit.h>
#import "../Core/MWWindowModel.h"
FOUNDATION_EXPORT NSString *const MWPreferencesDidChangeNotification;
@interface MWPreferences : NSObject
+ (instancetype)shared;
@property(nonatomic) UIUserInterfaceStyle appearance;
@property(nonatomic) BOOL reduceMotion;
@property(nonatomic) BOOL edgeAlwaysExpanded;
@property(nonatomic) double parkedSizeFraction;
@property(nonatomic) double parkedAspectRatio;
@property(nonatomic,readonly) NSArray<NSString *> *recentBundleIDs;
- (void)recordUse:(NSString *)bundle;
- (CGRect)frameForBundle:(NSString *)bundle viewport:(CGRect)viewport fallback:(CGRect)fallback;
- (void)saveFrame:(CGRect)frame forBundle:(NSString *)bundle viewport:(CGRect)viewport;
- (MWResizeMode)resizeModeForBundle:(NSString *)bundle;
- (void)saveResizeMode:(MWResizeMode)mode forBundle:(NSString *)bundle;
- (BOOL)compatibleCanvasForBundle:(NSString *)bundle;
- (void)saveCompatibleCanvas:(BOOL)enabled forBundle:(NSString *)bundle;
@end

