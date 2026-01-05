#import "DYYYSettingViewController.h"
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "DYYYConstants.h"

typedef NS_ENUM(NSInteger, DYYYSettingItemType) { DYYYSettingItemTypeSwitch, DYYYSettingItemTypeTextField, DYYYSettingItemTypePicker };

@interface DYYYSettingItem : NSObject

@property(nonatomic, copy) NSString *title;
@property(nonatomic, copy) NSString *key;
@property(nonatomic, assign) DYYYSettingItemType type;
@property(nonatomic, copy, nullable) NSString *placeholder;

+ (instancetype)itemWithTitle:(NSString *)title key:(NSString *)key type:(DYYYSettingItemType)type;
+ (instancetype)itemWithTitle:(NSString *)title key:(NSString *)key type:(DYYYSettingItemType)type placeholder:(nullable NSString *)placeholder;

@end

@implementation DYYYSettingItem

+ (instancetype)itemWithTitle:(NSString *)title key:(NSString *)key type:(DYYYSettingItemType)type {
    return [self itemWithTitle:title key:key type:type placeholder:nil];
}

+ (instancetype)itemWithTitle:(NSString *)title key:(NSString *)key type:(DYYYSettingItemType)type placeholder:(nullable NSString *)placeholder {
    DYYYSettingItem *item = [[DYYYSettingItem alloc] init];
    item.title = title;
    item.key = key;
    item.type = type;
    item.placeholder = placeholder;
    return item;
}

@end

@interface DYYYSettingViewController () <UITableViewDelegate, UITableViewDataSource>

@property(nonatomic, strong) UITableView *tableView;
@property(nonatomic, strong) NSArray<NSArray<DYYYSettingItem *> *> *settingSections;
@property(nonatomic, strong) UILabel *footerLabel;
@property(nonatomic, strong) NSMutableArray<NSString *> *sectionTitles;
@property(nonatomic, strong) NSMutableSet *expandedSections;
@property(nonatomic, strong) UIVisualEffectView *blurEffectView;
@property(nonatomic, strong) UIVisualEffectView *vibrancyEffectView;
@property(nonatomic, assign) BOOL isAgreementShown;

@end

@implementation DYYYSettingViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    self.title = @"DYYY設定";
    self.expandedSections = [NSMutableSet set];
    self.isAgreementShown = NO;

    [self setupAppearance];
    [self setupBlurEffect];
    [self setupTableView];
    [self setupDefaultValues];
    [self setupSettingItems];
    [self setupSectionTitles];
    [self setupFooterLabel];
    [self addTitleGradientAnimation];
}

- (void)setupDefaultValues {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];

    // 如果快捷倍速数值未设置，设置默认值
    if (![defaults objectForKey:@"DYYYSpeedSettings"]) {
        [defaults setObject:@"1.0,1.25,1.5,2.0" forKey:@"DYYYSpeedSettings"];
    }

    // 如果按钮大小未设置，设置默认值
    if (![defaults objectForKey:@"DYYYSpeedButtonSize"]) {
        [defaults setFloat:32.0 forKey:@"DYYYSpeedButtonSize"];
    }

}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];

    if (!self.isAgreementShown) {
        [self checkFirstLaunch];
        self.isAgreementShown = YES;
    }
}

- (void)setupAppearance {
    self.navigationController.navigationBar.barTintColor = [UIColor clearColor];
    self.navigationController.navigationBar.tintColor = [UIColor whiteColor];
    self.navigationController.navigationBar.largeTitleTextAttributes = @{NSForegroundColorAttributeName : [UIColor whiteColor]};
    self.navigationItem.largeTitleDisplayMode = UINavigationItemLargeTitleDisplayModeAlways;
    self.navigationController.navigationBar.prefersLargeTitles = YES;
}

- (void)setupBlurEffect {
    UIBlurEffect *blurEffect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleDark];
    self.blurEffectView = [[UIVisualEffectView alloc] initWithEffect:blurEffect];
    self.blurEffectView.frame = self.view.bounds;
    self.blurEffectView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.view addSubview:self.blurEffectView];

    UIVibrancyEffect *vibrancyEffect = [UIVibrancyEffect effectForBlurEffect:blurEffect];
    self.vibrancyEffectView = [[UIVisualEffectView alloc] initWithEffect:vibrancyEffect];
    self.vibrancyEffectView.frame = self.blurEffectView.bounds;
    self.vibrancyEffectView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.blurEffectView.contentView addSubview:self.vibrancyEffectView];

    UIView *overlayView = [[UIView alloc] initWithFrame:self.view.bounds];
    overlayView.backgroundColor = [UIColor colorWithWhite:0 alpha:0.3];
    overlayView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.view addSubview:overlayView];
}

- (void)setupTableView {
    self.tableView = [[UITableView alloc] initWithFrame:self.view.bounds style:UITableViewStyleInsetGrouped];
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    self.tableView.backgroundColor = [UIColor clearColor];
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    self.tableView.contentInset = UIEdgeInsetsMake(20, 0, 0, 0);
    self.tableView.sectionHeaderTopPadding = 0;
    [self.view addSubview:self.tableView];
}

