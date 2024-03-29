//
//  MFHTTP.m
//  MediaFireSDK
//
//  Created by Daniel Dean on 11/1/13.
//  Copyright (c) 2013 MediaFire. All rights reserved.
//

#import "MFHTTP.h"
#import "NSDictionary+MapObject.h"
#import "MFErrorMessage.h"
#import "MFErrorLog.h"
#import "MFURLRequestConfig.h"
#import "MFConfig.h"
#import "MFHTTPClientDelegate.h"

@implementation MFHTTP

//------------------------------------------------------------------------------
+ (void)execute:(MFURLRequestConfig*)config {
    if ([config.method isEqualToString:@"POST"]) {
        mflog(@"POST %@",[config.url absoluteString]);
        // construct the request
        if ((config.body != nil) || [config.localPathForUpload absoluteString].length) {
            // upload a file from it's path on disk.
            config.url = [self addParams:config.query toUrl:config.url];
            [MFHTTP uploadRequest:config];
        } else {
            // Normal text POST.
            config.body = [NSData dataWithBytes:[config.query cStringUsingEncoding:NSUTF8StringEncoding] length:[config.query length]];
            [MFHTTP standardRequest:config];
        }
    } else {
        config.url = [self addParams:config.query toUrl:config.url];
        mflog(@"GET %@",[config.url absoluteString]);
        if ([config.localPathForDownload absoluteString].length) {
            [MFHTTP downloadRequest:config];
        } else {
            [MFHTTP standardRequest:config];
        }
    }
}

//------------------------------------------------------------------------------
+ (NSMutableURLRequest*)createRequestFromConfig:(MFURLRequestConfig*)config {
    NSMutableURLRequest* request = [[NSMutableURLRequest alloc] initWithURL:config.url];
    [request setHTTPMethod:config.method];
    for (NSString* headerName in config.headers) {
        [request setValue:config.headers[headerName] forHTTPHeaderField:headerName];
    }
    return request;
}

//------------------------------------------------------------------------------
+ (BOOL)attemptRequestThruCustomClient:(MFURLRequestConfig*)config {
    if (config.httpClientId.length) {
        id client = [MFConfig httpClientById:config.httpClientId];
        if ([client conformsToProtocol:@protocol(MFHTTPClientDelegate)]) {
            [client addRequest:config];
            return true;
        }
    }
    return false;
}

//------------------------------------------------------------------------------
+ (void)downloadRequest:(MFURLRequestConfig*)config {
    if ([self attemptRequestThruCustomClient:config]) {
        return;
    }
    
    NSURL* localUrl = config.localPathForDownload;
    NSURLRequest* request = [self createRequestFromConfig:config];
    [[[MFConfig defaultHttpClient] downloadTaskWithRequest:request completionHandler:^(NSURL* location, NSURLResponse* response, NSError* error) {
        [MFConfig hideNetworkIndicator];

        NSHTTPURLResponse* httpResponse = (NSHTTPURLResponse*)response;
        // Some NSURLSession error
        if (error != nil) {
            erm(badHTTP:httpResponse.statusCode message:@"Unable to download file.");
            config.httpFail(nil, httpResponse.statusCode, nil);
            return;
        }
        // Likely an incorrect url
        if (httpResponse.statusCode != 200) {
            erm(badHTTP:httpResponse.statusCode message:@"Unable to find file.");
            config.httpFail(nil, httpResponse.statusCode, nil);
            return;
        }
        NSFileManager *fileManager = [NSFileManager defaultManager];
        NSError *errorCopy;
        [fileManager copyItemAtURL:location toURL:localUrl error:&errorCopy];
        
        if (httpResponse.statusCode == 200) {
            config.httpSuccess(@{@"filename" : [localUrl path]}, 200, nil);
        } else {
            erm(badHTTP:httpResponse.statusCode message:@"Unknown error.");
            config.httpFail(nil, httpResponse.statusCode, nil);
        }
    }] resume];
    [MFConfig showNetworkIndicator];
}

//------------------------------------------------------------------------------
+ (void)standardRequest:(MFURLRequestConfig*)config {
    if ([self attemptRequestThruCustomClient:config]) {
        return;
    }
    NSMutableURLRequest* request = [self createRequestFromConfig:config];
    if ([config.method isEqualToString:@"POST"]) {
        [request setHTTPBody:config.body];
    }
    [[[MFConfig defaultHttpClient] dataTaskWithRequest:request completionHandler:[self getCompletionHandlerFor:config]] resume];
    [MFConfig showNetworkIndicator];
}

//------------------------------------------------------------------------------
+ (HTTPCompletionHandler)getCompletionHandlerFor:(MFURLRequestConfig*)config {
    return ^(NSData* data, NSURLResponse* response, NSError* error) {
        [MFConfig hideNetworkIndicator];
        NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse*)response;
        NSString* responseText = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        if (error != nil) {
            config.httpFail(nil, httpResponse.statusCode, nil);
            return;
        }
        
        if (httpResponse.statusCode != 200) {
            config.httpFail(responseText, httpResponse.statusCode, nil);
        } else {
            if ((responseText == nil) && (data.length > 0)) {
                config.httpSuccess(nil, 200, @{@"blob" : data});
                return;
            }
            config.httpSuccess(responseText, 200, nil);
        }
        
    };
}

//------------------------------------------------------------------------------
+ (void)uploadRequest:(MFURLRequestConfig*)config {
    if ([self attemptRequestThruCustomClient:config]) {
        return;
    }
    NSURLRequest* request = [self createRequestFromConfig:config];
    if (config.localPathForUpload != nil) {
        [[[MFConfig defaultHttpClient] uploadTaskWithRequest:request fromFile:config.localPathForUpload completionHandler: [MFHTTP getCompletionHandlerFor:config]] resume];
        [MFConfig showNetworkIndicator];
        return;
    }
    if (config.body != nil) {
        [[[MFConfig defaultHttpClient] uploadTaskWithRequest:request fromData:config.body completionHandler: [MFHTTP getCompletionHandlerFor:config]] resume];
        [MFConfig showNetworkIndicator];
        return;
    }
    config.httpFail(nil, 0, nil);
}

//------------------------------------------------------------------------------
+ (NSURL*)addParams:(NSString*)query toUrl:(NSURL*)url {
    if (!query.length) {
        return url;
    }
    
    NSString* stringUrl = [url absoluteString];
    
    NSString* joiner = @"&";
    if ([stringUrl rangeOfString:@"?"].location == NSNotFound) {
        joiner = @"?";
    }
    
    NSString* combinedUrl = [NSString stringWithFormat:@"%@%@%@",stringUrl,joiner,query];
    return [NSURL URLWithString:combinedUrl];
}

@end
