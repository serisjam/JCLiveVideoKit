//
//  JCRtmp.m
//  JCLiveVideo
//
//  Created by seris-Jam on 16/6/29.
//  Copyright © 2016年 Jam. All rights reserved.
//

#import "JCRtmp.h"
#import "rtmp.h"

@interface JCRtmp () {
    PILI_RTMP *_rtmp;
}

@property (nonatomic, strong) NSString *pushURL;
@property (nonatomic, strong) dispatch_queue_t rtmpQueque;

@end

@implementation JCRtmp

- (instancetype)initWithPushURL:(NSString *)pushURL {
    
    self = [super init];
    
    if (self) {
        self.rtmpQueque = dispatch_queue_create("com.JCLiveKit.queue", nil);
        self.pushURL = pushURL;
    }
    
    return self;
}


- (void)connect {
    dispatch_async(self.rtmpQueque, ^{
        if (_rtmp != NULL) {
            [self cleanAll];
        }
        
        //创建rtmp
        _rtmp = PILI_RTMP_Alloc();
        PILI_RTMP_Init(_rtmp);
        
        //设置为发布流
        PILI_RTMP_EnableWrite(_rtmp);
        _rtmp->Link.timeout = 2;
        
        //连接服务器
        if (PILI_RTMP_Connect(_rtmp, NULL, NULL) < 0) {
            [self cleanAll];
        }
        
        //链接流
        if (PILI_RTMP_ConnectStream(_rtmp, 0, NULL) < 0) {
            [self cleanAll];
        }
        
    });
}

- (void)disConnect {
    [self cleanAll];
}

#pragma mark private method

- (void)cleanAll {
    //断开RTMP连接及释放rtmp内存
    PILI_RTMP_Close(_rtmp, NULL);
    PILI_RTMP_Free(_rtmp);
    //防止野指针
    _rtmp = NULL;
}

@end
