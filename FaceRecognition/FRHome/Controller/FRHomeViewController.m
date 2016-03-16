//
//  FRHomeViewController.m
//  FaceRecognition
//
//  Created by guoyi on 16/3/16.
//  Copyright © 2016年 郭毅. All rights reserved.
//

#import "FRHomeViewController.h"

#import "FRCaptureView.h"

@implementation FRHomeViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    FRCaptureView *captureView = [[FRCaptureView alloc] initWithFrame:self.view.bounds];
    [self.view addSubview:captureView];
    
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    
}

@end
