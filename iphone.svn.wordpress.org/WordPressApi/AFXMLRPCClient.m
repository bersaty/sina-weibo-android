//
//  AFXMLRPCClient.m
//  WordPressApiExample
//
//  Created by Jorge Bernal on 12/13/11.
//  Copyright (c) 2011 Automattic. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "AFXMLRPCClient.h"
#import "AFHTTPRequestOperation.h"
#import "AFAuthenticationAlertView.h"
#import "XMLRPCEncoder.h"
#import "XMLRPCResponse.h"

static NSUInteger const kAFXMLRPCClientDefaultMaxConcurrentOperationCount = 4;

@implementation AFXMLRPCRequest
@synthesize method, parameters;
- (void)dealloc {
    self.method = nil;
    self.parameters = nil;

    [super dealloc];
}
@end

@implementation AFXMLRPCRequestOperation
@synthesize XMLRPCRequest, success, failure;
- (void)dealloc {
    self.XMLRPCRequest = nil;
    self.success = nil;
    self.failure = nil;

    [super dealloc];
}
@end

@interface AFXMLRPCClient ()
@property (readwrite, nonatomic, retain) NSURL *xmlrpcEndpoint;
@property (readwrite, nonatomic, retain) NSMutableDictionary *defaultHeaders;
@property (readwrite, nonatomic, retain) NSOperationQueue *operationQueue;
@end

@implementation AFXMLRPCClient {
    NSURL *_xmlrpcEndpoint;
    NSMutableDictionary *_defaultHeaders;
    NSOperationQueue *_operationQueue;
}
@synthesize xmlrpcEndpoint = _xmlrpcEndpoint;
@synthesize defaultHeaders = _defaultHeaders;
@synthesize operationQueue = _operationQueue;

#pragma mark - Creating and Initializing XML-RPC Clients

+ (AFXMLRPCClient *)clientWithXMLRPCEndpoint:(NSURL *)xmlrpcEndpoint {
    return [[[self alloc] initWithXMLRPCEndpoint:xmlrpcEndpoint] autorelease];
}

- (id)initWithXMLRPCEndpoint:(NSURL *)xmlrpcEndpoint {
    self = [super init];
    if (!self) {
        return nil;
    }
    
    self.xmlrpcEndpoint = xmlrpcEndpoint;
    
    self.defaultHeaders = [NSMutableDictionary dictionary];
    
	// Accept-Encoding HTTP Header; see http://www.w3.org/Protocols/rfc2616/rfc2616-sec14.html#sec14.3
	[self setDefaultHeader:@"Accept-Encoding" value:@"gzip"];
    
    NSString *applicationUserAgent = [[NSUserDefaults standardUserDefaults] objectForKey:@"UserAgent"];
    if (applicationUserAgent) {
        [self setDefaultHeader:@"User-Agent" value:applicationUserAgent];
    } else {
        [self setDefaultHeader:@"User-Agent" value:[NSString stringWithFormat:@"%@/%@ (%@, %@ %@, %@, Scale/%f)", [[[NSBundle mainBundle] infoDictionary] objectForKey:(NSString *)kCFBundleIdentifierKey], [[[NSBundle mainBundle] infoDictionary] objectForKey:(NSString *)kCFBundleVersionKey], @"unknown", [[UIDevice currentDevice] systemName], [[UIDevice currentDevice] systemVersion], [[UIDevice currentDevice] model], ([[UIScreen mainScreen] respondsToSelector:@selector(scale)] ? [[UIScreen mainScreen] scale] : 1.0)]];
    }
    
    self.operationQueue = [[[NSOperationQueue alloc] init] autorelease];
	[self.operationQueue setMaxConcurrentOperationCount:kAFXMLRPCClientDefaultMaxConcurrentOperationCount];

    return self;
}

- (void)dealloc {
    [_xmlrpcEndpoint release];
    [_defaultHeaders release];
    [_operationQueue release];
    [super dealloc];
}

#pragma mark - Managing HTTP Header Values

- (NSString *)defaultValueForHeader:(NSString *)header {
	return [self.defaultHeaders valueForKey:header];
}

- (void)setDefaultHeader:(NSString *)header value:(NSString *)value {
	[self.defaultHeaders setValue:value forKey:header];
}

- (void)setAuthorizationHeaderWithUsername:(NSString *)username password:(NSString *)password {
    // TODO: not implemented yet
//	NSString *basicAuthCredentials = [NSString stringWithFormat:@"%@:%@", username, password];
//    [self setDefaultHeader:@"Authorization" value:[NSString stringWithFormat:@"Basic %@", AFBase64EncodedStringFromString(basicAuthCredentials)]];
}

- (void)setAuthorizationHeaderWithToken:(NSString *)token {
    [self setDefaultHeader:@"Authorization" value:[NSString stringWithFormat:@"Token token=\"%@\"", token]];
}

- (void)clearAuthorizationHeader {
	[self.defaultHeaders removeObjectForKey:@"Authorization"];
}

#pragma mark - Creating Request Objects