- (void)setupSettingItems {
    self.settingSections = @[
        @[
            [DYYYSettingItem itemWithTitle:@"影片背景顏色" key:@"DYYYVideoBGColor" type:DYYYSettingItemTypeTextField placeholder:@"十六進位"],
            [DYYYSettingItem itemWithTitle:@"啟用彈幕改色" key:@"DYYYEnableDanmuColor" type:DYYYSettingItemTypeSwitch],
            [DYYYSettingItem itemWithTitle:@"自訂彈幕顏色" key:@"DYYYDanmuColor" type:DYYYSettingItemTypeTextField placeholder:@"十六進位"],
            [DYYYSettingItem itemWithTitle:@"設定預設倍速" key:@"DYYYDefaultSpeed" type:DYYYSettingItemTypePicker],
            [DYYYSettingItem itemWithTitle:@"設定長按倍速" key:@"DYYYLongPressSpeed" type:DYYYSettingItemTypePicker],
            [DYYYSettingItem itemWithTitle:@"上下控制倍速" key:@"DYYYEnableLongPressSpeedGesture" type:DYYYSettingItemTypeSwitch],
            [DYYYSettingItem itemWithTitle:@"顯示進度時長" key:@"DYYYShowScheduleDisplay" type:DYYYSettingItemTypeSwitch],
            [DYYYSettingItem itemWithTitle:@"進度時長樣式" key:@"DYYYScheduleStyle" type:DYYYSettingItemTypeTextField placeholder:@"預設"],
            [DYYYSettingItem itemWithTitle:@"進度縱軸位置" key:@"DYYYTimelineVerticalPosition" type:DYYYSettingItemTypeTextField placeholder:@"-12.5"],
            [DYYYSettingItem itemWithTitle:@"進度標籤顏色" key:@"DYYYProgressLabelColor" type:DYYYSettingItemTypeTextField placeholder:@"十六進位"],
            [DYYYSettingItem itemWithTitle:@"隱藏影片進度" key:@"DYYYHideVideoProgress" type:DYYYSettingItemTypeSwitch],
            [DYYYSettingItem itemWithTitle:@"啟用自動播放" key:@"DYYYEnableAutoPlay" type:DYYYSettingItemTypeSwitch],
            [DYYYSettingItem itemWithTitle:@"推薦過濾直播" key:@"DYYYSkipLive" type:DYYYSettingItemTypeSwitch],
            [DYYYSettingItem itemWithTitle:@"推薦過濾熱點" key:@"DYYYSkipHotSpot" type:DYYYSettingItemTypeSwitch],
            [DYYYSettingItem itemWithTitle:@"推薦過濾低讚" key:@"DYYYFilterLowLikes" type:DYYYSettingItemTypeTextField placeholder:@"填0關閉"],
            [DYYYSettingItem itemWithTitle:@"推薦影片時限" key:@"DYYYFilterTimeLimit" type:DYYYSettingItemTypeTextField placeholder:@"填0關閉，單位為天"],
            [DYYYSettingItem itemWithTitle:@"推薦過濾HDR" key:@"DYYYFilterFeedHDR" type:DYYYSettingItemTypeSwitch],
            [DYYYSettingItem itemWithTitle:@"啟用首頁淨化" key:@"DYYYEnablePure" type:DYYYSettingItemTypeSwitch],
            [DYYYSettingItem itemWithTitle:@"啟用首頁全螢幕" key:@"DYYYEnableFullScreen" type:DYYYSettingItemTypeSwitch],
            [DYYYSettingItem itemWithTitle:@"啟用屏蔽廣告" key:@"DYYYNoAds" type:DYYYSettingItemTypeSwitch],
            [DYYYSettingItem itemWithTitle:@"屏蔽檢測更新" key:@"DYYYNoUpdates" type:DYYYSettingItemTypeSwitch],
            [DYYYSettingItem itemWithTitle:@"去除青少年彈窗" key:@"DYYYHideTeenMode" type:DYYYSettingItemTypeSwitch],
            [DYYYSettingItem itemWithTitle:@"評論區毛玻璃" key:@"DYYYEnableCommentBlur" type:DYYYSettingItemTypeSwitch],
            [DYYYSettingItem itemWithTitle:@"通知玻璃效果" key:@"DYYYEnableNotificationTransparency" type:DYYYSettingItemTypeSwitch],
            [DYYYSettingItem itemWithTitle:@"毛玻璃透明度" key:@"DYYYCommentBlurTransparent" type:DYYYSettingItemTypeTextField placeholder:@"0-1小數"],
            [DYYYSettingItem itemWithTitle:@"通知圓角半徑" key:@"DYYYNotificationCornerRadius" type:DYYYSettingItemTypeTextField placeholder:@"預設12"],
            [DYYYSettingItem itemWithTitle:@"時間屬地顯示" key:@"DYYYEnableArea" type:DYYYSettingItemTypeSwitch],
            [DYYYSettingItem itemWithTitle:@"國外解析帳號" key:@"DYYYGeonamesUsername" type:DYYYSettingItemTypeTextField placeholder:@"不填預設"],
            [DYYYSettingItem itemWithTitle:@"時間標籤顏色" key:@"DYYYLabelColor" type:DYYYSettingItemTypeTextField placeholder:@"十六進位"],
            [DYYYSettingItem itemWithTitle:@"屬地隨機漸變" key:@"DYYYEnableRandomGradient" type:DYYYSettingItemTypeSwitch],
            [DYYYSettingItem itemWithTitle:@"隱藏系統頂欄" key:@"DYYYHideStatusbar" type:DYYYSettingItemTypeSwitch],
            [DYYYSettingItem itemWithTitle:@"關注二次確認" key:@"DYYYFollowTips" type:DYYYSettingItemTypeSwitch],
            [DYYYSettingItem itemWithTitle:@"收藏二次確認" key:@"DYYYCollectTips" type:DYYYSettingItemTypeSwitch],
            [DYYYSettingItem itemWithTitle:@"預設直播畫質" key:@"DYYYLiveQuality" type:DYYYSettingItemTypePicker],
            [DYYYSettingItem itemWithTitle:@"提高影片畫質" key:@"DYYYEnableVideoHighestQuality" type:DYYYSettingItemTypeSwitch],
            [DYYYSettingItem itemWithTitle:@"停用直播PCDN功能" key:@"DYYYDisableLivePCDN" type:DYYYSettingItemTypeSwitch]
        ],
        @[
            [DYYYSettingItem itemWithTitle:@"設定頂欄透明" key:@"DYYYTopBarTransparent" type:DYYYSettingItemTypeTextField placeholder:@"0-1小數"],
            [DYYYSettingItem itemWithTitle:@"設定全局透明" key:@"DYYYGlobalTransparency" type:DYYYSettingItemTypeTextField placeholder:@"0-1小數"],
            [DYYYSettingItem itemWithTitle:@"首頁頭像透明" key:@"DYYYAvatarViewTransparency" type:DYYYSettingItemTypeTextField placeholder:@"0-1小數"],
            [DYYYSettingItem itemWithTitle:@"右側欄縮放度" key:@"DYYYElementScale" type:DYYYSettingItemTypeTextField placeholder:@"不填預設"],
            [DYYYSettingItem itemWithTitle:@"暱稱文案縮放" key:@"DYYYNicknameScale" type:DYYYSettingItemTypeTextField placeholder:@"不填預設"],
            [DYYYSettingItem itemWithTitle:@"暱稱下移距離" key:@"DYYYNicknameVerticalOffset" type:DYYYSettingItemTypeTextField placeholder:@"不填預設"],
            [DYYYSettingItem itemWithTitle:@"文案下移距離" key:@"DYYYDescriptionVerticalOffset" type:DYYYSettingItemTypeTextField placeholder:@"不填預設"],
            [DYYYSettingItem itemWithTitle:@"屬地下移距離" key:@"DYYYIPLabelVerticalOffset" type:DYYYSettingItemTypeTextField placeholder:@"不填預設"],
            [DYYYSettingItem itemWithTitle:@"修改底欄高度" key:@"DYYYTabBarHeight" type:DYYYSettingItemTypeTextField placeholder:@"預設為空"],
            [DYYYSettingItem itemWithTitle:@"設定首頁標題" key:@"DYYYIndexTitle" type:DYYYSettingItemTypeTextField placeholder:@"不填預設"],
            [DYYYSettingItem itemWithTitle:@"設定朋友標題" key:@"DYYYFriendsTitle" type:DYYYSettingItemTypeTextField placeholder:@"不填預設"],
            [DYYYSettingItem itemWithTitle:@"設定訊息標題" key:@"DYYYMsgTitle" type:DYYYSettingItemTypeTextField placeholder:@"不填預設"],
            [DYYYSettingItem itemWithTitle:@"設定我的標題" key:@"DYYYSelfTitle" type:DYYYSettingItemTypeTextField placeholder:@"不填預設"]
        ],
        @[
            [DYYYSettingItem itemWithTitle:@"隱藏全螢幕觀看" key:@"DYYYHideEntry" type:DYYYSettingItemTypeSwitch],
            [DYYYSettingItem itemWithTitle:@"隱藏底欄商城" key:@"DYYYHideShopButton" type:DYYYSettingItemTypeSwitch],
            [DYYYSettingItem itemWithTitle:@"隱藏雙列箭頭" key:@"DYYYHideDoubleColumnEntry" type:DYYYSettingItemTypeSwitch],
            [DYYYSettingItem itemWithTitle:@"隱藏底欄訊息" key:@"DYYYHideMessageButton" type:DYYYSettingItemTypeSwitch],
            [DYYYSettingItem itemWithTitle:@"隱藏底欄朋友" key:@"DYYYHideFriendsButton" type:DYYYSettingItemTypeSwitch],
            [DYYYSettingItem itemWithTitle:@"隱藏底欄我的" key:@"DYYYHideMyButton" type:DYYYSettingItemTypeSwitch],
            [DYYYSettingItem itemWithTitle:@"隱藏底欄加號" key:@"DYYYHidePlusButton" type:DYYYSettingItemTypeSwitch],
            [DYYYSettingItem itemWithTitle:@"隱藏底欄熱榜" key:@"DYYYHideHotSearch" type:DYYYSettingItemTypeSwitch],
            [DYYYSettingItem itemWithTitle:@"隱藏底欄評論" key:@"DYYYHideComment" type:DYYYSettingItemTypeSwitch],
            [DYYYSettingItem itemWithTitle:@"隱藏底欄紅點" key:@"DYYYHideBottomDot" type:DYYYSettingItemTypeSwitch],
            [DYYYSettingItem itemWithTitle:@"隱藏底欄背景" key:@"DYYYHideBottomBg" type:DYYYSettingItemTypeSwitch],
            [DYYYSettingItem itemWithTitle:@"隱藏常用小程序" key:@"DYYYHideSidebarRecentApps" type:DYYYSettingItemTypeSwitch],
            [DYYYSettingItem itemWithTitle:@"隱藏常訪問的人" key:@"DYYYHideSidebarRecentUsers" type:DYYYSettingItemTypeSwitch],
            [DYYYSettingItem itemWithTitle:@"隱藏側欄紅點" key:@"DYYYHideSidebarDot" type:DYYYSettingItemTypeSwitch],
            [DYYYSettingItem itemWithTitle:@"隱藏發作品框" key:@"DYYYHidePostView" type:DYYYSettingItemTypeSwitch],
            [DYYYSettingItem itemWithTitle:@"隱藏頭像加號" key:@"DYYYHideLOTAnimationView" type:DYYYSettingItemTypeSwitch],
            [DYYYSettingItem itemWithTitle:@"移除頭像加號" key:@"DYYYHideFollowPromptView" type:DYYYSettingItemTypeSwitch],
            [DYYYSettingItem itemWithTitle:@"隱藏點讚數值" key:@"DYYYHideLikeLabel" type:DYYYSettingItemTypeSwitch],
            [DYYYSettingItem itemWithTitle:@"隱藏評論數值" key:@"DYYYHideCommentLabel" type:DYYYSettingItemTypeSwitch],
            [DYYYSettingItem itemWithTitle:@"隱藏收藏數值" key:@"DYYYHideCollectLabel" type:DYYYSettingItemTypeSwitch],
            [DYYYSettingItem itemWithTitle:@"隱藏分享數值" key:@"DYYYHideShareLabel" type:DYYYSettingItemTypeSwitch],
            [DYYYSettingItem itemWithTitle:@"隱藏點讚按鈕" key:@"DYYYHideLikeButton" type:DYYYSettingItemTypeSwitch],
            [DYYYSettingItem itemWithTitle:@"隱藏評論按鈕" key:@"DYYYHideCommentButton" type:DYYYSettingItemTypeSwitch],
            [DYYYSettingItem itemWithTitle:@"隱藏收藏按鈕" key:@"DYYYHideCollectButton" type:DYYYSettingItemTypeSwitch],
            [DYYYSettingItem itemWithTitle:@"隱藏頭像按鈕" key:@"DYYYHideAvatarButton" type:DYYYSettingItemTypeSwitch],
            [DYYYSettingItem itemWithTitle:@"隱藏音樂按鈕" key:@"DYYYHideMusicButton" type:DYYYSettingItemTypeSwitch],
            [DYYYSettingItem itemWithTitle:@"隱藏分享按鈕" key:@"DYYYHideShareButton" type:DYYYSettingItemTypeSwitch],
            [DYYYSettingItem itemWithTitle:@"隱藏影片定位" key:@"DYYYHideLocation" type:DYYYSettingItemTypeSwitch],
            [DYYYSettingItem itemWithTitle:@"隱藏右上搜尋" key:@"DYYYHideDiscover" type:DYYYSettingItemTypeSwitch],
            [DYYYSettingItem itemWithTitle:@"隱藏相關搜尋" key:@"DYYYHideInteractionSearch" type:DYYYSettingItemTypeSwitch],
            [DYYYSettingItem itemWithTitle:@"隱藏彈出熱搜" key:@"DYYYHideSearchBubble" type:DYYYSettingItemTypeSwitch],
            [DYYYSettingItem itemWithTitle:@"隱藏搜尋同款" key:@"DYYYHideSearchSame" type:DYYYSettingItemTypeSwitch],
            [DYYYSettingItem itemWithTitle:@"隱藏長框搜尋" key:@"DYYYHideSearchEntrance" type:DYYYSettingItemTypeSwitch],
            [DYYYSettingItem itemWithTitle:@"隱藏進入直播" key:@"DYYYHideEnterLive" type:DYYYSettingItemTypeSwitch],
            [DYYYSettingItem itemWithTitle:@"隱藏評論視圖" key:@"DYYYHideCommentViews" type:DYYYSettingItemTypeSwitch],
            [DYYYSettingItem itemWithTitle:@"隱藏通知提示" key:@"DYYYHidePushBanner" type:DYYYSettingItemTypeSwitch],
            [DYYYSettingItem itemWithTitle:@"隱藏訊息頂欄紅包" key:@"DYYYHideMessageTabRedPacket" type:DYYYSettingItemTypeSwitch],
            [DYYYSettingItem itemWithTitle:@"隱藏頭像列表" key:@"DYYYHideAvatarList" type:DYYYSettingItemTypeSwitch],
            [DYYYSettingItem itemWithTitle:@"隱藏頭像氣泡" key:@"DYYYHideAvatarBubble" type:DYYYSettingItemTypeSwitch],
            [DYYYSettingItem itemWithTitle:@"隱藏左側邊欄" key:@"DYYYHideLeftSideBar" type:DYYYSettingItemTypeSwitch],
            [DYYYSettingItem itemWithTitle:@"隱藏吃喝玩樂" key:@"DYYYHideNearbyCapsuleView" type:DYYYSettingItemTypeSwitch],
            [DYYYSettingItem itemWithTitle:@"隱藏彈幕按鈕" key:@"DYYYHideDanmuButton" type:DYYYSettingItemTypeSwitch],
            [DYYYSettingItem itemWithTitle:@"隱藏取消靜音" key:@"DYYYHideCancelMute" type:DYYYSettingItemTypeSwitch],
            [DYYYSettingItem itemWithTitle:@"隱藏去汽水聽" key:@"DYYYHideQuqishuiting" type:DYYYSettingItemTypeSwitch],
            [DYYYSettingItem itemWithTitle:@"隱藏共創頭像" key:@"DYYYHideGongChuang" type:DYYYSettingItemTypeSwitch],
            [DYYYSettingItem itemWithTitle:@"隱藏熱點提示" key:@"DYYYHideHotspot" type:DYYYSettingItemTypeSwitch],
            [DYYYSettingItem itemWithTitle:@"隱藏推薦提示" key:@"DYYYHideRecommendTips" type:DYYYSettingItemTypeSwitch],
            [DYYYSettingItem itemWithTitle:@"隱藏分享提示" key:@"DYYYHideShareContentView" type:DYYYSettingItemTypeSwitch],
            [DYYYSettingItem itemWithTitle:@"隱藏作者聲明" key:@"DYYYHideAntiAddictedNotice" type:DYYYSettingItemTypeSwitch],
            [DYYYSettingItem itemWithTitle:@"隱藏底部相關" key:@"DYYYHideBottomRelated" type:DYYYSettingItemTypeSwitch],
            [DYYYSettingItem itemWithTitle:@"隱藏影片錨點" key:@"DYYYHideFeedAnchorContainer" type:DYYYSettingItemTypeSwitch],
            [DYYYSettingItem itemWithTitle:@"隱藏挑戰貼紙" key:@"DYYYHideChallengeStickers" type:DYYYSettingItemTypeSwitch],
            [DYYYSettingItem itemWithTitle:@"隱藏圖文標籤" key:@"DYYYHideEditTags" type:DYYYSettingItemTypeSwitch],
            [DYYYSettingItem itemWithTitle:@"隱藏校園提示" key:@"DYYYHideTemplateTags" type:DYYYSettingItemTypeSwitch],
            [DYYYSettingItem itemWithTitle:@"隱藏作者店鋪" key:@"DYYYHideHisShop" type:DYYYSettingItemTypeSwitch],
            [DYYYSettingItem itemWithTitle:@"隱藏頂欄橫線" key:@"DYYYHideTopBarLine" type:DYYYSettingItemTypeSwitch],
            [DYYYSettingItem itemWithTitle:@"隱藏影片合集" key:@"DYYYHideTemplateVideo" type:DYYYSettingItemTypeSwitch],
            [DYYYSettingItem itemWithTitle:@"隱藏短劇合集" key:@"DYYYHideTemplatePlaylet" type:DYYYSettingItemTypeSwitch],
            [DYYYSettingItem itemWithTitle:@"隱藏動圖標籤" key:@"DYYYHideLiveGIF" type:DYYYSettingItemTypeSwitch],
            [DYYYSettingItem itemWithTitle:@"隱藏筆記標籤" key:@"DYYYHideItemTag" type:DYYYSettingItemTypeSwitch],
            [DYYYSettingItem itemWithTitle:@"隱藏底部話題" key:@"DYYYHideTemplateGroup" type:DYYYSettingItemTypeSwitch],
            [DYYYSettingItem itemWithTitle:@"隱藏相機定位" key:@"DYYYHideCameraLocation" type:DYYYSettingItemTypeSwitch],
            [DYYYSettingItem itemWithTitle:@"隱藏影片滑條" key:@"DYYYHideStoryProgressSlide" type:DYYYSettingItemTypeSwitch],
            [DYYYSettingItem itemWithTitle:@"隱藏圖片滑條" key:@"DYYYHideDotsIndicator" type:DYYYSettingItemTypeSwitch],
            [DYYYSettingItem itemWithTitle:@"隱藏分享私訊" key:@"DYYYHidePrivateMessages" type:DYYYSettingItemTypeSwitch],
            [DYYYSettingItem itemWithTitle:@"隱藏暱稱右側" key:@"DYYYHideRightLabel" type:DYYYSettingItemTypeSwitch],
            [DYYYSettingItem itemWithTitle:@"隱藏群聊商店" key:@"DYYYHideGroupShop" type:DYYYSettingItemTypeSwitch],
            [DYYYSettingItem itemWithTitle:@"隱藏直播膠囊" key:@"DYYYHideLiveCapsuleView" type:DYYYSettingItemTypeSwitch],
            [DYYYSettingItem itemWithTitle:@"隱藏關注頂端" key:@"DYYYHideLiveView" type:DYYYSettingItemTypeSwitch],
            [DYYYSettingItem itemWithTitle:@"隱藏關注直播" key:@"DYYYHideConcernCapsuleView" type:DYYYSettingItemTypeSwitch],
            [DYYYSettingItem itemWithTitle:@"隱藏同城頂端" key:@"DYYYHideMenuView" type:DYYYSettingItemTypeSwitch],
            [DYYYSettingItem itemWithTitle:@"隱藏群直播中" key:@"DYYYHideGroupLiveIndicator" type:DYYYSettingItemTypeSwitch],
            [DYYYSettingItem itemWithTitle:@"隱藏聊天底欄" key:@"DYYYHideGroupInputActionBar" type:DYYYSettingItemTypeSwitch],
            [DYYYSettingItem itemWithTitle:@"隱藏新增朋友" key:@"DYYYHideButton" type:DYYYSettingItemTypeSwitch],
            [DYYYSettingItem itemWithTitle:@"隱藏日常按鈕" key:@"DYYYHideFamiliar" type:DYYYSettingItemTypeSwitch],
            [DYYYSettingItem itemWithTitle:@"隱藏直播廣場" key:@"DYYYHideLivePlayground" type:DYYYSettingItemTypeSwitch],
            [DYYYSettingItem itemWithTitle:@"隱藏禮物展館" key:@"DYYYHideGiftPavilion" type:DYYYSettingItemTypeSwitch],
            [DYYYSettingItem itemWithTitle:@"隱藏頂欄紅點" key:@"DYYYHideTopBarBadge" type:DYYYSettingItemTypeSwitch],
            [DYYYSettingItem itemWithTitle:@"隱藏退出清屏" key:@"DYYYHideLiveRoomClear" type:DYYYSettingItemTypeSwitch],
            [DYYYSettingItem itemWithTitle:@"隱藏投屏按鈕" key:@"DYYYHideLiveRoomMirroring" type:DYYYSettingItemTypeSwitch],
            [DYYYSettingItem itemWithTitle:@"隱藏直播發現" key:@"DYYYHideLiveDiscovery" type:DYYYSettingItemTypeSwitch],
            [DYYYSettingItem itemWithTitle:@"隱藏直播點歌" key:@"DYYYHideKTVSongIndicator" type:DYYYSettingItemTypeSwitch],
            [DYYYSettingItem itemWithTitle:@"隱藏流量提醒" key:@"DYYYHideCellularAlert" type:DYYYSettingItemTypeSwitch],
            [DYYYSettingItem itemWithTitle:@"隱藏紅包懸浮" key:@"DYYYHidePendantGroup" type:DYYYSettingItemTypeSwitch],
            [DYYYSettingItem itemWithTitle:@"隱藏章節進度" key:@"DYYYHideChapterProgress" type:DYYYSettingItemTypeSwitch],
            [DYYYSettingItem itemWithTitle:@"隱藏鍵盤AI" key:@"DYYYHideKeyboardAI" type:DYYYSettingItemTypeSwitch],
            [DYYYSettingItem itemWithTitle:@"隱藏上次看到" key:@"DYYYHidePopover" type:DYYYSettingItemTypeSwitch],
            [DYYYSettingItem itemWithTitle:@"隱藏展開漸變" key:@"DYYYHideGradient" type:DYYYSettingItemTypeSwitch],
            [DYYYSettingItem itemWithTitle:@"隱藏關閉按鈕" key:@"DYYYHideLiveRoomClose" type:DYYYSettingItemTypeSwitch],
            [DYYYSettingItem itemWithTitle:@"隱藏橫屏按鈕" key:@"DYYYHideLiveRoomFullscreen" type:DYYYSettingItemTypeSwitch],
            [DYYYSettingItem itemWithTitle:@"隱藏返回按鈕" key:@"DYYYHideBack" type:DYYYSettingItemTypeSwitch],
            [DYYYSettingItem itemWithTitle:@"隱藏商品資訊" key:@"DYYYHideLiveGoodsMsg" type:DYYYSettingItemTypeSwitch],
            [DYYYSettingItem itemWithTitle:@"隱藏點讚動畫" key:@"DYYYHideLiveLikeAnimation" type:DYYYSettingItemTypeSwitch],
            [DYYYSettingItem itemWithTitle:@"隱藏輸入掃碼" key:@"DYYYHideScancode" type:DYYYSettingItemTypeSwitch],
            [DYYYSettingItem itemWithTitle:@"隱藏私訊回覆" key:@"DYYYHideReply" type:DYYYSettingItemTypeSwitch],
            [DYYYSettingItem itemWithTitle:@"隱藏暫停相關" key:@"DYYYHidePauseVideoRelatedWord" type:DYYYSettingItemTypeSwitch]
        ],
        @[
            [DYYYSettingItem itemWithTitle:@"移除推薦" key:@"DYYYHideHotContainer" type:DYYYSettingItemTypeSwitch],
            [DYYYSettingItem itemWithTitle:@"移除關注" key:@"DYYYHideFollow" type:DYYYSettingItemTypeSwitch],
            [DYYYSettingItem itemWithTitle:@"移除精選" key:@"DYYYHideMediumVideo" type:DYYYSettingItemTypeSwitch],
            [DYYYSettingItem itemWithTitle:@"移除商城" key:@"DYYYHideMall" type:DYYYSettingItemTypeSwitch],
            [DYYYSettingItem itemWithTitle:@"移除朋友" key:@"DYYYHideFriend" type:DYYYSettingItemTypeSwitch],
            [DYYYSettingItem itemWithTitle:@"移除同城" key:@"DYYYHideNearby" type:DYYYSettingItemTypeSwitch],
            [DYYYSettingItem itemWithTitle:@"移除團購" key:@"DYYYHideGroupon" type:DYYYSettingItemTypeSwitch],
            [DYYYSettingItem itemWithTitle:@"移除直播" key:@"DYYYHideTabLive" type:DYYYSettingItemTypeSwitch],
            [DYYYSettingItem itemWithTitle:@"移除熱點" key:@"DYYYHidePadHot" type:DYYYSettingItemTypeSwitch],
            [DYYYSettingItem itemWithTitle:@"移除經驗" key:@"DYYYHideHangout" type:DYYYSettingItemTypeSwitch],
            [DYYYSettingItem itemWithTitle:@"移除短劇" key:@"DYYYHidePlaylet" type:DYYYSettingItemTypeSwitch],
            [DYYYSettingItem itemWithTitle:@"移除看劇" key:@"DYYYHideCinema" type:DYYYSettingItemTypeSwitch],
            [DYYYSettingItem itemWithTitle:@"移除少兒" key:@"DYYYHideKidsV2" type:DYYYSettingItemTypeSwitch],
            [DYYYSettingItem itemWithTitle:@"移除遊戲" key:@"DYYYHideGame" type:DYYYSettingItemTypeSwitch],
            [DYYYSettingItem itemWithTitle:@"移除長影片" key:@"DYYYHideMediumVideo" type:DYYYSettingItemTypeSwitch]
        ],
        @[
            [DYYYSettingItem itemWithTitle:@"隱藏面板日常" key:@"DYYYHidePanelDaily" type:DYYYSettingItemTypeSwitch],
            [DYYYSettingItem itemWithTitle:@"隱藏面板推薦" key:@"DYYYHidePanelRecommend" type:DYYYSettingItemTypeSwitch],
            [DYYYSettingItem itemWithTitle:@"隱藏面板舉報" key:@"DYYYHidePanelReport" type:DYYYSettingItemTypeSwitch],
            [DYYYSettingItem itemWithTitle:@"隱藏面板倍速" key:@"DYYYHidePanelSpeed" type:DYYYSettingItemTypeSwitch],
            [DYYYSettingItem itemWithTitle:@"隱藏面板清屏" key:@"DYYYHidePanelClearScreen" type:DYYYSettingItemTypeSwitch],
            [DYYYSettingItem itemWithTitle:@"隱藏面板緩存" key:@"DYYYHidePanelFavorite" type:DYYYSettingItemTypeSwitch],
            [DYYYSettingItem itemWithTitle:@"隱藏面板投屏" key:@"DYYYHidePanelCast" type:DYYYSettingItemTypeSwitch],
            [DYYYSettingItem itemWithTitle:@"隱藏面板彈幕" key:@"DYYYHidePanelSubtitle" type:DYYYSettingItemTypeSwitch],
            [DYYYSettingItem itemWithTitle:@"隱藏面板識圖" key:@"DYYYHidePanelSearchImage" type:DYYYSettingItemTypeSwitch],
            [DYYYSettingItem itemWithTitle:@"隱藏面板聽抖音" key:@"DYYYHidePanelListenDouyin" type:DYYYSettingItemTypeSwitch],
            [DYYYSettingItem itemWithTitle:@"隱藏電腦Pad打開" key:@"DYYYHidePanelOpenInPC" type:DYYYSettingItemTypeSwitch],
            [DYYYSettingItem itemWithTitle:@"隱藏面板稍後再看" key:@"DYYYHidePanelLater" type:DYYYSettingItemTypeSwitch],
            [DYYYSettingItem itemWithTitle:@"隱藏面板自動連播" key:@"DYYYHidePanelAutoPlay" type:DYYYSettingItemTypeSwitch],
            [DYYYSettingItem itemWithTitle:@"隱藏面板不感興趣" key:@"DYYYHidePanelNotInterested" type:DYYYSettingItemTypeSwitch],
            [DYYYSettingItem itemWithTitle:@"隱藏面板後台播放" key:@"DYYYHidePanelBackgroundPlay" type:DYYYSettingItemTypeSwitch],
            [DYYYSettingItem itemWithTitle:@"隱藏面板定時關閉" key:@"DYYYHidePanelTimerClose" type:DYYYSettingItemTypeSwitch],
            [DYYYSettingItem itemWithTitle:@"隱藏雙列快捷入口" key:@"DYYYHidePanelBiserial" type:DYYYSettingItemTypeSwitch],
            [DYYYSettingItem itemWithTitle:@"隱藏評論分享" key:@"DYYYHideCommentShareToFriends" type:DYYYSettingItemTypeSwitch],
            [DYYYSettingItem itemWithTitle:@"隱藏評論複製" key:@"DYYYHideCommentLongPressCopy" type:DYYYSettingItemTypeSwitch],
            [DYYYSettingItem itemWithTitle:@"隱藏評論儲存" key:@"DYYYHideCommentLongPressSaveImage" type:DYYYSettingItemTypeSwitch],
            [DYYYSettingItem itemWithTitle:@"隱藏評論舉報" key:@"DYYYHideCommentLongPressReport" type:DYYYSettingItemTypeSwitch],
            [DYYYSettingItem itemWithTitle:@"隱藏評論搜尋" key:@"DYYYHideCommentLongPressSearch" type:DYYYSettingItemTypeSwitch],
            [DYYYSettingItem itemWithTitle:@"隱藏評論轉發日常" key:@"DYYYHideCommentLongPressDaily" type:DYYYSettingItemTypeSwitch],
            [DYYYSettingItem itemWithTitle:@"隱藏評論影片回覆" key:@"DYYYHideCommentLongPressVideoReply" type:DYYYSettingItemTypeSwitch],
            [DYYYSettingItem itemWithTitle:@"隱藏評論識別圖片" key:@"DYYYHideCommentLongPressPictureSearch" type:DYYYSettingItemTypeSwitch]
        ],
        @[
            [DYYYSettingItem itemWithTitle:@"啟用新版長按面板" key:@"DYYYEnableModernPanel" type:DYYYSettingItemTypeSwitch],
            [DYYYSettingItem itemWithTitle:@"長按面板玻璃效果" key:@"DYYYLongPressPanelBlur" type:DYYYSettingItemTypeSwitch],
            [DYYYSettingItem itemWithTitle:@"長按面板深色模式" key:@"DYYYLongPressPanelDark" type:DYYYSettingItemTypeSwitch],
            [DYYYSettingItem itemWithTitle:@"儲存面板玻璃效果" key:@"DYYYEnableSheetBlur" type:DYYYSettingItemTypeSwitch],
            [DYYYSettingItem itemWithTitle:@"面板毛玻璃透明度" key:@"DYYYSheetBlurTransparent" type:DYYYSettingItemTypeTextField placeholder:@"0-1小數"],
            [DYYYSettingItem itemWithTitle:@"長按面板儲存影片" key:@"DYYYLongPressSaveVideo" type:DYYYSettingItemTypeSwitch],
            [DYYYSettingItem itemWithTitle:@"長按面板儲存封面" key:@"DYYYLongPressSaveCover" type:DYYYSettingItemTypeSwitch],
            [DYYYSettingItem itemWithTitle:@"長按面板儲存音訊" key:@"DYYYLongPressSaveAudio" type:DYYYSettingItemTypeSwitch],
            [DYYYSettingItem itemWithTitle:@"長按面板儲存圖片" key:@"DYYYLongPressSaveCurrentImage" type:DYYYSettingItemTypeSwitch],
            [DYYYSettingItem itemWithTitle:@"長按儲存所有圖片" key:@"DYYYLongPressSaveAllImages" type:DYYYSettingItemTypeSwitch],
            [DYYYSettingItem itemWithTitle:@"長按面板生成影片" key:@"DYYYLongPressCreateVideo" type:DYYYSettingItemTypeSwitch],
            [DYYYSettingItem itemWithTitle:@"長按面板複製文案" key:@"DYYYLongPressCopyText" type:DYYYSettingItemTypeSwitch],
            [DYYYSettingItem itemWithTitle:@"長按面板複製連結" key:@"DYYYLongPressCopyLink" type:DYYYSettingItemTypeSwitch],
            [DYYYSettingItem itemWithTitle:@"長按面板接口解析" key:@"DYYYLongPressApiDownload" type:DYYYSettingItemTypeSwitch],
            [DYYYSettingItem itemWithTitle:@"長按面板定時關閉" key:@"DYYYLongPressTimerClose" type:DYYYSettingItemTypeSwitch],
            [DYYYSettingItem itemWithTitle:@"長按面板過濾文案" key:@"DYYYLongPressFilterTitle" type:DYYYSettingItemTypeSwitch],
            [DYYYSettingItem itemWithTitle:@"長按面板過濾作者" key:@"DYYYLongPressFilterUser" type:DYYYSettingItemTypeSwitch],
            [DYYYSettingItem itemWithTitle:@"雙擊面板儲存影片" key:@"DYYYDoubleTapDownload" type:DYYYSettingItemTypeSwitch],
            [DYYYSettingItem itemWithTitle:@"雙擊面板儲存音訊" key:@"DYYYDoubleTapDownloadAudio" type:DYYYSettingItemTypeSwitch],
            [DYYYSettingItem itemWithTitle:@"雙擊面板接口解析" key:@"DYYYDoubleInterfaceDownload" type:DYYYSettingItemTypeSwitch],
            [DYYYSettingItem itemWithTitle:@"雙擊面板製作影片" key:@"DYYYDoubleCreateVideo" type:DYYYSettingItemTypeSwitch],
            [DYYYSettingItem itemWithTitle:@"雙擊面板複製文案" key:@"DYYYDoubleTapCopyDesc" type:DYYYSettingItemTypeSwitch],
            [DYYYSettingItem itemWithTitle:@"雙擊面板開啟評論" key:@"DYYYDoubleTapComment" type:DYYYSettingItemTypeSwitch],
            [DYYYSettingItem itemWithTitle:@"雙擊面板點讚影片" key:@"DYYYDoubleTapLike" type:DYYYSettingItemTypeSwitch],
            [DYYYSettingItem itemWithTitle:@"雙擊面板分享影片" key:@"DYYYDoubleTapshowSharePanel" type:DYYYSettingItemTypeSwitch],
            [DYYYSettingItem itemWithTitle:@"雙擊面板長按面板" key:@"DYYYDoubleTapshowDislikeOnVideo" type:DYYYSettingItemTypeSwitch]
        ],
        @[
            [DYYYSettingItem itemWithTitle:@"啟用雙擊開啟評論" key:@"DYYYEnableDoubleOpenComment" type:DYYYSettingItemTypeSwitch],
            [DYYYSettingItem itemWithTitle:@"啟用雙擊開啟選單" key:@"DYYYEnableDoubleTapMenu" type:DYYYSettingItemTypeSwitch],
            [DYYYSettingItem itemWithTitle:@"啟用自動勾選原圖" key:@"DYYYAutoSelectOriginalPhoto" type:DYYYSettingItemTypeSwitch],
            [DYYYSettingItem itemWithTitle:@"資料預設進入作品" key:@"DYYYDefaultEnterWorks" type:DYYYSettingItemTypeSwitch],
            [DYYYSettingItem itemWithTitle:@"停用自動進入直播" key:@"DYYYDisableAutoEnterLive" type:DYYYSettingItemTypeSwitch],
            [DYYYSettingItem itemWithTitle:@"左側邊欄快捷入口" key:@"DYYYEntrance" type:DYYYSettingItemTypeSwitch],
            [DYYYSettingItem itemWithTitle:@"接口解析儲存媒體" key:@"DYYYInterfaceDownload" type:DYYYSettingItemTypeTextField placeholder:@"不填關閉"],
            [DYYYSettingItem itemWithTitle:@"接口顯示清晰選項" key:@"DYYYShowAllVideoQuality" type:DYYYSettingItemTypeSwitch],
            [DYYYSettingItem itemWithTitle:@"移除評論實況水印" key:@"DYYYCommentLivePhotoNotWaterMark" type:DYYYSettingItemTypeSwitch],
            [DYYYSettingItem itemWithTitle:@"移除評論圖片水印" key:@"DYYYCommentNotWaterMark" type:DYYYSettingItemTypeSwitch],
            [DYYYSettingItem itemWithTitle:@"停用點擊首頁刷新" key:@"DYYYDisableHomeRefresh" type:DYYYSettingItemTypeSwitch],
            [DYYYSettingItem itemWithTitle:@"停用雙擊影片點讚" key:@"DYYYDisableDoubleTapLike" type:DYYYSettingItemTypeSwitch],
            [DYYYSettingItem itemWithTitle:@"啟用儲存他人頭像" key:@"DYYYEnableSaveAvatar" type:DYYYSettingItemTypeSwitch],
            [DYYYSettingItem itemWithTitle:@"儲存評論區表情包" key:@"DYYYForceDownloadEmotion" type:DYYYSettingItemTypeSwitch],
            [DYYYSettingItem itemWithTitle:@"儲存預覽頁表情包" key:@"DYYYForceDownloadPreviewEmotion" type:DYYYSettingItemTypeSwitch],
            [DYYYSettingItem itemWithTitle:@"儲存聊天頁表情包" key:@"DYYYForceDownloadIMEmotion" type:DYYYSettingItemTypeSwitch],
            [DYYYSettingItem itemWithTitle:@"長按評論複製評論" key:@"DYYYCommentCopyText" type:DYYYSettingItemTypeSwitch],
            [DYYYSettingItem itemWithTitle:@"長按簡介複製簡介" key:@"DYYYBioCopyText" type:DYYYSettingItemTypeSwitch],
            [DYYYSettingItem itemWithTitle:@"長按文案複製文案" key:@"DYYYLongPressCopyTextEnabled" type:DYYYSettingItemTypeSwitch],
            [DYYYSettingItem itemWithTitle:@"下載完成震動回饋" key:@"DYYYHapticFeedbackEnabled" type:DYYYSettingItemTypeSwitch]
        ],
        @[
            [DYYYSettingItem itemWithTitle:@"啟用快捷倍速按鈕" key:@"DYYYEnableFloatSpeedButton" type:DYYYSettingItemTypeSwitch],
            [DYYYSettingItem itemWithTitle:@"快捷倍速數值設定" key:@"DYYYSpeedSettings" type:DYYYSettingItemTypeTextField placeholder:@"逗號分隔"],
            [DYYYSettingItem itemWithTitle:@"自動恢復預設倍速" key:@"DYYYAutoRestoreSpeed" type:DYYYSettingItemTypeSwitch],
            [DYYYSettingItem itemWithTitle:@"倍速按鈕顯示後綴" key:@"DYYYSpeedButtonShowX" type:DYYYSettingItemTypeSwitch],
            [DYYYSettingItem itemWithTitle:@"快捷倍速按鈕大小" key:@"DYYYSpeedButtonSize" type:DYYYSettingItemTypeTextField placeholder:@"預設32"],
            [DYYYSettingItem itemWithTitle:@"啟用一鍵清屏按鈕" key:@"DYYYEnableFloatClearButton" type:DYYYSettingItemTypeSwitch],
            [DYYYSettingItem itemWithTitle:@"快捷清屏按鈕大小" key:@"DYYYEnableFloatClearButtonSize" type:DYYYSettingItemTypeTextField placeholder:@"預設40"],
            [DYYYSettingItem itemWithTitle:@"清屏隱藏彈幕" key:@"DYYYHideDanmaku" type:DYYYSettingItemTypeSwitch],
            [DYYYSettingItem itemWithTitle:@"清屏移除時間進度" key:@"DYYYRemoveTimeProgress" type:DYYYSettingItemTypeSwitch],
            [DYYYSettingItem itemWithTitle:@"清屏隱藏時間進度" key:@"DYYYHideTimeProgress" type:DYYYSettingItemTypeSwitch],
            [DYYYSettingItem itemWithTitle:@"清屏隱藏滑條" key:@"DYYYHideSlider" type:DYYYSettingItemTypeSwitch],
            [DYYYSettingItem itemWithTitle:@"清屏隱藏底欄" key:@"DYYYHideTabBar" type:DYYYSettingItemTypeSwitch],
            [DYYYSettingItem itemWithTitle:@"清屏隱藏倍速" key:@"DYYYHideSpeed" type:DYYYSettingItemTypeSwitch]
        ]
    ];
}

