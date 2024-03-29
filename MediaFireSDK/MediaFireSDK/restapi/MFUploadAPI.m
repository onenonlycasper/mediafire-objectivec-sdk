//
//  MFUploadAPI.m
//  MediaFireSDK
//
//  Created by Daniel Dean on 2/25/14.
//  Copyright (c) 2014 MediaFire. All rights reserved.
//

#import "MFUploadAPI.h"
#import "NSDictionary+Callbacks.h"
#import "MFErrorMessage.h"
#import "MFREST.h"
#import "NSDictionary+MapObject.h"
#import "MFHTTPOptions.h"
#import "MFConfig.h"

@implementation MFUploadAPI

//------------------------------------------------------------------------------
- (id)init {
    self = [self initWithVersion:[MFConfig defaultAPIVersion]];
    if (self == nil) {
        return nil;
    }
    return self;
}

//------------------------------------------------------------------------------
- (id)initWithVersion:(NSString*)version {
    self = [super initWithPath:@"upload" version:version];
    if (self == nil) {
        return nil;
    }
    return self;
}

//------------------------------------------------------------------------------
- (void)check:(NSDictionary*)parameters callbacks:(NSDictionary*)callbacks {
    [self check:@{} query:parameters callbacks:callbacks];
}

- (void)check:(NSDictionary*)options query:(NSDictionary*)parameters callbacks:(NSDictionary*)callbacks {
    [self createRequest:[options merge:@{HURL : @"check.php",HMETHOD : @"POST"}]
                  query:parameters
              callbacks:callbacks];
}

//------------------------------------------------------------------------------
- (void)instant:(NSDictionary*)parameters callbacks:(NSDictionary*)callbacks {
    [self instant:@{} query:parameters callbacks:callbacks];
}

- (void)instant:(NSDictionary*)options query:(NSDictionary*)parameters callbacks:(NSDictionary*)callbacks {
    [self createRequest:[options merge:@{HURL : @"instant.php", HTOKEN: HTKT_PARA, HPARALLEL : HPTT_UPLOAD}]
                  query:parameters
              callbacks:callbacks];
}

//------------------------------------------------------------------------------
- (void)uploadFile:(NSDictionary*)options query:(NSDictionary*)parameters callbacks:(NSDictionary*)callbacks {
    NSDictionary* headers = [self getHeadersFrom:options];
    if (headers == nil) {
        callbacks.onerror([MFErrorMessage nullField]);
        return;
    }
    
    NSMutableDictionary* reqOptions = [[NSMutableDictionary alloc] initWithDictionary:
                                       @{HREQHEADERS    : headers, HTOKEN: HTKT_PARA, HPARALLEL : HPTT_UPLOAD}];
    reqOptions[HCLIENT] = options[HCLIENT];
    if (options[@"file_path"] != nil) {
        reqOptions[@"upload"]       = @"path";
        reqOptions[@"upload_path"]  = options[@"file_path"];
    } else {
        reqOptions[@"upload"]         = @"data";
        reqOptions[@"upload_data"]  = options[@"file_data"];
    }
    
    NSMutableDictionary* optionsMutable = [options mutableCopy];
    [optionsMutable addEntriesFromDictionary:@{@"type" : @"basic"}];
    
    [self upload:reqOptions query:optionsMutable callbacks:callbacks];
}

//------------------------------------------------------------------------------
- (void)uploadUnit:(NSDictionary*)fileInfo query:(NSDictionary*)parameters callbacks:(NSDictionary*)callbacks {
    [self uploadUnit:@{} fileInfo:fileInfo query:parameters callbacks:callbacks];
}

//------------------------------------------------------------------------------
- (void)uploadUnit:(NSDictionary*)options fileInfo:(NSDictionary*)fileInfo query:(NSDictionary*)parameters callbacks:(NSDictionary*)callbacks {
    NSDictionary* headers = [self getHeadersFrom:fileInfo];
    if (headers == nil) {
        callbacks.onerror([MFErrorMessage nullField]);
        return;
    }
    NSDictionary* reqOptions = [options merge:
    @{HREQHEADERS   : headers,
      HUPTYPE       : @"data",
      HUPDATA       : fileInfo[@"unit_data"],
      HTOKEN        : HTKT_PARA,
      HPARALLEL     : HPTT_UPLOAD,
      HHOST         : MFREST.host}];
    
    [self upload:reqOptions query:parameters callbacks:callbacks];
}

//------------------------------------------------------------------------------
- (void)upload:(NSDictionary*)options query:(NSDictionary*)parameters callbacks:(NSDictionary *)callbacks {
    [self createRequest:[options merge:@{HURL : @"resumable.php", HURLPARAMS : @"true", HMETHOD : @"POST"}]
                  query:parameters
              callbacks:callbacks];
}

//------------------------------------------------------------------------------
- (void)pollUpload:(NSDictionary*)parameters callbacks:(NSDictionary*)callbacks {
    [self pollUpload:@{} query:parameters callbacks:callbacks];
}

- (void)pollUpload:(NSDictionary*)options query:(NSDictionary*)parameters callbacks:(NSDictionary*)callbacks {
    [self createRequest:[options merge:@{HURL : @"poll_upload.php",HMETHOD : @"POST", HTOKEN : HTKT_NONE}]
                  query:parameters
              callbacks:callbacks];
}

//------------------------------------------------------------------------------
- (NSDictionary*)getHeadersFrom:(NSDictionary*)info {
    // sanity check on normal upload
    if (info[@"file_name"] == nil || info[@"file_hash"] == nil || info[@"file_size"] == nil) {
        return nil;
    }
    NSMutableDictionary* headers = [[NSMutableDictionary alloc] initWithDictionary:
                                    @{@"x-filehash"  : info[@"file_hash"],
                                      @"x-filename"  : info[@"file_name"],
                                      @"x-filesize"  : info[@"file_size"],
                                      @"Content-Type": @"application/octet-stream"}];
    
    // sanity check on chunked upload
    if (info[@"unit_hash"] != nil || info[@"unit_id"] != nil || info[@"unit_size"] != nil) {
        if (info[@"unit_hash"] == nil || info[@"unit_id"] == nil || info[@"unit_size"] == nil) {
            return nil;
        }
        headers[@"x-unit-hash"] = info[@"unit_hash"];
        headers[@"x-unit-id"]   = info[@"unit_id"];
        headers[@"x-unit-size"] = info[@"unit_size"];
    }
    
    return headers;
}

@end
