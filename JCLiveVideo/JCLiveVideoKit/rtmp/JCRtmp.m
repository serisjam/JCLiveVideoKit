//
//  JCRtmp.m
//  JCLiveVideo
//
//  Created by seris-Jam on 16/6/29.
//  Copyright © 2016年 Jam. All rights reserved.
//

#import "JCRtmp.h"
#import "rtmp.h"

@interface JCRtmp ()

@property (nonatomic, strong) NSString *pushURL;
@property (nonatomic, strong) dispatch_queue_t rtmpQueque;

@end

@implementation JCRtmp

- (instancetype)initWithPushURL:(NSString *)pushURL {
    
    self = [super init];
    
    if (self) {
        self.rtmpQueque = dispatch_queue_create("com.JCLiveKit", nil);
        self.pushURL = pushURL;
    }
    
    return self;
}



@end
