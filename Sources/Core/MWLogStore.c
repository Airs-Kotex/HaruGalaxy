// SPDX-License-Identifier: Apache-2.0
#include "MWLogStore.h"
#include <stdio.h>
#include <string.h>
#include <unistd.h>
#include <fcntl.h>
#include <sys/stat.h>
#include <errno.h>

static int path_for(MWLogStore *s,unsigned index,char *path,size_t size) {
    int count=snprintf(path,size,"%s/events-%u.jsonl",s->directory,index);
    return count<0 || (size_t)count>=size ? -1 : 0;
}
static int open_current(MWLogStore *s) {
    char path[4200];
    if(path_for(s,0,path,sizeof(path))) return -1;
    s->fd=open(path,O_RDWR|O_CREAT|O_APPEND|O_CLOEXEC|O_NOFOLLOW,0600);
    if(s->fd<0) return -1;
    struct stat st;
    if(fstat(s->fd,&st) || !S_ISREG(st.st_mode)) { close(s->fd); s->fd=-1; return -1; }
    s->bytes=(size_t)st.st_size;
    // A terminated writer may have left part of a JSON record (or UTF-8 scalar).
    // Preserve every complete earlier line before accepting another append.
    if(s->bytes) {
        char buffer[4096]; off_t end=st.st_size,complete=0;
        while(end>0) {
            size_t size=(size_t)(end>(off_t)sizeof(buffer) ? sizeof(buffer) : (size_t)end);
            ssize_t count=pread(s->fd,buffer,size,end-(off_t)size);
            if(count<0 && errno==EINTR) continue;
            if(count!=(ssize_t)size) { close(s->fd); s->fd=-1; return -1; }
            for(ssize_t i=count-1;i>=0;i--) if(buffer[i]=='\n') { complete=end-(off_t)size+i+1; break; }
            if(complete) break;
            end-=(off_t)size;
        }
        if(complete<st.st_size) {
            if(ftruncate(s->fd,complete)) { close(s->fd); s->fd=-1; return -1; }
            s->recoveredBytes+=(uint64_t)(st.st_size-complete); s->bytes=(size_t)complete;
        }
    }
    return 0;
}
int MWLogStoreOpen(MWLogStore *s,const char *directory,size_t limit,unsigned files) {
    memset(s,0,sizeof(*s)); s->fd=-1;
    if(!directory || strlen(directory)>=sizeof(s->directory) || limit<64 || files<1 || files>16) return -1;
    strcpy(s->directory,directory); s->limit=limit; s->files=files;
    return open_current(s);
}
static int rotate(MWLogStore *s) {
    MWLogStoreClose(s);
    char from[4200],to[4200];
    for(unsigned i=s->files-1;i>0;i--) {
        if(path_for(s,i-1,from,sizeof(from)) || path_for(s,i,to,sizeof(to))) return -1;
        if(rename(from,to) && errno!=ENOENT) return -1;
    }
    if(path_for(s,0,from,sizeof(from))) return -1;
    // For files==1 there was no rename. Only our owned current log is removed.
    if(s->files==1 && unlink(from) && errno!=ENOENT) return -1;
    s->rotations++; return open_current(s);
}
int MWLogStoreAppend(MWLogStore *s,const void *data,size_t length) {
    if(!length) return 0;
    if(!data || length>s->limit) { s->dropped++; return -2; }
    if(s->fd<0) { s->dropped++; return -1; }
    if(s->bytes>s->limit-length && rotate(s)) { s->dropped++; return -1; }
    const char *cursor=data; size_t remaining=length;
    size_t original=s->bytes;
    while(remaining) {
        ssize_t written=write(s->fd,cursor,remaining);
        if(written<0 && errno==EINTR) continue;
        if(written<=0) {
            s->dropped++;
            if(!ftruncate(s->fd,(off_t)original)) s->bytes=original;
            else MWLogStoreClose(s);
            return -1;
        }
        remaining-=(size_t)written; cursor+=written; s->bytes+=(size_t)written;
    }
    return 0;
}
void MWLogStoreFlush(MWLogStore *s) { if(s->fd>=0) fsync(s->fd); }
void MWLogStoreClose(MWLogStore *s) {
    if(s->fd>=0) { close(s->fd); s->fd=-1; }
}
