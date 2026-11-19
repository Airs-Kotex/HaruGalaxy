// SPDX-License-Identifier: Apache-2.0
// Read-only selectors from the pinned FrontBoard/UIKit runtime headers.
#import "MWSceneLayerDiagnostics.h"
#import "MWRuntimeDiagnostics.h"

static NSArray *MWLayerList(id value) {
    if([value isKindOfClass:NSOrderedSet.class]) return [value array];
    if([value isKindOfClass:NSSet.class]) return [value allObjects];
    return [value isKindOfClass:NSArray.class] ? value : nil;
}
static NSDictionary *MWLayerGroup(id value) {
    NSArray *list=MWLayerList(value);
    if(!list) return @{@"available":@NO};
    NSMutableArray *samples=[NSMutableArray array];
    for(id layer in list) {
        if(samples.count==16) break;
        [samples addObject:@{@"keyboard":MWRuntimeBoolValue(layer,@"isKeyboardLayer"),
            @"keyboardProxy":MWRuntimeBoolValue(layer,@"isKeyboardProxyLayer"),
            @"type":MWRuntimeIntegerValue(layer,@"type")}];
    }
    // Only category counts and types, no context IDs or guest contents.
    return @{@"available":@YES,@"count":@(list.count),@"truncated":@(list.count>16),@"layers":samples};
}
// Read only. Bounds, alpha and class names reveal the compositor boundary
// without exporting video, view text, context IDs or a screenshot.
static NSArray *MWDisplayBackdropViews(id root) {
    if (![root isKindOfClass:UIView.class]) return @[];
    NSMutableArray<UIView *> *pending=[NSMutableArray arrayWithObject:root];
    NSMutableArray *samples=[NSMutableArray array];
    for (NSUInteger index=0;index<pending.count && index<16;index++) {
        UIView *view=pending[index];
        [samples addObject:@{@"class":NSStringFromClass(view.class),
            @"backgroundAlpha":@(view.backgroundColor ? CGColorGetAlpha(view.backgroundColor.CGColor) : 0),
            @"layerBackgroundAlpha":@(view.layer.backgroundColor ? CGColorGetAlpha(view.layer.backgroundColor) : 0),
            @"opaque":@(view.opaque),@"layerOpaque":@(view.layer.opaque),@"alpha":@(view.alpha),
            @"size":@[@(view.bounds.size.width),@(view.bounds.size.height)]}];
        for (UIView *child in view.subviews) {
            if (pending.count>=16) break;
            [pending addObject:child];
        }
    }
    return samples;
}
NSDictionary *MWSceneLayerSnapshot(id scene,id presenter) {
    id manager=MWRuntimeObjectValue(scene,@"layerManager");
    id view=MWRuntimeObjectValue(presenter,@"presentationView");
    id container=MWRuntimeObjectValue(view,@"hostContainerView");
    id context=MWRuntimeObjectValue(presenter,@"presentationContext");
    return @{@"registered":MWLayerGroup(MWRuntimeObjectValue(manager,@"layers")),
        @"hosted":MWLayerGroup(MWRuntimeObjectValue(container,@"hostedLayers")),
        @"notHosted":MWLayerGroup(MWRuntimeObjectValue(container,@"nonHostedLayers")),
        @"canShowKeyboardLayer":MWRuntimeBoolValue(container,@"_canShowKeyboardLayer"),
        @"presentedLayerTypes":MWRuntimeIntegerValue(context,@"presentedLayerTypes"),
        @"clientBackgroundStyle":MWRuntimeIntegerValue(MWRuntimeObjectValue(scene,@"clientSettings"),@"backgroundStyle"),
        @"presentationBackdropViews":MWDisplayBackdropViews(view),
        @"scope":@"layer_registration_and_hosting_not_pixels_or_touch_delivery"};
}
