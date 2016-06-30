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

#import "JCAudioCapture.h"
#import "JCAACEncoder.h"

#import "JCRtmp.h"

/**  时间戳 */
#define NOW (CACurrentMediaTime()*1000)

@interface ViewController () <JCH264EncoderDelegate, JAACEncoderDelegate>

@property (nonatomic, strong) JCVideoCapture *videoCapture;
@property (nonatomic, strong) JCH264Encoder *jcH264Encoder;

@property (nonatomic, strong) JCAudioCapture *audioCapture;
@property (nonatomic, strong) JCAACEncoder *audioEncoder;

@property (nonatomic, assign) uint64_t timestamp;

@property (nonatomic, strong) NSFileHandle *h264FileHandle;
@property (nonatomic, strong) NSFileHandle *aacFileHandle;

@property (nonatomic, strong) JCRtmp *rtmp;

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
    
    NSString *aacFile = [documentsDirectory stringByAppendingPathComponent:@"test.aac"];
    [fileManager removeItemAtPath:aacFile error:nil];
    [fileManager createFileAtPath:aacFile contents:nil attributes:nil];
    
    self.aacFileHandle = [NSFileHandle fileHandleForWritingAtPath:aacFile];
    
    self.rtmp = [[JCRtmp alloc] initWithPushURL:@"rtmp://192.168.10.253:1935/5showcam/stream111111"];
    
    self.jcH264Encoder = [[JCH264Encoder alloc] initWithJCLiveVideoQuality:JCLiveVideoQuality_Low1];
    [self.jcH264Encoder setDelegate:self];
    
    self.audioCapture = [[JCAudioCapture alloc] init];
    self.audioEncoder = [[JCAACEncoder alloc] init];
    [self.audioEncoder setDelegate:self];
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
    
    [self.audioCapture audioCaptureOriginBlock:^(AudioBufferList audioBufferList){
        [weakSelf.audioEncoder encodeAudioData:audioBufferList timeStamp:[weakSelf currentTimestamp]];
    }];
    
    [_videoCapture startRunning];
    [self.audioCapture startRunning];
    
    [self.rtmp connect];
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
    
    [_audioCapture stopRunning];
    
    [self.h264FileHandle closeFile];
    [self.aacFileHandle closeFile];
}

#pragma mark JCACCEncoderDelegate

- (void)getRawAACData:(NSData *)aacData withADTSHeaderData:(NSData *)adtsHeaderData {
    [self.aacFileHandle writeData:adtsHeaderData];
    [self.aacFileHandle writeData:aacData];
}

#pragma mark JCH264EncoderDelegate

- (void)getEncoder:(JCH264Encoder *)encoder withVideoFrame:(JCFLVVideoFrame *)videoFrame {
    [self.rtmp sendVideoFrame:videoFrame];
}

//- (void)getEncodedData:(NSData *)data isKeyFrame:(BOOL)isKeyFrame {
//    
//    if (self.h264FileHandle != NULL) {
//        const char bytes[] = "\x00\x00\x00\x01";
//        size_t length = (sizeof bytes) - 1; //string literals have implicit trailing '\0'
//        NSData *ByteHeader = [NSData dataWithBytes:bytes length:length];
//        [self.h264FileHandle writeData:ByteHeader];
//        [self.h264FileHandle writeData:data];
//    }
//}
//
//- (void)getSpsData:(NSData *)spsData withPpsData:(NSData *)ppsData {
//    
//    if (self.h264FileHandle != NULL) {
//        const char bytes[] = "\x00\x00\x00\x01";
//        size_t length = (sizeof bytes) - 1; //string literals have implicit trailing '\0'
//        NSData *ByteHeader = [NSData dataWithBytes:bytes length:length];
//        [self.h264FileHandle writeData:ByteHeader];
//        [self.h264FileHandle writeData:spsData];
//        [self.h264FileHandle writeData:ByteHeader];
//        [self.h264FileHandle writeData:ppsData];
//    }
//}

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
