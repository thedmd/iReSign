//
//  iReSign2.m
//  iReSign2
//
//  Created by Admin on 31.05.2013.
//  Copyright (c) 2013 Artifex Mundi. All rights reserved.
//

#import "iReSign2.h"

static NSString* kKeyBundleIDPlistApp           = @"CFBundleIdentifier";
static NSString* kKeyBundleIDPlistiTunesArtwork = @"softwareVersionBundleId";

static NSString* kPayloadDirName                = @"Payload";
static NSString* kInfoPlistFilename             = @"Info.plist";

static NSString* kResourceRules =
@"<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n"
@"<!DOCTYPE plist PUBLIC \"-//Apple//DTD PLIST 1.0//EN\" \"http://www.apple.com/DTDs/PropertyList-1.0.dtd\">\n"
@"<plist version=\"1.0\">\n"
@"<dict>\n"
@"	<key>rules</key>\n"
@"	<dict>\n"
@"		<key>.*</key>\n"
@"		<true/>\n"
@"		<key>Info.plist</key>\n"
@"		<dict>\n"
@"			<key>omit</key>\n"
@"			<true/>\n"
@"			<key>weight</key>\n"
@"			<real>10</real>\n"
@"		</dict>\n"
@"		<key>ResourceRules.plist</key>\n"
@"		<dict>\n"
@"			<key>omit</key>\n"
@"			<true/>\n"
@"			<key>weight</key>\n"
@"			<real>100</real>\n"
@"		</dict>\n"
@"	</dict>\n"
@"</dict>\n"
@"</plist>\n";


typedef enum iReSign2Operation
{
    kNone,
    kResign,
    kVerify
} iReSign2OperationType;

@interface iReSign2(Private)
@property (readwrite) float progress;
@end

@implementation iReSign2
{
    struct
    {
        unsigned int resignDidBegin:1;
        unsigned int resignDidEnd:1;
        unsigned int resignDidProgressChange:1;
        unsigned int resignDidStatusChange:1;
        unsigned int resignDidFailWithError:1;
    } delegateRespondsTo;
    
    bool                    _isBusy;
    float                   _progress;
    NSCondition*            _waitCondition;
}

@synthesize ipaPath;
@synthesize resignedIpaPath;
@synthesize certificateName;
@synthesize mobileProvisionPath;
@synthesize bundleID;
@synthesize delegate;
@synthesize isBusy;
@synthesize progress = _progress;

- (id)init
{
    return [self initWithCertificateName:nil mobileProvisionPath:nil bundleID:nil error:nil];
}

- (id)init:(NSError**)error
{
    return [self initWithCertificateName:nil mobileProvisionPath:nil bundleID:nil error:error];
}

- (id)initWithCertificateName:(NSString*)_certificateName mobileProvisionPath:(NSString*)_mobileProvisionPath error:(NSError**)error
{
    return [self initWithCertificateName:_certificateName mobileProvisionPath:_mobileProvisionPath bundleID:nil error:error];
}

- (id)initWithCertificateName:(NSString*)_certificateName mobileProvisionPath:(NSString*)_mobileProvisionPath bundleID:(NSString*)_bundleID error:(NSError**)error
{
    self = [super init];
    
    if (nil != self)
    {
        memset(&delegateRespondsTo, 0, sizeof(delegateRespondsTo));
        
        _waitCondition = [[NSCondition alloc] init];
        
        certificateName = _certificateName;
        mobileProvisionPath = _mobileProvisionPath;
        bundleID = _bundleID;
        
        _isBusy    = false;
        _progress  = 0.0f;
        
        NSFileManager* fileManager = [NSFileManager defaultManager];
        
        NSError* creationError = nil;
        
        if (![fileManager fileExistsAtPath:@"/usr/bin/zip"])
            creationError = [self createError:@"Failed to locate zip utility at /usr/bin/zip"];
        else if (![fileManager fileExistsAtPath:@"/usr/bin/unzip"])
            creationError = [self createError:@"Failed to locate unzip utility at /usr/bin/unzip"];
        else if (![fileManager fileExistsAtPath:@"/usr/bin/codesign"])
            creationError = [self createError:@"Failed to locate codesign utility at /usr/bin/codesign"];
        
        if (creationError)
        {
            if (error)
                *error = creationError;
            return nil;
        }
    }
    
    return self;
}