- (void)setupSectionTitles {
    self.sectionTitles = [@[ @"基本設定", @"介面設定", @"隱藏設定", @"頂欄移除", @"隱藏面板", @"面板設定", @"功能設定", @"懸浮按鈕" ] mutableCopy];
}

- (void)setupFooterLabel {
    self.footerLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, self.view.bounds.size.width, 50)];
    self.footerLabel.text = [NSString stringWithFormat:@"Developer By @huamidev\nVersion: %@ (%@)", DYYY_VERSION, @"260104"];
    self.footerLabel.textAlignment = NSTextAlignmentCenter;
    self.footerLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightRegular];
    self.footerLabel.textColor = [UIColor colorWithRed:173 / 255.0 green:216 / 255.0 blue:230 / 255.0 alpha:1.0];
    self.footerLabel.numberOfLines = 2;
    self.footerLabel.lineBreakMode = NSLineBreakByWordWrapping;
    self.tableView.tableFooterView = self.footerLabel;
}

- (void)addTitleGradientAnimation {
    CAGradientLayer *gradient = [CAGradientLayer layer];
    gradient.colors = @[ (__bridge id)[UIColor systemRedColor].CGColor, (__bridge id)[UIColor systemBlueColor].CGColor ];
    gradient.startPoint = CGPointMake(0, 0);
    gradient.endPoint = CGPointMake(1, 0);
    gradient.frame = CGRectMake(0, 0, 150, 30);

    UIView *titleView = [[UIView alloc] initWithFrame:gradient.frame];
    [titleView.layer addSublayer:gradient];

    UILabel *titleLabel = [[UILabel alloc] initWithFrame:titleView.bounds];
    titleLabel.text = self.title;
    titleLabel.textAlignment = NSTextAlignmentCenter;
    titleLabel.font = [UIFont boldSystemFontOfSize:20];
    titleLabel.textColor = [UIColor clearColor];

    gradient.mask = titleLabel.layer;
    self.navigationItem.titleView = titleView;

    CABasicAnimation *colorChange = [CABasicAnimation animationWithKeyPath:@"colors"];
    colorChange.toValue = @[ (__bridge id)[UIColor systemYellowColor].CGColor, (__bridge id)[UIColor systemGreenColor].CGColor ];
    colorChange.duration = 2.0;
    colorChange.autoreverses = YES;
    colorChange.repeatCount = HUGE_VALF;

    [gradient addAnimation:colorChange forKey:@"colorChangeAnimation"];
}

