// SPDX-License-Identifier: Apache-2.0
#import "MWDiagnostics.h"
#import "../Core/MWLogStore.h"
#import <UIKit/UIKit.h>
#import <mach/mach.h>
#import <sys/utsname.h>
#import <sys/sysctl.h>
#import <dlfcn.h>
#import <unistd.h>

static const void *MWLogQueueKey=&MWLogQueueKey;
static NSUncaughtExceptionHandler *MWPreviousExceptionHandler;

@interface MWDiagnostics ()
- (void)writeEvent:(NSString *)event fields:(NSDictionary *)fields detailed:(BOOL)detailed;
@end

static void MWExceptionHandler(NSException *exception) {
    MWLog(@"exception.uncaught",@{@"name":exception.name ?: @"",@"reason":exception.reason ?: @"",@"stack":exception.callStackSymbols ?: @[]});
    [MWDiagnostics.shared flush];
    if(MWPreviousExceptionHandler) MWPreviousExceptionHandler(exception);
}

void MWLog(NSString *event,NSDictionary *fields) { [MWDiagnostics.shared writeEvent:event fields:fields detailed:NO]; }
void MWTrace(NSString *event,NSDictionary *fields) { [MWDiagnostics.shared writeEvent:event fields:fields detailed:YES]; }
NSDictionary *MWErrorFields(NSError *error) {
    return @{@"domain":error.domain ?: @"",@"code":@(error.code),@"message":error.localizedDescription ?: @""};
}

