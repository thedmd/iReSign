//
//  main.cpp
//  iReSignCli
//
//  Created by Admin on 31.05.2013.
//  Copyright (c) 2013 Artifex Mundi. All rights reserved.
//

#import <Foundation/Foundation.h>
#include <iReSign2.h>
#include <stdio.h>

static void printUsage()
{
    puts("Usage:\n");
    puts("  iReSign2Cli -input <ipa-path> -provisioningPath <mobileprovisioning-path> -certificateName <certName>\n");
    puts("              [-bundleID <new-bundle-id>] [-output <target-ipa-path>\n");
}

@interface LocalDelegate : NSObject <iReSign2Delegate>
- (void)resign:(iReSign2*)sender didFailWithError:(NSError*)error;
@end

@implementation LocalDelegate
- (void)resign:(iReSign2*)sender didFailWithError:(NSError*)error;
{
    fprintf(stderr, "Error: %s\n\n", [[error localizedDescription] cStringUsingEncoding:NSUTF8StringEncoding]);
    printUsage();
    exit(1);
}
@end

int main(int argc, const char * argv[])
{
    NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
    
    if ([defaults stringForKey:@"help"])
    {
        printUsage();
        return 0;
    }
    
    NSString* ipaPath          = [defaults stringForKey:@"input"];
    NSString* outputPath       = [defaults stringForKey:@"output"];
    NSString* provisioningPath = [defaults stringForKey:@"provisioningPath"];
    NSString* certificateName  = [defaults stringForKey:@"certificateName"];
    NSString* bundleID         = [defaults stringForKey:@"bundleID"];
    
    if (ipaPath && !outputPath)
        outputPath = [NSString stringWithFormat:@"%@%@.%@", [ipaPath stringByDeletingPathExtension], @"-resigned", [ipaPath pathExtension]];
    
    NSError* error = nil;
    
    iReSign2* iresign = [[iReSign2 alloc] init:&error];
    if (iresign == nil)
    {
        fprintf(stderr, "Error: %s\n\n", [[error localizedDescription] cStringUsingEncoding:NSUTF8StringEncoding]);
        printUsage();
        return 1;
    }
    
    [iresign setIpaPath:ipaPath];
    [iresign setResignedIpaPath:outputPath];
    [iresign setMobileProvisionPath:provisioningPath];
    [iresign setCertificateName:certificateName];
    [iresign setBundleID:bundleID];
    
    LocalDelegate* delegate = [[LocalDelegate alloc] init];
    iresign.delegate = delegate;
    
    [iresign resign];
    [iresign wait];

    puts("Done\n");

    return 0;
}

