//
//  main.m
//  continuityCheck
//
//  Created by Jan (sysfloat) on 2015-06-17.
//  Copyright (c) 2015 Jan. All rights reserved.
//	MIT License
//

#import <Cocoa/Cocoa.h>
#import <dlfcn.h>

void startCAT();
bool showError(bool kextDev);
bool checkContinuity();
bool checkKextDevMode();

int main(int argc, const char * argv[]) {
    const char *arg;
    if(argc > 1)
        arg = argv[1];
    else
        arg = "";
    if(!checkKextDevMode() && strcmp(arg, "-silent") != 0) {
        showError(true);
    }
    if(!checkContinuity()) {
        if(strcmp(arg, "-silent") != 0)
            if(showError(false))
                startCAT();
        return 0;
    }
    else return 1;
    return -1;
}

void startCAT() {
    NSString *pth = [[NSBundle mainBundle] bundlePath];
    NSArray *pthCompArray = [[pth pathComponents] subarrayWithRange:NSMakeRange([[pth pathComponents] count]-4,1)];
    NSString *pthCATName = [NSString pathWithComponents:pthCompArray];
    NSTask *task = [[NSTask alloc] init];
    NSArray* arguments = [NSArray arrayWithObjects: [pth stringByAppendingString: [@"/../../../../" stringByAppendingString:pthCATName]], nil];
    [task setLaunchPath: @"/usr/bin/open"];
    [task setArguments: arguments];
    [task launch];
}

bool showError(bool kextDev) {
    NSAlert *alert = [[NSAlert alloc] init];
    [alert addButtonWithTitle:@"Open Continuity Activation Tool"];
    [alert addButtonWithTitle:@"Dismiss"];
    [alert setMessageText:@"Error: Continuity not Active"];
    [alert setInformativeText:@"Continuity is currently not active!\nThis might be due to an System update..\nDo you want to open Continuity Activation Tool to reenable it?"];
    if(kextDev) {
        [alert setMessageText:@"Error: Kext developer mode not set"];
        [alert setInformativeText:@"Kext developer mode is not set!\nThis might result in unusable WiFi/Bluetooth\nDo you want to open Continuity Activation to to fix this?"];
    }
    [alert setAlertStyle:NSWarningAlertStyle];
    if([alert runModal] == NSAlertFirstButtonReturn) { return true; }
    return false;
}

bool checkContinuity() {
    void *libHandle = dlopen("/System/Library/PrivateFrameworks/Sharing.framework/Sharing", RTLD_LAZY);
    int (*continuityFunction)(void *) = dlsym(libHandle, "SFDeviceSupportsContinuity");
    if(continuityFunction(NULL) == 1)
        return true;
    return false;
}

bool checkKextDevMode() {
    NSTask *task = [[NSTask alloc] init];
    [task setLaunchPath:@"/usr/sbin/nvram"];
    [task setArguments:[NSArray arrayWithObjects:@"boot-args", nil]];
    NSPipe *outputPipe = [NSPipe pipe];
    [task setStandardOutput:outputPipe];
    
    [task launch];
    [task waitUntilExit];
    
    NSFileHandle *read = [outputPipe fileHandleForReading];
    NSData *dataRead = [read readDataToEndOfFile];
    NSString *stringRead = [[NSString alloc] initWithData:dataRead encoding:NSUTF8StringEncoding];
    if([stringRead containsString:@"kext-dev-mode=1"])
        return true;
    return false;
}
