//
//  JCFLVVideoFrame.h
//  JCLiveVideo
//
//  Created by seris-Jam on 16/6/29.
//  Copyright © 2016年 Jam. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface JCFLVVideoFrame : NSObject

@property (nonatomic, assign) uint64_t timestamp;
@property (nonatomic, assign) BOOL isKeyFrame;

//flv格式tag header长度
@property (nonatomic, assign, readonly) NSInteger headerLength;
//flv格式tag data长度
@property (nonatomic, assign, readonly) NSInteger bodyLength;

- (instancetype)initWithSpsData:(NSData *)sps withPPSData:(NSData *)pps andBodyData:(NSData *)data;

- (unsigned char *)getHeaderData;
- (unsigned char *)getBodyData;

@end