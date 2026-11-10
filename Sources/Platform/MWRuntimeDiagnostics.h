// SPDX-License-Identifier: Apache-2.0
#import <UIKit/UIKit.h>
// Metadata and allowlisted zero-argument getters only; never object descriptions
// or text/clipboard/responder contents.
FOUNDATION_EXPORT NSDictionary *MWRuntimeMethodSnapshot(id object,NSString *selector);
FOUNDATION_EXPORT id MWRuntimeObjectValue(id object,NSString *selector);
FOUNDATION_EXPORT id MWRuntimeBoolValue(id object,NSString *selector);
FOUNDATION_EXPORT id MWRuntimeInsetsValue(id object,NSString *selector);
FOUNDATION_EXPORT id MWRuntimeIntegerValue(id object,NSString *selector);
FOUNDATION_EXPORT NSDictionary *MWDiagnosticWindow(UIWindow *window);