- (void)setDelegate:(id <iReSign2Delegate>)_delegate
{
    if (delegate != _delegate) {
        delegate = _delegate;
        
        delegateRespondsTo.resignDidBegin          = [_delegate respondsToSelector:@selector(resignDidBegin:)];
        delegateRespondsTo.resignDidEnd            = [_delegate respondsToSelector:@selector(resignDidEnd:)];
        delegateRespondsTo.resignDidProgressChange = [_delegate respondsToSelector:@selector(resign:didProgressChange:)];
        delegateRespondsTo.resignDidStatusChange   = [_delegate respondsToSelector:@selector(resign:didStatusChange:)];
        delegateRespondsTo.resignDidFailWithError  = [_delegate respondsToSelector:@selector(resign:didFailWithError:)];
    }
}

- (void)setProgress:(float)progress
{
    _progress = progress;
    [self invokeResingDidProgressChange:progress];
}

- (void)invokeResignDidBegin
{
    if (delegateRespondsTo.resignDidBegin)
        [delegate resignDidBegin:self];
}

- (void)invokeResignDidEnd
{
    if (delegateRespondsTo.resignDidEnd)
        [delegate resignDidEnd:self];
}

- (void)invokeResingDidProgressChange:(float)progress
{
    if (delegateRespondsTo.resignDidProgressChange)
        [delegate resign:self didProgressChange:progress];
}

- (void)invokeResignDidStatusChange:(NSString*)status
{
    if (delegateRespondsTo.resignDidStatusChange)
        [delegate resign:self didStatusChange:status];
}

- (void)invokeResignDidFailWithError:(NSError*)error
{
    if (delegateRespondsTo.resignDidFailWithError)
        [delegate resign:self didFailWithError:error];
}

- (bool)isBusy
{
    return _isBusy;
}

- (void)setStatus:(NSString *)format, ...
{
    va_list args;
    va_start(args, format);
    NSString* formatedStatus = [[NSString alloc] initWithFormat:format arguments:args];
    va_end(args);
    
    [self invokeResignDidStatusChange:formatedStatus];
}

- (NSString*)getTemporaryDirectory
{
    NSString* temporaryDirectory = nil;
    NSString* template = [NSTemporaryDirectory() stringByAppendingPathComponent:@"com.artifexmundi.iReSign2.XXXXXXXX"];
    const char* directoryTemplate = [template fileSystemRepresentation];
    char* directoryPath = strdup(directoryTemplate);
    char* result = mkdtemp(directoryPath);
    if (nil != result)
        temporaryDirectory = [NSString stringWithUTF8String:result];
    free(directoryPath);
    return temporaryDirectory;
}

- (void)resign
{
    if (self.isBusy)
        return;

    [_waitCondition lock];
    if (self.isBusy)
    {
        [_waitCondition unlock];
        return;
    }
    
    _isBusy = true;
    [_waitCondition unlock];
    
    dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    
    dispatch_async(queue, ^{
        [self invokeResignDidBegin];
        
        self.progress = 0.0f;
        
        NSError* error = [self doResign];
        if (error != nil)
            [self invokeResignDidFailWithError:error];
        else
            self.progress = 1.0f;
        
        [self invokeResignDidEnd];
        
        [_waitCondition lock];
        _isBusy = false;
        [_waitCondition signal];
        [_waitCondition unlock];
    });
}

- (void)wait
{
    [_waitCondition lock];
    while (_isBusy)
        [_waitCondition wait];
    [_waitCondition unlock];
}

- (NSError*)createError:(NSString*)format, ...
{
    va_list args;
    va_start(args, format);
    NSString* formatedError = [[NSString alloc] initWithFormat:format arguments:args];
    va_end(args);
    
    NSMutableDictionary *errorDetail = [NSMutableDictionary dictionary];
    [errorDetail setValue:formatedError forKey:NSLocalizedDescriptionKey];
    
    return [NSError errorWithDomain:@"iReSign2" code:100 userInfo:errorDetail];
}

