// 
// Copyright (c) 2010 Eric Czarny <eczarny@gmail.com>
// 
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of  this  software  and  associated documentation files (the "Software"), to
// deal  in  the Software without restriction, including without limitation the
// rights  to  use,  copy,  modify,  merge,  publish,  distribute,  sublicense,
// and/or sell copies  of  the  Software,  and  to  permit  persons to whom the
// Software is furnished to do so, subject to the following conditions:
// 
// The  above  copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
// 
// THE  SOFTWARE  IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED,  INCLUDING  BUT  NOT  LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS  FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS  OR  COPYRIGHT  HOLDERS  BE  LIABLE  FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY,  WHETHER  IN  AN  ACTION  OF CONTRACT, TORT OR OTHERWISE, ARISING
// FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS
// IN THE SOFTWARE.
// 

#import "SpectacleUtilities.h"
#import "SpectacleHotKey.h"
#import "SpectacleHotKeyAction.h"
#import "SpectacleConstants.h"

@interface SpectacleUtilities (SpectacleUtilitiesPrivate)

+ (NSString *)versionOfBundle: (NSBundle *)bundle;

#pragma mark -

+ (void)updateHotKey: (SpectacleHotKey *)hotKey withPotentiallyNewDefaultHotKey: (SpectacleHotKey *)defaultHotKey;

#pragma mark -

+ (NSDictionary *)defaultHotKeysWithNames: (NSArray *)names;

@end

#pragma mark -

@implementation SpectacleUtilities

+ (NSBundle *)preferencePaneBundle {
    NSString *preferencePanePath = [SpectacleUtilities pathForPreferencePaneNamed: SpectaclePreferencePaneName];
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSBundle *preferencePaneBundle = nil;
    
    if (preferencePanePath && [fileManager fileExistsAtPath: preferencePanePath isDirectory: nil]) {
        preferencePaneBundle = [NSBundle bundleWithPath: preferencePanePath];
    }
    
    if (!preferencePaneBundle) {
        NSLog(@"The preference pane does not exist at path: %@", preferencePanePath);
    }
    
    return preferencePaneBundle;
}

+ (NSBundle *)helperApplicationBundle {
    NSBundle *preferencePaneBundle = [SpectacleUtilities preferencePaneBundle];
    NSURL *bundleURL = [preferencePaneBundle URLForResource: SpectacleHelperApplicationName withExtension: SpectacleApplicationBundleExtension];
    NSBundle *helperApplicationBundle = nil;
    
    if (preferencePaneBundle && bundleURL) {
        helperApplicationBundle = [NSBundle bundleWithURL: bundleURL];
    } else {
        helperApplicationBundle = [NSBundle mainBundle];
    }
    
    return helperApplicationBundle;
}

#pragma mark -

+ (NSString *)preferencePaneVersion {
    return [SpectacleUtilities versionOfBundle: [SpectacleUtilities preferencePaneBundle]];
}

+ (NSString *)helperApplicationVersion {
    return [SpectacleUtilities versionOfBundle: [SpectacleUtilities helperApplicationBundle]];
}

#pragma mark -

+ (void)startSpectacle {
    NSWorkspace *sharedWorkspace = [NSWorkspace sharedWorkspace];
    NSBundle *helperApplicationBundle = [SpectacleUtilities helperApplicationBundle];
    NSURL *helperApplicationURL = nil;
    
    if ([SpectacleUtilities isSpectacleRunning]) {
        NSLog(@"Unable to start the Spectacle helper application as it is already running.");
        
        return;
    }
    
    if (!helperApplicationBundle) {
        NSLog(@"Unable to locate the Spectacle helper application bundle.");
    } else {
        helperApplicationURL = [helperApplicationBundle bundleURL];
        
        [sharedWorkspace launchApplicationAtURL: helperApplicationURL
                                        options: NSWorkspaceLaunchWithoutAddingToRecents | NSWorkspaceLaunchAsync
                                  configuration: nil
                                          error: nil];
    }
}

+ (void)stopSpectacle {
    if (![SpectacleUtilities isSpectacleRunning]) {
        NSLog(@"Unable to stop the Spectacle helper application as it is not running.");
        
        return;
    }
    
    [[NSDistributedNotificationCenter defaultCenter] postNotificationName: SpectacleHelperShouldTerminateNotification
                                                                   object: nil
                                                                 userInfo: nil
                                                       deliverImmediately: YES];
}

#pragma mark -

+ (BOOL)isSpectacleRunning {
    NSArray *runningApplications = [NSRunningApplication runningApplicationsWithBundleIdentifier: SpectacleHelperBundleIdentifier];
    
    if (runningApplications && ([runningApplications count] > 0)) {
        return YES;
    }
    
    return NO;
}