- (NSMutableURLRequest *)requestWithMethod:(NSString *)method
                                parameters:(NSArray *)parameters {
    NSMutableURLRequest *request = [[[NSMutableURLRequest alloc] initWithURL:self.xmlrpcEndpoint] autorelease];
    [request setHTTPMethod:@"POST"];
    [request setAllHTTPHeaderFields:self.defaultHeaders];
    
    XMLRPCEncoder *encoder = [[XMLRPCEncoder alloc] init];
    [encoder setMethod:method withParameters:parameters];
    NSData *body = [[encoder encode] dataUsingEncoding:NSUTF8StringEncoding];
    [encoder release];
    [request setHTTPBody:body];
    
    return request;
}

- (NSMutableURLRequest *)streamingRequestWithMethod:(NSString *)method
                                         parameters:(NSArray *)parameters {
    NSMutableURLRequest *request = [[[NSMutableURLRequest alloc] initWithURL:self.xmlrpcEndpoint] autorelease];
    [request setHTTPMethod:@"POST"];
    [request setAllHTTPHeaderFields:self.defaultHeaders];
    
    XMLRPCEncoder *encoder = [[XMLRPCEncoder alloc] init];
    [encoder setMethod:method withParameters:parameters];
    [request setHTTPBodyStream:[encoder encodedStream]];
    [request setValue:[[encoder encodedLength] stringValue] forHTTPHeaderField:@"Content-Length"];
    [encoder release];
    
    return request;    
}

- (AFXMLRPCRequest *)XMLRPCRequestWithMethod:(NSString *)method
                                  parameters:(NSArray *)parameters {
    AFXMLRPCRequest *request = [[[AFXMLRPCRequest alloc] init] autorelease];
    request.method = method;
    request.parameters = parameters;

    return request;
}

#pragma mark - Creating HTTP Operations

- (AFHTTPRequestOperation *)HTTPRequestOperationWithRequest:(NSURLRequest *)request 
                                                    success:(void (^)(AFHTTPRequestOperation *operation, id responseObject))success
                                                    failure:(void (^)(AFHTTPRequestOperation *operation, NSError *error))failure {
    AFHTTPRequestOperation *operation = [[[AFHTTPRequestOperation alloc] initWithRequest:request] autorelease];
    

    void (^xmlrpcSuccess)(AFHTTPRequestOperation *, id) = ^(AFHTTPRequestOperation *operation, id responseObject) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(void) {
            XMLRPCResponse *response = [[XMLRPCResponse alloc] initWithData:responseObject];
            NSError *err = nil;
            if (getenv("WPDebugXMLRPC")) {
                NSLog(@"[XML-RPC] < %@", [response body]);
            }
            
            if ([response isFault]) {
                NSDictionary *usrInfo = [NSDictionary dictionaryWithObjectsAndKeys:[response faultString], NSLocalizedDescriptionKey, nil];
                err = [NSError errorWithDomain:@"XMLRPC" code:[[response faultCode] intValue] userInfo:usrInfo];
            }
            
            if ([response object] == nil) {
                NSDictionary *usrInfo = [NSDictionary dictionaryWithObjectsAndKeys:NSLocalizedString(@"Blog returned invalid data.", @""), NSLocalizedDescriptionKey, nil];
                err = [NSError errorWithDomain:@"XMLRPC" code:kNoXMLPrefix userInfo:usrInfo];
#ifndef DEBUG
                NSNumber *extra_debug = [[NSUserDefaults standardUserDefaults] objectForKey:@"extra_debug"];
                if ([extra_debug boolValue]) {
#endif
                    // Log the whole response for "invalid data"
                    WPFLog(@"Blog returned invalid data (URL: %@)\n%@", request.URL.absoluteString, operation.responseString);
#ifndef DEBUG
                }
#endif
            }
            
            id object = [[response object] copy];
            [response release];

            dispatch_async(dispatch_get_main_queue(), ^(void) {
                if (err) {
                    if (failure) {
                        failure(operation, err);
                    }
                } else {
                    if (success) {
                        success(operation, object);
                    }
                }
                [object release];
            });
        });        
    };
    void (^xmlrpcFailure)(AFHTTPRequestOperation *, NSError *) = ^(AFHTTPRequestOperation *operation, NSError *error) {
        if (getenv("WPDebugXMLRPC")) {
            NSLog(@"[XML-RPC] ! %@", [error localizedDescription]);
        }

        if (failure) {
            failure(operation, [WPError errorWithResponse:operation.response error:error]);
        }
    };
    [operation setCompletionBlockWithSuccess:xmlrpcSuccess failure:xmlrpcFailure];
    [operation setAuthenticationChallengeBlock:^(NSURLConnection *connection, NSURLAuthenticationChallenge *challenge) {
        NSURLCredential *credential = [[NSURLCredentialStorage sharedCredentialStorage] defaultCredentialForProtectionSpace:[challenge protectionSpace]];
        
        if ([challenge previousFailureCount] == 0 && credential) {
            [[challenge sender] useCredential:credential forAuthenticationChallenge:challenge];
        } else {
            dispatch_async(dispatch_get_main_queue(), ^(void) {
                AFAuthenticationAlertView *alert = [[AFAuthenticationAlertView alloc] initWithChallenge:challenge];
                [alert show];
                [alert release];
            });
        }        
    }];

    if (getenv("WPDebugXMLRPC")) {
        NSLog(@"[XML-RPC] > %@", [[[NSString alloc] initWithData:[request HTTPBody] encoding:NSUTF8StringEncoding] autorelease]);
    }
    
    return operation;
}

