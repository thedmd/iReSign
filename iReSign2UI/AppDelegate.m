//
//  AppDelegate.m
//  iReSign2UI
//
//  Created by Admin on 31.05.2013.
//  Copyright (c) 2013 Artifex Mundi. All rights reserved.
//

#import "AppDelegate.h"
#import "IRTextFieldDrag.h"

static NSString* kDefaultKeyMobileProvisioningPath = @"MOBILE_PROVISIONING_PATH";
static NSString* kDefaultKeyCertificateName        = @"CERTIFICATE_NAME";
static NSString* kDefaultKeyBundleID               = @"BUNDLE_ID";

@interface AppDelegate () <iReSign2Delegate>
@property (nonatomic, retain) iReSign2*         iresign;
@property (nonatomic, retain) NSUserDefaults*   defaults;
@end

@implementation AppDelegate {
    iReSign2*       _iresign;
    NSUserDefaults* _defaults;
}

@synthesize iresign  = _iresign;
@synthesize defaults = _defaults;

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    // Insert code here to initialize your application
    
    NSError* error = nil;
    self.iresign = [[iReSign2 alloc] init:&error];
    if (nil == self.iresign)
    {
        if (error)
        {
            NSRunAlertPanel(@"Error",
                            [error localizedDescription],
                            @"OK", nil, nil);
            exit(1);
        }
    }
    
    self.iresign.delegate = self;
    
    self.defaults = [NSUserDefaults standardUserDefaults];
    
    NSString* provisioningPath = [self.defaults valueForKey:kDefaultKeyMobileProvisioningPath];
    NSString* certificateName  = [self.defaults valueForKey:kDefaultKeyCertificateName];
    NSString* bundleID         = [self.defaults valueForKey:kDefaultKeyBundleID];
    
    if (provisioningPath)
        [provisioningPathField setStringValue: provisioningPath];
    if (certificateName)
        [certificateNameField  setStringValue: certificateName];
    if (bundleID)
        [bundleIDField setStringValue:bundleID];
    
    [self enableControls:true];
    
    [self setStatus:@"Ready"];
}

- (IBAction)resign:(id)sender
{
    [self.defaults setValue:[provisioningPathField stringValue] forKey:kDefaultKeyMobileProvisioningPath];
    [self.defaults setValue:[certificateNameField  stringValue] forKey:kDefaultKeyCertificateName];
    [self.defaults setValue:[bundleIDField         stringValue] forKey:kDefaultKeyBundleID];
    [self.defaults synchronize];
    
    NSString* ipaPath = [pathField stringValue];
    
    [self.iresign setIpaPath:ipaPath];
    [self.iresign setMobileProvisionPath:[provisioningPathField stringValue]];
    [self.iresign setCertificateName:[certificateNameField stringValue]];
    if ([changeBundleIDCheckbox state] == NSOnState)
        [self.iresign setBundleID:[bundleIDField stringValue]];
    else
        [self.iresign setBundleID:nil];
    
    NSString* destinationPath = [NSString stringWithFormat:@"%@%@.%@", [ipaPath stringByDeletingPathExtension], @"-resigned", [ipaPath pathExtension]];
    
    [self.iresign setResignedIpaPath:destinationPath];
    [self.iresign resign];
}

- (IBAction)browse:(id)sender
{
    NSOpenPanel *panel = [NSOpenPanel openPanel];
    
    // Configure your panel the way you want it
    [panel setCanChooseFiles:YES];
    [panel setCanChooseDirectories:NO];
    [panel setAllowsMultipleSelection:NO];
    [panel setAllowedFileTypes:[NSArray arrayWithObject:@"ipa"]];
    
    [panel beginWithCompletionHandler:^(NSInteger result)
    {
        if (result == NSFileHandlingPanelOKButton)
            [pathField setStringValue:[[panel URL] path]];
    }];
}

- (IBAction)provisioningBrowse:(id)sender
{
    NSOpenPanel *panel = [NSOpenPanel openPanel];
    
    // Configure your panel the way you want it
    [panel setCanChooseFiles:YES];
    [panel setCanChooseDirectories:NO];
    [panel setAllowsMultipleSelection:NO];
    [panel setAllowedFileTypes:[NSArray arrayWithObject:@"mobileprovision"]];
    
    [panel beginWithCompletionHandler:^(NSInteger result)
     {
         if (result == NSFileHandlingPanelOKButton)
             [provisioningPathField setStringValue:[[panel URL] path]];
     }];
}

- (IBAction)changeBundleIDPressed:(id)sender
{
    [bundleIDField setEnabled:[self canEnableBundleIDField]];
}

- (bool)canEnableBundleIDField
{
    return changeBundleIDCheckbox.state == NSOnState;
}

- (void)setStatus:(NSString*)status
{
    [statusLabel setStringValue: status];
}

- (void)resignDidBegin:(iReSign2*)sender
{
    [self enableControls:false];
}

- (void)resignDidEnd:(iReSign2*)sender
{
    [self enableControls:true];
}

- (void)resign:(iReSign2*)sender didProgressChange:(float)progress
{
}

- (void)resign:(iReSign2*)sender didStatusChange:(NSString*)status
{
    [self setStatus: status];
}

- (void)resign:(iReSign2*)sender didFailWithError:(NSError*)error
{
    NSRunAlertPanel(@"Error",
                    [error localizedDescription],
                    @"OK", nil, nil);
    
    [self setStatus:@"Conversion failed"];
}

- (void)enableControls:(bool)enable
{
    [pathField setEnabled:enable];
    [provisioningPathField setEnabled:enable];
    [certificateNameField setEnabled:enable];
    [bundleIDField setEnabled:enable && [self canEnableBundleIDField]];
    [browseButton setEnabled:enable];
    [provisioningBrowseButton setEnabled:enable];
    [resignButton setEnabled:enable];
    [changeBundleIDCheckbox setEnabled:enable];
    
    [progressIndicator setHidden:enable];
    if (enable)
        [progressIndicator stopAnimation:self];
    else
        [progressIndicator startAnimation:self];
}

@end
