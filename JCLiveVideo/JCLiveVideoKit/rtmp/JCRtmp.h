//
//  JCRtmp.h
//  JCLiveVideo
//
//  Created by seris-Jam on 16/6/29.
//  Copyright © 2016年 Jam. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "JCRtmpConnectStatus.h"
#import "JCFLVVideoFrame.h"

@class JCRtmp;

@protocol JCRtmpConnectDelegate <NSObject>

- (void)JCRtmp:(JCRtmp *)rtmp withJCRtmpConnectStatus:(JCLiveStatus)liveStatus;

@end

@interface JCRtmp : NSObject

@property (nonatomic, assign) id<JCRtmpConnectDelegate> delegate;

- (instancetype)initWithPushURL:(NSString *)pushURL;

//连接
- (void)connect;
//断开连接
- (void)disConnect;

@end