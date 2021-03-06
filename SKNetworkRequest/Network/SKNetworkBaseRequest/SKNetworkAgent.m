//
//  SKNetworkAgent.m
//  shavekevinRequest
//
//  Created by shavekevin on 16/3/8.
//  Copyright © 2016年 shavekevin. All rights reserved.
//

#import "SKNetworkAgent.h"
#import "SKNetworkBaseRequest.h"
#import "SKNetworkConfig.h"

@implementation SKNetworkAgent {
    /**
     *  networkManager
     */
    AFHTTPRequestOperationManager *_manager;
    /**
     *  配置
     */
    SKNetworkConfig *_config;
    /**
     *  a  dictionary  which can  remember  request
     */
    NSMutableDictionary *_requestRecord;
}
/**
 *  单例
 *
 *  @return 单例 Singleton
 */

+ (SKNetworkAgent *)sharedInstance {
    
    static SKNetworkAgent *shareInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        shareInstance = [[SKNetworkAgent alloc]init];
    });
    return shareInstance;
}
/**
 *  init
 *
 *  @return 初始化
 */
- (instancetype)init {
    
    if (self = [super init]) {
        _config = [SKNetworkConfig shareInstance];
        _manager = [AFHTTPRequestOperationManager manager];
        _manager.operationQueue.maxConcurrentOperationCount = 10;
        _requestRecord = [NSMutableDictionary dictionary];
        
        
    }
    return self;
}
/**
 *  @brief 构建网络请求  拼接基础URL
 *
 *  @param request the  request which needed
 *
 *  @return url  of request  which contains baseurl  and  cdnUrl
 */
- (NSString *)buildRequestUrl:(SKNetworkBaseRequest *)request {
    
    NSString *detailUrl = [request requestUrl];
    if ([detailUrl hasPrefix:@"http"]) {
        return detailUrl;
    }
    
    NSString *baseUrl;
    if ([request useCDN]) {
        if ([request cdnUrl].length > 0) {
            baseUrl = [request cdnUrl];
        } else {
            baseUrl = [_config  cdnUrl];
        }
    } else {
        if ([request baseUrl].length > 0) {
            baseUrl = [request baseUrl];
        } else {
            baseUrl = [_config baseUrl];
        }
    }
    
    NSString *bulidUrl = [NSString stringWithFormat:@"%@%@",baseUrl,detailUrl];
    return bulidUrl;
}

/**
 *  设置公共参数
 *
 *  @param dicParame 设置公共参数
 *
 *  @return 公共参数组成的字典
 */
- (NSDictionary *)baseRequestArgument:(NSDictionary *)dicParame {
    if (dicParame&& [dicParame isKindOfClass:[NSDictionary class]]) {
       // NSMutableDictionary *dict = [dicParame mutableCopy];
        //
      //  dicParame setValue:<#(nullable id)#> forKey:<#(nonnull NSString *)#>
       // return  dict;
    }
    return nil;
}

/**
 *  @brief 添加网络请求 同步还是异步
 *
 *  @param request request
 *  @param async   async  or  not
 */
- (void)addRequest:(SKNetworkBaseRequest *)request async:(BOOL)async {
    NSString *url = [self buildRequestUrl:request];
    id parame = request.requestArgument;
    parame = [self baseRequestArgument:parame];
    SKNetworkRequestMethod method = [request requestMethod];
    if (method == SKNetworkRequestMethodGet && parame) {
        NSData *data = [NSJSONSerialization dataWithJSONObject:parame options:NSJSONWritingPrettyPrinted error:nil];
        parame = [NSDictionary dictionaryWithObject:[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] forKey:@"queryJson"];
    }
    if (async) {
        
        [self asyncRequest:request url:url parame:parame];
    } else {
        
        [self syncRequest:request url:url parame:parame];
        
    }
}
/**
 *  @brief 同步网络请求
 *
 *  @param request request
 *  @param url      full url
 *  @param parame  dicParame
 */
