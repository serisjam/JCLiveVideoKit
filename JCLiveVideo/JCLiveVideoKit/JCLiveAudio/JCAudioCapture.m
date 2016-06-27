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
    
}

@end
