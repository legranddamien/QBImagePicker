//
//  QBAlbumsViewController.m
//  QBImagePicker
//
//  Created by Katsuma Tanaka on 2015/04/03.
//  Copyright (c) 2015 Katsuma Tanaka. All rights reserved.
//

#import "QBAlbumsViewController.h"
#import <Photos/Photos.h>

// Views
#import "QBAlbumCell.h"

// ViewControllers
#import "QBImagePickerController.h"
#import "QBAssetsViewController.h"

#define LAST_ALBUM_KEY @"qb.albums.last_album.key"

static CGSize CGSizeScale(CGSize size, CGFloat scale) {
    return CGSizeMake(size.width * scale, size.height * scale);
}

@interface QBImagePickerController (Private)

@property (nonatomic, strong) NSBundle *assetBundle;

@end

@interface QBAlbumsViewController ()

@property (nonatomic, strong) IBOutlet UIBarButtonItem *doneButton;

@property (nonatomic, copy) NSArray *fetchResults;

@property (nonatomic, strong) NSMutableArray<NSArray *> *assetCollections;

@property (nonatomic, strong) NSMutableDictionary *results;
@property (nonatomic, strong) NSMutableDictionary *resultsUpdate;

@property (nonatomic) BOOL showLoading;

@end

@implementation QBAlbumsViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    [self setUpToolbarItems];
    
    // Fetch user albums and smart albums
    PHFetchResult *smartAlbums = [PHAssetCollection fetchAssetCollectionsWithType:PHAssetCollectionTypeSmartAlbum subtype:PHAssetCollectionSubtypeAny options:nil];
    PHFetchResult *userAlbums = [PHAssetCollection fetchAssetCollectionsWithType:PHAssetCollectionTypeAlbum subtype:PHAssetCollectionSubtypeAny options:nil];
    self.fetchResults = @[smartAlbums, userAlbums];
    
    [self.tableView registerClass:[UITableViewCell class] forCellReuseIdentifier:@"LoadingCell"];
    
    self.assetCollections = [NSMutableArray arrayWithCapacity:3];
    
    _showLoading = YES;
    
    [self updateAssetCollectionsForSection:0 withCompletions:^{
        [self.tableView reloadData];
        
        // Register observer
//        [[PHPhotoLibrary sharedPhotoLibrary] registerChangeObserver:self];
        
        NSInteger firstCount = self.assetCollections.count;
        
        [self updateAssetCollectionsForSection:1 withCompletions:^{
            
            NSInteger secondCount = self.assetCollections.count;
            
            if(secondCount > firstCount)
            {
                [self.tableView beginUpdates];
                [self.tableView insertSections:[NSIndexSet indexSetWithIndex:secondCount-1] withRowAnimation:UITableViewRowAnimationBottom];
                [self.tableView endUpdates];
            }
            
            [self updateAssetCollectionsForSection:3 withCompletions:^{
               
                self.showLoading = NO;
                
                [self.tableView beginUpdates];
                
                [self.tableView deleteSections:[NSIndexSet indexSetWithIndex:self.assetCollections.count-1] withRowAnimation:UITableViewRowAnimationBottom];
                
                if(self.assetCollections.count > secondCount)
                {
                    [self.tableView insertSections:[NSIndexSet indexSetWithIndex:self.assetCollections.count-1] withRowAnimation:UITableViewRowAnimationBottom];
                }
                
                [self.tableView endUpdates];
                
                
                NSString *localIndentifier = [[NSUserDefaults standardUserDefaults] stringForKey:LAST_ALBUM_KEY];
                if(localIndentifier)
                {
                    NSInteger section = 0;
                    BOOL found = NO;
                    for (NSArray *array in self.assetCollections)
                    {
                        NSInteger row = 0;
                        
                        for (PHAssetCollection *collection in array)
                        {
                            if([collection.localIdentifier isEqualToString:localIndentifier])
                            {
                                found = YES;
                                [self openAlbumAtIndexPath:[NSIndexPath indexPathForRow:row inSection:section]];
                                break;
                            }
                            
                            row++;
                        }
                        
                        if(found)
                        {
                            break;
                        }
                        
                        section++;
                    }
                }
                
            }];
            
        }];
    }];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    // Configure navigation item
    self.navigationItem.title = NSLocalizedStringFromTableInBundle(@"albums.title", @"QBImagePicker", self.imagePickerController.assetBundle, nil);
    self.navigationItem.prompt = self.imagePickerController.prompt;
    
    // Show/hide 'Done' button
    if (self.imagePickerController.allowsMultipleSelection) {
        [self.navigationItem setRightBarButtonItem:self.doneButton animated:NO];
    } else {
        [self.navigationItem setRightBarButtonItem:nil animated:NO];
    }
    
    [self updateControlState];
    [self updateSelectionInfo];
}

