//
//  QBPreviewViewController.h
//  QBImagePicker
//
//  Created by Damien Legrand on 06/11/2015.
//  Copyright © 2015 Katsuma Tanaka. All rights reserved.
//

#import <UIKit/UIKit.h>
@import Photos;

@interface QBPreviewViewController : UIViewController

- (instancetype)initWithAsset:(PHAsset *)asset andThumbnail:(UIImage *)thumbnail;

@end
