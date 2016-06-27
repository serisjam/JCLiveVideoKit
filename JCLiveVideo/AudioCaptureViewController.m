//
//  AudioCaptureViewController.m
//  JCLiveVideo
//
//  Created by seris-Jam on 16/6/27.
//  Copyright © 2016年 Jam. All rights reserved.
//

#import <libkern/OSAtomic.h>

#import "AudioCaptureViewController.h"
#import "JCAudioCapture.h"
#import "JCAACEncoder.h"

@interface AudioCaptureViewController () <JAACEncoderDelegate>

@property (nonatomic, strong) JCAudioCapture *audioCapture;
@property (nonatomic, strong) JCAACEncoder *audioEncoder;

@property (nonatomic, assign) uint64_t timestamp;

@property (nonatomic, strong) NSFileHandle *aacFileHandle;

@end

/**  时间戳 */
#define NOW (CACurrentMediaTime()*1000)

@implementation AudioCaptureViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
    self.audioCapture = [[JCAudioCapture alloc] init];
    self.audioEncoder = [[JCAACEncoder alloc] init];
    
    //打开文件句柄, 记录音频文件
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = [paths objectAtIndex:0];
    
    NSString *h264File = [documentsDirectory stringByAppendingPathComponent:@"audio.aac"];
    [fileManager removeItemAtPath:h264File error:nil];
    [fileManager createFileAtPath:h264File contents:nil attributes:nil];
    
    self.aacFileHandle = [NSFileHandle fileHandleForWritingAtPath:h264File];
    
    [self.audioEncoder setDelegate:self];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    __weak typeof(self) weakSelf = self;
    [self.audioCapture audioCaptureOriginBlock:^(AudioBufferList audioBufferList){
        [weakSelf.audioEncoder encodeAudioData:audioBufferList timeStamp:[weakSelf currentTimestamp]];
    }];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

- (IBAction)onStart:(id)sender {
    [self.audioCapture startRunning];
}


- (IBAction)onStop:(id)sender {
    [self.audioCapture stopRunning];
    [self.aacFileHandle closeFile];
}

#pragma mark JCACCEncoderDelegate

- (void)getRawAACData:(NSData *)aacData withADTSHeaderData:(NSData *)adtsHeaderData {
    [self.aacFileHandle writeData:adtsHeaderData];
    [self.aacFileHandle writeData:aacData];
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
