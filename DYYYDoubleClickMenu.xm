#import "AwemeHeaders.h"
#import "DYYYManager.h"
#import "DYYYToast.h"

%hook AWEPlayInteractionViewController

- (void)onPlayer:(id)arg0 didDoubleClick:(id)arg1 {
	BOOL isPopupEnabled = [[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYEnableDoubleOpenAlertController"];
	BOOL isDirectCommentEnabled = [[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYEnableDoubleOpenComment"];

	// 直接打开评论区的情况
	if (isDirectCommentEnabled) {
		[self performCommentAction];
		return;
	}

	// 显示弹窗的情况
	if (isPopupEnabled) {
		// 获取当前视频模型
		AWEAwemeModel *awemeModel = nil;

		// 尝试通过可能的方法/属性获取模型
		if ([self respondsToSelector:@selector(awemeModel)]) {
			awemeModel = [self performSelector:@selector(awemeModel)];
		} else if ([self respondsToSelector:@selector(currentAwemeModel)]) {
			awemeModel = [self performSelector:@selector(currentAwemeModel)];
		} else if ([self respondsToSelector:@selector(getAwemeModel)]) {
			awemeModel = [self performSelector:@selector(getAwemeModel)];
		}

		// 如果仍然无法获取模型，尝试从视图控制器获取
		if (!awemeModel) {
			UIViewController *baseVC = [self valueForKey:@"awemeBaseViewController"];
			if (baseVC && [baseVC respondsToSelector:@selector(model)]) {
				awemeModel = [baseVC performSelector:@selector(model)];
			} else if (baseVC && [baseVC respondsToSelector:@selector(awemeModel)]) {
				awemeModel = [baseVC performSelector:@selector(awemeModel)];
			}
		}

		// 如果无法获取模型，执行默认行为并返回
		if (!awemeModel) {
			%orig;
			return;
		}

		AWEVideoModel *videoModel = awemeModel.video;
		AWEMusicModel *musicModel = awemeModel.music;

		// 确定内容类型（视频或图片）
		BOOL isImageContent = (awemeModel.awemeType == 68);
		NSString *downloadTitle = isImageContent ? @"儲存圖片" : @"儲存影片";

		// 创建AWEUserActionSheetView
		AWEUserActionSheetView *actionSheet = [[NSClassFromString(@"AWEUserActionSheetView") alloc] init];
		NSMutableArray *actions = [NSMutableArray array];

		// 添加下载选项
		if ([[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYDoubleTapDownload"] || ![[NSUserDefaults standardUserDefaults] objectForKey:@"DYYYDoubleTapDownload"]) {

			AWEUserSheetAction *downloadAction = [NSClassFromString(@"AWEUserSheetAction")
			    actionWithTitle:downloadTitle
				    imgName:nil
				    handler:^{
				      if (isImageContent) {
					      // 图片内容
					      AWEImageAlbumImageModel *currentImageModel = nil;
					      if (awemeModel.currentImageIndex > 0 && awemeModel.currentImageIndex <= awemeModel.albumImages.count) {
						      currentImageModel = awemeModel.albumImages[awemeModel.currentImageIndex - 1];
					      } else {
						      currentImageModel = awemeModel.albumImages.firstObject;
					      }

					      if (currentImageModel && currentImageModel.urlList.count > 0) {
						      NSURL *url = [NSURL URLWithString:currentImageModel.urlList.firstObject];
						      [DYYYManager downloadMedia:url
								       mediaType:MediaTypeImage
								      completion:^(BOOL success){
								      }];
					      }
				      } else {
					      // 视频内容
					      if (videoModel && videoModel.h264URL && videoModel.h264URL.originURLList.count > 0) {
						      NSURL *url = [NSURL URLWithString:videoModel.h264URL.originURLList.firstObject];
						      [DYYYManager downloadMedia:url
								       mediaType:MediaTypeVideo
								      completion:^(BOOL success){
								      }];
					      }
				      }
				    }];
			[actions addObject:downloadAction];

			// 添加保存封面选项
			if (!isImageContent) { // 仅视频内容显示保存封面选项
				AWEUserSheetAction *saveCoverAction = [NSClassFromString(@"AWEUserSheetAction")
				    actionWithTitle:@"儲存封面"
					    imgName:nil
					    handler:^{
					      AWEVideoModel *videoModel = awemeModel.video;
					      if (videoModel && videoModel.coverURL && videoModel.coverURL.originURLList.count > 0) {
						      NSURL *coverURL = [NSURL URLWithString:videoModel.coverURL.originURLList.firstObject];
						      [DYYYManager downloadMedia:coverURL
								       mediaType:MediaTypeImage
								      completion:^(BOOL success){
								      }];
					      }
					    }];
				[actions addObject:saveCoverAction];
			}

			// 如果是图集，添加下载所有图片选项
			if (isImageContent && awemeModel.albumImages.count > 1) {
				AWEUserSheetAction *downloadAllAction = [NSClassFromString(@"AWEUserSheetAction") actionWithTitle:@"儲存所有圖片"
															  imgName:nil
															  handler:^{
															    NSMutableArray *imageURLs = [NSMutableArray array];
															    for (AWEImageAlbumImageModel *imageModel in awemeModel.albumImages) {
																    if (imageModel.urlList.count > 0) {
																	    [imageURLs addObject:imageModel.urlList.firstObject];
																    }
															    }
															    [DYYYManager downloadAllImages:imageURLs];
															  }];
				[actions addObject:downloadAllAction];
			}
		}

		// 添加下载音频选项
		if ([[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYDoubleTapDownloadAudio"] || ![[NSUserDefaults standardUserDefaults] objectForKey:@"DYYYDoubleTapDownloadAudio"]) {

			AWEUserSheetAction *downloadAudioAction = [NSClassFromString(@"AWEUserSheetAction")
			    actionWithTitle:@"儲存音訊"
				    imgName:nil
				    handler:^{
				      if (musicModel && musicModel.playURL && musicModel.playURL.originURLList.count > 0) {
					      NSURL *url = [NSURL URLWithString:musicModel.playURL.originURLList.firstObject];
					      [DYYYManager downloadMedia:url mediaType:MediaTypeAudio completion:nil];
				      }
				    }];
			[actions addObject:downloadAudioAction];
		}

		// 添加接口保存选项
		if ([[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYDoubleInterfaceDownload"]) {
			NSString *apiKey = [[NSUserDefaults standardUserDefaults] objectForKey:@"DYYYInterfaceDownload"];
			if (apiKey.length > 0) {
				AWEUserSheetAction *apiDownloadAction = [NSClassFromString(@"AWEUserSheetAction") actionWithTitle:@"接口儲存"
															  imgName:nil
															  handler:^{
															    NSString *shareLink = [awemeModel valueForKey:@"shareURL"];
															    if (shareLink.length == 0) {
																    [DYYYManager showToast:@"無法取得分享連結"];
																    return;
															    }

															    // 使用封装的方法进行解析下载
															    [DYYYManager parseAndDownloadVideoWithShareLink:shareLink apiKey:apiKey];
															  }];
				[actions addObject:apiDownloadAction];
			}
		}

		// 添加制作视频功能
		if ([[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYDoubleCreateVideo"] || ![[NSUserDefaults standardUserDefaults] objectForKey:@"DYYYDoubleCreateVideo"]) {
			// 仅对图集且包含多张图片的内容显示此选项
			if (isImageContent && awemeModel.albumImages.count > 1) {
				AWEUserSheetAction *createVideoAction = [NSClassFromString(@"AWEUserSheetAction")
				    actionWithTitle:@"製作影片"
					    imgName:nil
					    handler:^{
					      // 收集普通图片URL
					      NSMutableArray *imageURLs = [NSMutableArray array];
					      // 收集实况照片信息（图片URL+视频URL）
					      NSMutableArray *livePhotos = [NSMutableArray array];

					      // 获取背景音乐URL
					      NSString *bgmURL = nil;
					      if (musicModel && musicModel.playURL && musicModel.playURL.originURLList.count > 0) {
						      bgmURL = musicModel.playURL.originURLList.firstObject;
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
							    [DYYYManager showToast:[NSString stringWithFormat:@"影片製作失敗: %@", message]];
						    }
						  }];
					    }];
				[actions addObject:createVideoAction];
			}
		}

		// 添加复制文案选项
		if ([[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYDoubleTapCopyDesc"] || ![[NSUserDefaults standardUserDefaults] objectForKey:@"DYYYDoubleTapCopyDesc"]) {

			AWEUserSheetAction *copyTextAction = [NSClassFromString(@"AWEUserSheetAction") actionWithTitle:@"複製文案"
													       imgName:nil
													       handler:^{
														 NSString *descText = [awemeModel valueForKey:@"descriptionString"];
														 [[UIPasteboard generalPasteboard] setString:descText];
														 [DYYYToast showSuccessToastWithMessage:@"文案已複製"];
													       }];
			[actions addObject:copyTextAction];
		}

		// 添加打开评论区选项
		if ([[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYDoubleTapComment"] || ![[NSUserDefaults standardUserDefaults] objectForKey:@"DYYYDoubleTapComment"]) {

			AWEUserSheetAction *openCommentAction = [NSClassFromString(@"AWEUserSheetAction") actionWithTitle:@"開啟評論"
														  imgName:nil
														  handler:^{
														    [self performCommentAction];
														  }];
			[actions addObject:openCommentAction];
		}

		// 添加分享选项
		if ([[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYDoubleTapshowSharePanel"] || ![[NSUserDefaults standardUserDefaults] objectForKey:@"DYYYDoubleTapshowSharePanel"]) {

			AWEUserSheetAction *showSharePanel = [NSClassFromString(@"AWEUserSheetAction") actionWithTitle:@"分享影片"
													       imgName:nil
													       handler:^{
														 [self showSharePanel]; // 执行分享操作
													       }];
			[actions addObject:showSharePanel];
		}

		// 添加点赞视频选项
		if ([[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYDoubleTapLike"] || ![[NSUserDefaults standardUserDefaults] objectForKey:@"DYYYDoubleTapLike"]) {

			AWEUserSheetAction *likeAction = [NSClassFromString(@"AWEUserSheetAction") actionWithTitle:@"按讚影片"
													   imgName:nil
													   handler:^{
													     [self performLikeAction]; // 执行点赞操作
													   }];
			[actions addObject:likeAction];
		}

		// 添加长按面板
		if ([[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYDoubleTapshowDislikeOnVideo"] || ![[NSUserDefaults standardUserDefaults] objectForKey:@"DYYYDoubleTapshowDislikeOnVideo"]) {

			AWEUserSheetAction *showDislikeOnVideo = [NSClassFromString(@"AWEUserSheetAction") actionWithTitle:@"長按面板"
														   imgName:nil
														   handler:^{
														     [self showDislikeOnVideo]; // 执行长按面板操作
														   }];
			[actions addObject:showDislikeOnVideo];
		}

		// 显示操作表
		[actionSheet setActions:actions];
		[actionSheet show];

		return;
	}

	// 默认行为
	%orig;
}

%end

%ctor {
	if ([[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYUserAgreementAccepted"]) {
		%init;
	}
}
