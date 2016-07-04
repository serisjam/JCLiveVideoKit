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

@property (nonatomic, strong) NSData *data;
@property (nonatomic, strong) NSData *spsData;
@property (nonatomic, strong) NSData *ppsData;

@end