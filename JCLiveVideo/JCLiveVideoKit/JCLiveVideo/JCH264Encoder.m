//
//  JCH264Encoder.m
//  CaptureVideoDemo
//
//  Created by seris-Jam on 16/6/23.
//  Copyright © 2016年 Jam. All rights reserved.
//

#import "JCH264Encoder.h"

@interface JCLiveVideoproperties : NSObject

/// 视频分辨率宽
@property (nonatomic, assign) int width;

/// 视频分辨率高
@property (nonatomic, assign) int height;

/// 视频的帧率，即 fps
@property (nonatomic, assign) NSUInteger videoFrameRate;

/// 视频的最大帧率，即 fps
@property (nonatomic, assign) NSUInteger videoMaxFrameRate;

/// 视频的最小帧率，即 fps
@property (nonatomic, assign) NSUInteger videoMinFrameRate;

/// 最大关键帧间隔，可设定为 fps 的2倍，影响一个 gop 的大小
@property (nonatomic, assign) NSUInteger videoMaxKeyframeInterval;

/// 视频的码率，单位是 bps
@property (nonatomic, assign) NSUInteger videoBitRate;

/// 视频的最大码率，单位是 bps
@property (nonatomic, assign) NSUInteger videoMaxBitRate;

/// 视频的最小码率，单位是 bps
@property (nonatomic, assign) NSUInteger videoMinBitRate;

@property (nonatomic, assign) JCLiveVideoQuality liveVideoQuality;

- (instancetype)initWithJCLiveVideoQuality:(JCLiveVideoQuality)liveVideoQuality;
- (void)changeJCLiveVideoQuality:(JCLiveVideoQuality)liveVideoQuality;

@end

@implementation JCLiveVideoproperties

- (instancetype)initWithJCLiveVideoQuality:(JCLiveVideoQuality)liveVideoQuality {
    self = [super init];
    
    if (self) {
        self.liveVideoQuality = liveVideoQuality;
        [self configPropertiesWithJCLiveVideoQuality:liveVideoQuality];
    }
    
    return self;
}

- (void)configPropertiesWithJCLiveVideoQuality:(JCLiveVideoQuality)liveVideoQuality {
    switch (liveVideoQuality) {
        case JCLiveVideoQuality_Low1: {
            self.width = 480;
            self.height = 640;
            self.videoFrameRate = 15;
            self.videoMaxFrameRate = 20;
            self.videoMinFrameRate = 12;
            self.videoBitRate = 500 * 1024;
            self.videoMaxBitRate = 700 * 1024;
            self.videoMinBitRate = 400 * 1024;
        }
            break;
        case JCLiveVideoQuality_Low2: {
            self.width = 480;
            self.height = 640;
            self.videoFrameRate = 24;
            self.videoMaxFrameRate = 24;
            self.videoMinFrameRate = 15;
            self.videoBitRate = 600 * 1024;
            self.videoMaxBitRate = 900 * 1024;
            self.videoMinBitRate = 500 * 1024;
        }
            break;
        case JCLiveVideoQuality_Medium1: {
            self.width = 540;
            self.height = 960;
            self.videoFrameRate = 15;
            self.videoMaxFrameRate = 20;
            self.videoMinFrameRate = 12;
            self.videoBitRate = 800 * 1024;
            self.videoMaxBitRate = 900 * 1024;
            self.videoMinBitRate = 700 * 1024;
            
        }
            break;
        case JCLiveVideoQuality_Medium2: {
            self.width = 540;
            self.height = 960;
            self.videoFrameRate = 24;
            self.videoMaxFrameRate = 30;
            self.videoMinFrameRate = 15;
            self.videoBitRate = 800 * 1024;
            self.videoMaxBitRate = 900 * 1024;
            self.videoMinBitRate = 700 * 1024;
        }
            break;
        case JCLiveVideoQuality_High1: {
            self.width = 720;
            self.height = 1280;
            self.videoFrameRate = 15;
            self.videoMaxFrameRate = 20;
            self.videoMinFrameRate = 12;
            self.videoBitRate = 1000 * 1024;
            self.videoMaxBitRate = 1100 * 1024;
            self.videoMinBitRate = 800 * 1024;
        }
            break;
        case JCLiveVideoQuality_High2: {
            self.width = 720;
            self.height = 1280;
            self.videoFrameRate = 24;
            self.videoMaxFrameRate = 30;
            self.videoMinFrameRate = 15;
            self.videoBitRate = 1200 * 1024;
            self.videoMaxBitRate = 1400 * 1024;
            self.videoMinBitRate = 1000 * 1024;
        }
            break;
        default:
            break;
    }
    
    self.width = 368;
    self.height = 640;
    self.videoMaxKeyframeInterval = self.videoFrameRate*2;
}

- (void)changeJCLiveVideoQuality:(JCLiveVideoQuality)liveVideoQuality {
    self.liveVideoQuality = liveVideoQuality;
    [self configPropertiesWithJCLiveVideoQuality:liveVideoQuality];
}

@end

@interface JCH264Encoder ()

