// SPDX-License-Identifier: Apache-2.0
#import <UIKit/UIKit.h>
#import "MWAppDelegate.h"
#import "Platform/MWPrivate.h"

int main(int argc,char **argv) {
    @autoreleasepool {
        MWLoadPrivateFrameworks();
        void (*initializeShell)(id)=dlsym(RTLD_DEFAULT,"FBSystemShellInitialize");
        if(initializeShell) initializeShell(nil);
        return UIApplicationMain(argc,argv,nil,NSStringFromClass(MWAppDelegate.class));
    }
}

