//
//  JCRtmpFrameBuffer.h
//  JCLiveVideo
//
//  Created by seris-Jam on 16/6/30.
//  Copyright © 2016年 Jam. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "JCFLVVideoFrame.h"

@interface JCRtmpFrameBuffer : NSObject

- (NSInteger)getCount;
- (void)addVideoFrame:(JCFLVVideoFrame *)videoFrame;

- (JCFLVVideoFrame *)getFirstVideoFrame;

@end