#pragma mark - Helper Methods

- (NSArray *)optionsForKey:(NSString *)key {
    if ([key isEqualToString:@"DYYYDefaultSpeed"] || [key isEqualToString:@"DYYYLongPressSpeed"]) {
        // 倍速选项
        return @[ @0.75, @1.0, @1.25, @1.5, @2.0, @2.5, @3.0 ];
    } else if ([key isEqualToString:@"DYYYLiveQuality"]) {
        // 直播清晰度选项
        return @[ @"藍光幀彩", @"藍光", @"超清", @"高清", @"標清", @"自動" ];
    }
    return @[];
}

- (NSString *)displayValueForKey:(NSString *)key value:(id)value {
    if ([key isEqualToString:@"DYYYDefaultSpeed"] || [key isEqualToString:@"DYYYLongPressSpeed"]) {
        // 倍速显示格式
        float speedValue = [value floatValue];
        return [NSString stringWithFormat:@"%.2f", speedValue];
    } else if ([key isEqualToString:@"DYYYLiveQuality"]) {
        // 直播清晰度直接显示
        return value ?: @"自動";
    }
    return [NSString stringWithFormat:@"%@", value];
}

- (id)defaultValueForKey:(NSString *)key {
    if ([key isEqualToString:@"DYYYDefaultSpeed"] || [key isEqualToString:@"DYYYLongPressSpeed"]) {
        return @1.0;
    } else if ([key isEqualToString:@"DYYYLiveQuality"]) {
        return @"自動";
    }
    return nil;
}