#pragma mark -

+ (NSArray *)hotKeyNames {
    NSBundle *bundle = [SpectacleUtilities helperApplicationBundle];
    NSString *path = [bundle pathForResource: SpectacleHotKeyNamesPropertyListFile ofType: ZeroKitPropertyListFileExtension];
    NSArray *hotKeyNames = [NSArray arrayWithContentsOfFile: path];
    
    return hotKeyNames;
}

#pragma mark -

+ (NSArray *)hotKeysFromDictionary: (NSDictionary *)dictionary hotKeyTarget: (id)target {
    NSDictionary *defaultHotKeys = [SpectacleUtilities defaultHotKeysWithNames: [dictionary allKeys]];
    NSMutableArray *hotKeys = [NSMutableArray array];
    
    for (NSData *hotKeyData in [dictionary allValues]) {
        SpectacleHotKey *hotKey = [NSKeyedUnarchiver unarchiveObjectWithData: hotKeyData];
        NSString *hotKeyName = [hotKey hotKeyName];
        
        [hotKey setHotKeyAction: [SpectacleUtilities actionForHotKeyWithName: hotKeyName target: target]];
        
        [SpectacleUtilities updateHotKey: hotKey withPotentiallyNewDefaultHotKey: [defaultHotKeys objectForKey: hotKeyName]];
        
        [hotKeys addObject: hotKey];
    }
    
    return hotKeys;
}

#pragma mark -

+ (SpectacleHotKeyAction *)actionForHotKeyWithName: (NSString *)name target: (id)target {
    SEL selector = NULL;
    
    if ([name isEqualToString: SpectacleWindowActionMoveToCenter]) {
        selector = @selector(moveFrontMostWindowToCenter:);
    } else if ([name isEqualToString: SpectacleWindowActionMoveToFullscreen]) {
        selector = @selector(moveFrontMostWindowToFullscreen:);
    } else if ([name isEqualToString: SpectacleWindowActionMoveToLeftHalf]) {
        selector = @selector(moveFrontMostWindowToLeftHalf:);
    } else if ([name isEqualToString: SpectacleWindowActionMoveToRightHalf]) {
        selector = @selector(moveFrontMostWindowToRightHalf:);
    } else if ([name isEqualToString: SpectacleWindowActionMoveToTopHalf]) {
        selector = @selector(moveFrontMostWindowToTopHalf:);
    } else if ([name isEqualToString: SpectacleWindowActionMoveToBottomHalf]) {
        selector = @selector(moveFrontMostWindowToBottomHalf:);
    } else if ([name isEqualToString: SpectacleWindowActionMoveToUpperLeft]) {
        selector = @selector(moveFrontMostWindowToUpperLeft:);
    } else if ([name isEqualToString: SpectacleWindowActionMoveToLowerLeft]) {
        selector = @selector(moveFrontMostWindowToLowerLeft:);
    } else if ([name isEqualToString: SpectacleWindowActionMoveToUpperRight]) {
        selector = @selector(moveFrontMostWindowToUpperRight:);
    } else if ([name isEqualToString: SpectacleWindowActionMoveToLowerRight]) {
        selector = @selector(moveFrontMostWindowToLowerRight:);
    } else if ([name isEqualToString: SpectacleWindowActionMoveToLeftDisplay]) {
        selector = @selector(moveFrontMostWindowToLeftDisplay:);
    } else if ([name isEqualToString: SpectacleWindowActionMoveToRightDisplay]) {
        selector = @selector(moveFrontMostWindowToRightDisplay:);
    } else if ([name isEqualToString: SpectacleWindowActionMoveToTopDisplay]) {
        selector = @selector(moveFrontMostWindowToTopDisplay:);
    } else if ([name isEqualToString: SpectacleWindowActionMoveToBottomDisplay]) {
        selector = @selector(moveFrontMostWindowToBottomDisplay:);
    } else if ([name isEqualToString: SpectacleWindowActionMoveToNextSpace]) {
        selector = @selector(moveFrontMostWindowToNextSpace:);
    } else if ([name isEqualToString: SpectacleWindowActionMoveToPreviousSpace]) {
        selector = @selector(moveFrontMostWindowToPreviousSpace:);
    } else if ([name isEqualToString: SpectacleWindowActionUndoLastMove]) {
        selector = @selector(undoLastWindowAction:);
    } else if ([name isEqualToString: SpectacleWindowActionRedoLastMove]) {
        selector = @selector(redoLastWindowAction:);
    }
    
    return [SpectacleHotKeyAction hotKeyActionFromTarget: target selector: selector];
}

#pragma mark -

