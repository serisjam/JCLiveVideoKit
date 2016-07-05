//
//  JCAudioCapture.m
//  JCLiveVideo
//
//  Created by 贾淼 on 16/6/25.
//  Copyright © 2016年 Jam. All rights reserved.
//

#import "JCAudioCapture.h"

@interface JCAudioCapture ()

@property (nonatomic, strong) AVAudioSession *audioSession;
@property (nonatomic, assign) AudioComponent component;
@property (nonatomic, assign) AudioComponentInstance compentInstance;

@property (nonatomic, strong) audioCaptureOriginDataBlock captureOriginDataBlock;

@property (nonatomic, assign) BOOL isRuning;

@end

@implementation JCAudioCapture

- (void)dealloc {

    [[NSNotificationCenter defaultCenter] removeObserver:self];
    
    dispatch_sync(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
        AudioOutputUnitStop(self.compentInstance);
        AudioComponentInstanceDispose(self.compentInstance);
        self.compentInstance = nil;
        self.component = nil;
        
    });
}

- (instancetype)init {
    self = [super init];
    
    if (self) {
        self.isRuning = NO;
        [self configAudioSession];
    }
    
    return self;
}

- (void)configAudioSession {
    self.audioSession = [AVAudioSession sharedInstance];
    
    //设置类别，播放还是录音还是VOIP
    [self.audioSession setCategory:AVAudioSessionCategoryPlayAndRecord withOptions:AVAudioSessionCategoryOptionDefaultToSpeaker|AVAudioSessionCategoryOptionMixWithOthers error:nil];
    
    //采样率
    [self.audioSession setPreferredSampleRate:44100 error:nil];
    
    //当激活session时给其他音频一个通知
    [self.audioSession setActive:YES withOptions:AVAudioSessionSetActiveOptionNotifyOthersOnDeactivation error:nil];
    
    //切换手机话筒和麦克风
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(microphoneDeviceChange:) name:AVAudioSessionRouteChangeNotification object:self.audioSession];
    //被其他语音输入打断
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(otherDeviceInterruption:) name:AVAudioSessionInterruptionNotification object:self.audioSession];
    
    
    //创建一个音频组件描述来标识一个音频单元
    AudioComponentDescription acd;
    acd.componentType = kAudioUnitType_Output;
    acd.componentSubType = kAudioUnitSubType_RemoteIO;
    acd.componentManufacturer = kAudioUnitManufacturer_Apple;
    
    //获取一个指向指定音频单元（集）的库的引用
    self.component = AudioComponentFindNext(NULL, &acd);
    
    //获取该音频单元实例
    OSStatus status = AudioComponentInstanceNew(self.component, &_compentInstance);
    
    if (status != noErr) {
        
    }
    
    //
    UInt32 oneFlag = 1;
    //bus 0输出端，1输入端
    UInt32 busOne = 1;
    //音频单元关联输入
    AudioUnitSetProperty(_compentInstance, kAudioOutputUnitProperty_EnableIO, kAudioUnitScope_Input, busOne, &oneFlag, sizeof(oneFlag));
    
    //声音格式设置
    AudioStreamBasicDescription format;
    memset(&format, 0, sizeof(format));
    
    format.mSampleRate = 44100;
    format.mFormatID = kAudioFormatLinearPCM;
    format.mFormatFlags = kAudioFormatFlagIsSignedInteger | kAudioFormatFlagsNativeEndian | kAudioFormatFlagIsPacked;
    // 1:单声道；2:立体声
    format.mChannelsPerFrame = 2;
    // 语音每采样点占用位数
    format.mBitsPerChannel = 16;
    format.mBytesPerFrame = format.mBitsPerChannel / 8 * format.mChannelsPerFrame;
    format.mFramesPerPacket = 1;
    format.mBytesPerPacket = format.mBytesPerFrame * format.mFramesPerPacket;
    //音频单元输出格式设置
    AudioUnitSetProperty(_compentInstance, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Output, 1, &format, sizeof(format));
    
    //音频输入处理回调
    AURenderCallbackStruct cbs;
    cbs.inputProcRefCon = (__bridge void *)self;
    cbs.inputProc = handleInputBuffer;
    AudioUnitSetProperty(_compentInstance, kAudioOutputUnitProperty_SetInputCallback, kAudioUnitScope_Global, 1, &cbs, sizeof(cbs));
    
    AudioUnitInitialize(_compentInstance);
    
    [self.audioSession setActive:YES error:nil];
    
}