#pragma mark - First Launch Agreement

- (void)checkFirstLaunch {
    BOOL hasAgreed = [[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYUserAgreementAccepted"];

    if (!hasAgreed) {
        dispatch_async(dispatch_get_main_queue(), ^{
          [self showAgreementAlert];
        });
    }
}

- (void)showAgreementAlert {
    UIAlertController *alertController =
        [UIAlertController alertControllerWithTitle:@"使用者協議"
                                            message:@"本插件為開源專案\n僅供學習交流用途\n如有侵權請聯繫, GitHub 倉庫：huami1314/DYYY\n請遵守當地法律法規, "
                                                    @"逆向工程僅為學習目的\n盜用原碼進行商業用途/發布但未標記開源專案必究\n詳情請參閱專案內 MIT 許可證\n\n請輸入\"我已閱讀並同意繼續使用\"以繼續使用"
                                     preferredStyle:UIAlertControllerStyleAlert];

    [alertController addTextFieldWithConfigurationHandler:^(UITextField *_Nonnull textField) {
      textField.clearButtonMode = UITextFieldViewModeWhileEditing;
    }];

    UIAlertAction *confirmAction = [UIAlertAction actionWithTitle:@"確認"
                                                            style:UIAlertActionStyleDefault
                                                          handler:^(UIAlertAction *_Nonnull action) {
                                                            UITextField *textField = alertController.textFields.firstObject;
                                                            NSString *inputText = textField.text;

                                                            if ([inputText isEqualToString:@"我已閱讀並同意繼續使用"]) {
                                                                [[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"DYYYUserAgreementAccepted"];
                                                            } else {
                                                                UIAlertController *errorAlert = [UIAlertController alertControllerWithTitle:@"輸入錯誤"
                                                                                                                                    message:@"請正確輸入"
                                                                                                                             preferredStyle:UIAlertControllerStyleAlert];

                                                                UIAlertAction *okAction = [UIAlertAction actionWithTitle:@"確定"
                                                                                                                   style:UIAlertActionStyleDefault
                                                                                                                 handler:^(UIAlertAction *_Nonnull action) {
                                                                                                                   [self showAgreementAlert];
                                                                                                                 }];

                                                                [errorAlert addAction:okAction];
                                                                [self presentViewController:errorAlert animated:YES completion:nil];
                                                            }
                                                          }];

    UIAlertAction *exitAction = [UIAlertAction actionWithTitle:@"退出"
                                                         style:UIAlertActionStyleDestructive
                                                       handler:^(UIAlertAction *_Nonnull action) {
                                                         exit(0);
                                                       }];

    [alertController addAction:confirmAction];
    [alertController addAction:exitAction];

    [self presentViewController:alertController animated:YES completion:nil];
}

#pragma mark - UITableViewDataSource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return self.settingSections.count;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    switch (section) {
        case 0:
            return @"基本設定";
        case 1:
            return @"介面設定";
        case 2:
            return @"隱藏設定";
        case 3:
            return @"頂欄移除";
        case 4:
            return @"隱藏面板";
        case 5:
            return @"面板設定";
        case 6:
            return @"功能設定";
        case 7:
            return @"懸浮按鈕";
        default:
            return @"";
    }
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section {
    UIView *headerView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, tableView.bounds.size.width, 44)];

    UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(15, 0, headerView.bounds.size.width - 50, 44)];
    titleLabel.text = [self tableView:tableView titleForHeaderInSection:section];
    titleLabel.textColor = [UIColor whiteColor];
    titleLabel.font = [UIFont systemFontOfSize:16 weight:UIFontWeightMedium];
    [headerView addSubview:titleLabel];

    UIImageView *arrowImageView = [[UIImageView alloc] initWithFrame:CGRectMake(titleLabel.frame.origin.x + titleLabel.frame.size.width - 30, 15, 14, 14)];
    arrowImageView.image = [UIImage systemImageNamed:[self.expandedSections containsObject:@(section)] ? @"chevron.down" : @"chevron.right"];
    arrowImageView.tintColor = [UIColor lightGrayColor];
    arrowImageView.tag = 100;
    arrowImageView.contentMode = UIViewContentModeScaleAspectFit;
    [headerView addSubview:arrowImageView];

    UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
    button.frame = headerView.bounds;
    button.tag = section;
    [button addTarget:self action:@selector(headerTapped:) forControlEvents:UIControlEventTouchUpInside];
    [headerView addSubview:button];

    return headerView;
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
    return 44;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [self.expandedSections containsObject:@(section)] ? self.settingSections[section].count : 0;
}