- (NSError*)doResign
{
    NSFileManager* fileManager = [NSFileManager defaultManager];
    
    [self setStatus:@"Checking IPA file..."];

    if (![fileManager fileExistsAtPath:ipaPath])
        return [self createError:@"IPA file does not exist at specified path."];

    if (![[[ipaPath pathExtension] lowercaseString] isEqualToString:@"ipa"])
        return [self createError:@"Choosed file is not an IPA file"];
    
    if ([certificateName length] == 0)
        return [self createError:@"Provide certificate name in order to resing an IPA."];

    NSString* workingPath = [self getTemporaryDirectory];
    if (nil == workingPath)
        return [self createError:@"Failed to create temporary directory."];
    
    [self setStatus:@"Extracting original application..."];
    NSTask* unzipTask = [NSTask launchedTaskWithLaunchPath:@"/usr/bin/unzip" arguments:[NSArray arrayWithObjects:@"-q", ipaPath, @"-d", workingPath, nil]];
    [unzipTask waitUntilExit];
    if (unzipTask.terminationReason != NSTaskTerminationReasonExit || unzipTask.terminationStatus != 0)
        return [self createError:@"Failed to extract original application."];
    
    [self setStatus:@"Extraction complete"];

    if (![fileManager fileExistsAtPath:[workingPath stringByAppendingPathComponent:kPayloadDirName]])
        return [self createError:@"Failed to locate payload."];
    
    if ([bundleID length] > 0)
    {
        [self setStatus:@"Replacing bundle ID..."];
        
        if (![self doChangeBundleID:bundleID workingPath:workingPath])
            return [self createError:@"Failed to change bundle ID."];;
    }
    
    NSString* applicationPath = [self doFindApplication: workingPath];
    if (nil == applicationPath)
        return [self createError:@"Failed to locate application in payload directory."];
    
    if ([mobileProvisionPath length] > 0)
    {
        NSError* error = nil;
        
        [self setStatus:@"Provisioning %@...", [applicationPath lastPathComponent]];
        if ((error = [self doProvisioning:mobileProvisionPath applicationPath:applicationPath workingPath:workingPath]))
            return error;
    }

    [self setStatus:@"Signing %@...", [applicationPath lastPathComponent]];
    
    if (![self doCodeSigning:workingPath applicationPath:applicationPath certificateName:certificateName])
        return [self createError:@"Failed to sign application."];
    
    
    [self setStatus:@"Verifying %@...", [applicationPath lastPathComponent]];
    
    if (![self doVerifySignature:applicationPath])
        return [self createError:@"Failed to verify application signature."];

    [self setStatus:@"Compressing..."];
    
    //NSString* destinationPath = [NSString stringWithFormat:@"%@%@.%@", [ipaPath stringByDeletingPathExtension], @"-resigned", [ipaPath pathExtension]];
    NSString* destinationPath = [self resignedIpaPath];
    
    if (![self doZip:destinationPath workingPath:workingPath])
        return [self createError:@"Failed to compress new IPA."];
    
    [self setStatus:@"IPA resigned"];
    
    [fileManager removeItemAtPath:workingPath error:nil];
    
    return nil;
}

 - (bool)doChangeBundleID:(NSString*)newBundleID workingPath:(NSString*)workingPath
 {
     return [self doAppBundleIDChange:newBundleID workingPath:workingPath] &&
            [self doITunesMetadataBundleIDChange:bundleID workingPath:workingPath];
 }

- (BOOL)doITunesMetadataBundleIDChange:(NSString *)newBundleID workingPath:(NSString*)workingPath
{
    NSArray *dirContents = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:workingPath error:nil];
    NSString *infoPlistPath = nil;
    
    for (NSString *file in dirContents) {
        if ([[[file pathExtension] lowercaseString] isEqualToString:@"plist"]) {
            infoPlistPath = [workingPath stringByAppendingPathComponent:file];
            break;
        }
    }
    
    // For self-created IPA files iTunes Artwork is not present.
    if (nil == infoPlistPath)
        return true;
    
    return [self changeBundleIDForFile:infoPlistPath bundleIDKey:kKeyBundleIDPlistiTunesArtwork newBundleID:newBundleID plistOutOptions:NSPropertyListXMLFormat_v1_0];
}