#pragma mark -- AudioCallBack
static OSStatus handleInputBuffer(void *inRefCon,
                                  AudioUnitRenderActionFlags *ioActionFlags,
                                  const AudioTimeStamp *inTimeStamp,
                                  UInt32 inBusNumber,
                                  UInt32 inNumberFrames,
                                  AudioBufferList *ioData) {
    
    @autoreleasepool {
        JCAudioCapture *source = (__bridge JCAudioCapture *)inRefCon;
        
        if (!source) {
            return -1;
        }
        
        AudioBuffer buffer;
        buffer.mData = NULL;
        buffer.mDataByteSize = 0;
        buffer.mNumberChannels = 1;
        
        AudioBufferList buffers;
        buffers.mNumberBuffers = 1;
        buffers.mBuffers[0] = buffer;
        
        OSStatus status = AudioUnitRender(source.compentInstance, ioActionFlags, inTimeStamp, inBusNumber, inNumberFrames, &buffers);
        
        if (!source.isRuning) {
            dispatch_sync(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
                AudioOutputUnitStop(source.compentInstance);
            });
            
            return status;
        }
        
        if (source.isMuted) {
            for (int i = 0; i < buffers.mNumberBuffers; i++) {
                AudioBuffer ab = buffers.mBuffers[i];
                memset(ab.mData, 0, ab.mDataByteSize);
            }
        }
        
        if (source.captureOriginDataBlock && !status) {
            source.captureOriginDataBlock(buffers);
        }
        
        return status;
    }
}

#pragma mark publich method

- (void)audioCaptureOriginBlock:(audioCaptureOriginDataBlock)captureOriginDataBlock {
    self.captureOriginDataBlock = captureOriginDataBlock;
}

- (void)startRunning {
    if (_isRuning) {
        return ;
    }
    
    __weak typeof(self) weakSelf = self;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
        weakSelf.isRuning = YES;
        AudioOutputUnitStart(self.compentInstance);
    });
}

- (void)stopRunning {
    if (!_isRuning) {
        return ;
    }
    
    __weak typeof(self) weakSelf = self;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
        weakSelf.isRuning = NO;
        AudioOutputUnitStop(self.compentInstance);
    });
}

#pragma mark Notification

- (void)microphoneDeviceChange:(NSNotification *)notification {
    NSString* seccReason = @"";
    NSInteger  reason = [[[notification userInfo] objectForKey:AVAudioSessionRouteChangeReasonKey] integerValue];
    //  AVAudioSessionRouteDescription* prevRoute = [[notification userInfo] objectForKey:AVAudioSessionRouteChangePreviousRouteKey];
    switch (reason) {
        case AVAudioSessionRouteChangeReasonNoSuitableRouteForCategory:
            seccReason = @"The route changed because no suitable route is now available for the specified category.";
            break;
        case AVAudioSessionRouteChangeReasonWakeFromSleep:
            seccReason = @"The route changed when the device woke up from sleep.";
            break;
        case AVAudioSessionRouteChangeReasonOverride:
            seccReason = @"The output route was overridden by the app.";
            break;
        case AVAudioSessionRouteChangeReasonCategoryChange:
            seccReason = @"The category of the session object changed.";
            break;
        case AVAudioSessionRouteChangeReasonOldDeviceUnavailable:
            seccReason = @"The previous audio output path is no longer available.";
            break;
        case AVAudioSessionRouteChangeReasonNewDeviceAvailable:
            seccReason = @"A preferred new audio output path is now available.";
            break;
        case AVAudioSessionRouteChangeReasonUnknown:
        default:
            seccReason = @"The reason for the change is unknown.";
            break;
    }
    AVAudioSessionPortDescription *input = [[self.audioSession.currentRoute.inputs count] ? self.audioSession.currentRoute.inputs:nil objectAtIndex:0];
    if (input.portType == AVAudioSessionPortHeadsetMic) {
    }
}

- (void)otherDeviceInterruption:(NSNotification *)notification {
    NSInteger reason = 0;
    
    if ([notification.name isEqualToString:AVAudioSessionInterruptionNotification]) {
        __weak typeof(self) weakSelf = self;
        reason = [[[notification userInfo] objectForKey:AVAudioSessionInterruptionTypeKey] integerValue];
        if (reason == AVAudioSessionInterruptionTypeBegan) {
            if (weakSelf.isRuning) {
                dispatch_sync(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
                    AudioOutputUnitStop(weakSelf.compentInstance);
                });
            }
        }
        
        if (reason == AVAudioSessionInterruptionTypeEnded) {
            NSNumber* seccondReason = [[notification userInfo] objectForKey:AVAudioSessionInterruptionOptionKey] ;
            switch ([seccondReason integerValue]) {
                case AVAudioSessionInterruptionOptionShouldResume:
                    if (weakSelf.isRuning) {
                        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
                            AudioOutputUnitStart(weakSelf.compentInstance);
                        });
                    }
                    break;
                default:
                    break;
            }
        }
    };
}

@end
