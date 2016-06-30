//
//  JCRtmpFrameBuffer.m
//  JCLiveVideo
//
//  Created by seris-Jam on 16/6/30.
//  Copyright © 2016年 Jam. All rights reserved.
//

#import <libkern/OSAtomic.h>

#import "JCRtmpFrameBuffer.h"

@interface JCRtmpFrameBuffer ()

@property (nonatomic, strong) NSMutableArray *buffers;
//取样帧容器
@property (nonatomic, strong) NSMutableArray *sampleBuffers;

@end

//最大保存帧数
static const NSInteger max = 1000;
//每10帧发送1帧
static const NSUInteger defaultMaxBuffers = 10;

@implementation JCRtmpFrameBuffer

- (instancetype)init {
    
    self = [super init];
    
    if (self) {
        self.buffers = [NSMutableArray arrayWithCapacity:max];
        self.sampleBuffers = [NSMutableArray arrayWithCapacity:defaultMaxBuffers];
    }
    
    return self;
}

- (NSInteger)getCount {
    return [self.buffers count];
}

- (void)addVideoFrame:(JCFLVVideoFrame *)videoFrame {
    
    static OSSpinLock lock;
    
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        lock = OS_SPINLOCK_INIT;
    });
    
    OSSpinLockLock(&lock);

    if (self.sampleBuffers.count < defaultMaxBuffers) {
        [self.sampleBuffers addObject:videoFrame];
    } else {
        /// 排序
        [self.sampleBuffers addObject:videoFrame];
        NSArray *sortedSendQuery = [self.sampleBuffers sortedArrayUsingFunction:frameDataCompare context:NULL];
        [self.sampleBuffers removeAllObjects];
        [self.sampleBuffers addObjectsFromArray:sortedSendQuery];
        /// 丢帧
        [self disCardVideoFrame];
        
        /// 把当前第一帧存入时间缓存中
        JCFLVVideoFrame *videoFrame = [self.sampleBuffers firstObject];
        if (videoFrame) {
            [self.sampleBuffers removeObjectAtIndex:0];
            [self.buffers addObject:videoFrame];
        }
    }
    
    OSSpinLockUnlock(&lock);
}

- (JCFLVVideoFrame *)getFirstVideoFrame {
    JCFLVVideoFrame *videoFrame = [self.buffers objectAtIndex:0];
    
    if (videoFrame) {
        [self.buffers removeObjectAtIndex:0];
        
        return videoFrame;
    }
    
    return nil;
}

#pragma mark private

NSInteger frameDataCompare(id obj1, id obj2, void *context){
    JCFLVVideoFrame *frame1 = (JCFLVVideoFrame*) obj1;
    JCFLVVideoFrame *frame2 = (JCFLVVideoFrame*) obj2;
    
    if (frame1.timestamp == frame2.timestamp)
        return NSOrderedSame;
    else if(frame1.timestamp > frame2.timestamp)
        return NSOrderedDescending;
    return NSOrderedAscending;
}

//丢弃过期时间帧
- (void)disCardVideoFrame {
    if (self.buffers.count < max) {
        return ;
    }
    
    //丢弃预测帧
    NSArray *discardFrames = [self getDiscardPBFrame];
    if (discardFrames.count > 0) {
        [self.buffers removeObjectsInArray:discardFrames];
        return;
    }
    
    //如果全是关键帧，丢帧最近的关键帧
    JCFLVVideoFrame *discardIFrame = [self getFirstIFrame];
    if (discardIFrame) {
        [self.buffers removeObject:discardIFrame];
    }
    
    //如果当前buffer中全是预测帧，就全部清空
    [self.buffers removeAllObjects];
}

//获取丢弃的预测帧指的是P或者B帧
- (NSArray *)getDiscardPBFrame {
    NSMutableArray *discardFrame = [NSMutableArray array];
    
    for (JCFLVVideoFrame *videoFrame in self.buffers) {
        if (videoFrame.isKeyFrame && discardFrame.count > 0) {
            break;
        } else  {
            [discardFrame addObject:videoFrame];
        }
    }
    
    return discardFrame;
}

- (JCFLVVideoFrame *)getFirstIFrame {
    
    for (JCFLVVideoFrame *iVideoFrame in self.buffers) {
        if (iVideoFrame.isKeyFrame ) {
            return iVideoFrame;
        }
    }
    
    return nil;
}

@end
