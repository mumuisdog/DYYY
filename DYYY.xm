//
//  DYYY
//
//  Copyright (c) 2024 huami. All rights reserved.
//  Channel: @huamidev
//  Created on: 2024/10/04
//
#import <UIKit/UIKit.h>
#import <objc/runtime.h>

#import "AwemeHeaders.h"
#import "CityManager.h"
#import "DYYYBottomAlertView.h"
#import "DYYYManager.h"

#import "DYYYConstants.h"
#import "DYYYFloatClearButton.h"
#import "DYYYFloatSpeedButton.h"
#import "DYYYSettingViewController.h"
#import "DYYYToast.h"
#import "DYYYUtils.h"

// 关闭不可见水印
%hook AWEHPChannelInvisibleWaterMarkModel

- (BOOL)isEnter {
    return NO;
}

- (BOOL)isAppear {
    return NO;
}

%end

// 长按复制个人简介
%hook AWEProfileMentionLabel

- (void)layoutSubviews {
    %orig;

    if (!DYYYGetBool(@"DYYYBioCopyText")) {
        return;
    }

    BOOL hasLongPressGesture = NO;
    for (UIGestureRecognizer *gesture in self.gestureRecognizers) {
        if ([gesture isKindOfClass:[UILongPressGestureRecognizer class]]) {
            hasLongPressGesture = YES;
            break;
        }
    }

    if (!hasLongPressGesture) {
        UILongPressGestureRecognizer *longPressGesture = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(handleLongPress:)];
        longPressGesture.minimumPressDuration = 0.5;
        [self addGestureRecognizer:longPressGesture];
        self.userInteractionEnabled = YES;
    }
}

%new
- (void)handleLongPress:(UILongPressGestureRecognizer *)gesture {
    if (gesture.state == UIGestureRecognizerStateBegan) {
        NSString *bioText = self.text;
        if (bioText && bioText.length > 0) {
            [[UIPasteboard generalPasteboard] setString:bioText];
            [DYYYToast showSuccessToastWithMessage:@"個人簡介已複製"];
        }
    }
}

%end

// 默认视频流最高画质
%hook AWEVideoModel

- (AWEURLModel *)playURL {
    if (!DYYYGetBool(@"DYYYEnableVideoHighestQuality")) {
        return %orig;
    }

    // 获取比特率模型数组
    NSArray *bitrateModels = [self bitrateModels];
    if (!bitrateModels || bitrateModels.count == 0) {
        return %orig;
    }

    // 查找比特率最高的模型
    id highestBitrateModel = nil;
    NSInteger highestBitrate = 0;

    for (id model in bitrateModels) {
        NSInteger bitrate = 0;
        BOOL validModel = NO;

        if ([model isKindOfClass:NSClassFromString(@"AWEVideoBSModel")]) {
            id bitrateValue = [model bitrate];
            if (bitrateValue) {
                bitrate = [bitrateValue integerValue];
                validModel = YES;
            }
        }

        if (validModel && bitrate > highestBitrate) {
            highestBitrate = bitrate;
            highestBitrateModel = model;
        }
    }

    // 如果找到了最高比特率模型，获取其播放地址
    if (highestBitrateModel) {
        id playAddr = [highestBitrateModel valueForKey:@"playAddr"];
        if (playAddr && [playAddr isKindOfClass:%c(AWEURLModel)]) {
            return playAddr;
        }
    }

    return %orig;
}

- (NSArray *)bitrateModels {

    NSArray *originalModels = %orig;

    if (!DYYYGetBool(@"DYYYEnableVideoHighestQuality")) {
        return originalModels;
    }

    if (originalModels.count == 0) {
        return originalModels;
    }

    // 查找比特率最高的模型
    id highestBitrateModel = nil;
    NSInteger highestBitrate = 0;

    for (id model in originalModels) {

        NSInteger bitrate = 0;
        BOOL validModel = NO;

        if ([model isKindOfClass:NSClassFromString(@"AWEVideoBSModel")]) {
            id bitrateValue = [model bitrate];
            if (bitrateValue) {
                bitrate = [bitrateValue integerValue];
                validModel = YES;
            }
        }

        if (validModel) {
            if (bitrate > highestBitrate) {
                highestBitrate = bitrate;
                highestBitrateModel = model;
            }
        }
    }

    if (highestBitrateModel) {
        return @[ highestBitrateModel ];
    }

    return originalModels;
}

%end

// 禁用自动进入直播间
%hook AWELiveGuideElement

- (BOOL)enableAutoEnterRoom {
    if (DYYYGetBool(@"DYYYDisableAutoEnterLive")) {
        return NO;
    }
    return %orig;
}

- (BOOL)enableNewAutoEnter {
    if (DYYYGetBool(@"DYYYDisableAutoEnterLive")) {
        return NO;
    }
    return %orig;
}

%end

%hook AWEFeedChannelManager

- (void)reloadChannelWithChannelModels:(id)arg1 currentChannelIDList:(id)arg2 reloadType:(id)arg3 selectedChannelID:(id)arg4 {
    NSArray *channelModels = arg1;
    NSMutableArray *newChannelModels = [NSMutableArray array];
    NSArray *currentChannelIDList = arg2;
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSMutableArray *newCurrentChannelIDList = [NSMutableArray arrayWithArray:currentChannelIDList];
    NSString *hideOtherChannels = [defaults objectForKey:@"DYYYHideOtherChannel"] ?: @"";
    NSArray *hideChannelKeywords = [hideOtherChannels componentsSeparatedByString:@","];
    if (!arg1 || !arg2) {
        %orig(arg1, arg2, arg3, arg4);
        return;
    }

    if (![channelModels isKindOfClass:[NSArray class]] || ![currentChannelIDList isKindOfClass:[NSArray class]]) {
        %orig(arg1, arg2, arg3, arg4);
        return;
    }

    if (channelModels.count == 0) {
        %orig(arg1, arg2, arg3, arg4);
        return;
    }

    for (AWEHPTopTabItemModel *tabItemModel in channelModels) {
        NSString *channelID = tabItemModel.channelID;
        NSString *newChannelTitle = tabItemModel.title;
        NSString *oldChannelTitle = tabItemModel.channelTitle;
        BOOL isHideChannel = NO;

        if ([channelID isEqualToString:@"homepage_hot_container"]) {
            isHideChannel = [defaults boolForKey:@"DYYYHideHotContainer"];
        } else if ([channelID isEqualToString:@"homepage_follow"]) {
            isHideChannel = [defaults boolForKey:@"DYYYHideFollow"];
        } else if ([channelID isEqualToString:@"homepage_mediumvideo"]) {
            isHideChannel = [defaults boolForKey:@"DYYYHideMediumVideo"];
        } else if ([channelID isEqualToString:@"homepage_mall"]) {
            isHideChannel = [defaults boolForKey:@"DYYYHideMall"];
        } else if ([channelID isEqualToString:@"homepage_nearby"]) {
            isHideChannel = [defaults boolForKey:@"DYYYHideNearby"];
        } else if ([channelID isEqualToString:@"homepage_groupon"]) {
            isHideChannel = [defaults boolForKey:@"DYYYHideGroupon"];
        } else if ([channelID isEqualToString:@"homepage_tablive"]) {
            isHideChannel = [defaults boolForKey:@"DYYYHideTabLive"];
        } else if ([channelID isEqualToString:@"homepage_pad_hot"]) {
            isHideChannel = [defaults boolForKey:@"DYYYHidePadHot"];
        } else if ([channelID isEqualToString:@"homepage_hangout"]) {
            isHideChannel = [defaults boolForKey:@"DYYYHideHangout"];
        } else if ([channelID isEqualToString:@"homepage_familiar"]) {
            isHideChannel = [defaults boolForKey:@"DYYYHideFriend"];
        } else if ([channelID isEqualToString:@"homepage_playlet_stream"]) {
            isHideChannel = [defaults boolForKey:@"DYYYHidePlaylet"];
        } else if ([channelID isEqualToString:@"homepage_pad_cinema"]) {
            isHideChannel = [defaults boolForKey:@"DYYYHideCinema"];
        } else if ([channelID isEqualToString:@"homepage_pad_kids_v2"]) {
            isHideChannel = [defaults boolForKey:@"DYYYHideKidsV2"];
        } else if ([channelID isEqualToString:@"homepage_pad_game"]) {
            isHideChannel = [defaults boolForKey:@"DYYYHideGame"];
        }
        if (oldChannelTitle.length > 0 || newChannelTitle.length > 0) {
            for (NSString *keyword in hideChannelKeywords) {
                if (keyword.length > 0 && ([oldChannelTitle containsString:keyword] || [newChannelTitle containsString:keyword])) {
                    isHideChannel = YES;
                }
            }
        }
        if (!isHideChannel) {
            [newChannelModels addObject:tabItemModel];
        } else {
            [newCurrentChannelIDList removeObject:channelID];
        }
    }

    %orig(newChannelModels, newCurrentChannelIDList, arg3, arg4);
}

%end

%hook AWELandscapeFeedViewController
- (void)viewDidLoad {
    %orig;

    // 尝试优先走属性
    gFeedCV = self.collectionView;

    // 保险起见再fallback,遍历 subviews
    if (!gFeedCV) {
        gFeedCV = [DYYYUtils findSubviewOfClass:[UICollectionView class] inView:self.view];
    }
}
%end

%hook UICollectionView

// 拦截手指拖动
- (void)handlePan:(UIPanGestureRecognizer *)pan {

    /* 仅处理横屏Feed列表。其余collectionView直接走系统逻辑 */
    if (self != gFeedCV || !DYYYGetBool(@"DYYYVideoGesture")) {
        %orig;
        return;
    }

    /* 取触点坐标、手势状态 */
    CGPoint loc = [pan locationInView:self];
    CGFloat w = self.bounds.size.width;
    CGFloat xPct = loc.x / w; // 0.0 ~ 1.0
    UIGestureRecognizerState st = pan.state;

    /* BEGAN：判定左右 20 % 区域 → 进入亮度 / 音量模式 */
    if (st == UIGestureRecognizerStateBegan) {

        gStartY = loc.y;

        if (xPct <= 0.20) { // 左边缘 → 亮度
            gMode = DYEdgeModeBrightness;
            gStartVal = [UIScreen mainScreen].brightness;

        } else if (xPct >= 0.80) { // 右边缘 → 音量
            gMode = DYEdgeModeVolume;
            gStartVal = [[objc_getClass("AVSystemController") sharedAVSystemController] volumeForCategory:@"Audio/Video"];

        } else {
            gMode = DYEdgeModeNone; // 中间区域走原逻辑
        }
    }

    /* 调节阶段：左右边缘时吞掉滚动、修改亮度/音量 */
    if (gMode != DYEdgeModeNone) {

        if (st == UIGestureRecognizerStateChanged) {

            CGFloat delta = (gStartY - loc.y) / self.bounds.size.height; // ↑ 为正
            const CGFloat kScale = 2.0;                                  // 灵敏度
            float newVal = gStartVal + delta * kScale;
            newVal = fminf(fmaxf(newVal, 0.0), 1.0); // Clamp 0~1

            if (gMode == DYEdgeModeBrightness) {
                [UIScreen mainScreen].brightness = newVal;
                // 弹系统亮度 HUD
                [[%c(SBHUDController) sharedInstance] presentHUDWithIcon:@"Brightness" level:newVal];

            } else { // DYEdgeModeVolume
                // iOS 18 音量控制 + 系统音量 HUD
                [[objc_getClass("AVSystemController") sharedAVSystemController] setVolumeTo:newVal forCategory:@"Audio/Video"];
            }

            // 吞掉滚动：归零 translation，防止内容位移
            [pan setTranslation:CGPointZero inView:self];
        }

        /* 结束／取消：状态复位 */
        if (st == UIGestureRecognizerStateEnded || st == UIGestureRecognizerStateCancelled || st == UIGestureRecognizerStateFailed) {
            gMode = DYEdgeModeNone;
        }

        return; // 左右边缘：彻底阻断 %orig，避免翻页
    }

    /* 中间区域：直接执行原先翻页逻辑 */
    %orig;
}

%end

%hook AWELeftSideBarAddChildTransitionObject

- (void)handleShowSliderPanGesture:(id)gr {
    if (DYYYGetBool(@"DYYYDisableSidebarGesture")) {
        return;
    }
    %orig(gr);
}

%end

%hook AWEPlayInteractionUserAvatarElement
- (void)onFollowViewClicked:(UITapGestureRecognizer *)gesture {
    if (DYYYGetBool(@"DYYYFollowTips")) {
        // 获取用户信息
        AWEUserModel *author = nil;
        NSString *nickname = @"";
        NSString *signature = @"";
        NSString *avatarURL = @"";

        if ([self respondsToSelector:@selector(model)]) {
            id model = [self model];
            if ([model isKindOfClass:NSClassFromString(@"AWEAwemeModel")]) {
                author = [model valueForKey:@"author"];
            }
        }

        if (author) {
            // 获取昵称
            if ([author respondsToSelector:@selector(nickname)]) {
                nickname = [author valueForKey:@"nickname"] ?: @"";
            }

            // 获取签名
            if ([author respondsToSelector:@selector(signature)]) {
                signature = [author valueForKey:@"signature"] ?: @"";
            }

            // 获取头像URL
            if ([author respondsToSelector:@selector(avatarThumb)]) {
                AWEURLModel *avatarThumb = [author valueForKey:@"avatarThumb"];
                if (avatarThumb && avatarThumb.originURLList.count > 0) {
                    avatarURL = avatarThumb.originURLList.firstObject;
                }
            }
        }

        NSMutableString *messageContent = [NSMutableString string];
        if (signature.length > 0) {
            [messageContent appendFormat:@"%@", signature];
        }

        NSString *title = nickname.length > 0 ? nickname : @"關注確認";

        [DYYYBottomAlertView showAlertWithTitle:title
                                        message:messageContent
                                      avatarURL:avatarURL
                               cancelButtonText:@"取消"
                              confirmButtonText:@"關注"
                                   cancelAction:nil
                                    closeAction:nil
                                  confirmAction:^{
                                    %orig(gesture);
                                  }];
    } else {
        %orig;
    }
}

%end

%hook AWEPlayInteractionUserAvatarFollowController
- (void)onFollowViewClicked:(UITapGestureRecognizer *)gesture {
    if (DYYYGetBool(@"DYYYFollowTips")) {
        // 获取用户信息
        AWEUserModel *author = nil;
        NSString *nickname = @"";
        NSString *signature = @"";
        NSString *avatarURL = @"";

        if ([self respondsToSelector:@selector(model)]) {
            id model = [self model];
            if ([model isKindOfClass:NSClassFromString(@"AWEAwemeModel")]) {
                author = [model valueForKey:@"author"];
            }
        }

        if (author) {
            // 获取昵称
            if ([author respondsToSelector:@selector(nickname)]) {
                nickname = [author valueForKey:@"nickname"] ?: @"";
            }

            // 获取签名
            if ([author respondsToSelector:@selector(signature)]) {
                signature = [author valueForKey:@"signature"] ?: @"";
            }

            // 获取头像URL
            if ([author respondsToSelector:@selector(avatarThumb)]) {
                AWEURLModel *avatarThumb = [author valueForKey:@"avatarThumb"];
                if (avatarThumb && avatarThumb.originURLList.count > 0) {
                    avatarURL = avatarThumb.originURLList.firstObject;
                }
            }
        }

        NSMutableString *messageContent = [NSMutableString string];
        if (signature.length > 0) {
            [messageContent appendFormat:@"%@", signature];
        }

        NSString *title = nickname.length > 0 ? nickname : @"關注確認";

        [DYYYBottomAlertView showAlertWithTitle:title
                                        message:messageContent
                                      avatarURL:avatarURL
                               cancelButtonText:@"取消"
                              confirmButtonText:@"關注"
                                   cancelAction:nil
                                    closeAction:nil
                                  confirmAction:^{
                                    %orig(gesture);
                                  }];
    } else {
        %orig;
    }
}

%end

%hook AWENormalModeTabBarGeneralPlusButton
+ (id)button {
    BOOL isHidePlusButton = DYYYGetBool(@"DYYYHidePlusButton");
    if (isHidePlusButton) {
        return nil;
    }
    return %orig;
}
%end

%hook AWEFeedContainerContentView
- (void)setAlpha:(CGFloat)alpha {
    // 纯净模式功能
    static dispatch_source_t timer = nil;
    static int attempts = 0;
    static BOOL pureModeSet = NO;
    if (DYYYGetBool(@"DYYYEnablePure")) {
        %orig(0.0);
        if (pureModeSet) {
            return;
        }
        if (!timer) {
            timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, dispatch_get_main_queue());
            dispatch_source_set_timer(timer, DISPATCH_TIME_NOW, 0.5 * NSEC_PER_SEC, 0);
            dispatch_source_set_event_handler(timer, ^{
              UIWindow *keyWindow = [DYYYUtils getActiveWindow];
              if (keyWindow && keyWindow.rootViewController) {
                  UIViewController *feedVC = [DYYYUtils findViewControllerOfClass:NSClassFromString(@"AWEFeedTableViewController") inViewController:keyWindow.rootViewController];
                  if (feedVC) {
                      [feedVC setValue:@YES forKey:@"pureMode"];
                      pureModeSet = YES;
                      dispatch_source_cancel(timer);
                      timer = nil;
                      attempts = 0;
                      return;
                  }
              }
              attempts++;
              if (attempts >= 10) {
                  dispatch_source_cancel(timer);
                  timer = nil;
                  attempts = 0;
              }
            });
            dispatch_resume(timer);
        }
        return;
    } else {
        if (timer) {
            dispatch_source_cancel(timer);
            timer = nil;
        }
        attempts = 0;
        pureModeSet = NO;
    }
    NSString *transparentValue = [[NSUserDefaults standardUserDefaults] objectForKey:@"DYYYTopBarTransparent"];
    if (transparentValue && transparentValue.length > 0) {
        CGFloat alphaValue = [transparentValue floatValue];
        if (alphaValue >= 0.0 && alphaValue <= 1.0) {
            CGFloat finalAlpha = (alphaValue < 0.011) ? 0.011 : alphaValue;
            %orig(finalAlpha);
        } else {
            %orig(1.0);
        }
    } else {
        %orig(1.0);
    }
}
%end

%hook AWEFeedTopBarContainer
- (void)didMoveToSuperview {
    %orig;
    applyTopBarTransparency(self);
}
- (void)setAlpha:(CGFloat)alpha {
    NSString *transparentValue = [[NSUserDefaults standardUserDefaults] objectForKey:@"DYYYTopBarTransparent"];
    if (transparentValue && transparentValue.length > 0) {
        CGFloat alphaValue = [transparentValue floatValue];
        if (alphaValue >= 0.0 && alphaValue <= 1.0) {
            CGFloat finalAlpha = (alphaValue < 0.011) ? 0.011 : alphaValue;
            %orig(finalAlpha);
        } else {
            %orig(1.0);
        }
    } else {
        %orig(1.0);
    }
}
%end

// 设置修改顶栏标题
%hook AWEHPTopTabItemTextContentView

- (void)layoutSubviews {
    %orig;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
      NSString *topTitleConfig = [[NSUserDefaults standardUserDefaults] objectForKey:@"DYYYModifyTopTabText"];
      if (topTitleConfig.length == 0)
          return;

      NSArray *titlePairs = [topTitleConfig componentsSeparatedByString:@"#"];

      NSString *accessibilityLabel = nil;
      if ([self.superview respondsToSelector:@selector(accessibilityLabel)]) {
          accessibilityLabel = self.superview.accessibilityLabel;
      }
      if (accessibilityLabel.length == 0)
          return;

      for (NSString *pair in titlePairs) {
          NSArray *components = [pair componentsSeparatedByString:@"="];
          if (components.count != 2)
              continue;

          NSString *originalTitle = components[0];
          NSString *newTitle = components[1];

          if ([accessibilityLabel isEqualToString:originalTitle]) {
              if ([self respondsToSelector:@selector(setContentText:)]) {
                  [self setContentText:newTitle];
              } else {
                  [self setValue:newTitle forKey:@"contentText"];
              }
              break;
          }
      }
    });
}

%end

%hook AWEDanmakuContentLabel
- (void)setTextColor:(UIColor *)textColor {
    if (DYYYGetBool(@"DYYYEnableDanmuColor")) {
        NSString *danmuColor = [[NSUserDefaults standardUserDefaults] objectForKey:@"DYYYDanmuColor"];
        if (DYYYGetBool(@"DYYYDanmuRainbowRotating")) {
            danmuColor = @"rainbow_rotating";
        }
        [DYYYUtils applyColorSettingsToLabel:self colorHexString:danmuColor];
    } else {
        %orig(textColor);
    }
}

- (void)setStrokeWidth:(double)strokeWidth {
    if (DYYYGetBool(@"DYYYEnableDanmuColor")) {
        %orig(FLT_MIN);
    } else {
        %orig(strokeWidth);
    }
}

- (void)setStrokeColor:(UIColor *)strokeColor {
    if (DYYYGetBool(@"DYYYEnableDanmuColor")) {
        %orig(nil);
    } else {
        %orig(strokeColor);
    }
}

%end

%hook XIGDanmakuPlayerView

- (id)initWithFrame:(CGRect)frame {
    id orig = %orig;

    ((UIView *)orig).tag = DYYY_IGNORE_GLOBAL_ALPHA_TAG;

    return orig;
}

- (void)setAlpha:(CGFloat)alpha {
    if (DYYYGetBool(@"DYYYCommentShowDanmaku") && alpha == 0.0) {
        return;
    } else {
        %orig(alpha);
    }
}

%end

%hook DDanmakuPlayerView

- (void)setAlpha:(CGFloat)alpha {
    if (DYYYGetBool(@"DYYYCommentShowDanmaku") && alpha == 0.0) {
        return;
    } else {
        %orig(alpha);
    }
}

%end

%hook AWEMarkView

- (void)layoutSubviews {
    %orig;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
      UIViewController *vc = [DYYYUtils firstAvailableViewControllerFromView:self];

      if ([vc isKindOfClass:%c(AWEPlayInteractionViewController)]) {
          if (self.markLabel) {
              self.markLabel.textColor = [UIColor whiteColor];
          }
      }

      if (DYYYGetBool(@"DYYYHideLocation")) {
          [self removeFromSuperview];
          return;
      }
    });
}

%end

%group DYYYSettingsGesture

%hook UIWindow
- (instancetype)initWithFrame:(CGRect)frame {
    UIWindow *window = %orig(frame);
    if (window) {
        UILongPressGestureRecognizer *doubleFingerLongPressGesture = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(handleDoubleFingerLongPressGesture:)];
        doubleFingerLongPressGesture.numberOfTouchesRequired = 2;
        [window addGestureRecognizer:doubleFingerLongPressGesture];
    }
    return window;
}

%new
- (void)handleDoubleFingerLongPressGesture:(UILongPressGestureRecognizer *)gesture {
    if (gesture.state == UIGestureRecognizerStateBegan) {
        UIViewController *rootViewController = self.rootViewController;
        if (rootViewController) {
            UIViewController *settingVC = [[DYYYSettingViewController alloc] init];

            if (settingVC) {
                BOOL isIPad = UIDevice.currentDevice.userInterfaceIdiom == UIUserInterfaceIdiomPad;
                if (@available(iOS 15.0, *)) {
                    if (!isIPad) {
                        settingVC.modalPresentationStyle = UIModalPresentationPageSheet;
                    } else {
                        settingVC.modalPresentationStyle = UIModalPresentationFullScreen;
                    }
                } else {
                    settingVC.modalPresentationStyle = UIModalPresentationFullScreen;
                }

                if (settingVC.modalPresentationStyle == UIModalPresentationFullScreen) {
                    UIButton *closeButton = [UIButton buttonWithType:UIButtonTypeSystem];
                    [closeButton setTitle:@"關閉" forState:UIControlStateNormal];
                    closeButton.translatesAutoresizingMaskIntoConstraints = NO;

                    [settingVC.view addSubview:closeButton];

                    [NSLayoutConstraint activateConstraints:@[
                        [closeButton.trailingAnchor constraintEqualToAnchor:settingVC.view.trailingAnchor constant:-10],
                        [closeButton.topAnchor constraintEqualToAnchor:settingVC.view.topAnchor constant:40], [closeButton.widthAnchor constraintEqualToConstant:80],
                        [closeButton.heightAnchor constraintEqualToConstant:40]
                    ]];

                    [closeButton addTarget:self action:@selector(closeSettings:) forControlEvents:UIControlEventTouchUpInside];
                }

                UIView *handleBar = [[UIView alloc] init];
                handleBar.backgroundColor = [UIColor whiteColor];
                handleBar.layer.cornerRadius = 2.5;
                handleBar.translatesAutoresizingMaskIntoConstraints = NO;
                [settingVC.view addSubview:handleBar];

                [NSLayoutConstraint activateConstraints:@[
                    [handleBar.centerXAnchor constraintEqualToAnchor:settingVC.view.centerXAnchor], [handleBar.topAnchor constraintEqualToAnchor:settingVC.view.topAnchor constant:8],
                    [handleBar.widthAnchor constraintEqualToConstant:40], [handleBar.heightAnchor constraintEqualToConstant:5]
                ]];

                [rootViewController presentViewController:settingVC animated:YES completion:nil];
            }
        }
    }
}

%new
- (void)closeSettings:(UIButton *)button {
    [button.superview.window.rootViewController dismissViewControllerAnimated:YES completion:nil];
}

- (void)makeKeyAndVisible {
    %orig;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
      if (!isFloatSpeedButtonEnabled)
          return;

      if (speedButton && ![speedButton isDescendantOfView:self]) {
          dispatch_async(dispatch_get_main_queue(), ^{
            [self addSubview:speedButton];
            [speedButton loadSavedPosition];
            [speedButton resetFadeTimer];
          });
      }
    });
}
%end

%end

%hook AWEBaseListViewController
- (void)viewDidLayoutSubviews {
    %orig;
    [self applyBlurEffectIfNeeded];
}

%new
- (void)applyBlurEffectIfNeeded {
    if (DYYYGetBool(@"DYYYEnableCommentBlur") && [self isKindOfClass:NSClassFromString(@"AWECommentPanelContainerSwiftImpl.CommentContainerInnerViewController")]) {
        // 动态获取用户设置的透明度
        float userTransparency = [[[NSUserDefaults standardUserDefaults] objectForKey:@"DYYYCommentBlurTransparent"] floatValue];
        if (userTransparency <= 0 || userTransparency > 1) {
            userTransparency = 0.9;
        }

        // 应用毛玻璃效果
        [DYYYUtils applyBlurEffectToView:self.view transparency:userTransparency blurViewTag:999];

        [DYYYUtils clearBackgroundRecursivelyInView:self.view];
    }
}
%end

// 重写全局透明方法
%hook AWEPlayInteractionViewController
- (void)loadView {
    %orig;
    if (hideButton) {
        hideButton.hidden = NO;
        hideButton.alpha = 0.5;
    }
}

- (void)viewWillAppear:(BOOL)animated {
    %orig;
    isInPlayInteractionVC = YES;
    dyyyInteractionViewVisible = YES;
    if (hideButton) {
        hideButton.hidden = NO;
        hideButton.alpha = 0.5;
    }
}

- (void)viewDidAppear:(BOOL)animated {
    %orig;
    dyyyInteractionViewVisible = YES;
}

