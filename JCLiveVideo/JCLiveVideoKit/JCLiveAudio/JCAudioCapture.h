//
//  JCAudioCapture.h
//  JCLiveVideo
//
//  Created by 贾淼 on 16/6/25.
//  Copyright © 2016年 Jam. All rights reserved.
//

#import <AVFoundation/AVFoundation.h>
#import <AudioToolbox/AudioToolbox.h>


typedef void(^audioCaptureOriginDataBlock)(AudioBufferList audioBufferList);

@interface JCAudioCapture : NSObject

- (void)startRunning;
- (void)stopRunning;

//获取原始音频流
- (void)audioCaptureOriginBlock:(audioCaptureOriginDataBlock)audioCaptureOriginBlock;

@end