- (void)dealloc
{
    // Deregister observer
//    [[PHPhotoLibrary sharedPhotoLibrary] unregisterChangeObserver:self];
}


#pragma mark - Storyboard

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    [self configureAssetController:segue.destinationViewController
                     withIndexPath:self.tableView.indexPathForSelectedRow];
}

- (void)configureAssetController:(QBAssetsViewController *)controller withIndexPath:(NSIndexPath *)indexPath
{
    controller.imagePickerController = self.imagePickerController;
    controller.assetCollection = self.assetCollections[indexPath.section][indexPath.row];
    
    [[NSUserDefaults standardUserDefaults] setObject:controller.assetCollection.localIdentifier forKey:LAST_ALBUM_KEY];
}

- (void)openAlbumAtIndexPath:(NSIndexPath *)indexPath
{
    QBAssetsViewController *controller = [self.storyboard instantiateViewControllerWithIdentifier:@"QBAssetsViewController"];
    [self configureAssetController:controller withIndexPath:indexPath];
    [self.navigationController pushViewController:controller animated:YES];
}


#pragma mark - Actions

- (IBAction)cancel:(id)sender
{
    if ([self.imagePickerController.delegate respondsToSelector:@selector(qb_imagePickerControllerDidCancel:)]) {
        [self.imagePickerController.delegate qb_imagePickerControllerDidCancel:self.imagePickerController];
    }
}

- (IBAction)done:(id)sender
{
    if ([self.imagePickerController.delegate respondsToSelector:@selector(qb_imagePickerController:didFinishPickingAssets:)]) {
        [self.imagePickerController.delegate qb_imagePickerController:self.imagePickerController
                                               didFinishPickingAssets:self.imagePickerController.selectedAssets.array];
    }
}


#pragma mark - Toolbar

- (void)setUpToolbarItems
{
    // Space
    UIBarButtonItem *leftSpace = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:NULL];
    UIBarButtonItem *rightSpace = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:NULL];
    
    // Info label
    NSDictionary *attributes = @{ NSForegroundColorAttributeName: [UIColor blackColor] };
    UIBarButtonItem *infoButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"" style:UIBarButtonItemStylePlain target:nil action:NULL];
    infoButtonItem.enabled = NO;
    [infoButtonItem setTitleTextAttributes:attributes forState:UIControlStateNormal];
    [infoButtonItem setTitleTextAttributes:attributes forState:UIControlStateDisabled];
    
    self.toolbarItems = @[leftSpace, infoButtonItem, rightSpace];
}

- (void)updateSelectionInfo
{
    NSMutableOrderedSet *selectedAssets = self.imagePickerController.selectedAssets;
    
    if (selectedAssets.count > 0) {
        NSBundle *bundle = self.imagePickerController.assetBundle;
        NSString *format;
        if (selectedAssets.count > 1) {
            format = NSLocalizedStringFromTableInBundle(@"assets.toolbar.items-selected", @"QBImagePicker", bundle, nil);
        } else {
            format = NSLocalizedStringFromTableInBundle(@"assets.toolbar.item-selected", @"QBImagePicker", bundle, nil);
        }
        
        NSString *title = [NSString stringWithFormat:format, selectedAssets.count];
        [(UIBarButtonItem *)self.toolbarItems[1] setTitle:title];
    } else {
        [(UIBarButtonItem *)self.toolbarItems[1] setTitle:@""];
    }
}


#pragma mark - Fetching Asset Collections