- (void)asyncRequest:(SKNetworkBaseRequest *)request url:(NSString *)url  parame:(NSDictionary *)parame{
    
    SKNetworkRequestMethod method = [request requestMethod];
    AFConstructingBlock constructionBlock = [request constructingBodyBlock];
    if (request.requestSerializerType == SKNetworkRequestSerializerTypeHttp) {
        _manager.requestSerializer = [AFHTTPRequestSerializer serializer];
        
    } else if (request.requestSerializerType == SKNetworkRequestSerializerTypeJson){
        _manager.requestSerializer = [AFJSONRequestSerializer serializer];
    }
    _manager.requestSerializer.timeoutInterval =[request requestTimeoutInterval];
    //if api need  server username andd  password
    NSArray *authorizationHeaderFieldArray = [request requestAuthorizationHeaderFieldArray];
    if (authorizationHeaderFieldArray != nil) {
        [_manager.requestSerializer setAuthorizationHeaderFieldWithUsername:authorizationHeaderFieldArray.firstObject password:authorizationHeaderFieldArray.lastObject];
    }
    // if api need add custom value to httpheaderField
    NSDictionary *headerFieldValueDictionary = [request requestHeaderFieldValueDictionary];
    if (headerFieldValueDictionary != nil) {
        for (id httpHeaderField in headerFieldValueDictionary.allKeys) {
            id value = headerFieldValueDictionary[httpHeaderField];
            if ([httpHeaderField isKindOfClass:[NSString class]] && [value isKindOfClass:[NSString class]]) {
                [_manager.requestSerializer setValue:(NSString*)value forHTTPHeaderField:(NSString*)httpHeaderField];
            }
        }
    }
    // method  get post
    if (method == SKNetworkRequestMethodGet) {
        request.requestOperation = [_manager GET:url parameters:parame success:^(AFHTTPRequestOperation * _Nonnull operation, id  _Nonnull responseObject) {
            [self handleRequestResult:operation];
            
        } failure:^(AFHTTPRequestOperation * _Nullable operation, NSError * _Nonnull error) {
            [self handleRequestResult:operation];

        }];
    } else if (method == SKNetworkRequestMethodPost) {
        if (constructionBlock != nil) {
            request.requestOperation = [_manager POST:url parameters:parame constructingBodyWithBlock:constructionBlock success:^(AFHTTPRequestOperation * _Nonnull operation, id  _Nonnull responseObject) {
                
                [self handleRequestResult:operation];

            } failure:^(AFHTTPRequestOperation * _Nullable operation, NSError * _Nonnull error) {
                [self handleRequestResult:operation];

            }];
        }
        else {
            request.requestOperation = [_manager POST:url parameters:parame success:^(AFHTTPRequestOperation * _Nonnull operation, id  _Nonnull responseObject) {
                [self handleRequestResult:operation];

                
            } failure:^(AFHTTPRequestOperation * _Nullable operation, NSError * _Nonnull error) {
                [self handleRequestResult:operation];

            }];
        }
    }  else if (method == SKNetworkRequestMethodPut) {
        request.requestOperation = [_manager PUT:url parameters:parame success:^(AFHTTPRequestOperation * _Nonnull operation, id  _Nonnull responseObject) {
            [self handleRequestResult:operation];

            
        } failure:^(AFHTTPRequestOperation * _Nullable operation, NSError * _Nonnull error) {
            [self handleRequestResult:operation];

        }];
        
    } else {
        
        return;
    }
    [self addOperation:request];
    
}
/**
 *  @brief 异步网络请求
 *
 *  @param request request
 *  @param url     full url
 *  @param parame  dicParame
 */
