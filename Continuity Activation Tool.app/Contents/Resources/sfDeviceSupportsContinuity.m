//
//  SFDeviceSupportsContinuity check utility
//  retuns 1 if Continuity is currently enabled by OS X
//  retunrs 0 if Continuity is currently disabled by OS X
//
//  Created by David Dudok de Wit (dokterdok) on 02.11.14.
//  MIT License
//
//

#import <Foundation/Foundation.h>
#include <IOBluetooth/IOBluetooth.h>
#import <dlfcn.h>
#define NSLog(FORMAT, ...) printf("%s\n", [[NSString stringWithFormat:FORMAT, ##__VA_ARGS__] UTF8String]);

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        void *libHandle = dlopen("/System/Library/PrivateFrameworks/Sharing.framework/Sharing", RTLD_LAZY);
        int (*continuityFunction)(void *) = dlsym(libHandle, "SFDeviceSupportsContinuity");
        NSLog(@"%i", continuityFunction(NULL));
    }
    return 0;
}