- (BOOL)doAppBundleIDChange:(NSString *)newBundleID workingPath:(NSString*)workingPath
{
    NSArray *dirContents = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:[workingPath stringByAppendingPathComponent:kPayloadDirName] error:nil];
    NSString *infoPlistPath = nil;
    
    for (NSString *file in dirContents) {
        if ([[[file pathExtension] lowercaseString] isEqualToString:@"app"]) {
            infoPlistPath = [[[workingPath stringByAppendingPathComponent:kPayloadDirName]
                              stringByAppendingPathComponent:file]
                             stringByAppendingPathComponent:kInfoPlistFilename];
            break;
        }
    }
    
    return [self changeBundleIDForFile:infoPlistPath bundleIDKey:kKeyBundleIDPlistApp newBundleID:newBundleID plistOutOptions:NSPropertyListBinaryFormat_v1_0];
}

- (BOOL)changeBundleIDForFile:(NSString *)filePath bundleIDKey:(NSString *)bundleIDKey newBundleID:(NSString *)newBundleID plistOutOptions:(NSPropertyListWriteOptions)options
{
    NSMutableDictionary *plist = nil;
    
    if ([[NSFileManager defaultManager] fileExistsAtPath:filePath]) {
        plist = [[NSMutableDictionary alloc] initWithContentsOfFile:filePath];
        [plist setObject:newBundleID forKey:bundleIDKey];
        
        NSData *xmlData = [NSPropertyListSerialization dataWithPropertyList:plist format:options options:kCFPropertyListImmutable error:nil];
        
        return [xmlData writeToFile:filePath atomically:YES];
        
    }
    
    return NO;
}

- (NSString*)doFindApplication:(NSString*)workingPath
{
    NSArray *dirContents = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:[workingPath stringByAppendingPathComponent:kPayloadDirName] error:nil];
    for (NSString *file in dirContents)
        if ([[[file pathExtension] lowercaseString] isEqualToString:@"app"])
            return [[workingPath stringByAppendingPathComponent:kPayloadDirName] stringByAppendingPathComponent:file];
    
    return nil;
}

- (bool)doCodeSigning:(NSString*)workingPath applicationPath:(NSString*)applicationPath certificateName:(NSString*)_certificateName
{
    NSString* resourceRulesPath     = [workingPath stringByAppendingPathComponent:@"ResourceRules.plist"];
    [kResourceRules writeToFile:resourceRulesPath atomically:true encoding:NSUTF8StringEncoding error:nil];
    NSString *resourceRulesArgument = [NSString stringWithFormat:@"--resource-rules=%@", resourceRulesPath];

    NSTask* codesignTask = [[NSTask alloc] init];
    [codesignTask setLaunchPath:@"/usr/bin/codesign"];
    [codesignTask setArguments:[NSArray arrayWithObjects:@"-fs", _certificateName, resourceRulesArgument, applicationPath, nil]];

    NSPipe* pipe = [NSPipe pipe];
    [codesignTask setStandardOutput:pipe];
    [codesignTask setStandardError:pipe];
    NSFileHandle* handle = [pipe fileHandleForReading];

    [codesignTask launch];
    [codesignTask waitUntilExit];
    
    [[NSFileManager defaultManager] removeItemAtPath:resourceRulesPath error:nil];

    NSString* result = [[NSString alloc] initWithData:[handle readDataToEndOfFile] encoding:NSASCIIStringEncoding];
    NSLog(@"%@", result);

    if (codesignTask.terminationReason != NSTaskTerminationReasonExit || codesignTask.terminationStatus != 0)
        return false;
    
    return true;
}

- (bool)doVerifySignature:(NSString*)applicationPath
{
    NSTask* verifyTask = [[NSTask alloc] init];
    [verifyTask setLaunchPath:@"/usr/bin/codesign"];
    [verifyTask setArguments:[NSArray arrayWithObjects:@"-v", applicationPath, nil]];
    
    NSPipe* pipe = [NSPipe pipe];
    [verifyTask setStandardOutput:pipe];
    [verifyTask setStandardError:pipe];
    NSFileHandle* handle = [pipe fileHandleForReading];
    
    [verifyTask launch];
    [verifyTask waitUntilExit];
    
    if (verifyTask.terminationReason != NSTaskTerminationReasonExit || verifyTask.terminationStatus != 0)
        return false;
    
    NSString* result = [[NSString alloc] initWithData:[handle readDataToEndOfFile] encoding:NSASCIIStringEncoding];
    NSLog(@"%@", result);
    
    return true;
}