@implementation MWDiagnostics {
    dispatch_queue_t _queue;
    dispatch_source_t _heartbeat;
    MWLogStore _store;
    NSString *_directory;
    NSString *_applicationState;
    NSUInteger _sequence;
    BOOL _started;
    double _lastHeartbeat, _lastMainAck;
    NSString *_storageError;
}
+ (instancetype)shared {
    static MWDiagnostics *logger; static dispatch_once_t once;
    dispatch_once(&once,^{logger=[self new];}); return logger;
}
- (instancetype)init {
    if((self=[super init])) {
        _queue=dispatch_queue_create("io.github.uiharuxpro4milkyway.diagnostics",DISPATCH_QUEUE_SERIAL);
        dispatch_queue_set_specific(_queue,MWLogQueueKey,(void *)MWLogQueueKey,NULL);
        _sessionIdentifier=NSUUID.UUID.UUIDString;
        _applicationState=@"launching";
        NSString *documents=NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,NSUserDomainMask,YES).firstObject ?: NSTemporaryDirectory();
        _directory=[documents stringByAppendingPathComponent:@"Diagnostics"];
        NSError *error=nil;
        [[NSFileManager defaultManager] createDirectoryAtPath:_directory withIntermediateDirectories:YES
            attributes:@{NSFileProtectionKey:NSFileProtectionCompleteUntilFirstUserAuthentication,NSFilePosixPermissions:@0700} error:&error];
        _store.fd=-1;
        if(error || MWLogStoreOpen(&_store,_directory.fileSystemRepresentation,2*1024*1024,4)) {
            _storageError=error.localizedDescription ?: @"Unable to open log store";
            NSLog(@"Diagnostics store unavailable: %@",error.localizedDescription ?: @"open failed");
        }
        [NSUserDefaults.standardUserDefaults registerDefaults:@{@"diagnosticsDetailed":@YES}];
    }
    return self;
}
- (BOOL)detailed { return [NSUserDefaults.standardUserDefaults boolForKey:@"diagnosticsDetailed"]; }
- (void)setDetailed:(BOOL)detailed {
    [NSUserDefaults.standardUserDefaults setBool:detailed forKey:@"diagnosticsDetailed"];
    MWLog(@"diagnostics.level",@{@"detailed":@(detailed)});
}
- (void)writeEvent:(NSString *)event fields:(NSDictionary *)fields detailed:(BOOL)detailed {
    if(detailed && !self.detailed) return;
    NSString *name=[event copy]; NSDictionary *payload=[fields copy] ?: @{};
    void (^write)(void)=^{
        @autoreleasepool {
            NSDictionary *record=@{@"schema":@1,@"session":self.sessionIdentifier,@"sequence":@(++self->_sequence),
                @"time":@([NSDate date].timeIntervalSince1970),@"uptime":@(NSProcessInfo.processInfo.systemUptime),
                @"pid":@(getpid()),@"event":name ?: @"unknown",@"fields":payload};
            NSError *error=nil;
            NSData *json=[NSJSONSerialization isValidJSONObject:record] ? [NSJSONSerialization dataWithJSONObject:record options:0 error:&error] : nil;
            if(!json || json.length>128*1024) { self->_store.dropped++; return; }
            NSMutableData *line=[json mutableCopy]; [line appendBytes:"\n" length:1];
            if(MWLogStoreAppend(&self->_store,line.bytes,line.length)) {
                self->_storageError=@"A log write failed; check available storage and dropped record count";
                NSLog(@"Diagnostic write failed for %@",name);
            }
        }
    };
    if(dispatch_get_specific(MWLogQueueKey)) write(); else dispatch_async(_queue,write);
}
- (void)start {
    NSAssert(NSThread.isMainThread,@"Start diagnostics on main thread");
    if(_started) return; _started=YES;
    MWPreviousExceptionHandler=NSGetUncaughtExceptionHandler(); NSSetUncaughtExceptionHandler(MWExceptionHandler);
    NSDictionary *previous=[NSUserDefaults.standardUserDefaults dictionaryForKey:@"previousDiagnosticSession"];
    if(previous) MWLog(@"session.previous",previous);
    [NSUserDefaults.standardUserDefaults setObject:@{@"id":self.sessionIdentifier,@"cleanTerminationObserved":@NO,@"startedAt":@([NSDate date].timeIntervalSince1970)} forKey:@"previousDiagnosticSession"];
    MWLog(@"session.start",[self environmentSnapshot]);
    NSNotificationCenter *center=NSNotificationCenter.defaultCenter;
    for(NSString *name in @[UIApplicationDidEnterBackgroundNotification,UIApplicationWillEnterForegroundNotification,
        UIApplicationDidBecomeActiveNotification,UIApplicationWillResignActiveNotification,UIApplicationDidReceiveMemoryWarningNotification,
        UIApplicationWillTerminateNotification,UIDeviceOrientationDidChangeNotification])
        [center addObserver:self selector:@selector(applicationEvent:) name:name object:nil];
    _heartbeat=dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER,0,0,_queue);
    _lastHeartbeat=NSProcessInfo.processInfo.systemUptime; _lastMainAck=_lastHeartbeat;
    __weak typeof(self) weakSelf=self;
    dispatch_source_set_timer(_heartbeat,dispatch_time(DISPATCH_TIME_NOW,5*NSEC_PER_SEC),5*NSEC_PER_SEC,NSEC_PER_SEC/2);
    dispatch_source_set_event_handler(_heartbeat,^{[weakSelf heartbeat];}); dispatch_resume(_heartbeat);
    [self flush];
}
- (void)applicationEvent:(NSNotification *)notification {
    UIApplicationState state=UIApplication.sharedApplication.applicationState;
    MWLog(@"application.lifecycle",@{@"notification":notification.name,@"state":@(state)});
    dispatch_async(_queue,^{self->_applicationState=[NSString stringWithFormat:@"%ld",(long)state];});
    if([notification.name isEqual:UIApplicationWillTerminateNotification]) {
        [NSUserDefaults.standardUserDefaults setObject:@{@"id":self.sessionIdentifier,@"cleanTerminationObserved":@YES} forKey:@"previousDiagnosticSession"];
    }
    [self flush];
}
- (void)heartbeat {
    double now=NSProcessInfo.processInfo.systemUptime,interval=now-_lastHeartbeat; _lastHeartbeat=now;
    task_vm_info_data_t info={0}; mach_msg_type_number_t count=TASK_VM_INFO_COUNT;
    kern_return_t result=task_info(mach_task_self(),TASK_VM_INFO,(task_info_t)&info,&count);
    NSDictionary *fields=@{@"interval":@(interval),@"mainAckAge":@(now-_lastMainAck),@"applicationState":_applicationState,
        @"physicalFootprint":@(result==KERN_SUCCESS ? info.phys_footprint : 0),@"thermalState":@(NSProcessInfo.processInfo.thermalState),
        @"rotations":@(_store.rotations),@"dropped":@(_store.dropped)};
    [self writeEvent:interval>12 ? @"heartbeat.gap" : @"heartbeat" fields:fields detailed:interval<=12];
    dispatch_async(dispatch_get_main_queue(),^{
        double ack=NSProcessInfo.processInfo.systemUptime;
        dispatch_async(self->_queue,^{self->_lastMainAck=ack;});
    });
    MWLogStoreFlush(&_store);
}
- (NSDictionary *)environmentSnapshot {
    struct utsname identity={0}; uname(&identity);
    char build[128]={0}; size_t size=sizeof(build); sysctlbyname("kern.osversion",build,&size,NULL,0);
    NSDictionary *info=NSBundle.mainBundle.infoDictionary;
    NSMutableDictionary *capabilities=[NSMutableDictionary dictionary];
    NSDictionary *selectors=@{@"FBSceneManager":@"createSceneWithDefinition:initialParameters:",
        @"UIRootWindowScenePresentationBinder":@"initWithPriority:displayConfiguration:",
        @"BKSProcessAssertion":@"initWithPID:flags:reason:name:withHandler:",
        @"FBSWorkspaceScenesClient":@"sceneID:updateWithSettingsDiff:transitionContext:completion:"};
    for(NSString *name in selectors) capabilities[name]=@([NSClassFromString(name) instancesRespondToSelector:NSSelectorFromString(selectors[name])]);
    NSMutableDictionary *entitlements=[NSMutableDictionary dictionary];
    void *security=dlopen("/System/Library/Frameworks/Security.framework/Security",RTLD_LAZY);
    CFTypeRef (*createTask)(CFAllocatorRef)=security ? dlsym(security,"SecTaskCreateFromSelf") : NULL;
    CFTypeRef (*readEntitlement)(CFTypeRef,CFStringRef,CFErrorRef *)=security ? dlsym(security,"SecTaskCopyValueForEntitlement") : NULL;
    CFTypeRef task=createTask ? createTask(kCFAllocatorDefault) : NULL;
    if(task && readEntitlement) for(NSString *key in @[@"platform-application",@"com.apple.multitasking.unlimitedassertions",@"com.apple.frontboard.launchapplications",@"com.apple.runningboard.assertions.frontboard",@"com.apple.runningboard.primitiveattribute"]) {
        CFTypeRef value=readEntitlement(task,(__bridge CFStringRef)key,NULL);
        entitlements[key]=value ? CFBridgingRelease(value) : @"absent";
    }
    if(task) CFRelease(task);
    if(security) dlclose(security);
    return @{@"model":[NSString stringWithUTF8String:identity.machine] ?: @"unknown",
        @"systemVersion":NSProcessInfo.processInfo.operatingSystemVersionString,@"systemBuild":[NSString stringWithUTF8String:build] ?: @"unknown",
        @"version":info[@"CFBundleShortVersionString"] ?: @"unknown",@"build":info[@"CFBundleVersion"] ?: @"unknown",
        @"session":self.sessionIdentifier,@"pid":@(getpid()),@"uid":@(getuid()),@"capabilities":capabilities,@"entitlements":entitlements,
        @"detailed":@(self.detailed),@"trollstoreVersion":@"not detected",@"logPolicy":@"local only; 4 files x 2 MiB; no screen/input capture"};
}
- (void)flush {
    if(dispatch_get_specific(MWLogQueueKey)) MWLogStoreFlush(&_store);
    else dispatch_sync(_queue,^{MWLogStoreFlush(&self->_store);});
}
- (void)markProblem { MWLog(@"user.problem_marker",@{@"note":@"User marked the most recent issue"}); [self flush]; }
- (void)exportWithCompletion:(void (^)(NSURL *,NSError *))completion {
    NSDictionary *environment=[self environmentSnapshot];
    MWLog(@"diagnostics.export",@{});
    dispatch_async(_queue,^{
        MWLogStoreFlush(&self->_store);
        NSMutableDictionary *files=[NSMutableDictionary dictionary],*rawFiles=[NSMutableDictionary dictionary],*exportErrors=[NSMutableDictionary dictionary];
        for(unsigned i=0;i<4;i++) {
            NSString *name=[NSString stringWithFormat:@"events-%u.jsonl",i];
            NSString *path=[self->_directory stringByAppendingPathComponent:name];
            if(![NSFileManager.defaultManager fileExistsAtPath:path]) continue;
            NSError *readError=nil;
            NSData *bytes=[NSData dataWithContentsOfFile:path options:0 error:&readError];
            NSString *text=bytes ? [[NSString alloc] initWithData:bytes encoding:NSUTF8StringEncoding] : nil;
            if(text) files[name]=text;
            else {
                exportErrors[name]=readError.localizedDescription ?: @"Invalid UTF-8; original bytes retained in rawFiles";
                if(bytes) rawFiles[name]=@{@"encoding":@"base64",@"data":[bytes base64EncodedStringWithOptions:0]};
            }
        }
        NSDictionary *bundle=@{@"schema":@1,@"environment":environment,@"logs":files,@"rawFiles":rawFiles,@"exportErrors":exportErrors,
            @"rotations":@(self->_store.rotations),@"dropped":@(self->_store.dropped),@"recoveredTailBytes":@(self->_store.recoveredBytes),
            @"storage":@{@"available":@(self->_store.fd>=0),@"error":self->_storageError ?: @""}};
        NSError *error=nil;
        NSData *data=[NSJSONSerialization dataWithJSONObject:bundle options:NSJSONWritingPrettyPrinted error:&error];
        NSString *exportDirectory=[NSTemporaryDirectory() stringByAppendingPathComponent:@"MWDiagnosticExports"];
        [NSFileManager.defaultManager createDirectoryAtPath:exportDirectory withIntermediateDirectories:YES attributes:@{NSFilePosixPermissions:@0700} error:nil];
        // Retain at most three abandoned exports from interrupted share sheets.
        NSArray<NSURL *> *oldFiles=[NSFileManager.defaultManager contentsOfDirectoryAtURL:[NSURL fileURLWithPath:exportDirectory] includingPropertiesForKeys:@[NSURLCreationDateKey] options:0 error:nil];
        oldFiles=[oldFiles sortedArrayUsingComparator:^NSComparisonResult(NSURL *a,NSURL *b) {
            NSDate *ad=nil,*bd=nil; [a getResourceValue:&ad forKey:NSURLCreationDateKey error:nil]; [b getResourceValue:&bd forKey:NSURLCreationDateKey error:nil];
            return [ad ?: NSDate.distantPast compare:bd ?: NSDate.distantPast];
        }];
        for(NSUInteger i=0;i+2<oldFiles.count;i++) [NSFileManager.defaultManager removeItemAtURL:oldFiles[i] error:nil];
        NSString *filename=[NSString stringWithFormat:@"UiharuX-Diagnostics-%@.json",NSUUID.UUID.UUIDString];
        NSURL *url=[NSURL fileURLWithPath:[exportDirectory stringByAppendingPathComponent:filename]];
        if(data && ![data writeToURL:url options:NSDataWritingAtomic error:&error]) data=nil;
        dispatch_async(dispatch_get_main_queue(),^{completion(data ? url : nil,error);});
    });
}
- (void)clearWithCompletion:(void (^)(NSError *))completion {
    dispatch_async(_queue,^{
        MWLogStoreClose(&self->_store);
        for(unsigned i=0;i<4;i++) [[NSFileManager defaultManager] removeItemAtPath:[self->_directory stringByAppendingPathComponent:[NSString stringWithFormat:@"events-%u.jsonl",i]] error:nil];
        int result=MWLogStoreOpen(&self->_store,self->_directory.fileSystemRepresentation,2*1024*1024,4);
        self->_storageError=result ? @"Unable to reopen log store" : nil;
        [self writeEvent:@"diagnostics.cleared" fields:@{} detailed:NO];
        NSError *error=result ? [NSError errorWithDomain:@"MWDiagnostics" code:1 userInfo:@{NSLocalizedDescriptionKey:@"无法重新打开日志目录，请检查存储空间。"}] : nil;
        dispatch_async(dispatch_get_main_queue(),^{completion(error);});
    });
}
@end