- (void)toggleSection:(UIButton *)sender {
    NSNumber *section = @(sender.tag);
    if ([self.expandedSections containsObject:section]) {
        [self.expandedSections removeObject:section];
    } else {
        [self.expandedSections addObject:section];
    }

    [self.tableView reloadSections:[NSIndexSet indexSetWithIndex:sender.tag] withRowAnimation:UITableViewRowAnimationFade];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    DYYYSettingItem *item = self.settingSections[indexPath.section][indexPath.row];

    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"SettingCell"];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"SettingCell"];
        cell.textLabel.translatesAutoresizingMaskIntoConstraints = NO;
        [cell.textLabel.leadingAnchor constraintEqualToAnchor:cell.contentView.leadingAnchor constant:16].active = YES;
        [cell.textLabel.centerYAnchor constraintEqualToAnchor:cell.contentView.centerYAnchor].active = YES;

        UIView *selectedBackgroundView = [[UIView alloc] init];
        selectedBackgroundView.backgroundColor = [UIColor colorWithRed:84 / 255.0 green:84 / 255.0 blue:84 / 255.0 alpha:1.0];
        cell.selectedBackgroundView = selectedBackgroundView;
    }

    cell.textLabel.text = item.title;
    cell.textLabel.textColor = [UIColor whiteColor];
    cell.backgroundColor = [UIColor colorWithWhite:1 alpha:0.1];

    cell.backgroundView = nil;

    if (indexPath.row == [self.settingSections[indexPath.section] count] - 1) {
        cell.layer.cornerRadius = 10;
        cell.layer.maskedCorners = kCALayerMinXMaxYCorner | kCALayerMaxXMaxYCorner;
        cell.layer.masksToBounds = YES;
    } else {
        cell.layer.cornerRadius = 0;
        cell.layer.maskedCorners = 0;
    }

    if (item.type == DYYYSettingItemTypeSwitch) {
        UISwitch *switchView = [[UISwitch alloc] init];
        [switchView setOn:[[NSUserDefaults standardUserDefaults] boolForKey:item.key]];
        [switchView addTarget:self action:@selector(switchToggled:) forControlEvents:UIControlEventValueChanged];
        switchView.tag = indexPath.section * 1000 + indexPath.row;
        cell.accessoryView = switchView;
    } else if (item.type == DYYYSettingItemTypeTextField) {
        UITextField *textField = [[UITextField alloc] initWithFrame:CGRectMake(0, 0, 100, 30)];
        textField.borderStyle = UITextBorderStyleRoundedRect;
        textField.placeholder = item.placeholder;
        textField.attributedPlaceholder = [[NSAttributedString alloc] initWithString:item.placeholder attributes:@{NSForegroundColorAttributeName : [UIColor lightGrayColor]}];
        textField.text = [[NSUserDefaults standardUserDefaults] objectForKey:item.key];
        textField.textAlignment = NSTextAlignmentRight;
        textField.backgroundColor = [UIColor colorWithWhite:1 alpha:0.1];
        textField.textColor = [UIColor whiteColor];

        [textField addTarget:self action:@selector(textFieldDidChange:) forControlEvents:UIControlEventEditingDidEnd];
        textField.tag = indexPath.section * 1000 + indexPath.row;
        cell.accessoryView = textField;
    } else if (item.type == DYYYSettingItemTypePicker) {
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;

        UILabel *pickerLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 80, 44)];
        // 获取当前值
        id currentValue = [[NSUserDefaults standardUserDefaults] objectForKey:item.key];
        if (!currentValue) {
            currentValue = [self defaultValueForKey:item.key];
        }

        pickerLabel.text = [self displayValueForKey:item.key value:currentValue];
        pickerLabel.textColor = [UIColor whiteColor];
        pickerLabel.textAlignment = NSTextAlignmentRight;
        pickerLabel.tag = indexPath.section * 1000 + indexPath.row;

        // 添加垂直居中约束
        pickerLabel.translatesAutoresizingMaskIntoConstraints = NO;
        UIView *containerView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 80, 44)];
        [containerView addSubview:pickerLabel];

        [NSLayoutConstraint activateConstraints:@[
            [pickerLabel.centerYAnchor constraintEqualToAnchor:containerView.centerYAnchor], [pickerLabel.leadingAnchor constraintEqualToAnchor:containerView.leadingAnchor],
            [pickerLabel.trailingAnchor constraintEqualToAnchor:containerView.trailingAnchor]
        ]];

        cell.accessoryView = containerView;
    }

    return cell;
}