- (void)viewWillDisappear:(BOOL)animated {
    %orig;
    isInPlayInteractionVC = NO;
    dyyyInteractionViewVisible = NO;
}

- (UIView *)view {
    UIView *originalView = %orig;

    NSString *transparentValue = DYYYGetString(@"DYYYGlobalTransparency");
    if (transparentValue.length > 0) {
        CGFloat alphaValue = transparentValue.floatValue;
        if (alphaValue >= 0.0 && alphaValue <= 1.0) {
            for (UIView *subview in originalView.subviews) {
                if (subview.tag != DYYY_IGNORE_GLOBAL_ALPHA_TAG) {
                    if (subview.alpha > 0) {
                        subview.alpha = alphaValue;
                    }
                }
            }
        }
    }

    return originalView;
}

%end

%hook AWEAwemeDetailNaviBarContainerView

- (void)layoutSubviews {
    %orig;

    NSString *transparentValue = [[NSUserDefaults standardUserDefaults] stringForKey:@"DYYYGlobalTransparency"];
    if (!transparentValue.length)
        return;

    CGFloat alphaValue = transparentValue.floatValue;
    if (alphaValue < 0.0 || alphaValue > 1.0)
        return;

    if ([NSStringFromClass([self.superview class]) isEqualToString:NSStringFromClass([self class])])
        return;

    static char kDYYNaviAlphaCacheKey;
    NSArray *alphaViews = objc_getAssociatedObject(self, &kDYYNaviAlphaCacheKey);
    if (!alphaViews) {
        NSMutableArray *tmp = [NSMutableArray array];
        for (UIView *subview in self.subviews) {
            if (subview.tag != DYYY_IGNORE_GLOBAL_ALPHA_TAG && subview.superview == self && subview.alpha > 0) {
                [tmp addObject:subview];
            }
        }
        alphaViews = [tmp copy];
        objc_setAssociatedObject(self, &kDYYNaviAlphaCacheKey, alphaViews, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }

    for (UIView *v in alphaViews) {
        v.alpha = alphaValue;
    }
}

%end

%hook AWEFeedVideoButton
- (id)touchUpInsideBlock {
    id r = %orig;

    // 只有收藏按钮才显示确认弹窗
    if (DYYYGetBool(@"DYYYCollectTips") && [self.accessibilityLabel isEqualToString:@"收藏"]) {

        dispatch_async(dispatch_get_main_queue(), ^{
          [DYYYBottomAlertView showAlertWithTitle:@"收藏確認"
                                          message:@"是否確認/取消收藏？"
                                        avatarURL:nil
                                 cancelButtonText:nil
                                confirmButtonText:nil
                                     cancelAction:nil
                                      closeAction:nil
                                    confirmAction:^{
                                      if (r && [r isKindOfClass:NSClassFromString(@"NSBlock")]) {
                                          ((void (^)(void))r)();
                                      }
                                    }];
        });

        return nil;
    }

    return r;
}
%end

%hook AWEPlayInteractionProgressContainerView
- (void)layoutSubviews {
    %orig;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
      if (![[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYEnableFullScreen"]) {
          return;
      }

      static char kDYProgressBgKey;
      NSArray *bgViews = objc_getAssociatedObject(self, &kDYProgressBgKey);
      if (!bgViews) {
          NSMutableArray *tmp = [NSMutableArray array];
          for (UIView *subview in self.subviews) {
              if ([subview class] == [UIView class]) {
                  [tmp addObject:subview];
              }
          }
          bgViews = [tmp copy];
          objc_setAssociatedObject(self, &kDYProgressBgKey, bgViews, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
      }

      for (UIView *v in bgViews) {
          v.backgroundColor = [UIColor clearColor];
      }
    });
}

%end

%hook AWEFeedProgressSlider

- (void)setAlpha:(CGFloat)alpha {
    if (DYYYGetBool(@"DYYYShowScheduleDisplay")) {
        if (DYYYGetBool(@"DYYYHideVideoProgress")) {
            %orig(0);
        } else {
            %orig(1.0);
        }
    } else {
        %orig;
    }
}

static CGFloat leftLabelLeftMargin = -1;
static CGFloat rightLabelRightMargin = -1;

- (void)setLimitUpperActionArea:(BOOL)arg1 {
    %orig;

    NSString *durationFormatted = [self.progressSliderDelegate formatTimeFromSeconds:floor(self.progressSliderDelegate.model.videoDuration / 1000)];

    if (DYYYGetBool(@"DYYYShowScheduleDisplay")) {
        UIView *parentView = self.superview;
        if (!parentView)
            return;

        [[parentView viewWithTag:10001] removeFromSuperview];
        [[parentView viewWithTag:10002] removeFromSuperview];

        CGRect sliderOriginalFrameInParent = [self convertRect:self.bounds toView:parentView];
        CGRect sliderFrame = self.frame;

        CGFloat verticalOffset = -12.5;
        NSString *offsetValueString = [[NSUserDefaults standardUserDefaults] objectForKey:@"DYYYTimelineVerticalPosition"];
        if (offsetValueString.length > 0) {
            CGFloat configOffset = [offsetValueString floatValue];
            if (configOffset != 0)
                verticalOffset = configOffset;
        }

        NSString *scheduleStyle = [[NSUserDefaults standardUserDefaults] objectForKey:@"DYYYScheduleStyle"];
        BOOL showRemainingTime = [scheduleStyle isEqualToString:@"進度條右側剩餘"];
        BOOL showCompleteTime = [scheduleStyle isEqualToString:@"進度條右側完整"];
        BOOL showLeftRemainingTime = [scheduleStyle isEqualToString:@"進度條左側剩餘"];
        BOOL showLeftCompleteTime = [scheduleStyle isEqualToString:@"進度條左側完整"];

        NSString *labelColorHex = [[NSUserDefaults standardUserDefaults] objectForKey:@"DYYYProgressLabelColor"];

        CGFloat labelYPosition = sliderOriginalFrameInParent.origin.y + verticalOffset;
        CGFloat labelHeight = 15.0;
        UIFont *labelFont = [UIFont systemFontOfSize:8];

        if (!showRemainingTime && !showCompleteTime) {
            UILabel *leftLabel = [[UILabel alloc] init];
            leftLabel.backgroundColor = [UIColor clearColor];
            leftLabel.font = labelFont;
            leftLabel.tag = 10001;
            if (showLeftRemainingTime)
                leftLabel.text = @"00:00";
            else if (showLeftCompleteTime)
                leftLabel.text = [NSString stringWithFormat:@"00:00/%@", durationFormatted];
            else
                leftLabel.text = @"00:00";

            [leftLabel sizeToFit];

            if (leftLabelLeftMargin == -1) {
                leftLabelLeftMargin = sliderFrame.origin.x;
            }

            leftLabel.frame = CGRectMake(leftLabelLeftMargin, labelYPosition, leftLabel.frame.size.width, labelHeight);
            [parentView addSubview:leftLabel];

            [DYYYUtils applyColorSettingsToLabel:leftLabel colorHexString:labelColorHex];
        }

        if (!showLeftRemainingTime && !showLeftCompleteTime) {
            UILabel *rightLabel = [[UILabel alloc] init];
            rightLabel.backgroundColor = [UIColor clearColor];
            rightLabel.font = labelFont;
            rightLabel.tag = 10002;
            if (showRemainingTime)
                rightLabel.text = @"00:00";
            else if (showCompleteTime)
                rightLabel.text = [NSString stringWithFormat:@"00:00/%@", durationFormatted];
            else
                rightLabel.text = durationFormatted;

            [rightLabel sizeToFit];

            if (rightLabelRightMargin == -1) {
                rightLabelRightMargin = sliderFrame.origin.x + sliderFrame.size.width - rightLabel.frame.size.width;
            }

            rightLabel.frame = CGRectMake(rightLabelRightMargin, labelYPosition, rightLabel.frame.size.width, labelHeight);
            [parentView addSubview:rightLabel];

            [DYYYUtils applyColorSettingsToLabel:rightLabel colorHexString:labelColorHex];
        }

        [self setNeedsLayout];
    } else {
        UIView *parentView = self.superview;
        if (parentView) {
            [[parentView viewWithTag:10001] removeFromSuperview];
            [[parentView viewWithTag:10002] removeFromSuperview];
        }
        [self setNeedsLayout];
    }
}

%end

%hook AWEPlayInteractionProgressController

%new
- (NSString *)formatTimeFromSeconds:(CGFloat)seconds {
    NSInteger hours = (NSInteger)seconds / 3600;
    NSInteger minutes = ((NSInteger)seconds % 3600) / 60;
    NSInteger secs = (NSInteger)seconds % 60;

    if (hours > 0) {
        return [NSString stringWithFormat:@"%02ld:%02ld:%02ld", (long)hours, (long)minutes, (long)secs];
    } else {
        return [NSString stringWithFormat:@"%02ld:%02ld", (long)minutes, (long)secs];
    }
}

- (void)updateProgressSliderWithTime:(CGFloat)arg1 totalDuration:(CGFloat)arg2 {
    %orig;

    if (DYYYGetBool(@"DYYYShowScheduleDisplay")) {
        AWEFeedProgressSlider *progressSlider = self.progressSlider;
        UIView *parentView = progressSlider.superview;
        if (!parentView)
            return;

        UILabel *leftLabel = [parentView viewWithTag:10001];
        UILabel *rightLabel = [parentView viewWithTag:10002];

        NSString *labelColorHex = [[NSUserDefaults standardUserDefaults] objectForKey:@"DYYYProgressLabelColor"];

        NSString *scheduleStyle = [[NSUserDefaults standardUserDefaults] objectForKey:@"DYYYScheduleStyle"];
        BOOL showRemainingTime = [scheduleStyle isEqualToString:@"進度條右側剩餘"];
        BOOL showCompleteTime = [scheduleStyle isEqualToString:@"進度條右側完整"];
        BOOL showLeftRemainingTime = [scheduleStyle isEqualToString:@"進度條左側剩餘"];
        BOOL showLeftCompleteTime = [scheduleStyle isEqualToString:@"進度條左側完整"];

        // 更新左标签
        if (arg1 >= 0 && leftLabel) {
            NSString *newLeftText = @"";
            if (showLeftRemainingTime) {
                CGFloat remainingTime = arg2 - arg1;
                if (remainingTime < 0)
                    remainingTime = 0;
                newLeftText = [self formatTimeFromSeconds:remainingTime];
            } else if (showLeftCompleteTime) {
                newLeftText = [NSString stringWithFormat:@"%@/%@", [self formatTimeFromSeconds:arg1], [self formatTimeFromSeconds:arg2]];
            } else {
                newLeftText = [self formatTimeFromSeconds:arg1];
            }

            if (![leftLabel.text isEqualToString:newLeftText]) {
                leftLabel.text = newLeftText;
                [leftLabel sizeToFit];
                CGRect leftFrame = leftLabel.frame;
                leftFrame.size.height = 15.0;
                leftLabel.frame = leftFrame;
            }
            [DYYYUtils applyColorSettingsToLabel:leftLabel colorHexString:labelColorHex];
        }

        // 更新右标签
        if (arg2 > 0 && rightLabel) {
            NSString *newRightText = @"";
            if (showRemainingTime) {
                CGFloat remainingTime = arg2 - arg1;
                if (remainingTime < 0)
                    remainingTime = 0;
                newRightText = [self formatTimeFromSeconds:remainingTime];
            } else if (showCompleteTime) {
                newRightText = [NSString stringWithFormat:@"%@/%@", [self formatTimeFromSeconds:arg1], [self formatTimeFromSeconds:arg2]];
            } else {
                newRightText = [self formatTimeFromSeconds:arg2];
            }

            if (![rightLabel.text isEqualToString:newRightText]) {
                rightLabel.text = newRightText;
                [rightLabel sizeToFit];
                CGRect rightFrame = rightLabel.frame;
                rightFrame.size.height = 15.0;
                rightLabel.frame = rightFrame;
            }
            [DYYYUtils applyColorSettingsToLabel:rightLabel colorHexString:labelColorHex];
        }
    }
}

- (void)setHidden:(BOOL)hidden {
    %orig;
    BOOL hideVideoProgress = DYYYGetBool(@"DYYYHideVideoProgress");
    BOOL showScheduleDisplay = DYYYGetBool(@"DYYYShowScheduleDisplay");
    if (hideVideoProgress && showScheduleDisplay && !hidden) {
        self.alpha = 0;
    }
}

%end
%hook AWENormalModeTabBarTextView

- (void)layoutSubviews {
     @try {
        %orig;

        if (![NSThread isMainThread]) {
            dispatch_async(dispatch_get_main_queue(), ^{
              [self layoutSubviews];
            });
            return;
        }

        if (!self || !self.superview) {
            return;
        }

        NSString *indexTitle = [[NSUserDefaults standardUserDefaults] objectForKey:@"DYYYIndexTitle"];
        NSString *friendsTitle = [[NSUserDefaults standardUserDefaults] objectForKey:@"DYYYFriendsTitle"];
        NSString *msgTitle = [[NSUserDefaults standardUserDefaults] objectForKey:@"DYYYMsgTitle"];
        NSString *selfTitle = [[NSUserDefaults standardUserDefaults] objectForKey:@"DYYYSelfTitle"];

        if (!(indexTitle.length || friendsTitle.length || msgTitle.length || selfTitle.length)) {
            return;
        }

        static char kDYTabLabelCacheKey;
        NSArray *labelCache = objc_getAssociatedObject(self, &kDYTabLabelCacheKey);
        if (!labelCache) {
            NSMutableArray *tmp = [NSMutableArray array];
            if (!tmp) {
                return;
            }

            NSArray *subviews = [self subviews];
            if (!subviews) {
                return;
            }

            for (UIView *subview in subviews) {
                if (subview && [subview isKindOfClass:[UILabel class]]) {
                    [tmp addObject:subview];
                }
            }

            labelCache = [tmp copy];
            if (labelCache) {
                objc_setAssociatedObject(self, &kDYTabLabelCacheKey, labelCache, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            }
        }

        if (!labelCache) {
            return;
        }

        for (UILabel *label in labelCache) {
            if (!label || ![label isKindOfClass:[UILabel class]]) {
                continue;
            }

            NSString *labelText = label.text;
            if (!labelText) {
                continue;
            }

            if ([labelText isEqualToString:@"首页"] && indexTitle.length > 0) {
                label.text = indexTitle;
                dispatch_async(dispatch_get_main_queue(), ^{
                  [self setNeedsLayout];
                });
            } else if ([labelText isEqualToString:@"朋友"] && friendsTitle.length > 0) {
                label.text = friendsTitle;
                dispatch_async(dispatch_get_main_queue(), ^{
                  [self setNeedsLayout];
                });
            } else if ([labelText isEqualToString:@"消息"] && msgTitle.length > 0) {
                label.text = msgTitle;
                dispatch_async(dispatch_get_main_queue(), ^{
                  [self setNeedsLayout];
                });
            } else if ([labelText isEqualToString:@"我"] && selfTitle.length > 0) {
                label.text = selfTitle;
                dispatch_async(dispatch_get_main_queue(), ^{
                  [self setNeedsLayout];
                });
            }
        }

    } @catch (NSException *exception) {
        return;
        }
    }
}
%end

%hook AWEPlayInteractionTimestampElement

- (id)timestampLabel {
    UILabel *label = %orig;
    NSString *labelColorHex = [[NSUserDefaults standardUserDefaults] objectForKey:@"DYYYLabelColor"];
    if (DYYYGetBool(@"DYYYEnableRandomGradient")) {
        labelColorHex = @"random_gradient";
    }
    if (DYYYGetBool(@"DYYYEnableArea")) {
        NSString *originalText = label.text ?: @"";
        NSString *cityCode = self.model.cityCode;

        if (cityCode.length > 0) {
            NSString *cityName = [CityManager.sharedInstance getCityNameWithCode:cityCode];
            NSString *provinceName = [CityManager.sharedInstance getProvinceNameWithCode:cityCode];
            // 使用 GeoNames API
            if (!cityName || cityName.length == 0) {
                NSString *cacheKey = cityCode;

                static NSCache *geoNamesCache = nil;
                static dispatch_once_t onceToken;
                dispatch_once(&onceToken, ^{
                  geoNamesCache = [[NSCache alloc] init];
                  geoNamesCache.name = @"com.dyyy.geonames.cache";
                  geoNamesCache.countLimit = 1000;
                });

                NSDictionary *cachedData = [geoNamesCache objectForKey:cacheKey];

                if (!cachedData) {
                    NSString *cachesDir = [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) firstObject];
                    NSString *geoNamesCacheDir = [cachesDir stringByAppendingPathComponent:@"DYYYGeoNamesCache"];

                    NSFileManager *fileManager = [NSFileManager defaultManager];
                    if (![fileManager fileExistsAtPath:geoNamesCacheDir]) {
                        [fileManager createDirectoryAtPath:geoNamesCacheDir withIntermediateDirectories:YES attributes:nil error:nil];
                    }

                    NSString *cacheFilePath = [geoNamesCacheDir stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.plist", cacheKey]];

                    if ([fileManager fileExistsAtPath:cacheFilePath]) {
                        cachedData = [NSDictionary dictionaryWithContentsOfFile:cacheFilePath];
                        if (cachedData) {
                            [geoNamesCache setObject:cachedData forKey:cacheKey];
                        }
                    }
                }

                if (cachedData) {
                    NSString *countryName = cachedData[@"countryName"];
                    NSString *adminName1 = cachedData[@"adminName1"];
                    NSString *localName = cachedData[@"name"];
                    NSString *displayLocation = @"未知";

                    if (countryName.length > 0) {
                        if (adminName1.length > 0 && localName.length > 0 && ![countryName isEqualToString:@"中国"] && ![countryName isEqualToString:localName]) {
                            // 国外位置：国家 + 州/省 + 地点
                            displayLocation = [NSString stringWithFormat:@"%@ %@ %@", countryName, adminName1, localName];
                        } else if (localName.length > 0 && ![countryName isEqualToString:localName]) {
                            // 只有国家和地点名
                            displayLocation = [NSString stringWithFormat:@"%@ %@", countryName, localName];
                        } else {
                            // 只有国家名
                            displayLocation = countryName;
                        }
                    } else if (localName.length > 0) {
                        displayLocation = localName;
                    }

                    dispatch_async(dispatch_get_main_queue(), ^{
                      NSString *currentLabelText = label.text ?: @"";
                      if ([currentLabelText containsString:@"IP地址："]) {
                          NSRange range = [currentLabelText rangeOfString:@"IP地址："];
                          if (range.location != NSNotFound) {
                              NSString *baseText = [currentLabelText substringToIndex:range.location];
                              if (![currentLabelText containsString:displayLocation]) {
                                  label.text = [NSString stringWithFormat:@"%@IP地址：%@", baseText, displayLocation];
                              }
                          }
                      } else {
                          if (currentLabelText.length > 0 && ![displayLocation isEqualToString:@"未知"]) {
                              label.text = [NSString stringWithFormat:@"%@  IP地址：%@", currentLabelText, displayLocation];
                          } else if (![displayLocation isEqualToString:@"未知"]) {
                              label.text = [NSString stringWithFormat:@"IP地址：%@", displayLocation];
                          }
                      }

                      [DYYYUtils applyColorSettingsToLabel:label colorHexString:labelColorHex];
                    });
                } else {
                    [CityManager fetchLocationWithGeonameId:cityCode
                                          completionHandler:^(NSDictionary *locationInfo, NSError *error) {
                                            if (locationInfo) {
                                                NSString *countryName = locationInfo[@"countryName"];
                                                NSString *adminName1 = locationInfo[@"adminName1"]; // 州/省级名称
                                                NSString *localName = locationInfo[@"name"];        // 当前地点名称
                                                NSString *displayLocation = @"未知";

                                                // 根据返回数据构建位置显示文本
                                                if (countryName.length > 0) {
                                                    if (adminName1.length > 0 && localName.length > 0 && ![countryName isEqualToString:@"中国"] && ![countryName isEqualToString:localName]) {
                                                        // 国外位置：国家 + 州/省 + 地点
                                                        displayLocation = [NSString stringWithFormat:@"%@ %@ %@", countryName, adminName1, localName];
                                                    } else if (localName.length > 0 && ![countryName isEqualToString:localName]) {
                                                        // 只有国家和地点名
                                                        displayLocation = [NSString stringWithFormat:@"%@ %@", countryName, localName];
                                                    } else {
                                                        // 只有国家名
                                                        displayLocation = countryName;
                                                    }
                                                } else if (localName.length > 0) {
                                                    displayLocation = localName;
                                                }

                                                // 修改：仅当位置不为"未知"时才缓存
                                                if (![displayLocation isEqualToString:@"未知"]) {
                                                    [geoNamesCache setObject:locationInfo forKey:cacheKey];

                                                    NSString *cachesDir = [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) firstObject];
                                                    NSString *geoNamesCacheDir = [cachesDir stringByAppendingPathComponent:@"DYYYGeoNamesCache"];
                                                    NSString *cacheFilePath = [geoNamesCacheDir stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.plist", cacheKey]];

                                                    [locationInfo writeToFile:cacheFilePath atomically:YES];
                                                }

                                                dispatch_async(dispatch_get_main_queue(), ^{
                                                  NSString *currentLabelText = label.text ?: @"";

                                                  if ([currentLabelText containsString:@"IP地址："]) {
                                                      NSRange range = [currentLabelText rangeOfString:@"IP地址："];
                                                      if (range.location != NSNotFound) {
                                                          NSString *baseText = [currentLabelText substringToIndex:range.location];
                                                          if (![currentLabelText containsString:displayLocation]) {
                                                              label.text = [NSString stringWithFormat:@"%@IP地址：%@", baseText, displayLocation];
                                                          }
                                                      }
                                                  } else {
                                                      if (currentLabelText.length > 0 && ![displayLocation isEqualToString:@"未知"]) {
                                                          label.text = [NSString stringWithFormat:@"%@  IP地址：%@", currentLabelText, displayLocation];
                                                      } else if (![displayLocation isEqualToString:@"未知"]) {
                                                          label.text = [NSString stringWithFormat:@"IP地址：%@", displayLocation];
                                                      }
                                                  }

                                                  [DYYYUtils applyColorSettingsToLabel:label colorHexString:labelColorHex];
                                                });
                                            }
                                          }];
                }
            } else if (![originalText containsString:cityName]) {
                BOOL isDirectCity = [provinceName isEqualToString:cityName] || ([cityCode hasPrefix:@"11"] || [cityCode hasPrefix:@"12"] || [cityCode hasPrefix:@"31"] || [cityCode hasPrefix:@"50"]);
                if (!self.model.ipAttribution) {
                    if (isDirectCity) {
                        label.text = [NSString stringWithFormat:@"%@  IP地址：%@", originalText, cityName];
                    } else {
                        label.text = [NSString stringWithFormat:@"%@  IP地址：%@ %@", originalText, provinceName, cityName];
                    }
                } else {
                    BOOL containsProvince = [originalText containsString:provinceName];
                    BOOL containsCity = [originalText containsString:cityName];
                    if (containsProvince && !isDirectCity && !containsCity) {
                        label.text = [NSString stringWithFormat:@"%@ %@", originalText, cityName];
                    } else if (isDirectCity && !containsCity) {
                        label.text = [NSString stringWithFormat:@"%@  IP地址：%@", originalText, cityName];
                    }
                }
            }
        }
    }
    // 应用IP属地标签上移
    NSString *ipScaleValue = [[NSUserDefaults standardUserDefaults] objectForKey:@"DYYYNicknameScale"];
    if (ipScaleValue.length > 0) {
        UIFont *originalFont = label.font;
        CGRect originalFrame = label.frame;
        CGFloat offset = DYYYGetFloat(@"DYYYIPLabelVerticalOffset");
        if (offset > 0) {
            CGAffineTransform translationTransform = CGAffineTransformMakeTranslation(0, -offset);
            label.transform = translationTransform;
        } else {
            CGAffineTransform translationTransform = CGAffineTransformMakeTranslation(0, -3);
            label.transform = translationTransform;
        }

        label.font = originalFont;
    }

    [DYYYUtils applyColorSettingsToLabel:label colorHexString:labelColorHex];

    return label;
}

+ (BOOL)shouldActiveWithData:(id)arg1 context:(id)arg2 {
    return DYYYGetBool(@"DYYYEnableArea");
}

%end

%hook AWEPlayInteractionDescriptionScrollView

- (void)layoutSubviews {
    %orig;

    self.transform = CGAffineTransformIdentity;

    NSString *descriptionOffsetValue = [[NSUserDefaults standardUserDefaults] objectForKey:@"DYYYDescriptionVerticalOffset"];
    CGFloat verticalOffset = 0;
    if (descriptionOffsetValue.length > 0) {
        verticalOffset = [descriptionOffsetValue floatValue];
    }

    UIView *parentView = self.superview;
    UIView *grandParentView = nil;

    if (parentView) {
        grandParentView = parentView.superview;
    }

    if (grandParentView && verticalOffset != 0) {
        CGAffineTransform translationTransform = CGAffineTransformMakeTranslation(0, verticalOffset);
        grandParentView.transform = translationTransform;
    }
}

%end

// 对新版文案的偏移（33.0以上）
%hook AWEPlayInteractionDescriptionLabel

static char kLongPressGestureKey;
static NSString *const kDYYYLongPressCopyEnabledKey = @"DYYYLongPressCopyTextEnabled";

- (void)didMoveToWindow {
    %orig;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
      BOOL longPressCopyEnabled = DYYYGetBool(kDYYYLongPressCopyEnabledKey);

      if (![[NSUserDefaults standardUserDefaults] objectForKey:kDYYYLongPressCopyEnabledKey]) {
          longPressCopyEnabled = NO;
          [[NSUserDefaults standardUserDefaults] setBool:NO forKey:kDYYYLongPressCopyEnabledKey];
          [[NSUserDefaults standardUserDefaults] synchronize];
      }

      UIGestureRecognizer *existingGesture = objc_getAssociatedObject(self, &kLongPressGestureKey);
      if (existingGesture && !longPressCopyEnabled) {
          [self removeGestureRecognizer:existingGesture];
          objc_setAssociatedObject(self, &kLongPressGestureKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
          return;
      }

      if (longPressCopyEnabled && !objc_getAssociatedObject(self, &kLongPressGestureKey)) {
          UILongPressGestureRecognizer *highPriorityLongPress = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(handleHighPriorityLongPress:)];
          highPriorityLongPress.minimumPressDuration = 0.3;

          [self addGestureRecognizer:highPriorityLongPress];

          UIView *currentView = self;
          while (currentView.superview) {
              currentView = currentView.superview;

              for (UIGestureRecognizer *recognizer in currentView.gestureRecognizers) {
                  if ([recognizer isKindOfClass:[UILongPressGestureRecognizer class]] || [recognizer isKindOfClass:[UIPinchGestureRecognizer class]]) {
                      [recognizer requireGestureRecognizerToFail:highPriorityLongPress];
                  }
              }
          }

          objc_setAssociatedObject(self, &kLongPressGestureKey, highPriorityLongPress, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
      }
    });
}

%new
- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer {
    if ([gestureRecognizer.view isEqual:self] && [gestureRecognizer isKindOfClass:[UILongPressGestureRecognizer class]]) {
        return NO;
    }
    return YES;
}

%new
- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldBeRequiredToFailByGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer {
    if ([gestureRecognizer.view isEqual:self] && [gestureRecognizer isKindOfClass:[UILongPressGestureRecognizer class]]) {
        return YES;
    }
    return NO;
}

%new
- (void)handleHighPriorityLongPress:(UILongPressGestureRecognizer *)gestureRecognizer {
    if (gestureRecognizer.state == UIGestureRecognizerStateBegan) {

        NSString *description = self.text;

        if (description.length > 0) {
            [[UIPasteboard generalPasteboard] setString:description];
            [DYYYToast showSuccessToastWithMessage:@"影片文案已複製"];
        }
    }
}

- (void)layoutSubviews {
    %orig;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
      self.transform = CGAffineTransformIdentity;

      NSString *descriptionOffsetValue = [[NSUserDefaults standardUserDefaults] objectForKey:@"DYYYDescriptionVerticalOffset"];
      CGFloat verticalOffset = 0;
      if (descriptionOffsetValue.length > 0) {
          verticalOffset = [descriptionOffsetValue floatValue];
      }

      UIView *parentView = self.superview;
      UIView *grandParentView = nil;

      if (parentView) {
          grandParentView = parentView.superview;
      }

      if (grandParentView && verticalOffset != 0) {
          CGAffineTransform translationTransform = CGAffineTransformMakeTranslation(0, verticalOffset);
          grandParentView.transform = translationTransform;
      }
    });
}

