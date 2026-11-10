// SPDX-License-Identifier: Apache-2.0
#pragma once
#include <stdbool.h>
#include <stdint.h>

typedef enum {
    MWOrientationSourceNone,
    MWOrientationSourceSystem,
    MWOrientationSourcePhysical,
    MWOrientationSourceDevice
} MWOrientationSource;

typedef struct {
    uint64_t generation;
    bool active;
    int orientation, systemOrientation, physicalOrientation, deviceOrientation;
    MWOrientationSource source;
} MWOrientationState;

// UIKit interface orientation values 1...4; unknown/flat values are rejected.
bool MWOrientationIsValid(int orientation);
uint64_t MWOrientationSetActive(MWOrientationState *state,bool active);
bool MWOrientationObserveSystem(MWOrientationState *state,uint64_t generation,int orientation);
bool MWOrientationObservePhysical(MWOrientationState *state,uint64_t generation,int orientation);
// UIDevice's cached value is only a foreground fallback. Initial seeding cannot
// supersede system input or a fresh gravity observation in this generation.
bool MWOrientationObserveDevice(MWOrientationState *state,uint64_t generation,int orientation,bool foreground,bool seed);
int MWWorkspaceOrientation(const MWOrientationState *state,bool floating,int hostOrientation);
int MWWorkspaceQuarterTurns(int hostOrientation,int targetOrientation);
// Masks use UIKit's (1 << UIInterfaceOrientation); zero means unavailable.
typedef struct {
    unsigned retainedMask;
    bool maskConfirmed; // A client direction has matched this mask; not rendering proof.
} MWGuestOrientationState;
// Keep this state per guest session and consume observations in callback order.
// Every nonzero mask starts a new confirmation cycle, including repeated masks.
// Unknown masks preserve it until a matching client then reports a conflict.
unsigned MWGuestRetainOrientationMask(MWGuestOrientationState *state,unsigned observed,int clientOrientation);
// clientMask is the session's retained mask. Without one, use declarations.
// A client direction alone may echo a host request and must not lock rotation.
int MWGuestOrientation(int workspace,unsigned declaredMask,unsigned clientMask,int clientOrientation,int previous);