- (void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath {
    CGFloat sectionInset = 16;
    cell.contentView.frame = UIEdgeInsetsInsetRect(cell.contentView.frame, UIEdgeInsetsMake(0, sectionInset, 0, sectionInset));
}

#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    DYYYSettingItem *item = self.settingSections[indexPath.section][indexPath.row];
    if (item.type == DYYYSettingItemTypePicker) {
        [self showUniversalPickerForIndexPath:indexPath];
    }
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
}

- (void)showUniversalPickerForIndexPath:(NSIndexPath *)indexPath {
    DYYYSettingItem *item = self.settingSections[indexPath.section][indexPath.row];

    UIAlertController *alert = [UIAlertController alertControllerWithTitle:[NSString stringWithFormat:@"選擇%@", item.title] message:nil preferredStyle:UIAlertControllerStyleActionSheet];

    NSArray *options = [self optionsForKey:item.key];
    for (id option in options) {
        NSString *title = [self displayValueForKey:item.key value:option];
        UIAlertAction *action = [UIAlertAction actionWithTitle:title
                                                         style:UIAlertActionStyleDefault
                                                       handler:^(UIAlertAction *_Nonnull action) {
                                                         // 保存到对应的key
                                                         [[NSUserDefaults standardUserDefaults] setObject:option forKey:item.key];

                                                         // 更新对应的cell显示
                                                         UITableViewCell *cell = [self.tableView cellForRowAtIndexPath:indexPath];
                                                         UIView *containerView = cell.accessoryView;
                                                         if (containerView && containerView.subviews.count > 0) {
                                                             UILabel *pickerLabel = (UILabel *)containerView.subviews.firstObject;
                                                             if ([pickerLabel isKindOfClass:[UILabel class]]) {
                                                                 pickerLabel.text = [self displayValueForKey:item.key value:option];
                                                             }
                                                         }
                                                       }];
        [alert addAction:action];
    }

    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil];
    [alert addAction:cancelAction];

    if (UIDevice.currentDevice.userInterfaceIdiom == UIUserInterfaceIdiomPad) {
        UITableViewCell *selectedCell = [self.tableView cellForRowAtIndexPath:indexPath];
        alert.popoverPresentationController.sourceView = selectedCell;
        alert.popoverPresentationController.sourceRect = selectedCell.bounds;
    }

    [self presentViewController:alert animated:YES completion:nil];
}