%end

%hook AWEUserNameLabel

- (void)layoutSubviews {
    %orig;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
      self.transform = CGAffineTransformIdentity;

      // 添加垂直偏移支持
      NSString *verticalOffsetValue = [[NSUserDefaults standardUserDefaults] objectForKey:@"DYYYNicknameVerticalOffset"];
      CGFloat verticalOffset = 0;
      if (verticalOffsetValue.length > 0) {
          verticalOffset = [verticalOffsetValue floatValue];
      }

      UIView *parentView = self.superview;
      UIView *grandParentView = nil;

      if (parentView) {
          grandParentView = parentView.superview;
      }

      // 检查祖父视图是否为 AWEBaseElementView 类型
      if (grandParentView && [grandParentView.superview isKindOfClass:%c(AWEBaseElementView)]) {
          CGRect scaledFrame = grandParentView.frame;
          CGFloat translationX = -scaledFrame.origin.x;

          CGAffineTransform translationTransform = CGAffineTransformMakeTranslation(translationX, verticalOffset);
          grandParentView.transform = translationTransform;
      }
    });
}

%end

%hook AWEFeedVideoButton

- (void)setImage:(id)arg1 {
    %orig;

    NSString *nameString = nil;

    if ([self respondsToSelector:@selector(imageNameString)]) {
        nameString = [self performSelector:@selector(imageNameString)];
    }

    if (!nameString) {
        %orig;
        return;
    }

    NSString *documentsPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject];
    NSString *dyyyFolderPath = [documentsPath stringByAppendingPathComponent:@"DYYY"];

    [[NSFileManager defaultManager] createDirectoryAtPath:dyyyFolderPath withIntermediateDirectories:YES attributes:nil error:nil];

    NSDictionary *iconMapping = @{
        @"icon_home_like_after" : @"like_after.png",
        @"icon_home_like_before" : @"like_before.png",
        @"icon_home_comment" : @"comment.png",
        @"icon_home_unfavorite" : @"unfavorite.png",
        @"icon_home_favorite" : @"favorite.png",
        @"iconHomeShareRight" : @"share.png"
    };

    NSString *customFileName = nil;
    if ([nameString containsString:@"_comment"]) {
        customFileName = @"comment.png";
    } else if ([nameString containsString:@"_like"]) {
        customFileName = @"like_before.png";
    } else if ([nameString containsString:@"_collect"]) {
        customFileName = @"unfavorite.png";
    } else if ([nameString containsString:@"_share"]) {
        customFileName = @"share.png";
    }

    for (NSString *prefix in iconMapping.allKeys) {
        if ([nameString hasPrefix:prefix]) {
            customFileName = iconMapping[prefix];
            break;
        }
    }

    if (customFileName) {
        NSString *customImagePath = [dyyyFolderPath stringByAppendingPathComponent:customFileName];

        if ([[NSFileManager defaultManager] fileExistsAtPath:customImagePath]) {
            UIImage *customImage = [UIImage imageWithContentsOfFile:customImagePath];
            if (customImage) {
                CGFloat targetWidth = 44.0;
                CGFloat targetHeight = 44.0;
                CGSize originalSize = customImage.size;

                CGFloat scale = MIN(targetWidth / originalSize.width, targetHeight / originalSize.height);
                CGFloat newWidth = originalSize.width * scale;
                CGFloat newHeight = originalSize.height * scale;

                UIGraphicsBeginImageContextWithOptions(CGSizeMake(newWidth, newHeight), NO, 0.0);
                [customImage drawInRect:CGRectMake(0, 0, newWidth, newHeight)];
                UIImage *resizedImage = UIGraphicsGetImageFromCurrentImageContext();
                UIGraphicsEndImageContext();

                if (resizedImage) {
                    %orig(resizedImage);
                    return;
                }
            }
        }
    }
}

%end

// 获取资源的地址
%hook AWEURLModel
%new - (NSURL *)getDYYYSrcURLDownload {
    NSURL *bestURL;
    for (NSString *url in self.originURLList) {
        if ([url containsString:@"video_mp4"] || [url containsString:@".jpeg"] || [url containsString:@".mp3"]) {
            bestURL = [NSURL URLWithString:url];
        }
    }

    if (bestURL == nil) {
        bestURL = [NSURL URLWithString:[self.originURLList firstObject]];
    }

    return bestURL;
}
%end

// 禁用点击首页刷新
%hook AWENormalModeTabBarGeneralButton

- (BOOL)enableRefresh {
    if ([self.accessibilityLabel isEqualToString:@"首页"]) {
        if (DYYYGetBool(@"DYYYDisableHomeRefresh")) {
            return NO;
        }
    }
    return %orig;
}

%end

// 屏蔽版本更新
%hook AWEVersionUpdateManager

- (void)startVersionUpdateWorkflow:(id)arg1 completion:(id)arg2 {
    if (DYYYGetBool(@"DYYYNoUpdates")) {
        if (arg2) {
            void (^completionBlock)(void) = arg2;
            completionBlock();
        }
    } else {
        %orig;
    }
}

- (id)workflow {
    return DYYYGetBool(@"DYYYNoUpdates") ? nil : %orig;
}

- (id)badgeModule {
    return DYYYGetBool(@"DYYYNoUpdates") ? nil : %orig;
}

%end

// 应用内推送毛玻璃效果
%hook AWEInnerNotificationWindow

- (void)layoutSubviews {
    %orig;
    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYEnableNotificationTransparency"]) {
        [self setupBlurEffectForNotificationView];
    }
}

- (void)didMoveToWindow {
    %orig;
    if (DYYYGetBool(@"DYYYEnableNotificationTransparency")) {
        [self setupBlurEffectForNotificationView];
    }
}

%new
- (void)setupBlurEffectForNotificationView {
    for (UIView *subview in self.subviews) {
        if ([NSStringFromClass([subview class]) containsString:@"AWEInnerNotificationContainerView"]) {
            [self applyBlurEffectToView:subview];
            break;
        }
    }
}

%new
- (void)applyBlurEffectToView:(UIView *)containerView {
    if (!containerView) {
        return;
    }

    containerView.backgroundColor = [UIColor clearColor];

    float userRadius = [[[NSUserDefaults standardUserDefaults] objectForKey:@"DYYYNotificationCornerRadius"] floatValue];
    if (!userRadius || userRadius < 0 || userRadius > 50) {
        userRadius = 12;
    }

    containerView.layer.cornerRadius = userRadius;
    containerView.layer.masksToBounds = YES;

    for (UIView *subview in containerView.subviews) {
        if ([subview isKindOfClass:[UIVisualEffectView class]] && subview.tag == 999) {
            [subview removeFromSuperview];
        }
    }

    BOOL isDarkMode = [DYYYUtils isDarkMode];
    UIBlurEffectStyle blurStyle = isDarkMode ? UIBlurEffectStyleDark : UIBlurEffectStyleLight;
    UIBlurEffect *blurEffect = [UIBlurEffect effectWithStyle:blurStyle];
    UIVisualEffectView *blurView = [[UIVisualEffectView alloc] initWithEffect:blurEffect];

    blurView.frame = containerView.bounds;
    blurView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    blurView.tag = 999;
    blurView.layer.cornerRadius = userRadius;
    blurView.layer.masksToBounds = YES;

    float userTransparency = [[[NSUserDefaults standardUserDefaults] objectForKey:@"DYYYCommentBlurTransparent"] floatValue];
    if (userTransparency <= 0 || userTransparency > 1) {
        userTransparency = 0.5;
    }

    blurView.alpha = userTransparency;

    [containerView insertSubview:blurView atIndex:0];

    [self clearBackgroundRecursivelyInView:containerView];

    [self setLabelsColorWhiteInView:containerView];
}

%new
- (void)setLabelsColorWhiteInView:(UIView *)view {
    for (UIView *subview in view.subviews) {
        if ([subview isKindOfClass:[UILabel class]]) {
            UILabel *label = (UILabel *)subview;
            NSString *text = label.text;

            if (![text isEqualToString:@"回复"] && ![text isEqualToString:@"查看"] && ![text isEqualToString:@"续火花"]) {
                label.textColor = [UIColor whiteColor];
            }
        }
        [self setLabelsColorWhiteInView:subview];
    }
}

%new
- (void)clearBackgroundRecursivelyInView:(UIView *)view {
    for (UIView *subview in view.subviews) {
        if ([subview isKindOfClass:[UIVisualEffectView class]] && subview.tag == 999 && [subview isKindOfClass:[UIButton class]]) {
            continue;
        }
        subview.backgroundColor = [UIColor clearColor];
        subview.opaque = NO;
        [self clearBackgroundRecursivelyInView:subview];
    }
}

%end

// 为 AWEUserActionSheetView 添加毛玻璃效果
%hook AWEUserActionSheetView

- (void)layoutSubviews {
    %orig;
    if (DYYYGetBool(@"DYYYEnableSheetBlur")) {
        [self applyBlurEffectAndWhiteText];
    }
}

%new
- (void)applyBlurEffectAndWhiteText {
    // 应用毛玻璃效果到容器视图
    if (self.containerView) {
        self.containerView.backgroundColor = [UIColor clearColor];

        // 动态获取用户设置的透明度
        float userTransparency = [[[NSUserDefaults standardUserDefaults] objectForKey:@"DYYYSheetBlurTransparent"] floatValue];
        if (userTransparency <= 0 || userTransparency > 1) {
            userTransparency = 0.9; // 默认值0.9
        }

        [DYYYUtils applyBlurEffectToView:self.containerView transparency:userTransparency blurViewTag:9999];
        [DYYYUtils clearBackgroundRecursivelyInView:self.containerView];

        // 调用新的通用方法设置文本颜色，这里没有排除需求，所以传入 nil Block
        [DYYYUtils applyTextColorRecursively:[UIColor whiteColor] inView:self.containerView shouldExcludeViewBlock:nil];
    }
}

%end

%hook _TtC33AWECommentLongPressPanelSwiftImpl32CommentLongPressPanelCopyElement

- (void)elementTapped {
    if (DYYYGetBool(@"DYYYCommentCopyText")) {
        AWECommentLongPressPanelContext *commentPageContext = [self commentPageContext];
        AWECommentModel *selectdComment = [commentPageContext selectdComment];
        if (!selectdComment) {
            AWECommentLongPressPanelParam *params = [commentPageContext params];
            selectdComment = [params selectdComment];
        }
        NSString *descText = [selectdComment content];
        [[UIPasteboard generalPasteboard] setString:descText];
        [DYYYToast showSuccessToastWithMessage:@"評論已複製"];
    }
}
%end

// 启用自动勾选原图
%hook AWEIMPhotoPickerFunctionModel

- (void)setUseShadowIcon:(BOOL)arg1 {
    BOOL enabled = DYYYGetBool(@"DYYYAutoSelectOriginalPhoto");
    if (enabled) {
        %orig(YES);
    } else {
        %orig(arg1);
    }
}

- (BOOL)isSelected {
    BOOL enabled = DYYYGetBool(@"DYYYAutoSelectOriginalPhoto");
    if (enabled) {
        return YES;
    }
    return %orig;
}

%end

// 屏蔽直播PCDN
%hook HTSLiveStreamPcdnManager

+ (void)start {
    BOOL disablePCDN = DYYYGetBool(@"DYYYDisableLivePCDN");
    if (!disablePCDN) {
        %orig;
    } else {
        NSLog(@"[DYYY] HTSLiveStreamPcdnManager start blocked");
    }
}

+ (void)configAndStartLiveIO {
    BOOL disablePCDN = DYYYGetBool(@"DYYYDisableLivePCDN");
    if (!disablePCDN) {
        %orig;
    } else {
        NSLog(@"[DYYY] HTSLiveStreamPcdnManager configAndStartLiveIO blocked");
    }
}

%end

// PCDN啟動任務hook
%hook IESLiveLaunchTaskPcdn

- (void)excute {
    BOOL disablePCDN = DYYYGetBool(@"DYYYDisableLivePCDN");
    if (disablePCDN) {
        NSLog(@"[DYYY] IESLiveLaunchTaskPcdn excute blocked");
        return;
    }
    %orig;
}

%end

// 调整直播默认清晰度功能
static NSArray<NSString *> *dyyy_qualityRank = nil;

%hook HTSLiveStreamQualityFragment

- (void)setupStreamQuality:(id)arg1 {
    %orig;

    NSString *preferredQuality = [[NSUserDefaults standardUserDefaults] objectForKey:@"DYYYLiveQuality"];
    if (!preferredQuality || [preferredQuality isEqualToString:@"自动"]) {
        NSLog(@"[DYYY] Live quality auto - skipping hook");
        return;
    }

    BOOL preferLower = YES;
    NSLog(@"[DYYY] preferredQuality=%@ preferLower=%@", preferredQuality, @(preferLower));

    NSArray *qualities = self.streamQualityArray;
    if (!qualities || qualities.count == 0) {
        qualities = [self getQualities];
    }
    if (!qualities || qualities.count == 0) {
        return;
    }

    if (!dyyy_qualityRank) {
        dyyy_qualityRank = @[ @"藍光幀彩", @"藍光", @"超清", @"高清", @"標清" ];
    }
    NSArray *orderedNames = dyyy_qualityRank;

    // Map available names to their indices in the provided order
    NSMutableDictionary<NSString *, NSNumber *> *nameToIndex = [NSMutableDictionary dictionary];
    NSMutableArray<NSString *> *availableNames = [NSMutableArray array];
    NSMutableArray<NSNumber *> *rankArray = [NSMutableArray array];
    for (NSInteger i = 0; i < qualities.count; i++) {
        id q = qualities[i];
        NSString *name = nil;
        if ([q respondsToSelector:@selector(name)]) {
            name = [q name];
        } else {
            name = [q valueForKey:@"name"];
        }
        if (name) {
            [availableNames addObject:name];
            nameToIndex[name] = @(i);
            NSInteger rank = [orderedNames indexOfObject:name];
            if (rank != NSNotFound) {
                [rankArray addObject:@(rank)];
            }
        }
    }
    NSLog(@"[DYYY] available qualities: %@", availableNames);

    BOOL qualityDesc = YES; // ranks ascending -> high to low
    BOOL qualityAsc = YES;  // ranks descending -> low to high
    for (NSInteger i = 1; i < rankArray.count; i++) {
        NSInteger prev = rankArray[i - 1].integerValue;
        NSInteger curr = rankArray[i].integerValue;
        if (curr < prev) {
            qualityDesc = NO;
        }
        if (curr > prev) {
            qualityAsc = NO;
        }
    }

    NSInteger count = availableNames.count;
    NSInteger (^convertIndex)(NSInteger) = ^NSInteger(NSInteger idx) {
      if (qualityAsc && !qualityDesc) {
          return count - 1 - idx;
      }
      return idx;
    };

    NSArray *searchOrder = orderedNames;

    NSNumber *indexToUse = nameToIndex[preferredQuality];
    if (indexToUse) {
        NSInteger finalIdx = convertIndex(indexToUse.integerValue);
        NSLog(@"[DYYY] exact quality %@ found at index %ld", preferredQuality, (long)finalIdx);
        [self setResolutionWithIndex:finalIdx isManual:YES beginChange:nil completion:nil];
        return;
    }

    NSInteger targetPos = [orderedNames indexOfObject:preferredQuality];
    if (targetPos == NSNotFound) {
        NSLog(@"[DYYY] preferred quality %@ not in list", preferredQuality);
        return;
    }

    NSInteger step = preferLower ? 1 : -1;
    BOOL applied = NO;
    for (NSInteger pos = targetPos + step; pos >= 0 && pos < searchOrder.count; pos += step) {
        NSString *candidate = searchOrder[pos];
        NSNumber *idx = nameToIndex[candidate];
        if (idx) {
            NSInteger finalIdx = convertIndex(idx.integerValue);
            NSLog(@"[DYYY] fallback quality %@ at index %ld", candidate, (long)finalIdx);
            [self setResolutionWithIndex:finalIdx isManual:YES beginChange:nil completion:nil];
            applied = YES;
            break;
        }
    }
    if (!applied) {
        NSLog(@"[DYYY] no suitable fallback quality found");
    }
}

%end

// 强制启用新版抖音长按 UI（现代风）
%hook AWELongPressPanelDataManager
+ (BOOL)enableModernLongPressPanelConfigWithSceneIdentifier:(id)arg1 {
    return DYYYGetBool(@"DYYYEnableModernPanel");
}
%end

%hook AWELongPressPanelABSettings
+ (NSUInteger)modernLongPressPanelStyleMode {
    if (!DYYYGetBool(@"DYYYEnableModernPanel")) {
        return %orig;
    }

    BOOL forceBlur = DYYYGetBool(@"DYYYLongPressPanelBlur");
    BOOL forceDark = DYYYGetBool(@"DYYYLongPressPanelDark");

    if (forceBlur && forceDark) {
        return 1;
    } else if (!forceBlur && !forceDark) {
        BOOL isDarkMode = [DYYYUtils isDarkMode];
        return isDarkMode ? 1 : 2;
    }
}
%end

%hook AWEModernLongPressPanelUIConfig
+ (NSUInteger)modernLongPressPanelStyleMode {
    if (!DYYYGetBool(@"DYYYEnableModernPanel")) {
        return %orig;
    }

    BOOL forceBlur = DYYYGetBool(@"DYYYLongPressPanelBlur");
    BOOL forceDark = DYYYGetBool(@"DYYYLongPressPanelDark");

    if (forceBlur && forceDark) {
        return 1;
    } else if (!forceBlur && !forceDark) {
        BOOL isDarkMode = [DYYYUtils isDarkMode];
        return isDarkMode ? 1 : 2;
    }
}
%end

// 禁用个人资料自动进入橱窗
%hook AWEUserTabListModel

- (NSInteger)profileLandingTab {
    if (DYYYGetBool(@"DYYYDefaultEnterWorks")) {
        return 0;
    } else {
        return %orig;
    }
}

%end

%group AutoPlay

%hook AWEAwemeDetailTableViewController

- (BOOL)hasIphoneAutoPlaySwitch {
    return YES;
}

%end

%hook AWEAwemeDetailContainerPlayControlConfig

- (BOOL)enableUserProfilePostAutoPlay {
    return YES;
}

%end

%hook AWEFeedIPhoneAutoPlayManager

- (BOOL)isAutoPlayOpen {
    return YES;
}

%end

%hook AWEFeedModuleService

- (BOOL)getFeedIphoneAutoPlayState {
    return YES;
}
%end

%hook AWEFeedIPhoneAutoPlayManager

- (BOOL)getFeedIphoneAutoPlayState {
    BOOL r = %orig;
    return YES;
}
%end

%end

%hook AWEPlayInteractionSpeedController

static BOOL hasChangedSpeed = NO;

- (CGFloat)longPressFastSpeedValue {
    float longPressSpeed = DYYYGetFloat(@"DYYYLongPressSpeed");
    if (longPressSpeed == 0) {
        longPressSpeed = 2.0;
    }
    return longPressSpeed;
}

- (void)changeSpeed:(double)speed {
    float longPressSpeed = DYYYGetFloat(@"DYYYLongPressSpeed");

    if (speed == 2.0) {
        if (!hasChangedSpeed) {
            if (longPressSpeed != 0 && longPressSpeed != 2.0) {
                hasChangedSpeed = YES;
                %orig(longPressSpeed);
                return;
            }
        } else {
            hasChangedSpeed = NO;
            %orig(1.0);
            return;
        }
    }

    if (longPressSpeed == 0 || longPressSpeed == 2) {
        %orig(speed);
        return;
    }
}

%end

%hook UILabel

- (void)setText:(NSString *)text {
    UIView *superview = self.superview;

    if ([superview isKindOfClass:%c(AFDFastSpeedView)] && text) {
        float longPressSpeed = DYYYGetFloat(@"DYYYLongPressSpeed");
        if (longPressSpeed == 0) {
            longPressSpeed = 2.0;
        }

        NSString *speedString = [NSString stringWithFormat:@"%.2f", longPressSpeed];
        if ([speedString hasSuffix:@".00"]) {
            speedString = [speedString substringToIndex:speedString.length - 3];
        } else if ([speedString hasSuffix:@"0"] && [speedString containsString:@"."]) {
            speedString = [speedString substringToIndex:speedString.length - 1];
        }

        if ([text containsString:@"2"]) {
            text = [text stringByReplacingOccurrencesOfString:@"2" withString:speedString];
        }
    }

    %orig(text);
}
%end

// 强制启用保存他人头像
%hook AFDProfileAvatarFunctionManager
- (BOOL)shouldShowSaveAvatarItem {
    BOOL shouldEnable = DYYYGetBool(@"DYYYEnableSaveAvatar");
    if (shouldEnable) {
        return YES;
    }
    return %orig;
}
%end

%hook AWECommentMediaDownloadConfigLivePhoto

bool commentLivePhotoNotWaterMark = DYYYGetBool(@"DYYYCommentLivePhotoNotWaterMark");

- (bool)needClientWaterMark {
    return commentLivePhotoNotWaterMark ? 0 : %orig;
}

- (bool)needClientEndWaterMark {
    return commentLivePhotoNotWaterMark ? 0 : %orig;
}

- (id)watermarkConfig {
    return commentLivePhotoNotWaterMark ? nil : %orig;
}

%end

%hook AWECommentImageModel
- (id)downloadUrl {
    if (DYYYGetBool(@"DYYYCommentNotWaterMark")) {
        return self.originUrl;
    }
    return %orig;
}
%end

%hook _TtC33AWECommentLongPressPanelSwiftImpl37CommentLongPressPanelSaveImageElement

static BOOL isDownloadFlied = NO;

- (BOOL)elementShouldShow {
    BOOL DYYYForceDownloadEmotion = DYYYGetBool(@"DYYYForceDownloadEmotion");
    if (DYYYForceDownloadEmotion) {
        AWECommentLongPressPanelContext *commentPageContext = [self commentPageContext];
        AWECommentModel *selectdComment = [commentPageContext selectdComment];
        if (!selectdComment) {
            AWECommentLongPressPanelParam *params = [commentPageContext params];
            selectdComment = [params selectdComment];
        }
        AWEIMStickerModel *sticker = [selectdComment sticker];
        if (sticker) {
            AWEURLModel *staticURLModel = [sticker staticURLModel];
            NSArray *originURLList = [staticURLModel originURLList];
            if (originURLList.count > 0) {
                return YES;
            }
        }
    }
    return %orig;
}

- (void)elementTapped {
    BOOL DYYYForceDownloadEmotion = DYYYGetBool(@"DYYYForceDownloadEmotion");
    if (DYYYForceDownloadEmotion) {
        AWECommentLongPressPanelContext *commentPageContext = [self commentPageContext];
        AWECommentModel *selectdComment = [commentPageContext selectdComment];
        if (!selectdComment) {
            AWECommentLongPressPanelParam *params = [commentPageContext params];
            selectdComment = [params selectdComment];
        }
        AWEIMStickerModel *sticker = [selectdComment sticker];
        if (sticker) {
            AWEURLModel *staticURLModel = [sticker staticURLModel];
            NSArray *originURLList = [staticURLModel originURLList];
            if (originURLList.count > 0) {
                NSString *urlString = @"";
                if (isDownloadFlied) {
                    urlString = originURLList[originURLList.count - 1];
                    isDownloadFlied = NO;
                } else {
                    urlString = originURLList[0];
                }

                NSURL *heifURL = [NSURL URLWithString:urlString];
                [DYYYManager downloadMedia:heifURL
                                 mediaType:MediaTypeHeic
                                     audio:nil
                                completion:^(BOOL success){
                                }];
                return;
            }
        }
    }
    %orig;
}
%end

%group EnableStickerSaveMenu
static __weak YYAnimatedImageView *targetStickerView = nil;

%hook _TtCV28AWECommentPanelListSwiftImpl6NEWAPI27CommentCellStickerComponent

- (void)handleLongPressWithGes:(UILongPressGestureRecognizer *)gesture {
    if (gesture.state == UIGestureRecognizerStateBegan) {
        if ([gesture.view isKindOfClass:%c(YYAnimatedImageView)]) {
            targetStickerView = (YYAnimatedImageView *)gesture.view;
            NSLog(@"DYYY 長按表情：%@", targetStickerView);
        } else {
            targetStickerView = nil;
        }
    }

    %orig;
}

%end

%hook UIMenu

+ (instancetype)menuWithTitle:(NSString *)title image:(UIImage *)image identifier:(UIMenuIdentifier)identifier options:(UIMenuOptions)options children:(NSArray<UIMenuElement *> *)children {
    BOOL hasAddStickerOption = NO;
    BOOL hasSaveLocalOption = NO;

    for (UIMenuElement *element in children) {
        NSString *elementTitle = nil;

        if ([element isKindOfClass:%c(UIAction)]) {
            elementTitle = [(UIAction *)element title];
        } else if ([element isKindOfClass:%c(UICommand)]) {
            elementTitle = [(UICommand *)element title];
        }

        if ([elementTitle isEqualToString:@"添加到表情"]) {
            hasAddStickerOption = YES;
        } else if ([elementTitle isEqualToString:@"儲存到照片App"]) {
            hasSaveLocalOption = YES;
        }
    }

    if (hasAddStickerOption && !hasSaveLocalOption) {
        NSMutableArray *newChildren = [children mutableCopy];

        UIAction *saveAction = [%c(UIAction) actionWithTitle:@"儲存到照片App"
                                                                 image:nil
                                                            identifier:nil
                                                               handler:^(__kindof UIAction *_Nonnull action) {
                                                                 // 使用全局变量 targetStickerView 保存当前长按的表情
                                                                 if (targetStickerView) {
                                                                     [DYYYManager saveAnimatedSticker:targetStickerView];
                                                                 } else {
                                                                     [DYYYUtils showToast:@"無法取得表情視圖"];
                                                                 }
                                                               }];

        [newChildren addObject:saveAction];
        return %orig(title, image, identifier, options, newChildren);
    }

    return %orig;
}

%end
%end

%hook AWEIMEmoticonPreviewV2

