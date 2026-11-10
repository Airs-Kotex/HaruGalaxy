// SPDX-License-Identifier: Apache-2.0
#import <Foundation/Foundation.h>
// Explicit user-close path. The handle must be the one resolved for the
// hosted session, not a later bundle lookup selecting a replacement process.
FOUNDATION_EXPORT void MWEndOwnedGuest(id process,void (^pending)(void),void (^completion)(NSError *error));
// A selected app is reset before attaching a new hosted scene, preventing
// the original and hosted players from coexisting in the reused process.
FOUNDATION_EXPORT BOOL MWGuestResetPending(NSString *bundle);
FOUNDATION_EXPORT void MWResetGuestForHosting(NSString *bundle,id process,void (^pending)(void),void (^completion)(NSError *error));
