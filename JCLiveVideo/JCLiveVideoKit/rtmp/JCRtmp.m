//
//  JCRtmp.m
//  JCLiveVideo
//
//  Created by seris-Jam on 16/6/29.
//  Copyright © 2016年 Jam. All rights reserved.
//

#import "JCRtmp.h"
#import "rtmp.h"

#import "JCRtmpFrameBuffer.h"

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
        self.rtmpQueque = dispatch_queue_create("com.JCLiveKit", nil);
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

#pragma mark private method

- (void)cleanAll {
    PILI_RTMP_Close(_rtmp, NULL);
    PILI_RTMP_Free(_rtmp);
    _rtmp = NULL;
    
    self.isVideoHeader = NO;
}

- (void)callBackFailed {
    if ([self.delegate respondsToSelector:@selector(JCRtmp:withJCRtmpConnectStatus:)]) {
        [self.delegate JCRtmp:self withJCRtmpConnectStatus:JCLiveStatusFailed];
    }
}

- (void)sendFrameData {
    if (!_rtmp || [_frameBuffer getCount] <= 0) {
        return ;
    }
    
    JCFLVVideoFrame *videoFrame = [_frameBuffer getFirstVideoFrame];
    
    if (videoFrame == nil) {
        return;
    }
    
    if (!_isVideoHeader) {
        _isVideoHeader = YES;
        unsigned char *videoHeaderData = [videoFrame getHeaderData];
        [self sendPacket:RTMP_PACKET_TYPE_VIDEO data:videoHeaderData size:videoFrame.headerLength nTimestamp:videoFrame.timestamp];
        free(videoHeaderData);
    } else {
        unsigned char *videoBodyData = [videoFrame getBodyData];
        [self sendPacket:RTMP_PACKET_TYPE_VIDEO data:videoBodyData size:videoFrame.bodyLength nTimestamp:videoFrame.timestamp];
        free(videoBodyData);
    }
}

-(NSInteger) sendPacket:(unsigned int)nPacketType data:(unsigned char *)data size:(NSInteger) size nTimestamp:(uint64_t) nTimestamp{
    NSInteger rtmpLength = size;
    PILI_RTMPPacket rtmp_pack;
    PILI_RTMPPacket_Reset(&rtmp_pack);
    PILI_RTMPPacket_Alloc(&rtmp_pack,(uint32_t)rtmpLength);
    
    rtmp_pack.m_nBodySize = (uint32_t)size;
    memcpy(rtmp_pack.m_body,data,size);
    rtmp_pack.m_hasAbsTimestamp = 0;
    rtmp_pack.m_packetType = nPacketType;
    if(_rtmp) rtmp_pack.m_nInfoField2 = _rtmp->m_stream_id;
    rtmp_pack.m_nChannel = 0x04;
    rtmp_pack.m_headerType = RTMP_PACKET_SIZE_LARGE;
    if (RTMP_PACKET_TYPE_AUDIO == nPacketType && size !=4){
        rtmp_pack.m_headerType = RTMP_PACKET_SIZE_MEDIUM;
    }
    rtmp_pack.m_nTimeStamp = (uint32_t)nTimestamp;
    
    NSInteger nRet = [self RtmpPacketSend:&rtmp_pack];
    
    PILI_RTMPPacket_Free(&rtmp_pack);
    return nRet;
}

- (NSInteger)RtmpPacketSend:(PILI_RTMPPacket*)packet{
    if (PILI_RTMP_IsConnected(_rtmp)){
        int success = PILI_RTMP_SendPacket(_rtmp,packet, 0, NULL);
        if (success > 0) {
            [self sendFrameData];
        }
        return success;
    }
    return -1;
}

@end