- (NSError*)doProvisioning:(NSString*)provisioningPath applicationPath:(NSString*)applicationPath workingPath:(NSString*)workingPath
{
    NSString* applicationProvisioningPath = [applicationPath stringByAppendingPathComponent:@"embedded.mobileprovision"];
    if ([[NSFileManager defaultManager] fileExistsAtPath:applicationProvisioningPath])
        [[NSFileManager defaultManager] removeItemAtPath:applicationProvisioningPath error:nil];
    
    NSTask* provisioningTask = [[NSTask alloc] init];
    [provisioningTask setLaunchPath:@"/bin/cp"];
    [provisioningTask setArguments:[NSArray arrayWithObjects:provisioningPath, applicationProvisioningPath, nil]];
    [provisioningTask launch];
    [provisioningTask waitUntilExit];
    
    if (provisioningTask.terminationReason != NSTaskTerminationReasonExit || provisioningTask.terminationStatus != 0)
        return [self createError:@"Failed to copy mobile provisioning."];

    if ([[NSFileManager defaultManager] fileExistsAtPath:applicationProvisioningPath])
    {
        bool isIdentifierOK = false;
        NSString* identifierInProvisioning = @"";
        
        NSString* embeddedProvisioning = [NSString stringWithContentsOfFile:applicationProvisioningPath encoding:NSASCIIStringEncoding error:nil];
        NSArray* embeddedProvisioningLines = [embeddedProvisioning componentsSeparatedByCharactersInSet: [NSCharacterSet newlineCharacterSet]];
        
        for (int i = 0; i <= [embeddedProvisioningLines count]; i++)
        {
            if ([[embeddedProvisioningLines objectAtIndex:i] rangeOfString:@"application-identifier"].location != NSNotFound)
            {
                NSInteger fromPosition = [[embeddedProvisioningLines objectAtIndex:i+1] rangeOfString:@"<string>"].location + 8;
                NSInteger toPosition   = [[embeddedProvisioningLines objectAtIndex:i+1] rangeOfString:@"</string>"].location;
                
                NSRange range;
                range.location = fromPosition;
                range.length   = toPosition - fromPosition;
                
                NSString* fullIdentifier = [[embeddedProvisioningLines objectAtIndex:i+1] substringWithRange:range];
                
                NSArray* identifierComponents = [fullIdentifier componentsSeparatedByString:@"."];
                
                if ([[identifierComponents lastObject] isEqualTo:@"*"])
                    isIdentifierOK = true;
                
                for (int i = 1; i < [identifierComponents count]; i++)
                {
                    identifierInProvisioning = [identifierInProvisioning stringByAppendingString:[identifierComponents objectAtIndex:i]];
                    if (i < [identifierComponents count]-1)
                        identifierInProvisioning = [identifierInProvisioning stringByAppendingString:@"."];
                }
                break;
            }
        }
        
        NSLog(@"Mobileprovision identifier: %@", identifierInProvisioning);
        
        NSString *infoPlist = [NSString stringWithContentsOfFile:[applicationPath stringByAppendingPathComponent:kInfoPlistFilename] encoding:NSASCIIStringEncoding error:nil];
        if ([infoPlist rangeOfString:identifierInProvisioning].location != NSNotFound)
        {
            NSLog(@"Identifiers match");
            isIdentifierOK = true;
        }
        
        if (!isIdentifierOK)
            return [self createError:@"Provisioning failed: Product identifiers don't match."];
        
        return nil;
    }
    else
        return [self createError:@"Provisioning failed."];
}

- (bool)doZip:(NSString*)destinationPath workingPath:(NSString*)workingPath
{
    NSTask* zipTask = [[NSTask alloc] init];
    [zipTask setLaunchPath:@"/usr/bin/zip"];
    [zipTask setCurrentDirectoryPath:workingPath];
    [zipTask setArguments:[NSArray arrayWithObjects:@"-qry", destinationPath, @".", nil]];
    [zipTask launch];
    [zipTask waitUntilExit];
    
    if (zipTask.terminationReason != NSTaskTerminationReasonExit || zipTask.terminationStatus != 0)
        return false;
    
    return true;
}

@end