- (void)syncRequest:(SKNetworkBaseRequest *)request url:(NSString *)url  parame:(NSDictionary *)parame{
    SKNetworkRequestMethod method = [request requestMethod];
    AFHTTPRequestSerializer *requestSerializer;
    if (request.requestSerializerType == SKNetworkRequestSerializerTypeHttp) {
        requestSerializer = [AFHTTPRequestSerializer serializer];
    } else if (request.requestSerializerType == SKNetworkRequestSerializerTypeJson){
        requestSerializer = [AFJSONRequestSerializer serializer];
        
    }
    if (method == SKNetworkRequestMethodGet) {
        NSMutableURLRequest *requestS = [requestSerializer requestWithMethod:@"GET" URLString:url parameters:parame error:nil];
        request.requestOperation = [[AFHTTPRequestOperation alloc]initWithRequest:requestS];
    } else if (method == SKNetworkRequestMethodPost) {
        NSMutableURLRequest *requestS = [requestSerializer requestWithMethod:@"POST" URLString:url parameters:parame error:nil];
        request.requestOperation = [[AFHTTPRequestOperation alloc]initWithRequest:requestS];
    } else if (method == SKNetworkRequestMethodPut) {
        NSMutableURLRequest *requestS = [requestSerializer requestWithMethod:@"PUT" URLString:url parameters:parame error:nil];
        request.requestOperation = [[AFHTTPRequestOperation alloc]initWithRequest:requestS];
    } else {
        
        return;
    }
    
    AFHTTPResponseSerializer *responseSerializer = [AFHTTPResponseSerializer serializer];
    [request.requestOperation setResponseSerializer:responseSerializer];
    [request.requestOperation start];
    [request.requestOperation waitUntilFinished];
    
    [self addOperation:request];
    [self handleRequestResult:request.requestOperation];
   
}
/**
 *  @brief 取消网络请求
 *
 *  @param request cancel Request
 */
- (void)cancleRequest:(SKNetworkBaseRequest *)request {
    
    [request.requestOperation cancel];
    [request clearCompletionBlock];
    [self removeOperation:request.requestOperation];
    
}
/**
 *  @brief 根据记录的网络请求  然后取消所有的网络请求
 */
- (void)cancleAllRequest {
    
    NSDictionary *copyRecord = [_requestRecord copy];
    for (NSString *key in copyRecord) {
        SKNetworkBaseRequest *request = copyRecord[key];
        [request stop];
    }
}
/**
 *  @brief 添加网络请求操作到记录字典中
 *
 *  @param request add  operationRequest
 */
- (void)addOperation:(SKNetworkBaseRequest*)request {
    
    if (request.requestOperation != nil) {
        NSString *key = [self requestHashKey:request.requestOperation];
        @synchronized(self) {
            _requestRecord[key] = request;
        }
    }
}
/**
 *  @brief 网络请求成功或者失败的处理
 *
 *  @param operation deal with  request which request success or failure
 */
- (void)handleRequestResult:(AFHTTPRequestOperation*)operation {
    
    NSString *key = [self requestHashKey:operation];
    SKNetworkBaseRequest *request = _requestRecord[key];
    if (request) {
        if ([request statusCodeValidator]) {
            [request requestSuccessCompleteFilter];
            if (request.delegate != nil) {
                [request.delegate requestFinished:request];
            }
            if (request.successCompletionBlock) {
                request.successCompletionBlock(request);
            }
        } else {
            
            
            [request requestFailureFilter];
            if (request.delegate != nil) {
                [request.delegate requestFailed:request];
            }
            if (request.failureCompletionBlock) {
                request.failureCompletionBlock(request);
            }
        }
    }
    
    [self removeOperation:operation];
    [request clearCompletionBlock];
    
}
/**
 *  @brief 从记录队列中移除网络请求
 *
 *  @param operation remove request from the queuerecord
 */
- (void)removeOperation:(AFHTTPRequestOperation*)operation {
    
    NSString* key = [self requestHashKey:operation];
    @synchronized(self) {
        
        [_requestRecord removeObjectForKey:key];
    }
}
/**
 *  @brief 转化
 *
 *  @param operation turn
 *
 *  @return string
 */
- (NSString*)requestHashKey:(AFHTTPRequestOperation*)operation {
    
    NSString* key = [NSString stringWithFormat:@"%lu", (unsigned long)[operation hash]];
    return key;
}
@end
