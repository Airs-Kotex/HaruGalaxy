// SPDX-License-Identifier: Apache-2.0
#pragma once
#include <stddef.h>
#include <stdint.h>
typedef struct {
    int fd;
    char directory[4096];
    size_t bytes, limit;
    unsigned files;
    uint64_t rotations, dropped, recoveredBytes;
} MWLogStore;
// Caller serializes access. Directory must already exist.
int MWLogStoreOpen(MWLogStore *store, const char *directory, size_t limit, unsigned files);
int MWLogStoreAppend(MWLogStore *store, const void *bytes, size_t length);
void MWLogStoreFlush(MWLogStore *store);
void MWLogStoreClose(MWLogStore *store);
