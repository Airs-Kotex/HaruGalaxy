#include "MWLogStore.h"
#include <assert.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <unistd.h>
#include <fcntl.h>

int main(void) {
    char directory[]="/tmp/mw-log-test-XXXXXX";
    assert(mkdtemp(directory));
    MWLogStore store;
    assert(MWLogStoreOpen(&store,directory,128,4)==0);
    char record[64];
    for(int i=0;i<100;i++) {
        int length=snprintf(record,sizeof(record),"{\"sequence\":%d}\n",i);
        assert(MWLogStoreAppend(&store,record,(size_t)length)==0);
    }
    assert(store.rotations>0);
    char huge[129]; memset(huge,'x',sizeof(huge));
    assert(MWLogStoreAppend(&store,huge,sizeof(huge))==-2);
    assert(store.dropped==1);
    MWLogStoreFlush(&store); MWLogStoreClose(&store);
    int previous=-1,count=0;
    for(int i=3;i>=0;i--) {
        char path[256]; snprintf(path,sizeof(path),"%s/events-%d.jsonl",directory,i);
        struct stat st; assert(stat(path,&st)==0 && st.st_size<=128);
        assert((st.st_mode&0777)==0600);
        FILE *file=fopen(path,"r"); assert(file);
        while(fgets(record,sizeof(record),file)) {
            int sequence=-1; assert(sscanf(record,"{\"sequence\":%d}",&sequence)==1);
            assert(sequence>previous && strchr(record,'\n')); previous=sequence; count++;
        }
        fclose(file);
    }
    assert(previous==99 && count>0 && count<100);
    assert(MWLogStoreOpen(&store,directory,128,4)==0);
    assert(MWLogStoreAppend(&store,"{\"sequence\":100}\n",17)==0);
    MWLogStoreClose(&store);
    char current[256]; snprintf(current,sizeof(current),"%s/events-0.jsonl",directory);
    int fd=open(current,O_WRONLY|O_APPEND); assert(fd>=0);
    assert(write(fd,"\xF0\x9F",2)==2); close(fd);
    assert(MWLogStoreOpen(&store,directory,128,4)==0);
    assert(store.recoveredBytes==2);
    assert(MWLogStoreAppend(&store,"{\"sequence\":101}\n",17)==0);
    MWLogStoreClose(&store);
    FILE *recovered=fopen(current,"r"); assert(recovered);
    while(fgets(record,sizeof(record),recovered)) {
        int sequence=-1; assert(sscanf(record,"{\"sequence\":%d}",&sequence)==1 && strchr(record,'\n'));
    }
    fclose(recovered);
    for(int i=0;i<4;i++) {
        char path[256]; snprintf(path,sizeof(path),"%s/events-%d.jsonl",directory,i); unlink(path);
    }
    char path[256]; snprintf(path,sizeof(path),"%s/events-0.jsonl",directory);
    assert(symlink("/dev/null",path)==0);
    assert(MWLogStoreOpen(&store,directory,128,4)==-1);
    unlink(path); rmdir(directory);
    puts("PASS: bounded log rotation, complete ordered records, reopen, permissions and symlink rejection");
}
