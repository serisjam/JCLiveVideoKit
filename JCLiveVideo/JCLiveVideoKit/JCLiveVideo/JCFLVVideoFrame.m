//
//  JCFLVVideoFrame.m
//  JCLiveVideo
//
//  Created by seris-Jam on 16/6/29.
//  Copyright © 2016年 Jam. All rights reserved.
//

#import "JCFLVVideoFrame.h"

@interface JCFLVVideoFrame ()

@property (nonatomic, strong) NSData *spsData;
@property (nonatomic, strong) NSData *ppsData;

@property (nonatomic, strong) NSData *contentData;

@end

@implementation JCFLVVideoFrame

- (instancetype)init {
    self = [super init];
    
    if (self) {
        
    }
    
    return self;
}


- (instancetype)initWithSpsData:(NSData *)sps withPPSData:(NSData *)pps andBodyData:(NSData *)data {
    self = [super init];
    if (self) {
        _spsData = sps;
        _ppsData = pps;
        _contentData = data;
        
        _headerLength = 0;
        _bodyLength = 0;
    }
    
    return self;
}


//flv视频格式AVC头部封装
//原理来自 http://www.cnblogs.com/chef/archive/2012/07/18/2597279.html

- (unsigned char *)getHeaderData {
    
    if (!_spsData || !_ppsData) {
        return NULL;
    }
    
    unsigned char * body=NULL;
    NSInteger iIndex = 0;
    NSInteger rtmpLength = 1024;
    const char *sps = _spsData.bytes;
    const char *pps = _ppsData.bytes;
    NSInteger sps_len = _spsData.length;
    NSInteger pps_len = _ppsData.length;
    
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
    
    _headerLength = iIndex;
    
    return body;
}

- (unsigned char *)getBodyData {
    if(!_contentData || _contentData.length < 11) {
        return nil;
    }
    
    NSInteger i = 0;
    NSInteger rtmpLength = _contentData.length+9;
    unsigned char *body = (unsigned char*)malloc(rtmpLength);
    memset(body,0,rtmpLength);
    
    if(_isKeyFrame){
        body[i++] = 0x17;// 1:Iframe  7:AVC
    } else{
        body[i++] = 0x27;// 2:Pframe  7:AVC
    }
    body[i++] = 0x01;// AVC NALU
    body[i++] = 0x00;
    body[i++] = 0x00;
    body[i++] = 0x00;
    body[i++] = (_contentData.length >> 24) & 0xff;
    body[i++] = (_contentData.length >> 16) & 0xff;
    body[i++] = (_contentData.length >>  8) & 0xff;
    body[i++] = (_contentData.length ) & 0xff;
    memcpy(&body[i], _contentData.bytes, _contentData.length);
    
    _bodyLength = rtmpLength;
    
    return body;
}

@end
