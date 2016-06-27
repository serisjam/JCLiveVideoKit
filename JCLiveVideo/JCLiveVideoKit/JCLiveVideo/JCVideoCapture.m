//
//  JCVideoCapture.m
//  JCLiveVideo
//
//  Created by 贾淼 on 16/6/25.
//  Copyright © 2016年 Jam. All rights reserved.
//

#import "JCVideoCapture.h"

@interface JCVideoCaptureProperty ()

@property (nonatomic, strong) NSString *captureSessionPreset;

@end

@implementation JCVideoCaptureProperty

+ (JCVideoCaptureProperty *)defaultCaptureProperty {
    return [[self alloc] init];
}

- (instancetype)init {
    self = [super init];
    
    if (self) {
        [self configSessionPreset:JCCaptureVideo640x480];
        self.videoDevicePosition = JCVideoCaptureDevicePositionBack;
        self.videoCaptureFrameRate = 30;
    }
    
    return self;
}

- (void)setVideoQualityLevel:(JCCaptureVideoQuality)videoQualityLevel {
    [self configSessionPreset:videoQualityLevel];
}

- (void)configSessionPreset:(JCCaptureVideoQuality)videoQualityLevel {
    switch (videoQualityLevel) {
        case JCCaptureVideo480x360:
            self.captureSessionPreset = AVCaptureSessionPresetMedium;
            break;
        case JCCaptureVideo640x480:
            self.captureSessionPreset = AVCaptureSessionPreset640x480;
            break;
        case JCCaptureVideo1280x720:
            self.captureSessionPreset = AVCaptureSessionPreset1280x720;
            break;
        case JCCaptureVideo1920x1080:
            self.captureSessionPreset = AVCaptureSessionPreset1920x1080;
            break;
        default:
            break;
    }
}

@end

@interface JCVideoCapture () <AVCaptureVideoDataOutputSampleBufferDelegate, AVCaptureMetadataOutputObjectsDelegate>

@property (nonatomic, strong) AVCaptureSession *session;
@property (nonatomic, strong) AVCaptureVideoDataOutput *captureOutput;
@property (nonatomic, strong) AVCaptureVideoPreviewLayer *previewLayer;
@property (nonatomic, strong) cameraCaptureOriginDataBlock captureOriginDataBlock;

@property (nonatomic, assign) UIView *embedView;

@end

@implementation JCVideoCapture

- (void)dealloc {
    
    self.session = nil;
    self.captureOutput = nil;
    self.captureOriginDataBlock = nil;
    
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (instancetype)init {
    self = [self initWithJCCaptureVideoProperty:[JCVideoCaptureProperty defaultCaptureProperty]];
    
    if (self) {
    }
    
    return self;
}

- (instancetype)initWithJCCaptureVideoProperty:(JCVideoCaptureProperty *)captureProperty {
    self = [super init];
    
    if (self) {
        [self initializeCaptureWithProperty:captureProperty];
    }
    
    return self;
}

- (void)initializeCaptureWithProperty:(JCVideoCaptureProperty *)captureProperty {
    self.session = [[AVCaptureSession alloc] init];
    [self.session setSessionPreset:captureProperty.captureSessionPreset];
    
    AVCaptureDevice *device = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    NSError *error;
    CMTime frameDuration = CMTimeMake(1, captureProperty.videoCaptureFrameRate);
    
    NSArray *supportedFrameRateRanges = [device.activeFormat videoSupportedFrameRateRanges];
    BOOL frameRateSupported = NO;
    for (AVFrameRateRange *range in supportedFrameRateRanges) {
        if (CMTIME_COMPARE_INLINE(frameDuration, >=, range.minFrameDuration) &&
            CMTIME_COMPARE_INLINE(frameDuration, <=, range.maxFrameDuration)) {
            frameRateSupported = YES;
        }
    }
    if (frameRateSupported && [device lockForConfiguration:&error]) {
        [device setActiveVideoMaxFrameDuration:frameDuration];
        [device setActiveVideoMinFrameDuration:frameDuration];
        [device unlockForConfiguration];
    }
    
    AVCaptureDeviceInput *captureInput = [AVCaptureDeviceInput deviceInputWithDevice:device error:&error];
    [self.session addInput:captureInput];
    
    //进入后台或者切换前台的通知
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(willEnterBackground:) name:UIApplicationWillResignActiveNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(willEnterForeground:) name:UIApplicationDidBecomeActiveNotification object:nil];
    
    dispatch_queue_t dispatchQueue;
    dispatchQueue = dispatch_queue_create("com.jam.camera", NULL);
    
    _captureOutput = [[AVCaptureVideoDataOutput alloc] init];
    _captureOutput.videoSettings = [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithUnsignedInt:kCVPixelFormatType_32BGRA], (id)kCVPixelBufferPixelFormatTypeKey, nil];
    _captureOutput.alwaysDiscardsLateVideoFrames = YES;
    [_captureOutput setSampleBufferDelegate:self queue:dispatchQueue];
    
    [self.session addOutput:_captureOutput];
    [self setRelativeVideoOrientation];
}