#pragma mark - Actions

- (void)switchToggled:(UISwitch *)sender {
    NSIndexPath *indexPath = [NSIndexPath indexPathForRow:sender.tag % 1000 inSection:sender.tag / 1000];
    DYYYSettingItem *item = self.settingSections[indexPath.section][indexPath.row];
    [[NSUserDefaults standardUserDefaults] setBool:sender.isOn forKey:item.key];
}

- (void)textFieldDidChange:(UITextField *)textField {
    NSIndexPath *indexPath = [NSIndexPath indexPathForRow:textField.tag % 1000 inSection:textField.tag / 1000];
    DYYYSettingItem *item = self.settingSections[indexPath.section][indexPath.row];
    [[NSUserDefaults standardUserDefaults] setObject:textField.text forKey:item.key];
}

- (void)headerTapped:(UIButton *)sender {
    NSNumber *section = @(sender.tag);
    if ([self.expandedSections containsObject:section]) {
        [self.expandedSections removeObject:section];
    } else {
        [self.expandedSections addObject:section];
    }

    UIView *headerView = [self.tableView headerViewForSection:sender.tag];
    UIImageView *arrowImageView = [headerView viewWithTag:100];

    [UIView animateWithDuration:0.3
                     animations:^{
                       arrowImageView.image = [UIImage systemImageNamed:[self.expandedSections containsObject:section] ? @"chevron.down" : @"chevron.right"];
                     }];

    [self.tableView reloadSections:[NSIndexSet indexSetWithIndex:sender.tag] withRowAnimation:UITableViewRowAnimationFade];
}

@end