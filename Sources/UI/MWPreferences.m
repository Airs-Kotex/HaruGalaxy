// SPDX-License-Identifier: Apache-2.0
#import "MWPreferences.h"
#import "../Core/MWWindowModel.h"
NSString *const MWPreferencesDidChangeNotification=@"MWPreferencesDidChange";

@implementation MWPreferences
- (BOOL)keepMinimizedAlive { return [NSUserDefaults.standardUserDefaults boolForKey:@"keepMinimizedAlive"]; }
- (void)setKeepMinimizedAlive:(BOOL)value {
    [NSUserDefaults.standardUserDefaults setBool:value forKey:@"keepMinimizedAlive"];
    [[NSNotificationCenter defaultCenter] postNotificationName:MWPreferencesDidChangeNotification object:self];
}
- (double)parkedSizeFraction {
    id value=[NSUserDefaults.standardUserDefaults objectForKey:@"parkedSizeFraction"];
    double size=[value isKindOfClass:NSNumber.class] ? [value doubleValue] : 0.36;
    return isfinite(size) ? MIN(0.5,MAX(0.18,size)) : 0.36;
}
- (void)setParkedSizeFraction:(double)value {
    if(!isfinite(value)) return;
    [NSUserDefaults.standardUserDefaults setDouble:MIN(0.5,MAX(0.18,value)) forKey:@"parkedSizeFraction"];
    [[NSNotificationCenter defaultCenter] postNotificationName:MWPreferencesDidChangeNotification object:self];
}
- (double)parkedAspectRatio {
    double value=[NSUserDefaults.standardUserDefaults doubleForKey:@"parkedAspectRatio"];
    for(NSNumber *ratio in @[@0,@1,@(4.0/3),@(3.0/4),@(16.0/9),@(9.0/16)])
        if(fabs(value-ratio.doubleValue)<0.0001) return ratio.doubleValue;
    return 0;
}
- (void)setParkedAspectRatio:(double)value {
    for(NSNumber *ratio in @[@0,@1,@(4.0/3),@(3.0/4),@(16.0/9),@(9.0/16)]) if(fabs(value-ratio.doubleValue)<0.0001) {
        [NSUserDefaults.standardUserDefaults setDouble:ratio.doubleValue forKey:@"parkedAspectRatio"];
        [[NSNotificationCenter defaultCenter] postNotificationName:MWPreferencesDidChangeNotification object:self]; return;
    }
}
- (BOOL)compatibleCanvasForBundle:(NSString *)bundle {
    id value=[NSUserDefaults.standardUserDefaults dictionaryForKey:@"compatibleCanvases"][bundle];
    return [value isKindOfClass:NSNumber.class] && [value boolValue];
}
- (void)saveCompatibleCanvas:(BOOL)enabled forBundle:(NSString *)bundle {
    if(!bundle.length) return;
    NSMutableDictionary *values=[[NSUserDefaults.standardUserDefaults dictionaryForKey:@"compatibleCanvases"] mutableCopy] ?: [NSMutableDictionary dictionary];
    if(values.count>=50 && !values[bundle]) [values removeAllObjects];
    if(enabled) values[bundle]=@YES; else [values removeObjectForKey:bundle];
    [NSUserDefaults.standardUserDefaults setObject:values forKey:@"compatibleCanvases"];
}
- (MWResizeMode)resizeModeForBundle:(NSString *)bundle {
    NSNumber *value=[NSUserDefaults.standardUserDefaults dictionaryForKey:@"windowResizeModes"][bundle];
    return [value isKindOfClass:NSNumber.class] && value.integerValue==MWResizeProportional ? MWResizeProportional : MWResizeFree;
}
- (void)saveResizeMode:(MWResizeMode)mode forBundle:(NSString *)bundle {
    NSMutableDictionary *modes=[[NSUserDefaults.standardUserDefaults dictionaryForKey:@"windowResizeModes"] mutableCopy] ?: [NSMutableDictionary dictionary];
    if(modes.count>=50 && !modes[bundle]) [modes removeAllObjects];
    modes[bundle]=@(mode); [NSUserDefaults.standardUserDefaults setObject:modes forKey:@"windowResizeModes"];
}
+ (instancetype)shared {
    static MWPreferences *prefs; static dispatch_once_t once;
    dispatch_once(&once,^{prefs=[self new];}); return prefs;
}
- (UIUserInterfaceStyle)appearance {
    NSInteger v=[NSUserDefaults.standardUserDefaults integerForKey:@"appearance"];
    return v>=0 && v<=2 ? v : UIUserInterfaceStyleUnspecified;
}
- (void)setAppearance:(UIUserInterfaceStyle)value {
    [NSUserDefaults.standardUserDefaults setInteger:value forKey:@"appearance"];
    [[NSNotificationCenter defaultCenter] postNotificationName:MWPreferencesDidChangeNotification object:self];
}
- (BOOL)reduceMotion { return UIAccessibilityIsReduceMotionEnabled() || [NSUserDefaults.standardUserDefaults boolForKey:@"reduceMotion"]; }
- (void)setReduceMotion:(BOOL)value {
    [NSUserDefaults.standardUserDefaults setBool:value forKey:@"reduceMotion"];
    [[NSNotificationCenter defaultCenter] postNotificationName:MWPreferencesDidChangeNotification object:self];
}
- (BOOL)edgeAlwaysExpanded { return [NSUserDefaults.standardUserDefaults boolForKey:@"edgeAlwaysExpanded"]; }
- (void)setEdgeAlwaysExpanded:(BOOL)value {
    [NSUserDefaults.standardUserDefaults setBool:value forKey:@"edgeAlwaysExpanded"];
    [[NSNotificationCenter defaultCenter] postNotificationName:MWPreferencesDidChangeNotification object:self];
}
- (NSArray<NSString *> *)recentBundleIDs {
    NSArray *saved=[NSUserDefaults.standardUserDefaults arrayForKey:@"recentApps"] ?: @[];
    NSMutableArray *valid=[NSMutableArray array];
    for(id entry in saved) if([entry isKindOfClass:NSString.class] && [entry length] && valid.count<12) [valid addObject:entry];
    return valid;
}
- (void)recordUse:(NSString *)bundle {
    NSMutableArray *recent=[self.recentBundleIDs mutableCopy];
    [recent removeObject:bundle]; [recent insertObject:bundle atIndex:0];
    while(recent.count>12) [recent removeLastObject];
    [NSUserDefaults.standardUserDefaults setObject:recent forKey:@"recentApps"];
}
- (CGRect)frameForBundle:(NSString *)bundle viewport:(CGRect)v fallback:(CGRect)fallback {
    id record=[NSUserDefaults.standardUserDefaults dictionaryForKey:@"windowFrames"][bundle];
    if(![record isKindOfClass:NSDictionary.class]) return fallback;
    for(NSString *key in @[@"x",@"y",@"w",@"h"])
        if(![record[key] isKindOfClass:NSNumber.class] || !isfinite([record[key] doubleValue])) return fallback;
    MWRect rect={v.origin.x+[record[@"x"] doubleValue]*v.size.width,v.origin.y+[record[@"y"] doubleValue]*v.size.height,
        [record[@"w"] doubleValue]*v.size.width,[record[@"h"] doubleValue]*v.size.height};
    MWRect result=MWConstrainExistingRect(rect,(MWRect){v.origin.x,v.origin.y,v.size.width,v.size.height});
    return CGRectMake(result.x,result.y,result.width,result.height);
}
- (void)saveFrame:(CGRect)r forBundle:(NSString *)bundle viewport:(CGRect)v {
    if(v.size.width<=0 || v.size.height<=0 || !bundle.length) return;
    MWRect rect=MWConstrainExistingRect((MWRect){r.origin.x,r.origin.y,r.size.width,r.size.height},(MWRect){v.origin.x,v.origin.y,v.size.width,v.size.height});
    NSMutableDictionary *frames=[[NSUserDefaults.standardUserDefaults dictionaryForKey:@"windowFrames"] mutableCopy] ?: [NSMutableDictionary dictionary];
    if(frames.count>=50 && !frames[bundle]) [frames removeAllObjects];
    frames[bundle]=@{@"x":@((rect.x-v.origin.x)/v.size.width),@"y":@((rect.y-v.origin.y)/v.size.height),@"w":@(rect.width/v.size.width),@"h":@(rect.height/v.size.height)};
    [NSUserDefaults.standardUserDefaults setObject:frames forKey:@"windowFrames"];
}
@end

