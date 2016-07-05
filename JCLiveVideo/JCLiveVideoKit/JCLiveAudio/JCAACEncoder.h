//
//  JCAACEncoder.h
//  JCLiveVideo
//
//  Created by seris-Jam on 16/6/27.
//  Copyright © 2016年 Jam. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import "JCFLVAudioFrame.h"

@class JCAACEncoder;

@protocol JAACEncoderDelegate <NSObject>

- (void)getAudioEncoder:(JCAACEncoder *)audioEncoder withAuidoFrame:(JCFLVAudioFrame *)audioFrame;

@end

@interface JCAACEncoder : NSObject

@property (nonatomic, weak) id<JAACEncoderDelegate> delegate;

- (instancetype)init;

- (void)encodeAudioData:(AudioBufferList)inBufferList timeStamp:(uint64_t)timeStamp;

@end