//视频质量选项
@property (nonatomic, strong) JCLiveVideoproperties *jcLiveVideoproperties;
//压缩session
@property (nonatomic, assign) VTCompressionSessionRef compressionSession;
//h.264 sps数据
@property (nonatomic, strong) NSData *sps;
//h.264 pps数据
@property (nonatomic, strong) NSData *pps;

@property (nonatomic, assign) NSInteger frameCount;

//是否在后台，在后台不编码
@property (nonatomic, assign) BOOL isBackGround;

@end

@implementation JCH264Encoder

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (instancetype)initWithJCLiveVideoQuality:(JCLiveVideoQuality)liveVideoQuality {
    self = [super init];
    
    if (self) {
        self.compressionSession = NULL;
        self.sps = nil;
        self.pps = nil;
        self.frameCount = 0;
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(willEnterBackground:) name:UIApplicationWillResignActiveNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(willEnterForeground:) name:UIApplicationDidBecomeActiveNotification object:nil];
        
        self.jcLiveVideoproperties = [[JCLiveVideoproperties alloc] initWithJCLiveVideoQuality:liveVideoQuality];
        [self configVideoCompressonWith:_jcLiveVideoproperties];
    }
    
    return self;
}

- (void)changeJCLiveVideoQuality:(JCLiveVideoQuality)liveVideoQuality {
    
    if (self.jcLiveVideoproperties.liveVideoQuality == liveVideoQuality) {
        return ;
    }
    
    [self.jcLiveVideoproperties changeJCLiveVideoQuality:liveVideoQuality];
    
    VTCompressionSessionCompleteFrames(_compressionSession, kCMTimeInvalid);
    VTCompressionSessionInvalidate(_compressionSession);
    CFRelease(_compressionSession);
    _compressionSession = NULL;
    
    [self configVideoCompressonWith:_jcLiveVideoproperties];
    
}


- (void)configVideoCompressonWith:(JCLiveVideoproperties *)liveVideoProperties {
    
    NSDictionary* pixelBufferOptions = @{ (NSString*) kCVPixelBufferPixelFormatTypeKey : //@(kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange),
                                          @(kCVPixelFormatType_32BGRA),
                                          (NSString*) kCVPixelBufferWidthKey : @(liveVideoProperties.width),
                                          (NSString*) kCVPixelBufferHeightKey : @(liveVideoProperties.height),
                                          (NSString*) kCVPixelBufferOpenGLESCompatibilityKey : @YES,
                                          (NSString*) kCVPixelBufferIOSurfacePropertiesKey : @{}};
    
    dispatch_sync(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
        OSStatus status = VTCompressionSessionCreate(NULL, liveVideoProperties.width, liveVideoProperties.height, kCMVideoCodecType_H264, NULL, (__bridge CFDictionaryRef)pixelBufferOptions, NULL, &VideoCompressonOutputCallback, (__bridge void*)self, &_compressionSession);
        
        if (status != 0) {
            NSLog(@"VTCompressionSessionCreate error");
            return;
        }
        
        status = VTSessionSetProperty(_compressionSession, kVTCompressionPropertyKey_MaxKeyFrameInterval, (__bridge CFTypeRef)@(liveVideoProperties.videoMaxKeyframeInterval));
        status = VTSessionSetProperty(_compressionSession, kVTCompressionPropertyKey_MaxKeyFrameIntervalDuration, (__bridge CFTypeRef)@(liveVideoProperties.videoMaxKeyframeInterval));
        status = VTSessionSetProperty(_compressionSession, kVTCompressionPropertyKey_ExpectedFrameRate, (__bridge CFTypeRef)@(liveVideoProperties.videoFrameRate));
        status = VTSessionSetProperty(_compressionSession, kVTCompressionPropertyKey_AverageBitRate, (__bridge CFTypeRef)@(liveVideoProperties.videoBitRate));
        NSArray *dataLimits = @[@(liveVideoProperties.videoBitRate*1.5/8), @(1)];
        status = VTSessionSetProperty(_compressionSession, kVTCompressionPropertyKey_DataRateLimits, (__bridge CFArrayRef)dataLimits);
        status = VTSessionSetProperty(_compressionSession, kVTCompressionPropertyKey_RealTime, kCFBooleanFalse);
        status = VTSessionSetProperty(_compressionSession, kVTCompressionPropertyKey_ProfileLevel, kVTProfileLevel_H264_Main_AutoLevel);
        status = VTSessionSetProperty(_compressionSession, kVTCompressionPropertyKey_AllowFrameReordering, kCFBooleanFalse);
        status = VTSessionSetProperty(_compressionSession, kVTCompressionPropertyKey_H264EntropyMode, kVTH264EntropyMode_CABAC);

        VTCompressionSessionPrepareToEncodeFrames(_compressionSession);
    });
}


