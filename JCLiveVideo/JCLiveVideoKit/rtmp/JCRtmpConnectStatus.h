//
//  JCRtmpConnectStatus.h
//  JCLiveVideo
//
//  Created by seris-Jam on 16/6/30.
//  Copyright © 2016年 Jam. All rights reserved.
//

#import <Foundation/Foundation.h>

//请求响应的状态
typedef NS_ENUM (NSInteger, JCLiveStatus) {
    JCLiveStatusSuccess,
    JCLiveStatusConnect,
    JCLiveStatusDisConnect,
    JCLiveStatusFailed
};

@interface JCRtmpConnectStatus : NSObject

@property (nonatomic, assign) JCLiveStatus status;
@property (nonatomic, strong) NSString *errorMsg;

@end
