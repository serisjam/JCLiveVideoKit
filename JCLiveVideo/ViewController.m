//
//  ViewController.m
//  JCLiveVideo
//
//  Created by 贾淼 on 16/6/25.
//  Copyright © 2016年 Jam. All rights reserved.
//

#import <libkern/OSAtomic.h>

#import "ViewController.h"

#import "JCVideoCapture.h"
#import "JCH264Encoder.h"

/**  时间戳 */
#define NOW (CACurrentMediaTime()*1000)

@interface ViewController () <JCH264EncoderDelegate>

@property (nonatomic, strong) JCVideoCapture *videoCapture;

@property (nonatomic, strong) JCH264Encoder *jcH264Encoder;

@property (nonatomic, assign) uint64_t timestamp;

@property (nonatomic, strong) NSFileHandle *h264FileHandle;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    _videoCapture = [[JCVideoCapture alloc] init];
    
    //打开文件句柄, 记录h264文件
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = [paths objectAtIndex:0];
    
    NSString *h264File = [documentsDirectory stringByAppendingPathComponent:@"test.h264"];
    [fileManager removeItemAtPath:h264File error:nil];
    [fileManager createFileAtPath:h264File contents:nil attributes:nil];
    
    self.h264FileHandle = [NSFileHandle fileHandleForWritingAtPath:h264File];
    
    self.jcH264Encoder = [[JCH264Encoder alloc] initWithJCLiveVideoQuality:JCLiveVideoQuality_Medium1];
    [self.jcH264Encoder setDelegate:self];

}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    
    [_videoCapture embedPreviewInView:self.view];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    __weak typeof(self) weakSelf = self;
    [_videoCapture carmeraScanOriginBlock:^(CMSampleBufferRef sampleBufferRef){
        [weakSelf.jcH264Encoder encodeVideoData:sampleBufferRef timeStamp:[weakSelf currentTimestamp]];
    }];
    
    [_videoCapture startRunning];
}

- (void)viewDidDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    
    [_videoCapture stopRunning];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark event

- (IBAction)onSwitch:(id)sender {
//    [_videoCapture swapFrontAndBackCameras];
    
    [_videoCapture stopRunning];
    [self.jcH264Encoder endVideoCompression];
    [self.h264FileHandle closeFile];
}

#pragma mark JCH264EncoderDelegate

- (void)getEncodedData:(NSData *)data isKeyFrame:(BOOL)isKeyFrame {
    
    if (self.h264FileHandle != NULL) {
        const char bytes[] = "\x00\x00\x00\x01";
        size_t length = (sizeof bytes) - 1; //string literals have implicit trailing '\0'
        NSData *ByteHeader = [NSData dataWithBytes:bytes length:length];
        [self.h264FileHandle writeData:ByteHeader];
        [self.h264FileHandle writeData:data];
    }
}

- (void)getSpsData:(NSData *)spsData withPpsData:(NSData *)ppsData {
    
    if (self.h264FileHandle != NULL) {
        const char bytes[] = "\x00\x00\x00\x01";
        size_t length = (sizeof bytes) - 1; //string literals have implicit trailing '\0'
        NSData *ByteHeader = [NSData dataWithBytes:bytes length:length];
        [self.h264FileHandle writeData:ByteHeader];
        [self.h264FileHandle writeData:spsData];
        [self.h264FileHandle writeData:ByteHeader];
        [self.h264FileHandle writeData:ppsData];
    }
}

#pragma mark private

- (uint64_t)currentTimestamp {
    static OSSpinLock lock;
    
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        lock = OS_SPINLOCK_INIT;
        _timestamp = NOW;
    });
    
    OSSpinLockLock(&lock);
    uint64_t currentts = NOW - _timestamp;
    OSSpinLockUnlock(&lock);
    
    return currentts;
}

@end
