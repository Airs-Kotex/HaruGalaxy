// SPDX-License-Identifier: Apache-2.0
#import <Foundation/Foundation.h>

// Opens this installed application through LaunchServices. Acceptance is not
// proof of foreground visibility; the coordinator observes the normal scene.
FOUNDATION_EXPORT BOOL MWRequestOwnApplicationForeground(NSError **error);
// Callers select an installed application from their window registry.
FOUNDATION_EXPORT BOOL MWRequestApplicationForeground(NSString *bundleIdentifier, NSError **error);
