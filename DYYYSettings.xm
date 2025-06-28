#import "AwemeHeaders.h"
#import "DYYYManager.h"
#import <MobileCoreServices/MobileCoreServices.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>

#import "DYYYABTestHook.h"

#import "DYYYAboutDialogView.h"
#import "DYYYBottomAlertView.h"
#import "DYYYCustomInputView.h"
#import "DYYYIconOptionsDialogView.h"
#import "DYYYKeywordListView.h"
#import "DYYYOptionsSelectionView.h"

#import "DYYYConstants.h"
#import "DYYYSettingsHelper.h"
#import "DYYYUtils.h"

@class DYYYIconOptionsDialogView;
static void showIconOptionsDialog(NSString *title, UIImage *previewImage, NSString *saveFilename, void (^onClear)(void), void (^onSelect)(void));

#import "DYYYBackupPickerDelegate.h"
#import "DYYYImagePickerDelegate.h"

#ifdef __cplusplus
extern "C" {
#endif
void *kViewModelKey = &kViewModelKey;
#ifdef __cplusplus
}
#endif
%hook AWESettingBaseViewController
- (bool)useCardUIStyle {
	return YES;
}

- (AWESettingBaseViewModel *)viewModel {
	AWESettingBaseViewModel *original = %orig;
	if (!original)
		return objc_getAssociatedObject(self, &kViewModelKey);
	return original;
}
%end

%hook AWELeftSideBarWeatherLabel
- (id)initWithFrame:(CGRect)frame {
	id orig = %orig;
	self.userInteractionEnabled = YES;
	UITapGestureRecognizer *tapGesture = [[UITapGestureRecognizer alloc] initWithTarget:[UIView class] action:@selector(openDYYYSettingsFromSender:)];
	objc_setAssociatedObject(tapGesture, "targetView", self, OBJC_ASSOCIATION_ASSIGN);
	[self addGestureRecognizer:tapGesture];
	return orig;
}

- (void)drawTextInRect:(CGRect)rect {
	CGContextRef context = UIGraphicsGetCurrentContext();
	CGContextClearRect(context, rect);

	NSDictionary *attributes = @{NSFontAttributeName : [UIFont systemFontOfSize:12.0], NSForegroundColorAttributeName : self.textColor};
	[@"DYYY" drawInRect:rect withAttributes:attributes];
}
%end

%hook AWELeftSideBarWeatherView
- (void)didMoveToSuperview {
	%orig;
	dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
	  CGRect frame = self.frame;
	  frame.origin.y += 10;
	  self.frame = frame;
	});
}

- (void)layoutSubviews {
	%orig;
	self.userInteractionEnabled = YES;
	UITapGestureRecognizer *tapGesture = [[UITapGestureRecognizer alloc] initWithTarget:[UIView class] action:@selector(openDYYYSettingsFromSender:)];
	objc_setAssociatedObject(tapGesture, "targetView", self, OBJC_ASSOCIATION_ASSIGN);
	[self addGestureRecognizer:tapGesture];

	for (UIView *subview in self.subviews) {
		subview.userInteractionEnabled = YES;
		UITapGestureRecognizer *subTapGesture = [[UITapGestureRecognizer alloc] initWithTarget:[UIView class] action:@selector(openDYYYSettingsFromSender:)];
		objc_setAssociatedObject(subTapGesture, "targetView", self, OBJC_ASSOCIATION_ASSIGN);
		[subview addGestureRecognizer:subTapGesture];

		[subview.subviews enumerateObjectsUsingBlock:^(UIView *childView, NSUInteger idx, BOOL *stop) {
		  if (![childView isKindOfClass:%c(AWELeftSideBarWeatherLabel)]) {
			  [childView removeFromSuperview];
		  }
		}];
	}
}
%end