- (void)updateAssetCollectionsForSection:(NSInteger)section withCompletions:(void(^)(void))completion
{
    dispatch_async(dispatch_get_global_queue( DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(void){
        
        NSMutableArray *albums = [NSMutableArray array];
        self.resultsUpdate = [NSMutableDictionary dictionaryWithDictionary:self.results];
        
        
        for (PHFetchResult *fetchResult in self.fetchResults) {
            [fetchResult enumerateObjectsUsingBlock:^(PHAssetCollection *assetCollection, NSUInteger index, BOOL *stop) {
                
                if((section == 0 && (assetCollection.assetCollectionSubtype == PHAssetCollectionSubtypeSmartAlbumUserLibrary
                                    || assetCollection.assetCollectionSubtype == PHAssetCollectionSubtypeSmartAlbumFavorites
                                    || assetCollection.assetCollectionSubtype == PHAssetCollectionSubtypeSmartAlbumPanoramas))
                   
                   || (section == 1 && (assetCollection.assetCollectionSubtype == PHAssetCollectionSubtypeAlbumCloudShared))
                   
                   || (section == 2 && (assetCollection.assetCollectionSubtype == PHAssetCollectionSubtypeAlbumRegular
                                        || assetCollection.assetCollectionSubtype == PHAssetCollectionSubtypeAlbumSyncedAlbum)))
                {
                    if((!self.imagePickerController.showEmptyCollections
                        && assetCollection.estimatedAssetCount > 0
                        && [self resultsForAssetCollection:assetCollection safe:NO].count > 0)
                        || self.imagePickerController.showEmptyCollections )
                    {
                         [albums addObject:assetCollection];
                    }
                }
                
            }];
        }
        
        
        if(section == 0)
        {
            [albums sortUsingComparator:^NSComparisonResult(PHAssetCollection *  _Nonnull obj1, PHAssetCollection *  _Nonnull obj2) {
                if(obj1.assetCollectionSubtype < obj2.assetCollectionSubtype) return NSOrderedDescending;
                else if(obj1.assetCollectionSubtype > obj2.assetCollectionSubtype) return NSOrderedAscending;
                return NSOrderedSame;
            }];
        }
        else
        {
            [albums sortUsingComparator:^NSComparisonResult(PHAssetCollection *  _Nonnull obj1, PHAssetCollection *  _Nonnull obj2) {
                return [obj1.localizedTitle compare:obj2.localizedTitle];
            }];
        }
        
        dispatch_async(dispatch_get_main_queue(), ^(void){
            
            self.results = [NSMutableDictionary dictionaryWithDictionary:self.resultsUpdate];
            self.resultsUpdate = nil;
            
            [self.assetCollections addObject:[NSArray arrayWithArray:albums]];
            if(completion) completion();
            
        });
        
    });
}

- (UIImage *)placeholderImageWithSize:(CGSize)size
{
    UIGraphicsBeginImageContext(size);
    CGContextRef context = UIGraphicsGetCurrentContext();
    
    UIColor *backgroundColor = [UIColor colorWithRed:(239.0 / 255.0) green:(239.0 / 255.0) blue:(244.0 / 255.0) alpha:1.0];
    UIColor *iconColor = [UIColor colorWithRed:(179.0 / 255.0) green:(179.0 / 255.0) blue:(182.0 / 255.0) alpha:1.0];
    
    // Background
    CGContextSetFillColorWithColor(context, [backgroundColor CGColor]);
    CGContextFillRect(context, CGRectMake(0, 0, size.width, size.height));
    
    // Icon (back)
    CGRect backIconRect = CGRectMake(size.width * (16.0 / 68.0),
                                     size.height * (20.0 / 68.0),
                                     size.width * (32.0 / 68.0),
                                     size.height * (24.0 / 68.0));
    
    CGContextSetFillColorWithColor(context, [iconColor CGColor]);
    CGContextFillRect(context, backIconRect);
    
    CGContextSetFillColorWithColor(context, [backgroundColor CGColor]);
    CGContextFillRect(context, CGRectInset(backIconRect, 1.0, 1.0));
    
    // Icon (front)
    CGRect frontIconRect = CGRectMake(size.width * (20.0 / 68.0),
                                      size.height * (24.0 / 68.0),
                                      size.width * (32.0 / 68.0),
                                      size.height * (24.0 / 68.0));
    
    CGContextSetFillColorWithColor(context, [backgroundColor CGColor]);
    CGContextFillRect(context, CGRectInset(frontIconRect, -1.0, -1.0));
    
    CGContextSetFillColorWithColor(context, [iconColor CGColor]);
    CGContextFillRect(context, frontIconRect);
    
    CGContextSetFillColorWithColor(context, [backgroundColor CGColor]);
    CGContextFillRect(context, CGRectInset(frontIconRect, 1.0, 1.0));
    
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    return image;
}


#pragma mark - Checking for Selection Limit

- (BOOL)isMinimumSelectionLimitFulfilled
{
    return (self.imagePickerController.minimumNumberOfSelection <= self.imagePickerController.selectedAssets.count);
}

- (BOOL)isMaximumSelectionLimitReached
{
    NSUInteger minimumNumberOfSelection = MAX(1, self.imagePickerController.minimumNumberOfSelection);
    
    if (minimumNumberOfSelection <= self.imagePickerController.maximumNumberOfSelection) {
        return (self.imagePickerController.maximumNumberOfSelection <= self.imagePickerController.selectedAssets.count);
    }
    
    return NO;
}

- (void)updateControlState
{
    self.doneButton.enabled = [self isMinimumSelectionLimitFulfilled];
}

- (PHFetchResult *)resultsForAssetCollection:(PHAssetCollection *)assetCollection safe:(BOOL)safe
{
    NSMutableDictionary *dict = (safe) ? _results : _resultsUpdate;
    if(dict == nil)
    {
        return nil;
    }
    
    if(dict[assetCollection]) return dict[assetCollection];
    
    PHFetchOptions *options = [PHFetchOptions new];
    options.sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"creationDate" ascending:YES]];
    
    switch (self.imagePickerController.mediaType) {
        case QBImagePickerMediaTypeImage:
            options.predicate = [NSPredicate predicateWithFormat:@"mediaType == %ld", PHAssetMediaTypeImage];
            break;
            
        case QBImagePickerMediaTypeVideo:
            options.predicate = [NSPredicate predicateWithFormat:@"mediaType == %ld", PHAssetMediaTypeVideo];
            break;
            
        default:
            break;
    }
    
    PHFetchResult *fetched = [PHAsset fetchAssetsInAssetCollection:assetCollection options:options];
    dict[assetCollection] = fetched;
    
    return fetched;
}

