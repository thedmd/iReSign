//
//  AppDelegate.h
//  iReSign2UI
//
//  Created by Admin on 31.05.2013.
//  Copyright (c) 2013 Artifex Mundi. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class IRTextFieldDrag;
@interface AppDelegate : NSObject <NSApplicationDelegate> {
@private
    IBOutlet IRTextFieldDrag* pathField;
    IBOutlet IRTextFieldDrag* provisioningPathField;
    IBOutlet IRTextFieldDrag* certificateNameField;
    IBOutlet IRTextFieldDrag* bundleIDField;
    IBOutlet NSButton* browseButton;
    IBOutlet NSButton* provisioningBrowseButton;
    IBOutlet NSButton* resignButton;
    IBOutlet NSTextField* statusLabel;
    IBOutlet NSButton* changeBundleIDCheckbox;
    IBOutlet NSProgressIndicator* progressIndicator;
}

@property (assign) IBOutlet NSWindow *window;

- (IBAction)resign:(id)sender;
- (IBAction)browse:(id)sender;
- (IBAction)provisioningBrowse:(id)sender;
- (IBAction)changeBundleIDPressed:(id)sender;

@end