// 添加保存按钮
- (void)layoutSubviews {
    %orig;
    static char kHasSaveButtonKey;
    BOOL DYYYForceDownloadPreviewEmotion = DYYYGetBool(@"DYYYForceDownloadPreviewEmotion");
    if (DYYYForceDownloadPreviewEmotion) {
        if (!objc_getAssociatedObject(self, &kHasSaveButtonKey)) {
            UIButton *saveButton = [UIButton buttonWithType:UIButtonTypeSystem];
            UIImage *downloadIcon = [UIImage systemImageNamed:@"arrow.down.circle"];
            [saveButton setImage:downloadIcon forState:UIControlStateNormal];
            [saveButton setTintColor:[UIColor whiteColor]];
            saveButton.backgroundColor = [UIColor colorWithRed:0.0 green:0.5 blue:0.9 alpha:0.5];

            saveButton.layer.shadowColor = [UIColor blackColor].CGColor;
            saveButton.layer.shadowOffset = CGSizeMake(0, 2);
            saveButton.layer.shadowOpacity = 0.3;
            saveButton.layer.shadowRadius = 3;

            saveButton.translatesAutoresizingMaskIntoConstraints = NO;
            [self addSubview:saveButton];
            CGFloat buttonSize = 24.0;
            saveButton.layer.cornerRadius = buttonSize / 2;

            [NSLayoutConstraint activateConstraints:@[
                [saveButton.bottomAnchor constraintEqualToAnchor:self.bottomAnchor constant:-15], [saveButton.rightAnchor constraintEqualToAnchor:self.rightAnchor constant:-10],
                [saveButton.widthAnchor constraintEqualToConstant:buttonSize], [saveButton.heightAnchor constraintEqualToConstant:buttonSize]
            ]];

            saveButton.userInteractionEnabled = YES;
            [saveButton addTarget:self action:@selector(dyyy_saveButtonTapped:) forControlEvents:UIControlEventTouchUpInside];
            objc_setAssociatedObject(self, &kHasSaveButtonKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        }
    }
}

%new
- (void)dyyy_saveButtonTapped:(UIButton *)sender {
    // 获取表情包URL
    AWEIMEmoticonModel *emoticonModel = self.model;
    if (!emoticonModel) {
        [DYYYUtils showToast:@"無法取得表情包資訊"];
        return;
    }

    NSString *urlString = nil;
    MediaType mediaType = MediaTypeImage;

    // 尝试动态URL
    if ([emoticonModel valueForKey:@"animate_url"]) {
        urlString = [emoticonModel valueForKey:@"animate_url"];
    }
    // 如果没有动态URL，则使用静态URL
    else if ([emoticonModel valueForKey:@"static_url"]) {
        urlString = [emoticonModel valueForKey:@"static_url"];
    }
    // 使用animateURLModel获取URL
    else if ([emoticonModel valueForKey:@"animateURLModel"]) {
        AWEURLModel *urlModel = [emoticonModel valueForKey:@"animateURLModel"];
        if (urlModel.originURLList.count > 0) {
            urlString = urlModel.originURLList[0];
        }
    }

    if (!urlString) {
        [DYYYUtils showToast:@"無法取得表情包連結"];
        return;
    }

    NSURL *url = [NSURL URLWithString:urlString];
    [DYYYManager downloadMedia:url
                     mediaType:MediaTypeHeic
                         audio:nil
                    completion:^(BOOL success){
                    }];
}

%end

static AWEIMReusableCommonCell *currentCell;

%hook AWEIMCustomMenuComponent
- (void)msg_showMenuForBubbleFrameInScreen:(CGRect)bubbleFrame tapLocationInScreen:(CGPoint)tapLocation menuItemList:(id)menuItems moreEmoticon:(BOOL)moreEmoticon onCell:(id)cell extra:(id)extra {
    if (!DYYYGetBool(@"DYYYForceDownloadIMEmotion")) {
        %orig(bubbleFrame, tapLocation, menuItems, moreEmoticon, cell, extra);
        return;
    }
    NSArray *originalMenuItems = menuItems;

    NSMutableArray *newMenuItems = [originalMenuItems mutableCopy];
    currentCell = (AWEIMReusableCommonCell *)cell;

    AWEIMCustomMenuModel *newMenuItem1 = [%c(AWEIMCustomMenuModel) new];
    newMenuItem1.title = @"儲存表情";
    newMenuItem1.imageName = @"im_emoticon_interactive_tab_new";
    newMenuItem1.willPerformMenuActionSelectorBlock = ^(id arg1) {
      AWEIMMessageComponentContext *context = (AWEIMMessageComponentContext *)currentCell.currentContext;
      if ([context.message isKindOfClass:%c(AWEIMGiphyMessage)]) {
          AWEIMGiphyMessage *giphyMessage = (AWEIMGiphyMessage *)context.message;
          if (giphyMessage.giphyURL && giphyMessage.giphyURL.originURLList.count > 0) {
              NSURL *url = [NSURL URLWithString:giphyMessage.giphyURL.originURLList.firstObject];
              [DYYYManager downloadMedia:url
                               mediaType:MediaTypeHeic
                                   audio:nil
                              completion:^(BOOL success){
                              }];
          }
      }
    };
    newMenuItem1.trackerName = @"儲存表情";
    AWEIMMessageComponentContext *context = (AWEIMMessageComponentContext *)currentCell.currentContext;
    if ([context.message isKindOfClass:%c(AWEIMGiphyMessage)]) {
        [newMenuItems addObject:newMenuItem1];
    }
    %orig(bubbleFrame, tapLocation, newMenuItems, moreEmoticon, cell, extra);
}

%end

%hook AWELongVideoControlModel
- (bool)allowDownload {
    return YES;
}
%end

%hook AWELongVideoControlModel
- (long long)preventDownloadType {
    return 0;
}
%end

%hook AWEFeedTabJumpGuideView

- (void)layoutSubviews {
    %orig;
    [self removeFromSuperview];
}

%end

%hook AWEFeedLiveMarkView
- (void)setHidden:(BOOL)hidden {
    if (DYYYGetBool(@"DYYYHideAvatarButton")) {
        hidden = YES;
    }

    %orig(hidden);
}
%end

%hook AWECommentInputBackgroundView
- (void)layoutSubviews {
    %orig;

    if (DYYYGetBool(@"DYYYHideComment")) {
        [self removeFromSuperview];
        return;
    }
}
%end

// 隐藏头像加号和透明
%hook LOTAnimationView
- (void)layoutSubviews {
    %orig;

    // 检查是否需要隐藏加号
    if (DYYYGetBool(@"DYYYHideLOTAnimationView")) {
        [self removeFromSuperview];
        return;
    }

    // 应用透明度设置
    NSString *transparencyValue = [[NSUserDefaults standardUserDefaults] objectForKey:@"DYYYAvatarViewTransparency"];
    if (transparencyValue && transparencyValue.length > 0) {
        CGFloat alphaValue = [transparencyValue floatValue];
        if (alphaValue >= 0.0 && alphaValue <= 1.0) {
            self.alpha = alphaValue;
        }
    }
}
%end

// 首页头像隐藏和透明
%hook AWEAdAvatarView
- (void)layoutSubviews {
    %orig;

    if (DYYYGetBool(@"DYYYHideAvatarButton")) {
        [self removeFromSuperview];
        return;
    }

    // 应用透明度设置
    NSString *transparencyValue = [[NSUserDefaults standardUserDefaults] objectForKey:@"DYYYAvatarViewTransparency"];
    if (transparencyValue && transparencyValue.length > 0) {
        CGFloat alphaValue = [transparencyValue floatValue];
        if (alphaValue >= 0.0 && alphaValue <= 1.0) {
            self.alpha = alphaValue;
        }
    }
}
%end

// 移除同城吃喝玩乐提示框
%hook AWENearbySkyLightCapsuleView
- (void)layoutSubviews {
    if (DYYYGetBool(@"DYYYHideNearbyCapsuleView")) {
        [self removeFromSuperview];
        return;
    }
    %orig;
}
%end

// 移除共创头像列表
%hook AWEPlayInteractionCoCreatorNewInfoView
- (void)layoutSubviews {
    if (DYYYGetBool(@"DYYYHideGongChuang")) {
        [self removeFromSuperview];
        return;
    }
    %orig;
}
%end

// 隐藏右下音乐和取消静音按钮
%hook AFDCancelMuteAwemeView
- (void)layoutSubviews {
    %orig;

    UIView *superview = self.superview;

    if ([superview isKindOfClass:NSClassFromString(@"AWEBaseElementView")]) {
        if (DYYYGetBool(@"DYYYHideCancelMute")) {
            self.hidden = YES;
            return;
        }
    }
}
%end

// 隐藏弹幕按钮
%hook AWEPlayDanmakuInputContainView

- (void)layoutSubviews {
    %orig;

    if (DYYYGetBool(@"DYYYHideDanmuButton")) {
        self.hidden = YES;
        return;
    }
}

%end

// 隐藏评论区免费去看短剧
%hook AWEShowPlayletCommentHeaderView
- (void)layoutSubviews {
    %orig;
    if (DYYYGetBool(@"DYYYHideCommentViews")) {
        self.hidden = YES;
        return;
    }
}

%end

// 隐藏评论区定位
%hook AWEPOIEntryAnchorView

- (void)p_addViews {
    if (DYYYGetBool(@"DYYYHideCommentViews")) {
        return;
    }
    %orig;
}

%end

// 隐藏评论音乐
%hook AWECommentGuideLunaAnchorView
- (void)layoutSubviews {
    %orig;

    if (DYYYGetBool(@"DYYYHideCommentViews")) {
        [self setHidden:YES];
    }

    if (DYYYGetBool(@"DYYYMusicCopyText")) {
        UILabel *label = nil;
        if ([self respondsToSelector:@selector(preTitleLabel)]) {
            label = [self valueForKey:@"preTitleLabel"];
        }
        if (label && [label isKindOfClass:[UILabel class]]) {
            label.text = @"";
        }
    }
}

- (void)p_didClickSong {
    if (DYYYGetBool(@"DYYYMusicCopyText")) {
        // 通过 KVC 拿到内部的 songButton
        UIButton *btn = nil;
        if ([self respondsToSelector:@selector(songButton)]) {
            btn = (UIButton *)[self valueForKey:@"songButton"];
        }

        // 获取歌曲名并复制到剪贴板
        if (btn && [btn isKindOfClass:[UIButton class]]) {
            NSString *song = btn.currentTitle;
            if (song.length) {
                [UIPasteboard generalPasteboard].string = song;
                [DYYYToast showSuccessToastWithMessage:@"歌曲名稱已複製"];
            }
        }
    } else {
        %orig;
    }
}

%end

// Swift 类组 - 这些会在 %ctor 中动态初始化
%group CommentHeaderGeneralGroup
%hook AWECommentPanelHeaderSwiftImpl_CommentHeaderGeneralView
- (void)layoutSubviews {
    %orig;

    if (DYYYGetBool(@"DYYYHideCommentViews")) {
        [self setHidden:YES];
    }
}
%end
%end
%group CommentHeaderGoodsGroup
%hook AWECommentPanelHeaderSwiftImpl_CommentHeaderGoodsView
- (void)layoutSubviews {
    %orig;

    if (DYYYGetBool(@"DYYYHideCommentViews")) {
        [self setHidden:YES];
    }
}
%end
%end
%group CommentHeaderTemplateGroup
%hook AWECommentPanelHeaderSwiftImpl_CommentHeaderTemplateAnchorView
- (void)layoutSubviews {
    %orig;

    if (DYYYGetBool(@"DYYYHideCommentViews")) {
        [self setHidden:YES];
    }
}
%end
%end
%group CommentBottomTipsVCGroup
%hook AWECommentPanelListSwiftImpl_CommentBottomTipsContainerViewController
- (void)viewWillAppear:(BOOL)animated {
    %orig(animated);
    if (DYYYGetBool(@"DYYYHideCommentTips")) {
        ((UIViewController *)self).view.hidden = YES;
    }
}
%end
%end
// Swift 类初始化
%ctor {

    // 动态获取 Swift 类并初始化对应的组
    Class commentHeaderGeneralClass = objc_getClass("AWECommentPanelHeaderSwiftImpl.CommentHeaderGeneralView");
    if (commentHeaderGeneralClass) {
        %init(CommentHeaderGeneralGroup, AWECommentPanelHeaderSwiftImpl_CommentHeaderGeneralView = commentHeaderGeneralClass);
    }

    Class commentHeaderGoodsClass = objc_getClass("AWECommentPanelHeaderSwiftImpl.CommentHeaderGoodsView");
    if (commentHeaderGoodsClass) {
        %init(CommentHeaderGoodsGroup, AWECommentPanelHeaderSwiftImpl_CommentHeaderGoodsView = commentHeaderGoodsClass);
    }

    Class commentHeaderTemplateClass = objc_getClass("AWECommentPanelHeaderSwiftImpl.CommentHeaderTemplateAnchorView");
    if (commentHeaderTemplateClass) {
        %init(CommentHeaderTemplateGroup, AWECommentPanelHeaderSwiftImpl_CommentHeaderTemplateAnchorView = commentHeaderTemplateClass);
    }

    Class tipsVCClass = objc_getClass("AWECommentPanelListSwiftImpl.CommentBottomTipsContainerViewController");
    if (tipsVCClass) {
        %init(CommentBottomTipsVCGroup, AWECommentPanelListSwiftImpl_CommentBottomTipsContainerViewController = tipsVCClass);
    }
}

// 去除隐藏大家都在搜后的留白
%hook AWESearchAnchorListModel

- (BOOL)hideWords {
    return DYYYGetBool(@"DYYYHideCommentViews");
}

%end

// 隐藏观看历史搜索
%hook AWEDiscoverFeedEntranceView
- (id)init {
    if (DYYYGetBool(@"DYYYHideInteractionSearch")) {
        return nil;
    }
    return %orig;
}
%end

// 隐藏校园提示
%hook AWETemplateTagsCommonView

- (void)layoutSubviews {
    %orig;

    if (DYYYGetBool(@"DYYYHideTemplateTags")) {
        UIView *parentView = self.superview;
        if (parentView) {
            parentView.hidden = YES;
        } else {
            self.hidden = YES;
        }
    }
}

%end

%hook ACCGestureResponsibleStickerView

- (void)layoutSubviews {
    %orig;

    if (DYYYGetBool(@"DYYYHideEditTags")) {
        for (UIView *subview in self.subviews) {
            if ([subview isKindOfClass:NSClassFromString(@"ACCEditTagStickerView")]) {
                self.hidden = YES;
                return;
            }
        }
    }

    if (DYYYGetBool(@"DYYYHideChallengeStickers")) {
        for (UIView *subview in self.subviews) {
            if ([subview isKindOfClass:NSClassFromString(@"ACCMordernQuickFlashStickerView")]) {
                self.hidden = YES;
                return;
            }
        }
    }
}

%end

// 去除"我的"加入挑战横幅
%hook AWEPostWorkViewController
- (BOOL)isDouGuideTipViewShow {
    BOOL r = %orig;
    if (DYYYGetBool(@"DYYYHideChallengeStickers")) {
        return YES;
    }
    return r;
}
%end

// 隐藏消息页顶栏头像气泡
%hook AFDSkylightCellBubble
- (void)layoutSubviews {
    %orig;

    if (DYYYGetBool(@"DYYYHideAvatarBubble")) {
        self.hidden = YES;
        return;
    }
}
%end

// 隐藏消息页开启通知提示
%hook AWEIMMessageTabOptPushBannerView

- (instancetype)initWithFrame:(CGRect)frame {
    if (DYYYGetBool(@"DYYYHidePushBanner")) {
        return %orig(CGRectMake(frame.origin.x, frame.origin.y, 0, 0));
    }
    return %orig;
}

%end

// 隐藏合集和声明
%hook AWEAntiAddictedNoticeBarView
- (void)layoutSubviews {
    %orig;

    // 获取 tipsLabel 属性
    UILabel *tipsLabel = [self valueForKey:@"tipsLabel"];

    if (tipsLabel && [tipsLabel isKindOfClass:%c(UILabel)]) {
        NSString *labelText = tipsLabel.text;

        if (labelText) {
            // 明确判断是合集还是作者声明
            if ([labelText containsString:@"合集"]) {
                // 如果是合集，只检查合集的开关
                if (DYYYGetBool(@"DYYYHideTemplateVideo")) {
                    [self removeFromSuperview];
                    return;
                } else if (DYYYGetBool(@"DYYYEnableFullScreen")) {
                    self.backgroundColor = [UIColor clearColor];
                }
            } else {
                // 如果不是合集（即作者声明），只检查声明的开关
                if (DYYYGetBool(@"DYYYHideAntiAddictedNotice")) {
                    [self removeFromSuperview];
                    return;
                }
            }
        }
    }
}
%end

// 隐藏我的添加朋友
%hook AWEProfileNavigationButton
- (void)setupUI {

    if (DYYYGetBool(@"DYYYHideButton")) {
        return;
    }
    %orig;
}
%end

// 隐藏朋友"关注/不关注"按钮
%hook AWEFeedUnfollowFamiliarFollowAndDislikeView
- (void)showUnfollowFamiliarView {
    if (DYYYGetBool(@"DYYYHideFamiliar")) {
        self.hidden = YES;
        return;
    }
    %orig;
}
%end

// 隐藏朋友日常按钮
%hook AWEFamiliarNavView
- (void)layoutSubviews {
    if (DYYYGetBool(@"DYYYHideFamiliar")) {
        self.hidden = YES;
    }
    %orig;
}
%end

// 隐藏分享给朋友提示
%hook AWEPlayInteractionStrongifyShareContentView

- (void)layoutSubviews {
    %orig;
    if (DYYYGetBool(@"DYYYHideShareContentView")) {
        UIView *parentView = self.superview;
        if (parentView) {
            parentView.hidden = YES;
        } else {
            self.hidden = YES;
        }
    }
}

%end

// 移除下面推荐框黑条
%hook AWEPlayInteractionRelatedVideoView
- (void)layoutSubviews {
    %orig;
    if (DYYYGetBool(@"DYYYHideBottomRelated")) {
        [self removeFromSuperview];
    }
}
%end

%hook AWEFeedRelatedSearchTipView
- (void)layoutSubviews {
    %orig;
    if (DYYYGetBool(@"DYYYHideBottomRelated")) {
        [self removeFromSuperview];
    }
}
%end

%hook AWENormalModeTabBarBadgeContainerView

- (void)layoutSubviews {
    %orig;
    if (![[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYHideBottomDot"]) {
        return;
    }

    static char kDYBadgeCacheKey;
    NSArray *badges = objc_getAssociatedObject(self, &kDYBadgeCacheKey);
    if (!badges) {
        NSMutableArray *tmp = [NSMutableArray array];
        for (UIView *subview in [self subviews]) {
            if ([subview isKindOfClass:NSClassFromString(@"DUXBadge")]) {
                [tmp addObject:subview];
            }
        }
        badges = [tmp copy];
        objc_setAssociatedObject(self, &kDYBadgeCacheKey, badges, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }

    for (UIView *badge in badges) {
        badge.hidden = YES;
    }
}

%end

%hook AWELeftSideBarEntranceView
- (void)layoutSubviews {
    %orig;

    UIResponder *responder = self;
    UIViewController *parentVC = nil;
    while ((responder = [responder nextResponder])) {
        if ([responder isKindOfClass:%c(AWEFeedContainerViewController)]) {
            parentVC = (UIViewController *)responder;
            break;
        }
    }

    if (!(parentVC && [[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYHideLeftSideBar"])) {
        return;
    }

    static char kDYLeftSideViewCacheKey;
    NSArray *cachedViews = objc_getAssociatedObject(self, &kDYLeftSideViewCacheKey);
    if (!cachedViews) {
        NSMutableArray *views = [NSMutableArray array];
        for (UIView *subview in self.subviews) {
            if ([subview isKindOfClass:%c(DUXBaseImageView)]) {
                [views addObject:subview];
            }
        }
        cachedViews = [views copy];
        objc_setAssociatedObject(self, &kDYLeftSideViewCacheKey, cachedViews, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }

    for (UIView *v in cachedViews) {
        v.hidden = YES;
    }
}

%end

%hook AWEFeedVideoButton

- (void)layoutSubviews {
    %orig;

    NSString *accessibilityLabel = self.accessibilityLabel;

    BOOL hideBtn = NO;
    BOOL hideLabel = NO;

    if ([accessibilityLabel isEqualToString:@"点赞"]) {
        hideBtn = [[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYHideLikeButton"];
        hideLabel = [[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYHideLikeLabel"];
    } else if ([accessibilityLabel isEqualToString:@"评论"]) {
        hideBtn = [[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYHideCommentButton"];
        hideLabel = [[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYHideCommentLabel"];
    } else if ([accessibilityLabel isEqualToString:@"分享"]) {
        hideBtn = [[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYHideShareButton"];
        hideLabel = [[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYHideShareLabel"];
    } else if ([accessibilityLabel isEqualToString:@"收藏"]) {
        hideBtn = [[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYHideCollectButton"];
        hideLabel = [[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYHideCollectLabel"];
    }

    if (!hideBtn && !hideLabel) {
        return; // 设置未启用，无需额外处理
    }

    if (hideBtn) {
        [self removeFromSuperview];
        return;
    }

    static char kDYLabelCacheKey;
    NSArray *cachedLabels = objc_getAssociatedObject(self, &kDYLabelCacheKey);
    if (!cachedLabels) {
        NSMutableArray *labels = [NSMutableArray array];
        for (UIView *subview in self.subviews) {
            if ([subview isKindOfClass:[UILabel class]]) {
                [labels addObject:subview];
            }
        }
        cachedLabels = [labels copy];
        objc_setAssociatedObject(self, &kDYLabelCacheKey, cachedLabels, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }

    for (UILabel *label in cachedLabels) {
        label.hidden = hideLabel;
    }
}

%end

%hook UIButton

- (void)setTitle:(NSString *)title forState:(UIControlState)state {
    %orig;

    if ([title isEqualToString:@"加入挑战"]) {
        dispatch_async(dispatch_get_main_queue(), ^{
          if (DYYYGetBool(@"DYYYHideChallengeStickers")) {
              UIResponder *responder = self;
              BOOL isInPlayInteractionViewController = NO;

              while ((responder = [responder nextResponder])) {
                  if ([responder isKindOfClass:%c(AWEPlayInteractionViewController)]) {
                      isInPlayInteractionViewController = YES;
                      break;
                  }
              }

              if (isInPlayInteractionViewController) {
                  UIView *parentView = self.superview;
                  if (parentView) {
                      UIView *grandParentView = parentView.superview;
                      if (grandParentView) {
                          [grandParentView removeFromSuperview];
                          return;
                      } else {
                          [parentView removeFromSuperview];
                          return;
                      }
                  } else {
                      [self removeFromSuperview];
                      return;
                  }
              }
          }
        });
    }
}

- (void)layoutSubviews {
    %orig;

    NSString *accessibilityLabel = self.accessibilityLabel;

    if ([accessibilityLabel isEqualToString:@"拍照搜同款"] || [accessibilityLabel isEqualToString:@"扫一扫"]) {
        if (DYYYGetBool(@"DYYYHideScancode")) {
            [self removeFromSuperview];
        }
    }

    if ([accessibilityLabel isEqualToString:@"返回"]) {
        if (DYYYGetBool(@"DYYYHideBack")) {
            UIView *parent = self.superview;
            // 父视图是AWEBaseElementView(排除用户主页返回按钮) 按钮类不是AWENoxusHighlightButton(排除横屏返回按钮)
            if ([parent isKindOfClass:%c(AWEBaseElementView)] && ![self isKindOfClass:%c(AWENoxusHighlightButton)]) {
                [self removeFromSuperview];
            }
            return;
        }
    }
}

%end

%hook AWEIMFeedVideoQuickReplayInputViewController

- (void)viewDidLayoutSubviews {
    %orig;

    if (DYYYGetBool(@"DYYYHideReply")) {
        [self.view removeFromSuperview];
        return;
    }
}

%end

%hook AWEHPSearchBubbleEntranceView
- (void)layoutSubviews {
    %orig;

    if (DYYYGetBool(@"DYYYHideSearchBubble")) {
        self.hidden = YES;
        return;
    }
}

%end

%hook AWEMusicCoverButton

- (void)layoutSubviews {
    %orig;

    NSString *accessibilityLabel = self.accessibilityLabel;

    if ([accessibilityLabel isEqualToString:@"音乐详情"]) {
        if (DYYYGetBool(@"DYYYHideMusicButton")) {
            [self removeFromSuperview];
            return;
        }
    }
}

%end

%hook AWEPlayInteractionListenFeedView
- (void)layoutSubviews {
    %orig;

    if (DYYYGetBool(@"DYYYHideMusicButton")) {
        [self removeFromSuperview];
        return;
    }
}
%end

%hook AWEPlayInteractionFollowPromptView

- (void)layoutSubviews {
    %orig;

    NSString *accessibilityLabel = self.accessibilityLabel;

    if ([accessibilityLabel isEqualToString:@"关注"]) {
        if (DYYYGetBool(@"DYYYHideAvatarButton")) {
            self.hidden = YES;
            return;
        }
        if (DYYYGetBool(@"DYYYHideFollowPromptView")) {
            self.userInteractionEnabled = NO;
            [self removeFromSuperview];
        }
    }
}

%end

%hook AWEPlayInteractionElementMaskView
- (void)layoutSubviews {
    if (DYYYGetBool(@"DYYYHideGradient")) {
        self.hidden = YES;
        return;
    }
    %orig;
}
%end

%hook AWEGradientView
- (void)layoutSubviews {
    if (DYYYGetBool(@"DYYYHideGradient")) {
        UIView *parent = self.superview;
        if ([parent.accessibilityLabel isEqualToString:@"暂停，按钮"] || [parent.accessibilityLabel isEqualToString:@"播放，按钮"] || [parent.accessibilityLabel isEqualToString:@"“切换视角，按钮"]) {
            self.hidden = YES;
        }
        return;
    }
    %orig;
}
%end

%hook AWEHotSpotBlurView
- (void)layoutSubviews {
    if (DYYYGetBool(@"DYYYHideGradient")) {
        self.hidden = YES;
        return;
    }
    %orig;
}
%end

%hook AWEHotSearchInnerBottomView
- (void)layoutSubviews {
    if (DYYYGetBool(@"DYYYHideHotSearch")) {
        self.hidden = YES;
        return;
    }
    %orig;
}
%end

// 隐藏双指缩放虾线
%hook AWELoadingAndVolumeView

- (void)layoutSubviews {
    %orig;
    self.hidden = YES;
    return;
}

%end

// 隐藏状态栏
%hook AWEFeedRootViewController
- (BOOL)prefersStatusBarHidden {
    if (DYYYGetBool(@"DYYYHideStatusbar")) {
        return YES;
    } else {
        if (class_getInstanceMethod([self class], @selector(prefersStatusBarHidden)) != class_getInstanceMethod([%c(AWEFeedRootViewController) class], @selector(prefersStatusBarHidden))) {
            return %orig;
        }
        return NO;
    }
}
%end

// 直播状态栏
%hook IESLiveAudienceViewController
- (BOOL)prefersStatusBarHidden {
    if (DYYYGetBool(@"DYYYHideStatusbar")) {
        return YES;
    } else {
        if (class_getInstanceMethod([self class], @selector(prefersStatusBarHidden)) !=
            class_getInstanceMethod([%c(IESLiveAudienceViewController) class], @selector(prefersStatusBarHidden))) {
            return %orig;
        }
        return NO;
    }
}
%end

// 主页状态栏
%hook AWEAwemeDetailTableViewController
- (BOOL)prefersStatusBarHidden {
    if (DYYYGetBool(@"DYYYHideStatusbar")) {
        return YES;
    } else {
        if (class_getInstanceMethod([self class], @selector(prefersStatusBarHidden)) !=
            class_getInstanceMethod([%c(AWEAwemeDetailTableViewController) class], @selector(prefersStatusBarHidden))) {
            return %orig;
        }
        return NO;
    }
}
%end

// 热点状态栏
%hook AWEAwemeHotSpotTableViewController
- (BOOL)prefersStatusBarHidden {
    if (DYYYGetBool(@"DYYYHideStatusbar")) {
        return YES;
    } else {
        if (class_getInstanceMethod([self class], @selector(prefersStatusBarHidden)) !=
            class_getInstanceMethod([%c(AWEAwemeHotSpotTableViewController) class], @selector(prefersStatusBarHidden))) {
            return %orig;
        }
        return NO;
    }
}
%end

// 图文状态栏
%hook AWEFullPageFeedNewContainerViewController
- (BOOL)prefersStatusBarHidden {
    if (DYYYGetBool(@"DYYYHideStatusbar")) {
        return YES;
    } else {
        if (class_getInstanceMethod([self class], @selector(prefersStatusBarHidden)) !=
            class_getInstanceMethod([%c(AWEFullPageFeedNewContainerViewController) class], @selector(prefersStatusBarHidden))) {
            return %orig;
        }
        return NO;
    }
}
%end

// 隐藏昵称上方元素
%hook AWEFeedTemplateAnchorView

- (void)layoutSubviews {
    %orig;

    BOOL hideFeedAnchor = DYYYGetBool(@"DYYYHideFeedAnchorContainer");
    BOOL hideLocation = DYYYGetBool(@"DYYYHideLocation");

    if (!hideFeedAnchor && !hideLocation)
        return;

    AWECodeGenCommonAnchorBasicInfoModel *anchorInfo = [self valueForKey:@"templateAnchorInfo"];
    if (!anchorInfo || ![anchorInfo respondsToSelector:@selector(name)])
        return;

    NSString *name = [anchorInfo valueForKey:@"name"];
    BOOL isPoi = [name isEqualToString:@"poi_poi"];

    if ((hideFeedAnchor && !isPoi) || (hideLocation && isPoi)) {
        UIView *parentView = self.superview;
        if (parentView) {
            UIView *grandparentView = parentView.superview;
            if (grandparentView && [grandparentView isKindOfClass:%c(AWEBaseElementView)]) {
                [grandparentView removeFromSuperview];
                return;
            }
        }
    }
}

%end

%hook AWEPlayInteractionSearchAnchorView

- (void)layoutSubviews {
    if (DYYYGetBool(@"DYYYHideInteractionSearch")) {
        [self removeFromSuperview];
        return;
    }
    %orig;
}

%end

%hook AWEAwemeMusicInfoView

- (void)layoutSubviews {
    if (DYYYGetBool(@"DYYYHideQuqishuiting")) {
        UIView *parentView = self.superview;
        if (parentView) {
            [parentView removeFromSuperview];
        }
        return;
    }
    %orig;
}

%end

// 隐藏暂停关键词
%hook AWEFeedPauseRelatedWordComponent

- (id)updateViewWithModel:(id)arg0 {
    if (DYYYGetBool(@"DYYYHidePauseVideoRelatedWord")) {
        return nil;
    }
    return %orig;
}

- (id)pauseContentWithModel:(id)arg0 {
    if (DYYYGetBool(@"DYYYHidePauseVideoRelatedWord")) {
        return nil;
    }
    return %orig;
}

- (id)recommendsWords {
    if (DYYYGetBool(@"DYYYHidePauseVideoRelatedWord")) {
        return nil;
    }
    return %orig;
}

- (void)showRelatedRecommendPanelControllerWithSelectedText:(id)arg0 {
    if (DYYYGetBool(@"DYYYHidePauseVideoRelatedWord")) {
        return;
    }
    %orig;
}

- (void)setupUI {
    %orig;
    if (DYYYGetBool(@"DYYYHidePauseVideoRelatedWord")) {
        if (self.relatedView) {
            self.relatedView.hidden = YES;
        }
    }
}

%end

// 隐藏短剧合集
%hook AWETemplatePlayletView

- (void)layoutSubviews {
    %orig;
    if (DYYYGetBool(@"DYYYHideTemplatePlaylet")) {
        [self removeFromSuperview];
    }
}
%end

// 隐藏视频顶部搜索框、隐藏搜索框背景、应用全局透明
%hook AWESearchEntranceView

- (void)layoutSubviews {

    if (DYYYGetBool(@"DYYYHideSearchEntrance")) {
        self.hidden = YES;
        return;
    }
    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYHideSearchEntranceIndicator"]) {
        static char kDYSearchIndicatorKey;
        NSArray *indicatorViews = objc_getAssociatedObject(self, &kDYSearchIndicatorKey);
        if (!indicatorViews) {
            NSMutableArray *tmp = [NSMutableArray array];
            for (UIView *subviews in self.subviews) {
                if ([subviews isKindOfClass:%c(UIImageView)] && [NSStringFromClass([((UIImageView *)subviews).image class]) isEqualToString:@"_UIResizableImage"]) {
                    [tmp addObject:subviews];
                }
            }
            indicatorViews = [tmp copy];
            objc_setAssociatedObject(self, &kDYSearchIndicatorKey, indicatorViews, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        }

        for (UIImageView *imgView in indicatorViews) {
            imgView.hidden = YES;
        }
    }

    // NSString *transparentValue = DYYYGetString(@"DYYYGlobalTransparency");
    // if (transparentValue.length > 0) {
    //     CGFloat alphaValue = transparentValue.floatValue;
    //     if (alphaValue >= 0.0 && alphaValue <= 1.0) {
    //         self.alpha = alphaValue;
    //     }
    // }

    %orig;
}

%end

// 隐藏视频滑条
%hook AWEStoryProgressSlideView

- (void)layoutSubviews {
    %orig;

    BOOL shouldHide = [[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYHideStoryProgressSlide"];
    if (!shouldHide)
        return;

    static char kDYStoryProgressCacheKey;
    UIView *targetView = objc_getAssociatedObject(self, &kDYStoryProgressCacheKey);
    if (!targetView) {
        for (UIView *obj in self.subviews) {
            if ([obj isKindOfClass:NSClassFromString(@"UISlider")] || obj.frame.size.height < 5) {
                targetView = obj.superview;
                break;
            }
        }
        if (targetView) {
            objc_setAssociatedObject(self, &kDYStoryProgressCacheKey, targetView, OBJC_ASSOCIATION_ASSIGN);
        }
    }

    if (targetView) {
        targetView.hidden = YES;
    }
}

%end

// 隐藏好友分享私信
%hook AFDNewFastReplyView

- (void)layoutSubviews {
    %orig;

    if (DYYYGetBool(@"DYYYHidePrivateMessages")) {
        UIView *parentView = self.superview;
        if (parentView) {
            parentView.hidden = YES;
        } else {
            self.hidden = YES;
        }
    }
}

%end

// 隐藏下面底部热点框

%hook AWETemplateHotspotView

- (void)layoutSubviews {
    %orig;
    if (DYYYGetBool(@"DYYYHideHotspot")) {
        [self removeFromSuperview];
        return;
    }
}

%end

%hook AWEHomePageBubbleLiveHeadLabelContentView
- (void)layoutSubviews {
    %orig;
    if (DYYYGetBool(@"DYYYHideConcernCapsuleView")) {
        UIView *parentView = self.superview;
        UIView *grandparentView = parentView.superview;

        if (grandparentView) {
            grandparentView.hidden = YES;
            return;
        } else if (parentView) {
            parentView.hidden = YES;
            return;
        } else {
            self.hidden = YES;
            return;
        }
    }
}
%end

// 隐藏直播发现
%hook AWEFeedLiveTabRevisitControlView

- (void)layoutSubviews {
    %orig;

    if (DYYYGetBool(@"DYYYHideLiveDiscovery")) {
        self.hidden = YES;
        return;
    }
}
%end

%hook IESLiveDynamicRankListEntranceView
- (void)layoutSubviews {
    %orig;
    if (DYYYGetBool(@"DYYYHideLiveDetail")) {
        self.hidden = YES;
        return;
    }
}
%end

%hook IESLiveMatrixEntranceView
- (void)layoutSubviews {
    %orig;
    if (DYYYGetBool(@"DYYYHideLiveDetail")) {
        self.hidden = YES;
        return;
    }
}
%end

%hook IESLiveShortTouchActionView
- (void)layoutSubviews {
    %orig;
    if (DYYYGetBool(@"DYYYHideTouchView")) {
        self.hidden = YES;
        return;
    }
}
%end

%hook IESLiveLotteryAnimationViewNew
- (void)layoutSubviews {
    %orig;
    if (DYYYGetBool(@"DYYYHideTouchView")) {
        self.hidden = YES;
        return;
    }
}
%end

%hook IESLiveConfigurableShortTouchEntranceView
- (void)layoutSubviews {
    %orig;
    if (DYYYGetBool(@"DYYYHideTouchView")) {
        self.hidden = YES;
        return;
    }
}
%end

%hook IESLiveRedEnvelopeAniLynxView
- (void)layoutSubviews {
    %orig;
    if (DYYYGetBool(@"DYYYHideTouchView")) {
        self.hidden = YES;
        return;
    }
}
%end

// 隐藏直播点歌
%hook IESLiveKTVSongIndicatorView
- (void)layoutSubviews {
    %orig;
    if (DYYYGetBool(@"DYYYHideKTVSongIndicator")) {
        self.hidden = YES;
        return;
    }
}
%end

// 隐藏图片滑条
%hook AWEStoryProgressContainerView
- (BOOL)isHidden {
    BOOL originalValue = %orig;
    BOOL customHide = DYYYGetBool(@"DYYYHideDotsIndicator");
    return originalValue || customHide;
}

- (void)setHidden:(BOOL)hidden {
    BOOL forceHide = DYYYGetBool(@"DYYYHideDotsIndicator");
    %orig(forceHide ? YES : hidden);
}
%end

// 隐藏昵称右侧
%hook UILabel
- (void)layoutSubviews {
    %orig;

    BOOL hideRightLabel = DYYYGetBool(@"DYYYHideRightLabel");
    if (!hideRightLabel)
        return;

    NSString *accessibilityLabel = self.accessibilityLabel;
    if (!accessibilityLabel || accessibilityLabel.length == 0)
        return;

    NSString *trimmedLabel = [accessibilityLabel stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    BOOL shouldHide = NO;

    if ([trimmedLabel hasSuffix:@"人共創"]) {
        NSString *prefix = [trimmedLabel substringToIndex:trimmedLabel.length - 3];
        NSCharacterSet *nonDigits = [[NSCharacterSet decimalDigitCharacterSet] invertedSet];
        shouldHide = ([prefix rangeOfCharacterFromSet:nonDigits].location == NSNotFound);
    }

    if (!shouldHide) {
        shouldHide = [trimmedLabel isEqualToString:@"章节要点"] || [trimmedLabel isEqualToString:@"图集"];
    }

    if (shouldHide) {
        self.hidden = YES;

        // 找到父视图是否为 UIStackView
        UIView *superview = self.superview;
        if ([superview isKindOfClass:[UIStackView class]]) {
            UIStackView *stackView = (UIStackView *)superview;
            // 刷新 UIStackView 的布局
            [stackView layoutIfNeeded];
        }
    }
}
%end

// 隐藏顶栏关注下的提示线
%hook AWEFeedMultiTabSelectedContainerView

- (void)setHidden:(BOOL)hidden {
    BOOL forceHide = DYYYGetBool(@"DYYYHideTopBarLine");

    if (forceHide) {
        %orig(YES);
    } else {
        %orig(hidden);
    }
}

%end

%hook AFDRecommendToFriendEntranceLabel
- (void)layoutSubviews {
    %orig;
    if (DYYYGetBool(@"DYYYHideRecommendTips")) {
        if (self.accessibilityLabel) {
            [self removeFromSuperview];
        }
    }
}

%end

// 隐藏自己无公开作品的视图
%hook AWEProfileMixItemCollectionViewCell
- (void)layoutSubviews {
    %orig;
    if (DYYYGetBool(@"DYYYHidePostView")) {
        if ([self.accessibilityLabel isEqualToString:@"私密作品"]) {
            self.hidden = YES;
            return;
        }
    }
}
%end

%hook AWEProfileTaskCardStyleListCollectionViewCell
- (BOOL)shouldShowPublishGuide {
    if (DYYYGetBool(@"DYYYHidePostView")) {
        return NO;
    }
    return %orig;
}
%end

%hook AWEProfileRichEmptyView

- (void)setTitle:(id)title {
    if (DYYYGetBool(@"DYYYHidePostView")) {
        return;
    }
    %orig(title);
}

- (void)setDetail:(id)detail {
    if (DYYYGetBool(@"DYYYHidePostView")) {
        return;
    }
    %orig(detail);
}
%end

// 隐藏关注直播顶端的直播视图
%hook AWENewLiveSkylightViewController

- (void)showSkylight:(BOOL)arg0 animated:(BOOL)arg1 actionMethod:(unsigned long long)arg2 {
    if (DYYYGetBool(@"DYYYHideLiveView")) {
        return;
    }
    %orig(arg0, arg1, arg2);
}

- (void)updateIsSkylightShowing:(BOOL)arg0 {
    if (DYYYGetBool(@"DYYYHideLiveView")) {
        %orig(NO);
    } else {
        %orig(arg0);
    }
}

%end

// 隐藏关注直播
%hook AWEConcernSkylightCapsuleView
- (void)setHidden:(BOOL)hidden {
    if (DYYYGetBool(@"DYYYHideConcernCapsuleView")) {
        %orig(YES);
        return;
    }

    %orig(hidden);
}
%end

%hook AWELiveAutoEnterStyleAView

- (void)layoutSubviews {
    %orig;

    if (DYYYGetBool(@"DYYYHideLiveView")) {
        self.hidden = YES;
        return;
    }
}

%end

// 隐藏同城顶端
%hook AWENearbyFullScreenViewModel

- (void)setShowSkyLight:(id)arg1 {
    if (DYYYGetBool(@"DYYYHideMenuView")) {
        arg1 = nil;
    }
    %orig(arg1);
}

- (void)setHaveSkyLight:(id)arg1 {
    if (DYYYGetBool(@"DYYYHideMenuView")) {
        arg1 = nil;
    }
    %orig(arg1);
}

%end

// 隐藏笔记
%hook AWECorrelationItemTag

- (void)layoutSubviews {
    %orig;
    if (DYYYGetBool(@"DYYYHideItemTag")) {
        self.hidden = YES;
        return;
    }
}

%end

// 隐藏话题
%hook AWEPlayInteractionTemplateButtonGroup
- (void)layoutSubviews {
    if (DYYYGetBool(@"DYYYHideTemplateGroup")) {
        self.hidden = YES;
        return;
    }
    %orig;
}
%end

%hook AWEPlayInteractionViewController

- (void)onVideoPlayerViewDoubleClicked:(id)arg1 {
    BOOL isSwitchOn = DYYYGetBool(@"DYYYDisableDoubleTapLike");
    if (!isSwitchOn) {
        %orig;
    }
}
%end

%hook AFDPureModePageTapController

- (void)onVideoPlayerViewDoubleClicked:(id)arg1 {
    BOOL isSwitchOn = DYYYGetBool(@"DYYYDisableDoubleTapLike");
    if (!isSwitchOn) {
        %orig;
    }
}
%end

// 隐藏右上搜索，但可点击
%hook AWEHPDiscoverFeedEntranceView

- (void)layoutSubviews {
    %orig;

    if (DYYYGetBool(@"DYYYHideDiscover")) {
        UIView *firstSubview = self.subviews.firstObject;
        if ([firstSubview isKindOfClass:[UIImageView class]]) {
            ((UIImageView *)firstSubview).image = nil;
        }
    }
}

%end

// 隐藏点击进入直播间
%hook AWELiveFeedStatusLabel
- (void)layoutSubviews {
    if (DYYYGetBool(@"DYYYHideEnterLive")) {
        UIView *parentView = self.superview;
        UIView *grandparentView = parentView.superview;

        if (grandparentView) {
            grandparentView.hidden = YES;
            return;
        } else if (parentView) {
            parentView.hidden = YES;
            return;
        } else {
            self.hidden = YES;
            return;
        }
    }
    %orig;
}
%end

// 去除消息群直播提示
%hook AWEIMCellLiveStatusContainerView

- (void)p_initUI {
    if (![[NSUserDefaults standardUserDefaults] objectForKey:@"DYYYHideGroupLiveIndicator"])
        %orig;
}
%end

%hook AWELiveStatusIndicatorView

- (void)layoutSubviews {
    if (DYYYGetBool(@"DYYYHideGroupLiveIndicator")) {
        self.hidden = YES;
        return;
    }
    %orig;
}
%end

%hook AWELiveSkylightCatchView
- (void)layoutSubviews {

    if (DYYYGetBool(@"DYYYHideLiveCapsuleView")) {
        self.hidden = YES;
        return;
    }
    %orig;
}

%end

// 隐藏首页直播胶囊
%hook AWEHPTopTabItemBadgeContentView

- (void)layoutSubviews {
    %orig;
    if (DYYYGetBool(@"DYYYHideLiveCapsuleView")) {
        self.hidden = YES;
        return;
    }
}

%end

// 隐藏群商店
%hook AWEIMFansGroupTopDynamicDomainTemplateView
- (void)layoutSubviews {
    if (DYYYGetBool(@"DYYYHideGroupShop")) {
        self.hidden = YES;
        return;
    }
    %orig;
}
%end

// 去除群聊天输入框上方快捷方式
%hook AWEIMInputActionBarInteractor

- (void)p_setupUI {
    if (DYYYGetBool(@"DYYYHideGroupInputActionBar")) {
        self.hidden = YES;
        return;
    }
    %orig;
}
%end

// 隐藏相机定位
%hook AWETemplateCommonView
- (void)layoutSubviews {
    %orig;
    if (DYYYGetBool(@"DYYYHideCameraLocation")) {
        [self removeFromSuperview];
    }
}
%end

// 隐藏侧栏红点
%hook AWEHPTopBarCTAItemView

- (void)showRedDot {
    if (![[NSUserDefaults standardUserDefaults] objectForKey:@"DYYYHideSidebarDot"])
        %orig;
}

- (void)hideCountRedDot {
    if (![[NSUserDefaults standardUserDefaults] objectForKey:@"DYYYHideSidebarDot"])
        %orig;
}

- (void)layoutSubviews {
    %orig;

    if (![[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYHideSidebarDot"]) {
        return;
    }

    static char kDYSidebarBadgeCacheKey;
    NSArray *cachedBadges = objc_getAssociatedObject(self, &kDYSidebarBadgeCacheKey);
    if (!cachedBadges) {
        NSMutableArray *badges = [NSMutableArray array];
        for (UIView *subview in self.subviews) {
            if ([subview isKindOfClass:%c(DUXBadge)]) {
                [badges addObject:subview];
            }
        }
        cachedBadges = [badges copy];
        objc_setAssociatedObject(self, &kDYSidebarBadgeCacheKey, cachedBadges, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }

    for (UIView *badge in cachedBadges) {
        badge.hidden = YES;
    }
}
%end

%hook AWELeftSideBarEntranceView

- (void)setRedDot:(id)redDot {
    %orig(nil);
}

- (void)setNumericalRedDot:(id)numericalRedDot {
    %orig(nil);
}

%end

// 隐藏搜同款
%hook ACCStickerContainerView
- (void)layoutSubviews {
    %orig;
    if (DYYYGetBool(@"DYYYHideSearchSame")) {
        [self removeFromSuperview];
    }
}
%end

// 隐藏礼物展馆
%hook BDXWebView
- (void)layoutSubviews {
    %orig;

    BOOL enabled = DYYYGetBool(@"DYYYHideGiftPavilion");
    if (!enabled)
        return;

    NSString *title = [self valueForKey:@"title"];

    if ([title containsString:@"任務Banner"] || [title containsString:@"活動Banner"]) {
        self.hidden = YES;
    }
}
%end

%hook AWEVideoTypeTagView

- (void)setupUI {
    if (![[NSUserDefaults standardUserDefaults] objectForKey:@"DYYYHideLiveGIF"])
        %orig;
}
%end

// 隐藏直播广场
%hook IESLiveFeedDrawerEntranceView
- (void)layoutSubviews {
    %orig;

    if (DYYYGetBool(@"DYYYHideLivePlayground")) {
        self.hidden = YES;
    }
}

%end

// 隐藏顶栏红点
%hook AWEHPTopTabItemBadgeContentView
- (id)showBadgeWithBadgeStyle:(NSUInteger)style badgeConfig:(id)config count:(NSInteger)count text:(id)text {
    BOOL hideEnabled = DYYYGetBool(@"DYYYHideTopBarBadge");

    if (hideEnabled) {
        return nil;
    } else {
        return %orig(style, config, count, text);
    }
}
%end

// 隐藏直播退出清屏、投屏按钮
%hook IESLiveButton

- (void)layoutSubviews {
    %orig;
    BOOL hideClear = [[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYHideLiveRoomClear"];
    BOOL hideMirror = [[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYHideLiveRoomMirroring"];
    BOOL hideFull = [[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYHideLiveRoomFullscreen"];

    if (!(hideClear || hideMirror || hideFull)) {
        return;
    }

    NSString *label = self.accessibilityLabel;
    if (hideClear && [label isEqualToString:@"退出清屏"] && self.superview) {
        self.superview.hidden = YES;
        return;
    } else if (hideMirror && [label isEqualToString:@"投屏"] && self.superview) {
        self.superview.hidden = YES;
        return;
    } else if (hideFull && [label isEqualToString:@"横屏"] && self.superview) {
        static char kDYLiveButtonCacheKey;
        NSArray *cached = objc_getAssociatedObject(self, &kDYLiveButtonCacheKey);
        if (!cached) {
            cached = [self.subviews copy];
            objc_setAssociatedObject(self, &kDYLiveButtonCacheKey, cached, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        }
        for (UIView *subview in cached) {
            subview.hidden = YES;
        }
        return;
    }
}

%end

// 隐藏直播间右上方关闭直播按钮
%hook IESLiveLayoutPlaceholderView
- (void)layoutSubviews {
    %orig;
    if (DYYYGetBool(@"DYYYHideLiveRoomClose")) {
        self.hidden = YES;
        return;
    }
}
%end

// 隐藏直播间流量弹窗
%hook AWELiveFlowAlertView
- (void)layoutSubviews {
    %orig;
    if (DYYYGetBool(@"DYYYHideCellularAlert")) {
        self.hidden = YES;
        return;
    }
}
%end

// 隐藏直播间商品信息
%hook IESECLivePluginLayoutView
- (void)layoutSubviews {
    if (DYYYGetBool(@"DYYYHideLiveGoodsMsg")) {
        self.hidden = YES;
        return;
    }
    %orig;
}
%end

%hook IESLiveBottomRightCardView
- (void)layoutSubviews {

    if (DYYYGetBool(@"DYYYHideLiveGoodsMsg")) {
        self.hidden = YES;
        return;
    }
    %orig;
}
%end

%hook IESLiveGameCPExplainCardContainerImpl
- (void)layoutSubviews {
    %orig;
    if (DYYYGetBool(@"DYYYHideLiveGoodsMsg")) {
        self.hidden = YES;
        return;
    }
}
%end

%hook AWEPOILivePurchaseAtmosphereView
- (void)layoutSubviews {
    if (DYYYGetBool(@"DYYYHideLiveGoodsMsg") && self.superview) {
        self.superview.hidden = YES;
        return;
    }
    %orig;
}
%end

%hook IESLiveActivityBannnerView
- (void)layoutSubviews {
    if (DYYYGetBool(@"DYYYHideLiveGoodsMsg")) {
        self.hidden = YES;
        return;
    }
    %orig;
}
%end

// 隐藏直播间点赞动画
%hook HTSLiveDiggView
- (void)setIconImageView:(UIImageView *)arg1 {
    if (DYYYGetBool(@"DYYYHideLiveLikeAnimation")) {
        %orig(nil);
    } else {
        %orig(arg1);
    }
}
%end

// 隐藏直播间文字贴纸
%hook IESLiveStickerView
- (void)layoutSubviews {
    if (DYYYGetBool(@"DYYYHideStickerView")) {
        self.hidden = YES;
        return;
    }
    %orig;
}
%end

// 预约直播
%hook IESLivePreAnnouncementPanelViewNew
- (void)layoutSubviews {
    if (DYYYGetBool(@"DYYYHideStickerView")) {
        self.hidden = YES;
        return;
    }
    %orig;
}
%end

// 隐藏会员进场特效
%hook IESLiveDynamicUserEnterView
- (void)layoutSubviews {
    if (DYYYGetBool(@"DYYYHideLivePopup")) {
        self.hidden = YES;
        return;
    }
    %orig;
}
%end

// 隐藏特殊进场特效
%hook PlatformCanvasView
- (void)layoutSubviews {
    %orig;
    if (DYYYGetBool(@"DYYYHideLivePopup")) {
        UIView *pview = self.superview;
        UIView *gpview = pview.superview;
        // 基于accessibilitylabel的判断
        BOOL isLynxView = [pview isKindOfClass:%c(UILynxView)] && [gpview isKindOfClass:%c(LynxView)] && [gpview.accessibilityLabel isEqualToString:@"lynxview"];
        // 基于最近的视图控制器IESLiveAudienceViewController的判断
        UIViewController *vc = [DYYYUtils firstAvailableViewControllerFromView:self];
        BOOL isLiveAudienceVC = [vc isKindOfClass:%c(IESLiveAudienceViewController)];
        if (isLynxView && isLiveAudienceVC) {
            self.hidden = YES;
        }
    }
    return;
}
%end

%hook IESLiveDanmakuVariousView
- (void)layoutSubviews {
    if (DYYYGetBool(@"DYYYHideLiveDanmaku")) {
        self.hidden = YES;
        return;
    }
    %orig;
}

%end

%hook IESLiveHotMessageView
- (void)layoutSubviews {

    if (DYYYGetBool(@"DYYYHideLiveHotMessage")) {
        self.hidden = YES;
        return;
    }
    %orig;
}
%end

// 屏蔽青少年模式弹窗
%hook AWETeenModeAlertView
- (BOOL)show {
    if (DYYYGetBool(@"DYYYHideteenmode")) {
        return NO;
    }
    return %orig;
}
%end

// 屏蔽青少年模式弹窗
%hook AWETeenModeSimpleAlertView
- (BOOL)show {
    if (DYYYGetBool(@"DYYYHideteenmode")) {
        return NO;
    }
    return %orig;
}
%end

%hook AWEAwemeModel

- (id)initWithDictionary:(id)arg1 error:(id *)arg2 {
    id orig = %orig;
    if (orig && [self contentFilter])
        return nil;
    return orig;
}

- (id)init {
    id orig = %orig;
    if (orig && [self contentFilter])
        return nil;
    return orig;
}

%new
- (BOOL)contentFilter {
    BOOL noAds = DYYYGetBool(@"DYYYNoAds");
    BOOL skipLive = DYYYGetBool(@"DYYYSkipLive");
    BOOL skipHotSpot = DYYYGetBool(@"DYYYSkipHotSpot");
    BOOL filterHDR = DYYYGetBool(@"DYYYFilterFeedHDR");

    BOOL shouldFilterAds = noAds && (self.isAds);
    BOOL shouldFilterHotSpot = skipHotSpot && self.hotSpotLynxCardModel;
    BOOL shouldFilterRecLive = skipLive && (self.cellRoom != nil);
    BOOL shouldFilterHDR = NO;
    BOOL shouldFilterLowLikes = NO;
    BOOL shouldFilterKeywords = NO;
    BOOL shouldFilterProp = NO;
    BOOL shouldFilterTime = NO;
    BOOL shouldFilterUser = NO;

    // 获取用户设置的需要过滤的关键词
    NSString *filterKeywords = [[NSUserDefaults standardUserDefaults] objectForKey:@"DYYYFilterKeywords"];
    NSArray *keywordsList = nil;

    if (filterKeywords.length > 0) {
        keywordsList = [filterKeywords componentsSeparatedByString:@","];
    }

    // 过滤包含指定拍同款的视频
    NSString *filterProp = [[NSUserDefaults standardUserDefaults] objectForKey:@"DYYYFilterProp"];
    NSArray *propKeywordsList = nil;

    if (filterProp.length > 0) {
        propKeywordsList = [filterProp componentsSeparatedByString:@","];
    }

    // 获取需要过滤的用户列表
    NSString *filterUsers = [[NSUserDefaults standardUserDefaults] objectForKey:@"DYYYFilterUsers"];

    // 检查是否需要过滤特定用户
    if (self.shareRecExtra && ![self.shareRecExtra isEqual:@""] && filterUsers.length > 0 && self.author) {
        NSArray *usersList = [filterUsers componentsSeparatedByString:@","];
        NSString *currentShortID = self.author.shortID;
        NSString *currentNickname = self.author.nickname;

        if (currentShortID.length > 0) {
            for (NSString *userInfo in usersList) {
                // 解析"昵称-id"格式
                NSArray *components = [userInfo componentsSeparatedByString:@"-"];
                if (components.count >= 2) {
                    NSString *userId = [components lastObject];
                    NSString *userNickname = [[components subarrayWithRange:NSMakeRange(0, components.count - 1)] componentsJoinedByString:@"-"];

                    if ([userId isEqualToString:currentShortID]) {
                        shouldFilterUser = YES;
                        break;
                    }
                }
            }
        }
    }

    // 只有当shareRecExtra不为空时才过滤点赞量低的视频和关键词
    if (self.shareRecExtra && ![self.shareRecExtra isEqual:@""]) {
        NSInteger filterLowLikesThreshold = DYYYGetInteger(@"DYYYFilterLowLikes");
        // 过滤低点赞量视频
        if (filterLowLikesThreshold > 0) {
            AWESearchAwemeExtraModel *searchExtraModel = [self searchExtraModel];
            if (!searchExtraModel) {
                AWEAwemeStatisticsModel *statistics = self.statistics;
                if (statistics && statistics.diggCount) {
                    shouldFilterLowLikes = statistics.diggCount.integerValue < filterLowLikesThreshold;
                }
            }
        }

        // 过滤包含特定关键词的视频
        if (keywordsList.count > 0) {
            // 检查视频标题
            if (self.descriptionString.length > 0) {
                for (NSString *keyword in keywordsList) {
                    NSString *trimmedKeyword = [keyword stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
                    if (trimmedKeyword.length > 0 && [self.descriptionString containsString:trimmedKeyword]) {
                        shouldFilterKeywords = YES;
                        break;
                    }
                }
            }
        }

        // 过滤包含特定道具的视频
        if (propKeywordsList.count > 0 && self.propGuideV2) {
            NSString *propName = self.propGuideV2.propName;
            if (propName.length > 0) {
                for (NSString *propKeyword in propKeywordsList) {
                    NSString *trimmedKeyword = [propKeyword stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
                    if (trimmedKeyword.length > 0 && [propName containsString:trimmedKeyword]) {
                        shouldFilterProp = YES;
                        break;
                    }
                }
            }
        }

        // 过滤视频发布时间
        long long currentTimestamp = (long long)[[NSDate date] timeIntervalSince1970];
        NSInteger daysThreshold = DYYYGetInteger(@"DYYYFilterTimeLimit");
        if (daysThreshold > 0) {
            NSTimeInterval videoTimestamp = [self.createTime doubleValue];
            if (videoTimestamp > 0) {
                NSTimeInterval threshold = daysThreshold * 86400.0;
                NSTimeInterval current = (NSTimeInterval)currentTimestamp;
                NSTimeInterval timeDifference = current - videoTimestamp;
                shouldFilterTime = (timeDifference > threshold);
            }
        }
    }

    // 检查是否为HDR视频
    if (filterHDR && self.video && self.video.bitrateModels) {
        for (id bitrateModel in self.video.bitrateModels) {
            NSNumber *hdrType = [bitrateModel valueForKey:@"hdrType"];
            NSNumber *hdrBit = [bitrateModel valueForKey:@"hdrBit"];

            // 如果hdrType=1且hdrBit=10，则视为HDR视频
            if (hdrType && [hdrType integerValue] == 1 && hdrBit && [hdrBit integerValue] == 10) {
                shouldFilterHDR = YES;
                break;
            }
        }
    }
    return shouldFilterAds || shouldFilterRecLive || shouldFilterHotSpot || shouldFilterHDR || shouldFilterLowLikes || shouldFilterKeywords || shouldFilterProp || shouldFilterTime || shouldFilterUser;
}

- (AWEECommerceLabel *)ecommerceBelowLabel {
    if (DYYYGetBool(@"DYYYHideHisShop")) {
        return nil;
    }
    return %orig;
}

- (bool)preventDownload {
    return NO;
}

- (void)setAdLinkType:(long long)arg1 {
    if (DYYYGetBool(@"DYYYNoAds")) {
        arg1 = 0;
    }
    %orig;
}

// 固定设置为 1，启用自定义背景色
- (NSUInteger)awe_playerBackgroundViewShowType {
    if ([[NSUserDefaults standardUserDefaults] objectForKey:@"DYYYVideoBGColor"]) {
        return 1;
    }
    return %orig;
}

- (UIColor *)awe_smartBackgroundColor {
    NSString *colorHex = [[NSUserDefaults standardUserDefaults] objectForKey:@"DYYYVideoBGColor"];
    if (colorHex && colorHex.length > 0) {
        CGFloat screenWidth = [UIScreen mainScreen].bounds.size.width;
        UIColor *customColor = [DYYYUtils colorFromSchemeHexString:colorHex targetWidth:screenWidth];
        if (customColor)
            return customColor;
    }
    return %orig;
}

%end

%hook MTKView

- (void)layoutSubviews {
    %orig;
    UIViewController *vc = [DYYYUtils firstAvailableViewControllerFromView:self];
    Class playVCClass = NSClassFromString(@"AWEPlayVideoViewController");
    if (vc && playVCClass && [vc isKindOfClass:playVCClass]) {
        NSString *colorHex = [[NSUserDefaults standardUserDefaults] objectForKey:@"DYYYVideoBGColor"];
        if (colorHex && colorHex.length > 0) {
            CGFloat screenWidth = [UIScreen mainScreen].bounds.size.width;
            UIColor *customColor = [DYYYUtils colorFromSchemeHexString:colorHex targetWidth:screenWidth];
            if (customColor)
                self.backgroundColor = customColor;
        }
    }
}

%end

// 拦截开屏广告
%hook BDASplashControllerView
+ (id)alloc {
    BOOL noAds = DYYYGetBool(@"DYYYNoAds");
    if (noAds) {
        return nil;
    }
    return %orig;
}
%end

// 去除启动视频广告
%hook AWEAwesomeSplashFeedCellOldAccessoryView

- (id)ddExtraView {
    if (DYYYGetBool(@"DYYYNoAds")) {
        return NULL;
    }

    return %orig;
}

%end

// 去广告功能
%hook AwemeAdManager
- (void)showAd {
    if (DYYYGetBool(@"DYYYNoAds"))
        return;
    %orig;
}
%end

%hook AWEPlayInteractionUserAvatarView
- (void)layoutSubviews {
    %orig;

    if (![[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYHideFollowPromptView"]) {
        return;
    }

    static char kDYAvatarCacheKey;
    NSArray *viewCache = objc_getAssociatedObject(self, &kDYAvatarCacheKey);
    if (!viewCache) {
        NSMutableArray *tmp = [NSMutableArray array];
        for (UIView *subview in self.subviews) {
            if ([subview isMemberOfClass:[UIView class]]) {
                [tmp addObject:subview];
            }
        }
        viewCache = [tmp copy];
        objc_setAssociatedObject(self, &kDYAvatarCacheKey, viewCache, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }

    for (UIView *container in viewCache) {
        for (UIView *child in container.subviews) {
            child.alpha = 0.0;
        }
    }
}
%end

%hook AWEPlayInteractionViewController

- (void)onPlayer:(id)arg0 didDoubleClick:(id)arg1 {
    BOOL isPopupEnabled = DYYYGetBool(@"DYYYEnableDoubleTapMenu");
    BOOL isDirectCommentEnabled = DYYYGetBool(@"DYYYEnableDoubleOpenComment");

    // 直接打开评论区的情况
    if (isDirectCommentEnabled) {
        [self performCommentAction];
        return;
    }

    if (isPopupEnabled) {
        AWEAwemeModel *awemeModel = nil;

        awemeModel = [self performSelector:@selector(awemeModel)];

        AWEVideoModel *videoModel = awemeModel.video;
        AWEMusicModel *musicModel = awemeModel.music;
        NSURL *audioURL = nil;
        if (musicModel && musicModel.playURL && musicModel.playURL.originURLList.count > 0) {
            audioURL = [NSURL URLWithString:musicModel.playURL.originURLList.firstObject];
        }

        // 确定内容类型（视频或图片）
        BOOL isImageContent = (awemeModel.awemeType == 68);
        // 判断是否为新版实况照片
        BOOL isNewLivePhoto = (awemeModel.video && awemeModel.animatedImageVideoInfo != nil);
        NSString *downloadTitle;

        if (isImageContent) {
            AWEImageAlbumImageModel *currentImageModel = nil;
            if (awemeModel.currentImageIndex > 0 && awemeModel.currentImageIndex <= awemeModel.albumImages.count) {
                currentImageModel = awemeModel.albumImages[awemeModel.currentImageIndex - 1];
            } else {
                currentImageModel = awemeModel.albumImages.firstObject;
            }

            if (awemeModel.albumImages.count > 1) {
                downloadTitle = (currentImageModel.clipVideo != nil || awemeModel.isLivePhoto) ? @"儲存目前原況" : @"儲存目前圖片";
            } else {
                downloadTitle = (currentImageModel.clipVideo != nil || awemeModel.isLivePhoto) ? @"儲存原況" : @"儲存圖片";
            }
        } else if (isNewLivePhoto) {
            downloadTitle = @"儲存原況";
        } else {
            downloadTitle = @"儲存影片";
        }

        AWEUserActionSheetView *actionSheet = [[NSClassFromString(@"AWEUserActionSheetView") alloc] init];
        NSMutableArray *actions = [NSMutableArray array];

        // 添加下载选项
        if (DYYYGetBool(@"DYYYDoubleTapDownload") || ![[NSUserDefaults standardUserDefaults] objectForKey:@"DYYYDoubleTapDownload"]) {

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
                                                            [DYYYUtils showToast:@"圖片儲存已取消"];
                                                        }
                                                      }];
                                  } else {
                                      [DYYYUtils showToast:@"沒有找到合適格式的圖片"];
                                  }
                              }
                          } else if (isNewLivePhoto) {
                              // 新版实况照片
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
                          } else {
                              if (videoModel.h264URL && videoModel.h264URL.originURLList.count > 0) {
                                  NSURL *url = [NSURL URLWithString:videoModel.h264URL.originURLList.firstObject];
                                  [DYYYManager downloadMedia:url
                                                   mediaType:MediaTypeVideo
                                                       audio:audioURL
                                                  completion:^(BOOL success){
                                                  }];
                              }
                          }
                        }];
            [actions addObject:downloadAction];

            // 如果是图集，添加下载所有图片选项
            if (isImageContent && awemeModel.albumImages.count > 1) {
                // 检查是否有实况照片
                BOOL hasLivePhoto = NO;
                for (AWEImageAlbumImageModel *imageModel in awemeModel.albumImages) {
                    if (imageModel.clipVideo != nil) {
                        hasLivePhoto = YES;
                        break;
                    }
                }

                NSString *actionTitle = hasLivePhoto ? @"儲存所有原況" : @"儲存所有圖片";

                AWEUserSheetAction *downloadAllAction = [NSClassFromString(@"AWEUserSheetAction")
                    actionWithTitle:actionTitle
                            imgName:nil
                            handler:^{
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
                                  [DYYYUtils showToast:@"沒有找到合適格式的圖片"];
                              }
                            }];
                [actions addObject:downloadAllAction];
            }
        }

        // 添加下载音频选项
        if (DYYYGetBool(@"DYYYDoubleTapDownloadAudio") || ![[NSUserDefaults standardUserDefaults] objectForKey:@"DYYYDoubleTapDownloadAudio"]) {

            AWEUserSheetAction *downloadAudioAction = [NSClassFromString(@"AWEUserSheetAction") actionWithTitle:@"儲存音訊"
                                                                                                        imgName:nil
                                                                                                        handler:^{
                                                                                                          if (musicModel && musicModel.playURL && musicModel.playURL.originURLList.count > 0) {
                                                                                                              NSURL *url = [NSURL URLWithString:musicModel.playURL.originURLList.firstObject];
                                                                                                              [DYYYManager downloadMedia:url mediaType:MediaTypeAudio audio:nil completion:nil];
                                                                                                          }
                                                                                                        }];
            [actions addObject:downloadAudioAction];
        }

        // 添加接口保存选项
        if (DYYYGetBool(@"DYYYDoubleInterfaceDownload")) {
            NSString *apiKey = [[NSUserDefaults standardUserDefaults] objectForKey:@"DYYYInterfaceDownload"];
            if (apiKey.length > 0) {
                AWEUserSheetAction *apiDownloadAction = [NSClassFromString(@"AWEUserSheetAction") actionWithTitle:@"接口儲存"
                                                                                                          imgName:nil
                                                                                                          handler:^{
                                                                                                            NSString *shareLink = [awemeModel valueForKey:@"shareURL"];
                                                                                                            if (shareLink.length == 0) {
                                                                                                                [DYYYUtils showToast:@"無法取得分享連結"];
                                                                                                                return;
                                                                                                            }

                                                                                                            // 使用封裝的方法進行解析下載
                                                                                                            [DYYYManager parseAndDownloadVideoWithShareLink:shareLink apiKey:apiKey];
                                                                                                          }];
                [actions addObject:apiDownloadAction];
            }
        }

        // 添加制作视频功能
        if (DYYYGetBool(@"DYYYDoubleCreateVideo") || ![[NSUserDefaults standardUserDefaults] objectForKey:@"DYYYDoubleCreateVideo"]) {
            if (isImageContent) {
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
                                        [DYYYUtils showToast:[NSString stringWithFormat:@"影片製作失敗: %@", message]];
                                    }
                                  }];
                            }];
                [actions addObject:createVideoAction];
            }
        }

        // 添加复制文案选项
        if (DYYYGetBool(@"DYYYDoubleTapCopyDesc") || ![[NSUserDefaults standardUserDefaults] objectForKey:@"DYYYDoubleTapCopyDesc"]) {

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
        if (DYYYGetBool(@"DYYYDoubleTapComment") || ![[NSUserDefaults standardUserDefaults] objectForKey:@"DYYYDoubleTapComment"]) {

            AWEUserSheetAction *openCommentAction = [NSClassFromString(@"AWEUserSheetAction") actionWithTitle:@"打開評論"
                                                                                                      imgName:nil
                                                                                                      handler:^{
                                                                                                        [self performCommentAction];
                                                                                                      }];
            [actions addObject:openCommentAction];
        }

        // 添加分享选项
        if (DYYYGetBool(@"DYYYDoubleTapshowSharePanel") || ![[NSUserDefaults standardUserDefaults] objectForKey:@"DYYYDoubleTapshowSharePanel"]) {

            AWEUserSheetAction *showSharePanel = [NSClassFromString(@"AWEUserSheetAction") actionWithTitle:@"分享影片"
                                                                                                   imgName:nil
                                                                                                   handler:^{
                                                                                                     [self showSharePanel];
                                                                                                   }];
            [actions addObject:showSharePanel];
        }

        // 添加点赞视频选项
        if (DYYYGetBool(@"DYYYDoubleTapLike") || ![[NSUserDefaults standardUserDefaults] objectForKey:@"DYYYDoubleTapLike"]) {

            AWEUserSheetAction *likeAction = [NSClassFromString(@"AWEUserSheetAction") actionWithTitle:@"點讚影片"
                                                                                               imgName:nil
                                                                                               handler:^{
                                                                                                 [self performLikeAction];
                                                                                               }];
            [actions addObject:likeAction];
        }

        // 添加长按面板
        if (DYYYGetBool(@"DYYYDoubleTapshowDislikeOnVideo") || ![[NSUserDefaults standardUserDefaults] objectForKey:@"DYYYDoubleTapshowDislikeOnVideo"]) {

            AWEUserSheetAction *showDislikeOnVideo = [NSClassFromString(@"AWEUserSheetAction") actionWithTitle:@"長按面板"
                                                                                                       imgName:nil
                                                                                                       handler:^{
                                                                                                         [self showDislikeOnVideo];
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

%hook AFDPrivacyHalfScreenViewController

%new
- (void)updateDarkModeAppearance {
    BOOL isDarkMode = [DYYYUtils isDarkMode];

    UIView *contentView = self.view.subviews.count > 1 ? self.view.subviews[1] : nil;
    if (contentView) {
        if (isDarkMode) {
            contentView.backgroundColor = [UIColor colorWithRed:0.13 green:0.13 blue:0.13 alpha:1.0];
        } else {
            contentView.backgroundColor = [UIColor whiteColor];
        }
    }

    // 修改标题文本颜色
    if (self.titleLabel) {
        if (isDarkMode) {
            self.titleLabel.textColor = [UIColor whiteColor];
        } else {
            self.titleLabel.textColor = [UIColor blackColor];
        }
    }

    // 修改内容文本颜色
    if (self.contentLabel) {
        if (isDarkMode) {
            self.contentLabel.textColor = [UIColor lightGrayColor];
        } else {
            self.contentLabel.textColor = [UIColor darkGrayColor];
        }
    }

    // 修改左侧按钮颜色和文字颜色
    if (self.leftCancelButton) {
        if (isDarkMode) {
            [self.leftCancelButton setBackgroundColor:[UIColor colorWithRed:0.25 green:0.25 blue:0.25 alpha:1.0]]; // 暗色模式按钮背景色
            [self.leftCancelButton setTitleColor:[UIColor lightGrayColor] forState:UIControlStateNormal];          // 暗色模式文字颜色
        } else {
            [self.leftCancelButton setBackgroundColor:[UIColor colorWithRed:0.9 green:0.9 blue:0.9 alpha:1.0]]; // 默认按钮背景色
            [self.leftCancelButton setTitleColor:[UIColor darkTextColor] forState:UIControlStateNormal];        // 默认文字颜色
        }
    }
}

- (void)viewDidLoad {
    %orig;
    [self updateDarkModeAppearance];
}

- (void)viewWillAppear:(BOOL)animated {
    %orig;
    [self updateDarkModeAppearance];
}

- (void)configWithImageView:(UIImageView *)imageView
                  lockImage:(UIImage *)lockImage
           defaultLockState:(BOOL)defaultLockState
             titleLabelText:(NSString *)titleText
           contentLabelText:(NSString *)contentText
       leftCancelButtonText:(NSString *)leftButtonText
     rightConfirmButtonText:(NSString *)rightButtonText
       rightBtnClickedBlock:(void (^)(void))rightBtnBlock
     leftButtonClickedBlock:(void (^)(void))leftBtnBlock {

    %orig;
    [self updateDarkModeAppearance];
}

%end

%hook UITextField

- (void)willMoveToWindow:(UIWindow *)newWindow {
    %orig;

    if (newWindow) {
        BOOL isDarkMode = [DYYYUtils isDarkMode];
        self.keyboardAppearance = isDarkMode ? UIKeyboardAppearanceDark : UIKeyboardAppearanceLight;
    }
}

- (BOOL)becomeFirstResponder {
    BOOL isDarkMode = [DYYYUtils isDarkMode];
    self.keyboardAppearance = isDarkMode ? UIKeyboardAppearanceDark : UIKeyboardAppearanceLight;
    return %orig;
}

%end

%hook UITextView

- (void)willMoveToWindow:(UIWindow *)newWindow {
    %orig;

    if (newWindow) {
        BOOL isDarkMode = [DYYYUtils isDarkMode];
        self.keyboardAppearance = isDarkMode ? UIKeyboardAppearanceDark : UIKeyboardAppearanceLight;
    }
}

- (BOOL)becomeFirstResponder {
    BOOL isDarkMode = [DYYYUtils isDarkMode];
    self.keyboardAppearance = isDarkMode ? UIKeyboardAppearanceDark : UIKeyboardAppearanceLight;
    return %orig;
}

%end

// 底栏高度
static CGFloat tabHeight = 0;
static CGFloat originalTabHeight = 0;

%hook AWENormalModeTabBar

- (void)layoutSubviews {
    %orig;

    if (originalTabHeight == 0 && self.frame.size.height > 30) {
        originalTabHeight = self.frame.size.height;
    }

    CGFloat customHeight = DYYYGetFloat(@"DYYYTabBarHeight");
    if (customHeight > 0) {
        tabHeight = customHeight;
    } else if (originalTabHeight > 0) {
        tabHeight = originalTabHeight;
    } else {
        tabHeight = self.frame.size.height;
    }

    if (tabHeight <= 0)
        return;

    if ([self respondsToSelector:@selector(setDesiredHeight:)]) {
        ((void (*)(id, SEL, double))objc_msgSend)(self, @selector(setDesiredHeight:), tabHeight);
    }

    if (fabs(self.frame.size.height - tabHeight) > 0.1) {
        CGRect frame = self.frame;
        frame.size.height = tabHeight;
        if (self.superview) {
            frame.origin.y = self.superview.bounds.size.height - tabHeight;
        }
        self.frame = frame;
    }

    BOOL hideShop = DYYYGetBool(@"DYYYHideShopButton");
    BOOL hideMsg = DYYYGetBool(@"DYYYHideMessageButton");
    BOOL hideFri = DYYYGetBool(@"DYYYHideFriendsButton");
    BOOL hideMe = DYYYGetBool(@"DYYYHideMyButton");

    NSMutableArray *visibleButtons = [NSMutableArray array];
    NSMutableArray *buttonsToRemove = [NSMutableArray array];
    BOOL isPad = (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad);
    UIView *ipadContainerView = nil;

    Class generalButtonClass = %c(AWENormalModeTabBarGeneralButton);
    Class plusButtonClass = %c(AWENormalModeTabBarGeneralPlusButton);
    Class tabBarButtonClass = %c(UITabBarButton);

    for (UIView *subview in self.subviews) {
        if ([subview isKindOfClass:generalButtonClass] || [subview isKindOfClass:plusButtonClass]) {
            NSString *label = subview.accessibilityLabel;
            BOOL shouldHide = NO;
            if ([label isEqualToString:@"商城"])
                shouldHide = hideShop;
            else if ([label containsString:@"消息"])
                shouldHide = hideMsg;
            else if ([label containsString:@"朋友"])
                shouldHide = hideFri;
            else if ([label containsString:@"我"])
                shouldHide = hideMe;

            if (shouldHide) {
                [buttonsToRemove addObject:subview];
            } else {
                [visibleButtons addObject:subview];
            }
        } else if ([subview isKindOfClass:tabBarButtonClass]) {
            [buttonsToRemove addObject:subview];
        } else if (isPad && ipadContainerView == nil && [subview class] == [UIView class] && fabs(subview.frame.size.width - self.bounds.size.width) > 0.1) {
            ipadContainerView = subview;
        }
    }

    for (UIView *button in buttonsToRemove) {
        button.userInteractionEnabled = NO;
        [button removeFromSuperview];
    }

    [visibleButtons sortUsingComparator:^NSComparisonResult(UIView *a, UIView *b) {
      return [@(a.frame.origin.x) compare:@(b.frame.origin.x)];
    }];

    if (isPad) {
        // iPad端布局逻辑
        CGFloat containerWidth = ipadContainerView ? ipadContainerView.bounds.size.width : self.bounds.size.width;
        CGFloat offsetX = ipadContainerView ? ipadContainerView.frame.origin.x : 0;
        CGFloat buttonWidth = (visibleButtons.count > 0) ? (containerWidth / visibleButtons.count) : 0;

        // 在目标容器内均匀分布按钮
        for (NSInteger i = 0; i < visibleButtons.count; i++) {
            UIView *button = visibleButtons[i];
            button.frame = CGRectMake(offsetX + (i * buttonWidth), button.frame.origin.y, buttonWidth, button.frame.size.height);
        }
    } else {
        // iPhone端布局逻辑
        CGFloat totalWidth = self.bounds.size.width;
        CGFloat buttonWidth = (visibleButtons.count > 0) ? (totalWidth / visibleButtons.count) : 0;

        for (NSInteger i = 0; i < visibleButtons.count; i++) {
            UIView *button = visibleButtons[i];
            button.frame = CGRectMake(i * buttonWidth, button.frame.origin.y, buttonWidth, button.frame.size.height);
        }
    }
}

- (void)setHidden:(BOOL)hidden {
    %orig(hidden);

    // 禁用首页刷新功能
    if (DYYYGetBool(@"DYYYDisableHomeRefresh")) {
        Class generalButtonClass = %c(AWENormalModeTabBarGeneralButton);
        for (UIView *subview in self.subviews) {
            if ([subview isKindOfClass:generalButtonClass]) {
                AWENormalModeTabBarGeneralButton *button = (AWENormalModeTabBarGeneralButton *)subview;
                if ([button.accessibilityLabel isEqualToString:@"首页"]) {
                    // status == 2 表示选中状态
                    button.userInteractionEnabled = (button.status != 2);
                }
            }
        }
    }

    // 背景和分隔线处理
    BOOL hideBottomBg = DYYYGetBool(@"DYYYHideBottomBg");
    BOOL enableFullScreen = DYYYGetBool(@"DYYYEnableFullScreen");

    UIView *backgroundView = nil;
    for (UIView *subview in self.subviews) {
        if ([subview class] == [UIView class]) {
            BOOL hasImageView = NO;
            for (UIView *childView in subview.subviews) {
                if ([childView isKindOfClass:[UIImageView class]]) {
                    hasImageView = YES;
                    break;
                }
            }
            if (hasImageView) {
                backgroundView = subview;
                break;
            }
        }
    }

    if (backgroundView) {
        if (hideBottomBg) {
            backgroundView.hidden = YES;
        } else if (enableFullScreen) {
            BOOL isHomeSelected = NO;
            BOOL isFriendsSelected = NO;
            Class generalButtonClass = %c(AWENormalModeTabBarGeneralButton);

            for (UIView *subview in self.subviews) {
                if ([subview isKindOfClass:generalButtonClass]) {
                    AWENormalModeTabBarGeneralButton *button = (AWENormalModeTabBarGeneralButton *)subview;
                    if (button.status == 2) {
                        if ([button.accessibilityLabel isEqualToString:@"首页"])
                            isHomeSelected = YES;
                        else if ([button.accessibilityLabel containsString:@"朋友"])
                            isFriendsSelected = YES;
                    }
                }
            }

            BOOL hideFriendsButton = DYYYGetBool(@"DYYYHideFriendsButton");
            BOOL shouldShowBackground = isHomeSelected || (isFriendsSelected && !hideFriendsButton);
            backgroundView.hidden = shouldShowBackground;
        }
    }

    if (enableFullScreen) {
        for (UIView *subview in self.subviews) {
            if (subview.frame.size.height > 0 && subview.frame.size.height <= 0.5 && subview.frame.size.width > 300) {
                subview.hidden = YES;
            }
        }
    }
}

%end

%hook AWEConcernCellLastView
- (void)layoutSubviews {
    %orig;

    if (DYYYGetBool(@"DYYYEnableFullScreen") && tabHeight > 0) {
        for (UIView *subview in self.subviews) {
            CGRect frame = subview.frame;
            frame.origin.y -= tabHeight;
            subview.frame = frame;
        }
    }
}
%end

%hook AWECommentContainerViewController

- (void)viewDidAppear:(BOOL)animated {
    %orig;
    dyyyCommentViewVisible = YES;
    updateSpeedButtonVisibility();
    updateClearButtonVisibility();
    NSString *transparentValue = [[NSUserDefaults standardUserDefaults] objectForKey:@"DYYYTopBarTransparent"];
    if (transparentValue && transparentValue.length > 0) {
        CGFloat alphaValue = [transparentValue floatValue];
        if (alphaValue >= 0.0 && alphaValue <= 1.0) {

            UIView *parentView = self.view.superview;
            if (parentView) {
                for (UIView *subview in parentView.subviews) {
                    if ([subview.accessibilityLabel isEqualToString:@"搜索"]) {
                        CGFloat finalAlpha = (alphaValue < 0.011) ? 0.011 : alphaValue;
                        subview.alpha = finalAlpha;
                    }
                }
            }
        }
    }
}

- (void)viewDidDisappear:(BOOL)animated {
    %orig;
    dyyyCommentViewVisible = NO;
    updateSpeedButtonVisibility();
    updateClearButtonVisibility();
}

- (void)viewDidLayoutSubviews {
    %orig;

    if (!DYYYGetBool(@"DYYYEnableCommentBlur"))
        return;

    Class containerViewClass = NSClassFromString(@"AWECommentInputViewSwiftImpl.CommentInputContainerView");
    NSArray<UIView *> *containerViews = [DYYYUtils findAllSubviewsOfClass:containerViewClass inView:self.view];
    for (UIView *containerView in containerViews) {
        for (UIView *subview in containerView.subviews) {
            if (subview.hidden == NO && subview.backgroundColor && CGColorGetAlpha(subview.backgroundColor.CGColor) == 1) {
                float userTransparency = [[[NSUserDefaults standardUserDefaults] objectForKey:@"DYYYCommentBlurTransparent"] floatValue];
                if (userTransparency <= 0 || userTransparency > 1) {
                    userTransparency = 0.8;
                }
                [DYYYUtils applyBlurEffectToView:subview transparency:userTransparency blurViewTag:999];
            }
        }
    }

    Class middleContainerClass = NSClassFromString(@"AWECommentInputViewSwiftImpl.CommentInputViewMiddleContainer");
    NSArray<UIView *> *middleContainers = [DYYYUtils findAllSubviewsOfClass:middleContainerClass inView:self.view];
    for (UIView *middleContainer in middleContainers) {
        BOOL containsDanmu = NO;
        for (UIView *innerSubviewCheck in middleContainer.subviews) {
            if ([innerSubviewCheck isKindOfClass:[UILabel class]] && [((UILabel *)innerSubviewCheck).text containsString:@"彈幕"]) {
                containsDanmu = YES;
                break;
            }
        }

        if (containsDanmu) {
            UIView *parentView = middleContainer.superview;
            for (UIView *innerSubview in parentView.subviews) {
                if ([innerSubview isKindOfClass:[UIView class]]) {
                    if (innerSubview.subviews.count > 0) {
                        innerSubview.subviews[0].hidden = YES;
                    }

                    UIView *whiteBackgroundView = [[UIView alloc] initWithFrame:innerSubview.bounds];
                    whiteBackgroundView.backgroundColor = [UIColor whiteColor];
                    whiteBackgroundView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
                    [innerSubview addSubview:whiteBackgroundView];
                    break;
                }
            }
        } else {
            for (UIView *subview in middleContainer.subviews) {
                if (subview.hidden == NO && subview.backgroundColor && CGColorGetAlpha(subview.backgroundColor.CGColor) == 1) {
                    [DYYYUtils applyBlurEffectToView:subview transparency:0.2f blurViewTag:999];
                }
            }
        }
    }
}

%end

// 开启评论区毛玻璃后滚动区域填满底部
%hook AWEListKitMagicCollectionView

- (void)layoutSubviews {
    %orig;

    if (!DYYYGetBool(@"DYYYEnableCommentBlur")) {
        return;
    }

    UICollectionView *collectionView = (UICollectionView *)self;

    UIView *superview = collectionView.superview;
    CGRect targetFrame = superview.bounds;
    if (superview == nil || CGSizeEqualToSize(targetFrame.size, CGSizeZero) || CGRectEqualToRect(collectionView.frame, targetFrame)) {
        return;
    }

    collectionView.frame = targetFrame;
}

%end

%hook UIView
- (id)initWithFrame:(CGRect)frame {
    UIView *view = %orig;
    if (hideButton && hideButton.isElementsHidden) {
        for (NSString *className in targetClassNames) {
            if ([view isKindOfClass:NSClassFromString(className)]) {
                if ([view isKindOfClass:NSClassFromString(@"AWELeftSideBarEntranceView")]) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                      UIViewController *controller = [hideButton findViewController:view];
                      if ([controller isKindOfClass:NSClassFromString(@"AWEFeedContainerViewController")]) {
                          view.alpha = 0.0;
                      }
                    });
                    break;
                }
                view.alpha = 0.0;
                break;
            }
        }
    }
    return view;
}

- (void)didAddSubview:(UIView *)subview {
    %orig;
    if (hideButton && hideButton.isElementsHidden) {
        for (NSString *className in targetClassNames) {
            if ([subview isKindOfClass:NSClassFromString(className)]) {
                if ([subview isKindOfClass:NSClassFromString(@"AWELeftSideBarEntranceView")]) {
                    UIViewController *controller = [hideButton findViewController:subview];
                    if ([controller isKindOfClass:NSClassFromString(@"AWEFeedContainerViewController")]) {
                        subview.alpha = 0.0;
                    }
                    break;
                }
                subview.alpha = 0.0;
                break;
            }
        }
    }
}

- (void)willMoveToSuperview:(UIView *)newSuperview {
    %orig;
    if (hideButton && hideButton.isElementsHidden) {
        for (NSString *className in targetClassNames) {
            if ([self isKindOfClass:NSClassFromString(className)]) {
                if ([self isKindOfClass:NSClassFromString(@"AWELeftSideBarEntranceView")]) {
                    UIViewController *controller = [hideButton findViewController:self];
                    if ([controller isKindOfClass:NSClassFromString(@"AWEFeedContainerViewController")]) {
                        self.alpha = 0.0;
                    }
                    break;
                }
                self.alpha = 0.0;
                break;
            }
        }
    }
}
- (void)layoutSubviews {
    %orig;

    if (DYYYGetBool(@"DYYYEnableFullScreen")) {
        if (self.frame.size.height == tabHeight && tabHeight > 0) {
            UIViewController *vc = [DYYYUtils firstAvailableViewControllerFromView:self];
            if ([vc isKindOfClass:NSClassFromString(@"AWEMixVideoPanelDetailTableViewController")] || [vc isKindOfClass:NSClassFromString(@"AWECommentInputViewController")] ||
                [vc isKindOfClass:NSClassFromString(@"AWEAwemeDetailTableViewController")]) {
                self.backgroundColor = [UIColor clearColor];
            }
        }
    }

    if (DYYYGetBool(@"DYYYEnableFullScreen") || DYYYGetBool(@"DYYYEnableCommentBlur")) {
        UIViewController *vc = [DYYYUtils firstAvailableViewControllerFromView:self];
        if ([vc isKindOfClass:%c(AWEPlayInteractionViewController)]) {
            for (UIView *subview in self.subviews) {
                if ([subview isKindOfClass:[UIView class]] && subview.backgroundColor && CGColorEqualToColor(subview.backgroundColor.CGColor, [UIColor blackColor].CGColor)) {
                    subview.hidden = YES;
                }
            }
        }
    }
}

- (void)setFrame:(CGRect)frame {
    if (![NSThread isMainThread]) {
        dispatch_async(dispatch_get_main_queue(), ^{
          [self setFrame:frame];
        });
        return;
    }

    BOOL enableBlur = DYYYGetBool(@"DYYYEnableCommentBlur");
    BOOL enableFS = DYYYGetBool(@"DYYYEnableFullScreen");
    BOOL hideAvatar = DYYYGetBool(@"DYYYHideAvatarList");

    Class SkylightListViewClass = NSClassFromString(@"AWEIMSkylightListView");
    if (hideAvatar && SkylightListViewClass && [self isKindOfClass:SkylightListViewClass]) {
        frame = CGRectZero;
        %orig(frame);
        return;
    }

    UIViewController *vc = [DYYYUtils firstAvailableViewControllerFromView:self];
    Class DetailVCClass = NSClassFromString(@"AWEMixVideoPanelDetailTableViewController");
    Class PlayVCClass1 = NSClassFromString(@"AWEAwemePlayVideoViewController");
    Class PlayVCClass2 = NSClassFromString(@"AWEDPlayerFeedPlayerViewController");

    BOOL isDetailVC = (DetailVCClass && [vc isKindOfClass:DetailVCClass]);
    BOOL isPlayVC = ((PlayVCClass1 && [vc isKindOfClass:PlayVCClass1]) || (PlayVCClass2 && [vc isKindOfClass:PlayVCClass2]));

    if (isPlayVC && enableBlur) {
        if (frame.origin.x != 0) {
            return;
        }
    }

    if (isPlayVC && enableFS) {
        if (frame.origin.x != 0 && frame.origin.y != 0) {
            %orig(frame);
            return;
        }
        CGRect superF = self.superview.frame;
        if (CGRectGetHeight(superF) > 0 && CGRectGetHeight(frame) > 0 && CGRectGetHeight(frame) < CGRectGetHeight(superF)) {
            CGFloat diff = CGRectGetHeight(superF) - CGRectGetHeight(frame);
            if (fabs(diff - tabHeight) < 1.0) {
                frame.size.height = CGRectGetHeight(superF);
            }
        }
        %orig(frame);
        return;
    }

    %orig(frame);
}

%end

%hook AWEPlayInteractionViewController
- (void)viewDidLayoutSubviews {
    %orig;
    if (isFloatSpeedButtonEnabled) {
        BOOL hasRightStack = NO;
        Class stackClass = NSClassFromString(@"AWEElementStackView");
        for (UIView *sub in self.view.subviews) {
            if ([sub isKindOfClass:stackClass] && ([sub.accessibilityLabel isEqualToString:@"right"] || [DYYYUtils containsSubviewOfClass:NSClassFromString(@"AWEPlayInteractionUserAvatarView")
                                                                                                                                   inView:self.view])) {
                hasRightStack = YES;
                break;
            }
        }
        if (hasRightStack) {
            if (speedButton == nil) {
                speedButtonSize = [[NSUserDefaults standardUserDefaults] floatForKey:@"DYYYSpeedButtonSize"] ?: 32.0;
                CGRect screenBounds = [UIScreen mainScreen].bounds;
                CGRect initialFrame = CGRectMake((screenBounds.size.width - speedButtonSize) / 2, (screenBounds.size.height - speedButtonSize) / 2, speedButtonSize, speedButtonSize);
                speedButton = [[FloatingSpeedButton alloc] initWithFrame:initialFrame];
                speedButton.interactionController = self;
                showSpeedX = [[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYSpeedButtonShowX"];
                updateSpeedButtonUI();
            } else {
                [speedButton resetButtonState];
                if (speedButton.interactionController == nil || speedButton.interactionController != self) {
                    speedButton.interactionController = self;
                }
                if (speedButton.frame.size.width != speedButtonSize) {
                    CGPoint center = speedButton.center;
                    CGRect newFrame = CGRectMake(0, 0, speedButtonSize, speedButtonSize);
                    speedButton.frame = newFrame;
                    speedButton.center = center;
                    speedButton.layer.cornerRadius = speedButtonSize / 2;
                }
            }
            dyyyInteractionViewVisible = YES;
            UIWindow *keyWindow = [UIApplication sharedApplication].keyWindow;
            if (keyWindow && ![speedButton isDescendantOfView:keyWindow]) {
                [keyWindow addSubview:speedButton];
                [speedButton loadSavedPosition];
                [speedButton resetFadeTimer];
            }
        }
    }

    if (!DYYYGetBool(@"DYYYEnableFullScreen")) {
        return;
    }

    UIViewController *parentVC = self.parentViewController;
    int maxIterations = 3;
    int count = 0;

    while (parentVC && count < maxIterations) {
        if ([parentVC isKindOfClass:%c(AFDPlayRemoteFeedTableViewController)]) {
            return;
        }
        parentVC = parentVC.parentViewController;
        count++;
    }

    if (!self.view.superview) {
        return;
    }

    CGRect frame = self.view.frame;
    CGFloat screenWidth = [UIScreen mainScreen].bounds.size.width;
    CGFloat superviewHeight = self.view.superview.frame.size.height;

    if (frame.size.width != screenWidth && frame.size.height < superviewHeight) {
        return;
    }

    NSString *currentReferString = self.referString;

    BOOL useFullHeight = [currentReferString isEqualToString:@"general_search"] || [currentReferString isEqualToString:@"chat"] || [currentReferString isEqualToString:@"search_result"] ||
                         [currentReferString isEqualToString:@"close_friends_moment"] || [currentReferString isEqualToString:@"offline_mode"] || [currentReferString isEqualToString:@"challenge"] ||
                         currentReferString == nil;

    if (useFullHeight) {
        frame.size.height = superviewHeight;
    } else {
        frame.size.height = superviewHeight - tabHeight;
    }

    if (fabs(frame.size.height - self.view.frame.size.height) > 0.5) {
        self.view.frame = frame;
    }
}

- (void)viewDidDisappear:(BOOL)animated {
    %orig;
    BOOL hasRightStack = NO;
    Class stackClass = NSClassFromString(@"AWEElementStackView");
    for (UIView *sub in self.view.subviews) {
        if ([sub isKindOfClass:stackClass] && ([sub.accessibilityLabel isEqualToString:@"right"] || [DYYYUtils containsSubviewOfClass:NSClassFromString(@"AWEPlayInteractionUserAvatarView")
                                                                                                                               inView:self.view])) {
            hasRightStack = YES;
            break;
        }
    }
    if (hasRightStack) {
        dyyyInteractionViewVisible = NO;
        dyyyCommentViewVisible = self.isCommentVCShowing;
        updateSpeedButtonVisibility();
        updateClearButtonVisibility();
    }
}

%new
- (UIViewController *)firstAvailableUIViewController {
    UIResponder *responder = [self.view nextResponder];
    while (responder != nil) {
        if ([responder isKindOfClass:[UIViewController class]]) {
            return (UIViewController *)responder;
        }
        responder = [responder nextResponder];
    }
    return nil;
}

%new
- (void)speedButtonTapped:(UIButton *)sender {
    [(FloatingSpeedButton *)sender resetFadeTimer];
    NSArray *speeds = getSpeedOptions();
    if (speeds.count == 0)
        return;

    NSInteger currentIndex = getCurrentSpeedIndex();
    NSInteger newIndex = (currentIndex + 1) % speeds.count;

    setCurrentSpeedIndex(newIndex);

    float newSpeed = [speeds[newIndex] floatValue];

    NSString *formattedSpeed;
    if (fmodf(newSpeed, 1.0) == 0) {
        formattedSpeed = [NSString stringWithFormat:@"%.0f", newSpeed];
    } else if (fmodf(newSpeed * 10, 1.0) == 0) {
        formattedSpeed = [NSString stringWithFormat:@"%.1f", newSpeed];
    } else {
        formattedSpeed = [NSString stringWithFormat:@"%.2f", newSpeed];
    }

    if (showSpeedX) {
        formattedSpeed = [formattedSpeed stringByAppendingString:@"x"];
    }

    [sender setTitle:formattedSpeed forState:UIControlStateNormal];

    [UIView animateWithDuration:0.1
        delay:0
        options:UIViewAnimationOptionCurveEaseOut
        animations:^{
          sender.transform = CGAffineTransformMakeScale(1.1, 1.1);
        }
        completion:^(BOOL finished) {
          [UIView animateWithDuration:0.1
                                delay:0
                              options:UIViewAnimationOptionCurveEaseIn
                           animations:^{
                             sender.transform = CGAffineTransformIdentity;
                           }
                           completion:nil];
        }];

    BOOL speedApplied = NO;

    UIViewController *rootVC = [UIApplication sharedApplication].keyWindow.rootViewController;
    while (rootVC.presentedViewController) {
        rootVC = rootVC.presentedViewController;
    }

    NSArray *viewControllers = findViewControllersInHierarchy(rootVC);

    for (UIViewController *vc in viewControllers) {
        if ([vc isKindOfClass:%c(AWEAwemePlayVideoViewController)]) {
            [(AWEAwemePlayVideoViewController *)vc setVideoControllerPlaybackRate:newSpeed];
            speedApplied = YES;
        }
        if ([vc isKindOfClass:%c(AWEDPlayerFeedPlayerViewController)]) {
            [(AWEDPlayerFeedPlayerViewController *)vc setVideoControllerPlaybackRate:newSpeed];
            speedApplied = YES;
        }
    }

    if (!speedApplied) {
        [DYYYUtils showToast:@"無法找到影片控制器"];
    }
}

%new
- (void)buttonTouchDown:(UIButton *)sender {
    [UIView animateWithDuration:0.1
                     animations:^{
                       sender.alpha = 0.7;
                       sender.transform = CGAffineTransformMakeScale(0.95, 0.95);
                     }];
}

%new
- (void)buttonTouchUp:(UIButton *)sender {
    [UIView animateWithDuration:0.1
                     animations:^{
                       sender.alpha = 1.0;
                       sender.transform = CGAffineTransformIdentity;
                     }];
}

%end

%hook AWEAwemePlayVideoViewController

- (void)setIsAutoPlay:(BOOL)arg0 {
    %orig(arg0);
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
      if ([[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYUserAgreementAccepted"]) {
          float defaultSpeed = [[NSUserDefaults standardUserDefaults] floatForKey:@"DYYYDefaultSpeed"];
          if (defaultSpeed > 0 && defaultSpeed != 1) {
              dispatch_async(dispatch_get_main_queue(), ^{
                [self setVideoControllerPlaybackRate:defaultSpeed];
              });
          }
      }
      float speed = getCurrentSpeed();
      if (speed != 1.0) {
          dispatch_async(dispatch_get_main_queue(), ^{
            [self adjustPlaybackSpeed:speed];
          });
      }
    });
}

- (void)prepareForDisplay {
    %orig;

    BOOL autoRestoreSpeed = [[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYAutoRestoreSpeed"];
    if (autoRestoreSpeed) {
        setCurrentSpeedIndex(0);
    }
    float speed = getCurrentSpeed();
    if (speed != 1.0) {
        [self adjustPlaybackSpeed:speed];
    }
    updateSpeedButtonUI();
}

%new
- (void)adjustPlaybackSpeed:(float)speed {
    [self setVideoControllerPlaybackRate:speed];
}

%end

%hook AWEDPlayerFeedPlayerViewController

- (void)viewDidLayoutSubviews {
    %orig;
    if (DYYYGetBool(@"DYYYEnableFullScreen")) {
        UIView *contentView = self.contentView;
        if (contentView && contentView.superview) {
            CGRect frame = contentView.frame;
            CGFloat parentHeight = contentView.superview.frame.size.height;
            if (tabHeight > 0) {
                if (frame.size.height == parentHeight - tabHeight) {
                    frame.size.height = parentHeight;
                    contentView.frame = frame;
                } else if (frame.size.height == parentHeight - (tabHeight * 2)) {
                    frame.size.height = parentHeight - tabHeight;
                    contentView.frame = frame;
                }
            } else {
                if (frame.size.height == parentHeight - tabHeight) {
                    frame.size.height = parentHeight;
                    contentView.frame = frame;
                } else if (frame.size.height == parentHeight - (tabHeight * 2)) {
                    frame.size.height = parentHeight - tabHeight;
                    contentView.frame = frame;
                }
            }
        }
    }
}

- (void)setIsAutoPlay:(BOOL)arg0 {
    %orig(arg0);
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
      if ([[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYUserAgreementAccepted"]) {
          float defaultSpeed = [[NSUserDefaults standardUserDefaults] floatForKey:@"DYYYDefaultSpeed"];
          if (defaultSpeed > 0 && defaultSpeed != 1) {
              dispatch_async(dispatch_get_main_queue(), ^{
                [self setVideoControllerPlaybackRate:defaultSpeed];
              });
          }
      }
      float speed = getCurrentSpeed();
      if (speed != 1.0) {
          dispatch_async(dispatch_get_main_queue(), ^{
            [self adjustPlaybackSpeed:speed];
          });
      }
    });
}

- (void)prepareForDisplay {
    %orig;
    BOOL autoRestoreSpeed = [[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYAutoRestoreSpeed"];
    if (autoRestoreSpeed) {
        setCurrentSpeedIndex(0);
    }
    float speed = getCurrentSpeed();
    if (speed != 1.0) {
        [self adjustPlaybackSpeed:speed];
    }
    updateSpeedButtonUI();
}

%new
- (void)adjustPlaybackSpeed:(float)speed {
    [self setVideoControllerPlaybackRate:speed];
}

%end

%hook AWEFeedTableView
- (void)layoutSubviews {
    %orig;

    if (DYYYGetBool(@"DYYYEnableFullScreen")) {
        CGRect frame = self.frame;
        frame.size.height = self.superview.frame.size.height;
        self.frame = frame;
    } else if (tabHeight > 0) {
        UIWindow *window = [UIApplication sharedApplication].keyWindow;
        if (window && window.safeAreaInsets.bottom == 0)
            return;

        CGRect frame = self.frame;
        frame.size.height = self.superview.frame.size.height - tabHeight;
        self.frame = frame;
    }
}
%end

%hook AWEFeedTableViewCell
- (void)prepareForReuse {
    if (hideButton && hideButton.isElementsHidden) {
        [hideButton hideUIElements];
    }
    %orig;
}

- (void)layoutSubviews {
    %orig;
    if (hideButton && hideButton.isElementsHidden) {
        [hideButton hideUIElements];
    }
}
%end

%hook AWEFeedViewCell
- (void)layoutSubviews {
    if (hideButton && hideButton.isElementsHidden) {
        [hideButton hideUIElements];
    }
    %orig;
}

- (void)setModel:(id)model {
    if (hideButton && hideButton.isElementsHidden) {
        [hideButton hideUIElements];
    }
    %orig;
}
%end

%hook UIViewController
- (void)viewWillAppear:(BOOL)animated {
    %orig;
    isAppInTransition = YES;
    if (hideButton && hideButton.isElementsHidden) {
        [hideButton hideUIElements];
    }
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
      isAppInTransition = NO;
    });
}

- (void)viewWillDisappear:(BOOL)animated {
    %orig;
    isAppInTransition = YES;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
      isAppInTransition = NO;
    });
}
%end

%hook AFDPureModePageContainerViewController
- (void)viewDidAppear:(BOOL)animated {
    %orig;
    isPureViewVisible = YES;
    updateClearButtonVisibility();
}

- (void)viewDidDisappear:(BOOL)animated {
    %orig;
    isPureViewVisible = NO;
    updateClearButtonVisibility();
}
%end

%hook AWEFeedContainerViewController
- (void)aweme:(id)arg1 currentIndexWillChange:(NSInteger)arg2 {
    if (hideButton && hideButton.isElementsHidden) {
        [hideButton hideUIElements];
    }
    %orig;
}

- (void)aweme:(id)arg1 currentIndexDidChange:(NSInteger)arg2 {
    if (hideButton && hideButton.isElementsHidden) {
        [hideButton hideUIElements];
    }
    %orig;
}

- (void)viewWillLayoutSubviews {
    %orig;
    if (hideButton && hideButton.isElementsHidden) {
        [hideButton hideUIElements];
    }
}
%end

%hook AppDelegate
- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    BOOL result = %orig;
    initTargetClassNames();

    BOOL isEnabled = [[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYEnableFloatClearButton"];
    if (isEnabled) {
        if (hideButton) {
            [hideButton removeFromSuperview];
            hideButton = nil;
        }

        CGFloat buttonSize = [[NSUserDefaults standardUserDefaults] floatForKey:@"DYYYEnableFloatClearButtonSize"] ?: 40.0;
        hideButton = [[HideUIButton alloc] initWithFrame:CGRectMake(0, 0, buttonSize, buttonSize)];
        hideButton.alpha = 0.5;

        NSString *savedPositionString = [[NSUserDefaults standardUserDefaults] objectForKey:@"DYYYHideUIButtonPosition"];
        if (savedPositionString) {
            hideButton.center = CGPointFromString(savedPositionString);
        } else {
            CGFloat screenWidth = [UIScreen mainScreen].bounds.size.width;
            CGFloat screenHeight = [UIScreen mainScreen].bounds.size.height;
            hideButton.center = CGPointMake(screenWidth - buttonSize / 2 - 5, screenHeight / 2);
        }

        hideButton.hidden = NO;
        [getKeyWindow() addSubview:hideButton];

        [[NSNotificationCenter defaultCenter] addObserverForName:UIWindowDidBecomeKeyNotification
                                                          object:nil
                                                           queue:[NSOperationQueue mainQueue]
                                                      usingBlock:^(NSNotification *_Nonnull notification) {
                                                        updateClearButtonVisibility();
                                                      }];

        [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidBecomeActiveNotification
                                                          object:nil
                                                           queue:[NSOperationQueue mainQueue]
                                                      usingBlock:^(NSNotification *_Nonnull notification) {
                                                        isAppActive = YES;
                                                        updateClearButtonVisibility();
                                                      }];

        [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationWillResignActiveNotification
                                                          object:nil
                                                           queue:[NSOperationQueue mainQueue]
                                                      usingBlock:^(NSNotification *_Nonnull notification) {
                                                        isAppActive = NO;
                                                        updateClearButtonVisibility();
                                                      }];
    }

    return result;
}
%end

%hook AWEElementStackView
static CGFloat currentScale = 1.0;
- (void)setAlpha:(CGFloat)alpha {
    %orig;
    if (speedButton && isFloatSpeedButtonEnabled) {
        if (alpha == 0) {
            dyyyCommentViewVisible = YES;
        } else if (alpha == 1) {
            dyyyCommentViewVisible = NO;
        }
        updateSpeedButtonVisibility();
        updateClearButtonVisibility();
    }
}
- (void)layoutSubviews {
    %orig;
    UIViewController *viewController = [DYYYUtils firstAvailableViewControllerFromView:self];
    if ([viewController isKindOfClass:%c(AWECommentInputViewController)]) {
        NSString *transparentValue = DYYYGetString(@"DYYYGlobalTransparency");
        if (transparentValue.length > 0) {
            CGFloat alphaValue = transparentValue.floatValue;
            if (alphaValue >= 0.0 && alphaValue <= 1.0) {
                self.alpha = alphaValue;
            }
        }
    }

    if ([viewController isKindOfClass:%c(AWEPlayInteractionViewController)]) {
        // 右侧元素的处理逻辑
        if ([self.accessibilityLabel isEqualToString:@"right"] || [DYYYUtils containsSubviewOfClass:NSClassFromString(@"AWEPlayInteractionUserAvatarView") inView:self]) {
            NSString *scaleValue = [[NSUserDefaults standardUserDefaults] objectForKey:@"DYYYElementScale"];
            self.transform = CGAffineTransformIdentity;
            if (scaleValue.length > 0) {
                CGFloat scale = [scaleValue floatValue];
                if (currentScale != scale)
                    currentScale = scale;
                if (scale > 0 && scale != 1.0) {
                    NSArray *subviews = [self.subviews copy];
                    CGFloat ty = 0;
                    for (UIView *view in subviews) {
                        CGFloat viewHeight = view.frame.size.height;
                        ty += (viewHeight - viewHeight * scale) / 2;
                    }
                    CGFloat frameWidth = self.frame.size.width;
                    CGFloat right_tx = (frameWidth - frameWidth * scale) / 2;
                    self.transform = CGAffineTransformMake(scale, 0, 0, scale, right_tx, ty);
                } else {
                    self.transform = CGAffineTransformIdentity;
                }
            }
        }
        // 左侧元素的处理逻辑
        else if ([self.accessibilityLabel isEqualToString:@"left"] || [DYYYUtils containsSubviewOfClass:NSClassFromString(@"AWEFeedAnchorContainerView") inView:self]) {
            NSString *scaleValue = [[NSUserDefaults standardUserDefaults] objectForKey:@"DYYYNicknameScale"];
            if (scaleValue.length > 0) {
                CGFloat scale = [scaleValue floatValue];
                self.transform = CGAffineTransformIdentity;
                if (scale > 0 && scale != 1.0) {
                    NSArray *subviews = [self.subviews copy];
                    CGFloat ty = 0;
                    for (UIView *view in subviews) {
                        CGFloat viewHeight = view.frame.size.height;
                        ty += (viewHeight - viewHeight * scale) / 2;
                    }
                    CGFloat frameWidth = self.frame.size.width;
                    CGFloat left_tx = (frameWidth - frameWidth * scale) / 2 - frameWidth * (1 - scale);
                    CGAffineTransform newTransform = CGAffineTransformMakeScale(scale, scale);
                    newTransform = CGAffineTransformTranslate(newTransform, left_tx / scale, ty / scale);
                    self.transform = newTransform;
                }
            }
        }
    }
}
- (NSArray<__kindof UIView *> *)arrangedSubviews {

    UIViewController *viewController = [DYYYUtils firstAvailableViewControllerFromView:self];
    if ([viewController isKindOfClass:%c(AWEPlayInteractionViewController)]) {

        if ([self.accessibilityLabel isEqualToString:@"left"] || [DYYYUtils containsSubviewOfClass:NSClassFromString(@"AWEFeedAnchorContainerView") inView:self]) {
            NSString *scaleValue = [[NSUserDefaults standardUserDefaults] objectForKey:@"DYYYNicknameScale"];
            if (scaleValue.length > 0) {
                CGFloat scale = [scaleValue floatValue];
                self.transform = CGAffineTransformIdentity;
                if (scale > 0 && scale != 1.0) {
                    NSArray *subviews = [self.subviews copy];
                    CGFloat ty = 0;
                    for (UIView *view in subviews) {
                        CGFloat viewHeight = view.frame.size.height;
                        ty += (viewHeight - viewHeight * scale) / 2;
                    }
                    CGFloat frameWidth = self.frame.size.width;
                    CGFloat left_tx = (frameWidth - frameWidth * scale) / 2 - frameWidth * (1 - scale);
                    CGAffineTransform newTransform = CGAffineTransformMakeScale(scale, scale);
                    newTransform = CGAffineTransformTranslate(newTransform, left_tx / scale, ty / scale);
                    self.transform = newTransform;
                }
            }
        }
    }

    NSArray *originalSubviews = %orig;
    return originalSubviews;
}
%end

%hook AWELiveNewPreStreamViewController
static char kDyLastAppliedScaleKey;
static char kDyLastAppliedShiftKey;
static char kDyLastAppliedTabHeightKey;
static NSArray<Class> *kTargetViewClasses = @[ NSClassFromString(@"AWEElementStackView"), NSClassFromString(@"IESLiveStackView") ];
- (void)viewDidLayoutSubviews {
    %orig;

    NSMutableArray<UIView *> *targetViews = [NSMutableArray array];
    for (Class targetClass in kTargetViewClasses) {
        if (targetClass) {
            [targetViews addObjectsFromArray:[DYYYUtils findAllSubviewsOfClass:targetClass inView:self.view]];
        }
    }

    if (targetViews.count == 0)
        return;

    NSString *transparentValue = DYYYGetString(@"DYYYGlobalTransparency");
    if (transparentValue.length > 0) {
        CGFloat alphaValue = transparentValue.floatValue;
        if (alphaValue >= 0.0 && alphaValue <= 1.0) {
            [targetViews setValue:@(alphaValue) forKey:@"alpha"];
        }
    }

    BOOL shouldShiftUp = DYYYGetBool(@"DYYYEnableFullScreen");
    BOOL lastAppliedShift = [objc_getAssociatedObject(self, &kDyLastAppliedShiftKey) boolValue];

    CGFloat vcScaleValue = DYYYGetFloat(@"DYYYNicknameScale");
    CGFloat targetScale = (vcScaleValue != 0.0) ? MAX(0.01, vcScaleValue) : 1.0;
    CGFloat lastAppliedScale = [objc_getAssociatedObject(self, &kDyLastAppliedScaleKey) floatValue] ?: 1.0;

    CGFloat targetHeight = tabHeight;
    CGFloat lastAppliedTabHeight = [objc_getAssociatedObject(self, &kDyLastAppliedTabHeightKey) floatValue];

    if (fabs(targetScale - lastAppliedScale) < 0.01 && fabs(targetHeight - lastAppliedTabHeight) < 0.1 && shouldShiftUp == lastAppliedShift) {
        return;
    }

    const CGFloat scaleDelta = targetScale - 1.0;
    const BOOL shouldScale = fabs(scaleDelta) >= 0.01;

    for (UIView *targetView in targetViews) {
        CGAffineTransform finalTransform = CGAffineTransformIdentity;

        if (shouldScale) {
            CGFloat tx = CGRectGetWidth(targetView.bounds) * scaleDelta * 0.5;
            CGFloat ty = 0;
            for (UIView *subview in targetView.subviews) {
                ty += -CGRectGetHeight(subview.bounds) * scaleDelta * 0.5;
            }
            CGAffineTransform scaleTransform = CGAffineTransformMakeScale(targetScale, targetScale);
            finalTransform = CGAffineTransformTranslate(scaleTransform, tx / targetScale, ty / targetScale);
        }

        if (shouldShiftUp) {
            const CGFloat divisor = CGAffineTransformIsIdentity(finalTransform) ? 1.0 : targetScale;
            finalTransform = CGAffineTransformTranslate(finalTransform, 0, -targetHeight / divisor);
        }

        targetView.transform = finalTransform;
    }

    objc_setAssociatedObject(self, &kDyLastAppliedScaleKey, @(targetScale), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(self, &kDyLastAppliedShiftKey, @(shouldShiftUp), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(self, &kDyLastAppliedTabHeightKey, @(targetHeight), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}
%end

%hook AWEStoryContainerCollectionView
- (void)layoutSubviews {
    %orig;
    if ([self.subviews count] == 2)
        return;

    // 获取 enableEnterProfile 属性来判断是否是主页
    id enableEnterProfile = [self valueForKey:@"enableEnterProfile"];
    BOOL isHome = (enableEnterProfile != nil && [enableEnterProfile boolValue]);

    // 检查是否在作者主页
    BOOL isAuthorProfile = NO;
    UIResponder *responder = self;
    while ((responder = [responder nextResponder])) {
        if ([NSStringFromClass([responder class]) containsString:@"UserHomeViewController"] || [NSStringFromClass([responder class]) containsString:@"ProfileViewController"]) {
            isAuthorProfile = YES;
            break;
        }
    }

    // 如果不是主页也不是作者主页，直接返回
    if (!isHome && !isAuthorProfile)
        return;

    for (UIView *subview in self.subviews) {
        if ([subview isKindOfClass:[UIView class]]) {
            UIView *nextResponder = (UIView *)subview.nextResponder;

            // 处理主页的情况
            if (isHome && [nextResponder isKindOfClass:%c(AWEPlayInteractionViewController)]) {
                UIViewController *awemeBaseViewController = [nextResponder valueForKey:@"awemeBaseViewController"];
                if (![awemeBaseViewController isKindOfClass:%c(AWEFeedCellViewController)]) {
                    continue;
                }

                CGRect frame = subview.frame;
                if (DYYYGetBool(@"DYYYEnableFullScreen")) {
                    frame.size.height = subview.superview.frame.size.height - tabHeight;
                    subview.frame = frame;
                }
            }
            // 处理作者主页的情况
            else if (isAuthorProfile) {
                // 检查是否是作品图片
                BOOL isWorkImage = NO;

                // 可以通过检查子视图、标签或其他特性来确定是否是作品图片
                for (UIView *childView in subview.subviews) {
                    if ([NSStringFromClass([childView class]) containsString:@"ImageView"] || [NSStringFromClass([childView class]) containsString:@"ThumbnailView"]) {
                        isWorkImage = YES;
                        break;
                    }
                }

                if (isWorkImage) {
                    // 修复作者主页作品图片上移问题
                    CGRect frame = subview.frame;
                    frame.origin.y += tabHeight;
                    subview.frame = frame;
                }
            }
        }
    }
}
%end

%hook AFDFastSpeedView
- (void)layoutSubviews {
    %orig;

    if (![[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYEnableFullScreen"]) {
        return;
    }

    static char kDYFastSpeedBgKey;
    NSArray *bgViews = objc_getAssociatedObject(self, &kDYFastSpeedBgKey);
    if (!bgViews) {
        NSMutableArray *tmp = [NSMutableArray array];
        for (UIView *subview in self.subviews) {
            if ([subview class] == [UIView class]) {
                [tmp addObject:subview];
            }
        }
        bgViews = [tmp copy];
        objc_setAssociatedObject(self, &kDYFastSpeedBgKey, bgViews, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }

    for (UIView *view in bgViews) {
        view.backgroundColor = [UIColor clearColor];
    }
}
%end

%hook AWELandscapeFeedEntryView
- (void)setCenter:(CGPoint)center {
    if (DYYYGetBool(@"DYYYEnableFullScreen")) {
        center.y += 50;
    }

    %orig(center);
}

- (void)layoutSubviews {
    %orig;
    if (DYYYGetBool(@"DYYYHideEntry")) {
        [self removeFromSuperview];
    }
}

%end

%hook AWEAwemeDetailTableView

- (void)setFrame:(CGRect)frame {
    if (DYYYGetBool(@"DYYYEnableFullScreen")) {
        CGFloat screenHeight = [UIScreen mainScreen].bounds.size.height;

        CGFloat remainder = fmod(frame.size.height, screenHeight);
        if (remainder != 0) {
            frame.size.height += (screenHeight - remainder);
        }
    }
    %orig(frame);
}

%end

%hook AWEMixVideoPanelMoreView

- (void)setFrame:(CGRect)frame {
    if (DYYYGetBool(@"DYYYEnableFullScreen")) {
        CGFloat targetY = frame.origin.y - tabHeight;
        CGFloat screenHeightMinusGDiff = [UIScreen mainScreen].bounds.size.height - tabHeight;

        CGFloat tolerance = 10.0;

        if (fabs(targetY - screenHeightMinusGDiff) <= tolerance) {
            frame.origin.y = targetY;
        }
    }
    %orig(frame);
}

- (void)layoutSubviews {
    %orig;

    if (DYYYGetBool(@"DYYYEnableFullScreen")) {
        self.backgroundColor = [UIColor clearColor];
    }
}

%end

%hook CommentInputContainerView

- (void)layoutSubviews {
    %orig;
    UIViewController *parentVC = nil;
    if ([self respondsToSelector:@selector(viewController)]) {
        id viewController = [self performSelector:@selector(viewController)];
        if ([viewController respondsToSelector:@selector(parentViewController)]) {
            parentVC = [viewController parentViewController];
        }
    }

    if (parentVC && ([parentVC isKindOfClass:%c(AWEAwemeDetailTableViewController)] || [parentVC isKindOfClass:%c(AWEAwemeDetailCellViewController)])) {
        static char kDYCommentHideCacheKey;
        UIView *target = objc_getAssociatedObject(self, &kDYCommentHideCacheKey);
        if (!target) {
            for (UIView *subview in [self subviews]) {
                if ([subview class] == [UIView class]) {
                    target = subview;
                    objc_setAssociatedObject(self, &kDYCommentHideCacheKey, target, OBJC_ASSOCIATION_ASSIGN);
                    break;
                }
            }
        }
        if (target) {
            target.hidden = ([(UIView *)self frame].size.height == tabHeight);
        }
    }
}

%end

// 聊天视频底部评论框背景透明
%hook AWEIMFeedBottomQuickEmojiInputBar

- (void)layoutSubviews {
    %orig;

    if (DYYYGetBool(@"DYYYEnableFullScreen")) {
        UIView *parentView = self.superview;
        while (parentView) {
            if ([NSStringFromClass([parentView class]) isEqualToString:@"UIView"]) {
                dispatch_async(dispatch_get_main_queue(), ^{
                  parentView.backgroundColor = [UIColor clearColor];
                  parentView.layer.backgroundColor = [UIColor clearColor].CGColor;
                  parentView.opaque = NO;
                });
                break;
            }
            parentView = parentView.superview;
        }
    }
}

%end

// 隐藏章节进度条
%hook AWEDemaciaChapterProgressSlider

- (void)layoutSubviews {
    %orig;
    if (DYYYGetBool(@"DYYYHideChapterProgress")) {
        [self removeFromSuperview];
    }
}

%end

// 隐藏上次看到
%hook DUXPopover
- (void)layoutSubviews {
    %orig;

    if (!DYYYGetBool(@"DYYYHidePopover")) {
        return;
    }

    id rawContent = nil;
    @try {
        rawContent = [self valueForKey:@"content"];
    } @catch (__unused NSException *e) {
        return;
    }

    NSString *text = [rawContent isKindOfClass:NSString.class] ? (NSString *)rawContent : [rawContent description];

    if ([text containsString:@"上次看到"]) {
        self.hidden = YES;
        return;
    }
}
%end

// 隐藏双栏入口
%hook AWENormalModeTabBarFeedView
- (void)layoutSubviews {
    %orig;
    if (![[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYHideDoubleColumnEntry"]) {
        return;
    }

    static char kDYDoubleColumnCacheKey;
    static char kDYDoubleColumnCountKey;
    NSArray *cachedViews = objc_getAssociatedObject(self, &kDYDoubleColumnCacheKey);
    NSNumber *cachedCount = objc_getAssociatedObject(self, &kDYDoubleColumnCountKey);
    if (!cachedViews || cachedCount.unsignedIntegerValue != self.subviews.count) {
        NSMutableArray *views = [NSMutableArray array];
        for (UIView *subview in self.subviews) {
            if (![subview isKindOfClass:[UILabel class]]) {
                [views addObject:subview];
            }
        }
        cachedViews = [views copy];
        objc_setAssociatedObject(self, &kDYDoubleColumnCacheKey, cachedViews, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        objc_setAssociatedObject(self, &kDYDoubleColumnCountKey, @(self.subviews.count), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }

    for (UIView *v in cachedViews) {
        v.hidden = YES;
    }
    return;
}
%end

%hook UIImageView
- (void)layoutSubviews {
    %orig;
    if (DYYYGetBool(@"DYYYHideCommentDiscover")) {
        if (!self.accessibilityLabel) {
            UIView *parentView = self.superview;

            if (parentView && [parentView class] == [UIView class] && [parentView.accessibilityLabel isEqualToString:@"搜索"]) {
                self.hidden = YES;
            }

            else if (parentView && [NSStringFromClass([parentView class]) isEqualToString:@"AWESearchEntryHalfScreenElement"] && [parentView.accessibilityLabel isEqualToString:@"搜索"]) {
                self.hidden = YES;
            }
        }
    }
    return;
}
%end

// 移除极速版我的片面红包横幅
%hook AWELuckyCatBannerView
- (id)initWithFrame:(CGRect)frame {
    return nil;
}

- (id)init {
    return nil;
}
%end

static NSMutableDictionary *keepCellsInfo;
static NSMutableDictionary *sectionKeepInfo;

static NSString *const kAWELeftSideBarTopRightLayoutView = @"AWELeftSideBarTopRightLayoutView";
static NSString *const kAWELeftSideBarFunctionContainerView = @"AWELeftSideBarFunctionContainerView";
static NSString *const kAWELeftSideBarWeatherView = @"AWELeftSideBarWeatherView";

static NSString *const kStreamlineSidebarKey = @"DYYYHideSidebarElements";

%hook AWELeftSideBarViewController

- (void)viewDidLoad {
    %orig;

    if (!DYYYGetBool(kStreamlineSidebarKey)) {
        return;
    }

    if (!keepCellsInfo) {
        keepCellsInfo = [NSMutableDictionary dictionary];
    }
    if (!sectionKeepInfo) {
        sectionKeepInfo = [NSMutableDictionary dictionary];
    }
}

- (void)viewDidDisappear:(BOOL)animated {
    %orig;

    if (!DYYYGetBool(kStreamlineSidebarKey)) {
        return;
    }

    [keepCellsInfo removeAllObjects];
    [sectionKeepInfo removeAllObjects];
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath {
    UICollectionViewCell *cell = %orig;

    if (!DYYYGetBool(kStreamlineSidebarKey)) {
        return cell;
    }

    if (!cell)
        return cell;

    @try {
        BOOL shouldKeep = [DYYYUtils containsSubviewOfClass:NSClassFromString(kAWELeftSideBarTopRightLayoutView) inView:cell.contentView] ||
                          [DYYYUtils containsSubviewOfClass:NSClassFromString(kAWELeftSideBarFunctionContainerView) inView:cell.contentView] ||
                          [DYYYUtils containsSubviewOfClass:NSClassFromString(kAWELeftSideBarWeatherView) inView:cell.contentView];

        NSString *key = [NSString stringWithFormat:@"%ld-%ld", (long)indexPath.section, (long)indexPath.row];
        keepCellsInfo[key] = @(shouldKeep);
        if (shouldKeep) {
            sectionKeepInfo[@(indexPath.section)] = @YES;
        } else if (!sectionKeepInfo[@(indexPath.section)]) {
            sectionKeepInfo[@(indexPath.section)] = @NO;
        }

        if (!shouldKeep) {
            cell.hidden = YES;
            cell.alpha = 0;
            CGRect frame = cell.frame;
            frame.size.width = 0;
            frame.size.height = 0;
            cell.frame = frame;
        } else if ([DYYYUtils containsSubviewOfClass:NSClassFromString(kAWELeftSideBarFunctionContainerView) inView:cell.contentView]) {
            [self adjustContainerViewLayout:cell];
        }
    } @catch (NSException *exception) {
        NSLog(@"Error in cellForItemAtIndexPath: %@", exception);
    }

    return cell;
}

- (CGSize)collectionView:(UICollectionView *)collectionView layout:(id)layout sizeForItemAtIndexPath:(NSIndexPath *)indexPath {
    CGSize originalSize = %orig;

    if (!DYYYGetBool(kStreamlineSidebarKey)) {
        return originalSize;
    }

    NSString *key = [NSString stringWithFormat:@"%ld-%ld", (long)indexPath.section, (long)indexPath.row];
    NSNumber *shouldKeep = keepCellsInfo[key];

    if (shouldKeep != nil && ![shouldKeep boolValue]) {
        return CGSizeZero;
    }

    return originalSize;
}

- (UIEdgeInsets)collectionView:(UICollectionView *)collectionView layout:(id)layout insetForSectionAtIndex:(NSInteger)section {
    UIEdgeInsets originalInsets = %orig;

    if (!DYYYGetBool(kStreamlineSidebarKey)) {
        return originalInsets;
    }

    BOOL hasKeepCells = [sectionKeepInfo[@(section)] boolValue];

    if (!hasKeepCells) {
        return UIEdgeInsetsZero;
    }

    return originalInsets;
}

%new
- (void)adjustContainerViewLayout:(UICollectionViewCell *)containerCell {
    if (!DYYYGetBool(kStreamlineSidebarKey)) {
        return;
    }

    UICollectionView *collectionView = [self collectionView];
    if (!collectionView || !containerCell)
        return;

    UIView *containerView = [DYYYUtils findSubviewOfClass:NSClassFromString(kAWELeftSideBarFunctionContainerView) inView:containerCell.contentView];
    if (!containerView)
        return;

    CGFloat windowHeight = collectionView.window.bounds.size.height;
    CGFloat currentY = [containerCell convertPoint:containerCell.bounds.origin toView:nil].y;
    CGFloat newHeight = windowHeight - currentY - 20;

    CGRect containerFrame = containerView.frame;
    containerFrame.size.height = newHeight;
    containerView.frame = containerFrame;

    CGRect cellFrame = containerCell.frame;
    cellFrame.size.height = newHeight;
    containerCell.frame = cellFrame;
}

%end

%hook AFDViewedBottomView
- (void)layoutSubviews {
    %orig;

    if (DYYYGetBool(@"DYYYEnableFullScreen")) {

        self.backgroundColor = [UIColor clearColor];

        self.effectView.hidden = YES;
    }
}
%end

%hook AWENormalModeTabBarGeneralPlusButton
- (void)setImage:(UIImage *)image forState:(UIControlState)state {

    if ([self.accessibilityLabel isEqualToString:@"拍摄"]) {

        NSString *documentsPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject];
        NSString *dyyyFolderPath = [documentsPath stringByAppendingPathComponent:@"DYYY"];

        NSString *customImagePath = [dyyyFolderPath stringByAppendingPathComponent:@"tab_plus.png"];

        if ([[NSFileManager defaultManager] fileExistsAtPath:customImagePath]) {
            UIImage *customImage = [UIImage imageWithContentsOfFile:customImagePath];
            if (customImage) {

                %orig(customImage, state);
                return;
            }
        }
    }

    %orig;
}
%end

// 极速版红包激励挂件容器视图类组（移除逻辑）
%group IncentivePendantGroup
%hook AWEIncentiveSwiftImplDOUYINLite_IncentivePendantContainerView
- (void)layoutSubviews {
    %orig;
    if (DYYYGetBool(@"DYYYHidePendantGroup")) {
        [self removeFromSuperview];
    }
}
%end
%end

// View scaling fix when comment blur is enabled
%group BDMultiContentImageViewGroup
%hook BDMultiContentContainer_ImageContentView

- (void)setTransform:(CGAffineTransform)transform {
    if (DYYYGetBool(@"DYYYEnableCommentBlur")) {
        return;
    }
    %orig(transform);
}

%end
%end

%hook AWEStoryContainerCollectionView

- (void)setFrame:(CGRect)frame {
    if (DYYYGetBool(@"DYYYEnableCommentBlur")) {
        if (frame.origin.y != 0) {
            return;
        }
    }
    %orig(frame);
}

%end

// Swift 类初始化
%ctor {

    // 初始化红包激励挂件容器视图类组
    Class incentivePendantClass = objc_getClass("AWEIncentiveSwiftImplDOUYINLite.IncentivePendantContainerView");
    if (incentivePendantClass) {
        %init(IncentivePendantGroup, AWEIncentiveSwiftImplDOUYINLite_IncentivePendantContainerView = incentivePendantClass);
    }
    Class imageContentClass = objc_getClass("BDMultiContentContainer.ImageContentView");
    if (imageContentClass) {
        %init(BDMultiContentImageViewGroup, BDMultiContentContainer_ImageContentView = imageContentClass);
    }
}

%ctor {
    %init(DYYYSettingsGesture);
    if (DYYYGetBool(@"DYYYUserAgreementAccepted")) {
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
          Class wSwiftImpl = objc_getClass("AWECommentInputViewSwiftImpl.CommentInputContainerView");
          %init(CommentInputContainerView = wSwiftImpl);
        });
        BOOL isAutoPlayEnabled = DYYYGetBool(@"DYYYEnableAutoPlay");
        if (isAutoPlayEnabled) {
            %init(AutoPlay);
        }
        if (DYYYGetBool(@"DYYYForceDownloadEmotion")) {
            %init(EnableStickerSaveMenu);
        }
    }
}

// 隐藏键盘 AI
static __weak UIView *cachedHideView = nil;
static void hideParentViewsSubviews(UIView *view) {
    if (!view)
        return;
    UIView *parentView = [view superview];
    if (!parentView)
        return;
    UIView *grandParentView = [parentView superview];
    if (!grandParentView)
        return;
    UIView *greatGrandParentView = [grandParentView superview];
    if (!greatGrandParentView)
        return;
    cachedHideView = greatGrandParentView;
    for (UIView *subview in greatGrandParentView.subviews) {
        subview.hidden = YES;
    }
}
// 递归查找目标视图
static void findTargetViewInView(UIView *view) {
    if (cachedHideView)
        return;
    if ([view isKindOfClass:NSClassFromString(@"AWESearchKeyboardVoiceSearchEntranceView")]) {
        hideParentViewsSubviews(view);
        return;
    }
    for (UIView *subview in view.subviews) {
        findTargetViewInView(subview);
        if (cachedHideView)
            break;
    }
}

%ctor {
    // 注册键盘通知
    if (DYYYGetBool(@"DYYYUserAgreementAccepted")) {
        [[NSNotificationCenter defaultCenter] addObserverForName:UIKeyboardWillShowNotification
                                                          object:nil
                                                           queue:[NSOperationQueue mainQueue]
                                                      usingBlock:^(NSNotification *notification) {
                                                        if (DYYYGetBool(@"DYYYHideKeyboardAI")) {
                                                            if (cachedHideView) {
                                                                for (UIView *subview in cachedHideView.subviews) {
                                                                    subview.hidden = YES;
                                                                }
                                                            } else {
                                                                for (UIWindow *window in [UIApplication sharedApplication].windows) {
                                                                    findTargetViewInView(window);
                                                                    if (cachedHideView)
                                                                        break;
                                                                }
                                                            }
                                                        }
                                                      }];
    }
}

%ctor {
    signal(SIGSEGV, SIG_IGN);
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    isFloatSpeedButtonEnabled = [defaults boolForKey:@"DYYYEnableFloatSpeedButton"];
}