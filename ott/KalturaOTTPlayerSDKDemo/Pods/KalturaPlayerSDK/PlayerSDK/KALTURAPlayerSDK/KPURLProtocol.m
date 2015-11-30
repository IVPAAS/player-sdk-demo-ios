//
//  KPURLProtocol.m
//  KALTURAPlayerSDK
//
//  Created by Nissim Pardo on 8/2/15.
//  Copyright (c) 2015 Kaltura. All rights reserved.
//

#import "KPURLProtocol.h"
#import "KCacheManager.h"
#import "NSDictionary+Cache.h"

static NSString * const KPURLProtocolHandledKey = @"KPURLProtocolHandledKey";

@interface KPURLProtocol()

@property (nonatomic, strong) NSURLConnection *connection;
//@property (nonatomic, strong) NSMutableData *mutableData;
//@property (nonatomic, strong) NSURLResponse *response;
@property (nonatomic, strong) CachedURLParams *cacheParams;

@end

@implementation KPURLProtocol

+ (BOOL)canInitWithRequest:(NSURLRequest *)request {
    if ([NSURLProtocol propertyForKey:KPURLProtocolHandledKey inRequest:request]) {
        return NO;
    }
    if ([request.URL.host isEqualToString:CacheManager.host]) {
        for (NSString *key in CacheManager.withDomain.allKeys) {
            if ([request.URL.absoluteString containsString:key]) {
                return YES;
            }
        }
    } else {
        for (NSString *key in CacheManager.subStrings.allKeys) {
            if ([request.URL.absoluteString containsString:key]) {
                return YES;
            }
        }
    }
    return NO;
}

+ (NSURLRequest *) canonicalRequestForRequest:(NSURLRequest *)request {
    return request;
}

- (void) startLoading {
    
    NSDictionary *cachedResponse = self.request.URL.absoluteString.cachedResponse;
    if (cachedResponse) {
        
        NSData *data = cachedResponse.data;
        NSString *mimeType = cachedResponse.mimeType;
        NSString *encoding = cachedResponse.encoding;
        
        NSURLResponse *response = [[NSURLResponse alloc] initWithURL:self.request.URL
                                                            MIMEType:mimeType
                                               expectedContentLength:data.length
                                                    textEncodingName:encoding];
        
        [self.client URLProtocol:self didReceiveResponse:response cacheStoragePolicy:NSURLCacheStorageNotAllowed];
        [self.client URLProtocol:self didLoadData:data];
        [self.client URLProtocolDidFinishLoading:self];
        
    } else {
        _cacheParams = [CachedURLParams new];
        _cacheParams.url = self.request.URL;
        NSMutableURLRequest *newRequest = [self.request mutableCopy];
        [NSURLProtocol setProperty:@YES forKey:KPURLProtocolHandledKey inRequest:newRequest];
    
        self.connection = [NSURLConnection connectionWithRequest:newRequest delegate:self];
        
    }
    
}

- (void) stopLoading {
    
    [self.connection cancel];
    _cacheParams.data = nil;
    
}

#pragma mark - NSURLConnectionDelegate

- (void) connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response {
    [self.client URLProtocol:self didReceiveResponse:response cacheStoragePolicy:NSURLCacheStorageNotAllowed];
    
    _cacheParams.response = response;
}

- (void) connection:(NSURLConnection *)connection didReceiveData:(NSData *)data {
    [self.client URLProtocol:self didLoadData:data];
    
    [_cacheParams.data appendData:data];
}

- (void) connectionDidFinishLoading:(NSURLConnection *)connection {
    [self.client URLProtocolDidFinishLoading:self];
    [_cacheParams storeCacheResponse];
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error {
    [self.client URLProtocol:self didFailWithError:error];
}


@end
