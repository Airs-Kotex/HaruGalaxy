// SPDX-License-Identifier: Apache-2.0
#import "MWApplicationCatalog.h"
#import "MWPrivate.h"

@implementation MWApplication
- (UIImage *)icon {
    @try {
        if([UIImage respondsToSelector:@selector(_applicationIconImageForBundleIdentifier:format:scale:)])
            return [UIImage _applicationIconImageForBundleIdentifier:self.bundleIdentifier format:0 scale:UIScreen.mainScreen.scale];
    } @catch(NSException *exception) { (void)exception; }
    return [UIImage systemImageNamed:@"app.fill"];
}
@end

@implementation MWApplicationCatalog
+ (NSArray<MWApplication *> *)applicationsWithError:(NSError **)error {
    MWLoadPrivateFrameworks();
    Class cls=NSClassFromString(@"LSApplicationWorkspace");
    if(![cls respondsToSelector:@selector(defaultWorkspace)]) {
        if(error) *error=MWError(1,@"无法读取应用列表，请使用 TrollStore 安装此应用。");
        return @[];
    }
    NSMutableArray *result=[NSMutableArray array];
    @try {
        for(LSApplicationProxy *proxy in [[cls defaultWorkspace] allInstalledApplications]) {
            NSString *identifier=proxy.bundleIdentifier;
            if(!identifier.length || [identifier isEqual:NSBundle.mainBundle.bundleIdentifier]) continue;
            if(proxy.launchProhibited || proxy.placeholder || proxy.removedSystemApp || [proxy.appTags containsObject:@"hidden"]) continue;
            if(![@[@"User",@"System"] containsObject:proxy.applicationType]) continue;
            MWApplication *app=[MWApplication new];
            app.bundleIdentifier=identifier; app.name=proxy.localizedName ?: identifier;
            [result addObject:app];
        }
    } @catch(NSException *exception) {
        if(error) *error=MWError(2,[NSString stringWithFormat:@"读取应用列表失败：%@",exception.reason]);
        return @[];
    }
    return [result sortedArrayUsingComparator:^NSComparisonResult(MWApplication *a,MWApplication *b) {
        return [a.name localizedStandardCompare:b.name];
    }];
}
@end

