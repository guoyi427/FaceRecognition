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
    int _exifOrientation;
    
    //  UI
    UIImageView *_preview;
    UIView *_leftEyeView;
    UIView *_rightEyeView;
    UIView *_mouthView;
    
    NSTimer *_updateTimer;
}

@end

@implementation FRCaptureView

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = [UIColor magentaColor];
        [self _prepareSession];
        [self _preparePreView];
        _updateTimer = [NSTimer scheduledTimerWithTimeInterval:1 target:self selector:@selector(_faceRecognition) userInfo:nil repeats:YES];
    }
    return self;
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
}

#pragma mark - Face Recognition

- (void)_faceRecognition {
    
    CIImage *faceImage = [CIImage imageWithCGImage:_preview.image.CGImage options:@{
                                                                                    CIDetectorImageOrientation : [NSNumber numberWithInt:_exifOrientation]
                                                                                    }];
    
    CIDetector *detector = [CIDetector detectorOfType:CIDetectorTypeFace
                                              context:nil
                                              options:@{
                                                        CIDetectorAccuracy : CIDetectorAccuracyLow
                                                        }];
    NSArray *faceFeatures = [detector featuresInImage:faceImage options:@{
                                                                          CIDetectorImageOrientation : [NSNumber numberWithInt:_exifOrientation]
                                                                          }];
    
    float width_screen = [UIScreen mainScreen].bounds.size.width;
    float height_screen = [UIScreen mainScreen].bounds.size.height;
    
    for (CIFaceFeature *feature in faceFeatures) {
        NSLog(@"feature = left Eye %@ right Eye %@ mouth %@", NSStringFromCGPoint(feature.leftEyePosition),
              NSStringFromCGPoint(feature.rightEyePosition),
              NSStringFromCGPoint(feature.mouthPosition));
        
        float x_position_left = feature.leftEyePosition.x / height_screen * width_screen;
        float y_position_left = feature.leftEyePosition.y / width_screen * height_screen;
        
        _leftEyeView.frame = CGRectMake(x_position_left, y_position_left, 10, 10);
        _rightEyeView.frame = CGRectMake(feature.rightEyePosition.x, feature.rightEyePosition.y, 10, 10);
        _mouthView.frame = CGRectMake(feature.mouthPosition.x, feature.mouthPosition.y, 30, 10);
    }
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
    
    UIDeviceOrientation deviceOrientation = [UIDevice currentDevice].orientation;
    
    enum {
        PHOTOS_EXIF_0ROW_TOP_0COL_LEFT			= 1, //   1  =  0th row is at the top, and 0th column is on the left (THE DEFAULT).
        PHOTOS_EXIF_0ROW_TOP_0COL_RIGHT			= 2, //   2  =  0th row is at the top, and 0th column is on the right.
        PHOTOS_EXIF_0ROW_BOTTOM_0COL_RIGHT      = 3, //   3  =  0th row is at the bottom, and 0th column is on the right.
        PHOTOS_EXIF_0ROW_BOTTOM_0COL_LEFT       = 4, //   4  =  0th row is at the bottom, and 0th column is on the left.
        PHOTOS_EXIF_0ROW_LEFT_0COL_TOP          = 5, //   5  =  0th row is on the left, and 0th column is the top.
        PHOTOS_EXIF_0ROW_RIGHT_0COL_TOP         = 6, //   6  =  0th row is on the right, and 0th column is the top.
        PHOTOS_EXIF_0ROW_RIGHT_0COL_BOTTOM      = 7, //   7  =  0th row is on the right, and 0th column is the bottom.
        PHOTOS_EXIF_0ROW_LEFT_0COL_BOTTOM       = 8  //   8  =  0th row is on the left, and 0th column is the bottom.
    };

    BOOL isUsingFrontFacingCamera = FALSE;
    AVCaptureDevicePosition currentCameraPosition = AVCaptureDevicePositionFront;
    
    if (currentCameraPosition != AVCaptureDevicePositionBack)
    {
        isUsingFrontFacingCamera = TRUE;
    }
    
    switch (deviceOrientation) {
        case UIDeviceOrientationPortraitUpsideDown:  // Device oriented vertically, home button on the top
            _exifOrientation = PHOTOS_EXIF_0ROW_LEFT_0COL_BOTTOM;
            break;
        case UIDeviceOrientationLandscapeLeft:       // Device oriented horizontally, home button on the right
            if (isUsingFrontFacingCamera)
                _exifOrientation = PHOTOS_EXIF_0ROW_BOTTOM_0COL_RIGHT;
            else
                _exifOrientation = PHOTOS_EXIF_0ROW_TOP_0COL_LEFT;
            break;
        case UIDeviceOrientationLandscapeRight:      // Device oriented horizontally, home button on the left
            if (isUsingFrontFacingCamera)
                _exifOrientation = PHOTOS_EXIF_0ROW_TOP_0COL_LEFT;
            else
                _exifOrientation = PHOTOS_EXIF_0ROW_BOTTOM_0COL_RIGHT;
            break;
        case UIDeviceOrientationPortrait:            // Device oriented vertically, home button on the bottom
        default:
            _exifOrientation = PHOTOS_EXIF_0ROW_RIGHT_0COL_TOP;
            break;
    }
    
    UIImage *image = [UIImage imageWithCGImage:cgImage scale:1 orientation:_exifOrientation];
    CGColorSpaceRelease(colorSpace);
    CGImageRelease(cgImage);
    CGContextRelease(cgContext);
    
    CVPixelBufferUnlockBaseAddress(imageBufferRef, 0);

    _preview.image = image;
}

@end
