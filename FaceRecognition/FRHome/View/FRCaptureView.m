//
//  FRCaptureView.m
//  FaceRecognition
//
//  Created by guoyi on 16/3/16.
//  Copyright © 2016年 郭毅. All rights reserved.
//

#import "FRCaptureView.h"

#import <AVFoundation/AVFoundation.h>
#import <CoreImage/CoreImage.h>

@interface FRCaptureView () <AVCaptureVideoDataOutputSampleBufferDelegate>
{
    AVCaptureSession *_session;
    AVCaptureDeviceInput *_deviceInput;
    AVCaptureVideoDataOutput *_videoDataOutput;
    dispatch_queue_t _videoOutQueue;
    
    //  UI
    UIImageView *_preview;
    UIView *_leftEyeView;
    UIView *_rightEyeView;
    UIView *_mouthView;
    UIImageView *_thumbnailImageView;
    
    NSTimer *_updateTimer;
    
    //  Data
    UIImageOrientation _imageOrientation;
}

@end

@implementation FRCaptureView

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = [UIColor magentaColor];
        [self _prepareData];
        [self _prepareSession];
        [self _preparePreView];
        _updateTimer = [NSTimer scheduledTimerWithTimeInterval:1 target:self selector:@selector(_faceRecognition) userInfo:nil repeats:YES];
    }
    return self;
}

- (void)_prepareData {
    _imageOrientation = UIImageOrientationRight;
}

- (void)_prepareSession {
    _session = [[AVCaptureSession alloc] init];
    
    AVCaptureDevice *frontDevice = nil;
    NSArray<AVCaptureDevice *> *devices = [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
    for (AVCaptureDevice *device in devices) {
        if (device.position == AVCaptureDevicePositionFront) {
            frontDevice = device;
            break;
        }
    }
    
    NSError *error;
    _deviceInput = [[AVCaptureDeviceInput alloc] initWithDevice:frontDevice error:&error];
    
    _videoOutQueue = dispatch_queue_create("videoDataOut", DISPATCH_QUEUE_PRIORITY_DEFAULT);

    _videoDataOutput = [[AVCaptureVideoDataOutput alloc] init];
    [_videoDataOutput setSampleBufferDelegate:self queue:dispatch_get_main_queue()];
    _videoDataOutput.videoSettings = @{
                                       (NSString *)kCVPixelBufferPixelFormatTypeKey : [NSNumber numberWithUnsignedInt:kCVPixelFormatType_32BGRA]
                                       };
    
    if ([_session canAddInput:_deviceInput]) {
        [_session addInput:_deviceInput];
    }
    
    if ([_session canAddOutput:_videoDataOutput]) {
        [_session addOutput:_videoDataOutput];
    }
    
//    AVCaptureVideoPreviewLayer *layer = [AVCaptureVideoPreviewLayer layerWithSession:_session];
//    layer.frame = self.frame;
//    layer.videoGravity = AVLayerVideoGravityResizeAspectFill;
//    [self.layer addSublayer:layer];
    
    [_session startRunning];
}

- (void)_preparePreView {
    _preview = [[UIImageView alloc] initWithFrame:self.bounds];
    _preview.contentMode = UIViewContentModeScaleAspectFit;
    [self addSubview:_preview];
    
    _leftEyeView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 10, 10)];
    _leftEyeView.backgroundColor = [UIColor redColor];
    [self addSubview:_leftEyeView];
    
    _rightEyeView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 10, 10)];
    _rightEyeView.backgroundColor = [UIColor yellowColor];
    [self addSubview:_rightEyeView];
    
    _mouthView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 30, 10)];
    _mouthView.backgroundColor = [UIColor blueColor];
    [self addSubview:_mouthView];
    
    _thumbnailImageView = [[UIImageView alloc] initWithFrame:CGRectMake(0, CGRectGetHeight(self.frame) - 100, 100, 100)];
    _thumbnailImageView.contentMode = UIViewContentModeScaleAspectFit;
    _thumbnailImageView.backgroundColor = [UIColor blackColor];
    [_preview addSubview:_thumbnailImageView];
}

#pragma mark - Face Recognition

- (void)_faceRecognition {
    
    NSDictionary *options = @{
                              CIDetectorImageOrientation : [NSNumber numberWithInt:_imageOrientation]
                              };
    
    CIImage *faceImage = [CIImage imageWithCGImage:_preview.image.CGImage];
    
    CIDetector *detector = [CIDetector detectorOfType:CIDetectorTypeFace
                                              context:nil
                                              options:@{
                                                        CIDetectorAccuracy : CIDetectorAccuracyLow,
                                                        }];
    NSArray *faceFeatures = [detector featuresInImage:faceImage options:options];
    for (CIFaceFeature *feature in faceFeatures) {
        NSLog(@"feature = left Eye %@ right Eye %@ mouth %@", NSStringFromCGPoint(feature.leftEyePosition),
              NSStringFromCGPoint(feature.rightEyePosition),
              NSStringFromCGPoint(feature.mouthPosition));
        _leftEyeView.frame = CGRectMake(feature.leftEyePosition.x, feature.leftEyePosition.y, 10, 10);
        _rightEyeView.frame = CGRectMake(feature.rightEyePosition.x, feature.rightEyePosition.y, 10, 10);
        _mouthView.frame = CGRectMake(feature.mouthPosition.x, feature.mouthPosition.y, 30, 10);
    }

    _thumbnailImageView.image = [UIImage imageWithCIImage:faceImage];
}

#pragma mark - AVCaptureVideoDataOutputSampleBuffer - Delegate

- (void)captureOutput:(AVCaptureOutput *)captureOutput didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection {
    CVImageBufferRef imageBufferRef = CMSampleBufferGetImageBuffer(sampleBuffer);
    
    CVPixelBufferLockBaseAddress(imageBufferRef, 0);
    unsigned char *screenBuffer = CVPixelBufferGetBaseAddress(imageBufferRef);
    
    size_t bytesPerRow = CVPixelBufferGetBytesPerRow(imageBufferRef);
    size_t width = CVPixelBufferGetWidth(imageBufferRef);
    size_t height = CVPixelBufferGetHeight(imageBufferRef);
    
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGContextRef cgContext = CGBitmapContextCreate(screenBuffer,
                                                   width,
                                                   height,
                                                   8,
                                                   bytesPerRow,
                                                   colorSpace,
                                                   kCGBitmapByteOrder32Little | kCGImageAlphaPremultipliedFirst);
    
    CGImageRef cgImage = CGBitmapContextCreateImage(cgContext);
    
    UIImage *image = [UIImage imageWithCGImage:cgImage scale:1 orientation:_imageOrientation];
    CGColorSpaceRelease(colorSpace);
    CGImageRelease(cgImage);
    CGContextRelease(cgContext);
    
    CVPixelBufferUnlockBaseAddress(imageBufferRef, 0);

    _preview.image = image;
}

@end