%hook AWELeftSideBarEntranceView
- (void)leftSideBarEntranceViewTapped:(UITapGestureRecognizer *)gesture {
	if (![[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYentrance"]) {
		%orig;
		return;
	}

	UIViewController *feedVC = [DYYYSettingsHelper findViewController:self];
	if (![feedVC isKindOfClass:%c(AWEFeedContainerViewController)]) {
		feedVC = UIApplication.sharedApplication.keyWindow.rootViewController;
		while (feedVC && ![feedVC isKindOfClass:%c(AWEFeedContainerViewController)]) {
			feedVC = feedVC.presentedViewController;
		}
	}

	if (feedVC) {
		[DYYYSettingsHelper openSettingsWithViewController:feedVC];
	} else {
		%orig;
	}
}
%end

%hook UIView
%new
+ (void)openDYYYSettingsFromSender:(UITapGestureRecognizer *)sender {
	UIView *targetView = objc_getAssociatedObject(sender, "targetView");
	if (targetView) {
		[DYYYSettingsHelper openSettingsFromView:targetView];
	}
}
%end

#ifdef __cplusplus
extern "C"
#endif
    void
    showDYYYSettingsVC(UIViewController *rootVC, BOOL hasAgreed) {
	AWESettingBaseViewController *settingsVC = [[%c(AWESettingBaseViewController) alloc] init];
	if (!hasAgreed) {
		[DYYYSettingsHelper showAboutDialog:@"使用者協議"
					    message:@"本插件為開源專案\n僅供學習交流用途\n如有侵權請聯繫, GitHub 倉庫：huami1314/DYYY\n請遵守當地法律法規, "
						    @"逆向工程僅為學習目的\n盜用原始碼進行商業用途/發布但未標記開源專案必究\n詳情請參閱專案內 MIT 許可證\n\n請輸入\"我已閱讀並同意繼續使用\"以繼續"
					  onConfirm:^{
					    [DYYYSettingsHelper showUserAgreementAlert];
					  }];
	}

	// 等待视图加载并使用KVO安全访问属性
	dispatch_async(dispatch_get_main_queue(), ^{
	  if ([settingsVC.view isKindOfClass:[UIView class]]) {
		  for (UIView *subview in settingsVC.view.subviews) {
			  if ([subview isKindOfClass:%c(AWENavigationBar)]) {
				  AWENavigationBar *navigationBar = (AWENavigationBar *)subview;
				  if ([navigationBar respondsToSelector:@selector(titleLabel)]) {
					  navigationBar.titleLabel.text = DYYY_NAME;
				  }
				  break;
			  }
		  }
	  }
	});

	AWESettingsViewModel *viewModel = [[%c(AWESettingsViewModel) alloc] init];
	viewModel.colorStyle = 0;

	// 创建主分类列表
	AWESettingSectionModel *mainSection = [[%c(AWESettingSectionModel) alloc] init];
	mainSection.sectionHeaderTitle = @"功能";
	mainSection.sectionHeaderHeight = 40;
	mainSection.type = 0;
	NSMutableArray<AWESettingItemModel *> *mainItems = [NSMutableArray array];

	// 创建基本设置分类项
	AWESettingItemModel *basicSettingItem = [[%c(AWESettingItemModel) alloc] init];
	basicSettingItem.identifier = @"DYYYBasicSettings";
	basicSettingItem.title = @"基本設定";
	basicSettingItem.type = 0;
	basicSettingItem.svgIconImageName = @"ic_gearsimplify_outlined_20";
	basicSettingItem.cellType = 26;
	basicSettingItem.colorStyle = 0;
	basicSettingItem.isEnable = YES;
	basicSettingItem.cellTappedBlock = ^{
	  // 创建基本设置二级界面的设置项
	  NSMutableDictionary *cellTapHandlers = [NSMutableDictionary dictionary];

	  // 【外观设置】分类
	  NSMutableArray<AWESettingItemModel *> *appearanceItems = [NSMutableArray array];
	  NSArray *appearanceSettings = @[
		  @{@"identifier" : @"DYYYEnableDanmuColor",
		    @"title" : @"啟用彈幕改色",
		    @"detail" : @"",
		    @"cellType" : @6,
		    @"imageName" : @"ic_dansquare_outlined_20"},
		  @{
			  @"identifier" : @"DYYYdanmuColor",
			  @"title" : @"自訂彈幕顏色",
			  @"subTitle" : @"填入 random 使用隨機色彩彈幕",
			  @"detail" : @"十六進位",
			  @"cellType" : @20,
			  @"imageName" : @"ic_dansquarenut_outlined_20"
		  },			
	  ];

	  for (NSDictionary *dict in appearanceSettings) {
		  AWESettingItemModel *item = [DYYYSettingsHelper createSettingItem:dict cellTapHandlers:cellTapHandlers];
		  [appearanceItems addObject:item];
	  }

	  // 【视频播放设置】分类
	  NSMutableArray<AWESettingItemModel *> *videoItems = [NSMutableArray array];
	  NSArray *videoSettings = @[
		  @{
			  @"identifier" : @"DYYYVideoBGColor",
			  @"title" : @"影片背景顏色",
			  @"subTitle" : @"可自訂部分橫向螢幕影片的背景顏色",
			  @"detail" : @"",
			  @"cellType" : @20,
			  @"imageName" : @"ic_tv_outlined_20"
		  },	  
		  @{@"identifier" : @"DYYYisShowScheduleDisplay",
		    @"title" : @"顯示進度時長",
		    @"detail" : @"",
		    @"cellType" : @6,
		    @"imageName" : @"ic_playertime_outlined_20"},
		  @{@"identifier" : @"DYYYScheduleStyle",
		    @"title" : @"進度時長樣式",
		    @"detail" : @"",
		    @"cellType" : @26,
		    @"imageName" : @"ic_playertime_outlined_20"},
		  @{@"identifier" : @"DYYYProgressLabelColor",
		    @"title" : @"進度標籤顏色",
		    @"detail" : @"十六進位",
		    @"cellType" : @26,
		    @"imageName" : @"ic_playertime_outlined_20"},
		  @{@"identifier" : @"DYYYTimelineVerticalPosition",
		    @"title" : @"進度縱軸位置",
		    @"detail" : @"-12.5",
		    @"cellType" : @26,
		    @"imageName" : @"ic_playertime_outlined_20"},
		  @{@"identifier" : @"DYYYHideVideoProgress",
		    @"title" : @"隱藏影片進度",
		    @"detail" : @"",
		    @"cellType" : @6,
		    @"imageName" : @"ic_playertime_outlined_20"},
		  @{
			  @"identifier" : @"DYYYisEnableAutoPlay",
			  @"title" : @"啟用自動播放",
			  @"subTitle" : @"暫時僅支援推薦、搜尋和個人主頁的自動連播",
			  @"detail" : @"",
			  @"cellType" : @37,
			  @"imageName" : @"ic_play_outlined_12"
		  },
		  @{@"identifier" : @"DYYYDefaultSpeed",
		    @"title" : @"設定預設倍速",
		    @"detail" : @"",
		    @"cellType" : @26,
		    @"imageName" : @"ic_speed_outlined_20"},
		  @{@"identifier" : @"DYYYLongPressSpeed",
		    @"title" : @"設定長按倍速",
		    @"detail" : @"",
		    @"cellType" : @26,
		    @"imageName" : @"ic_speed_outlined_20"},
		  @{@"identifier" : @"DYYYisEnableArea",
		    @"title" : @"時間屬地顯示",
		    @"detail" : @"",
		    @"cellType" : @6,
		    @"imageName" : @"ic_location_outlined_20"},
		  @{
			  @"identifier" : @"DYYYGeonamesUsername",
			  @"title" : @"國外解析帳號",
			  @"subTitle" : @"使用 Geonames.org 帳號解析國外 IP 位置",
			  @"detail" : @"",
			  @"cellType" : @20,
			  @"imageName" : @"ic_location_outlined_20"
		  },
		  @{@"identifier" : @"DYYYLabelColor",
		    @"title" : @"屬地標籤顏色",
		    @"detail" : @"十六進位",
		    @"cellType" : @26,
		    @"imageName" : @"ic_location_outlined_20"},
		  @{
			  @"identifier" : @"DYYYEnabsuijiyanse",
			  @"title" : @"屬地隨機漸變",
			  @"subTitle" : @"啟用後將覆蓋上面的屬地標籤顏色",
			  @"detail" : @"",
			  @"cellType" : @37,
			  @"imageName" : @"ic_location_outlined_20"
		  }
	  ];

	  for (NSDictionary *dict in videoSettings) {
		  AWESettingItemModel *item = [DYYYSettingsHelper createSettingItem:dict cellTapHandlers:cellTapHandlers];

		  if ([item.identifier isEqualToString:@"DYYYDefaultSpeed"]) {
			  NSString *savedSpeed = [[NSUserDefaults standardUserDefaults] objectForKey:@"DYYYDefaultSpeed"];
			  item.detail = savedSpeed ?: @"1.0x";

			  item.cellTappedBlock = ^{
			    NSArray *speedOptions = @[ @"0.75x", @"1.0x", @"1.25x", @"1.5x", @"2.0x", @"2.5x", @"3.0x" ];

			    [DYYYOptionsSelectionView showWithPreferenceKey:@"DYYYDefaultSpeed"
							       optionsArray:speedOptions
								 headerText:@"選擇預設倍速"
							     onPresentingVC:topView()
							   selectionChanged:^(NSString *selectedValue) {
							     item.detail = selectedValue;
							     [item refreshCell];
							   }];
			  };
		  }

		  else if ([item.identifier isEqualToString:@"DYYYLongPressSpeed"]) {
			  NSString *savedSpeed = [[NSUserDefaults standardUserDefaults] objectForKey:@"DYYYLongPressSpeed"];
			  item.detail = savedSpeed ?: @"2.0x";

			  item.cellTappedBlock = ^{
			    NSArray *speedOptions = @[ @"0.75x", @"1.0x", @"1.25x", @"1.5x", @"2.0x", @"2.5x", @"3.0x" ];

			    [DYYYOptionsSelectionView showWithPreferenceKey:@"DYYYLongPressSpeed"
							       optionsArray:speedOptions
								 headerText:@"選擇右側長按倍速"
							     onPresentingVC:topView()
							   selectionChanged:^(NSString *selectedValue) {
							     item.detail = selectedValue;
							     [item refreshCell];
							   }];
			  };
		  }

		  else if ([item.identifier isEqualToString:@"DYYYScheduleStyle"]) {
			  NSString *savedStyle = [[NSUserDefaults standardUserDefaults] objectForKey:@"DYYYScheduleStyle"];
			  item.detail = savedStyle ?: @"預設";
			  item.cellTappedBlock = ^{
			    NSArray *styleOptions = @[ @"進度條兩側上下", @"進度條左側剩餘", @"進度條左側完整", @"進度條右側剩餘", @"進度條右側完整" ];

			    [DYYYOptionsSelectionView showWithPreferenceKey:@"DYYYScheduleStyle"
							       optionsArray:styleOptions
								 headerText:@"選擇進度時長樣式"
							     onPresentingVC:topView()
							   selectionChanged:^(NSString *selectedValue) {
							     item.detail = selectedValue;
							     [item refreshCell];
							   }];
			  };
		  }

		  [videoItems addObject:item];
	  }
	  // 【杂项设置】分类
	  NSMutableArray<AWESettingItemModel *> *miscellaneousItems = [NSMutableArray array];
	  NSArray *miscellaneousSettings = @[
		  @{@"identifier" : @"DYYYEnableLiveHighestQuality",
		    @"title" : @"直播預設最高畫質",
		    @"detail" : @"",
		    @"cellType" : @6,
		    @"imageName" : @"ic_video_outlined_20"},
		  @{@"identifier" : @"DYYYEnableVideoHighestQuality",
		    @"title" : @"影片預設最高畫質",
		    @"detail" : @"",
		    @"cellType" : @6,
		    @"imageName" : @"ic_squaretriangletwo_outlined_20"},
		  @{@"identifier" : @"DYYYisHideStatusbar",
		    @"title" : @"隱藏系統頂欄",
		    @"detail" : @"",
		    @"cellType" : @6,
		    @"imageName" : @"ic_eyeslash_outlined_16"},
		  @{@"identifier" : @"DYYYisEnablePure",
		    @"title" : @"啟用首頁淨化",
		    @"detail" : @"",
		    @"cellType" : @6,
		    @"imageName" : @"ic_broom_outlined"},
		  @{@"identifier" : @"DYYYisEnableFullScreen",
		    @"title" : @"啟用首頁全螢幕",
		    @"detail" : @"",
		    @"cellType" : @6,
		    @"imageName" : @"ic_fullscreen_outlined_16"}
	  ];

	  for (NSDictionary *dict in miscellaneousSettings) {
		  AWESettingItemModel *item = [DYYYSettingsHelper createSettingItem:dict cellTapHandlers:cellTapHandlers];
		  [miscellaneousItems addObject:item];
	  }
	  // 【过滤与屏蔽】分类
	  NSMutableArray<AWESettingItemModel *> *filterItems = [NSMutableArray array];
	  NSArray *filterSettings = @[
		  @{@"identifier" : @"DYYYisSkipLive",
		    @"title" : @"推薦過濾直播",
		    @"detail" : @"",
		    @"cellType" : @6,
		    @"imageName" : @"ic_video_outlined_20"},
		  @{@"identifier" : @"DYYYisSkipHotSpot",
		    @"title" : @"推薦過濾熱點",
		    @"detail" : @"",
		    @"cellType" : @6,
		    @"imageName" : @"ic_squaretriangletwo_outlined_20"},
		  @{@"identifier" : @"DYYYfilterLowLikes",
		    @"title" : @"推薦過濾低讚",
		    @"detail" : @"0",
		    @"cellType" : @26,
		    @"imageName" : @"ic_thumbsdown_outlined_20"},
		  @{@"identifier" : @"DYYYfilterKeywords",
		    @"title" : @"推薦過濾文案",
		    @"detail" : @"",
		    @"cellType" : @26,
		    @"imageName" : @"ic_tag_outlined_20"},
		  @{@"identifier" : @"DYYYfilterUsers",
		    @"title" : @"推薦過濾使用者",
		    @"detail" : @"",
		    @"cellType" : @26,
		    @"imageName" : @"ic_userban_outlined_20"},	
		  @{@"identifier" : @"DYYYfiltertimelimit",
		    @"title" : @"推薦影片時限",
		    @"detail" : @"",
		    @"cellType" : @26,
		    @"imageName" : @"ic_playertime_outlined_20"},
		  @{
			  @"identifier" : @"DYYYfilterFeedHDR",
			  @"title" : @"推薦過濾HDR",
			  @"subTitle" : @"開啟後推薦頁面會屏蔽 HDR 影片",
			  @"detail" : @"",
			  @"cellType" : @37,
			  @"imageName" : @"ic_sun_outlined"
		  },
		  @{@"identifier" : @"DYYYfilterProp",
		    @"title" : @"推薦過濾拍同款",
		    @"detail" : @"",
		    @"cellType" : @26,
		    @"imageName" : @"ic_tag_outlined_20"},
		  @{@"identifier" : @"DYYYNoAds",
		    @"title" : @"啟用屏蔽廣告",
		    @"detail" : @"",
		    @"cellType" : @6,
		    @"imageName" : @"ic_ad_outlined_20"},
		  @{@"identifier" : @"DYYYHideteenmode",
		    @"title" : @"移除青少年彈窗",
		    @"detail" : @"",
		    @"cellType" : @6,
		    @"imageName" : @"ic_personcircleclean_outlined_20"},
		  @{
			  @"identifier" : @"DYYYNoUpdates",
			  @"title" : @"屏蔽抖音檢測更新",
			  @"subTitle" : @"屏蔽抖音應用的版本更新",
			  @"detail" : @"",
			  @"cellType" : @37,
			  @"imageName" : @"ic_circletop_outlined"
		  },
		  @{@"identifier" : @"DYYYDisableLivePCDN",
		    @"title" : @"屏蔽直播PCDN功能",
		    @"detail" : @"",
		    @"cellType" : @6,
		    @"imageName" : @"ic_video_outlined_20"}
	  ];

	  for (NSDictionary *dict in filterSettings) {
		  AWESettingItemModel *item = [DYYYSettingsHelper createSettingItem:dict cellTapHandlers:cellTapHandlers];

		  if ([item.identifier isEqualToString:@"DYYYfilterLowLikes"]) {
			  NSString *savedValue = [[NSUserDefaults standardUserDefaults] objectForKey:@"DYYYfilterLowLikes"];
			  item.detail = savedValue ?: @"0";
			  item.cellTappedBlock = ^{
			    [DYYYSettingsHelper showTextInputAlert:@"設定過濾讚數閾值"
						       defaultText:item.detail
						       placeholder:@"填0關閉功能"
							 onConfirm:^(NSString *text) {
							   NSScanner *scanner = [NSScanner scannerWithString:text];
							   NSInteger value;
							   BOOL isValidNumber = [scanner scanInteger:&value] && [scanner isAtEnd];

							   if (isValidNumber) {
								   if (value < 0)
									   value = 0;
								   NSString *valueString = [NSString stringWithFormat:@"%ld", (long)value];
								   [DYYYSettingsHelper setUserDefaults:valueString forKey:@"DYYYfilterLowLikes"];

								   item.detail = valueString;
								   [item refreshCell];
							   } else {
								   DYYYAboutDialogView *errorDialog = [[DYYYAboutDialogView alloc] initWithTitle:@"輸入錯誤" message:@"\n\n請輸入有效的數字\n\n"];
								   [errorDialog show];
							   }
							 }
							  onCancel:nil];
			  };
		  } else if ([item.identifier isEqualToString:@"DYYYfilterUsers"]) {
			  NSString *savedValue = [[NSUserDefaults standardUserDefaults] objectForKey:@"DYYYfilterUsers"];
			  item.detail = savedValue ?: @"";
			  item.cellTappedBlock = ^{
			    // 将保存的逗号分隔字符串转换为数组
			    NSString *savedKeywords = [[NSUserDefaults standardUserDefaults] objectForKey:@"DYYYfilterUsers"] ?: @"";
			    NSArray *keywordArray = [savedKeywords length] > 0 ? [savedKeywords componentsSeparatedByString:@","] : @[];
			    DYYYKeywordListView *keywordListView = [[DYYYKeywordListView alloc] initWithTitle:@"過濾使用者列表" keywords:keywordArray];
			    keywordListView.onConfirm = ^(NSArray *keywords) {
			      NSString *keywordString = [keywords componentsJoinedByString:@","];
			      [DYYYSettingsHelper setUserDefaults:keywordString forKey:@"DYYYfilterUsers"];
			      item.detail = keywordString;
			      [item refreshCell];
			    };

			    [keywordListView show];
			  };
		  } else if ([item.identifier isEqualToString:@"DYYYfilterKeywords"]) {
			  NSString *savedValue = [[NSUserDefaults standardUserDefaults] objectForKey:@"DYYYfilterKeywords"];
			  item.detail = savedValue ?: @"";
			  item.cellTappedBlock = ^{
			    NSString *savedKeywords = [[NSUserDefaults standardUserDefaults] objectForKey:@"DYYYfilterKeywords"] ?: @"";
			    NSArray *keywordArray = [savedKeywords length] > 0 ? [savedKeywords componentsSeparatedByString:@","] : @[];
			    DYYYKeywordListView *keywordListView = [[DYYYKeywordListView alloc] initWithTitle:@"設定過濾關鍵詞" keywords:keywordArray];
			    keywordListView.onConfirm = ^(NSArray *keywords) {
			      NSString *keywordString = [keywords componentsJoinedByString:@","];

			      [DYYYSettingsHelper setUserDefaults:keywordString forKey:@"DYYYfilterKeywords"];
			      item.detail = keywordString;
			      [item refreshCell];
			    };
			    [keywordListView show];
			  };
		  } else if ([item.identifier isEqualToString:@"DYYYfiltertimelimit"]) {
			  NSString *savedValue = [[NSUserDefaults standardUserDefaults] objectForKey:@"DYYYfiltertimelimit"];
			  item.detail = savedValue ?: @"";
			  item.cellTappedBlock = ^{
			    [DYYYSettingsHelper showTextInputAlert:@"過濾影片的發布時間"
						       defaultText:item.detail
						       placeholder:@"單位為天"
							 onConfirm:^(NSString *text) {
							   NSString *trimmedText = [text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
							   [DYYYSettingsHelper setUserDefaults:trimmedText forKey:@"DYYYfiltertimelimit"];
							   item.detail = trimmedText ?: @"";
							   [item refreshCell];
							 }
							  onCancel:nil];
			  };
		  } else if ([item.identifier isEqualToString:@"DYYYfilterProp"]) {
			  NSString *savedValue = [[NSUserDefaults standardUserDefaults] objectForKey:@"DYYYfilterProp"];
			  item.detail = savedValue ?: @"";
			  item.cellTappedBlock = ^{
			    NSString *savedKeywords = [[NSUserDefaults standardUserDefaults] objectForKey:@"DYYYfilterProp"] ?: @"";
			    NSArray *keywordArray = [savedKeywords length] > 0 ? [savedKeywords componentsSeparatedByString:@","] : @[];
			    DYYYKeywordListView *keywordListView = [[DYYYKeywordListView alloc] initWithTitle:@"設定過濾詞（支援部分匹配）" keywords:keywordArray];
			    keywordListView.onConfirm = ^(NSArray *keywords) {
			      NSString *keywordString = [keywords componentsJoinedByString:@","];

			      [DYYYSettingsHelper setUserDefaults:keywordString forKey:@"DYYYfilterProp"];
			      item.detail = keywordString;
			      [item refreshCell];
			    };
			    [keywordListView show];
			  };
		  }
		  [filterItems addObject:item];
	  }

	  // 【二次确认】分类
	  NSMutableArray<AWESettingItemModel *> *securityItems = [NSMutableArray array];
	  NSArray *securitySettings = @[
		  @{@"identifier" : @"DYYYfollowTips",
		    @"title" : @"關注二次確認",
		    @"detail" : @"",
		    @"cellType" : @6,
		    @"imageName" : @"ic_userplus_outlined_20"},
		  @{@"identifier" : @"DYYYcollectTips",
		    @"title" : @"收藏二次確認",
		    @"detail" : @"",
		    @"cellType" : @6,
		    @"imageName" : @"ic_star_outlined_20"}
	  ];

	  for (NSDictionary *dict in securitySettings) {
		  AWESettingItemModel *item = [DYYYSettingsHelper createSettingItem:dict];
		  [securityItems addObject:item];
	  }

	  // 创建并组织所有section
	  NSMutableArray *sections = [NSMutableArray array];
	  [sections addObject:[DYYYSettingsHelper createSectionWithTitle:@"外觀設定" items:appearanceItems]];
	  [sections addObject:[DYYYSettingsHelper createSectionWithTitle:@"影片播放" items:videoItems]];
	  [sections addObject:[DYYYSettingsHelper createSectionWithTitle:@"雜項設定" items:miscellaneousItems]];
	  [sections addObject:[DYYYSettingsHelper createSectionWithTitle:@"過濾與屏蔽" items:filterItems]];
	  [sections addObject:[DYYYSettingsHelper createSectionWithTitle:@"二次確認" items:securityItems]];
	  
	  // 创建并推入二级设置页面
	  AWESettingBaseViewController *subVC = [DYYYSettingsHelper createSubSettingsViewController:@"基本設定" sections:sections];
	  [rootVC.navigationController pushViewController:(UIViewController *)subVC animated:YES];
	};
	[mainItems addObject:basicSettingItem];

	// 创建界面设置分类项
	AWESettingItemModel *uiSettingItem = [[%c(AWESettingItemModel) alloc] init];
	uiSettingItem.identifier = @"DYYYUISettings";
	uiSettingItem.title = @"介面設定";
	uiSettingItem.type = 0;
	uiSettingItem.svgIconImageName = @"ic_ipadiphone_outlined";
	uiSettingItem.cellType = 26;
	uiSettingItem.colorStyle = 0;
	uiSettingItem.isEnable = YES;
	uiSettingItem.cellTappedBlock = ^{
	  // 创建界面设置二级界面的设置项
	  NSMutableDictionary *cellTapHandlers = [NSMutableDictionary dictionary];

	  // 【透明度設定】分类
	  NSMutableArray<AWESettingItemModel *> *transparencyItems = [NSMutableArray array];
	  NSArray *transparencySettings = @[
		  @{@"identifier" : @"DYYYtopbartransparent",
		    @"title" : @"設定頂欄透明",
		    @"detail" : @"0-1小數",
		    @"cellType" : @26,
		    @"imageName" : @"ic_module_outlined_20"},
		  @{@"identifier" : @"DYYYGlobalTransparency",
		    @"title" : @"設定全局透明",
		    @"detail" : @"0-1小數",
		    @"cellType" : @26,
		    @"imageName" : @"ic_eye_outlined_20"},
		  @{@"identifier" : @"DYYYAvatarViewTransparency",
		    @"title" : @"首頁頭像透明",
		    @"detail" : @"0-1小數",
		    @"cellType" : @26,
		    @"imageName" : @"ic_user_outlined_20"},
		  @{@"identifier" : @"DYYYisEnableCommentBlur",
		    @"title" : @"評論區毛玻璃",
		    @"detail" : @"",
		    @"cellType" : @6,
		    @"imageName" : @"ic_comment_outlined_20"},
		  @{@"identifier" : @"DYYYisEnableCommentBarBlur",
		    @"title" : @"評論欄毛玻璃",
		    @"detail" : @"",
		    @"cellType" : @6,
		    @"imageName" : @"ic_msgnut_outlined_20"},
		  @{@"identifier" : @"DYYYEnableNotificationTransparency",
		    @"title" : @"通知欄毛玻璃",
		    @"detail" : @"",
		    @"cellType" : @6,
		    @"imageName" : @"ic_comment_outlined_20"},
		  @{@"identifier" : @"DYYYNotificationCornerRadius",
		    @"title" : @"通知圓角半徑",
		    @"detail" : @"預設12",
		    @"cellType" : @26,
		    @"imageName" : @"ic_comment_outlined_20"},
		  @{@"identifier" : @"DYYYCommentBlurTransparent",
		    @"title" : @"毛玻璃透明度",
		    @"detail" : @"0-1小數",
		    @"cellType" : @26,
		    @"imageName" : @"ic_eye_outlined_20"},
	  ];

	  for (NSDictionary *dict in transparencySettings) {
		  AWESettingItemModel *item = [DYYYSettingsHelper createSettingItem:dict cellTapHandlers:cellTapHandlers];
		  [transparencyItems addObject:item];
	  }

	  // 【缩放与大小】分类
	  NSMutableArray<AWESettingItemModel *> *scaleItems = [NSMutableArray array];
	  NSArray *scaleSettings = @[
		  @{@"identifier" : @"DYYYElementScale",
		    @"title" : @"右側欄縮放度",
		    @"detail" : @"不填預設",
		    @"cellType" : @26,
		    @"imageName" : @"ic_zoomin_outlined_20"},
		  @{@"identifier" : @"DYYYNicknameScale",
		    @"title" : @"暱稱文案縮放",
		    @"detail" : @"不填預設",
		    @"cellType" : @26,
		    @"imageName" : @"ic_zoomin_outlined_20"},
		  @{@"identifier" : @"DYYYNicknameVerticalOffset",
		    @"title" : @"暱稱下移距離",
		    @"detail" : @"不填預設",
		    @"cellType" : @26,
		    @"imageName" : @"ic_pensketch_outlined_20"},
		  @{@"identifier" : @"DYYYDescriptionVerticalOffset",
		    @"title" : @"文案下移距離",
		    @"detail" : @"不填預設",
		    @"cellType" : @26,
		    @"imageName" : @"ic_pensketch_outlined_20"},
		  @{@"identifier" : @"DYYYIPLabelVerticalOffset",
		    @"title" : @"屬地上移距離",
		    @"detail" : @"預設為 3",
		    @"cellType" : @26,
		    @"imageName" : @"ic_pensketch_outlined_20"},
		  @{@"identifier" : @"DYYYTabBarHeight",
		    @"title" : @"首頁底欄高度",
		    @"detail" : @"預設83",
		    @"cellType" : @26,
		    @"imageName" : @"ic_pensketch_outlined_20"},
	  ];

	  for (NSDictionary *dict in scaleSettings) {
		  AWESettingItemModel *item = [DYYYSettingsHelper createSettingItem:dict cellTapHandlers:cellTapHandlers];
		  [scaleItems addObject:item];
	  }

	  // 【标题自定义】分类
	  NSMutableArray<AWESettingItemModel *> *titleItems = [NSMutableArray array];
	  NSArray *titleSettings = @[
		  @{@"identifier" : @"DYYYModifyTopTabText",
		    @"title" : @"設定頂欄標題",
		    @"detail" : @"標題=修改#標題=修改",
		    @"cellType" : @26,
		    @"imageName" : @"ic_tag_outlined_20"},
		  @{@"identifier" : @"DYYYIndexTitle",
		    @"title" : @"設定首頁標題",
		    @"detail" : @"不填預設",
		    @"cellType" : @26,
		    @"imageName" : @"ic_squaretriangle_outlined_20"},
		  @{@"identifier" : @"DYYYFriendsTitle",
		    @"title" : @"設定朋友標題",
		    @"detail" : @"不填預設",
		    @"cellType" : @26,
		    @"imageName" : @"ic_usertwo_outlined_20"},
		  @{@"identifier" : @"DYYYMsgTitle",
		    @"title" : @"設定訊息標題",
		    @"detail" : @"不填預設",
		    @"cellType" : @26,
		    @"imageName" : @"ic_msg_outlined_20"},
		  @{@"identifier" : @"DYYYDYYYSettingsHelperTitle",
		    @"title" : @"設定我的標題",
		    @"detail" : @"不填預設",
		    @"cellType" : @26,
		    @"imageName" : @"ic_user_outlined_20"},
	  ];

	  for (NSDictionary *dict in titleSettings) {
		  AWESettingItemModel *item = [DYYYSettingsHelper createSettingItem:dict cellTapHandlers:cellTapHandlers];
		  if ([item.identifier isEqualToString:@"DYYYModifyTopTabText"]) {
			  NSString *savedValue = [[NSUserDefaults standardUserDefaults] objectForKey:@"DYYYModifyTopTabText"];
			  item.detail = savedValue ?: @"";
			  item.cellTappedBlock = ^{
			    NSString *savedPairs = [[NSUserDefaults standardUserDefaults] objectForKey:@"DYYYModifyTopTabText"] ?: @"";
			    NSArray *pairArray = savedPairs.length > 0 ? [savedPairs componentsSeparatedByString:@"#"] : @[];
			    DYYYKeywordListView *keywordListView = [[DYYYKeywordListView alloc] initWithTitle:@"設定頂欄標題" keywords:pairArray];
			    keywordListView.addItemTitle = @"新增標題修改";
			    keywordListView.editItemTitle = @"編輯標題修改";
			    keywordListView.inputPlaceholder = @"原標題=新標題";
			    keywordListView.onConfirm = ^(NSArray *keywords) {
			      NSString *keywordString = [keywords componentsJoinedByString:@"#"];
			      [DYYYSettingsHelper setUserDefaults:keywordString forKey:@"DYYYModifyTopTabText"];
			      item.detail = keywordString;
			      [item refreshCell];
			    };
			    [keywordListView show];
			  };
		  }
		  [titleItems addObject:item];
	  }

	  // 【图标自定义】分类
	  NSMutableArray<AWESettingItemModel *> *iconItems = [NSMutableArray array];

	  [iconItems addObject:[DYYYSettingsHelper createIconCustomizationItemWithIdentifier:@"DYYYIconLikeBefore" title:@"未按讚圖示" svgIcon:@"ic_heart_outlined_20" saveFile:@"like_before.png"]];
	  [iconItems addObject:[DYYYSettingsHelper createIconCustomizationItemWithIdentifier:@"DYYYIconLikeAfter" title:@"已按讚圖示" svgIcon:@"ic_heart_filled_20" saveFile:@"like_after.png"]];
	  [iconItems addObject:[DYYYSettingsHelper createIconCustomizationItemWithIdentifier:@"DYYYIconComment" title:@"評論的圖示" svgIcon:@"ic_comment_outlined_20" saveFile:@"comment.png"]];
	  [iconItems addObject:[DYYYSettingsHelper createIconCustomizationItemWithIdentifier:@"DYYYIconUnfavorite" title:@"未收藏圖示" svgIcon:@"ic_star_outlined_20" saveFile:@"unfavorite.png"]];
	  [iconItems addObject:[DYYYSettingsHelper createIconCustomizationItemWithIdentifier:@"DYYYIconFavorite" title:@"已收藏圖示" svgIcon:@"ic_star_filled_20" saveFile:@"favorite.png"]];
	  [iconItems addObject:[DYYYSettingsHelper createIconCustomizationItemWithIdentifier:@"DYYYIconShare" title:@"分享的圖示" svgIcon:@"ic_share_outlined" saveFile:@"share.png"]];
	  [iconItems addObject:[DYYYSettingsHelper createIconCustomizationItemWithIdentifier:@"DYYYIconPlus" title:@"拍攝的圖示" svgIcon:@"ic_camera_outlined" saveFile:@"tab_plus.png"]];

	  NSMutableArray *sections = [NSMutableArray array];
	  [sections addObject:[DYYYSettingsHelper createSectionWithTitle:@"透明度設定" items:transparencyItems]];
	  [sections addObject:[DYYYSettingsHelper createSectionWithTitle:@"縮放與大小" items:scaleItems]];
	  [sections addObject:[DYYYSettingsHelper createSectionWithTitle:@"標題自訂" items:titleItems]];
	  [sections addObject:[DYYYSettingsHelper createSectionWithTitle:@"圖示自訂" items:iconItems]];
	  // 创建并组织所有section
	  // 创建并推入二级设置页面
	  AWESettingBaseViewController *subVC = [DYYYSettingsHelper createSubSettingsViewController:@"介面設定" sections:sections];	  
	  [rootVC.navigationController pushViewController:(UIViewController *)subVC animated:YES];
	};

	[mainItems addObject:uiSettingItem];

	// 创建隐藏设置分类项
	AWESettingItemModel *hideSettingItem = [[%c(AWESettingItemModel) alloc] init];
	hideSettingItem.identifier = @"DYYYHideSettings";
	hideSettingItem.title = @"隱藏設定";
	hideSettingItem.type = 0;
	hideSettingItem.svgIconImageName = @"ic_eyeslash_outlined_20";
	hideSettingItem.cellType = 26;
	hideSettingItem.colorStyle = 0;
	hideSettingItem.isEnable = YES;
	hideSettingItem.cellTappedBlock = ^{
	  // 创建隐藏设置二级界面的设置项

	  // 【主介面元素】分类
	  NSMutableArray<AWESettingItemModel *> *mainUiItems = [NSMutableArray array];
	  NSArray *mainUiSettings = @[
		  @{
			  @"identifier" : @"DYYYisHiddenBottomBg",
			  @"title" : @"隱藏底欄背景",
			  @"subTitle" : @"完全透明化底欄，可能需要配合首頁全螢幕使用",
			  @"detail" : @"",
			  @"cellType" : @37,
			  @"imageName" : @"ic_eyeslash_outlined_16"
		  },	  
		  @{@"identifier" : @"DYYYisHiddenBottomDot",
		    @"title" : @"隱藏底欄紅點",
		    @"detail" : @"",
		    @"cellType" : @6,
		    @"imageName" : @"ic_eyeslash_outlined_16"},
		  @{
			  @"identifier" : @"DYYYHideDoubleColumnEntry",
			  @"title" : @"隱藏雙列箭頭",
			  @"subTitle" : @"隱藏底欄首頁旁的雙列箭頭",
			  @"detail" : @"",
			  @"cellType" : @37,
			  @"imageName" : @"ic_eyeslash_outlined_16"
		  },
		  @{@"identifier" : @"DYYYHideShopButton",
		    @"title" : @"隱藏底欄商城",
		    @"detail" : @"",
		    @"cellType" : @6,
		    @"imageName" : @"ic_eyeslash_outlined_16"},
		  @{@"identifier" : @"DYYYHideMessageButton",
		    @"title" : @"隱藏底欄訊息",
		    @"detail" : @"",
		    @"cellType" : @6,
		    @"imageName" : @"ic_eyeslash_outlined_16"},
		  @{@"identifier" : @"DYYYHideFriendsButton",
		    @"title" : @"隱藏底欄朋友",
		    @"detail" : @"",
		    @"cellType" : @6,
		    @"imageName" : @"ic_eyeslash_outlined_16"},
		  @{@"identifier" : @"DYYYisHiddenJia",
		    @"title" : @"隱藏底欄加號",
		    @"detail" : @"",
		    @"cellType" : @6,
		    @"imageName" : @"ic_eyeslash_outlined_16"},
		  @{@"identifier" : @"DYYYHideMyButton",
		    @"title" : @"隱藏底欄我的",
		    @"detail" : @"",
		    @"cellType" : @6,
		    @"imageName" : @"ic_eyeslash_outlined_16"},
		  @{@"identifier" : @"DYYYHideComment",
		    @"title" : @"隱藏底欄評論",
		    @"detail" : @"",
		    @"cellType" : @6,
		    @"imageName" : @"ic_eyeslash_outlined_16"},
		  @{@"identifier" : @"DYYYHideHotSearch",
		    @"title" : @"隱藏底欄熱榜",
		    @"detail" : @"",
		    @"cellType" : @6,
		    @"imageName" : @"ic_eyeslash_outlined_16"},
		  @{@"identifier" : @"DYYYHideTopBarBadge",
		    @"title" : @"隱藏頂欄紅點",
		    @"detail" : @"",
		    @"cellType" : @6,
		    @"imageName" : @"ic_eyeslash_outlined_16"}
	  ];

	  for (NSDictionary *dict in mainUiSettings) {
		  AWESettingItemModel *item = [DYYYSettingsHelper createSettingItem:dict];
		  [mainUiItems addObject:item];
	  }

	  // 【影片播放介面】分类
	  NSMutableArray<AWESettingItemModel *> *videoUiItems = [NSMutableArray array];
	  NSArray *videoUiSettings = @[
		  @{
			  @"identifier" : @"DYYYHideLOTAnimationView",
			  @"title" : @"隱藏頭像加號",
			  @"subTitle" : @"原始位置可點擊",
			  @"detail" : @"",
			  @"cellType" : @37,
			  @"imageName" : @"ic_eyeslash_outlined_16"
		  },
		  @{
			  @"identifier" : @"DYYYHideFollowPromptView",
			  @"title" : @"移除頭像加號",
			  @"subTitle" : @"完全移除不可點擊",
			  @"detail" : @"",
			  @"cellType" : @37,
			  @"imageName" : @"ic_eyeslash_outlined_16"
		  },
		  @{@"identifier" : @"DYYYHideLikeLabel",
		    @"title" : @"隱藏按讚數值",
		    @"detail" : @"",
		    @"cellType" : @6,
		    @"imageName" : @"ic_eyeslash_outlined_16"},
		  @{@"identifier" : @"DYYYHideCommentLabel",
		    @"title" : @"隱藏評論數值",
		    @"detail" : @"",
		    @"cellType" : @6,
		    @"imageName" : @"ic_eyeslash_outlined_16"},
		  @{@"identifier" : @"DYYYHideCollectLabel",
		    @"title" : @"隱藏收藏數值",
		    @"detail" : @"",
		    @"cellType" : @6,
		    @"imageName" : @"ic_eyeslash_outlined_16"},
		  @{@"identifier" : @"DYYYHideShareLabel",
		    @"title" : @"隱藏分享數值",
		    @"detail" : @"",
		    @"cellType" : @6,
		    @"imageName" : @"ic_eyeslash_outlined_16"},
		  @{@"identifier" : @"DYYYHideLikeButton",
		    @"title" : @"隱藏按讚按鈕",
		    @"detail" : @"",
		    @"cellType" : @6,
		    @"imageName" : @"ic_eyeslash_outlined_16"},
		  @{@"identifier" : @"DYYYHideCommentButton",
		    @"title" : @"隱藏評論按鈕",
		    @"detail" : @"",
		    @"cellType" : @6,
		    @"imageName" : @"ic_eyeslash_outlined_16"},
		  @{@"identifier" : @"DYYYHideCollectButton",
		    @"title" : @"隱藏收藏按鈕",
		    @"detail" : @"",
		    @"cellType" : @6,
		    @"imageName" : @"ic_eyeslash_outlined_16"},
		  @{@"identifier" : @"DYYYHideShareButton",
		    @"title" : @"隱藏分享按鈕",
		    @"detail" : @"",
		    @"cellType" : @6,
		    @"imageName" : @"ic_eyeslash_outlined_16"},
		  @{@"identifier" : @"DYYYHideAvatarButton",
		    @"title" : @"隱藏頭像按鈕",
		    @"detail" : @"",
		    @"cellType" : @6,
		    @"imageName" : @"ic_eyeslash_outlined_16"},
		  @{@"identifier" : @"DYYYHideMusicButton",
		    @"title" : @"隱藏音樂按鈕",
		    @"detail" : @"",
		    @"cellType" : @6,
		    @"imageName" : @"ic_eyeslash_outlined_16"},
		  @{@"identifier" : @"DYYYHideGradient",
		    @"title" : @"隱藏遮罩效果",
		    @"detail" : @"",
		    @"cellType" : @6,			
		    @"imageName" : @"ic_eyeslash_outlined_16"},
		  @{@"identifier" : @"DYYYisHiddenEntry",
		    @"title" : @"隱藏全螢幕觀看",
		    @"detail" : @"",
		    @"cellType" : @6,
		    @"imageName" : @"ic_eyeslash_outlined_16"}
	  ];

	  for (NSDictionary *dict in videoUiSettings) {
		  AWESettingItemModel *item = [DYYYSettingsHelper createSettingItem:dict];
		  [videoUiItems addObject:item];
	  }

	  // 【侧边栏】分类
	  NSMutableArray<AWESettingItemModel *> *sidebarItems = [NSMutableArray array];
	  NSArray *sidebarSettings = @[
		  @{@"identifier" : @"DYYYStreamlinethesidebar",
		    @"title" : @"隱藏側欄元素",
		    @"detail" : @"",
		    @"cellType" : @6,
		    @"imageName" : @"ic_eyeslash_outlined_16"},
		  @{@"identifier" : @"DYYYisHiddenSidebarDot",
		    @"title" : @"隱藏側欄紅點",
		    @"detail" : @"",
		    @"cellType" : @6,
		    @"imageName" : @"ic_eyeslash_outlined_16"},
		  @{@"identifier" : @"DYYYisHiddenLeftSideBar",
		    @"title" : @"隱藏左側邊欄",
		    @"detail" : @"",
		    @"cellType" : @6,
		    @"imageName" : @"ic_eyeslash_outlined_16"},
		  @{
			  @"identifier" : @"DYYYHideBack",
			  @"title" : @"隱藏返回按鈕",
			  @"subTitle" : @"主頁影片左上角的返回按鈕",
			  @"detail" : @"",
			  @"cellType" : @37,
			  @"imageName" : @"ic_eyeslash_outlined_16"
		  },
		  @{@"identifier" : @"DYYYHideSettingsAbout",
		    @"title" : @"隱藏設定關於",
		    @"detail" : @"",
		    @"cellType" : @6,
		    @"imageName" : @"ic_eyeslash_outlined_16"},
	  ];

	  for (NSDictionary *dict in sidebarSettings) {
		  AWESettingItemModel *item = [DYYYSettingsHelper createSettingItem:dict];
		  [sidebarItems addObject:item];
	  }

	  // 【消息页与我的页】分类
	  NSMutableArray<AWESettingItemModel *> *messageAndMineItems = [NSMutableArray array];
	  NSArray *messageAndMineSettings = @[
		  @{@"identifier" : @"DYYYHidePushBanner",
		    @"title" : @"隱藏通知權限提示",
		    @"detail" : @"",
		    @"cellType" : @6,
		    @"imageName" : @"ic_eyeslash_outlined_16"},
		  @{@"identifier" : @"DYYYisHiddenAvatarList",
		    @"title" : @"隱藏訊息頭像列表",
		    @"detail" : @"",
		    @"cellType" : @6,
		    @"imageName" : @"ic_eyeslash_outlined_16"},
		  @{@"identifier" : @"DYYYisHiddenAvatarBubble",
		    @"title" : @"隱藏訊息頭像氣泡",
		    @"detail" : @"",
		    @"cellType" : @6,
		    @"imageName" : @"ic_eyeslash_outlined_16"},
		  @{@"identifier" : @"DYYYHideButton",
		    @"title" : @"隱藏我的添加朋友",
		    @"detail" : @"",
		    @"cellType" : @6,
		    @"imageName" : @"ic_eyeslash_outlined_16"},
		  @{@"identifier" : @"DYYYHideFamiliar",
		    @"title" : @"隱藏朋友日常按鈕",
		    @"detail" : @"",
		    @"cellType" : @6,
		    @"imageName" : @"ic_eyeslash_outlined_16"},
		  @{@"identifier" : @"DYYYHideGroupShop",
		    @"title" : @"隱藏群聊商店按鈕",
		    @"detail" : @"",
		    @"cellType" : @6,
		    @"imageName" : @"ic_eyeslash_outlined_16"},
		  @{@"identifier" : @"DYYYGroupLiving",
		    @"title" : @"隱藏群頭像直播中",
		    @"detail" : @"",
		    @"cellType" : @6,
		    @"imageName" : @"ic_eyeslash_outlined_16"},
		  @{@"identifier" : @"DYYYHideGroupInputActionBar",
		    @"title" : @"隱藏聊天頁工具欄",
		    @"detail" : @"",
		    @"cellType" : @6,
		    @"imageName" : @"ic_eyeslash_outlined_16"},
		  @{@"identifier" : @"DYYYHidePostView",
		    @"title" : @"隱藏我的頁發作品",
		    @"detail" : @"",
		    @"cellType" : @6,
		    @"imageName" : @"ic_eyeslash_outlined_16"}
	  ];
	  for (NSDictionary *dict in messageAndMineSettings) {
		  AWESettingItemModel *item = [DYYYSettingsHelper createSettingItem:dict];
		  [messageAndMineItems addObject:item];
	  }

	  // 【提示与位置信息】分类
	  NSMutableArray<AWESettingItemModel *> *infoItems = [NSMutableArray array];
	  NSArray *infoSettings = @[
		  @{@"identifier" : @"DYYYHidenLiveView",
		    @"title" : @"隱藏關注頂端",
		    @"detail" : @"",
		    @"cellType" : @6,
		    @"imageName" : @"ic_eyeslash_outlined_16"},
		  @{@"identifier" : @"DYYYHideMenuView",
		    @"title" : @"隱藏同城頂端",
		    @"detail" : @"",
		    @"cellType" : @6,
		    @"imageName" : @"ic_eyeslash_outlined_16"},
		  @{@"identifier" : @"DYYYHideNearbyCapsuleView",
		    @"title" : @"隱藏吃喝玩樂",
		    @"detail" : @"",
		    @"cellType" : @6,
		    @"imageName" : @"ic_eyeslash_outlined_16"},
		  @{@"identifier" : @"DYYYHideDiscover",
		    @"title" : @"隱藏右上搜尋",	
		    @"detail" : @"",
		    @"cellType" : @6,
		    @"imageName" : @"ic_eyeslash_outlined_16"},
		  @{@"identifier" : @"DYYYHideCommentDiscover",
		    @"title" : @"隱藏評論搜尋",
		    @"detail" : @"",
		    @"cellType" : @6,
		    @"imageName" : @"ic_eyeslash_outlined_16"},
		  @{@"identifier" : @"DYYYHideInteractionSearch",
		    @"title" : @"隱藏相關搜尋",
		    @"detail" : @"",
		    @"cellType" : @6,
		    @"imageName" : @"ic_eyeslash_outlined_16"},
		  @{
			  @"identifier" : @"DYYYHideSearchBubble",
			  @"title" : @"隱藏彈出熱搜",
			  @"subTitle" : @"從右上搜尋位置彈出的熱搜白框",
			  @"detail" : @"",
			  @"cellType" : @37,
			  @"imageName" : @"ic_eyeslash_outlined_16"
		  },
		  @{@"identifier" : @"DYYYHideSearchSame",
		    @"title" : @"隱藏搜尋同款",
		    @"detail" : @"",
		    @"cellType" : @6,
		    @"imageName" : @"ic_eyeslash_outlined_16"},
		  @{@"identifier" : @"DYYYHideSearchEntrance",
		    @"title" : @"隱藏頂部搜尋框",
		    @"detail" : @"",
		    @"cellType" : @6,
		    @"imageName" : @"ic_eyeslash_outlined_16"},
		  @{@"identifier" : @"DYYYHideSearchEntranceIndicator",
		    @"title" : @"隱藏搜尋指示條",
		    @"detail" : @"",
		    @"cellType" : @6,
		    @"imageName" : @"ic_eyeslash_outlined_16"},
		  @{@"identifier" : @"DYYYHideDanmuButton",
		    @"title" : @"隱藏彈幕按鈕",
		    @"detail" : @"",
		    @"cellType" : @6,
		    @"imageName" : @"ic_eyeslash_outlined_16"},
		  @{@"identifier" : @"DYYYHideCancelMute",
		    @"title" : @"隱藏靜音按鈕",
		    @"detail" : @"",
		    @"cellType" : @6,
		    @"imageName" : @"ic_eyeslash_outlined_16"},
		  @{@"identifier" : @"DYYYHideLocation",
		    @"title" : @"隱藏影片定位",
		    @"detail" : @"",
		    @"cellType" : @6,
		    @"imageName" : @"ic_eyeslash_outlined_16"},
		  @{@"identifier" : @"DYYYHideQuqishuiting",
		    @"title" : @"隱藏去汽水聽",
		    @"detail" : @"",
		    @"cellType" : @6,
		    @"imageName" : @"ic_eyeslash_outlined_16"},
		  @{@"identifier" : @"DYYYHideGongChuang",
		    @"title" : @"隱藏共創頭像",
		    @"detail" : @"",
		    @"cellType" : @6,
		    @"imageName" : @"ic_eyeslash_outlined_16"},
		  @{@"identifier" : @"DYYYHideHotspot",
		    @"title" : @"隱藏熱點提示",
		    @"detail" : @"",
		    @"cellType" : @6,
		    @"imageName" : @"ic_eyeslash_outlined_16"},
		  @{@"identifier" : @"DYYYHideRecommendTips",
		    @"title" : @"隱藏推薦提示",
		    @"detail" : @"",
		    @"cellType" : @6,
		    @"imageName" : @"ic_eyeslash_outlined_16"},
		  @{@"identifier" : @"DYYYHideBottomRelated",
		    @"title" : @"隱藏底部相關",
		    @"detail" : @"",
		    @"cellType" : @6,
		    @"imageName" : @"ic_eyeslash_outlined_16"},
		  @{@"identifier" : @"DYYYHideShareContentView",
		    @"title" : @"隱藏分享提示",
		    @"detail" : @"",
		    @"cellType" : @6,
		    @"imageName" : @"ic_eyeslash_outlined_16"},
		  @{@"identifier" : @"DYYYHideAntiAddictedNotice",
		    @"title" : @"隱藏作者聲明",
		    @"detail" : @"",
		    @"cellType" : @6,
		    @"imageName" : @"ic_eyeslash_outlined_16"},
		  @{@"identifier" : @"DYYYHideFeedAnchorContainer",
		    @"title" : @"隱藏拍攝同款",
		    @"detail" : @"",
		    @"cellType" : @6,
		    @"imageName" : @"ic_eyeslash_outlined_16"},
		  @{@"identifier" : @"DYYYHideChallengeStickers",
		    @"title" : @"隱藏挑戰貼紙",
		    @"detail" : @"",
		    @"cellType" : @6,
		    @"imageName" : @"ic_eyeslash_outlined_16"},
		  @{@"identifier" : @"DYYYHideTemplateTags",
		    @"title" : @"隱藏校園提示",
		    @"detail" : @"",
		    @"cellType" : @6,
		    @"imageName" : @"ic_eyeslash_outlined_16"},
		  @{@"identifier" : @"DYYYHideHisShop",
		    @"title" : @"隱藏作者商店",
		    @"detail" : @"",
		    @"cellType" : @6,
		    @"imageName" : @"ic_eyeslash_outlined_16"},
		  @{@"identifier" : @"DYYYHideConcernCapsuleView",
		    @"title" : @"隱藏關注直播",
		    @"detail" : @"",
		    @"cellType" : @6,
		    @"imageName" : @"ic_eyeslash_outlined_16"},
		  @{@"identifier" : @"DYYYHidentopbarprompt",
		    @"title" : @"隱藏頂欄橫線",
		    @"detail" : @"",
		    @"cellType" : @6,
		    @"imageName" : @"ic_eyeslash_outlined_16"},
		  @{@"identifier" : @"DYYYHideTemplateVideo",
		    @"title" : @"隱藏影片合集",
		    @"detail" : @"",
		    @"cellType" : @6,
		    @"imageName" : @"ic_eyeslash_outlined_16"},
		  @{@"identifier" : @"DYYYHideTemplatePlaylet",
		    @"title" : @"隱藏短劇合集",
		    @"detail" : @"",
		    @"cellType" : @6,
		    @"imageName" : @"ic_eyeslash_outlined_16"},
		  @{@"identifier" : @"DYYYHideLiveGIF",
		    @"title" : @"隱藏動圖標籤",
		    @"detail" : @"",
		    @"cellType" : @6,
		    @"imageName" : @"ic_eyeslash_outlined_16"},
		  @{@"identifier" : @"DYYYHideItemTag",
		    @"title" : @"隱藏筆記標籤",
		    @"detail" : @"",
		    @"cellType" : @6,
		    @"imageName" : @"ic_eyeslash_outlined_16"},
		  @{@"identifier" : @"DYYYHideTemplateGroup",
		    @"title" : @"隱藏底部話題",
		    @"detail" : @"",
		    @"cellType" : @6,
		    @"imageName" : @"ic_eyeslash_outlined_16"},
		  @{@"identifier" : @"DYYYHideCameraLocation",
		    @"title" : @"隱藏相機定位",
		    @"detail" : @"",
		    @"cellType" : @6,
		    @"imageName" : @"ic_eyeslash_outlined_16"},
		  @{@"identifier" : @"DYYYHideCommentTips",
		    @"title" : @"隱藏評論提示",
		    @"detail" : @"",
		    @"cellType" : @6,
		    @"imageName" : @"ic_eyeslash_outlined_16"},			
		  @{@"identifier" : @"DYYYHideCommentViews",
		    @"title" : @"隱藏評論視圖",
		    @"detail" : @"",
		    @"cellType" : @6,
		    @"imageName" : @"ic_eyeslash_outlined_16"},
		  @{
			  @"identifier" : @"DYYYHideLiveCapsuleView",
			  @"title" : @"隱藏直播紅點",
			  @"subTitle" : @"隱藏頂欄的直播中提示",
			  @"detail" : @"",
			  @"cellType" : @37,
			  @"imageName" : @"ic_eyeslash_outlined_16"
		  },
		  @{@"identifier" : @"DYYYHideStoryProgressSlide",
		    @"title" : @"隱藏影片滑條",
		    @"detail" : @"",
		    @"cellType" : @6,
		    @"imageName" : @"ic_eyeslash_outlined_16"},
		  @{@"identifier" : @"DYYYHideDotsIndicator",
		    @"title" : @"隱藏圖片滑條",
		    @"detail" : @"",
		    @"cellType" : @6,
		    @"imageName" : @"ic_eyeslash_outlined_16"},
		  @{@"identifier" : @"DYYYHidePopover",
		    @"title" : @"隱藏上次看到",
		    @"detail" : @"",
		    @"cellType" : @6,
		    @"imageName" : @"ic_eyeslash_outlined_16"},			
		  @{@"identifier" : @"DYYYHideChapterProgress",
		    @"title" : @"隱藏章節進度",
		    @"detail" : @"",
		    @"cellType" : @6,
		    @"imageName" : @"ic_eyeslash_outlined_16"},
		  @{@"identifier" : @"DYYYHidePrivateMessages",
		    @"title" : @"隱藏分享私信",
		    @"detail" : @"",
		    @"cellType" : @6,
		    @"imageName" : @"ic_eyeslash_outlined_16"},
		  @{@"identifier" : @"DYYYHideRightLable",
		    @"title" : @"隱藏暱稱右側",
		    @"detail" : @"",
		    @"cellType" : @6,
		    @"imageName" : @"ic_eyeslash_outlined_16"},
		  @{
			  @"identifier" : @"DYYYHidePendantGroup",
			  @"title" : @"隱藏紅包懸浮",
			  @"subTitle" : @"隱藏抖音極速版的紅包懸浮按鈕，可能失效，不修復。",
			  @"detail" : @"",
			  @"cellType" : @37,
			  @"imageName" : @"ic_eyeslash_outlined_16"
		  },
		  @{
			  @"identifier" : @"DYYYHideScancode",
			  @"title" : @"隱藏輸入掃碼",
			  @"subTitle" : @"隱藏點擊搜尋後輸入框右部的掃碼按鈕",
			  @"detail" : @"",
			  @"cellType" : @37,
			  @"imageName" : @"ic_eyeslash_outlined_16"
		  },
		  @{@"identifier" : @"DYYYHideReply",
		    @"title" : @"隱藏私信回復",
		    @"detail" : @"",
		    @"cellType" : @6,
		    @"imageName" : @"ic_eyeslash_outlined_16"},
		  @{@"identifier" : @"DYYYHidePauseVideoRelatedWord",
		    @"title" : @"隱藏暫停相關",
		    @"detail" : @"",
		    @"cellType" : @6,
		    @"imageName" : @"ic_eyeslash_outlined_16"},
		  @{
			  @"identifier" : @"DYYYHidekeyboardai",
			  @"title" : @"隱藏鍵盤 AI",
			  @"subTitle" : @"隱藏搜尋下方的 AI 和語音搜尋按鈕",
			  @"detail" : @"",
			  @"cellType" : @37,
			  @"imageName" : @"ic_eyeslash_outlined_16"
		  }
	  ];

	  for (NSDictionary *dict in infoSettings) {
		  AWESettingItemModel *item = [DYYYSettingsHelper createSettingItem:dict];
		  [infoItems addObject:item];
	  }

	  // 【直播界面净化】分类
	  NSMutableArray<AWESettingItemModel *> *livestreamItems = [NSMutableArray array];
	  NSArray *livestreamSettings = @[
		  @{@"identifier" : @"DYYYHideLivePlayground",
		    @"title" : @"隱藏直播廣場",
		    @"detail" : @"",
		    @"cellType" : @6,
		    @"imageName" : @"ic_eyeslash_outlined_16"},
		  @{@"identifier" : @"DYYYHideEnterLive",
		    @"title" : @"隱藏進入直播",
		    @"detail" : @"",
		    @"cellType" : @6,
		    @"imageName" : @"ic_eyeslash_outlined_16"},
		  @{@"identifier" : @"DYYYHideLiveRoomClose",
		    @"title" : @"隱藏關閉按鈕",
		    @"detail" : @"",
		    @"cellType" : @6,
		    @"imageName" : @"ic_eyeslash_outlined_16"},
		  @{@"identifier" : @"DYYYHideLiveRoomFullscreen",
		    @"title" : @"隱藏橫向按鈕",
		    @"detail" : @"",
		    @"cellType" : @6,
		    @"imageName" : @"ic_eyeslash_outlined_16"},
		  @{@"identifier" : @"DYYYHideGiftPavilion",
		    @"title" : @"隱藏禮物展館",
		    @"detail" : @"",
		    @"cellType" : @6,
		    @"imageName" : @"ic_eyeslash_outlined_16"},
		  @{@"identifier" : @"DYYYHideLiveRoomMirroring",
		    @"title" : @"隱藏投影按鈕",
		    @"detail" : @"",
		    @"cellType" : @6,
		    @"imageName" : @"ic_eyeslash_outlined_16"},
		  @{@"identifier" : @"DYYYHideLiveDiscovery",
		    @"title" : @"隱藏直播發現",
		    @"detail" : @"",
		    @"cellType" : @6,
		    @"imageName" : @"ic_eyeslash_outlined_16"},
		  @{@"identifier" : @"DYYYHideKTVSongIndicator",
		    @"title" : @"隱藏直播點歌",
		    @"detail" : @"",
		    @"cellType" : @6,
		    @"imageName" : @"ic_eyeslash_outlined_16"},
		  @{
			  @"identifier" : @"DYYYHideLiveDetail",
			  @"title" : @"隱藏直播熱榜",
			  @"subTitle" : @"隱藏使用者下方的小時榜、人氣榜、熱度等資訊",
			  @"detail" : @"",
			  @"cellType" : @37,
			  @"imageName" : @"ic_eyeslash_outlined_16"
		  },
		  @{
			  @"identifier" : @"DYYYHideTouchView",
			  @"title" : @"隱藏紅包懸浮",
			  @"subTitle" : @"隱藏使用者下方的紅包、積分等懸浮按鈕",
			  @"detail" : @"",
			  @"cellType" : @37,
			  @"imageName" : @"ic_eyeslash_outlined_16"
		  },
		  @{@"identifier" : @"DYYYHideLiveGoodsMsg",
		    @"title" : @"隱藏商品資訊",
		    @"detail" : @"",
		    @"cellType" : @6,
		    @"imageName" : @"ic_eyeslash_outlined_16"},
		  @{@"identifier" : @"DYYYHideLiveLikeAnimation",
		    @"title" : @"隱藏按讚動畫",
		    @"detail" : @"",
		    @"cellType" : @6,
		    @"imageName" : @"ic_eyeslash_outlined_16"},
		  @{@"identifier" : @"DYYYHideCellularAlert",
		    @"title" : @"隱藏流量提醒",
		    @"detail" : @"",
		    @"cellType" : @6,
		    @"imageName" : @"ic_eyeslash_outlined_16"},
		  @{@"identifier" : @"DYYYHideLivePopup",
		    @"title" : @"隱藏進場特效",
		    @"detail" : @"",
		    @"cellType" : @6,
		    @"imageName" : @"ic_eyeslash_outlined_16"},
		  @{@"identifier" : @"DYYYHideStickerView",
		    @"title" : @"隱藏文字貼紙",
		    @"detail" : @"",
		    @"cellType" : @6,
		    @"imageName" : @"ic_eyeslash_outlined_16"},
		  @{@"identifier" : @"DYYYHideLiveRoomClear",
		    @"title" : @"隱藏退出清除螢幕",
		    @"detail" : @"",
		    @"cellType" : @6,
		    @"imageName" : @"ic_eyeslash_outlined_16"}

	  ];
	  for (NSDictionary *dict in livestreamSettings) {
		  AWESettingItemModel *item = [DYYYSettingsHelper createSettingItem:dict];
		  [livestreamItems addObject:item];
	  }

	  // 【长按面板】分类
	  NSMutableArray<AWESettingItemModel *> *modernpanels = [NSMutableArray array];
	  NSArray *modernpanelSettings = @[
		  @{@"identifier" : @"DYYYHidePanelDaily",
		    @"title" : @"隱藏面板日常",
		    @"detail" : @"",
		    @"cellType" : @6,
		    @"imageName" : @"ic_eyeslash_outlined_16"},
		  @{@"identifier" : @"DYYYHidePanelRecommend",
		    @"title" : @"隱藏面板推薦",
		    @"detail" : @"",
		    @"cellType" : @6,
		    @"imageName" : @"ic_eyeslash_outlined_16"},
		  @{@"identifier" : @"DYYYHidePanelReport",
		    @"title" : @"隱藏面板舉報",
		    @"detail" : @"",
		    @"cellType" : @6,
		    @"imageName" : @"ic_eyeslash_outlined_16"},
		  @{@"identifier" : @"DYYYHidePanelSpeed",
		    @"title" : @"隱藏面板倍速",
		    @"detail" : @"",
		    @"cellType" : @6,
		    @"imageName" : @"ic_eyeslash_outlined_16"},
		  @{@"identifier" : @"DYYYHidePanelClearScreen",
		    @"title" : @"隱藏面板清屏",
		    @"detail" : @"",
		    @"cellType" : @6,
		    @"imageName" : @"ic_eyeslash_outlined_16"},
		  @{@"identifier" : @"DYYYHidePanelFavorite",
		    @"title" : @"隱藏面板緩存",
		    @"detail" : @"",
		    @"cellType" : @6,
		    @"imageName" : @"ic_eyeslash_outlined_16"},
		  @{@"identifier" : @"DYYYHidePanelCast",
		    @"title" : @"隱藏面板投屏",
		    @"detail" : @"",
		    @"cellType" : @6,
		    @"imageName" : @"ic_eyeslash_outlined_16"},
		  @{@"identifier" : @"DYYYHidePanelSubtitle",
		    @"title" : @"隱藏面板彈幕",
		    @"detail" : @"",
		    @"cellType" : @6,
		    @"imageName" : @"ic_eyeslash_outlined_16"},
		  @{@"identifier" : @"DYYYHidePanelSearchImage",
		    @"title" : @"隱藏面板識圖",
		    @"detail" : @"",
		    @"cellType" : @6,
		    @"imageName" : @"ic_eyeslash_outlined_16"},
		  @{@"identifier" : @"DYYYHidePanelListenDouyin",
		    @"title" : @"隱藏面板聽抖音",
		    @"detail" : @"",
		    @"cellType" : @6,
		    @"imageName" : @"ic_eyeslash_outlined_16"},
		  @{@"identifier" : @"DYYYHidePanelOpenInPC",
		    @"title" : @"隱藏電腦Pad打開",
		    @"detail" : @"",
		    @"cellType" : @6,
		    @"imageName" : @"ic_eyeslash_outlined_16"},
		  @{@"identifier" : @"DYYYHidePanelLater",
		    @"title" : @"隱藏面板稍後再看",
		    @"detail" : @"",
		    @"cellType" : @6,
		    @"imageName" : @"ic_eyeslash_outlined_16"},
		  @{@"identifier" : @"DYYYHidePanelAutoPlay",
		    @"title" : @"隱藏面板自動連播",
		    @"detail" : @"",
		    @"cellType" : @6,
		    @"imageName" : @"ic_eyeslash_outlined_16"},
		  @{@"identifier" : @"DYYYHidePanelNotInterested",
		    @"title" : @"隱藏面板不感興趣",
		    @"detail" : @"",
		    @"cellType" : @6,
		    @"imageName" : @"ic_eyeslash_outlined_16"},
		  @{@"identifier" : @"DYYYHidePanelBackgroundPlay",
		    @"title" : @"隱藏面板後台播放",
		    @"detail" : @"",
		    @"cellType" : @6,
		    @"imageName" : @"ic_eyeslash_outlined_16"},
		  @{@"identifier" : @"DYYYHidePanelTimerClose",
		    @"title" : @"隱藏面板定時關閉",
		    @"detail" : @"",
		    @"cellType" : @6,
		    @"imageName" : @"ic_eyeslash_outlined_16"},
		  @{@"identifier" : @"DYYYHidePanelBiserial",
		    @"title" : @"隱藏雙列快捷入口",
		    @"detail" : @"",
		    @"cellType" : @6,
		    @"imageName" : @"ic_eyeslash_outlined_16"}
	  ];

	  for (NSDictionary *dict in modernpanelSettings) {
		  AWESettingItemModel *item = [DYYYSettingsHelper createSettingItem:dict];
		  [modernpanels addObject:item];
	  }

	  // 【长按评论分类】
	  NSMutableArray<AWESettingItemModel *> *commentpanel = [NSMutableArray array];
	  NSArray *commentpanelSettings = @[
		  @{@"identifier" : @"DYYYHideCommentShareToFriends",
		    @"title" : @"隱藏評論分享",
		    @"detail" : @"",
		    @"cellType" : @6,
		    @"imageName" : @"ic_eyeslash_outlined_16"},
		  @{@"identifier" : @"DYYYHideCommentLongPressCopy",
		    @"title" : @"隱藏評論複製",
		    @"detail" : @"",
		    @"cellType" : @6,
		    @"imageName" : @"ic_eyeslash_outlined_16"},
		  @{@"identifier" : @"DYYYHideCommentLongPressSaveImage",
		    @"title" : @"隱藏評論儲存",
		    @"detail" : @"",
		    @"cellType" : @6,
		    @"imageName" : @"ic_eyeslash_outlined_16"},
		  @{@"identifier" : @"DYYYHideCommentLongPressReport",
		    @"title" : @"隱藏評論舉報",
		    @"detail" : @"",
		    @"cellType" : @6,
		    @"imageName" : @"ic_eyeslash_outlined_16"},
		  @{@"identifier" : @"DYYYHideCommentLongPressSearch",
		    @"title" : @"隱藏評論搜尋",
		    @"detail" : @"",
		    @"cellType" : @6,
		    @"imageName" : @"ic_eyeslash_outlined_16"},
		  @{@"identifier" : @"DYYYHideCommentLongPressDaily",
		    @"title" : @"隱藏評論轉發日常",
		    @"detail" : @"",
		    @"cellType" : @6,
		    @"imageName" : @"ic_eyeslash_outlined_16"},
		  @{@"identifier" : @"DYYYHideCommentLongPressVideoReply",
		    @"title" : @"隱藏評論影片回復",
		    @"detail" : @"",
		    @"cellType" : @6,
		    @"imageName" : @"ic_eyeslash_outlined_16"},
		  @{@"identifier" : @"DYYYHideCommentLongPressPictureSearch",
		    @"title" : @"隱藏評論識別圖片",
		    @"detail" : @"",
		    @"cellType" : @6,
		    @"imageName" : @"ic_eyeslash_outlined_16"}
	  ];
	  for (NSDictionary *dict in commentpanelSettings) {
		  AWESettingItemModel *item = [DYYYSettingsHelper createSettingItem:dict];
		  [commentpanel addObject:item];
	  }
	  // 创建并组织所有section
	  NSMutableArray *sections = [NSMutableArray array];
	  [sections addObject:[DYYYSettingsHelper createSectionWithTitle:@"主介面元素" items:mainUiItems]];
	  [sections addObject:[DYYYSettingsHelper createSectionWithTitle:@"影片播放介面" items:videoUiItems]];
	  [sections addObject:[DYYYSettingsHelper createSectionWithTitle:@"側邊欄元素" items:sidebarItems]];
	  [sections addObject:[DYYYSettingsHelper createSectionWithTitle:@"訊息頁與我的頁" items:messageAndMineItems]];
	  [sections addObject:[DYYYSettingsHelper createSectionWithTitle:@"提示與位置資訊" items:infoItems]];
	  [sections addObject:[DYYYSettingsHelper createSectionWithTitle:@"直播間介面" items:livestreamItems]];
	  [sections addObject:[DYYYSettingsHelper createSectionWithTitle:@"隱藏面板功能" footerTitle:@"隱藏影片長按面板中的功能" items:modernpanels]];
	  [sections addObject:[DYYYSettingsHelper createSectionWithTitle:@"隱藏長按評論功能" footerTitle:@"隱藏評論長按面板中的功能" items:commentpanel]];	  
	  // 创建并推入二级设置页面
	  AWESettingBaseViewController *subVC = [DYYYSettingsHelper createSubSettingsViewController:@"隱藏設定" sections:sections];
	  [rootVC.navigationController pushViewController:(UIViewController *)subVC animated:YES];
	};
	[mainItems addObject:hideSettingItem];

	// 创建顶栏移除分类项
	AWESettingItemModel *removeSettingItem = [[%c(AWESettingItemModel) alloc] init];
	removeSettingItem.identifier = @"DYYYRemoveSettings";
	removeSettingItem.title = @"頂欄移除";
	removeSettingItem.type = 0;
	removeSettingItem.svgIconImageName = @"ic_doublearrowup_outlined_20";
	removeSettingItem.cellType = 26;
	removeSettingItem.colorStyle = 0;
	removeSettingItem.isEnable = YES;
	removeSettingItem.cellTappedBlock = ^{
	  // 创建顶栏移除二级界面的设置项
	  NSMutableArray<AWESettingItemModel *> *removeSettingsItems = [NSMutableArray array];
	  NSArray *removeSettings = @[
		  @{@"identifier" : @"DYYYHideHotContainer",
		    @"title" : @"移除推薦",
		    @"detail" : @"",
		    @"cellType" : @6,
		    @"imageName" : @"ic_xmark_outlined_20"},
		  @{@"identifier" : @"DYYYHideFollow",
		    @"title" : @"移除關注",
		    @"detail" : @"",
		    @"cellType" : @6,
		    @"imageName" : @"ic_xmark_outlined_20"},
		  @{@"identifier" : @"DYYYHideMediumVideo",
		    @"title" : @"移除精選",
		    @"detail" : @"",
		    @"cellType" : @6,
		    @"imageName" : @"ic_xmark_outlined_20"},
		  @{@"identifier" : @"DYYYHideMall",
		    @"title" : @"移除商城",
		    @"detail" : @"",
		    @"cellType" : @6,
		    @"imageName" : @"ic_xmark_outlined_20"},
		  @{@"identifier" : @"DYYYHideNearby",
		    @"title" : @"移除同城",
		    @"detail" : @"",
		    @"cellType" : @6,
		    @"imageName" : @"ic_xmark_outlined_20"},
		  @{@"identifier" : @"DYYYHideGroupon",
		    @"title" : @"移除團購",
		    @"detail" : @"",
		    @"cellType" : @6,
		    @"imageName" : @"ic_xmark_outlined_20"},
		  @{@"identifier" : @"DYYYHideTabLive",
		    @"title" : @"移除直播",
		    @"detail" : @"",
		    @"cellType" : @6,
		    @"imageName" : @"ic_xmark_outlined_20"},
		  @{@"identifier" : @"DYYYHidePadHot",
		    @"title" : @"移除熱點",
		    @"detail" : @"",
		    @"cellType" : @6,
		    @"imageName" : @"ic_xmark_outlined_20"},
		  @{@"identifier" : @"DYYYHideHangout",
		    @"title" : @"移除經驗",
		    @"detail" : @"",
		    @"cellType" : @6,
		    @"imageName" : @"ic_xmark_outlined_20"},
		  @{@"identifier" : @"DYYYHidePlaylet",
		    @"title" : @"移除短劇",
		    @"detail" : @"",
		    @"cellType" : @6,
		    @"imageName" : @"ic_xmark_outlined_20"},
		  @{@"identifier" : @"DYYYHideCinema",
		    @"title" : @"移除看劇",
		    @"detail" : @"",
		    @"cellType" : @6,
		    @"imageName" : @"ic_xmark_outlined_20"},
		  @{@"identifier" : @"DYYYHideKidsV2",
		    @"title" : @"移除少兒",
		    @"detail" : @"",
		    @"cellType" : @6,
		    @"imageName" : @"ic_xmark_outlined_20"},
		  @{@"identifier" : @"DYYYHideGame",
		    @"title" : @"移除遊戲",
		    @"detail" : @"",
		    @"cellType" : @6,
		    @"imageName" : @"ic_xmark_outlined_20"},
		  @{@"identifier" : @"DYYYHideOtherChannel",
		    @"title" : @"移除頂欄其他",
		    @"detail" : @"",
		    @"cellType" : @26,
		    @"imageName" : @"ic_xmark_outlined_20"}
	  ];

	  for (NSDictionary *dict in removeSettings) {
		  AWESettingItemModel *item = [[%c(AWESettingItemModel) alloc] init];
		  item.identifier = dict[@"identifier"];
		  item.title = dict[@"title"];
		  NSString *savedDetail = [[NSUserDefaults standardUserDefaults] objectForKey:item.identifier];
		  item.detail = savedDetail ?: dict[@"detail"];
		  item.type = 1000;
		  item.svgIconImageName = dict[@"imageName"];
		  item.cellType = [dict[@"cellType"] integerValue];
		  item.colorStyle = 0;
		  item.isEnable = YES;
		  item.isSwitchOn = [DYYYSettingsHelper getUserDefaults:item.identifier];
		  __weak AWESettingItemModel *weakItem = item;
		  item.switchChangedBlock = ^{
		    __strong AWESettingItemModel *strongItem = weakItem;
		    if (strongItem) {
			    BOOL isSwitchOn = !strongItem.isSwitchOn;
			    strongItem.isSwitchOn = isSwitchOn;
			    [DYYYSettingsHelper setUserDefaults:@(isSwitchOn) forKey:strongItem.identifier];
		    }
		  };
		  [removeSettingsItems addObject:item];

		  if ([item.identifier isEqualToString:@"DYYYHideOtherChannel"]) {
			  NSString *savedValue = [[NSUserDefaults standardUserDefaults] objectForKey:@"DYYYHideOtherChannel"];
			  item.detail = savedValue ?: @"";
			  item.cellTappedBlock = ^{
			    // 将保存的逗号分隔字符串转换为数组
			    NSString *savedKeywords = [[NSUserDefaults standardUserDefaults] objectForKey:@"DYYYHideOtherChannel"] ?: @"";
			    NSArray *keywordArray = [savedKeywords length] > 0 ? [savedKeywords componentsSeparatedByString:@","] : @[];

			    // 创建并显示关键词列表视图
			    DYYYKeywordListView *keywordListView = [[DYYYKeywordListView alloc] initWithTitle:@"設定過濾其他頂欄" keywords:keywordArray];

			    // 设置确认回调
			    keywordListView.onConfirm = ^(NSArray *keywords) {
			      // 将关键词数组转换为逗号分隔的字符串
			      NSString *keywordString = [keywords componentsJoinedByString:@","];
			      [DYYYSettingsHelper setUserDefaults:keywordString forKey:@"DYYYHideOtherChannel"];
			      item.detail = keywordString;
			      [item refreshCell];
			    };

			    // 显示关键词列表视图
			    [keywordListView show];
			  };
		  }
	  }

	  NSMutableArray *sections = [NSMutableArray array];
	  [sections addObject:[DYYYSettingsHelper createSectionWithTitle:@"頂欄選項" items:removeSettingsItems]];

	  // 创建并推入二级设置页面，使用sections数组而不是直接使用removeSettingsItems
	  AWESettingBaseViewController *subVC = [DYYYSettingsHelper createSubSettingsViewController:@"頂欄移除" sections:sections];	  
	  [rootVC.navigationController pushViewController:(UIViewController *)subVC animated:YES];
	};
	[mainItems addObject:removeSettingItem];

	// 创建增强设置分类项
	AWESettingItemModel *enhanceSettingItem = [[%c(AWESettingItemModel) alloc] init];
	enhanceSettingItem.identifier = @"DYYYEnhanceSettings";
	enhanceSettingItem.title = @"增強設定";
	enhanceSettingItem.type = 0;
	enhanceSettingItem.svgIconImageName = @"ic_squaresplit_outlined_20";
	enhanceSettingItem.cellType = 26;
	enhanceSettingItem.colorStyle = 0;
	enhanceSettingItem.isEnable = YES;
	enhanceSettingItem.cellTappedBlock = ^{
	  // 创建增强设置二级界面的设置项
	  NSMutableDictionary *cellTapHandlers = [NSMutableDictionary dictionary];

	  // 【长按面板设置】分类
	  NSMutableArray<AWESettingItemModel *> *longPressItems = [NSMutableArray array];
	  NSArray *longPressSettings = @[
		  @{@"identifier" : @"DYYYLongPressSaveVideo",
		    @"title" : @"長按儲存目前影片",
		    @"detail" : @"",
		    @"cellType" : @6,
		    @"imageName" : @"ic_boxarrowdown_outlined"},
		  @{@"identifier" : @"DYYYLongPressSaveCover",
		    @"title" : @"長按儲存影片封面",
		    @"detail" : @"",
		    @"cellType" : @6,
		    @"imageName" : @"ic_boxarrowdown_outlined"},
		  @{@"identifier" : @"DYYYLongPressSaveAudio",
		    @"title" : @"長按儲存影片音樂",
		    @"detail" : @"",
		    @"cellType" : @6,
		    @"imageName" : @"ic_boxarrowdown_outlined"},
		  @{@"identifier" : @"DYYYLongPressSaveCurrentImage",
		    @"title" : @"長按儲存目前圖片",
		    @"detail" : @"",
		    @"cellType" : @6,
		    @"imageName" : @"ic_boxarrowdown_outlined"},
		  @{@"identifier" : @"DYYYLongPressSaveAllImages",
		    @"title" : @"長按儲存所有圖片",
		    @"detail" : @"",
		    @"cellType" : @6,
		    @"imageName" : @"ic_boxarrowdown_outlined"},
		  @{@"identifier" : @"DYYYLongPressCreateVideo",
		    @"title" : @"長按面板製作影片",
		    @"detail" : @"",
		    @"cellType" : @6,
		    @"imageName" : @"ic_videosearch_outlined_20"},			
		  @{@"identifier" : @"DYYYLongPressCopyText",
		    @"title" : @"長按複製影片文案",
		    @"detail" : @"",
		    @"cellType" : @6,
		    @"imageName" : @"ic_rectangleonrectangleup_outlined_20"},
		  @{@"identifier" : @"DYYYLongPressCopyLink",
		    @"title" : @"長按複製分享連結",
		    @"detail" : @"",
		    @"cellType" : @6,
		    @"imageName" : @"ic_rectangleonrectangleup_outlined_20"},
		  @{@"identifier" : @"DYYYLongPressApiDownload",
		    @"title" : @"長按接口解析下載",
		    @"detail" : @"",
		    @"cellType" : @6,
		    @"imageName" : @"ic_cloudarrowdown_outlined_20"},
		  @{@"identifier" : @"DYYYLongPressTimerClose",
		    @"title" : @"長按定時關閉抖音",
		    @"detail" : @"",
		    @"cellType" : @6,
		    @"imageName" : @"ic_c_alarm_outlined"},
		  @{@"identifier" : @"DYYYLongPressFilterTitle",
		    @"title" : @"長按面板過濾文案",
		    @"detail" : @"",
		    @"cellType" : @6,
		    @"imageName" : @"ic_funnel_outlined_20"},
		  @{@"identifier" : @"DYYYLongPressFilterUser",
		    @"title" : @"長按面板過濾使用者",
		    @"detail" : @"",
		    @"cellType" : @6,
		    @"imageName" : @"ic_userban_outlined_20"},
	  ];

	  for (NSDictionary *dict in longPressSettings) {
		  AWESettingItemModel *item = [DYYYSettingsHelper createSettingItem:dict];
		  [longPressItems addObject:item];
	  }

	  // 【媒体保存】分类
	  NSMutableArray<AWESettingItemModel *> *downloadItems = [NSMutableArray array];
	  NSArray *downloadSettings = @[
		  @{@"identifier" : @"DYYYInterfaceDownload",
		    @"title" : @"接口解析儲存媒體",
		    @"detail" : @"不填關閉",
		    @"cellType" : @26,
		    @"imageName" : @"ic_cloudarrowdown_outlined_20"},
		  @{@"identifier" : @"DYYYShowAllVideoQuality",
		    @"title" : @"接口顯示解析度選項",
		    @"detail" : @"",
		    @"cellType" : @6,
		    @"imageName" : @"ic_hamburgernut_outlined_20"},
		  @{@"identifier" : @"DYYYisEnableSheetBlur",
		    @"title" : @"儲存面板玻璃效果",
		    @"detail" : @"",
		    @"cellType" : @6,
		    @"imageName" : @"ic_list_outlined"},
		  @{@"identifier" : @"DYYYSheetBlurTransparent",
		    @"title" : @"面板毛玻璃透明度",
		    @"detail" : @"0-1小數",
		    @"cellType" : @26,
		    @"imageName" : @"ic_eye_outlined_20"},
		  @{@"identifier" : @"DYYYCommentLivePhotoNotWaterMark",
		    @"title" : @"移除評論實況水印",
		    @"detail" : @"",
		    @"cellType" : @6,
		    @"imageName" : @"ic_livephoto_outlined_20"},
		  @{@"identifier" : @"DYYYCommentNotWaterMark",
		    @"title" : @"移除評論圖片水印",
		    @"detail" : @"",
		    @"cellType" : @6,
		    @"imageName" : @"ic_removeimage_outlined_20"},
		  @{
			  @"identifier" : @"DYYYForceDownloadEmotion",
			  @"title" : @"儲存評論區表情包",
			  @"subTitle" : @"iOS 17+的使用者請長按表情本身儲存",
			  @"detail" : @"",
			  @"cellType" : @37,
			  @"imageName" : @"ic_emoji_outlined"
		  },
		  @{@"identifier" : @"DYYYForceDownloadPreviewEmotion",
		    @"title" : @"儲存預覽頁表情包",
		    @"detail" : @"",
		    @"cellType" : @6,
		    @"imageName" : @"ic_emoji_outlined"},
		  @{@"identifier" : @"DYYYForceDownloadIMEmotion",
		    @"title" : @"儲存聊天頁表情包",
		    @"detail" : @"",
		    @"cellType" : @6,
		    @"imageName" : @"ic_emoji_outlined"},
		  @{@"identifier" : @"DYYYHapticFeedbackEnabled",
		    @"title" : @"下載完成震動反饋",
		    @"detail" : @"",
		    @"cellType" : @6,
		    @"imageName" : @"ic_gearsimplify_outlined_20"}
	  ];

	  for (NSDictionary *dict in downloadSettings) {
		  AWESettingItemModel *item = [DYYYSettingsHelper createSettingItem:dict cellTapHandlers:cellTapHandlers];

		  // 特殊处理接口解析保存媒体选项
		  if ([item.identifier isEqualToString:@"DYYYInterfaceDownload"]) {
			  // 获取已保存的接口URL
			  NSString *savedURL = [[NSUserDefaults standardUserDefaults] objectForKey:@"DYYYInterfaceDownload"];
			  item.detail = savedURL.length > 0 ? savedURL : @"不填關閉";

			  item.cellTappedBlock = ^{
			    NSString *defaultText = [item.detail isEqualToString:@"不填關閉"] ? @"" : item.detail;
			    [DYYYSettingsHelper showTextInputAlert:@"設定媒體解析接口"
						       defaultText:defaultText
						       placeholder:@"解析接口以url=結尾"
							 onConfirm:^(NSString *text) {
							   // 保存用户输入的接口URL
							   NSString *trimmedText = [text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
							   [DYYYSettingsHelper setUserDefaults:trimmedText forKey:@"DYYYInterfaceDownload"];

							   item.detail = trimmedText.length > 0 ? trimmedText : @"不填關閉";

							   [item refreshCell];
							 }
							  onCancel:nil];
			  };
		  }
		  [downloadItems addObject:item];
	  }

	  // 【热更新】分类
	  NSMutableArray<AWESettingItemModel *> *hotUpdateItems = [NSMutableArray array];
	  NSArray *hotUpdateSettings = @[
		  @{@"identifier" : @"DYYYABTestBlockEnabled",
		    @"title" : @"禁止下發設定",
		    @"detail" : @"",
		    @"cellType" : @6,
		    @"imageName" : @"ic_fire_outlined_20"},
		  @{@"identifier" : @"DYYYABTestModeString",
		    @"title" : @"設定應用方式",
		    @"detail" : @"",
		    @"cellType" : @26,
		    @"imageName" : @"ic_enterpriseservice_outlined"},
		  @{@"identifier" : @"SaveCurrentABTestData",
		    @"title" : @"匯出目前設定",
		    @"detail" : @"",
		    @"cellType" : @26,
		    @"imageName" : @"ic_memorycard_outlined_20"},
		  @{@"identifier" : @"SaveABTestConfigFile",
		    @"title" : @"匯出本機設定",
		    @"detail" : @"",
		    @"cellType" : @26,
		    @"imageName" : @"ic_memorycard_outlined_20"},
		  @{@"identifier" : @"LoadABTestConfigFile",
		    @"title" : @"導入本機設定",
		    @"detail" : @"",
		    @"cellType" : @26,
		    @"imageName" : @"ic_phonearrowup_outlined_20"},
		  @{@"identifier" : @"DeleteABTestConfigFile",
		    @"title" : @"刪除本機設定",
		    @"detail" : @"",
		    @"cellType" : @26,
		    @"imageName" : @"ic_trash_outlined_20"}
	  ];

	  // --- 声明一个__block变量来持有SaveABTestConfigFileitem ---
	  __block AWESettingItemModel *saveABTestConfigFileItemRef = nil;
	  // --- 定义一个用于刷新SaveABTestConfigFileitem的局部block ---
	  void (^refreshSaveABTestConfigFileItem)(void) = ^{
	    if (!saveABTestConfigFileItemRef)
		    return;

	    	    // 在后台队列执行文件状态检查和大小获取20
	    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
	      __weak AWESettingItemModel *weakSaveItem = saveABTestConfigFileItemRef;
	      __strong AWESettingItemModel *strongSaveItem = weakSaveItem;
	      if (!strongSaveItem) {
		      return;
	      }

	      NSFileManager *fileManager = [NSFileManager defaultManager];
	      NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
	      NSString *documentsDirectory = [paths firstObject];
	      NSString *dyyyFolderPath = [documentsDirectory stringByAppendingPathComponent:@"DYYY"];
	      NSString *jsonFilePath = [dyyyFolderPath stringByAppendingPathComponent:@"abtest_data_fixed.json"];

	      NSString *loadingStatus = [DYYYABTestHook isLocalConfigLoaded] ? @"已載入：" : @"未載入：";

	      NSString *detailText = nil;
	      BOOL isItemEnable = NO;

	      if (![fileManager fileExistsAtPath:jsonFilePath]) {
		      detailText = [NSString stringWithFormat:@"%@ (檔案不存在)", loadingStatus];
		      isItemEnable = NO;
	      } else {
		      unsigned long long jsonFileSize = 0;
		      NSError *attributesError = nil;
		      NSDictionary *attributes = [fileManager attributesOfItemAtPath:jsonFilePath error:&attributesError];
		      if (!attributesError && attributes) {
			      jsonFileSize = [attributes fileSize];
			      detailText = [NSString stringWithFormat:@"%@ %@", loadingStatus, [DYYYUtils formattedSize:jsonFileSize]];
			      isItemEnable = YES;
		      } else {
			      detailText = [NSString stringWithFormat:@"%@ (讀取失敗: %@)", loadingStatus, attributesError.localizedDescription ?: @"未知错误"];
			      isItemEnable = NO;
		      }
	      }

	      // 回到主线程更新 UI
	      dispatch_async(dispatch_get_main_queue(), ^{
		// 在主线程更新 UI 前检查 item 是否仍然存在
		__strong AWESettingItemModel *strongSaveItemAgain = weakSaveItem;
		if (strongSaveItemAgain) {
			strongSaveItemAgain.detail = detailText;
			strongSaveItemAgain.isEnable = isItemEnable;
			[strongSaveItemAgain refreshCell];
		}
	      });
	    });
	  };

	  for (NSDictionary *dict in hotUpdateSettings) {
		  AWESettingItemModel *item = [DYYYSettingsHelper createSettingItem:dict];

		  if ([item.identifier isEqualToString:@"DYYYABTestBlockEnabled"]) {
			  item.switchChangedBlock = ^{
			    BOOL newValue = !item.isSwitchOn;

			    if (newValue) {
				    [DYYYBottomAlertView showAlertWithTitle:@"禁止熱更新下發配置"
					message:@"這將暫停接收測試新功能的推播。確定要繼續嗎？"
					avatarURL:nil
					cancelButtonText:@"取消"
					confirmButtonText:@"確定"
					cancelAction:^{
					  item.isSwitchOn = !newValue;
					  [item refreshCell];
					}
					closeAction:nil
					confirmAction:^{
					  item.isSwitchOn = newValue;
					  [DYYYSettingsHelper setUserDefaults:@(newValue) forKey:@"DYYYABTestBlockEnabled"];

					  [DYYYABTestHook setABTestBlockEnabled:newValue];
					}];
			    } else {
				    item.isSwitchOn = newValue;
				    [DYYYSettingsHelper setUserDefaults:@(newValue) forKey:@"DYYYABTestBlockEnabled"];
				    [DYYYUtils showToast:@"已允許熱更新下發配置，重啟後生效。"];
			    }
			  };
		  } else if ([item.identifier isEqualToString:@"DYYYABTestModeString"]) {
			  // 使用 DYYYABTestHook 的类方法获取当前的模式
			  BOOL isPatchMode = [DYYYABTestHook isPatchMode];
			  item.detail = isPatchMode ? @"覆寫模式" : @"替換模式";

			  item.cellTappedBlock = ^{
			    NSString *currentMode = [[NSUserDefaults standardUserDefaults] objectForKey:@"DYYYABTestModeString"] ?: @"替換模式：清除原設定，寫入新數據";

			    NSArray *modeOptions = @[ @"覆寫模式：保留原設定，覆蓋同名項", @"替換模式：清除原設定，寫入新數據" ];

			    [DYYYOptionsSelectionView showWithPreferenceKey:@"DYYYABTestModeString"
							       optionsArray:modeOptions
								 headerText:@"選擇本機設定的應用方式"
							     onPresentingVC:topView()
							   selectionChanged:^(NSString *selectedValue) {
							     BOOL isPatchMode = [DYYYABTestHook isPatchMode];
							     item.detail = isPatchMode ? @"覆寫模式" : @"替換模式";

							     if (![selectedValue isEqualToString:currentMode]) {
								     [DYYYABTestHook applyFixedABTestData];
							     }
							     [item refreshCell];
							   }];
			  };
		  } else if ([item.identifier isEqualToString:@"SaveCurrentABTestData"]) {
			  item.detail = @"(獲取中...)";
			  item.isEnable = NO;

			  // 在后台队列获取数据并更新 UI
			  dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
			    __weak AWESettingItemModel *weakItem = item;
			    __strong AWESettingItemModel *strongItem = weakItem;
			    if (!strongItem) {
				    return;
			    }

			    NSDictionary *currentData = [DYYYABTestHook getCurrentABTestData];

			    NSString *detailText = nil;
			    BOOL isItemEnable = NO;
			    NSData *jsonDataForSize = nil;

			    if (!currentData) {
				    detailText = @"(獲取失敗)";
				    isItemEnable = NO;
			    } else {
				    NSError *serializationError = nil;
				    jsonDataForSize = [NSJSONSerialization dataWithJSONObject:currentData options:NSJSONWritingPrettyPrinted error:&serializationError];
				    if (!serializationError && jsonDataForSize) {
					    detailText = [DYYYUtils formattedSize:jsonDataForSize.length];
					    isItemEnable = YES;
				    } else {
					    detailText = [NSString stringWithFormat:@"(序列化失敗: %@)", serializationError.localizedDescription ?: @"未知错误"];
					    isItemEnable = NO;
				    }
			    }

			    // 回到主线程更新 UI
			    dispatch_async(dispatch_get_main_queue(), ^{
			      __strong AWESettingItemModel *strongItemAgain = weakItem;
			      if (strongItemAgain) {
				      strongItemAgain.detail = detailText;
				      strongItemAgain.isEnable = isItemEnable;
				      [strongItemAgain refreshCell];
			      }
			    });
			  });

			  item.cellTappedBlock = ^{
			    NSDictionary *currentData = [DYYYABTestHook getCurrentABTestData];

			    if (!currentData) {
				    [DYYYUtils showToast:@"ABTest設定獲取失敗"];
				    return;
			    }

			    NSError *error;
			    NSData *sortedJsonData = [NSJSONSerialization dataWithJSONObject:currentData options:NSJSONWritingPrettyPrinted | NSJSONWritingSortedKeys error:&error];

			    if (error) {
				    [DYYYUtils showToast:@"ABTest設定序列化失敗"];
				    return;
			    }

			    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
			    [formatter setDateFormat:@"yyyyMMdd_HHmmss"];
			    NSString *timestamp = [formatter stringFromDate:[NSDate date]];
			    NSString *tempFile = [NSString stringWithFormat:@"ABTest_Config_%@.json", timestamp];
			    NSString *tempFilePath = [DYYYUtils cachePathForFilename:tempFile];

			    BOOL success = [sortedJsonData writeToFile:tempFilePath atomically:YES];

			    if (!success) {
				    [DYYYUtils showToast:@"臨時檔案建立失敗"];	
				    return;
			    }

			    NSURL *tempFileURL = [NSURL fileURLWithPath:tempFilePath];
			    UIDocumentPickerViewController *documentPicker = [[UIDocumentPickerViewController alloc] initWithURLs:@[ tempFileURL ] inMode:UIDocumentPickerModeExportToService];

			    DYYYBackupPickerDelegate *pickerDelegate = [[DYYYBackupPickerDelegate alloc] init];
			    pickerDelegate.tempFilePath = tempFilePath;
			    pickerDelegate.completionBlock = ^(NSURL *url) {
			      [DYYYUtils showToast:@"ABTest設定已儲存"];
			    };

			    static char kABTestPickerDelegateKey;
			    documentPicker.delegate = pickerDelegate;
			    objc_setAssociatedObject(documentPicker, &kABTestPickerDelegateKey, pickerDelegate, OBJC_ASSOCIATION_RETAIN_NONATOMIC);

			    UIViewController *topVC = topView();
			    [topVC presentViewController:documentPicker animated:YES completion:nil];
			  };
		  } else if ([item.identifier isEqualToString:@"SaveABTestConfigFile"]) {
			  item.detail = @"(獲取中...)";

			  saveABTestConfigFileItemRef = item;
			  refreshSaveABTestConfigFileItem();

			  item.cellTappedBlock = ^{
			    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
			    NSString *documentsDirectory = [paths firstObject];

			    NSString *dyyyFolderPath = [documentsDirectory stringByAppendingPathComponent:@"DYYY"];
			    NSString *jsonFilePath = [dyyyFolderPath stringByAppendingPathComponent:@"abtest_data_fixed.json"];

			    NSData *jsonData = [NSData dataWithContentsOfFile:jsonFilePath];
			    if (!jsonData) {
				    [DYYYUtils showToast:@"本機設定獲取失敗"];
				    return;					
			    }

			    NSError *error;
			    NSDictionary *originalData = [NSJSONSerialization JSONObjectWithData:jsonData options:0 error:&error];
			    if (error || ![originalData isKindOfClass:[NSDictionary class]]) {
				    [DYYYUtils showToast:@"本機設定序列化失敗"];
				    return;
			    }

			    NSData *sortedJsonData = [NSJSONSerialization dataWithJSONObject:originalData options:NSJSONWritingPrettyPrinted | NSJSONWritingSortedKeys error:&error];
			    if (error || !sortedJsonData) {
				    [DYYYUtils showToast:@"排序資料序列化失敗"];
				    return;
			    }

			    // 创建临时文件
			    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
			    [formatter setDateFormat:@"yyyyMMdd_HHmmss"];
			    NSString *timestamp = [formatter stringFromDate:[NSDate date]];
			    NSString *tempFile = [NSString stringWithFormat:@"abtest_data_fixed_%@.json", timestamp];
			    NSString *tempFilePath = [DYYYUtils cachePathForFilename:tempFile];

			    if (![sortedJsonData writeToFile:tempFilePath atomically:YES]) {
				    [DYYYUtils showToast:@"臨時檔案建立失敗"];
				    return;
			    }

			    UIDocumentPickerViewController *documentPicker = [[UIDocumentPickerViewController alloc] initWithURLs:@[ [NSURL fileURLWithPath:tempFilePath] ]
															   inMode:UIDocumentPickerModeExportToService];

			    DYYYBackupPickerDelegate *pickerDelegate = [[DYYYBackupPickerDelegate alloc] init];
			    pickerDelegate.tempFilePath = tempFilePath;
			    pickerDelegate.completionBlock = ^(NSURL *url) {
			      [DYYYUtils showToast:@"本機設定已儲存"];
			    };

			    static char kABTestConfigPickerDelegateKey;
			    documentPicker.delegate = pickerDelegate;
			    objc_setAssociatedObject(documentPicker, &kABTestConfigPickerDelegateKey, pickerDelegate, OBJC_ASSOCIATION_RETAIN_NONATOMIC);

			    UIViewController *topVC = topView();
			    [topVC presentViewController:documentPicker animated:YES completion:nil];
			  };
		  } else if ([item.identifier isEqualToString:@"LoadABTestConfigFile"]) {
			  item.cellTappedBlock = ^{
			    BOOL isPatchMode = [DYYYABTestHook isPatchMode];

			    NSString *confirmTitle, *confirmMessage;
			    if (isPatchMode) {
				    confirmTitle = @"覆寫模式";
				    confirmMessage = @"\n匯入後將保留原始設定並覆寫同名項，\n\n點選確定後繼續操作。\n";
			    } else {
				    confirmTitle = @"替換模式";
				    confirmMessage = @"\n匯入後將忽略原設定並寫入新數據，\n\n點選確定後繼續操作。\n";
			    }
			    DYYYAboutDialogView *confirmDialog = [[DYYYAboutDialogView alloc] initWithTitle:confirmTitle message:confirmMessage];
			    confirmDialog.onConfirm = ^{
			      UIDocumentPickerViewController *documentPicker = [[UIDocumentPickerViewController alloc] initWithDocumentTypes:@[ @"public.json" ] inMode:UIDocumentPickerModeImport];

			      DYYYBackupPickerDelegate *pickerDelegate = [[DYYYBackupPickerDelegate alloc] init];
			      pickerDelegate.completionBlock = ^(NSURL *url) {
				// Delegate 回调通常在主线程，但文件操作和 Hook 调用应在后台
				dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
				  __weak AWESettingItemModel *weakSaveItem = saveABTestConfigFileItemRef;

				  NSURL *sourceURL = url; // 用户选择的源文件 URL

				  NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
				  NSString *documentsDirectory = [paths firstObject];
				  NSString *dyyyFolderPath = [documentsDirectory stringByAppendingPathComponent:@"DYYY"];
				  NSURL *destinationURL = [NSURL fileURLWithPath:[dyyyFolderPath stringByAppendingPathComponent:@"abtest_data_fixed.json"]];

				  NSFileManager *fileManager = [NSFileManager defaultManager];
				  NSError *error = nil;
				  BOOL success = NO;
				  NSString *message = nil;

				  if (![fileManager fileExistsAtPath:dyyyFolderPath]) {
					  [fileManager createDirectoryAtPath:dyyyFolderPath withIntermediateDirectories:YES attributes:nil error:&error];
					  if (error) {
						  message = [NSString stringWithFormat:@"建立目錄失敗: %@", error.localizedDescription];
					  }
				  }

				  if (!message) {
					  // 在同一个目录下创建一个临时文件 URL 以确保原子性
					  NSString *tempFileName = [NSUUID UUID].UUIDString;
					  NSURL *temporaryURL = [NSURL fileURLWithPath:[dyyyFolderPath stringByAppendingPathComponent:tempFileName]];

					  if ([fileManager copyItemAtURL:sourceURL toURL:temporaryURL error:&error]) {
						  if ([fileManager replaceItemAtURL:destinationURL withItemAtURL:temporaryURL backupItemName:nil options:0 resultingItemURL:nil error:&error]) {
							  [DYYYABTestHook cleanLocalABTestData];
							  [DYYYABTestHook loadLocalABTestConfig];
							  [DYYYABTestHook applyFixedABTestData];
							  success = YES;
							  message = @"配置已導入，部分設定需重新啟動應用後生效";
						  } else {
							  [fileManager removeItemAtURL:temporaryURL error:nil];
							  message = [NSString stringWithFormat:@"導入失敗 (替換檔案失敗): %@", error.localizedDescription];
						  }
					  } else {
						  message = [NSString stringWithFormat:@"導入失敗 (複製到臨時檔案失敗): %@", error.localizedDescription];
					  }
				  }
				  // 回到主线程显示 Toast 和更新 UI
				  dispatch_async(dispatch_get_main_queue(), ^{
				    __strong AWESettingItemModel *strongSaveItemAgain = weakSaveItem;

				    // 无论成功与否，都显示 Toast 告知用户结果
				    NSString *message = success ? @"配置已導入，部分設定需重新啟動應用後生效" : [NSString stringWithFormat:@"導入失敗: %@", error.localizedDescription];
				    [DYYYUtils showToast:message];

				    // 仅在导入成功且 item 仍然存在时更新 UI
				    if (success && strongSaveItemAgain) {
					    refreshSaveABTestConfigFileItem();
				    }
				  });
				});
			      };

			      static char kPickerDelegateKey;
			      documentPicker.delegate = pickerDelegate;
			      objc_setAssociatedObject(documentPicker, &kPickerDelegateKey, pickerDelegate, OBJC_ASSOCIATION_RETAIN_NONATOMIC);

			      UIViewController *topVC = topView();
			      [topVC presentViewController:documentPicker animated:YES completion:nil];
			    };
			    [confirmDialog show];
			  };
		  } else if ([item.identifier isEqualToString:@"DeleteABTestConfigFile"]) {
			  item.cellTappedBlock = ^{
			    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
			    NSString *documentsDirectory = [paths firstObject];
			    NSString *dyyyFolderPath = [documentsDirectory stringByAppendingPathComponent:@"DYYY"];
			    NSString *configPath = [dyyyFolderPath stringByAppendingPathComponent:@"abtest_data_fixed.json"];

			    if ([[NSFileManager defaultManager] fileExistsAtPath:configPath]) {
				    NSError *error = nil;
				    BOOL success = [[NSFileManager defaultManager] removeItemAtPath:configPath error:&error];

				    NSString *message = success ? @"本機設定已刪除成功" : [NSString stringWithFormat:@"刪除失敗: %@", error.localizedDescription];
				    [DYYYUtils showToast:message];

				    if (success) {
					    [DYYYABTestHook cleanLocalABTestData];
					    // 删除成功后修改 SaveABTestConfigFile item 的状态
					    saveABTestConfigFileItemRef.detail = @"(檔案已刪除)";
					    saveABTestConfigFileItemRef.isEnable = NO;
					    [saveABTestConfigFileItemRef refreshCell];
				    }
			    } else {
				    [DYYYUtils showToast:@"本機設定不存在"];
			    }
			  };
		  }

		  [hotUpdateItems addObject:item];
	  }

	  // 【交互增强】分类
	  NSMutableArray<AWESettingItemModel *> *interactionItems = [NSMutableArray array];
	  NSArray *interactionSettings = @[
		  @{
			  @"identifier" : @"DYYYentrance",
			  @"title" : @"左側邊欄快捷入口",
			  @"subTitle" : @"將側邊欄替換為 DYYY 快速入口",
			  @"detail" : @"",
			  @"cellType" : @37,
			  @"imageName" : @"ic_circlearrowin_outlined_20"
		  },
		  @{
			  @"identifier" : @"DYYYDisableSidebarGesture",
			  @"title" : @"禁止側滑進入邊欄",
			  @"subTitle" : @"禁止在首頁最左邊的頁面時右滑進入側邊欄",
			  @"detail" : @"",
			  @"cellType" : @37,
			  @"imageName" : @"ic_circlearrowin_outlined_20"
		  },
		  @{
			  @"identifier" : @"DYYYVideoGesture",
			  @"title" : @"橫向影片交互增強",
			  @"subTitle" : @"啟用橫向螢幕影片的手勢功能",
			  @"detail" : @"",
			  @"cellType" : @37,
			  @"imageName" : @"ic_phonearrowdown_outlined_20"
		  },
		  @{
			  @"identifier" : @"DYYYDisableAutoEnterLive",
			  @"title" : @"禁用自動進入直播",
			  @"subTitle" : @"禁止頂欄直播下自動進入直播間",
			  @"detail" : @"",
			  @"cellType" : @37,
			  @"imageName" : @"ic_video_outlined_20"
		  },
		  @{@"identifier" : @"DYYYEnableSaveAvatar",
		    @"title" : @"啟用儲存他人頭像",
		    @"detail" : @"",
		    @"cellType" : @6,
		    @"imageName" : @"ic_personcircleclean_outlined_20"},
		  @{@"identifier" : @"DYYYCommentCopyText",
		    @"title" : @"複製評論移除暱稱",
		    @"detail" : @"",
		    @"cellType" : @6,
		    @"imageName" : @"ic_at_outlined_20"},
		  @{
			  @"identifier" : @"DYYYBioCopyText",
			  @"title" : @"長按簡介複製簡介",
			  @"subTitle" : @"長按個人主頁的簡介複製",
			  @"detail" : @"",
			  @"cellType" : @37,
			  @"imageName" : @"ic_rectangleonrectangleup_outlined_20"
		  },
		  @{
			  @"identifier" : @"DYYYLongPressCopyTextEnabled",
			  @"title" : @"長按文案複製文案",
			  @"subTitle" : @"長按影片左下角的文案複製",
			  @"detail" : @"",
			  @"cellType" : @37,
			  @"imageName" : @"ic_rectangleonrectangleup_outlined_20"
		  },
		  @{
			  @"identifier" : @"DYYYMusicCopyText",
			  @"title" : @"評論音樂點擊複製",
			  @"subTitle" : @"含有音樂的影片開啟留言區頂部時，移除去汽水聽，點擊複製歌曲名稱",
			  @"detail" : @"",
			  @"cellType" : @37,
			  @"imageName" : @"ic_quaver_outlined_20"
		  },
		  @{@"identifier" : @"DYYYisAutoSelectOriginalPhoto",
		    @"title" : @"啟用自動勾選原圖",
		    @"detail" : @"",
		    @"cellType" : @6,
		    @"imageName" : @"ic_image_outlined_20"},
		  @{
			  @"identifier" : @"DYYYisEnableModern",
			  @"title" : @"啟用新版玻璃面板",
			  @"subTitle" : @"啟用抖音灰階測試的長按毛玻璃面板功能",
			  @"detail" : @"",
			  @"cellType" : @37,
			  @"imageName" : @"ic_moon_outlined"
		  },
		  @{@"identifier" : @"DYYYisEnableModernLight",
		    @"title" : @"啟用新版淺色面板",
		    @"detail" : @"",
		    @"cellType" : @6,
		    @"imageName" : @"ic_sun_outlined"},
		  @{@"identifier" : @"DYYYModernPanelFollowSystem",
		    @"title" : @"新版面板跟隨系統",
		    @"detail" : @"",
		    @"cellType" : @6,
		    @"imageName" : @"ic_squaresplit_outlined_20"},
		  @{@"identifier" : @"DYYYDouble",
		    @"title" : @"禁用雙擊影片按讚",
		    @"detail" : @"",
		    @"cellType" : @6,
		    @"imageName" : @"ic_thumbsup_outlined_20"},
		  @{@"identifier" : @"DYYYEnableDoubleOpenComment",
		    @"title" : @"啟用雙擊開啟評論",
		    @"detail" : @"",
		    @"cellType" : @6,
		    @"imageName" : @"ic_comment_outlined_20"},
		  @{
			  @"identifier" : @"DYYYDefaultEnterWorks",
			  @"title" : @"資料預設進入作品",
			  @"subTitle" : @"禁止個人資料頁自動進入櫥窗等頁面",
			  @"detail" : @"",
			  @"cellType" : @37,
			  @"imageName" : @"ic_playsquarestack_outlined_20"
		  },
		  @{
			  @"identifier" : @"DYYYEnableDoubleOpenAlertController",
			  @"title" : @"啟用雙擊開啟選單",
			  @"subTitle" : @"無法與雙擊開啟評論同時啟用",
			  @"detail" : @"",
			  @"cellType" : @20,
			  @"imageName" : @"ic_xiaoxihuazhonghua_outlined_20"
		  },
		  @{@"identifier" : @"DYYYDisableHomeRefresh",
		    @"title" : @"禁用點擊首頁重新整理",
		    @"detail" : @"",
		    @"cellType" : @6,
		    @"imageName" : @"ic_arrowcircle_outlined_20"}
	  ];

	  for (NSDictionary *dict in interactionSettings) {
		  AWESettingItemModel *item = [DYYYSettingsHelper createSettingItem:dict];
		  if ([item.identifier isEqualToString:@"DYYYEnableDoubleOpenAlertController"]) {
			  item.cellTappedBlock = ^{
			    // 检查是否启用了双击打开评论功能
			    BOOL isEnableDoubleOpenComment = [DYYYSettingsHelper getUserDefaults:@"DYYYEnableDoubleOpenComment"];
			    if (isEnableDoubleOpenComment) {
				    return;
			    }

			    NSMutableArray<AWESettingItemModel *> *doubleTapItems = [NSMutableArray array];
			    AWESettingItemModel *enableDoubleTapMenu = [DYYYSettingsHelper createSettingItem:@{
				    @"identifier" : @"DYYYEnableDoubleOpenAlertController",
				    @"title" : @"啟用雙擊選單",
				    @"detail" : @"",
				    @"cellType" : @6,
				    @"imageName" : @"ic_xiaoxihuazhonghua_outlined_20"
			    }];
			    [doubleTapItems addObject:enableDoubleTapMenu];
			    NSArray *doubleTapFunctions = @[
				    @{@"identifier" : @"DYYYDoubleTapDownload",
				      @"title" : @"儲存影片/圖片",
				      @"detail" : @"",
				      @"cellType" : @6,
				      @"imageName" : @"ic_boxarrowdown_outlined"},
				    @{@"identifier" : @"DYYYDoubleTapDownloadAudio",
				      @"title" : @"儲存音訊",
				      @"detail" : @"",
				      @"cellType" : @6,
				      @"imageName" : @"ic_boxarrowdown_outlined"},
				    @{@"identifier" : @"DYYYDoubleInterfaceDownload",
				      @"title" : @"接口儲存",
				      @"detail" : @"",
				      @"cellType" : @6,
				      @"imageName" : @"ic_cloudarrowdown_outlined_20"},
				    @{@"identifier" : @"DYYYDoubleCreateVideo",
				      @"title" : @"製作影片",
				      @"detail" : @"",
				      @"cellType" : @6,
				      @"imageName" : @"ic_videosearch_outlined_20"},
				    @{@"identifier" : @"DYYYDoubleTapCopyDesc",
				      @"title" : @"複製文案",
				      @"detail" : @"",
				      @"cellType" : @6,
				      @"imageName" : @"ic_rectangleonrectangleup_outlined_20"},
				    @{@"identifier" : @"DYYYDoubleTapComment",
				      @"title" : @"開啟評論",
				      @"detail" : @"",
				      @"cellType" : @6,
				      @"imageName" : @"ic_comment_outlined_20"},
				    @{@"identifier" : @"DYYYDoubleTapLike",
				      @"title" : @"按讚影片",
				      @"detail" : @"",
				      @"cellType" : @6,
				      @"imageName" : @"ic_heart_outlined_20"},
				    @{
					    @"identifier" : @"DYYYDoubleTapshowDislikeOnVideo",
					    @"title" : @"長按面板",
					    @"detail" : @"",
					    @"cellType" : @6,
					    @"imageName" : @"ic_xiaoxihuazhonghua_outlined_20"
				    },
				    @{@"identifier" : @"DYYYDoubleTapshowSharePanel",
				      @"title" : @"分享影片",
				      @"detail" : @"",
				      @"cellType" : @6,
				      @"imageName" : @"ic_share_outlined"},
			    ];

			    for (NSDictionary *dict in doubleTapFunctions) {
				    AWESettingItemModel *functionItem = [DYYYSettingsHelper createSettingItem:dict];
				    [doubleTapItems addObject:functionItem];
			    }
			    NSMutableArray *sections = [NSMutableArray array];
			    [sections addObject:[DYYYSettingsHelper createSectionWithTitle:@"雙擊選單設定" items:doubleTapItems]];
			    AWESettingBaseViewController *subVC = [DYYYSettingsHelper createSubSettingsViewController:@"雙擊選單設定" sections:sections];
			    [rootVC.navigationController pushViewController:(UIViewController *)subVC animated:YES];
			  };
		  }

		  [interactionItems addObject:item];
	  }

	  // 创建并组织所有section
	  NSMutableArray *sections = [NSMutableArray array];
	  [sections addObject:[DYYYSettingsHelper createSectionWithTitle:@"長按面板設定" items:longPressItems]];
	  [sections addObject:[DYYYSettingsHelper createSectionWithTitle:@"媒體儲存" items:downloadItems]];
	  [sections addObject:[DYYYSettingsHelper createSectionWithTitle:@"互動增強" items:interactionItems]];
	  [sections addObject:[DYYYSettingsHelper createSectionWithTitle:@"熱更新" footerTitle:@"允許使用者匯出或匯入抖音的ABTest設定，非必要不需要開啟。" items:hotUpdateItems]];
	  // 创建并推入二级设置页面
	  AWESettingBaseViewController *subVC = [DYYYSettingsHelper createSubSettingsViewController:@"增強設定" sections:sections];
	  [rootVC.navigationController pushViewController:(UIViewController *)subVC animated:YES];
	};

	[mainItems addObject:enhanceSettingItem];

	// 创建悬浮按钮设置分类项
	AWESettingItemModel *floatButtonSettingItem = [[%c(AWESettingItemModel) alloc] init];
	floatButtonSettingItem.identifier = @"DYYYFloatButtonSettings";
	floatButtonSettingItem.title = @"懸浮按鈕";
	floatButtonSettingItem.type = 0;
	floatButtonSettingItem.svgIconImageName = @"ic_gongchuang_outlined_20";
	floatButtonSettingItem.cellType = 26;
	floatButtonSettingItem.colorStyle = 0;
	floatButtonSettingItem.isEnable = YES;
	floatButtonSettingItem.cellTappedBlock = ^{
	  // 创建悬浮按钮设置二级界面的设置项

	  // 快捷倍速section
	  NSMutableArray<AWESettingItemModel *> *speedButtonItems = [NSMutableArray array];

	  // 倍速按钮
	  AWESettingItemModel *enableSpeedButton = [DYYYSettingsHelper
	      createSettingItem:
		  @{@"identifier" : @"DYYYEnableFloatSpeedButton",
		    @"title" : @"啟用快捷倍速按鈕",
		    @"detail" : @"",
		    @"cellType" : @6,
		    @"imageName" : @"ic_xspeed_outlined"}];
	  [speedButtonItems addObject:enableSpeedButton];

	  // 添加倍速设置项
	  AWESettingItemModel *speedSettingsItem = [[%c(AWESettingItemModel) alloc] init];
	  speedSettingsItem.identifier = @"DYYYSpeedSettings";
	  speedSettingsItem.title = @"快捷倍速數值設定";
	  speedSettingsItem.type = 0;
	  speedSettingsItem.svgIconImageName = @"ic_speed_outlined_20";
	  speedSettingsItem.cellType = 26;
	  speedSettingsItem.colorStyle = 0;
	  speedSettingsItem.isEnable = YES;

	  // 获取已保存的倍速数值设置
	  NSString *savedSpeedSettings = [[NSUserDefaults standardUserDefaults] objectForKey:@"DYYYSpeedSettings"];
	  // 如果没有设置过，使用默认值
	  if (!savedSpeedSettings || savedSpeedSettings.length == 0) {
		  savedSpeedSettings = @"1.0,1.25,1.5,2.0";
	  }
	  speedSettingsItem.detail = [NSString stringWithFormat:@"%@", savedSpeedSettings];
	  speedSettingsItem.cellTappedBlock = ^{
	    [DYYYSettingsHelper showTextInputAlert:@"設定快捷倍速數值"
				       defaultText:speedSettingsItem.detail
				       placeholder:@"使用半角逗號(,)分隔倍速值"
					 onConfirm:^(NSString *text) {
					   // 保存用户输入的倍速值
					   NSString *trimmedText = [text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
					   [[NSUserDefaults standardUserDefaults] setObject:trimmedText forKey:@"DYYYSpeedSettings"];
					   [[NSUserDefaults standardUserDefaults] synchronize];
					   speedSettingsItem.detail = trimmedText;
					   [speedSettingsItem refreshCell];
					 }
					  onCancel:nil];
	  };

	  // 添加自动恢复倍速设置项
	  AWESettingItemModel *autoRestoreSpeedItem = [[%c(AWESettingItemModel) alloc] init];
	  autoRestoreSpeedItem.identifier = @"DYYYAutoRestoreSpeed";
	  autoRestoreSpeedItem.title = @"自動恢復預設倍速";
	  autoRestoreSpeedItem.detail = @"";
	  autoRestoreSpeedItem.type = 1000;
	  autoRestoreSpeedItem.svgIconImageName = @"ic_switch_outlined";
	  autoRestoreSpeedItem.cellType = 6;
	  autoRestoreSpeedItem.colorStyle = 0;
	  autoRestoreSpeedItem.isEnable = YES;
	  autoRestoreSpeedItem.isSwitchOn = [[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYAutoRestoreSpeed"];
	  autoRestoreSpeedItem.switchChangedBlock = ^{
	    BOOL newValue = !autoRestoreSpeedItem.isSwitchOn;
	    autoRestoreSpeedItem.isSwitchOn = newValue;
	    [[NSUserDefaults standardUserDefaults] setBool:newValue forKey:@"DYYYAutoRestoreSpeed"];
	    [[NSUserDefaults standardUserDefaults] synchronize];
	  };
	  [speedButtonItems addObject:autoRestoreSpeedItem];

	  AWESettingItemModel *showXItem = [[%c(AWESettingItemModel) alloc] init];
	  showXItem.identifier = @"DYYYSpeedButtonShowX";
	  showXItem.title = @"倍速按鈕顯示後綴";
	  showXItem.detail = @"";
	  showXItem.type = 1000;
	  showXItem.svgIconImageName = @"ic_pensketch_outlined_20";
	  showXItem.cellType = 6;
	  showXItem.colorStyle = 0;
	  showXItem.isEnable = YES;
	  showXItem.isSwitchOn = [[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYSpeedButtonShowX"];
	  showXItem.switchChangedBlock = ^{
	    BOOL newValue = !showXItem.isSwitchOn;
	    showXItem.isSwitchOn = newValue;
	    [[NSUserDefaults standardUserDefaults] setBool:newValue forKey:@"DYYYSpeedButtonShowX"];
	    [[NSUserDefaults standardUserDefaults] synchronize];
	  };
	  [speedButtonItems addObject:showXItem];
	  // 添加按钮大小配置项
	  AWESettingItemModel *buttonSizeItem = [[%c(AWESettingItemModel) alloc] init];
	  buttonSizeItem.identifier = @"DYYYSpeedButtonSize";
	  buttonSizeItem.title = @"快捷倍速按鈕大小";
	  // 获取当前的按钮大小，如果没有设置则默认为32
	  CGFloat currentButtonSize = [[NSUserDefaults standardUserDefaults] floatForKey:@"DYYYSpeedButtonSize"] ?: 32;
	  buttonSizeItem.detail = [NSString stringWithFormat:@"%.0f", currentButtonSize];
	  buttonSizeItem.type = 0;
	  buttonSizeItem.svgIconImageName = @"ic_zoomin_outlined_20";
	  buttonSizeItem.cellType = 26;
	  buttonSizeItem.colorStyle = 0;
	  buttonSizeItem.isEnable = YES;
	  buttonSizeItem.cellTappedBlock = ^{
	    NSString *currentValue = [NSString stringWithFormat:@"%.0f", currentButtonSize];
	    [DYYYSettingsHelper showTextInputAlert:@"設定按鈕大小"
				       defaultText:currentValue
				       placeholder:@"請輸入20-60之間的數值"
					 onConfirm:^(NSString *text) {
					   NSInteger size = [text integerValue];
					   if (size >= 20 && size <= 60) {
						   [[NSUserDefaults standardUserDefaults] setFloat:size forKey:@"DYYYSpeedButtonSize"];
						   [[NSUserDefaults standardUserDefaults] synchronize];
						   buttonSizeItem.detail = [NSString stringWithFormat:@"%.0f", (CGFloat)size];
						   [buttonSizeItem refreshCell];
					   } else {
						   [DYYYUtils showToast:@"請輸入20-60之間的有效數值"];
					   }
					 }
					  onCancel:nil];
	  };

	  [speedButtonItems addObject:buttonSizeItem];

	  [speedButtonItems addObject:speedSettingsItem];

	  // 一键清屏section
	  NSMutableArray<AWESettingItemModel *> *clearButtonItems = [NSMutableArray array];

	  // 清屏按钮
	  AWESettingItemModel *enableClearButton = [DYYYSettingsHelper
	      createSettingItem:
		  @{@"identifier" : @"DYYYEnableFloatClearButton",
		    @"title" : @"一鍵清除螢幕按鈕",
		    @"detail" : @"",
		    @"cellType" : @6,
		    @"imageName" : @"ic_eyeslash_outlined_16"}];
	  [clearButtonItems addObject:enableClearButton];

	  // 添加清屏按钮大小配置项
	  AWESettingItemModel *clearButtonSizeItem = [[%c(AWESettingItemModel) alloc] init];
	  clearButtonSizeItem.identifier = @"DYYYEnableFloatClearButtonSize";
	  clearButtonSizeItem.title = @"清除螢幕按鈕大小";
	  // 获取当前的按钮大小，如果没有设置则默认为40
	  CGFloat currentClearButtonSize = [[NSUserDefaults standardUserDefaults] floatForKey:@"DYYYEnableFloatClearButtonSize"] ?: 40;
	  clearButtonSizeItem.detail = [NSString stringWithFormat:@"%.0f", currentClearButtonSize];
	  clearButtonSizeItem.type = 0;
	  clearButtonSizeItem.svgIconImageName = @"ic_zoomin_outlined_20";
	  clearButtonSizeItem.cellType = 26;
	  clearButtonSizeItem.colorStyle = 0;
	  clearButtonSizeItem.isEnable = YES;
	  clearButtonSizeItem.cellTappedBlock = ^{
	    NSString *currentValue = [NSString stringWithFormat:@"%.0f", currentClearButtonSize];
	    [DYYYSettingsHelper showTextInputAlert:@"設定清除螢幕按鈕大小"
				       defaultText:currentValue
				       placeholder:@"請輸入20-60之間的數值"
					 onConfirm:^(NSString *text) {
					   NSInteger size = [text integerValue];
					   // 确保输入值在有效范围内
					   if (size >= 20 && size <= 60) {
						   [[NSUserDefaults standardUserDefaults] setFloat:size forKey:@"DYYYEnableFloatClearButtonSize"];
						   [[NSUserDefaults standardUserDefaults] synchronize];
						   clearButtonSizeItem.detail = [NSString stringWithFormat:@"%.0f", (CGFloat)size];
						   [clearButtonSizeItem refreshCell];
					   } else {
						   [DYYYUtils showToast:@"請輸入20-60之間的有效數值"];
					   }
					 }
					  onCancel:nil];
	  };
	  [clearButtonItems addObject:clearButtonSizeItem];

	  // 添加清屏按钮自定义图标选项
	  AWESettingItemModel *clearButtonIcon = [DYYYSettingsHelper createIconCustomizationItemWithIdentifier:@"DYYYClearButtonIcon"
													 title:@"清除螢幕按鈕圖示"
												       svgIcon:@"ic_roaming_outlined"
												      saveFile:@"qingping.gif"];

	  [clearButtonItems addObject:clearButtonIcon];
	  // 清屏隐藏弹幕
	  AWESettingItemModel *hideDanmakuButton = [DYYYSettingsHelper
	      createSettingItem:
		  @{@"identifier" : @"DYYYHideDanmaku",
		    @"title" : @"清除螢幕隱藏彈幕",
		    @"detail" : @"",
		    @"cellType" : @6,
		    @"imageName" : @"ic_eyeslash_outlined_16"}];
	  [clearButtonItems addObject:hideDanmakuButton];

	  AWESettingItemModel *enableqingButton = [DYYYSettingsHelper createSettingItem:@{
		  @"identifier" : @"DYYYEnabshijianjindu",
		  @"title" : @"清除螢幕移除進度",
		  @"subTitle" : @"清除螢幕狀態下完全移除時間進度條",
		  @"detail" : @"",
		  @"cellType" : @37,
		  @"imageName" : @"ic_eyeslash_outlined_16"
	  }];
	  [clearButtonItems addObject:enableqingButton];
	  // 清屏隐藏时间进度
	  AWESettingItemModel *enableqingButton1 = [DYYYSettingsHelper createSettingItem:@{
		  @"identifier" : @"DYYYHideTimeProgress",
		  @"title" : @"清除螢幕隱藏進度",
		  @"subTitle" : @"原始位置可拖曳時間進度條",
		  @"detail" : @"",
		  @"cellType" : @37,
		  @"imageName" : @"ic_eyeslash_outlined_16"
	  }];
	  [clearButtonItems addObject:enableqingButton1];
	  AWESettingItemModel *hideSliderButton = [DYYYSettingsHelper createSettingItem:@{
		  @"identifier" : @"DYYYHideSlider",
		  @"title" : @"清除螢幕隱藏滑條",
		  @"subTitle" : @"清除螢幕狀態下隱藏多圖片下方的滑條",
		  @"detail" : @"",
		  @"cellType" : @37,
		  @"imageName" : @"ic_eyeslash_outlined_16"
	  }];
	  [clearButtonItems addObject:hideSliderButton];
	  AWESettingItemModel *hideChapterButton = [DYYYSettingsHelper createSettingItem:@{
		  @"identifier" : @"DYYYHideChapter",
		  @"title" : @"清除螢幕隱藏章節",
		  @"subTitle" : @"清除螢幕狀態下隱藏部分影片出現的章節進度顯示",
		  @"detail" : @"",
		  @"cellType" : @37,
		  @"imageName" : @"ic_eyeslash_outlined_16"
	  }];
	  [clearButtonItems addObject:hideChapterButton];
	  AWESettingItemModel *hideTabButton = [DYYYSettingsHelper
	      createSettingItem:
		  @{@"identifier" : @"DYYYHideTabBar",
		    @"title" : @"清除螢幕隱藏底欄",
		    @"detail" : @"",
		    @"cellType" : @6,
		    @"imageName" : @"ic_eyeslash_outlined_16"}];
	  [clearButtonItems addObject:hideTabButton];
	  AWESettingItemModel *hideSpeedButton = [DYYYSettingsHelper createSettingItem:@{
		  @"identifier" : @"DYYYHideSpeed",
		  @"title" : @"清除螢幕隱藏倍速",
		  @"subTitle" : @"清除螢幕狀態下隱藏DYYY的倍速按鈕",
		  @"detail" : @"",
		  @"cellType" : @37,
		  @"imageName" : @"ic_eyeslash_outlined_16"
	  }];
	  [clearButtonItems addObject:hideSpeedButton];
	  // 获取清屏按钮的当前开关状态
	  BOOL isEnabled = [DYYYSettingsHelper getUserDefaults:@"DYYYEnableFloatClearButton"];
	  clearButtonSizeItem.isEnable = isEnabled;
	  clearButtonIcon.isEnable = isEnabled;

	  // 创建并组织所有section
	  NSMutableArray *sections = [NSMutableArray array];
	  [sections addObject:[DYYYSettingsHelper createSectionWithTitle:@"快捷倍速" items:speedButtonItems]];
	  [sections addObject:[DYYYSettingsHelper createSectionWithTitle:@"一鍵清除螢幕" items:clearButtonItems]];

	  // 创建并推入二级设置页面
	  AWESettingBaseViewController *subVC = [DYYYSettingsHelper createSubSettingsViewController:@"懸浮按鈕" sections:sections];
	  [rootVC.navigationController pushViewController:(UIViewController *)subVC animated:YES];
	};
	[mainItems addObject:floatButtonSettingItem];

	// 创建备份设置分类
	AWESettingSectionModel *backupSection = [[%c(AWESettingSectionModel) alloc] init];
	backupSection.sectionHeaderTitle = @"備份";
	backupSection.sectionHeaderHeight = 40;
	backupSection.type = 0;
	NSMutableArray<AWESettingItemModel *> *backupItems = [NSMutableArray array];

	AWESettingItemModel *backupItem = [[%c(AWESettingItemModel) alloc] init];
	backupItem.identifier = @"DYYYBackupSettings";
	backupItem.title = @"備份設定";
	backupItem.detail = @"";
	backupItem.type = 0;
	backupItem.svgIconImageName = @"ic_memorycard_outlined_20";
	backupItem.cellType = 26;
	backupItem.colorStyle = 0;
	backupItem.isEnable = YES;
	backupItem.cellTappedBlock = ^{
	  // 获取所有以DYYY开头的NSUserDefaults键值
	  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	  NSDictionary *allDefaults = [defaults dictionaryRepresentation];
	  NSMutableDictionary *dyyySettings = [NSMutableDictionary dictionary];

	  for (NSString *key in allDefaults.allKeys) {
		  if ([key hasPrefix:@"DYYY"]) {
			  dyyySettings[key] = [defaults objectForKey:key];
		  }
	  }

	  // 查找并添加图标文件
	  NSString *documentsPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject];
	  NSString *dyyyFolderPath = [documentsPath stringByAppendingPathComponent:@"DYYY"];

	  NSArray *iconFileNames = @[ @"like_before.png", @"like_after.png", @"comment.png", @"unfavorite.png", @"favorite.png", @"share.png", @"tab_plus.png", @"qingping.gif" ];

	  NSMutableDictionary *iconBase64Dict = [NSMutableDictionary dictionary];

	  for (NSString *iconFileName in iconFileNames) {
		  NSString *iconPath = [dyyyFolderPath stringByAppendingPathComponent:iconFileName];
		  if ([[NSFileManager defaultManager] fileExistsAtPath:iconPath]) {
			  // 读取图片数据并转换为Base64
			  NSData *imageData = [NSData dataWithContentsOfFile:iconPath];
			  if (imageData) {
				  NSString *base64String = [imageData base64EncodedStringWithOptions:0];
				  iconBase64Dict[iconFileName] = base64String;
			  }
		  }
	  }

	  // 将图标Base64数据添加到备份设置中
	  if (iconBase64Dict.count > 0) {
		  dyyySettings[@"DYYYIconsBase64"] = iconBase64Dict;
	  }

	  // 转换为JSON数据
	  NSError *error;
	  id jsonObject = DYYYJSONSafeObject(dyyySettings);
	  NSData *sortedJsonData = [NSJSONSerialization dataWithJSONObject:jsonObject options:NSJSONWritingPrettyPrinted | NSJSONWritingSortedKeys error:&error];

	  if (error) {
		  [DYYYUtils showToast:@"備份失敗：無法序列化設定資料"];
		  return;
	  }

	  NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
	  [formatter setDateFormat:@"yyyyMMdd_HHmmss"];
	  NSString *timestamp = [formatter stringFromDate:[NSDate date]];
	  NSString *backupFileName = [NSString stringWithFormat:@"DYYY_Backup_%@.json", timestamp];
	  NSString *tempFilePath = [DYYYUtils cachePathForFilename:backupFileName];

	  BOOL success = [sortedJsonData writeToFile:tempFilePath atomically:YES];

	  if (!success) {
		  [DYYYUtils showToast:@"備份失敗：無法建立臨時檔案"];
		  return;
	  }

	  // 创建文档选择器让用户选择保存位置
	  NSURL *tempFileURL = [NSURL fileURLWithPath:tempFilePath];
	  UIDocumentPickerViewController *documentPicker = [[UIDocumentPickerViewController alloc] initWithURLs:@[ tempFileURL ] inMode:UIDocumentPickerModeExportToService];

	  DYYYBackupPickerDelegate *pickerDelegate = [[DYYYBackupPickerDelegate alloc] init];
	  pickerDelegate.tempFilePath = tempFilePath; // 设置临时文件路径
	  pickerDelegate.completionBlock = ^(NSURL *url) {
	    // 备份成功
	    [DYYYUtils showToast:@"備份成功"];
	  };

	  static char kDYYYBackupPickerDelegateKey;
	  documentPicker.delegate = pickerDelegate;
	  objc_setAssociatedObject(documentPicker, &kDYYYBackupPickerDelegateKey, pickerDelegate, OBJC_ASSOCIATION_RETAIN_NONATOMIC);

	  UIViewController *topVC = topView();
	  [topVC presentViewController:documentPicker animated:YES completion:nil];
	};
	[backupItems addObject:backupItem];

	// 添加恢复设置
	AWESettingItemModel *restoreItem = [[%c(AWESettingItemModel) alloc] init];
	restoreItem.identifier = @"DYYYRestoreSettings";
	restoreItem.title = @"恢復設定";
	restoreItem.detail = @"";
	restoreItem.type = 0;
	restoreItem.svgIconImageName = @"ic_phonearrowup_outlined_20";
	restoreItem.cellType = 26;
	restoreItem.colorStyle = 0;
	restoreItem.isEnable = YES;
	restoreItem.cellTappedBlock = ^{
	  UIDocumentPickerViewController *documentPicker = [[UIDocumentPickerViewController alloc] initWithDocumentTypes:@[ @"public.json", @"public.text" ] inMode:UIDocumentPickerModeImport];
	  documentPicker.allowsMultipleSelection = NO;

	  // 设置委托
	  DYYYBackupPickerDelegate *pickerDelegate = [[DYYYBackupPickerDelegate alloc] init];
	  pickerDelegate.completionBlock = ^(NSURL *url) {
	    NSData *jsonData = [NSData dataWithContentsOfURL:url];

	    if (!jsonData) {
		    [DYYYUtils showToast:@"無法讀取備份檔案"];
		    return;
	    }

	    NSError *jsonError;
	    NSDictionary *dyyySettings = [NSJSONSerialization JSONObjectWithData:jsonData options:0 error:&jsonError];

	    if (jsonError || ![dyyySettings isKindOfClass:[NSDictionary class]]) {
		    [DYYYUtils showToast:@"備份檔案格式錯誤"];
		    return;
	    }

	    // 恢复图标文件
	    NSDictionary *iconBase64Dict = dyyySettings[@"DYYYIconsBase64"];
	    if (iconBase64Dict && [iconBase64Dict isKindOfClass:[NSDictionary class]]) {
		    NSString *documentsPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject];
		    NSString *dyyyFolderPath = [documentsPath stringByAppendingPathComponent:@"DYYY"];

		    // 确保DYYY文件夹存在
		    if (![[NSFileManager defaultManager] fileExistsAtPath:dyyyFolderPath]) {
			    [[NSFileManager defaultManager] createDirectoryAtPath:dyyyFolderPath withIntermediateDirectories:YES attributes:nil error:nil];
		    }

		    // 从Base64还原图标文件
		    for (NSString *iconFileName in iconBase64Dict) {
			    NSString *base64String = iconBase64Dict[iconFileName];
			    if ([base64String isKindOfClass:[NSString class]]) {
				    NSData *imageData = [[NSData alloc] initWithBase64EncodedString:base64String options:0];
				    if (imageData) {
					    NSString *iconPath = [dyyyFolderPath stringByAppendingPathComponent:iconFileName];
					    [imageData writeToFile:iconPath atomically:YES];
				    }
			    }
		    }

		    NSMutableDictionary *cleanSettings = [dyyySettings mutableCopy];
		    [cleanSettings removeObjectForKey:@"DYYYIconsBase64"];
		    dyyySettings = cleanSettings;
	    }

	    // 恢复设置
	    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	    for (NSString *key in dyyySettings) {
		    [defaults setObject:dyyySettings[key] forKey:key];
	    }
	    [defaults synchronize];

	    [DYYYUtils showToast:@"設定已恢復，請重啟應用以應用所有更改"];

	    [restoreItem refreshCell];
	  };

	  static char kDYYYRestorePickerDelegateKey;
	  documentPicker.delegate = pickerDelegate;
	  objc_setAssociatedObject(documentPicker, &kDYYYRestorePickerDelegateKey, pickerDelegate, OBJC_ASSOCIATION_RETAIN_NONATOMIC);

	  UIViewController *topVC = topView();
	  [topVC presentViewController:documentPicker animated:YES completion:nil];
	};
	[backupItems addObject:restoreItem];
	backupSection.itemArray = backupItems;

	// 创建清理section
	AWESettingSectionModel *cleanupSection = [[%c(AWESettingSectionModel) alloc] init];
	cleanupSection.sectionHeaderTitle = @"清理";
	cleanupSection.sectionHeaderHeight = 40;
	cleanupSection.type = 0;
	NSMutableArray<AWESettingItemModel *> *cleanupItems = [NSMutableArray array];
	AWESettingItemModel *cleanSettingsItem = [[%c(AWESettingItemModel) alloc] init];
	cleanSettingsItem.identifier = @"DYYYCleanSettings";
	cleanSettingsItem.title = @"清除設定";
	cleanSettingsItem.detail = @"";
	cleanSettingsItem.type = 0;
	cleanSettingsItem.svgIconImageName = @"ic_trash_outlined_20";
	cleanSettingsItem.cellType = 26;
	cleanSettingsItem.colorStyle = 0;
	cleanSettingsItem.isEnable = YES;
	cleanSettingsItem.cellTappedBlock = ^{
	  [DYYYBottomAlertView showAlertWithTitle:@"清除設定"
	      message:@"請選擇要清除的設定類型"
	      avatarURL:nil
	      cancelButtonText:@"清除抖音設定"
	      confirmButtonText:@"清除插件設定"
	      cancelAction:^{
		// 清除抖音设置的确认对话框
		[DYYYBottomAlertView showAlertWithTitle:@"清除抖音設定"
						message:@"確定要清除抖音所有設定嗎？\n這將無法恢復，應用會自動退出！"
					      avatarURL:nil
				       cancelButtonText:@"取消"
				      confirmButtonText:@"確定"
					   cancelAction:nil
					    closeAction:nil
					  confirmAction:^{
					    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES);
					    if (paths.count > 0) {
						    NSString *preferencesPath = [paths.firstObject stringByAppendingPathComponent:@"Preferences"];
						    NSString *bundleIdentifier = [[NSBundle mainBundle] bundleIdentifier];
						    NSString *plistPath = [preferencesPath stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.plist", bundleIdentifier]];

						    NSError *error = nil;
						    [[NSFileManager defaultManager] removeItemAtPath:plistPath error:&error];

						    if (!error) {
							    [DYYYUtils showToast:@"抖音設定已清除，應用即將退出"];

							    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
							      exit(0);
							    });
						    } else {
							    [DYYYUtils showToast:[NSString stringWithFormat:@"清除失敗: %@", error.localizedDescription]];
						    }
					    }
					  }];
	      }
	      closeAction:^{
	      }
	      confirmAction:^{
		// 清除插件设置的确认对话框
		[DYYYBottomAlertView showAlertWithTitle:@"清除插件設定"
						message:@"確定要清除所有插件設定嗎？\n這將無法恢復！"
					      avatarURL:nil
				       cancelButtonText:@"取消"
				      confirmButtonText:@"確定"
					   cancelAction:nil
					    closeAction:nil
					  confirmAction:^{
					    // 获取所有以DYYY开头的NSUserDefaults键值并清除
					    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
					    NSDictionary *allDefaults = [defaults dictionaryRepresentation];

					    for (NSString *key in allDefaults.allKeys) {
						    if ([key hasPrefix:@"DYYY"]) {
							    [defaults removeObjectForKey:key];
						    }
					    }
					    [defaults synchronize];
					    [DYYYUtils showToast:@"插件設定已清除，請重啟應用"];
					  }];
	      }];
	};
	[cleanupItems addObject:cleanSettingsItem];

	NSArray<NSString *> *customDirs = @[ @"Application Support/gurd_cache", @"Caches", @"BDByteCast", @"kitelog" ];
	NSString *libraryDir = NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES).firstObject;
    NSMutableArray<NSString *> *allPaths = [NSMutableArray arrayWithObject:[DYYYUtils cacheDirectory]];
	for (NSString *sub in customDirs) {
		NSString *fullPath = [libraryDir stringByAppendingPathComponent:sub];
		if ([[NSFileManager defaultManager] fileExistsAtPath:fullPath]) {
			[allPaths addObject:fullPath];
		}
	}

	AWESettingItemModel *cleanCacheItem = [[%c(AWESettingItemModel) alloc] init];
	__weak AWESettingItemModel *weakCleanCacheItem = cleanCacheItem;	
	cleanCacheItem.identifier = @"DYYYCleanCache";
	cleanCacheItem.title = @"清理快取";
	cleanCacheItem.type = 0;
	cleanCacheItem.svgIconImageName = @"ic_broom_outlined";
	cleanCacheItem.cellType = 26;
	cleanCacheItem.colorStyle = 0;
	cleanCacheItem.isEnable = NO;
	cleanCacheItem.detail = @"計算中...";
	__block unsigned long long initialSize = 0;
	dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
	  for (NSString *basePath in allPaths) {
		  initialSize += [DYYYUtils directorySizeAtPath:basePath];
	  }
	  dispatch_async(dispatch_get_main_queue(), ^{
	    __strong AWESettingItemModel *strongCleanCacheItem = weakCleanCacheItem;
	    if (strongCleanCacheItem) {
		    strongCleanCacheItem.detail = [DYYYUtils formattedSize:initialSize];
		    strongCleanCacheItem.isEnable = YES;
		    [strongCleanCacheItem refreshCell];
	    }
	  });
	});
	cleanCacheItem.cellTappedBlock = ^{
	  __strong AWESettingItemModel *strongCleanCacheItem = weakCleanCacheItem;
	  if (!strongCleanCacheItem || !strongCleanCacheItem.isEnable) {
		  return;
	  }
	  // Disable the button to prevent multiple triggers
	  strongCleanCacheItem.isEnable = NO;
	  strongCleanCacheItem.detail = @"清理中...";
	  [strongCleanCacheItem refreshCell];

	  dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
	    [DYYYUtils clearCacheDirectory];
	    for (NSString *basePath in allPaths) {
		    [DYYYUtils removeAllContentsAtPath:basePath];
	    }

	    unsigned long long afterSize = 0;
	    for (NSString *basePath in allPaths) {
		    afterSize += [DYYYUtils directorySizeAtPath:basePath];
	    }

	    unsigned long long clearedSize = (initialSize > afterSize) ? (initialSize - afterSize) : 0;

	    dispatch_async(dispatch_get_main_queue(), ^{
	      [DYYYUtils showToast:[NSString stringWithFormat:@"已清理 %@ 快取", [DYYYUtils formattedSize:clearedSize]]];

	      strongCleanCacheItem.detail = [DYYYUtils formattedSize:afterSize];
	      // Re-enable the button after cleaning is done
	      strongCleanCacheItem.isEnable = YES;
	      [strongCleanCacheItem refreshCell];
	    });
	  });
	};
	[cleanupItems addObject:cleanCacheItem];

	cleanupSection.itemArray = cleanupItems;

	// 创建关于分类
	AWESettingSectionModel *aboutSection = [[%c(AWESettingSectionModel) alloc] init];
	aboutSection.sectionHeaderTitle = @"關於";
	aboutSection.sectionHeaderHeight = 40;
	aboutSection.type = 0;
	NSMutableArray<AWESettingItemModel *> *aboutItems = [NSMutableArray array];

	// 添加关于
	AWESettingItemModel *aboutItem = [[%c(AWESettingItemModel) alloc] init];
	aboutItem.identifier = @"DYYYAbout";
	aboutItem.title = @"關於插件";
	aboutItem.detail = DYYY_VERSION;
	aboutItem.type = 0;
	aboutItem.iconImageName = @"awe-settings-icon-about";
	aboutItem.cellType = 26;
	aboutItem.colorStyle = 0;
	aboutItem.isEnable = YES;
	aboutItem.cellTappedBlock = ^{
	  [DYYYSettingsHelper showAboutDialog:@"關於DYYY"
				      message:@"版本: " DYYY_VERSION @"\n\n"
					      @"感謝使用DYYY\n\n"
					      @"感謝huami開源\n\n"
					      @"@維他入我心 基於DYYY二次開發\n\n"
					      @"感謝huami group中群友的支援贊助\n\n"
					      @"Telegram @huamidev\n\n"
					      @"Telegram @vita_app\n\n"
					      @"開源地址 huami1314/DYYY\n\n"
					      @"倉庫地址 Wtrwx/DYYY\n\n"
				    onConfirm:nil];
	};
	[aboutItems addObject:aboutItem];

	AWESettingItemModel *licenseItem = [[%c(AWESettingItemModel) alloc] init];
	licenseItem.identifier = @"DYYYLicense";
	licenseItem.title = @"開源協議";
	licenseItem.detail = @"MIT License";
	licenseItem.type = 0;
	licenseItem.iconImageName = @"awe-settings-icon-opensource-notice";
	licenseItem.cellType = 26;
	licenseItem.colorStyle = 0;
	licenseItem.isEnable = YES;
	licenseItem.cellTappedBlock = ^{
	  [DYYYSettingsHelper showAboutDialog:@"MIT License"
				      message:@"Copyright (c) 2024 huami.\n\n"
					      @"Permission is hereby granted, free of charge, to any person obtaining a copy "
					      @"of this software and associated documentation files (the \"Software\"), to deal "
					      @"in the Software without restriction, including without limitation the rights "
					      @"to use, copy, modify, merge, publish, distribute, sublicense, and/or sell "
					      @"copies of the Software, and to permit persons to whom the Software is "
					      @"furnished to do so, subject to the following conditions:\n\n"
					      @"The above copyright notice and this permission notice shall be included in all "
					      @"copies or substantial portions of the Software.\n\n"
					      @"THE SOFTWARE IS PROVIDED \"AS IS\", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR "
					      @"IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, "
					      @"FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE "
					      @"AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER "
					      @"LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, "
					      @"OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE "
					      @"SOFTWARE."
				    onConfirm:nil];
	};
	[aboutItems addObject:licenseItem];
	mainSection.itemArray = mainItems;
	aboutSection.itemArray = aboutItems;

	viewModel.sectionDataArray = @[ mainSection, cleanupSection, backupSection, aboutSection ];
	objc_setAssociatedObject(settingsVC, kViewModelKey, viewModel, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
	[rootVC.navigationController pushViewController:(UIViewController *)settingsVC animated:YES];
}