- (AFXMLRPCRequestOperation *)XMLRPCRequestOperationWithRequest:(AFXMLRPCRequest *)request
                                                        success:(AFXMLRPCRequestOperationSuccessBlock)success
                                                        failure:(AFXMLRPCRequestOperationFailureBlock)failure {
    AFXMLRPCRequestOperation *operation = [[[AFXMLRPCRequestOperation alloc] init] autorelease];
    operation.XMLRPCRequest = request;
    operation.success = success;
    operation.failure = failure;
    
    return operation;
}

- (AFHTTPRequestOperation *)combinedHTTPRequestOperationWithOperations:(NSArray *)operations success:(AFXMLRPCRequestOperationSuccessBlock)success failure:(AFXMLRPCRequestOperationFailureBlock)failure {
    NSMutableArray *parameters = [NSMutableArray array];
    
    for (AFXMLRPCRequestOperation *operation in operations) {
        NSDictionary *param = [NSDictionary dictionaryWithObjectsAndKeys:
                               operation.XMLRPCRequest.method, @"methodName",
                               operation.XMLRPCRequest.parameters, @"params",
                               nil];
        [parameters addObject:param];
    }
    
    NSURLRequest *request = [self requestWithMethod:@"system.multicall" parameters:parameters];
    AFXMLRPCRequestOperationSuccessBlock _success = ^(AFHTTPRequestOperation *multicallOperation, id responseObject) {
        NSArray *responses = (NSArray *)responseObject;
        for (int i = 0; i < [responses count]; i++) {
            AFXMLRPCRequestOperation *operation = [operations objectAtIndex:i];
            id object = [responses objectAtIndex:i];
            
            NSError *error = nil;
            if ([object isKindOfClass:[NSDictionary class]] && [object objectForKey:@"faultCode"] && [object objectForKey:@"faultString"]) {
                NSDictionary *usrInfo = [NSDictionary dictionaryWithObjectsAndKeys:[object objectForKey:@"faultString"], NSLocalizedDescriptionKey, nil];
                error = [NSError errorWithDomain:@"XMLRPC" code:[[object objectForKey:@"faultCode"] intValue] userInfo:usrInfo];
            } else if ([object isKindOfClass:[NSArray class]] && [object count] == 1) {
                object = [object objectAtIndex:0];
            }

            
            if (error) {
                if (operation.failure) {
                    operation.failure(operation, error);
                }
            } else {
                if (operation.success) {
                    operation.success(operation, object);
                }
            }
        }
        if (success) {
            success(multicallOperation, responseObject);
        }
    };
    AFXMLRPCRequestOperationFailureBlock _failure = ^(AFHTTPRequestOperation *multicallOperation, NSError *error) {
        for (AFXMLRPCRequestOperation *operation in operations) {
            if (operation.failure) {
                operation.failure(operation, error);
            }
        }
        if (failure) {
            failure(multicallOperation, error);
        }
    };
    AFHTTPRequestOperation *operation = [self HTTPRequestOperationWithRequest:request
                                                                      success:_success
                                                                      failure:_failure];
    return operation;
}

#pragma mark - Managing Enqueued HTTP Operations

- (void)enqueueHTTPRequestOperation:(AFHTTPRequestOperation *)operation {
    [self.operationQueue addOperation:operation];
}

- (void)enqueueXMLRPCRequestOperation:(AFXMLRPCRequestOperation *)operation {
    NSURLRequest *request = [self requestWithMethod:operation.XMLRPCRequest.method parameters:operation.XMLRPCRequest.parameters];
    AFHTTPRequestOperation *op = [self HTTPRequestOperationWithRequest:request success:operation.success failure:operation.failure];
    [self enqueueHTTPRequestOperation:op];
}

- (void)cancelAllHTTPOperations {
    for (AFHTTPRequestOperation *operation in [self.operationQueue operations]) {
        [operation cancel];
    }
}

#pragma mark - Making XML-RPC Requests

- (void)callMethod:(NSString *)method
        parameters:(NSArray *)parameters
           success:(void (^)(AFHTTPRequestOperation *operation, id responseObject))success
           failure:(void (^)(AFHTTPRequestOperation *operation, NSError *error))failure {
    NSURLRequest *request = [self requestWithMethod:method parameters:parameters];
    AFHTTPRequestOperation *operation = [self HTTPRequestOperationWithRequest:request success:success failure:failure];

    [self enqueueHTTPRequestOperation:operation];
}


@end
