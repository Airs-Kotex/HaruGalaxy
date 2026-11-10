// SPDX-License-Identifier: Apache-2.0
// RunningBoard method declarations: pinned MTACS runtime headers.
#import "MWGuestTermination.h"
#import "MWPrivate.h"
#import "MWRuntimeDiagnostics.h"
#import "../Core/MWRuntimeTypes.h"
#import "../Core/MWGuestCloseState.h"
#import "../Diagnostics/MWDiagnostics.h"
#import <objc/runtime.h>
#include <signal.h>
#include <unistd.h>
#include <errno.h>
#include <string.h>

@interface NSObject (MWTerminateAPI)
+ (id)predicateMatchingHandle:(id)handle;
+ (id)defaultContextWithExplanation:(NSString *)explanation;
- (instancetype)initWithPredicate:(id)predicate context:(id)context;
- (BOOL)execute:(NSError **)error;
- (void)setExplanation:(NSString *)explanation;
@end
static BOOL MWTerminateMethod(id object,SEL selector,char result,const char *arguments) {
    if(!object || ![object respondsToSelector:selector]) return NO;
    Method method=class_getInstanceMethod(object_getClass(object),selector);
    if(!method || method_getNumberOfArguments(method)!=strlen(arguments)+2) return NO;
    char type[128]={0}; method_getReturnType(method,type,sizeof(type));
    if(!MWObjCTypeMatches(type,result)) return NO;
    for(unsigned i=0;i<strlen(arguments);i++) {
        method_getArgumentType(method,i+2,type,sizeof(type));
        if(!MWObjCTypeMatches(type,arguments[i])) return NO;
    }
    return YES;
}
@interface MWGuestExitObservation : NSObject {
@public MWGuestCloseState state;
}
@property(nonatomic) pid_t pid;
@property(nonatomic,copy) void (^pending)(void);
@property(nonatomic,copy) void (^completion)(NSError *);
- (void)poll;
- (void)finish:(NSError *)error;
@end
@implementation MWGuestExitObservation
- (void)finish:(NSError *)error {
    if(!self.completion) return;
    void (^completion)(NSError *)=self.completion;
    self.completion=nil; self.pending=nil;
    if(completion) completion(error);
}
- (void)poll {
    if(MWGuestCloseDone(&state)) return;
    // This never sends a signal. Permission failures and a reused live PID
    // are not success. The request itself targets the original RBS handle.
    errno=0; int exists=kill(self.pid,0); int status=errno;
    MWGuestCloseAction action=MWGuestCloseObserve(&state,CACurrentMediaTime(),MWGuestProcessAbsent(exists,status));
    if(action==MWGuestCloseCompleteExit) {
        MWLog(@"guest.user_close_exited",@{@"pid":@(self.pid),@"confirmed":@YES});
        [self finish:nil]; return;
    }
    if(action==MWGuestCloseReportPending) {
        MWLog(@"guest.user_close_request_pending",@{@"pid":@(self.pid),@"cancelled":@NO});
        if(self.pending) self.pending();
    }
    // Continue observing a late exit even if execute is still blocked. A
    // timeout cannot cancel that XPC or safely allow a duplicate request.
    double delay=state.reportedPending ? 1 : 0.1;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(delay*NSEC_PER_SEC)),dispatch_get_main_queue(),^{[self poll];});
}
@end
void MWEndOwnedGuest(id process,void (^pending)(void),void (^completion)(NSError *)) {
    NSCAssert(NSThread.isMainThread,@"Guest termination is initiated on the main thread");
    Class handleClass=NSClassFromString(@"RBSProcessHandle");
    if(!process) { completion(nil); return; }
    pid_t pid=[process isKindOfClass:handleClass] ? [(RBSProcessHandle *)process pid] : 0;
    if(pid<=1 || pid==getpid()) { completion(MWError(70,@"未能核实小窗应用的进程，未发送结束请求。")); return; }
    errno=0; int exists=kill(pid,0); int status=errno;
    if(MWGuestProcessAbsent(exists,status)) {
        MWLog(@"guest.user_close_exited",@{@"pid":@(pid),@"confirmed":@YES,@"beforeRequest":@YES});
        completion(nil); return;
    }
    // The predicate binds the original process instance (including its
    // identity), so a later app launch/PID reuse cannot become the target.
    @try {
        Class predicateClass=NSClassFromString(@"RBSProcessPredicate");
        Class requestClass=NSClassFromString(@"RBSTerminateRequest");
        Class contextClass=NSClassFromString(@"RBSTerminateContext");
        id request=[requestClass alloc];
        if(!MWTerminateMethod(predicateClass,@selector(predicateMatchingHandle:),'@',"@") ||
           !MWTerminateMethod(contextClass,@selector(defaultContextWithExplanation:),'@',"@") ||
           !MWTerminateMethod(request,@selector(initWithPredicate:context:),'@',"@@") ||
           (!MWTerminateMethod(request,@selector(execute:),'B',"^") && !MWTerminateMethod(request,@selector(execute:),'c',"^"))) {
            completion(MWError(70,@"系统缺少精确结束应用的接口。小窗已释放，请从系统多任务界面关闭该应用。")); return;
        }
        id predicate=[predicateClass predicateMatchingHandle:process];
        id context=[contextClass defaultContextWithExplanation:@"User closed hosted application in HaruGalaxy"];
        if(!predicate || !context) { completion(MWError(70,@"无法建立应用结束请求。")); return; }
        if(MWTerminateMethod(context,@selector(setExplanation:),'v',"@"))
            [context setExplanation:@"User closed hosted application in HaruGalaxy"];
        request=[request initWithPredicate:predicate context:context];
        if(!request) { completion(MWError(70,@"系统未创建应用结束请求。")); return; }
        id all=MWRuntimeBoolValue(request,@"targetsAllManagedProcesses");
        if(![all isKindOfClass:NSNumber.class] || [all boolValue]) {
            completion(MWError(70,@"无法确认结束请求只针对所选应用，未执行请求。")); return;
        }
        MWLog(@"guest.user_close_termination",@{@"pid":@(pid),@"target":@"original_process_handle"});
        MWGuestExitObservation *observation=[MWGuestExitObservation new];
        observation.pid=pid; MWGuestCloseBegin(&observation->state,CACurrentMediaTime());
        observation.pending=pending; observation.completion=completion;
        [observation poll];
        if(MWGuestCloseDone(&observation->state)) return;
        dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED,0),^{
            NSError *error=nil; BOOL accepted=NO;
            @try { accepted=[request execute:&error]; }
            @catch(NSException *exception) { error=MWError(70,exception.reason ?: @"应用结束请求失败。"); }
            if(error && ![error isKindOfClass:NSError.class]) error=MWError(70,@"系统返回了无法识别的结束结果。");
            dispatch_async(dispatch_get_main_queue(),^{
                if(MWGuestCloseDone(&observation->state)) return;
                MWLog(@"guest.user_close_requested",@{@"pid":@(pid),@"accepted":@(accepted),@"error":MWErrorFields(error)});
                if(!accepted) {
                    errno=0; int result=kill(pid,0); int probeError=errno;
                    if(MWGuestProcessAbsent(result,probeError)) { [observation poll]; return; }
                }
                if(!accepted && MWGuestCloseReject(&observation->state)==MWGuestCloseCompleteFailure)
                    [observation finish:error ?: MWError(70,@"系统未批准结束应用。请从系统多任务界面关闭该应用。")];
            });
        });
    } @catch(NSException *exception) { completion(MWError(70,exception.reason ?: @"应用结束请求失败。")); }
}
