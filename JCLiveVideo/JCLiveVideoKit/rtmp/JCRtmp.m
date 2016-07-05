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
@property (nonatomic, assign) BOOL isAudioHeader;
@property (nonatomic, strong) JCRtmpFrameBuffer *frameBuffer;

@end

@implementation JCRtmp

- (instancetype)initWithPushURL:(NSString *)pushURL {
    
    self = [super init];
    
    if (self) {
        self.rtmpQueque = dispatch_queue_create("com.JCLiveKit.queue", nil);
        self.pushURL = pushURL;
        
        self.isVideoHeader = NO;
        self.isAudioHeader = NO;
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

- (void)sendAudioFrame:(JCFLVAudioFrame *)audioFrame {
    __weak typeof(self) weakSelf = self;
    dispatch_async(_rtmpQueque, ^{
        [weakSelf.frameBuffer addAudioFrame:audioFrame];
        [weakSelf sendFrameData];
    });
}

#pragma mark private method

- (void)cleanAll {
    //断开RTMP连接及释放rtmp内存
    PILI_RTMP_Close(_rtmp, NULL);
    PILI_RTMP_Free(_rtmp);
    //防止野指针
    _rtmp = NULL;
    
    self.isVideoHeader = NO;
    self.isAudioHeader = NO;
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
    
    id frame = [_frameBuffer getFirstFrame];
    
    if (frame == nil) {
        return ;
    }
    
    if ([frame isKindOfClass:[JCFLVVideoFrame class]]) {
        if (!_isVideoHeader) {
            _isVideoHeader = YES;
            [self sendVideoHeader:frame];
        } else {
            [self sendVideoData:frame];
        }
    } else {
        if (!_isAudioHeader) {
            _isAudioHeader = YES;
            [self sendAudioHeader:frame];
        } else {
            [self sendAudioData:frame];
        }
    }
}

//flv视频格式AVC头部封装
//原理来自 http://www.cnblogs.com/chef/archive/2012/07/18/2597279.html
- (void)sendVideoHeader:(JCFLVVideoFrame *)videoFrame {
    if (!videoFrame.spsData || !videoFrame.ppsData) {
        return ;
    }
    
    unsigned char * body=NULL;
    NSInteger iIndex = 0;
    NSInteger rtmpLength = 1024;
    const char *sps = videoFrame.spsData.bytes;
    const char *pps = videoFrame.ppsData.bytes;
    NSInteger sps_len = videoFrame.spsData.length;
    NSInteger pps_len = videoFrame.ppsData.length;
    
    body = (unsigned char*)malloc(rtmpLength);
    memset(body,0,rtmpLength);
    
    body[iIndex++] = 0x17;
    body[iIndex++] = 0x00;
    
    body[iIndex++] = 0x00;
    body[iIndex++] = 0x00;
    body[iIndex++] = 0x00;
    
    body[iIndex++] = 0x01;
    body[iIndex++] = sps[1];
    body[iIndex++] = sps[2];
    body[iIndex++] = sps[3];
    body[iIndex++] = 0xff;
    
    /*sps*/
    body[iIndex++]   = 0xe1;
    body[iIndex++] = (sps_len >> 8) & 0xff;
    body[iIndex++] = sps_len & 0xff;
    memcpy(&body[iIndex],sps,sps_len);
    iIndex +=  sps_len;
    
    /*pps*/
    body[iIndex++]   = 0x01;
    body[iIndex++] = (pps_len >> 8) & 0xff;
    body[iIndex++] = (pps_len) & 0xff;
    memcpy(&body[iIndex], pps, pps_len);
    iIndex +=  pps_len;
    
    [self sendPacket:RTMP_PACKET_TYPE_VIDEO data:body size:iIndex nTimestamp:videoFrame.timestamp];
    
    free(body);
}

//flv视频格式AVC头部封装
//原理来自 http://www.cnblogs.com/chef/archive/2012/07/18/2597279.html
- (void)sendVideoData:(JCFLVVideoFrame *)videoFrame {
    
    if(!videoFrame.data || videoFrame.data.length < 11) {
        return ;
    }
    
    NSInteger i = 0;
    NSInteger rtmpLength = videoFrame.data.length+9;
    unsigned char *body = (unsigned char*)malloc(rtmpLength);
    memset(body,0,rtmpLength);
    
    if(videoFrame.isKeyFrame){
        body[i++] = 0x17;// 1:Iframe  7:AVC
    } else{
        body[i++] = 0x27;// 2:Pframe  7:AVC
    }
    body[i++] = 0x01;// AVC NALU
    body[i++] = 0x00;
    body[i++] = 0x00;
    body[i++] = 0x00;
    body[i++] = (videoFrame.data.length >> 24) & 0xff;
    body[i++] = (videoFrame.data.length >> 16) & 0xff;
    body[i++] = (videoFrame.data.length >>  8) & 0xff;
    body[i++] = (videoFrame.data.length ) & 0xff;
    memcpy(&body[i], videoFrame.data.bytes, videoFrame.data.length);
    
    [self sendPacket:RTMP_PACKET_TYPE_VIDEO data:body size:rtmpLength nTimestamp:videoFrame.timestamp];
    
    free(body);
}


- (void)sendAudioHeader:(JCFLVAudioFrame *)audioFrame{
    if(!audioFrame || !audioFrame.audioInfo) return;
    
    NSInteger rtmpLength = audioFrame.audioInfo.length + 2;/*spec data长度,一般是2*/
    unsigned char * body = (unsigned char*)malloc(rtmpLength);
    memset(body,0,rtmpLength);
    
    /*AF 00 + AAC RAW data*/
    body[0] = 0xAF;
    body[1] = 0x00;
    memcpy(&body[2],audioFrame.audioInfo.bytes,audioFrame.audioInfo.length); /*spec_buf是AAC sequence header数据*/
    [self sendPacket:RTMP_PACKET_TYPE_AUDIO data:body size:rtmpLength nTimestamp:0];
    free(body);
}

- (void)sendAudioData:(JCFLVAudioFrame *)frame {
    if(!frame) return;
    
    NSInteger rtmpLength = frame.contentData.length + 2;/*spec data长度,一般是2*/
    unsigned char * body = (unsigned char*)malloc(rtmpLength);
    memset(body,0,rtmpLength);
    
    /*AF 01 + AAC RAW data*/
    body[0] = 0xAF;
    body[1] = 0x01;
    memcpy(&body[2],frame.contentData.bytes,frame.contentData.length);
    [self sendPacket:RTMP_PACKET_TYPE_AUDIO data:body size:rtmpLength nTimestamp:frame.timestamp];
    free(body);
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