+ (NSInteger)currentWorkspace {
    CGWindowListOption options = kCGWindowListOptionOnScreenOnly | kCGWindowListExcludeDesktopElements;
    CFArrayRef windows = CGWindowListCreate(options, kCGNullWindowID);
    CFArrayRef windowDescriptions = CGWindowListCreateDescriptionFromArray(windows);
    NSInteger currentWorkspace = 0;
    
    for (NSInteger i = 0; i < CFArrayGetCount(windowDescriptions); i++) {
        CFDictionaryRef windowDescription = CFArrayGetValueAtIndex(windowDescriptions, i);
        NSNumber *workspace = (NSNumber *)CFDictionaryGetValue(windowDescription, kCGWindowWorkspace);
        
        if (workspace) {
            currentWorkspace = [workspace integerValue];
            
            break;
        }
    }
    
    CFRelease(windows);
    CFRelease(windowDescriptions);
    
    return currentWorkspace;
}

#pragma mark -

+ (NSInteger)frontMostWindowNumber {
    NSDictionary *activeApplication = [[NSWorkspace sharedWorkspace] activeApplication];
    UInt32 lowLongOfPSN = [[activeApplication objectForKey: @"NSApplicationProcessSerialNumberLow"] longValue];
    UInt32 highLongOfPSN = [[activeApplication objectForKey: @"NSApplicationProcessSerialNumberHigh"] longValue];
    ProcessSerialNumber activeApplicationPSN = {highLongOfPSN, lowLongOfPSN};
    CFArrayRef windowList = CGWindowListCopyWindowInfo(kCGWindowListOptionOnScreenOnly, kCGNullWindowID);
    ProcessSerialNumber currentPSN = {kNoProcess, kNoProcess};
    NSNumber *frontMostWindowNumber = nil;
    
    for (NSMutableDictionary *window in (NSArray *)windowList) {
        int pid = [[window objectForKey: (id)kCGWindowOwnerPID] intValue];
        
        GetProcessForPID(pid, &currentPSN);
        
        if((currentPSN.lowLongOfPSN == activeApplicationPSN.lowLongOfPSN) && (currentPSN.highLongOfPSN == activeApplicationPSN.highLongOfPSN)) {
            frontMostWindowNumber = [[[window objectForKey: (id)kCGWindowNumber] retain] autorelease];
            
            break;
        }
    }
    
    CFRelease(windowList);
    
    return [frontMostWindowNumber integerValue];
}

@end

#pragma mark -

@implementation SpectacleUtilities (SpectacleUtilitiesPrivate)

+ (NSString *)versionOfBundle: (NSBundle *)bundle {
    NSString *bundleVersion = [bundle objectForInfoDictionaryKey: ZeroKitApplicationBundleShortVersionString];
    
    if (!bundleVersion) {
        bundleVersion = [bundle objectForInfoDictionaryKey: ZeroKitApplicationBundleVersion];
    }
    
    return bundleVersion;
}

#pragma mark -

+ (void)updateHotKey: (SpectacleHotKey *)hotKey withPotentiallyNewDefaultHotKey: (SpectacleHotKey *)defaultHotKey {
    NSString *hotKeyName = [hotKey hotKeyName];
    NSInteger defaultHotKeyCode;
    
    if (![hotKeyName isEqualToString: SpectacleWindowActionMoveToLowerLeft] && ![hotKeyName isEqualToString: SpectacleWindowActionMoveToLowerRight]) {
        return;
    }
    
    defaultHotKeyCode = [defaultHotKey hotKeyCode];
    
    if (([hotKey hotKeyCode] == defaultHotKeyCode) && ([hotKey hotKeyModifiers] == 768)) {
        [hotKey setHotKeyCode: defaultHotKeyCode];
        
        [hotKey setHotKeyModifiers: [defaultHotKey hotKeyModifiers]];
    }
}

#pragma mark -

+ (NSDictionary *)defaultHotKeysWithNames: (NSArray *)names {
    NSBundle *bundle = [SpectacleUtilities helperApplicationBundle];
    NSString *path = [bundle pathForResource: ZeroKitDefaultPreferencesFile ofType: ZeroKitPropertyListFileExtension];
    NSDictionary *applicationDefaults = [NSDictionary dictionaryWithContentsOfFile: path];
    NSMutableDictionary *defaultHotKeys = [NSMutableDictionary dictionary];
    
    for (NSString *hotKeyName in names) {
        NSData *defaultHotKeyData = [applicationDefaults objectForKey: hotKeyName];
        SpectacleHotKey *defaultHotKey = [NSKeyedUnarchiver unarchiveObjectWithData: defaultHotKeyData];
        
        [defaultHotKeys setObject: defaultHotKey forKey: hotKeyName];
    }
    
    return defaultHotKeys;
}

@end
