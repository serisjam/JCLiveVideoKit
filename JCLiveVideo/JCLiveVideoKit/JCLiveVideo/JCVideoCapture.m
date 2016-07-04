//
//  JCVideoCapture.m
//  JCLiveVideo
//
//  Created by 贾淼 on 16/6/25.
//  Copyright © 2016年 Jam. All rights reserved.
//

#import "JCVideoCapture.h"
#import "GPUImage.h"
#import "GPUImageBeautifyFilter.h"

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
        self.videoCaptureFrameRate = 60;
    }
    
    return self;
}

- (void)setVideoQualityLevel:(JCCaptureVideoQuality)videoQualityLevel {
    [self configSessionPreset:videoQualityLevel];
}

- (void)configSessionPreset:(JCCaptureVideoQuality)videoQualityLevel {
    switch (videoQualityLevel) {
        case JCCaptureVideo640x480:
            self.captureSessionPreset = AVCaptureSessionPreset640x480;
            break;
        case JCCaptureVideo960x540:
            self.captureSessionPreset = AVCaptureSessionPresetiFrame960x540;
            break;
        case JCCaptureVideo1280x720:
            self.captureSessionPreset = AVCaptureSessionPreset1280x720;
            break;
        default:
            break;
    }
}

- (BOOL)isNeedClip {
    return [self.captureSessionPreset isEqualToString:AVCaptureSessionPreset640x480] ? YES : NO;
}

@end

@interface JCVideoCapture () <GPUImageVideoCameraDelegate>

@property (nonatomic, strong) GPUImageVideoCamera *videoCamera;
@property (nonatomic, strong) GPUImageView *gpuImageView;
@property (nonatomic, strong) cameraCaptureOriginDataBlock captureOriginDataBlock;

@property(nonatomic, strong) GPUImageOutput<GPUImageInput> *filter;
@property (nonatomic, strong) GPUImageCropFilter *cropfilter;

@property (nonatomic, assign) UIView *embedView;

@end

@implementation JCVideoCapture

- (void)dealloc {
    
    self.captureOriginDataBlock = nil;
    [UIApplication sharedApplication].idleTimerDisabled = NO;
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    
    [_videoCamera stopCameraCapture];
    _videoCamera = nil;
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
    
    _videoCamera = [[GPUImageVideoCamera alloc] initWithSessionPreset:captureProperty.captureSessionPreset cameraPosition:AVCaptureDevicePositionFront];
    _videoCamera.outputImageOrientation = UIDeviceOrientationPortrait;
    _videoCamera.horizontallyMirrorFrontFacingCamera = NO;
    _videoCamera.horizontallyMirrorRearFacingCamera = NO;
    _videoCamera.frameRate = (int32_t)30;

    _gpuImageView = [[GPUImageView alloc] initWithFrame:[UIScreen mainScreen].bounds];
    [_gpuImageView setFillMode:kGPUImageFillModePreserveAspectRatioAndFill];
    [_gpuImageView setAutoresizingMask:UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight];
    [_gpuImageView setInputRotation:kGPUImageFlipHorizonal atIndex:0];

    self.beautyFace = YES;
    
    //进入后台或者切换前台的通知
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(willEnterBackground:) name:UIApplicationWillResignActiveNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(willEnterForeground:) name:UIApplicationDidBecomeActiveNotification object:nil];
}

#pragma mark -- Custom Method
- (void)processVideo:(GPUImageOutput *)output{
    __weak typeof(self) _self = self;
    @autoreleasepool {
        GPUImageFramebuffer *imageFramebuffer = output.framebufferForOutput;
        CVPixelBufferRef pixelBuffer = [imageFramebuffer pixelBuffer];
        if (_self.captureOriginDataBlock) {
            _self.captureOriginDataBlock(pixelBuffer);
        }
    }
}

#pragma mark public method

-(void) embedPreviewInView:(UIView *)aView {
    if(_gpuImageView.superview) [_gpuImageView removeFromSuperview];
    [aView insertSubview:_gpuImageView atIndex:0];
}

- (void) startRunning {
    [UIApplication sharedApplication].idleTimerDisabled = YES;
    [_videoCamera startCameraCapture];
}

- (void) stopRunning {
    [UIApplication sharedApplication].idleTimerDisabled = NO;
    [_videoCamera stopCameraCapture];
}

- (void)carmeraScanOriginBlock:(cameraCaptureOriginDataBlock)cameraCaptureOriginBlock {
    _captureOriginDataBlock = cameraCaptureOriginBlock;
}

- (void)setBeautyFace:(BOOL)beautyFace {
    
    _beautyFace = beautyFace;
    [_filter removeAllTargets];
    [_cropfilter removeAllTargets];
    [_videoCamera removeAllTargets];
    
    if (_beautyFace) {
        
        _filter = [[GPUImageBeautifyFilter alloc] init];
        
        __weak typeof(self) _self = self;
        [_filter setFrameProcessingCompletionBlock:^(GPUImageOutput *output, CMTime time){
            [_self processVideo:output];
        }];
        
    } else {
        _filter = [[GPUImageEmptyFilter alloc] init];
        
        __weak typeof(self) _self = self;
        [_filter setFrameProcessingCompletionBlock:^(GPUImageOutput *output, CMTime time){
            [_self processVideo:output];
        }];
    }
    
    if ([_videoCamera.captureSessionPreset isEqualToString:AVCaptureSessionPreset640x480]) {
        _cropfilter = [[GPUImageCropFilter alloc] initWithCropRegion:CGRectMake(0.125, 0, 0.75, 1)];
        [_videoCamera addTarget:_cropfilter];
        [_cropfilter addTarget:_filter];
    } else {
        [_videoCamera addTarget:_filter];
    }
    
    [_filter addTarget:_gpuImageView];

    if (_videoCamera.cameraPosition == AVCaptureDevicePositionFront) {
        [_gpuImageView setInputRotation:kGPUImageFlipHorizonal atIndex:0];
    } else {
        [_gpuImageView setInputRotation:kGPUImageNoRotation atIndex:0];
    }
}

- (void)swapFrontAndBackCameras {
    [_videoCamera rotateCamera];
    
    if (_videoCamera.cameraPosition == AVCaptureDevicePositionFront) {
        [_gpuImageView setInputRotation:kGPUImageFlipHorizonal atIndex:0];
    } else {
        [_gpuImageView setInputRotation:kGPUImageNoRotation atIndex:0];
    }
}

#pragma mark  NSNotification
- (void)willEnterBackground:(NSNotification*)notification {
    [UIApplication sharedApplication].idleTimerDisabled = NO;
    [_videoCamera pauseCameraCapture];
    runSynchronouslyOnVideoProcessingQueue(^{
        glFinish();
    });
}

- (void)willEnterForeground:(NSNotification*)notification {
    [_videoCamera resumeCameraCapture];
    [UIApplication sharedApplication].idleTimerDisabled = YES;
}


@end