#pragma mark - UITableViewDataSource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    NSInteger nb = self.assetCollections.count;
    if(_showLoading) nb++;
    return nb;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    if(section == self.assetCollections.count) return 1;
    return (self.assetCollections[section].count == 0) ? 0 : self.assetCollections[section].count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    if(indexPath.section == self.assetCollections.count)
    {
        UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"LoadingCell" forIndexPath:indexPath];
        UIActivityIndicatorView *activity = [cell.contentView viewWithTag:456];
        if(activity == nil)
        {
            activity = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
            activity.tag = 456;
            [cell.contentView addSubview:activity];
            
            NSLayoutConstraint *x = [NSLayoutConstraint constraintWithItem:activity
                                                                 attribute:NSLayoutAttributeCenterX
                                                                 relatedBy:NSLayoutRelationEqual
                                                                    toItem:cell.contentView
                                                                 attribute:NSLayoutAttributeCenterX
                                                                multiplier:1
                                                                  constant:0];
            [cell.contentView addConstraint:x];
            
            NSLayoutConstraint *y = [NSLayoutConstraint constraintWithItem:activity
                                                                 attribute:NSLayoutAttributeCenterY
                                                                 relatedBy:NSLayoutRelationEqual
                                                                    toItem:cell.contentView
                                                                 attribute:NSLayoutAttributeCenterY
                                                                multiplier:1
                                                                  constant:0];
            [cell.contentView addConstraint:y];
            
        }
        
        [activity startAnimating];
        
        return cell;
    }
    
    
    QBAlbumCell *cell = [tableView dequeueReusableCellWithIdentifier:@"AlbumCell" forIndexPath:indexPath];
    cell.tag = indexPath.row;
    cell.borderWidth = 1.0 / self.traitCollection.displayScale;
    
    // Thumbnail
    PHAssetCollection *assetCollection = self.assetCollections[indexPath.section][indexPath.row];
    PHFetchResult *fetchResult = [self resultsForAssetCollection:assetCollection safe:YES];
    PHImageManager *imageManager = [PHImageManager defaultManager];
    
    if (fetchResult.count >= 3) {
        cell.imageView3.hidden = NO;
        
        [imageManager requestImageForAsset:fetchResult[fetchResult.count - 3]
                                targetSize:CGSizeScale(cell.imageView3.frame.size, self.traitCollection.displayScale)
                               contentMode:PHImageContentModeAspectFill
                                   options:nil
                             resultHandler:^(UIImage *result, NSDictionary *info) {
                                 if (cell.tag == indexPath.row) {
                                     cell.imageView3.image = result;
                                 }
                             }];
    } else {
        cell.imageView3.hidden = YES;
    }
    
    if (fetchResult.count >= 2) {
        cell.imageView2.hidden = NO;
        
        [imageManager requestImageForAsset:fetchResult[fetchResult.count - 2]
                                targetSize:CGSizeScale(cell.imageView2.frame.size, self.traitCollection.displayScale)
                               contentMode:PHImageContentModeAspectFill
                                   options:nil
                             resultHandler:^(UIImage *result, NSDictionary *info) {
                                 if (cell.tag == indexPath.row) {
                                     cell.imageView2.image = result;
                                 }
                             }];
    } else {
        cell.imageView2.hidden = YES;
    }
    
    if (fetchResult.count >= 1) {
        [imageManager requestImageForAsset:fetchResult[fetchResult.count - 1]
                                targetSize:CGSizeScale(cell.imageView1.frame.size, self.traitCollection.displayScale)
                               contentMode:PHImageContentModeAspectFill
                                   options:nil
                             resultHandler:^(UIImage *result, NSDictionary *info) {
                                 if (cell.tag == indexPath.row) {
                                     cell.imageView1.image = result;
                                 }
                             }];
    }
    
    if (fetchResult.count == 0) {
        cell.imageView3.hidden = NO;
        cell.imageView2.hidden = NO;
        
        // Set placeholder image
        UIImage *placeholderImage = [self placeholderImageWithSize:cell.imageView1.frame.size];
        cell.imageView1.image = placeholderImage;
        cell.imageView2.image = placeholderImage;
        cell.imageView3.image = placeholderImage;
    }
    
    // Album title
    cell.titleLabel.text = assetCollection.localizedTitle;
    
    // Number of photos
    cell.countLabel.text = [NSString stringWithFormat:@"%lu", (long)fetchResult.count];
    
    return cell;
}

