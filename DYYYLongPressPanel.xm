#import <objc/message.h>
#import <objc/runtime.h>
#import <substrate.h>

#import "AwemeHeaders.h"
#import "DYYYBottomAlertView.h"
#import "DYYYConfirmCloseView.h"
#import "DYYYCustomInputView.h"
#import "DYYYFilterSettingsView.h"
#import "DYYYKeywordListView.h"
#import "DYYYManager.h"
#import "DYYYToast.h"
#import "DYYYUtils.h"

%hook AWELongPressPanelViewGroupModel
%property(nonatomic, assign) BOOL isDYYYCustomGroup;
%end

// Modern风格长按面板（新版UI）
%hook AWEModernLongPressPanelTableViewController
- (NSArray *)dataArray {
    // 检查是否开启精简模式
    BOOL simplifyPanel = DYYYGetBool(@"DYYYSimplifyLongPressPanel");

    NSArray *originalArray = %orig;
    if (!originalArray) {
        originalArray = @[];
    }

    // 如果开启精简模式，直接跳过原始面板处理，只返回自定义选项
    if (simplifyPanel) {
        originalArray = @[]; // 清空原始数组
    } else {
        // 获取需要隐藏的按钮设置（从文本输入框读取，逗号分隔）
        NSString *hidePanelItems = DYYYGetString(@"DYYYHidePanelItems");
        NSMutableSet<NSString *> *hideItemsLowerSet = [NSMutableSet set];

        if (hidePanelItems && hidePanelItems.length > 0) {
            // 支持中英文逗号分隔
            NSString *normalizedItems = [hidePanelItems stringByReplacingOccurrencesOfString:@"，" withString:@","];
            NSArray *items = [normalizedItems componentsSeparatedByString:@","];
            for (NSString *item in items) {
                NSString *trimmedItem = [item stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
                if (trimmedItem.length > 0) {
                    [hideItemsLowerSet addObject:[trimmedItem lowercaseString]];
                }
            }
        }

        // 如果有需要隐藏的项目，才进行过滤
        if (hideItemsLowerSet.count > 0) {
            NSMutableArray *modifiedOriginalGroups = [NSMutableArray array];

            for (id group in originalArray) {
                if ([group isKindOfClass:%c(AWELongPressPanelViewGroupModel)]) {
                    AWELongPressPanelViewGroupModel *groupModel = (AWELongPressPanelViewGroupModel *)group;
                    NSMutableArray *filteredGroupArr = [NSMutableArray array];

                    for (id item in groupModel.groupArr) {
                        if ([item isKindOfClass:%c(AWELongPressPanelBaseViewModel)]) {
                            AWELongPressPanelBaseViewModel *viewModel = (AWELongPressPanelBaseViewModel *)item;
                            NSString *descString = viewModel.describeString;

                            BOOL shouldHide = NO;
                            if (descString && descString.length > 0) {
                                NSString *descLower = [descString lowercaseString];

                                // 精确匹配
                                if ([hideItemsLowerSet containsObject:descLower]) {
                                    shouldHide = YES;
                                } else {
                                    // 部分匹配
                                    for (NSString *hideItemLower in hideItemsLowerSet) {
                                        if ([descLower containsString:hideItemLower] || [hideItemLower containsString:descLower]) {
                                            shouldHide = YES;
                                            break;
                                        }
                                    }
                                }
                            }

                            if (!shouldHide) {
                                [filteredGroupArr addObject:item];
                            }
                        } else {
                            [filteredGroupArr addObject:item];
                        }
                    }

                    if (filteredGroupArr.count > 0) {
                        AWELongPressPanelViewGroupModel *filteredGroup = [[%c(AWELongPressPanelViewGroupModel) alloc] init];
                        filteredGroup.groupType = groupModel.groupType;
                        filteredGroup.isModern = groupModel.isModern;
                        filteredGroup.groupArr = filteredGroupArr;
                        [modifiedOriginalGroups addObject:filteredGroup];
                    }
                } else {
                    [modifiedOriginalGroups addObject:group];
                }
            }
            originalArray = modifiedOriginalGroups;
        }
    }

    // 检查是否启用了任意长按功能
    BOOL hasAnyFeatureEnabled = NO;
    // 检查各个单独的功能开关
    BOOL enableSaveVideo = DYYYGetBool(@"DYYYLongPressSaveVideo");
    BOOL enableSaveCover = DYYYGetBool(@"DYYYLongPressSaveCover");
    BOOL enableSaveAudio = DYYYGetBool(@"DYYYLongPressSaveAudio");
    BOOL enableSaveCurrentImage = DYYYGetBool(@"DYYYLongPressSaveCurrentImage");
    BOOL enableSaveAllImages = DYYYGetBool(@"DYYYLongPressSaveAllImages");
    BOOL enableCopyText = DYYYGetBool(@"DYYYLongPressCopyText");
    BOOL enableCopyLink = DYYYGetBool(@"DYYYLongPressCopyLink");
    BOOL enableApiDownload = DYYYGetBool(@"DYYYLongPressApiDownload");
    BOOL enableFilterUser = DYYYGetBool(@"DYYYLongPressFilterUser");
    BOOL enableFilterKeyword = DYYYGetBool(@"DYYYLongPressFilterTitle");
    BOOL enableTimerClose = DYYYGetBool(@"DYYYLongPressTimerClose");
    BOOL enableCreateVideo = DYYYGetBool(@"DYYYLongPressCreateVideo");

    // 检查是否有任何功能启用
    hasAnyFeatureEnabled = enableSaveVideo || enableSaveCover || enableSaveAudio || enableSaveCurrentImage || enableSaveAllImages || enableCopyText || enableCopyLink || enableApiDownload ||
                           enableFilterUser || enableFilterKeyword || enableTimerClose || enableCreateVideo;

    // 如果没有任何功能启用，仅使用官方按钮
    if (!hasAnyFeatureEnabled) {
        return originalArray;
    }

    // 创建自定义功能按钮
    NSMutableArray *viewModels = [NSMutableArray array];

    BOOL isNewLivePhoto = (self.awemeModel.video && self.awemeModel.animatedImageVideoInfo != nil);

    // 视频下载功能 (非实况照片才显示)
    if (enableSaveVideo && self.awemeModel.awemeType != 68 && !isNewLivePhoto) {
        AWELongPressPanelBaseViewModel *downloadViewModel = [[%c(AWELongPressPanelBaseViewModel) alloc] init];
        downloadViewModel.awemeModel = self.awemeModel;
        downloadViewModel.actionType = 666;
        downloadViewModel.duxIconName = @"ic_boxarrowdownhigh_outlined";
        downloadViewModel.describeString = @"保存视频";
        downloadViewModel.action = ^{
          AWEAwemeModel *awemeModel = self.awemeModel;
          AWEVideoModel *videoModel = awemeModel.video;
          AWEMusicModel *musicModel = awemeModel.music;
          NSURL *audioURL = nil;
          if (musicModel && musicModel.playURL && musicModel.playURL.originURLList.count > 0) {
              audioURL = [NSURL URLWithString:musicModel.playURL.originURLList.firstObject];
          }

                  if (videoModel.h264URL && videoModel.h264URL.originURLList.count > 0) {
                      NSURL *url = [NSURL URLWithString:videoModel.h264URL.originURLList.firstObject];
                      [DYYYManager downloadMedia:url
                                       mediaType:MediaTypeVideo
                                           audio:audioURL
                                      completion:^(BOOL success){
                                      }];
                  }
              
          
          AWELongPressPanelManager *panelManager = [%c(AWELongPressPanelManager) shareInstance];
          [panelManager dismissWithAnimation:YES completion:nil];
        };
        [viewModels addObject:downloadViewModel];
    }

    //  新版实况照片保存
    if (enableSaveVideo && self.awemeModel.awemeType != 68 && isNewLivePhoto) {
        AWELongPressPanelBaseViewModel *livePhotoViewModel = [[%c(AWELongPressPanelBaseViewModel) alloc] init];
        livePhotoViewModel.awemeModel = self.awemeModel;
        livePhotoViewModel.actionType = 679;
        livePhotoViewModel.duxIconName = @"ic_boxarrowdownhigh_outlined";
        livePhotoViewModel.describeString = @"保存实况";
        livePhotoViewModel.action = ^{
          AWEAwemeModel *awemeModel = self.awemeModel;
          AWEVideoModel *videoModel = awemeModel.video;

          // 使用封面URL作为图片URL
          NSURL *imageURL = nil;
          if (videoModel.coverURL && videoModel.coverURL.originURLList.count > 0) {
              imageURL = [NSURL URLWithString:videoModel.coverURL.originURLList.firstObject];
          }

          // 视频URL从视频模型获取
          NSURL *videoURL = nil;
          if (videoModel && videoModel.playURL && videoModel.playURL.originURLList.count > 0) {
              videoURL = [NSURL URLWithString:videoModel.playURL.originURLList.firstObject];
          } else if (videoModel && videoModel.h264URL && videoModel.h264URL.originURLList.count > 0) {
              videoURL = [NSURL URLWithString:videoModel.h264URL.originURLList.firstObject];
          }

          // 下载实况照片
          if (imageURL && videoURL) {
              [DYYYManager downloadLivePhoto:imageURL
                                    videoURL:videoURL
                                  completion:^{
                                  }];
          }

          AWELongPressPanelManager *panelManager = [%c(AWELongPressPanelManager) shareInstance];
          [panelManager dismissWithAnimation:YES completion:nil];
        };
        [viewModels addObject:livePhotoViewModel];
    }

    // 当前图片/实况下载功能
    if (enableSaveCurrentImage && self.awemeModel.awemeType == 68 && self.awemeModel.albumImages.count > 0) {
        AWELongPressPanelBaseViewModel *imageViewModel = [[%c(AWELongPressPanelBaseViewModel) alloc] init];
        imageViewModel.awemeModel = self.awemeModel;
        imageViewModel.actionType = 669;
        imageViewModel.duxIconName = @"ic_boxarrowdownhigh_outlined";

        if (self.awemeModel.albumImages.count == 1) {
            imageViewModel.describeString = @"保存图片";
        } else {
            imageViewModel.describeString = @"保存当前图片";
        }

        AWEImageAlbumImageModel *currimge = self.awemeModel.albumImages[self.awemeModel.currentImageIndex - 1];
        if (currimge.clipVideo != nil || self.awemeModel.isLivePhoto) {
            if (self.awemeModel.albumImages.count == 1) {
                imageViewModel.describeString = @"保存实况";
            } else {
                imageViewModel.describeString = @"保存当前实况";
            }
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
                                       audio:nil
                                  completion:^(BOOL success) {
                                    if (success) {
                                    } else {
                                        [DYYYUtils showToast:@"图片保存已取消"];
                                    }
                                  }];
              } else {
                  [DYYYUtils showToast:@"没有找到合适格式的图片"];
              }
          }
          AWELongPressPanelManager *panelManager = [%c(AWELongPressPanelManager) shareInstance];
          [panelManager dismissWithAnimation:YES completion:nil];
        };
        [viewModels addObject:imageViewModel];
    }

    // 保存所有图片/实况功能
    if (enableSaveAllImages && self.awemeModel.awemeType == 68 && self.awemeModel.albumImages.count > 1) {
        AWELongPressPanelBaseViewModel *allImagesViewModel = [[%c(AWELongPressPanelBaseViewModel) alloc] init];
        allImagesViewModel.awemeModel = self.awemeModel;
        allImagesViewModel.actionType = 670;
        allImagesViewModel.duxIconName = @"ic_boxarrowdownhigh_outlined";
        allImagesViewModel.describeString = @"保存所有图片";
        // 检查是否有实况照片并更改按钮文字
        BOOL hasLivePhoto = NO;
        for (AWEImageAlbumImageModel *imageModel in self.awemeModel.albumImages) {
            if (imageModel.clipVideo != nil) {
                hasLivePhoto = YES;
                break;
            }
        }
        if (hasLivePhoto) {
            allImagesViewModel.describeString = @"保存所有实况";
        }
        allImagesViewModel.action = ^{
          AWEAwemeModel *awemeModel = self.awemeModel;
          NSMutableArray *imageURLs = [NSMutableArray array];
          NSMutableArray *livePhotos = [NSMutableArray array];

          for (AWEImageAlbumImageModel *imageModel in awemeModel.albumImages) {
              if (imageModel.urlList.count > 0) {
                  // 查找非.image后缀的URL
                  NSURL *downloadURL = nil;
                  for (NSString *urlString in imageModel.urlList) {
                      NSURL *url = [NSURL URLWithString:urlString];
                      NSString *pathExtension = [url.path.lowercaseString pathExtension];
                      if (![pathExtension isEqualToString:@"image"]) {
                          downloadURL = url;
                          break;
                      }
                  }

                  if (!downloadURL && imageModel.urlList.count > 0) {
                      downloadURL = [NSURL URLWithString:imageModel.urlList.firstObject];
                  }

                  // 检查是否是实况照片
                  if (imageModel.clipVideo != nil) {
                      NSURL *videoURL = [imageModel.clipVideo.playURL getDYYYSrcURLDownload];
                      [livePhotos addObject:@{@"imageURL" : downloadURL.absoluteString, @"videoURL" : videoURL.absoluteString}];
                  } else {
                      [imageURLs addObject:downloadURL.absoluteString];
                  }
              }
          }

          // 分别处理普通图片和实况照片
          if (livePhotos.count > 0) {
              [DYYYManager downloadAllLivePhotos:livePhotos];
          }

          if (imageURLs.count > 0) {
              [DYYYManager downloadAllImages:imageURLs];
          }

          if (livePhotos.count == 0 && imageURLs.count == 0) {
              [DYYYUtils showToast:@"没有找到合适格式的图片"];
          }

          AWELongPressPanelManager *panelManager = [%c(AWELongPressPanelManager) shareInstance];
          [panelManager dismissWithAnimation:YES completion:nil];
        };
        [viewModels addObject:allImagesViewModel];
    }

    // 接口保存功能
    NSString *apiKey = [[NSUserDefaults standardUserDefaults] objectForKey:@"DYYYInterfaceDownload"];
    if (enableApiDownload && apiKey.length > 0) {
        AWELongPressPanelBaseViewModel *apiDownload = [[%c(AWELongPressPanelBaseViewModel) alloc] init];
        apiDownload.awemeModel = self.awemeModel;
        apiDownload.actionType = 673;
        apiDownload.duxIconName = @"ic_cloudarrowdown_outlined_20";
        apiDownload.describeString = @"接口保存";
        apiDownload.action = ^{
          NSString *shareLink = [self.awemeModel valueForKey:@"shareURL"];
          if (shareLink.length == 0) {
              [DYYYUtils showToast:@"无法获取分享链接"];
              return;
          }
          // 使用封装的方法进行解析下载
          [DYYYManager parseAndDownloadVideoWithShareLink:shareLink apiKey:apiKey];
          AWELongPressPanelManager *panelManager = [%c(AWELongPressPanelManager) shareInstance];
          [panelManager dismissWithAnimation:YES completion:nil];
        };
        [viewModels addObject:apiDownload];
    }

    // 封面下载功能
    if (enableSaveCover && self.awemeModel.awemeType != 68) {
        AWELongPressPanelBaseViewModel *coverViewModel = [[%c(AWELongPressPanelBaseViewModel) alloc] init];
        coverViewModel.awemeModel = self.awemeModel;
        coverViewModel.actionType = 667;
        coverViewModel.duxIconName = @"ic_boxarrowdownhigh_outlined";
        coverViewModel.describeString = @"保存封面";
        coverViewModel.action = ^{
          AWEAwemeModel *awemeModel = self.awemeModel;
          AWEVideoModel *videoModel = awemeModel.video;
          if (videoModel && videoModel.coverURL && videoModel.coverURL.originURLList.count > 0) {
              NSURL *url = [NSURL URLWithString:videoModel.coverURL.originURLList.firstObject];
              [DYYYManager downloadMedia:url
                               mediaType:MediaTypeImage
                                   audio:nil
                              completion:^(BOOL success) {
                                if (success) {
                                } else {
                                    [DYYYUtils showToast:@"封面保存已取消"];
                                }
                              }];
          }
          AWELongPressPanelManager *panelManager = [%c(AWELongPressPanelManager) shareInstance];
          [panelManager dismissWithAnimation:YES completion:nil];
        };
        [viewModels addObject:coverViewModel];
    }

    // 音频下载功能
    if (enableSaveAudio) {
        AWELongPressPanelBaseViewModel *audioViewModel = [[%c(AWELongPressPanelBaseViewModel) alloc] init];
        audioViewModel.awemeModel = self.awemeModel;
        audioViewModel.actionType = 668;
        audioViewModel.duxIconName = @"ic_boxarrowdownhigh_outlined";
        audioViewModel.describeString = @"保存音频";
        audioViewModel.action = ^{
          AWEAwemeModel *awemeModel = self.awemeModel;
          AWEMusicModel *musicModel = awemeModel.music;
          if (musicModel && musicModel.playURL && musicModel.playURL.originURLList.count > 0) {
              NSURL *url = [NSURL URLWithString:musicModel.playURL.originURLList.firstObject];
              [DYYYManager downloadMedia:url mediaType:MediaTypeAudio audio:nil completion:nil];
          }
          AWELongPressPanelManager *panelManager = [%c(AWELongPressPanelManager) shareInstance];
          [panelManager dismissWithAnimation:YES completion:nil];
        };
        [viewModels addObject:audioViewModel];
    }

    // 创建视频功能
    if (enableCreateVideo && self.awemeModel.awemeType == 68) {
        AWELongPressPanelBaseViewModel *createVideoViewModel = [[%c(AWELongPressPanelBaseViewModel) alloc] init];
        createVideoViewModel.awemeModel = self.awemeModel;
        createVideoViewModel.actionType = 677;
        createVideoViewModel.duxIconName = @"ic_videosearch_outlined_20";
        createVideoViewModel.describeString = @"制作视频";
        createVideoViewModel.action = ^{
          AWEAwemeModel *awemeModel = self.awemeModel;

          // 收集普通图片URL
          NSMutableArray *imageURLs = [NSMutableArray array];
          // 收集实况照片信息（图片URL+视频URL）
          NSMutableArray *livePhotos = [NSMutableArray array];

          // 获取背景音乐URL
          NSString *bgmURL = nil;
          if (awemeModel.music && awemeModel.music.playURL && awemeModel.music.playURL.originURLList.count > 0) {
              bgmURL = awemeModel.music.playURL.originURLList.firstObject;
          }

          // 处理所有图片和实况
          for (AWEImageAlbumImageModel *imageModel in awemeModel.albumImages) {
              if (imageModel.urlList.count > 0) {
                  // 查找非.image后缀的URL
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

                  // 如果是实况照片，需要收集图片和视频URL
                  if (imageModel.clipVideo != nil) {
                      NSURL *videoURL = [imageModel.clipVideo.playURL getDYYYSrcURLDownload];
                      if (videoURL) {
                          [livePhotos addObject:@{@"imageURL" : bestURL, @"videoURL" : videoURL.absoluteString}];
                      }
                  } else {
                      // 普通图片
                      [imageURLs addObject:bestURL];
                  }
              }
          }

          // 调用视频创建API
          [DYYYManager createVideoFromMedia:imageURLs
              livePhotos:livePhotos
              bgmURL:bgmURL
              progress:^(NSInteger current, NSInteger total, NSString *status) {
              }
              completion:^(BOOL success, NSString *message) {
                if (success) {
                } else {
                    [DYYYUtils showToast:[NSString stringWithFormat:@"视频制作失败: %@", message]];
                }
              }];

          AWELongPressPanelManager *panelManager = [%c(AWELongPressPanelManager) shareInstance];
          [panelManager dismissWithAnimation:YES completion:nil];
        };
        [viewModels addObject:createVideoViewModel];
    }

    // 复制文案功能
    if (enableCopyText) {
        AWELongPressPanelBaseViewModel *copyText = [[%c(AWELongPressPanelBaseViewModel) alloc] init];
        copyText.awemeModel = self.awemeModel;
        copyText.actionType = 671;
        copyText.duxIconName = @"ic_xiaoxihuazhonghua_outlined";
        copyText.describeString = @"复制文案";
        copyText.action = ^{
          NSString *descText = [self.awemeModel valueForKey:@"descriptionString"];
          [[UIPasteboard generalPasteboard] setString:descText];
          [DYYYToast showSuccessToastWithMessage:@"文案已复制"];
          AWELongPressPanelManager *panelManager = [%c(AWELongPressPanelManager) shareInstance];
          [panelManager dismissWithAnimation:YES completion:nil];
        };
        [viewModels addObject:copyText];
    }

    // 复制分享链接功能
    if (enableCopyLink) {
        AWELongPressPanelBaseViewModel *copyShareLink = [[%c(AWELongPressPanelBaseViewModel) alloc] init];
        copyShareLink.awemeModel = self.awemeModel;
        copyShareLink.actionType = 672;
        copyShareLink.duxIconName = @"ic_share_outlined";
        copyShareLink.describeString = @"复制链接";
        copyShareLink.action = ^{
          NSString *shareLink = [self.awemeModel valueForKey:@"shareURL"];
          NSString *cleanedURL = cleanShareURL(shareLink);
          [[UIPasteboard generalPasteboard] setString:cleanedURL];
          [DYYYToast showSuccessToastWithMessage:@"分享链接已复制"];
          AWELongPressPanelManager *panelManager = [%c(AWELongPressPanelManager) shareInstance];
          [panelManager dismissWithAnimation:YES completion:nil];
        };
        [viewModels addObject:copyShareLink];
    }

    // 过滤用户功能
    if (enableFilterUser) {
        AWELongPressPanelBaseViewModel *filterKeywords = [[%c(AWELongPressPanelBaseViewModel) alloc] init];
        filterKeywords.awemeModel = self.awemeModel;
        filterKeywords.actionType = 674;
        filterKeywords.duxIconName = @"ic_userban_outlined_20";
        filterKeywords.describeString = @"过滤用户";
        filterKeywords.action = ^{
          AWEUserModel *author = self.awemeModel.author;
          NSString *nickname = author.nickname ?: @"未知用户";
          NSString *shortId = author.shortID ?: @"";
          // 创建当前用户的过滤格式 "nickname-shortid"
          NSString *currentUserFilter = [NSString stringWithFormat:@"%@-%@", nickname, shortId];
          // 获取保存的过滤用户列表
          NSString *savedUsers = [[NSUserDefaults standardUserDefaults] objectForKey:@"DYYYFilterUsers"] ?: @"";
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
          NSString *actionButtonText = userExists ? @"取消过滤" : @"添加过滤";
          [DYYYBottomAlertView showAlertWithTitle:@"过滤用户视频"
              message:[NSString stringWithFormat:@"用户: %@ (ID: %@)", nickname, shortId]
              avatarURL:nil
              cancelButtonText:@"管理过滤列表"
              confirmButtonText:actionButtonText
              cancelAction:^{
                DYYYKeywordListView *keywordListView = [[DYYYKeywordListView alloc] initWithTitle:@"过滤用户列表" keywords:userArray];
                keywordListView.onConfirm = ^(NSArray *users) {
                  NSString *userString = [users componentsJoinedByString:@","];
                  [[NSUserDefaults standardUserDefaults] setObject:userString forKey:@"DYYYFilterUsers"];
                  [DYYYUtils showToast:@"过滤用户列表已更新"];
                };
                [keywordListView show];
              }
              closeAction:nil
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
                    [DYYYUtils showToast:@"已从过滤列表中移除此用户"];
                } else {
                    // 添加用户
                    [updatedUsers addObject:currentUserFilter];
                    [DYYYUtils showToast:@"已添加此用户到过滤列表"];
                }
                // 保存更新后的列表
                NSString *updatedUserString = [updatedUsers componentsJoinedByString:@","];
                [[NSUserDefaults standardUserDefaults] setObject:updatedUserString forKey:@"DYYYFilterUsers"];
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
        filterKeywords.describeString = @"过滤文案";
        filterKeywords.action = ^{
          NSString *descText = [self.awemeModel valueForKey:@"descriptionString"];
          NSString *propName = nil;
          if (self.awemeModel.propGuideV2) {
              propName = self.awemeModel.propGuideV2.propName;
          }
          DYYYFilterSettingsView *filterView = [[DYYYFilterSettingsView alloc] initWithTitle:@"过滤关键词调整" text:descText propName:propName];
          filterView.onConfirm = ^(NSString *selectedText) {
            if (selectedText.length > 0) {
                NSString *currentKeywords = [[NSUserDefaults standardUserDefaults] objectForKey:@"DYYYFilterKeywords"] ?: @"";
                NSString *newKeywords;
                if (currentKeywords.length > 0) {
                    newKeywords = [NSString stringWithFormat:@"%@,%@", currentKeywords, selectedText];
                } else {
                    newKeywords = selectedText;
                }
                [[NSUserDefaults standardUserDefaults] setObject:newKeywords forKey:@"DYYYFilterKeywords"];
                [DYYYUtils showToast:[NSString stringWithFormat:@"已添加过滤词: %@", selectedText]];
            }
          };
          // 设置过滤关键词按钮回调
          filterView.onKeywordFilterTap = ^{
            // 获取保存的关键词
            NSString *savedKeywords = [[NSUserDefaults standardUserDefaults] objectForKey:@"DYYYFilterKeywords"] ?: @"";
            NSArray *keywordArray = [savedKeywords length] > 0 ? [savedKeywords componentsSeparatedByString:@","] : @[];
            // 创建并显示关键词列表视图
            DYYYKeywordListView *keywordListView = [[DYYYKeywordListView alloc] initWithTitle:@"设置过滤关键词" keywords:keywordArray];
            // 设置确认回调
            keywordListView.onConfirm = ^(NSArray *keywords) {
              // 将关键词数组转换为逗号分隔的字符串
              NSString *keywordString = [keywords componentsJoinedByString:@","];
              // 保存到用户默认设置
              [[NSUserDefaults standardUserDefaults] setObject:keywordString forKey:@"DYYYFilterKeywords"];
              // 显示提示
              [DYYYUtils showToast:@"过滤关键词已更新"];
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

    if (enableTimerClose) {
        AWELongPressPanelBaseViewModel *timerCloseViewModel = [[%c(AWELongPressPanelBaseViewModel) alloc] init];
        timerCloseViewModel.awemeModel = self.awemeModel;
        timerCloseViewModel.actionType = 676;
        timerCloseViewModel.duxIconName = @"ic_c_alarm_outlined";
        // 检查是否已有定时任务在运行
        NSNumber *shutdownTime = [[NSUserDefaults standardUserDefaults] objectForKey:@"DYYYTimerShutdownTime"];
        BOOL hasActiveTimer = shutdownTime != nil && [shutdownTime doubleValue] > [[NSDate date] timeIntervalSince1970];
        timerCloseViewModel.describeString = hasActiveTimer ? @"取消定时" : @"定时关闭";
        timerCloseViewModel.action = ^{
          AWELongPressPanelManager *panelManager = [%c(AWELongPressPanelManager) shareInstance];
          [panelManager dismissWithAnimation:YES completion:nil];
          NSNumber *shutdownTime = [[NSUserDefaults standardUserDefaults] objectForKey:@"DYYYTimerShutdownTime"];
          BOOL hasActiveTimer = shutdownTime != nil && [shutdownTime doubleValue] > [[NSDate date] timeIntervalSince1970];
          if (hasActiveTimer) {
              [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"DYYYTimerShutdownTime"];
              [DYYYUtils showToast:@"已取消定时关闭任务"];
              return;
          }
          // 读取上次设置的时间
          NSInteger defaultMinutes = [[NSUserDefaults standardUserDefaults] integerForKey:@"DYYYTimerCloseMinutes"];
          if (defaultMinutes <= 0) {
              defaultMinutes = 5;
          }
          NSString *defaultText = [NSString stringWithFormat:@"%ld", (long)defaultMinutes];
          DYYYCustomInputView *inputView = [[DYYYCustomInputView alloc] initWithTitle:@"设置定时关闭时间" defaultText:defaultText placeholder:@"请输入关闭时间(单位:分钟)"];
          inputView.onConfirm = ^(NSString *inputText) {
            NSInteger minutes = [inputText integerValue];
            if (minutes <= 0) {
                minutes = 5;
            }
            // 保存用户设置的时间以供下次使用
            [[NSUserDefaults standardUserDefaults] setInteger:minutes forKey:@"DYYYTimerCloseMinutes"];
            NSInteger seconds = minutes * 60;
            NSTimeInterval shutdownTimeValue = [[NSDate date] timeIntervalSince1970] + seconds;
            [[NSUserDefaults standardUserDefaults] setObject:@(shutdownTimeValue) forKey:@"DYYYTimerShutdownTime"];
            [DYYYUtils showToast:[NSString stringWithFormat:@"抖音将在%ld分钟后关闭...", (long)minutes]];
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(seconds * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
              NSNumber *currentShutdownTime = [[NSUserDefaults standardUserDefaults] objectForKey:@"DYYYTimerShutdownTime"];
              if (currentShutdownTime != nil && [currentShutdownTime doubleValue] <= [[NSDate date] timeIntervalSince1970]) {
                  [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"DYYYTimerShutdownTime"];
                  // 显示确认关闭弹窗，而不是直接退出
                  DYYYConfirmCloseView *confirmView = [[DYYYConfirmCloseView alloc] initWithTitle:@"定时关闭" message:@"定时关闭时间已到，是否关闭抖音？"];
                  [confirmView show];
              }
            });
          };
          [inputView show];
        };
        [viewModels addObject:timerCloseViewModel];
    }

    // 创建自定义组
    NSMutableArray *customGroups = [NSMutableArray array];
    NSInteger totalButtons = viewModels.count;

    // 根据按钮总数确定每行的按钮数
    NSInteger firstRowCount = 0;
    NSInteger secondRowCount = 0;

    // 确定分配方式与原代码相同
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

    // 创建第一行
    if (firstRowCount > 0) {
        NSArray<AWELongPressPanelBaseViewModel *> *firstRowButtons = [viewModels subarrayWithRange:NSMakeRange(0, firstRowCount)];
        AWELongPressPanelViewGroupModel *firstRowGroup = [[%c(AWELongPressPanelViewGroupModel) alloc] init];
        firstRowGroup.isDYYYCustomGroup = YES;
        firstRowGroup.groupType = (firstRowCount <= 3) ? 11 : 12;
        firstRowGroup.isModern = YES;
        firstRowGroup.groupArr = firstRowButtons;
        [customGroups addObject:firstRowGroup];
    }

    // 创建第二行
    if (secondRowCount > 0) {
        NSArray<AWELongPressPanelBaseViewModel *> *secondRowButtons = [viewModels subarrayWithRange:NSMakeRange(firstRowCount, secondRowCount)];
        AWELongPressPanelViewGroupModel *secondRowGroup = [[%c(AWELongPressPanelViewGroupModel) alloc] init];
        secondRowGroup.isDYYYCustomGroup = YES;
        secondRowGroup.groupType = (secondRowCount <= 3) ? 11 : 12;
        secondRowGroup.isModern = YES;
        secondRowGroup.groupArr = secondRowButtons;
        [customGroups addObject:secondRowGroup];
    }

    return [customGroups arrayByAddingObjectsFromArray:originalArray];
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

    // 检查是否开启精简模式
    BOOL simplifyPanel = DYYYGetBool(@"DYYYSimplifyLongPressPanel");

    // 如果开启精简模式，直接跳过原始面板处理，只返回自定义选项
    if (simplifyPanel) {
        originalArray = @[]; // 清空原始数组
    } else {
        // 获取需要隐藏的按钮设置（从文本输入框读取，逗号分隔）
        NSString *hidePanelItems = DYYYGetString(@"DYYYHidePanelItems");
        NSMutableSet<NSString *> *hideItemsLowerSet = [NSMutableSet set];

        if (hidePanelItems && hidePanelItems.length > 0) {
            // 支持中英文逗号分隔
            NSString *normalizedItems = [hidePanelItems stringByReplacingOccurrencesOfString:@"，" withString:@","];
            NSArray *items = [normalizedItems componentsSeparatedByString:@","];
            for (NSString *item in items) {
                NSString *trimmedItem = [item stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
                if (trimmedItem.length > 0) {
                    [hideItemsLowerSet addObject:[trimmedItem lowercaseString]];
                }
            }
        }

        // 如果有需要隐藏的项目，才进行过滤
        if (hideItemsLowerSet.count > 0) {
            NSMutableArray *modifiedOriginalGroups = [NSMutableArray array];

            for (id group in originalArray) {
                if ([group isKindOfClass:%c(AWELongPressPanelViewGroupModel)]) {
                    AWELongPressPanelViewGroupModel *groupModel = (AWELongPressPanelViewGroupModel *)group;
                    NSMutableArray *filteredGroupArr = [NSMutableArray array];

                    for (id item in groupModel.groupArr) {
                        if ([item isKindOfClass:%c(AWELongPressPanelBaseViewModel)]) {
                            AWELongPressPanelBaseViewModel *viewModel = (AWELongPressPanelBaseViewModel *)item;
                            NSString *descString = viewModel.describeString;

                            BOOL shouldHide = NO;
                            if (descString && descString.length > 0) {
                                NSString *descLower = [descString lowercaseString];

                                // 精确匹配
                                if ([hideItemsLowerSet containsObject:descLower]) {
                                    shouldHide = YES;
                                } else {
                                    // 部分匹配
                                    for (NSString *hideItemLower in hideItemsLowerSet) {
                                        if ([descLower containsString:hideItemLower] || [hideItemLower containsString:descLower]) {
                                            shouldHide = YES;
                                            break;
                                        }
                                    }
                                }
                            }

                            if (!shouldHide) {
                                [filteredGroupArr addObject:item];
                            }
                        } else {
                            [filteredGroupArr addObject:item];
                        }
                    }

                    if (filteredGroupArr.count > 0) {
                        AWELongPressPanelViewGroupModel *filteredGroup = [[%c(AWELongPressPanelViewGroupModel) alloc] init];
                        filteredGroup.groupType = groupModel.groupType;
                        filteredGroup.groupArr = filteredGroupArr;
                        [modifiedOriginalGroups addObject:filteredGroup];
                    }
                } else {
                    [modifiedOriginalGroups addObject:group];
                }
            }
            originalArray = modifiedOriginalGroups;
        }
    }

    // 检查是否启用了任意长按功能
    BOOL hasAnyFeatureEnabled = NO;

    // 检查各个单独的功能开关
    BOOL enableSaveVideo = DYYYGetBool(@"DYYYLongPressSaveVideo");
    BOOL enableSaveCover = DYYYGetBool(@"DYYYLongPressSaveCover");
    BOOL enableSaveAudio = DYYYGetBool(@"DYYYLongPressSaveAudio");
    BOOL enableSaveCurrentImage = DYYYGetBool(@"DYYYLongPressSaveCurrentImage");
    BOOL enableSaveAllImages = DYYYGetBool(@"DYYYLongPressSaveAllImages");
    BOOL enableCopyText = DYYYGetBool(@"DYYYLongPressCopyText");
    BOOL enableCopyLink = DYYYGetBool(@"DYYYLongPressCopyLink");
    BOOL enableApiDownload = DYYYGetBool(@"DYYYLongPressApiDownload");
    BOOL enableFilterUser = DYYYGetBool(@"DYYYLongPressFilterUser");
    BOOL enableFilterKeyword = DYYYGetBool(@"DYYYLongPressFilterTitle");
    BOOL enableTimerClose = DYYYGetBool(@"DYYYLongPressTimerClose");
    BOOL enableCreateVideo = DYYYGetBool(@"DYYYLongPressCreateVideo");

    // 检查是否有任何功能启用
    hasAnyFeatureEnabled = enableSaveVideo || enableSaveCover || enableSaveAudio || enableSaveCurrentImage || enableSaveAllImages || enableCopyText || enableCopyLink || enableApiDownload ||
                           enableFilterUser || enableFilterKeyword || enableTimerClose || enableCreateVideo;

    if (!hasAnyFeatureEnabled) {
        return originalArray;
    }

    // 创建自定义功能组
    AWELongPressPanelViewGroupModel *newGroupModel = [[%c(AWELongPressPanelViewGroupModel) alloc] init];
    newGroupModel.groupType = 0;
    NSMutableArray *viewModels = [NSMutableArray array];

    BOOL isNewLivePhoto = (self.awemeModel.video && self.awemeModel.animatedImageVideoInfo != nil);

    // 视频下载功能 (非实况照片才显示)
    if (enableSaveVideo && self.awemeModel.awemeType != 68 && !isNewLivePhoto) {
        AWELongPressPanelBaseViewModel *downloadViewModel = [[%c(AWELongPressPanelBaseViewModel) alloc] init];
        downloadViewModel.awemeModel = self.awemeModel;
        downloadViewModel.actionType = 666;
        downloadViewModel.duxIconName = @"ic_boxarrowdownhigh_outlined";
        downloadViewModel.describeString = @"保存视频";
        downloadViewModel.action = ^{
          AWEAwemeModel *awemeModel = self.awemeModel;
          AWEVideoModel *videoModel = awemeModel.video;
          AWEMusicModel *musicModel = awemeModel.music;
          NSURL *audioURL = nil;
          if (musicModel && musicModel.playURL && musicModel.playURL.originURLList.count > 0) {
              audioURL = [NSURL URLWithString:musicModel.playURL.originURLList.firstObject];
          }

                  // 备用方法：直接使用h264URL
                  if (videoModel.h264URL && videoModel.h264URL.originURLList.count > 0) {
                      NSURL *url = [NSURL URLWithString:videoModel.h264URL.originURLList.firstObject];
                      [DYYYManager downloadMedia:url
                                       mediaType:MediaTypeVideo
                                           audio:audioURL
                                      completion:^(BOOL success){
                                      }];
                  }
              
          
          AWELongPressPanelManager *panelManager = [%c(AWELongPressPanelManager) shareInstance];
          [panelManager dismissWithAnimation:YES completion:nil];
        };
        [viewModels addObject:downloadViewModel];
    }

    //  新版实况照片保存
    if (enableSaveVideo && self.awemeModel.awemeType != 68 && isNewLivePhoto) {
        AWELongPressPanelBaseViewModel *livePhotoViewModel = [[%c(AWELongPressPanelBaseViewModel) alloc] init];
        livePhotoViewModel.awemeModel = self.awemeModel;
        livePhotoViewModel.actionType = 679;
        livePhotoViewModel.duxIconName = @"ic_boxarrowdownhigh_outlined";
        livePhotoViewModel.describeString = @"保存实况";
        livePhotoViewModel.action = ^{
          AWEAwemeModel *awemeModel = self.awemeModel;
          AWEVideoModel *videoModel = awemeModel.video;

          // 使用封面URL作为图片URL
          NSURL *imageURL = nil;
          if (videoModel.coverURL && videoModel.coverURL.originURLList.count > 0) {
              imageURL = [NSURL URLWithString:videoModel.coverURL.originURLList.firstObject];
          }

          // 视频URL从视频模型获取
          NSURL *videoURL = nil;
          if (videoModel && videoModel.playURL && videoModel.playURL.originURLList.count > 0) {
              videoURL = [NSURL URLWithString:videoModel.playURL.originURLList.firstObject];
          } else if (videoModel && videoModel.h264URL && videoModel.h264URL.originURLList.count > 0) {
              videoURL = [NSURL URLWithString:videoModel.h264URL.originURLList.firstObject];
          }

          // 下载实况照片
          if (imageURL && videoURL) {
              [DYYYManager downloadLivePhoto:imageURL
                                    videoURL:videoURL
                                  completion:^{
                                  }];
          }

          AWELongPressPanelManager *panelManager = [%c(AWELongPressPanelManager) shareInstance];
          [panelManager dismissWithAnimation:YES completion:nil];
        };
        [viewModels addObject:livePhotoViewModel];
    }

    // 当前图片/实况下载功能
    if (enableSaveCurrentImage && self.awemeModel.awemeType == 68 && self.awemeModel.albumImages.count > 0) {
        AWELongPressPanelBaseViewModel *imageViewModel = [[%c(AWELongPressPanelBaseViewModel) alloc] init];
        imageViewModel.awemeModel = self.awemeModel;
        imageViewModel.actionType = 669;
        imageViewModel.duxIconName = @"ic_boxarrowdownhigh_outlined";

        if (self.awemeModel.albumImages.count == 1) {
            imageViewModel.describeString = @"保存图片";
        } else {
            imageViewModel.describeString = @"保存当前图片";
        }

        AWEImageAlbumImageModel *currimge = self.awemeModel.albumImages[self.awemeModel.currentImageIndex - 1];
        if (currimge.clipVideo != nil || self.awemeModel.isLivePhoto) {
            if (self.awemeModel.albumImages.count == 1) {
                imageViewModel.describeString = @"保存实况";
            } else {
                imageViewModel.describeString = @"保存当前实况";
            }
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
                                       audio:nil
                                  completion:^(BOOL success) {
                                    if (success) {
                                    } else {
                                        [DYYYUtils showToast:@"图片保存已取消"];
                                    }
                                  }];
              } else {
                  [DYYYUtils showToast:@"没有找到合适格式的图片"];
              }
          }
          AWELongPressPanelManager *panelManager = [%c(AWELongPressPanelManager) shareInstance];
          [panelManager dismissWithAnimation:YES completion:nil];
        };
        [viewModels addObject:imageViewModel];
    }

    // 保存所有图片/实况功能
    if (enableSaveAllImages && self.awemeModel.awemeType == 68 && self.awemeModel.albumImages.count > 1) {
        AWELongPressPanelBaseViewModel *allImagesViewModel = [[%c(AWELongPressPanelBaseViewModel) alloc] init];
        allImagesViewModel.awemeModel = self.awemeModel;
        allImagesViewModel.actionType = 670;
        allImagesViewModel.duxIconName = @"ic_boxarrowdownhigh_outlined";
        allImagesViewModel.describeString = @"保存所有图片";
        // 检查是否有实况照片并更改按钮文字
        BOOL hasLivePhoto = NO;
        for (AWEImageAlbumImageModel *imageModel in self.awemeModel.albumImages) {
            if (imageModel.clipVideo != nil) {
                hasLivePhoto = YES;
                break;
            }
        }
        if (hasLivePhoto) {
            allImagesViewModel.describeString = @"保存所有实况";
        }
        allImagesViewModel.action = ^{
          AWEAwemeModel *awemeModel = self.awemeModel;
          NSMutableArray *imageURLs = [NSMutableArray array];
          NSMutableArray *livePhotos = [NSMutableArray array];

          for (AWEImageAlbumImageModel *imageModel in awemeModel.albumImages) {
              if (imageModel.urlList.count > 0) {
                  // 查找非.image后缀的URL
                  NSURL *downloadURL = nil;
                  for (NSString *urlString in imageModel.urlList) {
                      NSURL *url = [NSURL URLWithString:urlString];
                      NSString *pathExtension = [url.path.lowercaseString pathExtension];
                      if (![pathExtension isEqualToString:@"image"]) {
                          downloadURL = url;
                          break;
                      }
                  }

                  if (!downloadURL && imageModel.urlList.count > 0) {
                      downloadURL = [NSURL URLWithString:imageModel.urlList.firstObject];
                  }

                  // 检查是否是实况照片
                  if (imageModel.clipVideo != nil) {
                      NSURL *videoURL = [imageModel.clipVideo.playURL getDYYYSrcURLDownload];
                      [livePhotos addObject:@{@"imageURL" : downloadURL.absoluteString, @"videoURL" : videoURL.absoluteString}];
                  } else {
                      [imageURLs addObject:downloadURL.absoluteString];
                  }
              }
          }

          // 分别处理普通图片和实况照片
          if (livePhotos.count > 0) {
              [DYYYManager downloadAllLivePhotos:livePhotos];
          }

          if (imageURLs.count > 0) {
              [DYYYManager downloadAllImages:imageURLs];
          }

          if (livePhotos.count == 0 && imageURLs.count == 0) {
              [DYYYUtils showToast:@"没有找到合适格式的图片"];
          }

          AWELongPressPanelManager *panelManager = [%c(AWELongPressPanelManager) shareInstance];
          [panelManager dismissWithAnimation:YES completion:nil];
        };
        [viewModels addObject:allImagesViewModel];
    }

    // 接口保存功能
    NSString *apiKey = [[NSUserDefaults standardUserDefaults] objectForKey:@"DYYYInterfaceDownload"];
    if (enableApiDownload && apiKey.length > 0) {
        AWELongPressPanelBaseViewModel *apiDownload = [[%c(AWELongPressPanelBaseViewModel) alloc] init];
        apiDownload.awemeModel = self.awemeModel;
        apiDownload.actionType = 673;
        apiDownload.duxIconName = @"ic_cloudarrowdown_outlined_20";
        apiDownload.describeString = @"接口保存";
        apiDownload.action = ^{
          NSString *shareLink = [self.awemeModel valueForKey:@"shareURL"];
          if (shareLink.length == 0) {
              [DYYYUtils showToast:@"无法获取分享链接"];
              return;
          }
          // 使用封装的方法进行解析下载
          [DYYYManager parseAndDownloadVideoWithShareLink:shareLink apiKey:apiKey];
          AWELongPressPanelManager *panelManager = [%c(AWELongPressPanelManager) shareInstance];
          [panelManager dismissWithAnimation:YES completion:nil];
        };
        [viewModels addObject:apiDownload];
    }

    // 封面下载功能
    if (enableSaveCover && self.awemeModel.awemeType != 68) {
        AWELongPressPanelBaseViewModel *coverViewModel = [[%c(AWELongPressPanelBaseViewModel) alloc] init];
        coverViewModel.awemeModel = self.awemeModel;
        coverViewModel.actionType = 667;
        coverViewModel.duxIconName = @"ic_boxarrowdownhigh_outlined";
        coverViewModel.describeString = @"保存封面";
        coverViewModel.action = ^{
          AWEAwemeModel *awemeModel = self.awemeModel;
          AWEVideoModel *videoModel = awemeModel.video;
          if (videoModel && videoModel.coverURL && videoModel.coverURL.originURLList.count > 0) {
              NSURL *url = [NSURL URLWithString:videoModel.coverURL.originURLList.firstObject];
              [DYYYManager downloadMedia:url
                               mediaType:MediaTypeImage
                                   audio:nil
                              completion:^(BOOL success) {
                                if (success) {
                                } else {
                                    [DYYYUtils showToast:@"封面保存已取消"];
                                }
                              }];
          }
          AWELongPressPanelManager *panelManager = [%c(AWELongPressPanelManager) shareInstance];
          [panelManager dismissWithAnimation:YES completion:nil];
        };
        [viewModels addObject:coverViewModel];
    }

    // 音频下载功能
    if (enableSaveAudio) {
        AWELongPressPanelBaseViewModel *audioViewModel = [[%c(AWELongPressPanelBaseViewModel) alloc] init];
        audioViewModel.awemeModel = self.awemeModel;
        audioViewModel.actionType = 668;
        audioViewModel.duxIconName = @"ic_boxarrowdownhigh_outlined";
        audioViewModel.describeString = @"保存音频";
        audioViewModel.action = ^{
          AWEAwemeModel *awemeModel = self.awemeModel;
          AWEMusicModel *musicModel = awemeModel.music;
          if (musicModel && musicModel.playURL && musicModel.playURL.originURLList.count > 0) {
              NSURL *url = [NSURL URLWithString:musicModel.playURL.originURLList.firstObject];
              [DYYYManager downloadMedia:url mediaType:MediaTypeAudio audio:nil completion:nil];
          }
          AWELongPressPanelManager *panelManager = [%c(AWELongPressPanelManager) shareInstance];
          [panelManager dismissWithAnimation:YES completion:nil];
        };
        [viewModels addObject:audioViewModel];
    }

    // 创建视频功能
    if (enableCreateVideo && self.awemeModel.awemeType == 68) {
        AWELongPressPanelBaseViewModel *createVideoViewModel = [[%c(AWELongPressPanelBaseViewModel) alloc] init];
        createVideoViewModel.awemeModel = self.awemeModel;
        createVideoViewModel.actionType = 677;
        createVideoViewModel.duxIconName = @"ic_videosearch_outlined_20";
        createVideoViewModel.describeString = @"制作视频";
        createVideoViewModel.action = ^{
          AWEAwemeModel *awemeModel = self.awemeModel;

          // 收集普通图片URL
          NSMutableArray *imageURLs = [NSMutableArray array];
          // 收集实况照片信息（图片URL+视频URL）
          NSMutableArray *livePhotos = [NSMutableArray array];

          // 获取背景音乐URL
          NSString *bgmURL = nil;
          if (awemeModel.music && awemeModel.music.playURL && awemeModel.music.playURL.originURLList.count > 0) {
              bgmURL = awemeModel.music.playURL.originURLList.firstObject;
          }

          // 处理所有图片和实况
          for (AWEImageAlbumImageModel *imageModel in awemeModel.albumImages) {
              if (imageModel.urlList.count > 0) {
                  // 查找非.image后缀的URL
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

                  // 如果是实况照片，需要收集图片和视频URL
                  if (imageModel.clipVideo != nil) {
                      NSURL *videoURL = [imageModel.clipVideo.playURL getDYYYSrcURLDownload];
                      if (videoURL) {
                          [livePhotos addObject:@{@"imageURL" : bestURL, @"videoURL" : videoURL.absoluteString}];
                      }
                  } else {
                      // 普通图片
                      [imageURLs addObject:bestURL];
                  }
              }
          }

          // 调用视频创建API
          [DYYYManager createVideoFromMedia:imageURLs
              livePhotos:livePhotos
              bgmURL:bgmURL
              progress:^(NSInteger current, NSInteger total, NSString *status) {
              }
              completion:^(BOOL success, NSString *message) {
                if (success) {
                } else {
                    [DYYYUtils showToast:[NSString stringWithFormat:@"视频制作失败: %@", message]];
                }
              }];

          AWELongPressPanelManager *panelManager = [%c(AWELongPressPanelManager) shareInstance];
          [panelManager dismissWithAnimation:YES completion:nil];
        };
        [viewModels addObject:createVideoViewModel];
    }

    // 复制文案功能
    if (enableCopyText) {
        AWELongPressPanelBaseViewModel *copyText = [[%c(AWELongPressPanelBaseViewModel) alloc] init];
        copyText.awemeModel = self.awemeModel;
        copyText.actionType = 671;
        copyText.duxIconName = @"ic_xiaoxihuazhonghua_outlined";
        copyText.describeString = @"复制文案";
        copyText.action = ^{
          NSString *descText = [self.awemeModel valueForKey:@"descriptionString"];
          [[UIPasteboard generalPasteboard] setString:descText];
          [DYYYToast showSuccessToastWithMessage:@"文案已复制"];
          AWELongPressPanelManager *panelManager = [%c(AWELongPressPanelManager) shareInstance];
          [panelManager dismissWithAnimation:YES completion:nil];
        };
        [viewModels addObject:copyText];
    }

    // 复制分享链接功能
    if (enableCopyLink) {
        AWELongPressPanelBaseViewModel *copyShareLink = [[%c(AWELongPressPanelBaseViewModel) alloc] init];
        copyShareLink.awemeModel = self.awemeModel;
        copyShareLink.actionType = 672;
        copyShareLink.duxIconName = @"ic_share_outlined";
        copyShareLink.describeString = @"复制链接";
        copyShareLink.action = ^{
          NSString *shareLink = [self.awemeModel valueForKey:@"shareURL"];
          NSString *cleanedURL = cleanShareURL(shareLink);
          [[UIPasteboard generalPasteboard] setString:cleanedURL];
          [DYYYToast showSuccessToastWithMessage:@"分享链接已复制"];
          AWELongPressPanelManager *panelManager = [%c(AWELongPressPanelManager) shareInstance];
          [panelManager dismissWithAnimation:YES completion:nil];
        };
        [viewModels addObject:copyShareLink];
    }

    // 过滤用户功能
    if (enableFilterUser) {
        AWELongPressPanelBaseViewModel *filterKeywords = [[%c(AWELongPressPanelBaseViewModel) alloc] init];
        filterKeywords.awemeModel = self.awemeModel;
        filterKeywords.actionType = 674;
        filterKeywords.duxIconName = @"ic_userban_outlined_20";
        filterKeywords.describeString = @"过滤用户";
        filterKeywords.action = ^{
          AWEUserModel *author = self.awemeModel.author;
          NSString *nickname = author.nickname ?: @"未知用户";
          NSString *shortId = author.shortID ?: @"";
          // 创建当前用户的过滤格式 "nickname-shortid"
          NSString *currentUserFilter = [NSString stringWithFormat:@"%@-%@", nickname, shortId];
          // 获取保存的过滤用户列表
          NSString *savedUsers = [[NSUserDefaults standardUserDefaults] objectForKey:@"DYYYFilterUsers"] ?: @"";
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
          NSString *actionButtonText = userExists ? @"取消过滤" : @"添加过滤";
          [DYYYBottomAlertView showAlertWithTitle:@"过滤用户视频"
              message:[NSString stringWithFormat:@"用户: %@ (ID: %@)", nickname, shortId]
              avatarURL:nil
              cancelButtonText:@"管理过滤列表"
              confirmButtonText:actionButtonText
              cancelAction:^{
                DYYYKeywordListView *keywordListView = [[DYYYKeywordListView alloc] initWithTitle:@"过滤用户列表" keywords:userArray];
                keywordListView.onConfirm = ^(NSArray *users) {
                  NSString *userString = [users componentsJoinedByString:@","];
                  [[NSUserDefaults standardUserDefaults] setObject:userString forKey:@"DYYYFilterUsers"];
                  [DYYYUtils showToast:@"过滤用户列表已更新"];
                };
                [keywordListView show];
              }
              closeAction:nil
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
                    [DYYYUtils showToast:@"已从过滤列表中移除此用户"];
                } else {
                    // 添加用户
                    [updatedUsers addObject:currentUserFilter];
                    [DYYYUtils showToast:@"已添加此用户到过滤列表"];
                }
                // 保存更新后的列表
                NSString *updatedUserString = [updatedUsers componentsJoinedByString:@","];
                [[NSUserDefaults standardUserDefaults] setObject:updatedUserString forKey:@"DYYYFilterUsers"];
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
        filterKeywords.describeString = @"过滤文案";
        filterKeywords.action = ^{
          NSString *descText = [self.awemeModel valueForKey:@"descriptionString"];
          NSString *propName = nil;
          if (self.awemeModel.propGuideV2) {
              propName = self.awemeModel.propGuideV2.propName;
          }
          DYYYFilterSettingsView *filterView = [[DYYYFilterSettingsView alloc] initWithTitle:@"过滤关键词调整" text:descText propName:propName];
          filterView.onConfirm = ^(NSString *selectedText) {
            if (selectedText.length > 0) {
                NSString *currentKeywords = [[NSUserDefaults standardUserDefaults] objectForKey:@"DYYYFilterKeywords"] ?: @"";
                NSString *newKeywords;
                if (currentKeywords.length > 0) {
                    newKeywords = [NSString stringWithFormat:@"%@,%@", currentKeywords, selectedText];
                } else {
                    newKeywords = selectedText;
                }
                [[NSUserDefaults standardUserDefaults] setObject:newKeywords forKey:@"DYYYFilterKeywords"];
                [DYYYUtils showToast:[NSString stringWithFormat:@"已添加过滤词: %@", selectedText]];
            }
          };
          // 设置过滤关键词按钮回调
          filterView.onKeywordFilterTap = ^{
            // 获取保存的关键词
            NSString *savedKeywords = [[NSUserDefaults standardUserDefaults] objectForKey:@"DYYYFilterKeywords"] ?: @"";
            NSArray *keywordArray = [savedKeywords length] > 0 ? [savedKeywords componentsSeparatedByString:@","] : @[];
            // 创建并显示关键词列表视图
            DYYYKeywordListView *keywordListView = [[DYYYKeywordListView alloc] initWithTitle:@"设置过滤关键词" keywords:keywordArray];
            // 设置确认回调
            keywordListView.onConfirm = ^(NSArray *keywords) {
              // 将关键词数组转换为逗号分隔的字符串
              NSString *keywordString = [keywords componentsJoinedByString:@","];
              // 保存到用户默认设置
              [[NSUserDefaults standardUserDefaults] setObject:keywordString forKey:@"DYYYFilterKeywords"];
              // 显示提示
              [DYYYUtils showToast:@"过滤关键词已更新"];
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

    if (enableTimerClose) {
        AWELongPressPanelBaseViewModel *timerCloseViewModel = [[%c(AWELongPressPanelBaseViewModel) alloc] init];
        timerCloseViewModel.awemeModel = self.awemeModel;
        timerCloseViewModel.actionType = 676;
        timerCloseViewModel.duxIconName = @"ic_c_alarm_outlined";
        // 检查是否已有定时任务在运行
        NSNumber *shutdownTime = [[NSUserDefaults standardUserDefaults] objectForKey:@"DYYYTimerShutdownTime"];
        BOOL hasActiveTimer = shutdownTime != nil && [shutdownTime doubleValue] > [[NSDate date] timeIntervalSince1970];
        timerCloseViewModel.describeString = hasActiveTimer ? @"取消定时" : @"定时关闭";
        timerCloseViewModel.action = ^{
          AWELongPressPanelManager *panelManager = [%c(AWELongPressPanelManager) shareInstance];
          [panelManager dismissWithAnimation:YES completion:nil];
          NSNumber *shutdownTime = [[NSUserDefaults standardUserDefaults] objectForKey:@"DYYYTimerShutdownTime"];
          BOOL hasActiveTimer = shutdownTime != nil && [shutdownTime doubleValue] > [[NSDate date] timeIntervalSince1970];
          if (hasActiveTimer) {
              [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"DYYYTimerShutdownTime"];
              [DYYYUtils showToast:@"已取消定时关闭任务"];
              return;
          }
          // 读取上次设置的时间
          NSInteger defaultMinutes = [[NSUserDefaults standardUserDefaults] integerForKey:@"DYYYTimerCloseMinutes"];
          if (defaultMinutes <= 0) {
              defaultMinutes = 5;
          }
          NSString *defaultText = [NSString stringWithFormat:@"%ld", (long)defaultMinutes];
          DYYYCustomInputView *inputView = [[DYYYCustomInputView alloc] initWithTitle:@"设置定时关闭时间" defaultText:defaultText placeholder:@"请输入关闭时间(单位:分钟)"];
          inputView.onConfirm = ^(NSString *inputText) {
            NSInteger minutes = [inputText integerValue];
            if (minutes <= 0) {
                minutes = 5;
            }
            // 保存用户设置的时间以供下次使用
            [[NSUserDefaults standardUserDefaults] setInteger:minutes forKey:@"DYYYTimerCloseMinutes"];
            NSInteger seconds = minutes * 60;
            NSTimeInterval shutdownTimeValue = [[NSDate date] timeIntervalSince1970] + seconds;
            [[NSUserDefaults standardUserDefaults] setObject:@(shutdownTimeValue) forKey:@"DYYYTimerShutdownTime"];
            [DYYYUtils showToast:[NSString stringWithFormat:@"抖音将在%ld分钟后关闭...", (long)minutes]];
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(seconds * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
              NSNumber *currentShutdownTime = [[NSUserDefaults standardUserDefaults] objectForKey:@"DYYYTimerShutdownTime"];
              if (currentShutdownTime != nil && [currentShutdownTime doubleValue] <= [[NSDate date] timeIntervalSince1970]) {
                  [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"DYYYTimerShutdownTime"];
                  // 显示确认关闭弹窗，而不是直接退出
                  DYYYConfirmCloseView *confirmView = [[DYYYConfirmCloseView alloc] initWithTitle:@"定时关闭" message:@"定时关闭时间已到，是否关闭抖音？"];
                  [confirmView show];
              }
            });
          };
          [inputView show];
        };
        [viewModels addObject:timerCloseViewModel];
    }

    newGroupModel.groupArr = viewModels;

    // 返回自定义组+原始组的结果
    if (originalArray.count > 0) {
        NSMutableArray *resultArray = [originalArray mutableCopy];
        [resultArray insertObject:newGroupModel atIndex:0];
        return [resultArray copy];
    } else {
        return @[ newGroupModel ];
    }
}
%end

// 隐藏评论分享功能

typedef void (*DYYYCommentLongPressSetModelsArrayIMP)(id, SEL, id);

static NSMutableDictionary<NSString *, NSValue *> *DYYYCommentLongPressOriginalSetModelsArrayIMPs(void) {
    static NSMutableDictionary<NSString *, NSValue *> *imps = nil;
    if (!imps) {
        imps = [NSMutableDictionary dictionary];
    }
    return imps;
}

static BOOL DYYYCommentLongPressSettingEnabled(NSString *key) {
    return [[NSUserDefaults standardUserDefaults] boolForKey:key];
}

static BOOL DYYYCommentLongPressAnyHideSettingEnabled(void) {
    return DYYYCommentLongPressSettingEnabled(@"DYYYHideCommentShareToFriends") ||
           DYYYCommentLongPressSettingEnabled(@"DYYYHideCommentLongPressCopy") ||
           DYYYCommentLongPressSettingEnabled(@"DYYYHideCommentLongPressSaveImage") ||
           DYYYCommentLongPressSettingEnabled(@"DYYYHideCommentLongPressReport") ||
           DYYYCommentLongPressSettingEnabled(@"DYYYHideCommentLongPressSearch") ||
           DYYYCommentLongPressSettingEnabled(@"DYYYHideCommentLongPressDaily") ||
           DYYYCommentLongPressSettingEnabled(@"DYYYHideCommentLongPressVideoReply") ||
           DYYYCommentLongPressSettingEnabled(@"DYYYHideCommentLongPressPictureSearch");
}

static void DYYYCommentLongPressAddSignal(NSMutableArray<NSString *> *signals, id value) {
    if (!value || value == (id)kCFNull) {
        return;
    }

    NSString *signal = nil;
    if ([value isKindOfClass:[NSString class]]) {
        signal = (NSString *)value;
    } else if ([value isKindOfClass:[NSAttributedString class]]) {
        signal = [(NSAttributedString *)value string];
    } else if ([value respondsToSelector:@selector(stringValue)]) {
        signal = [value stringValue];
    }

    if (signal.length > 0) {
        [signals addObject:signal.lowercaseString];
    }
}

static id DYYYCommentLongPressObjectValueForSelector(id object, SEL selector) {
    if (!object || ![object respondsToSelector:selector]) {
        return nil;
    }

    Method method = class_getInstanceMethod([object class], selector);
    if (!method) {
        return nil;
    }

    char returnType[16] = {0};
    method_getReturnType(method, returnType, sizeof(returnType));
    if (returnType[0] != '@') {
        return nil;
    }

    @try {
        return ((id (*)(id, SEL))objc_msgSend)(object, selector);
    } @catch (__unused NSException *exception) {
        return nil;
    }
}

static NSString *DYYYCommentLongPressSelectorValueForSelector(id object, SEL selector) {
    if (!object || ![object respondsToSelector:selector]) {
        return nil;
    }

    Method method = class_getInstanceMethod([object class], selector);
    if (!method) {
        return nil;
    }

    char returnType[16] = {0};
    method_getReturnType(method, returnType, sizeof(returnType));
    if (returnType[0] != ':') {
        return nil;
    }

    @try {
        SEL value = ((SEL (*)(id, SEL))objc_msgSend)(object, selector);
        return value ? NSStringFromSelector(value) : nil;
    } @catch (__unused NSException *exception) {
        return nil;
    }
}

static NSArray<NSString *> *DYYYCommentLongPressSignalsForItem(id item) {
    NSMutableArray<NSString *> *signals = [NSMutableArray array];
    DYYYCommentLongPressAddSignal(signals, NSStringFromClass([item class]));

    NSArray<NSString *> *objectSelectors = @[
        @"title",
        @"itemTitle",
        @"panelTitle",
        @"displayTitle",
        @"describeString",
        @"descString",
        @"text",
        @"labelText",
        @"name",
        @"identifier",
        @"elementIdentifier",
        @"actionName",
        @"type"
    ];

    for (NSString *selectorName in objectSelectors) {
        DYYYCommentLongPressAddSignal(signals, DYYYCommentLongPressObjectValueForSelector(item, NSSelectorFromString(selectorName)));
    }

    NSArray<NSString *> *selectorSelectors = @[
        @"selector",
        @"actionSelector",
        @"tapSelector",
        @"clickSelector",
        @"eventSelector"
    ];

    for (NSString *selectorName in selectorSelectors) {
        DYYYCommentLongPressAddSignal(signals, DYYYCommentLongPressSelectorValueForSelector(item, NSSelectorFromString(selectorName)));
    }

    NSArray<NSString *> *kvcKeys = @[
        @"title",
        @"itemTitle",
        @"panelTitle",
        @"displayTitle",
        @"describeString",
        @"text",
        @"labelText",
        @"name",
        @"identifier",
        @"elementIdentifier",
        @"actionName"
    ];

    for (NSString *key in kvcKeys) {
        @try {
            DYYYCommentLongPressAddSignal(signals, [item valueForKey:key]);
        } @catch (__unused NSException *exception) {
        }
    }

    return signals;
}

static BOOL DYYYCommentLongPressSignalMatches(NSString *signal, NSArray<NSString *> *includeTokens, NSArray<NSString *> *excludeTokens) {
    if (signal.length == 0) {
        return NO;
    }

    for (NSString *exclude in excludeTokens) {
        if (exclude.length > 0 && [signal containsString:exclude.lowercaseString]) {
            return NO;
        }
    }

    for (NSString *include in includeTokens) {
        if (include.length > 0 && [signal containsString:include.lowercaseString]) {
            return YES;
        }
    }

    return NO;
}

static BOOL DYYYCommentLongPressSignalsMatch(NSArray<NSString *> *signals, NSArray<NSString *> *includeTokens, NSArray<NSString *> *excludeTokens) {
    for (NSString *signal in signals) {
        if (DYYYCommentLongPressSignalMatches(signal, includeTokens, excludeTokens)) {
            return YES;
        }
    }
    return NO;
}

static BOOL DYYYCommentLongPressClassHasSelectorMatch(id item, NSArray<NSString *> *includeTokens, NSArray<NSString *> *excludeTokens) {
    for (Class cls = [item class]; cls && cls != [NSObject class]; cls = class_getSuperclass(cls)) {
        unsigned int methodCount = 0;
        Method *methods = class_copyMethodList(cls, &methodCount);
        if (!methods) {
            continue;
        }

        BOOL matched = NO;
        for (unsigned int i = 0; i < methodCount; i++) {
            NSString *selectorName = NSStringFromSelector(method_getName(methods[i])).lowercaseString;
            if (DYYYCommentLongPressSignalMatches(selectorName, includeTokens, excludeTokens)) {
                matched = YES;
                break;
            }
        }

        free(methods);
        if (matched) {
            return YES;
        }
    }

    return NO;
}

static BOOL DYYYCommentLongPressItemMatches(id item, NSArray<NSString *> *signals, NSArray<NSString *> *signalTokens, NSArray<NSString *> *selectorTokens, NSArray<NSString *> *excludeTokens) {
    return DYYYCommentLongPressSignalsMatch(signals, signalTokens, excludeTokens) ||
           DYYYCommentLongPressClassHasSelectorMatch(item, selectorTokens, excludeTokens);
}

static BOOL DYYYCommentLongPressShouldFilterItem(id item) {
    NSArray<NSString *> *signals = DYYYCommentLongPressSignalsForItem(item);

    if (DYYYCommentLongPressSettingEnabled(@"DYYYHideCommentShareToFriends") &&
        DYYYCommentLongPressItemMatches(item,
                                        signals,
                                        @[@"privatemessage", @"shareuser", @"sharetofriend", @"sendtofriend", @"分享给朋友", @"发给朋友", @"好友", @"私信"],
                                        @[@"privatemessage", @"shareuser", @"sharetofriend", @"sendtofriend", @"sendmessage", @"share"],
                                        @[@"daily", @"moment", @"日常", @"转发日常"])) {
        return YES;
    }

    if (DYYYCommentLongPressSettingEnabled(@"DYYYHideCommentLongPressCopy") &&
        DYYYCommentLongPressItemMatches(item,
                                        signals,
                                        @[@"copyelement", @"copy", @"复制"],
                                        @[@"copycomment", @"copytext", @"copycontent", @"copyaction", @"copyelement", @"performcopy", @"handlcopy", @"handlecopy", @"didtapcopy"],
                                        @[@"copywithzone", @"mutablecopy"])) {
        return YES;
    }

    if (DYYYCommentLongPressSettingEnabled(@"DYYYHideCommentLongPressSaveImage") &&
        DYYYCommentLongPressItemMatches(item,
                                        signals,
                                        @[@"saveimage", @"savephoto", @"save_image", @"保存图片", @"保存"],
                                        @[@"saveimage", @"savephoto", @"downloadimage", @"saveaction", @"handlesave", @"didtapsave"],
                                        @[@"picturesearch", @"imagesearch", @"识别图片", @"搜图"])) {
        return YES;
    }

    if (DYYYCommentLongPressSettingEnabled(@"DYYYHideCommentLongPressReport") &&
        DYYYCommentLongPressItemMatches(item,
                                        signals,
                                        @[@"reportelement", @"report", @"举报"],
                                        @[@"reportcomment", @"reportaction", @"handlereport", @"didtapreport"],
                                        @[])) {
        return YES;
    }

    if (DYYYCommentLongPressSettingEnabled(@"DYYYHideCommentLongPressDaily") &&
        DYYYCommentLongPressItemMatches(item,
                                        signals,
                                        @[@"forwardelement", @"forwarddaily", @"publishdaily", @"daily", @"moment", @"转发日常", @"发日常", @"日常"],
                                        @[@"forwarddaily", @"publishdaily", @"dailyaction", @"handledaily", @"forwardaction"],
                                        @[@"privatemessage", @"sharetofriend", @"分享给朋友", @"好友", @"私信"])) {
        return YES;
    }

    if (DYYYCommentLongPressSettingEnabled(@"DYYYHideCommentLongPressVideoReply") &&
        DYYYCommentLongPressItemMatches(item,
                                        signals,
                                        @[@"videoreply", @"video_reply", @"视频回复"],
                                        @[@"videoreply", @"replywithvideo", @"handlevideoreply"],
                                        @[])) {
        return YES;
    }

    if (DYYYCommentLongPressSettingEnabled(@"DYYYHideCommentLongPressPictureSearch") &&
        DYYYCommentLongPressItemMatches(item,
                                        signals,
                                        @[@"picturesearch", @"imagesearch", @"photosearch", @"searchpicture", @"searchimage", @"identifyimage", @"recognizeimage", @"识别图片", @"图片搜索", @"搜图"],
                                        @[@"picturesearch", @"imagesearch", @"photosearch", @"searchpicture", @"searchimage", @"identifyimage", @"recognizeimage"],
                                        @[])) {
        return YES;
    }

    if (DYYYCommentLongPressSettingEnabled(@"DYYYHideCommentLongPressSearch") &&
        DYYYCommentLongPressItemMatches(item,
                                        signals,
                                        @[@"searchelement", @"search", @"搜索"],
                                        @[@"searchcomment", @"searchaction", @"handlesearch", @"didtapsearch", @"gosearch"],
                                        @[@"picturesearch", @"imagesearch", @"photosearch", @"searchpicture", @"searchimage", @"identifyimage", @"recognizeimage", @"识别图片", @"图片", @"搜图"])) {
        return YES;
    }

    return NO;
}

static NSArray *DYYYCommentLongPressFilteredModelsArray(NSArray *inputArray) {
    if (!DYYYCommentLongPressAnyHideSettingEnabled()) {
        return inputArray;
    }

    NSMutableArray *filteredArray = nil;
    for (id item in inputArray) {
        if (DYYYCommentLongPressShouldFilterItem(item)) {
            if (!filteredArray) {
                filteredArray = [NSMutableArray arrayWithCapacity:inputArray.count];
                for (id keepItem in inputArray) {
                    if (keepItem == item) {
                        break;
                    }
                    [filteredArray addObject:keepItem];
                }
            }
            continue;
        }

        if (filteredArray) {
            [filteredArray addObject:item];
        }
    }

    return filteredArray ? [filteredArray copy] : inputArray;
}

static DYYYCommentLongPressSetModelsArrayIMP DYYYCommentLongPressOriginalSetModelsArrayIMPForObject(id object) {
    NSMutableDictionary<NSString *, NSValue *> *imps = DYYYCommentLongPressOriginalSetModelsArrayIMPs();
    for (Class cls = object_getClass(object); cls; cls = class_getSuperclass(cls)) {
        NSValue *value = imps[NSStringFromClass(cls)];
        if (value) {
            return (DYYYCommentLongPressSetModelsArrayIMP)[value pointerValue];
        }
    }
    return NULL;
}

static void DYYYCommentLongPressSetModelsArray(id self, SEL _cmd, id arg1) {
    DYYYCommentLongPressSetModelsArrayIMP original = DYYYCommentLongPressOriginalSetModelsArrayIMPForObject(self);
    if (!original) {
        return;
    }

    if (![arg1 isKindOfClass:[NSArray class]]) {
        original(self, _cmd, arg1);
        return;
    }

    original(self, _cmd, DYYYCommentLongPressFilteredModelsArray((NSArray *)arg1));
}

static void DYYYHookCommentLongPressOwnerClass(Class ownerClass, NSMutableSet<NSString *> *hookedClasses) {
    if (!ownerClass || ![ownerClass instancesRespondToSelector:@selector(setModelsArray:)]) {
        return;
    }

    NSString *className = NSStringFromClass(ownerClass);
    if ([hookedClasses containsObject:className]) {
        return;
    }

    DYYYCommentLongPressSetModelsArrayIMP original = NULL;
    MSHookMessageEx(ownerClass, @selector(setModelsArray:), (IMP)DYYYCommentLongPressSetModelsArray, (IMP *)&original);
    if (original) {
        DYYYCommentLongPressOriginalSetModelsArrayIMPs()[className] = [NSValue valueWithPointer:(const void *)original];
        [hookedClasses addObject:className];
    }
}

static void DYYYHookCommentLongPressOwnerClassNamed(NSString *className, NSMutableSet<NSString *> *hookedClasses) {
    Class ownerClass = objc_getClass(className.UTF8String);
    DYYYHookCommentLongPressOwnerClass(ownerClass, hookedClasses);
}

static void DYYYInitCommentLongPressSetModelsHooks(void) {
    NSMutableSet<NSString *> *hookedClasses = [NSMutableSet set];
    NSArray<NSString *> *candidateOwnerClasses = @[
        @"AWECommentLongPressPanelSwiftImpl.CommentLongPressPanelNormalSectionViewModel",
        @"AWECommentLongPressPanelSwiftImpl.CommentLongPressPanelHorizonSectionViewModel",
        @"AWECommentLongPressPanelSwiftImpl.CommentLongPressPanelFooterSectionViewModel",
        @"AWECommentLongPressPanelSwiftImpl.CommentLongPressPanelCollectionViewModel",
        @"AWECommentLongPressPanelSwiftImpl.AWECommentLongPressPanelListViewModel",
        @"AWECommentLongPressPanelSwiftImpl.CommentLongPressPanelHorizonModel",
        @"_TtC33AWECommentLongPressPanelSwiftImpl43CommentLongPressPanelNormalSectionViewModel",
        @"_TtC33AWECommentLongPressPanelSwiftImpl44CommentLongPressPanelHorizonSectionViewModel",
        @"_TtC33AWECommentLongPressPanelSwiftImpl43CommentLongPressPanelFooterSectionViewModel",
        @"_TtC33AWECommentLongPressPanelSwiftImpl40CommentLongPressPanelCollectionViewModel",
        @"_TtC33AWECommentLongPressPanelSwiftImpl37AWECommentLongPressPanelListViewModel",
        @"_TtC33AWECommentLongPressPanelSwiftImpl33CommentLongPressPanelHorizonModel"
    ];

    for (NSString *className in candidateOwnerClasses) {
        DYYYHookCommentLongPressOwnerClassNamed(className, hookedClasses);
    }
}

%hook AWEIMCommentShareUserHorizontalCollectionViewCell

- (void)layoutSubviews {
    %orig;

    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYHideCommentShareToFriends"]) {
        self.hidden = YES;
    } else {
        self.hidden = NO;
    }
}

%end

%hook AWEIMCommentShareUserHorizontalSectionController

- (CGSize)sizeForItemAtIndex:(NSInteger)index model:(id)model collectionViewSize:(CGSize)size {
    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYHideCommentShareToFriends"]) {
        return CGSizeZero;
    }
    return %orig;
}

- (void)configCell:(id)cell index:(NSInteger)index model:(id)model {
    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYHideCommentShareToFriends"]) {
        return;
    }
    %orig;
}

%end

%ctor {
    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYUserAgreementAccepted"]) {
        %init;
    }
}

%ctor {
    DYYYInitCommentLongPressSetModelsHooks();
}
