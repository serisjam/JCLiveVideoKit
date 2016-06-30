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

@property (nonatomic, assign) BOOL isVideoHeader;
@property (nonatomic, strong) JCRtmpFrameBuffer *frameBuffer;

@end

@implementation JCRtmp

- (instancetype)initWithPushURL:(NSString *)pushURL {
    
    self = [super init];
    
    if (self) {
        self.rtmpQueque = dispatch_queue_create("com.JCLiveKit.queue", nil);
        self.pushURL = pushURL;
        
        self.isVideoHeader = NO;
        self.frameBuffer = [[JCRtmpFrameBuffer alloc] init];
    }
    
    return self;
}

- (void)connect {
    
    __weak typeof(self) weakSelf = self;
    
    dispatch_async(_rtmpQueque, ^{
        if (_rtmp != NULL) {
            [weakSelf cleanAll];
        }
        
        //创建一个RTMP对象
        _rtmp = PILI_RTMP_Alloc();
        PILI_RTMP_Init(_rtmp);
        
        //设置推流URL
        if (PILI_RTMP_SetupURL(_rtmp, (char*)[weakSelf.pushURL cStringUsingEncoding:NSASCIIStringEncoding], NULL) < 0) {
            [weakSelf cleanAll];
            [weakSelf callBackFailed];
        }
        
        //设置为推流
        PILI_RTMP_EnableWrite(_rtmp);
        //RTMP超时
        _rtmp->Link.timeout = 2;
        
        //链接服务器
        if (PILI_RTMP_Connect(_rtmp, NULL, NULL) < 0) {
            [weakSelf cleanAll];
            [weakSelf callBackFailed];
        }
        
        RTMPError error;
        
        //链接流
        if (PILI_RTMP_ConnectStream(_rtmp, 0, &error) < 0) {
            [weakSelf cleanAll];
            [weakSelf callBackFailed];
        }
        
        if ([weakSelf.delegate respondsToSelector:@selector(JCRtmp:withJCRtmpConnectStatus:)]) {
            [weakSelf.delegate JCRtmp:weakSelf withJCRtmpConnectStatus:JCLiveStatusConnect];
        }
    });
}

- (void)disConnect {
    [self cleanAll];
    
    if ([self.delegate respondsToSelector:@selector(JCRtmp:withJCRtmpConnectStatus:)]) {
        [self.delegate JCRtmp:self withJCRtmpConnectStatus:JCLiveStatusDisConnect];
    }
}

- (void)sendVideoFrame:(JCFLVVideoFrame *)videoFrame {
    __weak typeof(self) weakSelf = self;
    dispatch_async(_rtmpQueque, ^{
        [weakSelf.frameBuffer addVideoFrame:videoFrame];
        [weakSelf sendFrameData];
    });
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
