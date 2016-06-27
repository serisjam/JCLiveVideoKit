//
//  JCAACEncoder.m
//  JCLiveVideo
//
//  Created by seris-Jam on 16/6/27.
//  Copyright © 2016年 Jam. All rights reserved.
//

#import "JCAACEncoder.h"

@interface JCAACEncoder ()

@property (nonatomic, assign) AudioConverterRef m_converter;
@property (nonatomic, assign) char *aacBuf;

@end

@implementation JCAACEncoder

- (void)dealloc {
    if (self.aacBuf) {
        free(self.aacBuf);
    }
}

- (instancetype)init {
    self = [super init];
    
    if (self) {
    }
    
    return self;
}

- (void)encodeAudioData:(AudioBufferList)inBufferList timeStamp:(uint64_t)timeStamp {
    
    if (!self.aacBuf) {
        self.aacBuf = malloc(inBufferList.mBuffers[0].mDataByteSize);
    }
    
    [self createAudioConvert];
    
    AudioBufferList outBufferList;
    outBufferList.mNumberBuffers = 1;
    outBufferList.mBuffers[0].mNumberChannels = inBufferList.mBuffers[0].mNumberChannels;
    outBufferList.mBuffers[0].mDataByteSize = inBufferList.mBuffers[0].mDataByteSize;
    outBufferList.mBuffers[0].mData = self.aacBuf;
    
    UInt32 outputDataPacketSize = 1;
    if (AudioConverterFillComplexBuffer(_m_converter, inputDataProc, &inBufferList, &outputDataPacketSize, &outBufferList, NULL) != noErr) {
        return ;
    }
    
    NSData *rawAAC = [NSData dataWithBytes:outBufferList.mBuffers[0].mData length:outBufferList.mBuffers[0].mDataByteSize];
    NSData *adtsHeader = [self adtsDataForPacketLength:rawAAC.length];
    
    if ([self.delegate respondsToSelector:@selector(getRawAACData:withADTSHeaderData:)]) {
        [self.delegate getRawAACData:rawAAC withADTSHeaderData:adtsHeader];
    }
}

#pragma mark -- CustomMethod
-(BOOL)createAudioConvert{ //根据输入样本初始化一个编码转换器
    if (_m_converter != nil){
        return TRUE;
    }
    
    AudioStreamBasicDescription inputFormat = {0};
    inputFormat.mSampleRate = 44100;
    inputFormat.mFormatID = kAudioFormatLinearPCM;
    inputFormat.mFormatFlags = kAudioFormatFlagIsSignedInteger | kAudioFormatFlagsNativeEndian | kAudioFormatFlagIsPacked;
    inputFormat.mChannelsPerFrame = 2;
    inputFormat.mFramesPerPacket = 1;
    inputFormat.mBitsPerChannel = 16;
    inputFormat.mBytesPerFrame = inputFormat.mBitsPerChannel / 8 * inputFormat.mChannelsPerFrame;
    inputFormat.mBytesPerPacket = inputFormat.mBytesPerFrame * inputFormat.mFramesPerPacket;
    
    AudioStreamBasicDescription outputFormat; // 这里开始是输出音频格式
    memset(&outputFormat, 0, sizeof(outputFormat));
    outputFormat.mSampleRate       = inputFormat.mSampleRate; // 采样率保持一致
    outputFormat.mFormatID         = kAudioFormatMPEG4AAC;    // AAC编码 kAudioFormatMPEG4AAC kAudioFormatMPEG4AAC_HE_V2
    outputFormat.mChannelsPerFrame = 2;
    outputFormat.mFramesPerPacket  = 1024;                    // AAC一帧是1024个字节
    
    const OSType subtype = kAudioFormatMPEG4AAC;
    AudioClassDescription requestedCodecs[2] = {
        {
            kAudioEncoderComponentType,
            subtype,
            kAppleSoftwareAudioCodecManufacturer
        },
        {
            kAudioEncoderComponentType,
            subtype,
            kAppleHardwareAudioCodecManufacturer
        }
    };
    OSStatus result = AudioConverterNewSpecific(&inputFormat, &outputFormat, 2, requestedCodecs, &_m_converter);
    
    
    if(result != noErr) return NO;
    
    return YES;
}

#pragma mark -- AudioCallBack
//AudioConverterFillComplexBuffer 编码过程中，会要求这个函数来填充输入数据，也就是原始PCM数据
OSStatus inputDataProc(AudioConverterRef inConverter, UInt32 *ioNumberDataPackets, AudioBufferList *ioData,AudioStreamPacketDescription **outDataPacketDescription, void *inUserData) {
    AudioBufferList bufferList = *(AudioBufferList*)inUserData;
    ioData->mBuffers[0].mNumberChannels = 1;
    ioData->mBuffers[0].mData           = bufferList.mBuffers[0].mData;
    ioData->mBuffers[0].mDataByteSize   = bufferList.mBuffers[0].mDataByteSize;
    return noErr;
}


/**
 *  Add ADTS header at the beginning of each and every AAC packet.
 *  This is needed as MediaCodec encoder generates a packet of raw
 *  AAC data.
 *
 *  Note the packetLen must count in the ADTS header itself.
 *  See: http://wiki.multimedia.cx/index.php?title=ADTS
 *  Also: http://wiki.multimedia.cx/index.php?title=MPEG-4_Audio#Channel_Configurations
 **/
- (NSData *)adtsDataForPacketLength:(NSUInteger)packetLength
{
    int adtsLength = 7;
    char *packet = malloc(sizeof(char) * adtsLength);
    // Variables Recycled by addADTStoPacket
    int profile = 2;  //AAC LC
    //39=MediaCodecInfo.CodecProfileLevel.AACObjectELD;
    int freqIdx = 4;  //44.1KHz
    int chanCfg = 1;  //MPEG-4 Audio Channel Configuration. 1 Channel front-center
    NSUInteger fullLength = adtsLength + packetLength;
    // fill in ADTS data
    packet[0] = (char)0xFF;	// 11111111  	= syncword
    packet[1] = (char)0xF9;	// 1111 1 00 1  = syncword MPEG-2 Layer CRC
    packet[2] = (char)(((profile-1)<<6) + (freqIdx<<2) +(chanCfg>>2));
    packet[3] = (char)(((chanCfg&3)<<6) + (fullLength>>11));
    packet[4] = (char)((fullLength&0x7FF) >> 3);
    packet[5] = (char)(((fullLength&7)<<5) + 0x1F);
    packet[6] = (char)0xFC;
    NSData *data = [NSData dataWithBytesNoCopy:packet length:adtsLength freeWhenDone:YES];
    return data;
}

@end