- (NSArray<UITableViewRowAction *> *)tableView:(UITableView *)tableView editActionsForRowAtIndexPath:(NSIndexPath *)indexPath
{
    if(!self.imagePickerController.debug) return @[];
    
    UITableViewRowAction *infos = [UITableViewRowAction rowActionWithStyle:UITableViewRowActionStyleNormal title:@"DEBUG" handler:^(UITableViewRowAction * _Nonnull action, NSIndexPath * _Nonnull ip) {
        
        PHAssetCollection *collection = self.assetCollections[ip.section][ip.row];
        
        NSString *msg = [collection description];
        
        msg = [msg stringByAppendingString:@"\n\n"];
        
        msg = [msg stringByAppendingString:[NSString stringWithFormat:@"canContainAssets : %@\n", (collection.canContainAssets) ? @"YES" : @"NO"]];
        msg = [msg stringByAppendingString:[NSString stringWithFormat:@"canContainCollections : %@\n", (collection.canContainCollections) ? @"YES" : @"NO"]];
        msg = [msg stringByAppendingString:[NSString stringWithFormat:@"estimatedAssetCount : %d", (int)collection.estimatedAssetCount]];
        
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"DEBUG" message:msg preferredStyle:UIAlertControllerStyleAlert];
        
        [alert addAction:[UIAlertAction actionWithTitle:@"Ok" style:UIAlertActionStyleCancel handler:nil]];
        
        [self presentViewController:alert animated:YES completion:nil];
        
    }];
    
    return @[infos];
}


#pragma mark - PHPhotoLibraryChangeObserver

//- (void)photoLibraryDidChange:(PHChange *)changeInstance
//{
//    dispatch_async(dispatch_get_main_queue(), ^{
//        // Update fetch results
//        NSMutableArray *fetchResults = [self.fetchResults mutableCopy];
//        
//        [self.fetchResults enumerateObjectsUsingBlock:^(PHFetchResult *fetchResult, NSUInteger index, BOOL *stop) {
//            PHFetchResultChangeDetails *changeDetails = [changeInstance changeDetailsForFetchResult:fetchResult];
//            
//            if (changeDetails) {
//                [fetchResults replaceObjectAtIndex:index withObject:changeDetails.fetchResultAfterChanges];
//            }
//        }];
//        
//        if (![self.fetchResults isEqualToArray:fetchResults]) {
//            self.fetchResults = fetchResults;
//            
//            // Reload albums
//            [self updateAssetCollectionsWithCompletions:^{
//                [self.tableView reloadData];
//            }];
//        }
//    });
//}

@end
