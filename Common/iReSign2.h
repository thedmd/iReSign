//
//  iReSign2.h
//  iReSign2
//
//  Created by Admin on 31.05.2013.
//  Copyright (c) 2013 Artifex Mundi. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol iReSign2Delegate;

@interface iReSign2 : NSObject

@property (nonatomic, retain) NSString* ipaPath;
@property (nonatomic, retain) NSString* resignedIpaPath;
@property (nonatomic, retain) NSString* certificateName;
@property (nonatomic, retain) NSString* mobileProvisionPath;
@property (nonatomic, retain) NSString* bundleID;

@property (nonatomic, weak) id <iReSign2Delegate> delegate;

@property (readonly) bool isBusy;
@property (readonly) float progress;

- (id)init:(NSError**)error;
- (id)initWithCertificateName:(NSString*)certificateName mobileProvisionPath:(NSString*)mobileProvisionPath error:(NSError**)error;
- (id)initWithCertificateName:(NSString*)certificateName mobileProvisionPath:(NSString*)mobileProvisionPath bundleID:(NSString*)bundleID error:(NSError**)error;

- (void)resign;
- (void)wait;

@end

@protocol iReSign2Delegate <NSObject>
@optional
- (void)resignDidBegin:(iReSign2*)sender;
- (void)resignDidEnd:(iReSign2*)sender;
- (void)resign:(iReSign2*)sender didProgressChange:(float)progress;
- (void)resign:(iReSign2*)sender didStatusChange:(NSString*)status;
- (void)resign:(iReSign2*)sender didFailWithError:(NSError*)error;
@end

