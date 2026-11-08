// SPDX-License-Identifier: Apache-2.0
#import <UIKit/UIKit.h>
#import "MWAppDelegate.h"
#import "Platform/MWPrivate.h"
#import "Diagnostics/MWDiagnostics.h"

int main(int argc,char **argv) {
    @autoreleasepool {
        MWLoadPrivateFrameworks();
        [MWDiagnostics.shared start];
        MWLog(@"process.bootstrap",@{});
        void (*initializeShell)(id)=dlsym(RTLD_DEFAULT,"FBSystemShellInitialize");
        if(initializeShell) initializeShell(nil);
        MWLog(@"process.shell_initialized",@{@"available":@(initializeShell!=NULL)});
        return UIApplicationMain(argc,argv,nil,NSStringFromClass(MWAppDelegate.class));
    }
}

