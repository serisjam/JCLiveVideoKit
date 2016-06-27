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

@end

@implementation JCAudioCapture

- (instancetype)init {
    self = [super init];
    
    if (self) {
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
    AudioBuffer buffer;
    buffer.mData = NULL;
    buffer.mDataByteSize = 0;
    buffer.mNumberChannels = 1;
    
    AudioBufferList buffers;
    buffers.mNumberBuffers = 1;
    buffers.mBuffers[0] = buffer;
    
    JCAudioCapture *source = (__bridge JCAudioCapture *)inRefCon;
    
    OSStatus status = AudioUnitRender(source.compentInstance, ioActionFlags, inTimeStamp, inBusNumber, inNumberFrames, &buffers);
    
    if (source.captureOriginDataBlock) {
        source.captureOriginDataBlock(buffers);
    }
    
    return status;
}

#pragma mark publich method

- (void)audioCaptureOriginBlock:(audioCaptureOriginDataBlock)captureOriginDataBlock {
    self.captureOriginDataBlock = captureOriginDataBlock;
}

- (void)startRunning {
    AudioOutputUnitStart(self.compentInstance);
}

- (void)stopRunning {
    AudioOutputUnitStop(self.compentInstance);
}

@end
