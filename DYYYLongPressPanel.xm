#import "AwemeHeaders.h"
#import "DYYYBottomAlertView.h"
#import "DYYYCustomInputView.h"
#import "DYYYFilterSettingsView.h"
#import "DYYYKeywordListView.h"
#import "DYYYConfirmCloseView.h"
#import "DYYYManager.h"
#import "DYYYUtils.h"
#import "DYYYToast.h"

%hook AWELongPressPanelViewGroupModel
%property(nonatomic, assign) BOOL isDYYYCustomGroup;
%end

// Modern风格长按面板（新版UI）
%hook AWEModernLongPressPanelTableViewController
-(NSArray *)dataArray {
    NSArray *originalArray = %orig;
    if (!originalArray) {
        originalArray = @[];
    }
    
    // 检查是否启用了任意长按功能
    BOOL hasAnyFeatureEnabled = NO;
    // 检查各个单独的功能开关
    BOOL enableSaveVideo = [[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYLongPressSaveVideo"];
    BOOL enableSaveCover = [[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYLongPressSaveCover"];
    BOOL enableSaveAudio = [[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYLongPressSaveAudio"];
    BOOL enableSaveCurrentImage = [[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYLongPressSaveCurrentImage"];
    BOOL enableSaveAllImages = [[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYLongPressSaveAllImages"];
    BOOL enableCopyText = [[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYLongPressCopyText"];
    BOOL enableCopyLink = [[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYLongPressCopyLink"];
    BOOL enableApiDownload = [[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYLongPressApiDownload"];
    BOOL enableFilterUser = [[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYLongPressFilterUser"];
    BOOL enableFilterKeyword = [[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYLongPressFilterTitle"];
    BOOL enableTimerClose = [[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYLongPressTimerClose"];
    BOOL enableCreateVideo = [[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYLongPressCreateVideo"];
    
    // 检查是否有任何功能启用
    hasAnyFeatureEnabled = enableSaveVideo || enableSaveCover || enableSaveAudio || enableSaveCurrentImage || enableSaveAllImages || enableCopyText || enableCopyLink || enableApiDownload ||
                           enableFilterUser || enableFilterKeyword || enableTimerClose || enableCreateVideo;
    
    // 处理原始面板按钮的显示/隐藏
    NSMutableArray *officialButtons = [NSMutableArray array];
    
    // 获取需要隐藏的按钮设置
    BOOL hideDaily = [[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYHidePanelDaily"];
    BOOL hideRecommend = [[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYHidePanelRecommend"];
    BOOL hideNotInterested = [[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYHidePanelNotInterested"];
    BOOL hideReport = [[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYHidePanelReport"];
    BOOL hideSpeed = [[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYHidePanelSpeed"];
    BOOL hideClearScreen = [[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYHidePanelClearScreen"];
    BOOL hideFavorite = [[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYHidePanelFavorite"];
    BOOL hideLater = [[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYHidePanelLater"];
    BOOL hideCast = [[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYHidePanelCast"];
    BOOL hideOpenInPC = [[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYHidePanelOpenInPC"];
    BOOL hideSubtitle = [[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYHidePanelSubtitle"];
    BOOL hideAutoPlay = [[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYHidePanelAutoPlay"];
    BOOL hideSearchImage = [[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYHidePanelSearchImage"];
    BOOL hideListenDouyin = [[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYHidePanelListenDouyin"];
    BOOL hideBackgroundPlay = [[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYHidePanelBackgroundPlay"];
    BOOL hideBiserial = [[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYHidePanelBiserial"];
    
    // 存储处理后的原始组
    NSMutableArray *modifiedOriginalGroups = [NSMutableArray array];
    
    // 处理原始面板，收集所有未被隐藏的官方按钮
    for (id group in originalArray) {
        if ([group isKindOfClass:%c(AWELongPressPanelViewGroupModel)]) {
            AWELongPressPanelViewGroupModel *groupModel = (AWELongPressPanelViewGroupModel *)group;
            NSMutableArray *filteredGroupArr = [NSMutableArray array];
            
            for (id item in groupModel.groupArr) {
                if ([item isKindOfClass:%c(AWELongPressPanelBaseViewModel)]) {
                    AWELongPressPanelBaseViewModel *viewModel = (AWELongPressPanelBaseViewModel *)item;
                    NSString *descString = viewModel.describeString;
                    // 根据描述字符串判断按钮类型并决定是否保留
                    BOOL shouldHide = NO;
                    if ([descString isEqualToString:@"转发到日常"] && hideDaily) {
                        shouldHide = YES;
                    } else if ([descString isEqualToString:@"推荐"] && hideRecommend) {
                        shouldHide = YES;
                    } else if ([descString isEqualToString:@"不感兴趣"] && hideNotInterested) {
                        shouldHide = YES;
                    } else if ([descString isEqualToString:@"举报"] && hideReport) {
                        shouldHide = YES;
                    } else if ([descString isEqualToString:@"倍速"] && hideSpeed) {
                        shouldHide = YES;
                    } else if ([descString isEqualToString:@"清屏播放"] && hideClearScreen) {
                        shouldHide = YES;
                    } else if ([descString isEqualToString:@"缓存视频"] && hideFavorite) {
                        shouldHide = YES;
                    } else if ([descString isEqualToString:@"添加至稍后再看"] && hideLater) {
                        shouldHide = YES;
                    } else if ([descString isEqualToString:@"投屏"] && hideCast) {
                        shouldHide = YES;
                    } else if ([descString isEqualToString:@"电脑/Pad打开"] && hideOpenInPC) {
                        shouldHide = YES;
                    } else if ([descString isEqualToString:@"弹幕"] && hideSubtitle) {
                        shouldHide = YES;
                    } else if ([descString isEqualToString:@"弹幕开关"] && hideSubtitle) {
                        shouldHide = YES;
                    } else if ([descString isEqualToString:@"弹幕设置"] && hideSubtitle) {
                        shouldHide = YES;
                    } else if ([descString isEqualToString:@"自动连播"] && hideAutoPlay) {
                        shouldHide = YES;
                    } else if ([descString isEqualToString:@"识别图片"] && hideSearchImage) {
                        shouldHide = YES;
                    } else if ([descString isEqualToString:@"听抖音"] && hideListenDouyin) {
                        shouldHide = YES;
                    } else if ([descString isEqualToString:@"后台播放设置"] && hideBackgroundPlay) {
                        shouldHide = YES;
                    } else if ([descString isEqualToString:@"首页双列快捷入口"] && hideBiserial) {
                        shouldHide = YES;
                    }
                    
                    if (!shouldHide) {
                        // 添加图标修改
                        if ([descString isEqualToString:@"后台播放设置"]) {
                            viewModel.duxIconName = @"ic_phonearrowup_outlined_20";
                        } else if ([descString isEqualToString:@"转发到日常"]) {
                            viewModel.duxIconName = @"ic_flash_outlined_20";
                        } else if ([descString isEqualToString:@"首页双列快捷入口"]) {
                            viewModel.duxIconName = @"ic_squaresplit_outlined_20";
                        } else if ([descString isEqualToString:@"推荐"]) {
                            viewModel.duxIconName = @"ic_thumbsup_outlined_20";
                        } else if ([descString isEqualToString:@"不感兴趣"]) {
                            viewModel.duxIconName = @"ic_heartbreak_outlined_20";
                        } else if ([descString isEqualToString:@"弹幕"] || 
                                    [descString isEqualToString:@"弹幕开关"] || 
                                    [descString isEqualToString:@"弹幕设置"]) {
                            viewModel.duxIconName = @"ic_dansquare_outlined_20";
                        }
                        
                        // 将按钮添加到官方按钮列表
                        [officialButtons addObject:viewModel];
                        
                        // 同时添加到当前组的过滤列表
                        [filteredGroupArr addObject:viewModel];
                    }
                }
            }
            
            // 如果過濾後的組不為空，則儲存原始組結構
            if (filteredGroupArr.count > 0) {
                AWELongPressPanelViewGroupModel *newGroup = [[%c(AWELongPressPanelViewGroupModel) alloc] init];
                newGroup.isDYYYCustomGroup = YES;
                newGroup.groupType = groupModel.groupType;
                newGroup.isModern = YES;
                newGroup.groupArr = filteredGroupArr;
                [modifiedOriginalGroups addObject:newGroup];
            }
        }
    }
    
    // 如果沒有任何功能啟用，僅使用官方按鈕
    if (!hasAnyFeatureEnabled) {
        // 直接返回修改後的原始組
        return modifiedOriginalGroups;
    }
    
    // 創建自訂功能按鈕
    NSMutableArray *viewModels = [NSMutableArray array];
    
    // 影片下載功能
    if (enableSaveVideo && self.awemeModel.awemeType != 68) {
        AWELongPressPanelBaseViewModel *downloadViewModel = [[%c(AWELongPressPanelBaseViewModel) alloc] init];
        downloadViewModel.awemeModel = self.awemeModel;
        downloadViewModel.actionType = 666;
        downloadViewModel.duxIconName = @"ic_boxarrowdownhigh_outlined";
        downloadViewModel.describeString = @"儲存影片";
        downloadViewModel.action = ^{
            AWEAwemeModel *awemeModel = self.awemeModel;
            AWEVideoModel *videoModel = awemeModel.video;
            
            if (videoModel && videoModel.bitrateModels && videoModel.bitrateModels.count > 0) {
                // 優先使用bitrateModels中的最高品質版本
                id highestQualityModel = videoModel.bitrateModels.firstObject;
                NSArray *urlList = nil;
                id playAddrObj = [highestQualityModel valueForKey:@"playAddr"];

                if ([playAddrObj isKindOfClass:%c(AWEURLModel)]) {
                    AWEURLModel *playAddrModel = (AWEURLModel *)playAddrObj;
                    urlList = playAddrModel.originURLList;
                }

                if (urlList && urlList.count > 0) {
                    NSURL *url = [NSURL URLWithString:urlList.firstObject];
                    [DYYYManager downloadMedia:url
                                    mediaType:MediaTypeVideo
                                    completion:^(BOOL success){
                                    }];
                } else {
                    // 備用方法：直接使用h264URL
                    if (videoModel.h264URL && videoModel.h264URL.originURLList.count > 0) {
                        NSURL *url = [NSURL URLWithString:videoModel.h264URL.originURLList.firstObject];
                        [DYYYManager downloadMedia:url
                                        mediaType:MediaTypeVideo
                                        completion:^(BOOL success){
                                        }];
                    } 
                }
            }
            AWELongPressPanelManager *panelManager = [%c(AWELongPressPanelManager) shareInstance];
            [panelManager dismissWithAnimation:YES completion:nil];
        };
        [viewModels addObject:downloadViewModel];
    }
    
    // 目前圖片/原況下載功能
    if (enableSaveCurrentImage && self.awemeModel.awemeType == 68 && self.awemeModel.albumImages.count > 0) { 
        AWELongPressPanelBaseViewModel *imageViewModel = [[%c(AWELongPressPanelBaseViewModel) alloc] init];
        imageViewModel.awemeModel = self.awemeModel;
        imageViewModel.actionType = 669;
        imageViewModel.duxIconName = @"ic_boxarrowdownhigh_outlined";
        imageViewModel.describeString = @"儲存目前圖片";
        AWEImageAlbumImageModel *currimge = self.awemeModel.albumImages[self.awemeModel.currentImageIndex - 1];
        if (currimge.clipVideo != nil) {
            imageViewModel.describeString = @"儲存目前原況";
        }
        imageViewModel.action = ^{
            AWEAwemeModel *awemeModel = self.awemeModel;
            AWEImageAlbumImageModel *currentImageModel = nil;
            if (awemeModel.currentImageIndex > 0 && awemeModel.currentImageIndex <= awemeModel.albumImages.count) {
                currentImageModel = awemeModel.albumImages[awemeModel.currentImageIndex - 1];
            } else {
                currentImageModel = awemeModel.albumImages.firstObject;
            }
            // 如果是实况的话
            // 查找非.image后缀的URL
                NSURL *downloadURL = nil;
                for (NSString *urlString in currentImageModel.urlList) {
                    NSURL *url = [NSURL URLWithString:urlString];
                    NSString *pathExtension = [url.path.lowercaseString pathExtension];
                    if (![pathExtension isEqualToString:@"image"]) {
                        downloadURL = url;
                        break;
                    }
                }
                
            if (currentImageModel.clipVideo != nil) {
                NSURL *videoURL = [currentImageModel.clipVideo.playURL getDYYYSrcURLDownload];
                [DYYYManager downloadLivePhoto:downloadURL
                                      videoURL:videoURL
                                    completion:^{
                                    }];
            } else if (currentImageModel && currentImageModel.urlList.count > 0) {
                if (downloadURL) {
                    [DYYYManager downloadMedia:downloadURL
                                    mediaType:MediaTypeImage
                                    completion:^(BOOL success){
                                        if (success) {
                                        } else {
                                            [DYYYManager showToast:@"圖片儲存已取消"];
                                        }
                                    }];
                } else {
                    [DYYYManager showToast:@"沒有找到合適格式的圖片"];
                }
            }
            AWELongPressPanelManager *panelManager = [%c(AWELongPressPanelManager) shareInstance];
            [panelManager dismissWithAnimation:YES completion:nil];
        };
        [viewModels addObject:imageViewModel];
    }
    
    // 儲存所有圖片/原況功能
    if (enableSaveAllImages && self.awemeModel.awemeType == 68 && self.awemeModel.albumImages.count > 1) {
        AWELongPressPanelBaseViewModel *allImagesViewModel = [[%c(AWELongPressPanelBaseViewModel) alloc] init];
        allImagesViewModel.awemeModel = self.awemeModel;
        allImagesViewModel.actionType = 670;
        allImagesViewModel.duxIconName = @"ic_boxarrowdownhigh_outlined";
        allImagesViewModel.describeString = @"儲存所有圖片";
        // 檢查是否有原況照片並更改按鈕文字
        BOOL hasLivePhoto = NO;
        for (AWEImageAlbumImageModel *imageModel in self.awemeModel.albumImages) {
            if (imageModel.clipVideo != nil) {
                hasLivePhoto = YES;
                break;
            }
        }
        if (hasLivePhoto) {
            allImagesViewModel.describeString = @"儲存所有原況";
        }
        allImagesViewModel.action = ^{
            AWEAwemeModel *awemeModel = self.awemeModel;
            NSMutableArray *imageURLs = [NSMutableArray array];
            for (AWEImageAlbumImageModel *imageModel in awemeModel.albumImages) {
                if (imageModel.urlList.count > 0) {
                    // 查找非.image後綴的URL
                    NSURL *downloadURL = nil;
                    for (NSString *urlString in imageModel.urlList) {
                        NSURL *url = [NSURL URLWithString:urlString];
                        NSString *pathExtension = [url.path.lowercaseString pathExtension];
                        if (![pathExtension isEqualToString:@"image"]) {
                            downloadURL = url;
                            break;
                        }
                    }
                    
                    if (downloadURL) {
                        [imageURLs addObject:downloadURL.absoluteString];
                    }
                }
            }
            // 檢查是否有原況照片
            BOOL hasLivePhoto = NO;
            for (AWEImageAlbumImageModel *imageModel in awemeModel.albumImages) {
                if (imageModel.clipVideo != nil) {
                    hasLivePhoto = YES;
                    break;
                }
            }
            // 如果有原況照片，使用單獨的downloadLivePhoto方法逐個下載
            if (hasLivePhoto) {
                NSMutableArray *livePhotos = [NSMutableArray array];
                for (AWEImageAlbumImageModel *imageModel in awemeModel.albumImages) {
                    if (imageModel.urlList.count > 0 && imageModel.clipVideo != nil) {
                        // 為原況照片也進行URL過濾
                        NSURL *photoURL = nil;
                        for (NSString *urlString in imageModel.urlList) {
                            NSURL *url = [NSURL URLWithString:urlString];
                            NSString *pathExtension = [url.path.lowercaseString pathExtension];
                            if (![pathExtension isEqualToString:@"image"]) {
                                photoURL = url;
                                break;
                            }
                        }
                        if (!photoURL && imageModel.urlList.count > 0) {
                            photoURL = [NSURL URLWithString:imageModel.urlList.firstObject];
                        }
                        NSURL *videoURL = [imageModel.clipVideo.playURL getDYYYSrcURLDownload];
                        [livePhotos addObject:@{@"imageURL" : photoURL.absoluteString, @"videoURL" : videoURL.absoluteString}];
                    }
                }
                // 使用批量下載原況照片方法
                [DYYYManager downloadAllLivePhotos:livePhotos];
            } else if (imageURLs.count > 0) {
                [DYYYManager downloadAllImages:imageURLs];
            } else {
                [DYYYManager showToast:@"沒有找到合適格式的圖片"];
            }
            AWELongPressPanelManager *panelManager = [%c(AWELongPressPanelManager) shareInstance];
            [panelManager dismissWithAnimation:YES completion:nil];
        };
        [viewModels addObject:allImagesViewModel];
    }
    
    // 介面儲存功能
    NSString *apiKey = [[NSUserDefaults standardUserDefaults] objectForKey:@"DYYYInterfaceDownload"];
    if (enableApiDownload && apiKey.length > 0) {
        AWELongPressPanelBaseViewModel *apiDownload = [[%c(AWELongPressPanelBaseViewModel) alloc] init];
        apiDownload.awemeModel = self.awemeModel;
        apiDownload.actionType = 673;
        apiDownload.duxIconName = @"ic_cloudarrowdown_outlined_20";
        apiDownload.describeString = @"介面儲存";
        apiDownload.action = ^{
            NSString *shareLink = [self.awemeModel valueForKey:@"shareURL"];
            if (shareLink.length == 0) {
                [DYYYManager showToast:@"無法取得分享連結"];
                return;
            }
            // 使用封裝的方法進行解析下載
            [DYYYManager parseAndDownloadVideoWithShareLink:shareLink apiKey:apiKey];
            AWELongPressPanelManager *panelManager = [%c(AWELongPressPanelManager) shareInstance];
            [panelManager dismissWithAnimation:YES completion:nil];
        };
        [viewModels addObject:apiDownload];
    }

    // 封面下載功能
    if (enableSaveCover && self.awemeModel.awemeType != 68) {
        AWELongPressPanelBaseViewModel *coverViewModel = [[%c(AWELongPressPanelBaseViewModel) alloc] init];
        coverViewModel.awemeModel = self.awemeModel;
        coverViewModel.actionType = 667;
        coverViewModel.duxIconName = @"ic_boxarrowdownhigh_outlined";
        coverViewModel.describeString = @"儲存封面";
        coverViewModel.action = ^{
            AWEAwemeModel *awemeModel = self.awemeModel;
            AWEVideoModel *videoModel = awemeModel.video;
            if (videoModel && videoModel.coverURL && videoModel.coverURL.originURLList.count > 0) {
                NSURL *url = [NSURL URLWithString:videoModel.coverURL.originURLList.firstObject];
                [DYYYManager downloadMedia:url
                                mediaType:MediaTypeImage
                                completion:^(BOOL success){
                                    if (success) {
                                    } else {
                                        [DYYYManager showToast:@"封面儲存已取消"];
                                    }
                                }];
            }
            AWELongPressPanelManager *panelManager = [%c(AWELongPressPanelManager) shareInstance];
            [panelManager dismissWithAnimation:YES completion:nil];
        };
        [viewModels addObject:coverViewModel];
    }
    
    // 音訊下載功能
    if (enableSaveAudio) {
        AWELongPressPanelBaseViewModel *audioViewModel = [[%c(AWELongPressPanelBaseViewModel) alloc] init];
        audioViewModel.awemeModel = self.awemeModel;
        audioViewModel.actionType = 668;
        audioViewModel.duxIconName = @"ic_boxarrowdownhigh_outlined";
        audioViewModel.describeString = @"儲存音訊";
        audioViewModel.action = ^{
            AWEAwemeModel *awemeModel = self.awemeModel;
            AWEMusicModel *musicModel = awemeModel.music;
            if (musicModel && musicModel.playURL && musicModel.playURL.originURLList.count > 0) {
                NSURL *url = [NSURL URLWithString:musicModel.playURL.originURLList.firstObject];
                [DYYYManager downloadMedia:url mediaType:MediaTypeAudio completion:nil];
            }
            AWELongPressPanelManager *panelManager = [%c(AWELongPressPanelManager) shareInstance];
            [panelManager dismissWithAnimation:YES completion:nil];
        };
        [viewModels addObject:audioViewModel];
    }

    // 製作影片功能
    if (enableCreateVideo && self.awemeModel.awemeType == 68 && self.awemeModel.albumImages.count > 1) {
        AWELongPressPanelBaseViewModel *createVideoViewModel = [[%c(AWELongPressPanelBaseViewModel) alloc] init];
        createVideoViewModel.awemeModel = self.awemeModel;
        createVideoViewModel.actionType = 677;
        createVideoViewModel.duxIconName = @"ic_videosearch_outlined_20";
        createVideoViewModel.describeString = @"製作影片";
        createVideoViewModel.action = ^{
            AWEAwemeModel *awemeModel = self.awemeModel;
            
            // 收集普通圖片URL
            NSMutableArray *imageURLs = [NSMutableArray array];
            // 收集原況照片資訊（圖片URL+影片URL）
            NSMutableArray *livePhotos = [NSMutableArray array];
            
            // 取得背景音樂URL
            NSString *bgmURL = nil;
            if (awemeModel.music && awemeModel.music.playURL && awemeModel.music.playURL.originURLList.count > 0) {
                bgmURL = awemeModel.music.playURL.originURLList.firstObject;
            }
            
            // 處理所有圖片和原況
            for (AWEImageAlbumImageModel *imageModel in awemeModel.albumImages) {
                if (imageModel.urlList.count > 0) {
                    // 查找非.image後綴的URL
                    NSString *bestURL = nil;
                    for (NSString *urlString in imageModel.urlList) {
                        NSURL *url = [NSURL URLWithString:urlString];
                        NSString *pathExtension = [url.path.lowercaseString pathExtension];
                        if (![pathExtension isEqualToString:@"image"]) {
                            bestURL = urlString;
                            break;
                        }
                    }
                    
                    if (!bestURL && imageModel.urlList.count > 0) {
                        bestURL = imageModel.urlList.firstObject;
                    }
                    
                    // 如果是原況照片，需要收集圖片和影片URL
                    if (imageModel.clipVideo != nil) {
                        NSURL *videoURL = [imageModel.clipVideo.playURL getDYYYSrcURLDownload];
                        if (videoURL) {
                            [livePhotos addObject:@{
                                @"imageURL": bestURL,
                                @"videoURL": videoURL.absoluteString
                            }];
                        }
                    } else {
                        // 普通圖片
                        [imageURLs addObject:bestURL];
                    }
                }
            }
            
            // 呼叫影片創建API
            [DYYYManager createVideoFromMedia:imageURLs
                                   livePhotos:livePhotos
                                       bgmURL:bgmURL
                                     progress:^(NSInteger current, NSInteger total, NSString *status) {
                                     }
                                   completion:^(BOOL success, NSString *message) {
                                         if (success) {
                                         } else {
                                             [DYYYManager showToast:[NSString stringWithFormat:@"影片製作失敗: %@", message]];
                                         }
                                     }];
            
            AWELongPressPanelManager *panelManager = [%c(AWELongPressPanelManager) shareInstance];
            [panelManager dismissWithAnimation:YES completion:nil];
        };
        [viewModels addObject:createVideoViewModel];
    }

    // 複製文案功能
    if (enableCopyText) {
        AWELongPressPanelBaseViewModel *copyText = [[%c(AWELongPressPanelBaseViewModel) alloc] init];
        copyText.awemeModel = self.awemeModel;
        copyText.actionType = 671;
        copyText.duxIconName = @"ic_xiaoxihuazhonghua_outlined";
        copyText.describeString = @"複製文案";
        copyText.action = ^{
            NSString *descText = [self.awemeModel valueForKey:@"descriptionString"];
            [[UIPasteboard generalPasteboard] setString:descText];
            [DYYYToast showSuccessToastWithMessage:@"文案已複製"];
            AWELongPressPanelManager *panelManager = [%c(AWELongPressPanelManager) shareInstance];
            [panelManager dismissWithAnimation:YES completion:nil];
        };
        [viewModels addObject:copyText];
    }
    
    // 複製分享連結功能
    if (enableCopyLink) {
        AWELongPressPanelBaseViewModel *copyShareLink = [[%c(AWELongPressPanelBaseViewModel) alloc] init];
        copyShareLink.awemeModel = self.awemeModel;
        copyShareLink.actionType = 672;
        copyShareLink.duxIconName = @"ic_share_outlined";
        copyShareLink.describeString = @"複製連結";
        copyShareLink.action = ^{
            NSString *shareLink = [self.awemeModel valueForKey:@"shareURL"];
            NSString *cleanedURL = cleanShareURL(shareLink);
            [[UIPasteboard generalPasteboard] setString:cleanedURL];
            [DYYYToast showSuccessToastWithMessage:@"分享連結已複製"];
            AWELongPressPanelManager *panelManager = [%c(AWELongPressPanelManager) shareInstance];
            [panelManager dismissWithAnimation:YES completion:nil];
        };
        [viewModels addObject:copyShareLink];
    }
    
    // 過濾使用者功能
    if (enableFilterUser) {
        AWELongPressPanelBaseViewModel *filterKeywords = [[%c(AWELongPressPanelBaseViewModel) alloc] init];
        filterKeywords.awemeModel = self.awemeModel;
        filterKeywords.actionType = 674;
        filterKeywords.duxIconName = @"ic_userban_outlined_20";
        filterKeywords.describeString = @"過濾使用者";
        filterKeywords.action = ^{
            AWEUserModel *author = self.awemeModel.author;
            NSString *nickname = author.nickname ?: @"未知使用者";
            NSString *shortId = author.shortID ?: @"";
            // 創建目前使用者的過濾格式 "nickname-shortid"
            NSString *currentUserFilter = [NSString stringWithFormat:@"%@-%@", nickname, shortId];
            // 取得儲存的過濾使用者列表
            NSString *savedUsers = [[NSUserDefaults standardUserDefaults] objectForKey:@"DYYYfilterUsers"] ?: @"";
            NSArray *userArray = [savedUsers length] > 0 ? [savedUsers componentsSeparatedByString:@","] : @[];
            BOOL userExists = NO;
            for (NSString *userInfo in userArray) {
                NSArray *components = [userInfo componentsSeparatedByString:@"-"];
                if (components.count >= 2) {
                    NSString *userId = [components lastObject];
                    if ([userId isEqualToString:shortId] && shortId.length > 0) {
                        userExists = YES;
                        break;
                    }
                }
            }
            NSString *actionButtonText = userExists ? @"取消過濾" : @"新增過濾";
            [DYYYBottomAlertView showAlertWithTitle:@"過濾使用者影片"
                                            message:[NSString stringWithFormat:@"使用者: %@ (ID: %@)", nickname, shortId]
                                   cancelButtonText:@"管理過濾列表"
                                  confirmButtonText:actionButtonText
                                       cancelAction:^{
                DYYYKeywordListView *keywordListView = [[DYYYKeywordListView alloc] initWithTitle:@"過濾使用者列表" keywords:userArray];
                                keywordListView.onConfirm = ^(NSArray *users) {
                    NSString *userString = [users componentsJoinedByString:@","];
                    [[NSUserDefaults standardUserDefaults] setObject:userString forKey:@"DYYYfilterUsers"];
                    [[NSUserDefaults standardUserDefaults] synchronize];
                    [DYYYManager showToast:@"過濾使用者列表已更新"];
                };
                [keywordListView show];
            }
            confirmAction:^{
                // 新增或移除使用者過濾
                NSMutableArray *updatedUsers = [NSMutableArray arrayWithArray:userArray];
                if (userExists) {
                    // 移除使用者
                    NSMutableArray *toRemove = [NSMutableArray array];
                    for (NSString *userInfo in updatedUsers) {
                        NSArray *components = [userInfo componentsSeparatedByString:@"-"];
                        if (components.count >= 2) {
                            NSString *userId = [components lastObject];
                            if ([userId isEqualToString:shortId]) {
                                [toRemove addObject:userInfo];
                            }
                        }
                    }
                    [updatedUsers removeObjectsInArray:toRemove];
                    [DYYYManager showToast:@"已從過濾列表中移除此使用者"];
                } else {
                    // 新增使用者
                    [updatedUsers addObject:currentUserFilter];
                    [DYYYManager showToast:@"已新增此使用者到過濾列表"];
                }
                // 儲存更新後的列表
                NSString *updatedUserString = [updatedUsers componentsJoinedByString:@","];
                [[NSUserDefaults standardUserDefaults] setObject:updatedUserString forKey:@"DYYYfilterUsers"];
                [[NSUserDefaults standardUserDefaults] synchronize];
            }];
        };
        [viewModels addObject:filterKeywords];
    }
    
    // 過濾文案功能
    if (enableFilterKeyword) {
        AWELongPressPanelBaseViewModel *filterKeywords = [[%c(AWELongPressPanelBaseViewModel) alloc] init];
        filterKeywords.awemeModel = self.awemeModel;
        filterKeywords.actionType = 675;
        filterKeywords.duxIconName = @"ic_funnel_outlined_20";
        filterKeywords.describeString = @"過濾文案";
        filterKeywords.action = ^{
            NSString *descText = [self.awemeModel valueForKey:@"descriptionString"];
            DYYYFilterSettingsView *filterView = [[DYYYFilterSettingsView alloc] initWithTitle:@"過濾關鍵詞調整" text:descText];
            filterView.onConfirm = ^(NSString *selectedText) {
                if (selectedText.length > 0) {
                    NSString *currentKeywords = [[NSUserDefaults standardUserDefaults] objectForKey:@"DYYYfilterKeywords"] ?: @"";
                    NSString *newKeywords;
                    if (currentKeywords.length > 0) {
                        newKeywords = [NSString stringWithFormat:@"%@,%@", currentKeywords, selectedText];
                    } else {
                        newKeywords = selectedText;
                    }
                    [[NSUserDefaults standardUserDefaults] setObject:newKeywords forKey:@"DYYYfilterKeywords"];
                    [[NSUserDefaults standardUserDefaults] synchronize];
                    [DYYYManager showToast:[NSString stringWithFormat:@"已新增過濾詞: %@", selectedText]];
                }
            };
            // 設定過濾關鍵詞按鈕回調
            filterView.onKeywordFilterTap = ^{
                // 取得儲存的關鍵詞
                NSString *savedKeywords = [[NSUserDefaults standardUserDefaults] objectForKey:@"DYYYfilterKeywords"] ?: @"";
                NSArray *keywordArray = [savedKeywords length] > 0 ? [savedKeywords componentsSeparatedByString:@","] : @[];
                // 創建並顯示關鍵詞列表視圖
                DYYYKeywordListView *keywordListView = [[DYYYKeywordListView alloc] initWithTitle:@"設定過濾關鍵詞" keywords:keywordArray];
                // 設定確認回調
                keywordListView.onConfirm = ^(NSArray *keywords) {
                    // 將關鍵詞陣列轉換為逗號分隔的字串
                    NSString *keywordString = [keywords componentsJoinedByString:@","];
                    // 儲存到使用者預設設定
                    [[NSUserDefaults standardUserDefaults] setObject:keywordString forKey:@"DYYYfilterKeywords"];
                    [[NSUserDefaults standardUserDefaults] synchronize];
                    // 顯示提示
                    [DYYYManager showToast:@"過濾關鍵詞已更新"];
                };
                // 顯示關鍵詞列表視圖
                [keywordListView show];
            };
            [filterView show];
            AWELongPressPanelManager *panelManager = [%c(AWELongPressPanelManager) shareInstance];
            [panelManager dismissWithAnimation:YES completion:nil];
        };
        [viewModels addObject:filterKeywords];
    }
    
    if (enableTimerClose) {
        AWELongPressPanelBaseViewModel *timerCloseViewModel = [[%c(AWELongPressPanelBaseViewModel) alloc] init];
        timerCloseViewModel.awemeModel = self.awemeModel;
        timerCloseViewModel.actionType = 676;
        timerCloseViewModel.duxIconName = @"ic_c_alarm_outlined";
        // 檢查是否已有定時任務在執行
        NSNumber *shutdownTime = [[NSUserDefaults standardUserDefaults] objectForKey:@"DYYYTimerShutdownTime"];
        BOOL hasActiveTimer = shutdownTime != nil && [shutdownTime doubleValue] > [[NSDate date] timeIntervalSince1970];
        timerCloseViewModel.describeString = hasActiveTimer ? @"取消定時" : @"定時關閉";
        timerCloseViewModel.action = ^{
            AWELongPressPanelManager *panelManager = [%c(AWELongPressPanelManager) shareInstance];
            [panelManager dismissWithAnimation:YES completion:nil];
            NSNumber *shutdownTime = [[NSUserDefaults standardUserDefaults] objectForKey:@"DYYYTimerShutdownTime"];
            BOOL hasActiveTimer = shutdownTime != nil && [shutdownTime doubleValue] > [[NSDate date] timeIntervalSince1970];
            if (hasActiveTimer) {
                [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"DYYYTimerShutdownTime"];
                [[NSUserDefaults standardUserDefaults] synchronize];
                [DYYYManager showToast:@"已取消定時關閉任務"];
                return;
            }
            // 讀取上次設定的時間
            NSInteger defaultMinutes = [[NSUserDefaults standardUserDefaults] integerForKey:@"DYYYTimerCloseMinutes"];
            if (defaultMinutes <= 0) {
                defaultMinutes = 5;
            }
            NSString *defaultText = [NSString stringWithFormat:@"%ld", (long)defaultMinutes];
            DYYYCustomInputView *inputView = [[DYYYCustomInputView alloc] initWithTitle:@"設定定時關閉時間" defaultText:defaultText placeholder:@"請輸入關閉時間(單位:分鐘)"];
            inputView.onConfirm = ^(NSString *inputText) {
                NSInteger minutes = [inputText integerValue];
                if (minutes <= 0) {
                    minutes = 5;
                }
                // 儲存使用者設定的時間以供下次使用
                [[NSUserDefaults standardUserDefaults] setInteger:minutes forKey:@"DYYYTimerCloseMinutes"];
                [[NSUserDefaults standardUserDefaults] synchronize];
                NSInteger seconds = minutes * 60;
                NSTimeInterval shutdownTimeValue = [[NSDate date] timeIntervalSince1970] + seconds;
                [[NSUserDefaults standardUserDefaults] setObject:@(shutdownTimeValue) forKey:@"DYYYTimerShutdownTime"];
                [[NSUserDefaults standardUserDefaults] synchronize];
                [DYYYManager showToast:[NSString stringWithFormat:@"抖音將在%ld分鐘後關閉...", (long)minutes]];
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(seconds * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                    NSNumber *currentShutdownTime = [[NSUserDefaults standardUserDefaults] objectForKey:@"DYYYTimerShutdownTime"];
                    if (currentShutdownTime != nil && [currentShutdownTime doubleValue] <= [[NSDate date] timeIntervalSince1970]) {
                        [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"DYYYTimerShutdownTime"];
                        [[NSUserDefaults standardUserDefaults] synchronize];
                        // 顯示確認關閉彈窗，而不是直接退出
                        DYYYConfirmCloseView *confirmView = [[DYYYConfirmCloseView alloc]
                                                            initWithTitle:@"定時關閉"
                                                            message:@"定時關閉時間已到，是否關閉抖音？"];
                        [confirmView show];
                    }
                });
            };
            [inputView show];
        };
        [viewModels addObject:timerCloseViewModel];
    }
    
    // 創建自訂組
    NSMutableArray *customGroups = [NSMutableArray array];
    NSInteger totalButtons = viewModels.count;
    
    // 根據按鈕總數確定每行的按鈕數 
    NSInteger firstRowCount = 0;
    NSInteger secondRowCount = 0;
    
    // 確定分配方式與原程式碼相同
    if (totalButtons <= 2) {
        firstRowCount = totalButtons;
    } else if (totalButtons <= 4) {
        firstRowCount = totalButtons / 2;
        secondRowCount = totalButtons - firstRowCount;
    } else if (totalButtons <= 5) {
        firstRowCount = 3;
        secondRowCount = totalButtons - firstRowCount;
    } else if (totalButtons <= 6) {
        firstRowCount = 4;
        secondRowCount = totalButtons - firstRowCount;
    } else if (totalButtons <= 8) {
        firstRowCount = 4;
        secondRowCount = totalButtons - firstRowCount;
    } else {
        firstRowCount = 5;
        secondRowCount = totalButtons - firstRowCount;
    }
    
    // 創建第一行 
    if (firstRowCount > 0) {
        NSArray<AWELongPressPanelBaseViewModel *> *firstRowButtons = [viewModels subarrayWithRange:NSMakeRange(0, firstRowCount)];
        AWELongPressPanelViewGroupModel *firstRowGroup = [[%c(AWELongPressPanelViewGroupModel) alloc] init];
        firstRowGroup.isDYYYCustomGroup = YES;
        firstRowGroup.groupType = (firstRowCount <= 3) ? 11 : 12;
        firstRowGroup.isModern = YES;
        firstRowGroup.groupArr = firstRowButtons;
        [customGroups addObject:firstRowGroup];
    }
    
    // 創建第二行 
    if (secondRowCount > 0) {
        NSArray<AWELongPressPanelBaseViewModel *> *secondRowButtons = [viewModels subarrayWithRange:NSMakeRange(firstRowCount, secondRowCount)];
        AWELongPressPanelViewGroupModel *secondRowGroup = [[%c(AWELongPressPanelViewGroupModel) alloc] init];
        secondRowGroup.isDYYYCustomGroup = YES;
        secondRowGroup.groupType = (secondRowCount <= 3) ? 11 : 12;
        secondRowGroup.isModern = YES;
        secondRowGroup.groupArr = secondRowButtons;
        [customGroups addObject:secondRowGroup];
    }
    
    // 準備最終結果陣列
    NSMutableArray *resultArray = [NSMutableArray arrayWithArray:customGroups];
    
    // 新增修改後的原始組
    [resultArray addObjectsFromArray:modifiedOriginalGroups];
    
    return resultArray;
}
%end

// 修复Modern风格长按面板水平设置单元格的大小计算
%hook AWEModernLongPressHorizontalSettingCell
- (CGSize)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)layout sizeForItemAtIndexPath:(NSIndexPath *)indexPath {
    if (self.longPressViewGroupModel && [self.longPressViewGroupModel isDYYYCustomGroup]) {
        if (self.dataArray && indexPath.item < self.dataArray.count) {
            CGFloat totalWidth = collectionView.bounds.size.width;
            NSInteger itemCount = self.dataArray.count;
            CGFloat itemWidth = totalWidth / itemCount;
            return CGSizeMake(itemWidth, 73);
        }
        return CGSizeMake(73, 73);
    }
    return %orig;
}
%end

// 修复Modern风格长按面板交互单元格的大小计算
%hook AWEModernLongPressInteractiveCell
- (CGSize)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)layout sizeForItemAtIndexPath:(NSIndexPath *)indexPath {
    if (self.longPressViewGroupModel && [self.longPressViewGroupModel isDYYYCustomGroup]) {
        if (self.dataArray && indexPath.item < self.dataArray.count) {
            NSInteger itemCount = self.dataArray.count;
            CGFloat totalWidth = collectionView.bounds.size.width - 12 * (itemCount - 1);
            CGFloat itemWidth = totalWidth / itemCount;
            return CGSizeMake(itemWidth, 73);
        }
        return CGSizeMake(73, 73);
    }
    return %orig;
}
%end

// 经典风格长按面板
%hook AWELongPressPanelTableViewController
- (NSArray *)dataArray {
    NSArray *originalArray = %orig;
    if (!originalArray) {
        originalArray = @[];
    }
    if (!self.awemeModel.author.nickname) {
        return originalArray;
    }
    
    // 检查是否启用了任意长按功能
    BOOL hasAnyFeatureEnabled = NO;
    
    // 检查各个单独的功能开关
    BOOL enableSaveVideo = [[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYLongPressSaveVideo"];
    BOOL enableSaveCover = [[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYLongPressSaveCover"];
    BOOL enableSaveAudio = [[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYLongPressSaveAudio"];
    BOOL enableSaveCurrentImage = [[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYLongPressSaveCurrentImage"];
    BOOL enableSaveAllImages = [[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYLongPressSaveAllImages"];
    BOOL enableCopyText = [[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYLongPressCopyText"];
    BOOL enableCopyLink = [[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYLongPressCopyLink"];
    BOOL enableApiDownload = [[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYLongPressApiDownload"];
    BOOL enableFilterUser = [[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYLongPressFilterUser"];
    BOOL enableFilterKeyword = [[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYLongPressFilterTitle"];
    BOOL enableTimerClose = [[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYLongPressTimerClose"];
    BOOL enableCreateVideo = [[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYLongPressCreateVideo"];

    // 检查是否有任何功能启用
    hasAnyFeatureEnabled = enableSaveVideo || enableSaveCover || enableSaveAudio || enableSaveCurrentImage || enableSaveAllImages || enableCopyText || enableCopyLink || enableApiDownload ||
                           enableFilterUser || enableFilterKeyword || enableTimerClose || enableCreateVideo;
    
    // 处理原始面板按钮的显示/隐藏
    NSMutableArray *modifiedArray = [NSMutableArray array];
    
    // 获取需要隐藏的按钮设置
    BOOL hideDaily = [[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYHidePanelDaily"];
    BOOL hideRecommend = [[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYHidePanelRecommend"];
    BOOL hideNotInterested = [[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYHidePanelNotInterested"];
    BOOL hideReport = [[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYHidePanelReport"];
    BOOL hideSpeed = [[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYHidePanelSpeed"];
    BOOL hideClearScreen = [[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYHidePanelClearScreen"];
    BOOL hideFavorite = [[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYHidePanelFavorite"];
    BOOL hideLater = [[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYHidePanelLater"];
    BOOL hideCast = [[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYHidePanelCast"];
    BOOL hideOpenInPC = [[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYHidePanelOpenInPC"];
    BOOL hideSubtitle = [[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYHidePanelSubtitle"];
    BOOL hideAutoPlay = [[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYHidePanelAutoPlay"];
    BOOL hideSearchImage = [[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYHidePanelSearchImage"];
    BOOL hideListenDouyin = [[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYHidePanelListenDouyin"];
    BOOL hideBackgroundPlay = [[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYHidePanelBackgroundPlay"];
    BOOL hideBiserial = [[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYHidePanelBiserial"];

    // 收集所有未被隐藏的官方按钮
    NSMutableArray *officialButtons = [NSMutableArray array];
    
    // 处理原始面板
    for (id group in originalArray) {
        // 檢查是否為視圖組模型
        if ([group isKindOfClass:%c(AWELongPressPanelViewGroupModel)]) {
            AWELongPressPanelViewGroupModel *groupModel = (AWELongPressPanelViewGroupModel *)group;
            NSMutableArray *filteredGroupArr = [NSMutableArray array];
            for (id item in groupModel.groupArr) {
                // 檢查是否為基礎視圖模型
                if ([item isKindOfClass:%c(AWELongPressPanelBaseViewModel)]) {
                    AWELongPressPanelBaseViewModel *viewModel = (AWELongPressPanelBaseViewModel *)item;
                    NSString *descString = viewModel.describeString;
                    // 根據描述字串判斷按鈕類型並決定是否隱藏
                    BOOL shouldHide = NO;
                    if ([descString isEqualToString:@"转发到日常"] && hideDaily) {
                        shouldHide = YES;
                    } else if ([descString isEqualToString:@"推荐"] && hideRecommend) {
                        shouldHide = YES;
                    } else if ([descString isEqualToString:@"不感兴趣"] && hideNotInterested) {
                        shouldHide = YES;
                    } else if ([descString isEqualToString:@"举报"] && hideReport) {
                        shouldHide = YES;
                    } else if ([descString isEqualToString:@"倍速"] && hideSpeed) {
                        shouldHide = YES;
                    } else if ([descString isEqualToString:@"清屏播放"] && hideClearScreen) {
                        shouldHide = YES;
                    } else if ([descString isEqualToString:@"缓存视频"] && hideFavorite) {
                        shouldHide = YES;
                    } else if ([descString isEqualToString:@"添加至稍后再看"] && hideLater) {
                        shouldHide = YES;
                    } else if ([descString isEqualToString:@"投屏"] && hideCast) {
                        shouldHide = YES;
                    } else if ([descString isEqualToString:@"电脑/Pad打开"] && hideOpenInPC) {
                        shouldHide = YES;
                    } else if ([descString isEqualToString:@"弹幕"] && hideSubtitle) {
                        shouldHide = YES;
                    } else if ([descString isEqualToString:@"弹幕开关"] && hideSubtitle) {
                        shouldHide = YES;
                    } else if ([descString isEqualToString:@"弹幕设置"] && hideSubtitle) {
                        shouldHide = YES;
                    } else if ([descString isEqualToString:@"自动连播"] && hideAutoPlay) {
                        shouldHide = YES;
                    } else if ([descString isEqualToString:@"识别图片"] && hideSearchImage) {
                        shouldHide = YES;
                    } else if ([descString isEqualToString:@"听抖音"] && hideListenDouyin) {
                        shouldHide = YES;
                    } else if ([descString isEqualToString:@"后台播放设置"] && hideBackgroundPlay) {
                        shouldHide = YES;
                    } else if ([descString isEqualToString:@"首页双列快捷入口"] && hideBiserial) {
                        shouldHide = YES;
                    }
                    if (!shouldHide) {
                        // 添加图标修改逻辑
                        if ([descString isEqualToString:@"后台播放设置"]) {
                            viewModel.duxIconName = @"ic_phonearrowup_outlined_20";
                        } else if ([descString isEqualToString:@"转发到日常"]) {
                            viewModel.duxIconName = @"ic_flash_outlined_20";
                        } else if ([descString isEqualToString:@"首页双列快捷入口"]) {
                            viewModel.duxIconName = @"ic_squaresplit_outlined_20";
                        } else if ([descString isEqualToString:@"推荐"]) {
                            viewModel.duxIconName = @"ic_thumbsup_outlined_20";
                        } else if ([descString isEqualToString:@"不感兴趣"]) {
                            viewModel.duxIconName = @"ic_heartbreak_outlined_20";
                        } else if ([descString isEqualToString:@"弹幕"] || 
                                  [descString isEqualToString:@"弹幕开关"] || 
                                  [descString isEqualToString:@"弹幕设置"]) {
                            viewModel.duxIconName = @"ic_dansquare_outlined_20";
                        }
                        
                        // 新增到過濾後的按鈕組
                        [filteredGroupArr addObject:viewModel];
                        
                        // 同時新增到官方按鈕列表，用於重組
                        [officialButtons addObject:viewModel];
                    }
                } else {
                    // 不是視圖模型的，直接新增
                    [filteredGroupArr addObject:item];
                }
            }
            // 如果過濾後的陣列不為空，則保留原始結構
            if (filteredGroupArr.count > 0) {
                AWELongPressPanelViewGroupModel *newGroup = [[%c(AWELongPressPanelViewGroupModel) alloc] init];
                newGroup.groupType = groupModel.groupType;
                newGroup.groupArr = filteredGroupArr;
                [modifiedArray addObject:newGroup];
            }
        } else {
            // 不是組模型的，直接新增
            [modifiedArray addObject:group];
        }
    }
    
    // 如果沒有任何功能啟用，返回修改後的原始陣列
    if (!hasAnyFeatureEnabled) {
        return modifiedArray;
    }
    
    // 創建自訂功能組
    AWELongPressPanelViewGroupModel *newGroupModel = [[%c(AWELongPressPanelViewGroupModel) alloc] init];
    newGroupModel.groupType = 0;
    NSMutableArray *viewModels = [NSMutableArray array];
    
    // 影片下載功能
    if (enableSaveVideo && self.awemeModel.awemeType != 68) {
        AWELongPressPanelBaseViewModel *downloadViewModel = [[%c(AWELongPressPanelBaseViewModel) alloc] init];
        downloadViewModel.awemeModel = self.awemeModel;
        downloadViewModel.actionType = 666;
        downloadViewModel.duxIconName = @"ic_boxarrowdownhigh_outlined";
        downloadViewModel.describeString = @"儲存影片";
        downloadViewModel.action = ^{
            AWEAwemeModel *awemeModel = self.awemeModel;
            AWEVideoModel *videoModel = awemeModel.video;
            
            if (videoModel && videoModel.bitrateRawData && videoModel.bitrateRawData.count > 0) {
                // 查找最高品質版本
                id highestQualityModel = nil;
                int highestResolution = 0;
                int highestFPS = 0;
                int highestBitRate = 0;
                
                for (id model in videoModel.bitrateRawData) {
                    // 從gear_name取得解析度
                    NSString *gearName = [model valueForKey:@"gear_name"];
                    int resolution = 0;
                    
                    if ([gearName containsString:@"1440"]) {
                        resolution = 1440;
                    } else if ([gearName containsString:@"1080"]) {
                        resolution = 1080;
                    } else if ([gearName containsString:@"720"]) {
                        resolution = 720;
                    } else if ([gearName containsString:@"540"]) {
                        resolution = 540;
                    } else if ([gearName containsString:@"480"]) {
                        resolution = 480;
                    } else if ([gearName containsString:@"360"]) {
                        resolution = 360;
                    }
                    
                    // 取得幀率和位元率
                    int fps = [[model valueForKey:@"FPS"] intValue];
                    int bitRate = [[model valueForKey:@"bit_rate"] intValue];
                    
                    // 比較並選擇最高品質
                    if (resolution > highestResolution || 
                        (resolution == highestResolution && fps > highestFPS) ||
                        (resolution == highestResolution && fps == highestFPS && bitRate > highestBitRate)) {
                        highestResolution = resolution;
                        highestFPS = fps;
                        highestBitRate = bitRate;
                        highestQualityModel = model;
                    }
                }
                
                // 如果找不到最高品質模型，使用第一個
                if (!highestQualityModel && videoModel.bitrateRawData.count > 0) {
                    highestQualityModel = videoModel.bitrateRawData.firstObject;
                }
                
                NSArray *urlList = nil;
                id playAddrObj = [highestQualityModel valueForKey:@"playAddr"];
                    
                if ([playAddrObj isKindOfClass:%c(AWEURLModel)]) {
                    AWEURLModel *playAddrModel = (AWEURLModel *)playAddrObj;
                    urlList = playAddrModel.originURLList;
                }

                if (urlList && urlList.count > 0) {
                    NSURL *url = [NSURL URLWithString:urlList.firstObject];
                    [DYYYManager downloadMedia:url
                                    mediaType:MediaTypeVideo
                                    completion:^(BOOL success){
                                    }];
                } else {
                    // 備用方法：直接使用h264URL
                    if (videoModel.h264URL && videoModel.h264URL.originURLList.count > 0) {
                        NSURL *url = [NSURL URLWithString:videoModel.h264URL.originURLList.firstObject];
                        [DYYYManager downloadMedia:url
                                        mediaType:MediaTypeVideo
                                        completion:^(BOOL success){
                                        }];
                    } 
                }
            }
            AWELongPressPanelManager *panelManager = [%c(AWELongPressPanelManager) shareInstance];
            [panelManager dismissWithAnimation:YES completion:nil];
        };
        [viewModels addObject:downloadViewModel];
    }
    
    // 封面下載功能
    if (enableSaveCover && self.awemeModel.awemeType != 68) {
        AWELongPressPanelBaseViewModel *coverViewModel = [[%c(AWELongPressPanelBaseViewModel) alloc] init];
        coverViewModel.awemeModel = self.awemeModel;
        coverViewModel.actionType = 667;
        coverViewModel.duxIconName = @"ic_boxarrowdownhigh_outlined";
        coverViewModel.describeString = @"儲存封面";
        coverViewModel.action = ^{
            AWEAwemeModel *awemeModel = self.awemeModel;
            AWEVideoModel *videoModel = awemeModel.video;
            if (videoModel && videoModel.coverURL && videoModel.coverURL.originURLList.count > 0) {
                NSURL *url = [NSURL URLWithString:videoModel.coverURL.originURLList.firstObject];
                [DYYYManager downloadMedia:url
                                mediaType:MediaTypeImage
                                completion:^(BOOL success){
                                    if (success) {
                                    } else {
                                        [DYYYManager showToast:@"封面儲存已取消"];
                                    }
                                }];
            }
            AWELongPressPanelManager *panelManager = [%c(AWELongPressPanelManager) shareInstance];
            [panelManager dismissWithAnimation:YES completion:nil];
        };
        [viewModels addObject:coverViewModel];
    }
    
    // 音訊下載功能
    if (enableSaveAudio) {
        AWELongPressPanelBaseViewModel *audioViewModel = [[%c(AWELongPressPanelBaseViewModel) alloc] init];
        audioViewModel.awemeModel = self.awemeModel;
        audioViewModel.actionType = 668;
        audioViewModel.duxIconName = @"ic_boxarrowdownhigh_outlined";
        audioViewModel.describeString = @"儲存音訊";
        audioViewModel.action = ^{
            AWEAwemeModel *awemeModel = self.awemeModel;
            AWEMusicModel *musicModel = awemeModel.music;
            if (musicModel && musicModel.playURL && musicModel.playURL.originURLList.count > 0) {
                NSURL *url = [NSURL URLWithString:musicModel.playURL.originURLList.firstObject];
                [DYYYManager downloadMedia:url mediaType:MediaTypeAudio completion:nil];
            }
            AWELongPressPanelManager *panelManager = [%c(AWELongPressPanelManager) shareInstance];
            [panelManager dismissWithAnimation:YES completion:nil];
        };
        [viewModels addObject:audioViewModel];
    }
    
    // 目前圖片/原況下載功能
    if (enableSaveCurrentImage && self.awemeModel.awemeType == 68 && self.awemeModel.albumImages.count > 0) {
        AWELongPressPanelBaseViewModel *imageViewModel = [[%c(AWELongPressPanelBaseViewModel) alloc] init];
        imageViewModel.awemeModel = self.awemeModel;
        imageViewModel.actionType = 669;
        imageViewModel.duxIconName = @"ic_boxarrowdownhigh_outlined";
        imageViewModel.describeString = @"儲存目前圖片";
        AWEImageAlbumImageModel *currimge = self.awemeModel.albumImages[self.awemeModel.currentImageIndex - 1];
        if (currimge.clipVideo != nil) {
            imageViewModel.describeString = @"儲存目前原況";
        }
        imageViewModel.action = ^{
            AWEAwemeModel *awemeModel = self.awemeModel;
            AWEImageAlbumImageModel *currentImageModel = nil;
            if (awemeModel.currentImageIndex > 0 && awemeModel.currentImageIndex <= awemeModel.albumImages.count) {
                currentImageModel = awemeModel.albumImages[awemeModel.currentImageIndex - 1];
            } else {
                currentImageModel = awemeModel.albumImages.firstObject;
            }
            // 如果是原況的話
            if (currentImageModel.clipVideo != nil) {
                NSURL *url = [NSURL URLWithString:currentImageModel.urlList.firstObject];
                NSURL *videoURL = [currentImageModel.clipVideo.playURL getDYYYSrcURLDownload];
                [DYYYManager downloadLivePhoto:url
                                      videoURL:videoURL
                                    completion:^{
                                    }];
            } else if (currentImageModel && currentImageModel.urlList.count > 0) {
                NSURL *url = [NSURL URLWithString:currentImageModel.urlList.firstObject];
                [DYYYManager downloadMedia:url
                                mediaType:MediaTypeImage
                                completion:^(BOOL success){
                                    if (success) {
                                    } else {
                                        [DYYYManager showToast:@"圖片儲存已取消"];
                                    }
                                }];
            }
            AWELongPressPanelManager *panelManager = [%c(AWELongPressPanelManager) shareInstance];
            [panelManager dismissWithAnimation:YES completion:nil];
        };
        [viewModels addObject:imageViewModel];
    }
    
    // 儲存所有圖片/原況功能
    if (enableSaveAllImages && self.awemeModel.awemeType == 68 && self.awemeModel.albumImages.count > 1) {
        AWELongPressPanelBaseViewModel *allImagesViewModel = [[%c(AWELongPressPanelBaseViewModel) alloc] init];
        allImagesViewModel.awemeModel = self.awemeModel;
        allImagesViewModel.actionType = 670;
        allImagesViewModel.duxIconName = @"ic_boxarrowdownhigh_outlined";
        allImagesViewModel.describeString = @"儲存所有圖片";
        // 檢查是否有原況照片並更改按鈕文字
        BOOL hasLivePhoto = NO;
        for (AWEImageAlbumImageModel *imageModel in self.awemeModel.albumImages) {
            if (imageModel.clipVideo != nil) {
                hasLivePhoto = YES;
                break;
            }
        }
        if (hasLivePhoto) {
            allImagesViewModel.describeString = @"儲存所有原況";
        }
        allImagesViewModel.action = ^{
            AWEAwemeModel *awemeModel = self.awemeModel;
            NSMutableArray *imageURLs = [NSMutableArray array];
            for (AWEImageAlbumImageModel *imageModel in awemeModel.albumImages) {
                if (imageModel.urlList.count > 0) {
                    [imageURLs addObject:imageModel.urlList.firstObject];
                }
            }
            // 檢查是否有原況照片
            BOOL hasLivePhoto = NO;
            for (AWEImageAlbumImageModel *imageModel in awemeModel.albumImages) {
                if (imageModel.clipVideo != nil) {
                    hasLivePhoto = YES;
                    break;
                }
            }
            // 如果有原況照片，使用單獨的downloadLivePhoto方法逐個下載
            if (hasLivePhoto) {
                NSMutableArray *livePhotos = [NSMutableArray array];
                for (AWEImageAlbumImageModel *imageModel in awemeModel.albumImages) {
                    if (imageModel.urlList.count > 0 && imageModel.clipVideo != nil) {
                        NSURL *photoURL = [NSURL URLWithString:imageModel.urlList.firstObject];
                        NSURL *videoURL = [imageModel.clipVideo.playURL getDYYYSrcURLDownload];
                        [livePhotos addObject:@{@"imageURL" : photoURL.absoluteString, @"videoURL" : videoURL.absoluteString}];
                    }
                }
                // 使用批量下載原況照片方法
                [DYYYManager downloadAllLivePhotos:livePhotos];
            } else if (imageURLs.count > 0) {
                [DYYYManager downloadAllImages:imageURLs];
            }
            AWELongPressPanelManager *panelManager = [%c(AWELongPressPanelManager) shareInstance];
            [panelManager dismissWithAnimation:YES completion:nil];
        };
        [viewModels addObject:allImagesViewModel];
    }
    
        // 创建视频功能
    if (enableCreateVideo && self.awemeModel.awemeType == 68 && self.awemeModel.albumImages.count > 1) {
        AWELongPressPanelBaseViewModel *createVideoViewModel = [[%c(AWELongPressPanelBaseViewModel) alloc] init];
        createVideoViewModel.awemeModel = self.awemeModel;
        createVideoViewModel.actionType = 677;
        createVideoViewModel.duxIconName = @"ic_videosearch_outlined_20";
        createVideoViewModel.describeString = @"製作影片";
        createVideoViewModel.action = ^{
            AWEAwemeModel *awemeModel = self.awemeModel;
            
            // 收集普通圖片URL
            NSMutableArray *imageURLs = [NSMutableArray array];
            // 收集原況照片資訊（圖片URL+影片URL）
            NSMutableArray *livePhotos = [NSMutableArray array];
            
            // 取得背景音樂URL
            NSString *bgmURL = nil;
            if (awemeModel.music && awemeModel.music.playURL && awemeModel.music.playURL.originURLList.count > 0) {
                bgmURL = awemeModel.music.playURL.originURLList.firstObject;
            }
            
            // 處理所有圖片和原況
            for (AWEImageAlbumImageModel *imageModel in awemeModel.albumImages) {
                if (imageModel.urlList.count > 0) {
                    // 查找非.image後綴的URL
                    NSString *bestURL = nil;
                    for (NSString *urlString in imageModel.urlList) {
                        NSURL *url = [NSURL URLWithString:urlString];
                        NSString *pathExtension = [url.path.lowercaseString pathExtension];
                        if (![pathExtension isEqualToString:@"image"]) {
                            bestURL = urlString;
                            break;
                        }
                    }
                    
                    if (!bestURL && imageModel.urlList.count > 0) {
                        bestURL = imageModel.urlList.firstObject;
                    }
                    
                    // 如果是原況照片，需要收集圖片和影片URL
                    if (imageModel.clipVideo != nil) {
                        NSURL *videoURL = [imageModel.clipVideo.playURL getDYYYSrcURLDownload];
                        if (videoURL) {
                            [livePhotos addObject:@{
                                @"imageURL": bestURL,
                                @"videoURL": videoURL.absoluteString
                            }];
                        }
                    } else {
                        // 普通圖片
                        [imageURLs addObject:bestURL];
                    }
                }
            }
            
            // 呼叫影片創建API
            [DYYYManager createVideoFromMedia:imageURLs
                                   livePhotos:livePhotos
                                       bgmURL:bgmURL
                                     progress:^(NSInteger current, NSInteger total, NSString *status) {
                                     }
                                   completion:^(BOOL success, NSString *message) {
                                         if (success) {
                                         } else {
                                             [DYYYManager showToast:[NSString stringWithFormat:@"影片製作失敗: %@", message]];
                                         }
                                     }];
            
            AWELongPressPanelManager *panelManager = [%c(AWELongPressPanelManager) shareInstance];
            [panelManager dismissWithAnimation:YES completion:nil];
        };
        [viewModels addObject:createVideoViewModel];
    }
    
    // 複製文案功能
    if (enableCopyText) {
        AWELongPressPanelBaseViewModel *copyText = [[%c(AWELongPressPanelBaseViewModel) alloc] init];
        copyText.awemeModel = self.awemeModel;
        copyText.actionType = 671;
        copyText.duxIconName = @"ic_xiaoxihuazhonghua_outlined";
        copyText.describeString = @"複製文案";
        copyText.action = ^{
            NSString *descText = [self.awemeModel valueForKey:@"descriptionString"];
            [[UIPasteboard generalPasteboard] setString:descText];
            [DYYYToast showSuccessToastWithMessage:@"文案已複製"];
            AWELongPressPanelManager *panelManager = [%c(AWELongPressPanelManager) shareInstance];
            [panelManager dismissWithAnimation:YES completion:nil];
        };
        [viewModels addObject:copyText];
    }
    
    // 複製分享連結功能
    if (enableCopyLink) {
        AWELongPressPanelBaseViewModel *copyShareLink = [[%c(AWELongPressPanelBaseViewModel) alloc] init];
        copyShareLink.awemeModel = self.awemeModel;
        copyShareLink.actionType = 672;
        copyShareLink.duxIconName = @"ic_share_outlined";
        copyShareLink.describeString = @"複製連結";
        copyShareLink.action = ^{
            NSString *shareLink = [self.awemeModel valueForKey:@"shareURL"];
            NSString *cleanedURL = cleanShareURL(shareLink);
            [[UIPasteboard generalPasteboard] setString:cleanedURL];
            [DYYYToast showSuccessToastWithMessage:@"分享連結已複製"];
            AWELongPressPanelManager *panelManager = [%c(AWELongPressPanelManager) shareInstance];
            [panelManager dismissWithAnimation:YES completion:nil];
        };
        [viewModels addObject:copyShareLink];
    }
    
    // 接口保存功能
    NSString *apiKey = [[NSUserDefaults standardUserDefaults] objectForKey:@"DYYYInterfaceDownload"];
    if (enableApiDownload && apiKey.length > 0) {
        AWELongPressPanelBaseViewModel *apiDownload = [[%c(AWELongPressPanelBaseViewModel) alloc] init];
        apiDownload.awemeModel = self.awemeModel;
        apiDownload.actionType = 673;
        apiDownload.duxIconName = @"ic_cloudarrowdown_outlined_20";
        apiDownload.describeString = @"介面儲存";
        apiDownload.action = ^{
            NSString *shareLink = [self.awemeModel valueForKey:@"shareURL"];
            if (shareLink.length == 0) {
                [DYYYManager showToast:@"無法取得分享連結"];
                return;
            }
            // 使用封裝的方法進行解析下載
            [DYYYManager parseAndDownloadVideoWithShareLink:shareLink apiKey:apiKey];
            AWELongPressPanelManager *panelManager = [%c(AWELongPressPanelManager) shareInstance];
            [panelManager dismissWithAnimation:YES completion:nil];
        };
        [viewModels addObject:apiDownload];
    }
    
    if (enableTimerClose) {
        AWELongPressPanelBaseViewModel *timerCloseViewModel = [[%c(AWELongPressPanelBaseViewModel) alloc] init];
        timerCloseViewModel.awemeModel = self.awemeModel;
        timerCloseViewModel.actionType = 676;
        timerCloseViewModel.duxIconName = @"ic_c_alarm_outlined";
        // 檢查是否已有定時任務在執行
        NSNumber *shutdownTime = [[NSUserDefaults standardUserDefaults] objectForKey:@"DYYYTimerShutdownTime"];
        BOOL hasActiveTimer = shutdownTime != nil && [shutdownTime doubleValue] > [[NSDate date] timeIntervalSince1970];
        timerCloseViewModel.describeString = hasActiveTimer ? @"取消定時" : @"定時關閉";
        timerCloseViewModel.action = ^{
            AWELongPressPanelManager *panelManager = [%c(AWELongPressPanelManager) shareInstance];
            [panelManager dismissWithAnimation:YES completion:nil];
            NSNumber *shutdownTime = [[NSUserDefaults standardUserDefaults] objectForKey:@"DYYYTimerShutdownTime"];
            BOOL hasActiveTimer = shutdownTime != nil && [shutdownTime doubleValue] > [[NSDate date] timeIntervalSince1970];
            if (hasActiveTimer) {
                [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"DYYYTimerShutdownTime"];
                [[NSUserDefaults standardUserDefaults] synchronize];
                [DYYYManager showToast:@"已取消定時關閉任務"];
                return;
            }
            // 讀取上次設定的時間，如果沒有則使用預設值5分鐘
            NSInteger defaultMinutes = [[NSUserDefaults standardUserDefaults] integerForKey:@"DYYYTimerCloseMinutes"];
            if (defaultMinutes <= 0) {
                defaultMinutes = 5;
            }
            NSString *defaultText = [NSString stringWithFormat:@"%ld", (long)defaultMinutes];
            DYYYCustomInputView *inputView = [[DYYYCustomInputView alloc] initWithTitle:@"設定定時關閉時間" defaultText:defaultText placeholder:@"請輸入關閉時間(單位:分鐘)"];
            inputView.onConfirm = ^(NSString *inputText) {
                NSInteger minutes = [inputText integerValue];
                if (minutes <= 0) {
                    minutes = 5;
                }
                // 儲存使用者設定的時間以供下次使用
                [[NSUserDefaults standardUserDefaults] setInteger:minutes forKey:@"DYYYTimerCloseMinutes"];
                [[NSUserDefaults standardUserDefaults] synchronize];
                NSInteger seconds = minutes * 60;
                NSTimeInterval shutdownTimeValue = [[NSDate date] timeIntervalSince1970] + seconds;
                [[NSUserDefaults standardUserDefaults] setObject:@(shutdownTimeValue) forKey:@"DYYYTimerShutdownTime"];
                [[NSUserDefaults standardUserDefaults] synchronize];
                [DYYYManager showToast:[NSString stringWithFormat:@"抖音將在%ld分鐘後關閉...", (long)minutes]];
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(seconds * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                    NSNumber *currentShutdownTime = [[NSUserDefaults standardUserDefaults] objectForKey:@"DYYYTimerShutdownTime"];
                    if (currentShutdownTime != nil && [currentShutdownTime doubleValue] <= [[NSDate date] timeIntervalSince1970]) {
                        [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"DYYYTimerShutdownTime"];
                        [[NSUserDefaults standardUserDefaults] synchronize];
                        // 顯示確認關閉彈窗，而不是直接退出
                        DYYYConfirmCloseView *confirmView = [[DYYYConfirmCloseView alloc]
                                                            initWithTitle:@"定時關閉"
                                                            message:@"定時關閉時間已到，是否關閉抖音？"];
                        [confirmView show];
                    }
                });
            };
            [inputView show];
        };
        [viewModels addObject:timerCloseViewModel];
    }
    
    // 过滤用户功能
    if (enableFilterUser) {
        AWELongPressPanelBaseViewModel *filterKeywords = [[%c(AWELongPressPanelBaseViewModel) alloc] init];
        filterKeywords.awemeModel = self.awemeModel;
        filterKeywords.actionType = 674;
        filterKeywords.duxIconName = @"ic_userban_outlined_20";
        filterKeywords.describeString = @"過濾使用者";
        filterKeywords.action = ^{
            // 获取当前视频作者信息
            AWEUserModel *author = self.awemeModel.author;
            NSString *nickname = author.nickname ?: @"未知使用者";
            NSString *shortId = author.shortID ?: @"";
            // 创建当前用户的过滤格式 "nickname-shortid"
            NSString *currentUserFilter = [NSString stringWithFormat:@"%@-%@", nickname, shortId];
            // 获取保存的过滤用户列表
            NSString *savedUsers = [[NSUserDefaults standardUserDefaults] objectForKey:@"DYYYfilterUsers"] ?: @"";
            NSArray *userArray = [savedUsers length] > 0 ? [savedUsers componentsSeparatedByString:@","] : @[];
            // 检查当前用户是否已在过滤列表中
            BOOL userExists = NO;
            for (NSString *userInfo in userArray) {
                NSArray *components = [userInfo componentsSeparatedByString:@"-"];
                if (components.count >= 2) {
                    NSString *userId = [components lastObject];
                    if ([userId isEqualToString:shortId] && shortId.length > 0) {
                        userExists = YES;
                        break;
                    }
                }
            }
            NSString *actionButtonText = userExists ? @"取消過濾" : @"新增過濾";
            [DYYYBottomAlertView showAlertWithTitle:@"過濾使用者影片"
                                            message:[NSString stringWithFormat:@"使用者: %@ (ID: %@)", nickname, shortId]
                                   cancelButtonText:@"管理過濾列表"
                                  confirmButtonText:actionButtonText
                                       cancelAction:^{
                // 创建并显示关键词列表视图
                DYYYKeywordListView *keywordListView = [[DYYYKeywordListView alloc] initWithTitle:@"過濾使用者列表" keywords:userArray];
                // 设置确认回调
                keywordListView.onConfirm = ^(NSArray *users) {
                    // 将用户数组转换为逗号分隔的字符串
                    NSString *userString = [users componentsJoinedByString:@","];
                    // 保存到用户默认设置
                    [[NSUserDefaults standardUserDefaults] setObject:userString forKey:@"DYYYfilterUsers"];
                    [[NSUserDefaults standardUserDefaults] synchronize];
                    // 显示提示
                    [DYYYManager showToast:@"過濾使用者列表已更新"];
                };
                [keywordListView show];
            }
            confirmAction:^{
                // 添加或移除用户过滤
                NSMutableArray *updatedUsers = [NSMutableArray arrayWithArray:userArray];
                if (userExists) {
                    // 移除用户
                    NSMutableArray *toRemove = [NSMutableArray array];
                    for (NSString *userInfo in updatedUsers) {
                        NSArray *components = [userInfo componentsSeparatedByString:@"-"];
                        if (components.count >= 2) {
                            NSString *userId = [components lastObject];
                            if ([userId isEqualToString:shortId]) {
                                [toRemove addObject:userInfo];
                            }
                        }
                    }
                    [updatedUsers removeObjectsInArray:toRemove];
                    [DYYYManager showToast:@"已從過濾列表中移除此使用者"];
                                } else {
                    // 添加用户
                    [updatedUsers addObject:currentUserFilter];
                    [DYYYManager showToast:@"已新增此使用者到過濾列表"];
                }
                // 保存更新后的列表
                NSString *updatedUserString = [updatedUsers componentsJoinedByString:@","];
                [[NSUserDefaults standardUserDefaults] setObject:updatedUserString forKey:@"DYYYfilterUsers"];
                [[NSUserDefaults standardUserDefaults] synchronize];
            }];
        };
        [viewModels addObject:filterKeywords];
    }
    
    // 过滤文案功能
    if (enableFilterKeyword) {
        AWELongPressPanelBaseViewModel *filterKeywords = [[%c(AWELongPressPanelBaseViewModel) alloc] init];
        filterKeywords.awemeModel = self.awemeModel;
        filterKeywords.actionType = 675;
        filterKeywords.duxIconName = @"ic_funnel_outlined_20";
        filterKeywords.describeString = @"過濾文案";
        filterKeywords.action = ^{
            NSString *descText = [self.awemeModel valueForKey:@"descriptionString"];
            DYYYFilterSettingsView *filterView = [[DYYYFilterSettingsView alloc] initWithTitle:@"過濾關鍵詞調整" text:descText];
            filterView.onConfirm = ^(NSString *selectedText) {
                if (selectedText.length > 0) {
                    NSString *currentKeywords = [[NSUserDefaults standardUserDefaults] objectForKey:@"DYYYfilterKeywords"] ?: @"";
                    NSString *newKeywords;
                    if (currentKeywords.length > 0) {
                        newKeywords = [NSString stringWithFormat:@"%@,%@", currentKeywords, selectedText];
                    } else {
                        newKeywords = selectedText;
                    }
                    [[NSUserDefaults standardUserDefaults] setObject:newKeywords forKey:@"DYYYfilterKeywords"];
                    [[NSUserDefaults standardUserDefaults] synchronize];
                    [DYYYManager showToast:[NSString stringWithFormat:@"已新增過濾詞: %@", selectedText]];
                }
            };
            // 设置过滤关键词按钮回调
            filterView.onKeywordFilterTap = ^{
                // 获取保存的关键词
                NSString *savedKeywords = [[NSUserDefaults standardUserDefaults] objectForKey:@"DYYYfilterKeywords"] ?: @"";
                NSArray *keywordArray = [savedKeywords length] > 0 ? [savedKeywords componentsSeparatedByString:@","] : @[];
                // 创建并显示关键词列表视图
                DYYYKeywordListView *keywordListView = [[DYYYKeywordListView alloc] initWithTitle:@"設定過濾關鍵詞" keywords:keywordArray];
                // 设置确认回调
                keywordListView.onConfirm = ^(NSArray *keywords) {
                    // 将关键词数组转换为逗号分隔的字符串
                    NSString *keywordString = [keywords componentsJoinedByString:@","];
                    // 保存到用户默认设置
                    [[NSUserDefaults standardUserDefaults] setObject:keywordString forKey:@"DYYYfilterKeywords"];
                    [[NSUserDefaults standardUserDefaults] synchronize];
                    // 显示提示
                    [DYYYManager showToast:@"過濾關鍵詞已更新"];
                };
                // 显示关键词列表视图
                [keywordListView show];
            };
            [filterView show];
            AWELongPressPanelManager *panelManager = [%c(AWELongPressPanelManager) shareInstance];
            [panelManager dismissWithAnimation:YES completion:nil];
        };
        [viewModels addObject:filterKeywords];
    }
    
    newGroupModel.groupArr = viewModels;
    
    // 返回自定义组+原始组的结果
    if (modifiedArray.count > 0) {
        NSMutableArray *resultArray = [modifiedArray mutableCopy];
        [resultArray insertObject:newGroupModel atIndex:0];
        return [resultArray copy];
    } else {
        return @[ newGroupModel ];
    }
}
%end

%ctor {
    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYUserAgreementAccepted"]) {
        %init;
    }
}

%group DYYYFilterSetterGroup

%hook HOOK_TARGET_OWNER_CLASS

- (void)setModelsArray:(id)arg1 {
    if (![arg1 isKindOfClass:[NSArray class]]) {
        %orig(arg1);
        return;
    }

    NSArray *inputArray = (NSArray *)arg1;
    NSMutableArray *filteredArray = nil;

    for (id item in inputArray) {
        NSString *className = NSStringFromClass([item class]);

        BOOL shouldFilter =
   ([className isEqualToString:@"AWECommentIMSwiftImpl.CommentLongPressPanelForwardElement"] &&
             [[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYHideCommentLongPressDaily"]) ||

            ([className isEqualToString:@"AWECommentLongPressPanelSwiftImpl.CommentLongPressPanelCopyElement"] &&
             [[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYHideCommentLongPressCopy"]) ||

            ([className isEqualToString:@"AWECommentLongPressPanelSwiftImpl.CommentLongPressPanelSaveImageElement"] &&
             [[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYHideCommentLongPressSaveImage"]) ||

            ([className isEqualToString:@"AWECommentLongPressPanelSwiftImpl.CommentLongPressPanelReportElement"] &&
             [[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYHideCommentLongPressReport"]) ||

            ([className isEqualToString:@"AWECommentStudioSwiftImpl.CommentLongPressPanelVideoReplyElement"] &&
             [[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYHideCommentLongPressVideoReply"]) ||

            ([className isEqualToString:@"AWECommentSearchSwiftImpl.CommentLongPressPanelPictureSearchElement"] &&
             [[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYHideCommentLongPressPictureSearch"]) ||

            ([className isEqualToString:@"AWECommentSearchSwiftImpl.CommentLongPressPanelSearchElement"] &&
             [[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYHideCommentLongPressSearch"]);

        if (shouldFilter) {
            if (!filteredArray) {
                filteredArray = [NSMutableArray arrayWithCapacity:inputArray.count];
                for (id keepItem in inputArray) {
                    if (keepItem == item) break;
                    [filteredArray addObject:keepItem];
                }
            }
            continue;
        }

        if (filteredArray) {
            [filteredArray addObject:item];
        }
    }

    if (filteredArray) {
        %orig([filteredArray copy]);
    } else {
        %orig(arg1);
    }
}

%end
%end

%ctor {
    Class ownerClass = objc_getClass("AWECommentLongPressPanelSwiftImpl.CommentLongPressPanelNormalSectionViewModel");
    if (ownerClass) {
        %init(DYYYFilterSetterGroup, HOOK_TARGET_OWNER_CLASS = ownerClass);
    }
}