//
//  JCH264Encoder.h
//  CaptureVideoDemo
//
//  Created by seris-Jam on 16/6/23.
//  Copyright © 2016年 Jam. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <VideoToolbox/VideoToolbox.h>

/// 视频质量
typedef NS_ENUM(NSUInteger, JCLiveVideoQuality){
    /// 分辨率： 480x360 帧数：24 码率：800Kps
    JCLiveVideoQuality_Low1 = 0,
    /// 分辨率： 480x360 帧数：30 码率：800Kps
    JCLiveVideoQuality_Low2 = 1,
    /// 分辨率： 640x480 帧数：24 码率：800Kps
    JCLiveVideoQuality_Medium1 = 2,
    /// 分辨率： 640x480 帧数：30 码率：800Kps
    JCLiveVideoQuality_Medium2 = 3,
    /// 分辨率： 1280x720 帧数：24 码率：1000Kps
    JCLiveVideoQuality_High1 = 4,
    /// 分辨率： 1280x720 帧数：30 码率：1200Kps
    JCLiveVideoQuality_High2 = 5,
    /// 分辨率： 1920x1080 帧数：24 码率：1200Kps
    JCLiveVideoQuality_Best1 = 6,
    /// 分辨率： 1920x1080 帧数：30 码率：1400Kps
    JCLiveVideoQuality_Best2 = 7,
    /// 默认配置
    JCLiveVideoQuality_Default = JCLiveVideoQuality_High1
};

@protocol JCH264EncoderDelegate <NSObject>

- (void)getSpsData:(NSData *)spsData withPpsData:(NSData *)ppsData;
- (void)getEncodedData:(NSData *)data isKeyFrame:(BOOL)isKeyFrame;

@end


@interface JCH264Encoder : NSObject

@property (nonatomic, weak) id<JCH264EncoderDelegate> delegate;

- (instancetype)initWithJCLiveVideoQuality:(JCLiveVideoQuality)liveVideoQuality;

- (void)changeJCLiveVideoQuality:(JCLiveVideoQuality)liveVideoQuality;
- (void)changeJCLiveVideoOrientation:(UIInterfaceOrientation)fromInterfaceOrientation;

- (void)encodeVideoData:(CMSampleBufferRef)pixelBuffer timeStamp:(uint64_t)timeStamp;

- (void)endVideoCompression;

@end