%hook AWESettingsViewModel
- (NSArray *)sectionDataArray {
	NSArray *originalSections = %orig;
	BOOL sectionExists = NO;
	BOOL isMainSettingsPage = NO;

	// 遍历检查是否已存在DYYY部分
	for (AWESettingSectionModel *section in originalSections) {
		if ([section.sectionHeaderTitle isEqualToString:DYYY_NAME]) {
			sectionExists = YES;
		}
		if ([section.sectionHeaderTitle isEqualToString:@"账号"]) {
			isMainSettingsPage = YES;
		}
	}

	if (isMainSettingsPage && !sectionExists) {
		AWESettingItemModel *dyyyItem = [[%c(AWESettingItemModel) alloc] init];
		dyyyItem.identifier = DYYY_NAME;
		dyyyItem.title = DYYY_NAME;
		dyyyItem.detail = DYYY_VERSION;
		dyyyItem.type = 0;
		dyyyItem.svgIconImageName = @"ic_sapling_outlined";
		dyyyItem.cellType = 26;
		dyyyItem.colorStyle = 2;
		dyyyItem.isEnable = YES;
		dyyyItem.cellTappedBlock = ^{
		  UIViewController *rootVC = self.controllerDelegate;
		  BOOL hasAgreed = [DYYYSettingsHelper getUserDefaults:@"DYYYUserAgreementAccepted"];
		  showDYYYSettingsVC(rootVC, hasAgreed);
		};

		AWESettingSectionModel *newSection = [[%c(AWESettingSectionModel) alloc] init];
		newSection.itemArray = @[ dyyyItem ];
		newSection.type = 0;
		newSection.sectionHeaderHeight = 40;
		newSection.sectionHeaderTitle = @"DYYY";

		NSMutableArray *newSections = [NSMutableArray arrayWithArray:originalSections];
		[newSections insertObject:newSection atIndex:0];
		return newSections;
	}
	return originalSections;
}
%end