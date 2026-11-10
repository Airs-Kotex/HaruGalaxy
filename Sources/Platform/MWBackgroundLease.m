// SPDX-License-Identifier: Apache-2.0
// Selectors/flags documented by theos/headers/AssertionServices/BKSProcessAssertion.h.
#import "MWBackgroundLease.h"
#import "MWPrivate.h"
#import "../Diagnostics/MWDiagnostics.h"
#import <unistd.h>
NSString *const MWBackgroundLeaseDidChangeNotification=@"MWBackgroundLeaseDidChange";

@interface NSObject (MWBKSAssertion)
- (id)initWithPID:(NSInteger)pid flags:(NSUInteger)flags reason:(NSUInteger)reason name:(NSString *)name withHandler:(id)handler;
- (BOOL)valid;
- (void)invalidate;
@end

@implementation MWBackgroundLease {
    id _assertion;
    dispatch_source_t _monitor;
    BOOL _lastValid;
    pid_t _pid;
}
- (BOOL)acquireWithError:(NSError **)error {
    return [self acquireForProcess:getpid() name:@"HaruGalaxy floating workspace" error:error];
}
- (BOOL)acquireForProcess:(pid_t)pid name:(NSString *)name error:(NSError **)error {
    [self invalidate];
    if(pid<=0) { if(error) *error=MWError(40,@"应用进程尚未就绪。"); return NO; }
    _pid=pid;
    MWLoadPrivateFrameworks();
    Class cls=NSClassFromString(@"BKSProcessAssertion");
    SEL initializer=@selector(initWithPID:flags:reason:name:withHandler:);
    if(![cls instancesRespondToSelector:initializer] || ![cls instancesRespondToSelector:@selector(valid)] || ![cls instancesRespondToSelector:@selector(invalidate)]) {
        if(error) *error=MWError(40,@"当前系统缺少后台执行接口，请导出诊断日志。");
        MWLog(@"background.unavailable",@{}); return NO;
    }
    @try {
        // Guest keepalive prevents suspension but permits normal CPU throttling
        // and idle sleep. The host retains its existing execution policy.
        NSUInteger flags=pid==getpid() ? 7 : 5;
        _assertion=[[cls alloc] initWithPID:pid flags:flags reason:10005 name:name withHandler:nil];
        if(!_assertion) { if(error) *error=MWError(41,@"系统未创建后台执行请求。"); return NO; }
        _lastValid=[_assertion valid];
        MWLog(@"background.requested",@{@"valid":@(_lastValid),@"pid":@(pid),@"flags":@(flags),@"reason":@10005,@"guest":@(pid!=getpid())});
        __weak typeof(self) weakSelf=self;
        _monitor=dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER,0,0,dispatch_get_main_queue());
        dispatch_source_set_timer(_monitor,dispatch_time(DISPATCH_TIME_NOW,NSEC_PER_SEC),5*NSEC_PER_SEC,NSEC_PER_SEC/4);
        dispatch_source_set_event_handler(_monitor,^{
            MWBackgroundLease *lease=weakSelf;
            if(!lease) return;
            BOOL valid=lease.valid;
            MWTrace(@"background.status",@{@"valid":@(valid),@"pid":@(lease->_pid)});
            if(valid!=lease->_lastValid) {
                MWLog(valid ? @"background.acquired" : @"background.invalidated",@{@"pid":@(lease->_pid)});
                [NSNotificationCenter.defaultCenter postNotificationName:MWBackgroundLeaseDidChangeNotification object:lease];
            }
            lease->_lastValid=valid;
        });
        dispatch_resume(_monitor); return YES;
    } @catch(NSException *exception) {
        MWLog(@"background.exception",@{@"reason":exception.reason ?: @"unknown"});
        [self invalidate];
        if(error) *error=MWError(42,[NSString stringWithFormat:@"后台请求失败：%@",exception.reason]); return NO;
    }
}
- (BOOL)valid {
    @try { return _assertion && [_assertion valid]; }
    @catch(NSException *exception) { (void)exception; return NO; }
}
- (void)invalidate {
    if(_monitor) { dispatch_source_cancel(_monitor); _monitor=nil; }
    if(_assertion) {
        @try { [_assertion invalidate]; } @catch(NSException *exception) { (void)exception; }
        _assertion=nil; MWLog(@"background.released",@{@"pid":@(_pid)});
    }
    _pid=0;
}
- (void)dealloc { [self invalidate]; }
@end