#pragma mark -- VideoCompressonCallBack
static void VideoCompressonOutputCallback(void *outputCallbackRefCon, void *sourceFrameRefCon, OSStatus status, VTEncodeInfoFlags infoFlags, CMSampleBufferRef sampleBuffer) {
    if (status != 0) {
        return ;
    }
    
    if (!CMSampleBufferDataIsReady(sampleBuffer)) {
        return;
    }
    
    CFArrayRef sampleBufferInfoArrary = CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, true);
    if (!sampleBufferInfoArrary) {
        return;
    }
    
    CFDictionaryRef dic = (CFDictionaryRef)CFArrayGetValueAtIndex(sampleBufferInfoArrary, 0);
    if (!dic) {
        return;
    }
    
    JCH264Encoder* encoder = (__bridge JCH264Encoder*)outputCallbackRefCon;
    BOOL isKeyFrame = !CFDictionaryContainsKey(dic, kCMSampleAttachmentKey_NotSync);
    uint64_t timeStamp = [((__bridge_transfer NSNumber*)sourceFrameRefCon) longLongValue];
    
    if (isKeyFrame && !encoder.sps) {
        CMFormatDescriptionRef formatDesc = CMSampleBufferGetFormatDescription(sampleBuffer);
        size_t sparameterSetSize, sparameterSetCount;
        const uint8_t *sparameterSet;
        
        OSStatus statusCode = CMVideoFormatDescriptionGetH264ParameterSetAtIndex(formatDesc, 0, &sparameterSet, &sparameterSetSize, &sparameterSetCount, 0);
    
        if (statusCode == noErr) {
            size_t pparameterSetSize, pparameterSetCount;
            const uint8_t *pparameterSet;
            
            OSStatus statusCode = CMVideoFormatDescriptionGetH264ParameterSetAtIndex(formatDesc, 1, &pparameterSet, &pparameterSetSize, &pparameterSetCount, 0);
            
            if (statusCode == noErr) {
                encoder.sps = [NSData dataWithBytes:sparameterSet length:sparameterSetSize];
                encoder.pps = [NSData dataWithBytes:pparameterSet length:pparameterSetSize];
            }
        }
    }
    
    CMBlockBufferRef dataBuffer = CMSampleBufferGetDataBuffer(sampleBuffer);
    
    size_t length, totalLength;
    char *dataPointer;
    
    OSStatus statusCode = CMBlockBufferGetDataPointer(dataBuffer, 0, &length, &totalLength, &dataPointer);
    
    if (statusCode == noErr) {
        
        size_t bufferOffset = 0;
        
        static const int AVCCHeaderLength = 4;
        
        while (bufferOffset < totalLength - AVCCHeaderLength) {
            
            uint32_t NALUnitLength = 0;
            memcpy(&NALUnitLength, dataPointer+bufferOffset, AVCCHeaderLength);
            
            NALUnitLength = CFSwapInt32BigToHost(NALUnitLength);
            
            JCFLVVideoFrame *videoFrame = [JCFLVVideoFrame new];
            videoFrame.data = [[NSData alloc] initWithBytes:(dataPointer + bufferOffset + AVCCHeaderLength) length:NALUnitLength];
            videoFrame.isKeyFrame = isKeyFrame;
            videoFrame.timestamp = timeStamp;
            videoFrame.spsData = encoder.sps;
            videoFrame.ppsData = encoder.pps;
            
            if ([encoder.delegate respondsToSelector:@selector(getEncoder:withVideoFrame:)]) {
                [encoder.delegate getEncoder:encoder withVideoFrame:videoFrame];
            }
            
            bufferOffset += AVCCHeaderLength + NALUnitLength;
        }
        
    }
}


#pragma mark -- NSNotification
- (void)willEnterBackground:(NSNotification*)notification{
    _isBackGround = YES;
}

- (void)willEnterForeground:(NSNotification*)notification{
    
    if (_compressionSession) {
        VTCompressionSessionCompleteFrames(_compressionSession, kCMTimeInvalid);
        VTCompressionSessionInvalidate(_compressionSession);
        CFRelease(_compressionSession);
        _compressionSession = NULL;
    }
    
    [self configVideoCompressonWith:self.jcLiveVideoproperties];
    
    _isBackGround = NO;
}

#pragma mark -VideoCompressEncoder
- (void)encodeVideoData:(CVImageBufferRef)imageBuffer timeStamp:(uint64_t)timeStamp{
    
    if (_isBackGround) {
        return ;
    }
    
    dispatch_sync(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
        _frameCount++;
        CMTime presentationTimeStamp = CMTimeMake(_frameCount, 1000);
        CMTime duration = CMTimeMake(1, (int32_t)self.jcLiveVideoproperties.videoFrameRate);
        
        NSDictionary *prorperties = nil;
        if (_frameCount % (int32_t)self.jcLiveVideoproperties.videoMaxFrameRate == 0) {
            prorperties = @{(__bridge NSString *)kVTEncodeFrameOptionKey_ForceKeyFrame : @YES};
        }
        
        NSNumber *timeNumber = @(timeStamp);
        VTEncodeInfoFlags flags;
        
        VTCompressionSessionEncodeFrame(_compressionSession, imageBuffer, presentationTimeStamp, duration, (__bridge CFDictionaryRef)prorperties, (__bridge_retained void *)timeNumber, &flags);
    });
    
}

- (void)endVideoCompression {
    VTCompressionSessionCompleteFrames(_compressionSession, kCMTimeInvalid);
}

@end
