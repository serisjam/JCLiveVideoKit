//
//  LFStreamingBuffer.m
//  LFLiveKit
//
//  Created by 倾慕 on 16/5/2.
//  Copyright © 2016年 倾慕. All rights reserved.
//

#import "LFStreamingBuffer.h"
#import "NSMutableArray+LFAdd.h"

static const NSUInteger defaultSortBufferMaxCount = 10;///< 排序10个内
static const NSUInteger defaultUpdateInterval = 1;///< 更新频率为1s
static const NSUInteger defaultCallBackInterval = 5;///< 5s计时一次
static const NSUInteger defaultSendBufferMaxCount = 600;///< 最大缓冲区为600

@interface LFStreamingBuffer (){
    dispatch_semaphore_t _lock;
}

@property (nonatomic, strong) NSMutableArray <JCFLVVideoFrame*>*sortList;
@property (nonatomic, strong, readwrite) NSMutableArray <JCFLVVideoFrame*>*list;
@property (nonatomic, strong) NSMutableArray *thresholdList;

/** 处理buffer缓冲区情况 */
@property (nonatomic, assign) NSInteger currentInterval;
@property (nonatomic, assign) NSInteger callBackInterval;
@property (nonatomic, assign) NSInteger updateInterval;

@end

@implementation LFStreamingBuffer

- (instancetype)init{
    if(self = [super init]){
        _lock = dispatch_semaphore_create(1);
        self.updateInterval = defaultUpdateInterval;
        self.callBackInterval = defaultCallBackInterval;
        self.maxCount = defaultSendBufferMaxCount;
    }
    return self;
}

- (void)dealloc{
}

#pragma mark -- Custom
- (void)appendObject:(JCFLVVideoFrame*)frame{
    if(!frame) return;
    
    dispatch_semaphore_wait(_lock, DISPATCH_TIME_FOREVER);
    if(self.sortList.count < defaultSortBufferMaxCount){
        [self.sortList addObject:frame];
    }else{
        ///< 排序
        [self.sortList addObject:frame];
        NSArray *sortedSendQuery = [self.sortList sortedArrayUsingFunction:frameDataCompare context:NULL];
        [self.sortList removeAllObjects];
        [self.sortList addObjectsFromArray:sortedSendQuery];
        /// 丢帧
        [self removeExpireFrame];
        /// 添加至缓冲区
        JCFLVVideoFrame *firstFrame = [self.sortList lfPopFirstObject];
        
        if(firstFrame) [self.list addObject:firstFrame];
    }
    dispatch_semaphore_signal(_lock);
}

- (JCFLVVideoFrame*)popFirstObject{
    dispatch_semaphore_wait(_lock, DISPATCH_TIME_FOREVER);
    JCFLVVideoFrame *firstFrame = [self.list lfPopFirstObject];
    dispatch_semaphore_signal(_lock);
    return firstFrame;
}

- (void)removeAllObject{
    dispatch_semaphore_wait(_lock, DISPATCH_TIME_FOREVER);
    [self.list removeAllObjects];
    dispatch_semaphore_signal(_lock);
}

- (void)removeExpireFrame{
    if(self.list.count < self.maxCount) return;
    
    NSArray *pFrames = [self expirePFrames];///< 第一个P到第一个I之间的p帧
    if(pFrames && pFrames.count > 0){
        [self.list removeObjectsInArray:pFrames];
        return;
    }
    
    JCFLVVideoFrame *firstIFrame = [self firstIFrame];
    if(firstIFrame){
        [self.list removeObject:firstIFrame];
        return;
    }
    
    [self.list removeAllObjects];
}

- (NSArray*)expirePFrames{
    NSMutableArray *pframes = [[NSMutableArray alloc] init];
    for(NSInteger index = 0;index < self.list.count;index++){
        JCFLVVideoFrame *frame = [self.list objectAtIndex:index];
        if([frame isKindOfClass:[JCFLVVideoFrame class]]){
            JCFLVVideoFrame *videoFrame = (JCFLVVideoFrame*)frame;
            if(videoFrame.isKeyFrame && pframes.count > 0){
                break;
            }else{
                [pframes addObject:frame];
            }
        }
    }
    return pframes;
}

- (JCFLVVideoFrame*)firstIFrame{
    for(NSInteger index = 0;index < self.list.count;index++){
        JCFLVVideoFrame *frame = [self.list objectAtIndex:index];
        if([frame isKindOfClass:[JCFLVVideoFrame class]] && ((JCFLVVideoFrame*)frame).isKeyFrame){
            return frame;
        }
    }
    return nil;
}

NSInteger frameDataCompare(id obj1, id obj2, void *context){
    JCFLVVideoFrame* frame1 = (JCFLVVideoFrame*) obj1;
    JCFLVVideoFrame *frame2 = (JCFLVVideoFrame*) obj2;
    
    if (frame1.timestamp == frame2.timestamp)
        return NSOrderedSame;
    else if(frame1.timestamp > frame2.timestamp)
        return NSOrderedDescending;
    return NSOrderedAscending;
}

- (LFLiveBuffferState)currentBufferState{
    NSInteger currentCount = 0;
    NSInteger increaseCount = 0;
    NSInteger decreaseCount = 0;
    
    for(NSNumber *number in self.thresholdList){
        if(number.integerValue >= currentCount){
            increaseCount ++;
        }else{
            decreaseCount ++;
        }
        currentCount = [number integerValue];
    }
    
    if(increaseCount >= self.callBackInterval){
        return LFLiveBuffferIncrease;
    }
    
    if(decreaseCount >= self.callBackInterval){
        return LFLiveBuffferDecline;
    }
    
    return LFLiveBuffferUnknown;
}

#pragma mark -- Setter Getter
- (NSMutableArray*)list{
    if(!_list){
        _list = [[NSMutableArray alloc] init];
    }
    return _list;
}

- (NSMutableArray*)sortList{
    if(!_sortList){
        _sortList = [[NSMutableArray alloc] init];
    }
    return _sortList;
}

- (NSMutableArray*)thresholdList{
    if(!_thresholdList){
        _thresholdList = [[NSMutableArray alloc] init];
    }
    return _thresholdList;
}

@end