#pragma mark AVCaptureVideoDataOutputSampleBufferDelegate

- (void)captureOutput:(AVCaptureOutput *)captureOutput didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection {
    
    if (_captureOriginDataBlock) {
        _captureOriginDataBlock(sampleBuffer);
        return ;
    }
}

#pragma mark public method

-(void) embedPreviewInView:(UIView *)aView {
    if (!_session || _previewLayer) return;
    _previewLayer = [AVCaptureVideoPreviewLayer layerWithSession:_session];
    _previewLayer.frame = aView.bounds;
    _previewLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;
    _embedView = aView;
    [aView.layer insertSublayer:_previewLayer atIndex:0];
}

- (void) startRunning {
    [[self session] startRunning];
}

- (void) stopRunning {
    [[self session] stopRunning];
}

- (void)carmeraScanOriginBlock:(cameraCaptureOriginDataBlock)cameraCaptureOriginBlock {
    _captureOriginDataBlock = cameraCaptureOriginBlock;
}

- (void)swapFrontAndBackCameras {
    NSArray *inputs = self.session.inputs;
    for ( AVCaptureDeviceInput *input in inputs ) {
        AVCaptureDevice *device = input.device;
        if ( [device hasMediaType:AVMediaTypeVideo] ) {
            AVCaptureDevicePosition captureDevicePosition = device.position;
            AVCaptureDevice *newCamera = nil;
            AVCaptureDeviceInput *newInput = nil;
            
            if (captureDevicePosition == AVCaptureDevicePositionFront)
                newCamera = [self cameraWithPosition:AVCaptureDevicePositionBack];
            else
                newCamera = [self cameraWithPosition:AVCaptureDevicePositionFront];
            newInput = [AVCaptureDeviceInput deviceInputWithDevice:newCamera error:nil];
            
            [self.session beginConfiguration];
            [self.session removeInput:input];
            [self.session addInput:newInput];
            [self setRelativeVideoOrientation];
    
            [self.session commitConfiguration];
            break;
        }
    }
}

#pragma mark  NSNotification
- (void)willEnterBackground:(NSNotification*)notification {
    [self stopRunning];
}

- (void)willEnterForeground:(NSNotification*)notification {
    [self startRunning];
}


#pragma mark private

- (void)setRelativeVideoOrientation {
    AVCaptureConnection *connection = [_captureOutput connectionWithMediaType:AVMediaTypeVideo];
    switch ([[UIDevice currentDevice] orientation]) {
        case UIInterfaceOrientationPortrait:
#if defined(__IPHONE_8_0) && __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_8_0
        case UIInterfaceOrientationUnknown:
#endif
            connection.videoOrientation = AVCaptureVideoOrientationPortrait;
            
            break;
        case UIInterfaceOrientationPortraitUpsideDown:
            connection.videoOrientation =
            AVCaptureVideoOrientationPortraitUpsideDown;
            break;
        case UIInterfaceOrientationLandscapeLeft:
            connection.videoOrientation = AVCaptureVideoOrientationLandscapeLeft;
            break;
        case UIInterfaceOrientationLandscapeRight:
            connection.videoOrientation = AVCaptureVideoOrientationLandscapeRight;
            break;
        default:
            break;
    }
}

- (AVCaptureDevice *)cameraWithPosition:(AVCaptureDevicePosition)position
{
    NSArray *devices = [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
    for ( AVCaptureDevice *device in devices )
        if ( device.position == position )
            return device;
    return nil;
}

@end
