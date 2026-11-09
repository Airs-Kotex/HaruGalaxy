// SPDX-License-Identifier: Apache-2.0
#import <Foundation/Foundation.h>

// Registers only the real environment derived from an owned scene identity.
// Invalidating removes the mapping after its presenters have been torn down.
@interface MWSceneInputEnvironment : NSObject
- (instancetype)initWithScene:(id)scene identifier:(NSString *)identifier processIdentifier:(pid_t)pid;
- (void)invalidate;
@end
