//
//  QBPreviewViewController.m
//  QBImagePicker
//
//  Created by Damien Legrand on 06/11/2015.
//  Copyright © 2015 Katsuma Tanaka. All rights reserved.
//

#import "QBPreviewViewController.h"

@interface QBPreviewViewController ()

@property (nonatomic, weak) UIImageView *imageView;

@property (nonatomic, strong) PHAsset *asset;
@property (nonatomic, strong) UIImage *thumbnail;

@property (nonatomic) BOOL startLoadingData;

@property (nonatomic) PHImageRequestID requestID;

@property (nonatomic, strong) AVPlayer *player;
@property (nonatomic, weak) AVPlayerLayer *playerLayer;

@end

@implementation QBPreviewViewController

- (instancetype)initWithAsset:(PHAsset *)asset andThumbnail:(UIImage *)thumbnail
{
    self = [super initWithNibName:nil bundle:nil];
    if(self)
    {
        _asset = asset;
        _thumbnail = nil;
        _requestID = PHInvalidImageRequestID;
        
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor clearColor];
    
    UIImageView *imageView = [[UIImageView alloc] initWithFrame:self.view.bounds];
    imageView.contentMode = UIViewContentModeScaleAspectFill;
    imageView.image = _thumbnail;
    
    [self.view addSubview:imageView];
    _imageView = imageView;
    
    CGFloat w = self.presentingViewController.view.bounds.size.width - 24;
    
    self.preferredContentSize = CGSizeMake(w, (w / _asset.pixelWidth) * _asset.pixelHeight);
    
    _thumbnail = nil;
    
    if (@available(iOS 11.0, *)) {
        self.imageView.accessibilityIgnoresInvertColors = YES;
    }
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    [self loadData];
}

- (void)viewDidDisappear:(BOOL)animated
{
    [super viewDidDisappear:animated];
    
}

- (void)viewDidLayoutSubviews
{
    [super viewDidLayoutSubviews];
    _imageView.frame = self.view.bounds;
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    if(_requestID != PHInvalidImageRequestID)
    {
        [[PHImageManager defaultManager] cancelImageRequest:_requestID];
    }
}

#pragma mark - Private Methods

- (void)loadData
{
    if(_startLoadingData) return;
    _startLoadingData = YES;
    
    if(_asset.mediaType == PHAssetMediaTypeImage)
    {
        [self loadImage];
    }
    else if (_asset.mediaType == PHAssetMediaTypeVideo)
    {
        [self loadVideo];
    }
}

- (void)loadImage
{
    PHImageRequestOptions *options = [PHImageRequestOptions new];
    options.networkAccessAllowed = YES;
    options.deliveryMode = PHImageRequestOptionsDeliveryModeOpportunistic;
    
    
    _requestID = [[PHImageManager defaultManager] requestImageForAsset:_asset targetSize:_imageView.bounds.size contentMode:PHImageContentModeAspectFill options:options resultHandler:^(UIImage * _Nullable result, NSDictionary * _Nullable info) {
        
        self.imageView.image = result;
        
    }];
}

- (void)loadVideo
{
    PHVideoRequestOptions *options = [PHVideoRequestOptions new];
    options.networkAccessAllowed = YES;
    
    
    _requestID = [[PHImageManager defaultManager] requestPlayerItemForVideo:_asset options:options resultHandler:^(AVPlayerItem * _Nullable playerItem, NSDictionary * _Nullable info) {
        
        if(playerItem == nil) return;
        
        dispatch_async(dispatch_get_main_queue(), ^(void){
            
            self.player = [[AVPlayer alloc] initWithPlayerItem:playerItem];
            AVPlayerLayer *layer = [AVPlayerLayer playerLayerWithPlayer:self.player];
            layer.videoGravity = AVLayerVideoGravityResizeAspectFill;
            layer.frame = self.view.bounds;
            [self.view.layer addSublayer:layer];
            self.playerLayer = layer;
            
            [self.player play];
            
        });
        
    }];
}

@end
