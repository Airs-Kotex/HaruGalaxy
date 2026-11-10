// SPDX-License-Identifier: Apache-2.0
#import <Foundation/Foundation.h>
// Explicit user-close only. The handle must be the one resolved for the
// hosted session, not a bundle lookup that could select a replacement process.
FOUNDATION_EXPORT void MWEndOwnedGuest(id process,void (^pending)(void),void (^completion)(NSError *error));
