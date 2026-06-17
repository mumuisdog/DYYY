/*
 * Tweak Name: 1KeyHideDYUI
 * Target App: com.ss.iphone.ugc.Aweme
 * Dev: @c00kiec00k 曲奇的坏品味🍻
 * iOS Version: 16.5
 */
#import "DYYYFloatSpeedButton.h"
#import "DYYYFloatClearButton.h"
#import "DYYYUtils.h"
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <float.h>
#import <math.h>
#import <objc/runtime.h>
#import <signal.h>

void updateClearButtonVisibility(void);
void showClearButton(void);
void hideClearButton(void);

BOOL isInPlayInteractionVC = NO;
BOOL isPureViewVisible = NO;
BOOL clearButtonForceHidden = NO;
BOOL isAppActive = YES;
BOOL dyyyIsPerformingFloatClearOperation = NO;

static NSInteger dyyyClearButtonMutationDepth = 0;

static inline void DYYYBeginClearButtonMutation(void) {
    dyyyClearButtonMutationDepth++;
    dyyyIsPerformingFloatClearOperation = YES;
}

static inline void DYYYEndClearButtonMutation(void) {
    if (dyyyClearButtonMutationDepth > 0) {
        dyyyClearButtonMutationDepth--;
    }
    dyyyIsPerformingFloatClearOperation = dyyyClearButtonMutationDepth > 0;
}

static void DYYYPerformClearButtonMutation(dispatch_block_t block) {
    if (!block) {
        return;
    }
    DYYYBeginClearButtonMutation();
    @try {
        block();
    } @finally {
        DYYYEndClearButtonMutation();
    }
}


HideUIButton *hideButton = nil;
BOOL isAppInTransition = NO;
NSArray *targetClassNames;
static NSUInteger dyyyTargetClassConfiguration = NSUIntegerMax;

typedef NS_ENUM(NSInteger, DYYYClearProgressMode) {
    DYYYClearProgressModeNone = 0,
    DYYYClearProgressModeRemove,
    DYYYClearProgressModeHide,
};

static char dyyyProgressModeKey;
static char dyyyProgressOriginalHiddenKey;
static char dyyyProgressOriginalInteractionKey;
static char dyyyProgressOriginalLayerOpacityKey;

static DYYYClearProgressMode DYYYCurrentClearProgressMode(void) {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    if ([defaults boolForKey:@"DYYYRemoveTimeProgress"]) {
        return DYYYClearProgressModeRemove;
    }
    if ([defaults boolForKey:@"DYYYHideTimeProgress"]) {
        return DYYYClearProgressModeHide;
    }
    return DYYYClearProgressModeNone;
}

static BOOL DYYYIsClearProgressView(UIView *view) {
    static NSArray<NSString *> *classNames;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
      classNames = @[
          @"AWEPlayInteractionProgressContainerView",
          @"AWEDPlayerProgressContainerView",
          @"AWEFeedProgressSlider",
          @"AWEFeedProgressSliderForLongPress",
          @"AWEFakeProgressSliderView",
          @"AWEProgressContainerView",
          @"AWEProgressPlayBackSlider",
      ];
    });

    for (NSString *className in classNames) {
        Class progressClass = NSClassFromString(className);
        if (progressClass && [view isKindOfClass:progressClass]) {
            return YES;
        }
    }
    return NO;
}

static void DYYYRestoreClearProgressViewState(UIView *view) {
    NSNumber *appliedMode = objc_getAssociatedObject(view, &dyyyProgressModeKey);
    if (!appliedMode) {
        return;
    }

    NSNumber *originalLayerOpacity = objc_getAssociatedObject(view, &dyyyProgressOriginalLayerOpacityKey);
    if (originalLayerOpacity) {
        view.layer.opacity = originalLayerOpacity.floatValue;
    }

    if (appliedMode.integerValue == DYYYClearProgressModeRemove) {
        NSNumber *originalHidden = objc_getAssociatedObject(view, &dyyyProgressOriginalHiddenKey);
        NSNumber *originalInteraction = objc_getAssociatedObject(view, &dyyyProgressOriginalInteractionKey);
        if (originalHidden) {
            view.hidden = originalHidden.boolValue;
        }
        if (originalInteraction) {
            view.userInteractionEnabled = originalInteraction.boolValue;
        }
    }

    objc_setAssociatedObject(view, &dyyyProgressModeKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(view, &dyyyProgressOriginalHiddenKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(view, &dyyyProgressOriginalInteractionKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(view, &dyyyProgressOriginalLayerOpacityKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

static void DYYYApplyClearProgressViewState(UIView *view, DYYYClearProgressMode mode) {
    NSNumber *appliedMode = objc_getAssociatedObject(view, &dyyyProgressModeKey);
    if (appliedMode && appliedMode.integerValue != mode) {
        DYYYRestoreClearProgressViewState(view);
        appliedMode = nil;
    }

    if (mode == DYYYClearProgressModeNone) {
        DYYYRestoreClearProgressViewState(view);
        return;
    }

    if (!appliedMode) {
        objc_setAssociatedObject(view, &dyyyProgressModeKey, @(mode), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        objc_setAssociatedObject(view, &dyyyProgressOriginalLayerOpacityKey, @(view.layer.opacity), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        if (mode == DYYYClearProgressModeRemove) {
            objc_setAssociatedObject(view, &dyyyProgressOriginalHiddenKey, @(view.hidden), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            objc_setAssociatedObject(view, &dyyyProgressOriginalInteractionKey, @(view.userInteractionEnabled), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        }
    }

    view.layer.opacity = 0.0f;
    if (mode == DYYYClearProgressModeRemove) {
        view.hidden = YES;
        view.userInteractionEnabled = NO;
    }
}

void DYYYApplyFloatClearProgressStateToView(UIView *view) {
    if (!view || !DYYYIsClearProgressView(view)) {
        return;
    }
    DYYYClearProgressMode mode = hideButton.isElementsHidden ? DYYYCurrentClearProgressMode() : DYYYClearProgressModeNone;
    DYYYApplyClearProgressViewState(view, mode);
}

static void findViewsOfClassHelper(UIView *view, Class viewClass, NSMutableArray *result) {
    if ([view isKindOfClass:viewClass]) {
        [result addObject:view];
    }
    for (UIView *subview in view.subviews) {
        findViewsOfClassHelper(subview, viewClass, result);
    }
}
UIWindow *getKeyWindow(void) {
    UIWindow *activeWindow = [DYYYUtils getActiveWindow];
    if (activeWindow) {
        return activeWindow;
    }

    UIWindow *keyWindow = nil;
    for (UIWindow *window in [UIApplication sharedApplication].windows) {
        if (window.isKeyWindow) {
            keyWindow = window;
            break;
        }
    }
    return keyWindow;
}

static void DYYYApplyClearButtonHiddenState(HideUIButton *button, BOOL hidden) {
    if (!button) {
        return;
    }
    void (^applyBlock)(HideUIButton *) = ^(HideUIButton *target) {
        if (!target) {
            return;
        }
        if (target.hidden != hidden) {
            target.hidden = hidden;
        }
    };

    if ([NSThread isMainThread]) {
        applyBlock(button);
    } else {
        __weak HideUIButton *weakButton = button;
        dispatch_async(dispatch_get_main_queue(), ^{
            applyBlock(weakButton);
        });
    }
}

static BOOL DYYYShouldHideClearButton(void) {
    BOOL clearModeActive = (hideButton && hideButton.isElementsHidden);
    if (clearModeActive) {
        if (!isAppActive) {
            return YES;
        }
        return clearButtonForceHidden;
    }
    if (!isAppActive) {
        return YES;
    }
    if (!dyyyInteractionViewVisible) {
        return YES;
    }
    if (dyyyCommentViewVisible) {
        return YES;
    }
    if (isPureViewVisible) {
        return YES;
    }
    if (clearButtonForceHidden) {
        return YES;
    }
    return NO;
}

void updateClearButtonVisibility() {
    if (!hideButton) {
        return;
    }
    DYYYApplyClearButtonHiddenState(hideButton, DYYYShouldHideClearButton());
}

void showClearButton(void) {
    clearButtonForceHidden = NO;
    updateClearButtonVisibility(); // Call the central visibility logic
}

void hideClearButton(void) {
    clearButtonForceHidden = YES;
    updateClearButtonVisibility();
}

static void forceResetAllUIElements(void) {
    DYYYPerformClearButtonMutation(^{
        initTargetClassNames();
        Class StackViewClass = NSClassFromString(@"AWEElementStackView");
        for (UIWindow *window in [UIApplication sharedApplication].windows) {
            for (NSString *className in targetClassNames) {
                Class viewClass = NSClassFromString(className);
                if (!viewClass)
                    continue;
                NSMutableArray *views = [NSMutableArray array];
                findViewsOfClassHelper(window, viewClass, views);
                for (UIView *view in views) {
                    if ([view isKindOfClass:StackViewClass]) {
                        view.alpha = 1.0; // 基础透明度交给全局透明度处理，避免重复乘
                    } else {
                        view.alpha = 1.0; // 恢复透明度
                    }
                }
            }
        }
    });
}
static void reapplyHidingToAllElements(HideUIButton *button) {
    if (!button || !button.isElementsHidden)
        return;
    [button hideUIElements];
}
void initTargetClassNames(void) {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSUInteger configuration = 0;
    configuration |= [defaults boolForKey:@"DYYYHideTabBar"] ? (1U << 0) : 0;
    configuration |= [defaults boolForKey:@"DYYYHideDanmaku"] ? (1U << 1) : 0;
    configuration |= [defaults boolForKey:@"DYYYHideSlider"] ? (1U << 2) : 0;
    configuration |= [defaults boolForKey:@"DYYYHideChapter"] ? (1U << 3) : 0;
    if (targetClassNames && dyyyTargetClassConfiguration == configuration) {
        return;
    }

    NSMutableArray<NSString *> *list = [@[
        @"AWEHPTopBarCTAContainer", @"AWEHPDiscoverFeedEntranceView", @"AWELeftSideBarEntranceView", @"DUXBadge", @"AWEBaseElementView", @"AWEElementStackView", @"AWEPlayInteractionDescriptionLabel",
        @"AWEUserNameLabel", @"ACCEditTagStickerView", @"AWEFeedTemplateAnchorView", @"AWESearchFeedTagView", @"AWEPlayInteractionSearchAnchorView", @"AFDRecommendToFriendTagView",
        @"AWELandscapeFeedEntryView", @"AWEFeedAnchorContainerView", @"AFDAIbumFolioView", @"DUXPopover", @"AWEMixVideoPanelMoreView", @"AWEHotSearchInnerBottomView", @"AWEHPSegmentControlScrollView"
    ] mutableCopy];
    if (configuration & (1U << 0)) {
        [list addObject:@"AWENormalModeTabBar"];
    }
    if (configuration & (1U << 1)) {
        [list addObject:@"AWEVideoPlayDanmakuContainerView"];
        [list addObject:@"AWEDanmakuContainerView"];
    }
    if (configuration & (1U << 2)) {
        [list addObject:@"AWEStoryProgressSlideView"];
        [list addObject:@"AWEStoryProgressContainerView"];
    }
    if (configuration & (1U << 3)) {
        [list addObject:@"AWEDemaciaChapterProgressSlider"];
    }

    targetClassNames = [list copy];
    dyyyTargetClassConfiguration = configuration;
}

void reloadClearButtonConfiguration(void) {
    if (![NSThread isMainThread]) {
        dispatch_async(dispatch_get_main_queue(), ^{
          reloadClearButtonConfiguration();
        });
        return;
    }

    initTargetClassNames();

    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    BOOL isEnabled = [defaults boolForKey:@"DYYYEnableFloatClearButton"];
    if (!isEnabled) {
        if (hideButton) {
            if (hideButton.isElementsHidden) {
                [hideButton safeResetState];
            }
            [hideButton removeFromSuperview];
            hideButton = nil;
        }
        return;
    }

    UIWindow *activeWindow = [DYYYUtils getActiveWindow];
    if (!activeWindow) {
        return;
    }

    CGFloat buttonSize = [defaults floatForKey:@"DYYYEnableFloatClearButtonSize"];
    if (buttonSize <= 0.0) {
        buttonSize = 40.0;
    }
    buttonSize = MIN(MAX(buttonSize, 20.0), 60.0);

    if (!hideButton) {
        hideButton = [[HideUIButton alloc] initWithFrame:CGRectMake(0, 0, buttonSize, buttonSize)];
    } else if (fabs(hideButton.bounds.size.width - buttonSize) > FLT_EPSILON) {
        hideButton.bounds = CGRectMake(0, 0, buttonSize, buttonSize);
        hideButton.layer.cornerRadius = buttonSize / 2.0;
    }

    if (![hideButton isDescendantOfView:activeWindow]) {
        [activeWindow addSubview:hideButton];
        [hideButton loadSavedPosition];
    }

    [activeWindow bringSubviewToFront:hideButton];
    if (hideButton.isElementsHidden) {
        [hideButton hideUIElements];
    }
    updateClearButtonVisibility();
}
@implementation HideUIButton
- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.accessibilityLabel = @"DYYYClearScreenButton";
        self.backgroundColor = [UIColor clearColor];
        self.layer.cornerRadius = frame.size.width / 2;
        self.layer.masksToBounds = YES;
        self.isElementsHidden = NO;
        self.hiddenViewsList = [NSMutableArray array];

        self.originalAlpha = 1.0;
        self.alpha = 0.5;
        
        [self loadLockState];
        [self loadIcons];
        [self setImage:self.showIcon forState:UIControlStateNormal];
        
        UIPanGestureRecognizer *panGesture = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePan:)];
        [self addGestureRecognizer:panGesture];
        
        [self addTarget:self action:@selector(handleTap) forControlEvents:UIControlEventTouchUpInside];
        [self addTarget:self action:@selector(handleTouchDown) forControlEvents:UIControlEventTouchDown];
        [self addTarget:self action:@selector(handleTouchUpInside) forControlEvents:UIControlEventTouchUpInside];
        [self addTarget:self action:@selector(handleTouchUpOutside) forControlEvents:UIControlEventTouchUpOutside];
        
        UILongPressGestureRecognizer *longPressGesture = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(handleLongPress:)];
        [self addGestureRecognizer:longPressGesture];
        
        [self startPeriodicCheck];
        [self resetFadeTimer];

        // Start as hidden, will be shown by updateClearButtonVisibility if conditions are met
        self.hidden = YES;
    }
    return self;
}

- (void)didMoveToSuperview {
    [super didMoveToSuperview];
    if (self.superview) {
        [self loadSavedPosition];
    }
}

- (void)didMoveToWindow {
    [super didMoveToWindow];
    if (!self.window) {
        [self stopTimers];
        return;
    }
    [self startPeriodicCheck];
    [self resetFadeTimer];
}

- (void)startPeriodicCheck {
    if (self.checkTimer) {
        [self.checkTimer invalidate];
        self.checkTimer = nil;
    }
    __weak __typeof(self) weakSelf = self;
    NSTimer *timer = [NSTimer scheduledTimerWithTimeInterval:0.2
                                                    repeats:YES
                                                      block:^(NSTimer *timer) {
                                                        __strong __typeof(weakSelf) strongSelf = weakSelf;
                                                        if (!strongSelf) {
                                                            return;
                                                        }
                                                        if (strongSelf.isElementsHidden) {
                                                            [strongSelf hideUIElements];
                                                        }
                                                      }];
    self.checkTimer = timer;
}

- (void)resetFadeTimer {
    if (self.fadeTimer) {
        [self.fadeTimer invalidate];
        self.fadeTimer = nil;
    }
    __weak __typeof(self) weakSelf = self;
    NSTimer *fadeTimer = [NSTimer scheduledTimerWithTimeInterval:3.0
                                                         repeats:NO
                                                           block:^(NSTimer *timer) {
                                                             __strong __typeof(weakSelf) strongSelf = weakSelf;
                                                             if (!strongSelf) {
                                                                 return;
                                                             }
                                                             [UIView animateWithDuration:0.3
                                                                              animations:^{
                                                                                strongSelf.alpha = 0.5;
                                                                              }];
                                                             strongSelf.fadeTimer = nil;
                                                           }];
    self.fadeTimer = fadeTimer;
    if (self.alpha != self.originalAlpha) {
        [UIView animateWithDuration:0.2
                         animations:^{
                           self.alpha = self.originalAlpha;
                         }];
    }
}

- (void)stopTimers {
    if (self.checkTimer) {
        [self.checkTimer invalidate];
        self.checkTimer = nil;
    }
    if (self.fadeTimer) {
        [self.fadeTimer invalidate];
        self.fadeTimer = nil;
    }
}

- (void)saveButtonPosition {
    if (self.superview) {
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        CGFloat centerXPercent = self.center.x / self.superview.bounds.size.width;
        CGFloat centerYPercent = self.center.y / self.superview.bounds.size.height;
        
        [defaults setFloat:centerXPercent forKey:@"DYYYHideButtonCenterXPercent"];
        [defaults setFloat:centerYPercent forKey:@"DYYYHideButtonCenterYPercent"];
    }
}

- (void)loadSavedPosition {
    if (!self.superview) {
        return;
    }
    
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    float centerXPercent = [defaults floatForKey:@"DYYYHideButtonCenterXPercent"];
    float centerYPercent = [defaults floatForKey:@"DYYYHideButtonCenterYPercent"];
    
    if (centerXPercent > 0 && centerYPercent > 0) {
        self.center = CGPointMake(centerXPercent * self.superview.bounds.size.width,
                                  centerYPercent * self.superview.bounds.size.height);
    } else {
        self.center = CGPointMake(self.superview.bounds.size.width / 2.0f,
                                  self.superview.bounds.size.height / 3.0f);
    }
}

- (void)saveLockState {
    [[NSUserDefaults standardUserDefaults] setBool:self.isLocked forKey:@"DYYYHideUIButtonLockState"];
}

- (void)loadLockState {
    self.isLocked = [[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYHideUIButtonLockState"];
}

- (void)loadIcons {
    NSString *documentsPath = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).firstObject;
    NSString *iconPath = [documentsPath stringByAppendingPathComponent:@"DYYY/qingping.gif"];
    NSData *gifData = [NSData dataWithContentsOfFile:iconPath];

    NSArray<UIImage *> *frames = nil;
    CGFloat totalDuration = 0.0;
    BOOL hasFrames = gifData.length > 0 &&
                     [DYYYUtils framesFromAnimatedData:gifData
                                                scale:[UIScreen mainScreen].scale
                                               images:&frames
                                        totalDuration:&totalDuration];

    if (hasFrames && frames.count > 0) {
        UIImageView *animatedImageView = [[UIImageView alloc] initWithFrame:self.bounds];
        animatedImageView.animationImages = frames;
        animatedImageView.animationDuration = totalDuration;
        animatedImageView.animationRepeatCount = 0;
        [self addSubview:animatedImageView];

        animatedImageView.translatesAutoresizingMaskIntoConstraints = NO;
        [NSLayoutConstraint activateConstraints:@[
            [animatedImageView.centerXAnchor constraintEqualToAnchor:self.centerXAnchor], [animatedImageView.centerYAnchor constraintEqualToAnchor:self.centerYAnchor],
            [animatedImageView.widthAnchor constraintEqualToAnchor:self.widthAnchor], [animatedImageView.heightAnchor constraintEqualToAnchor:self.heightAnchor]
        ]];

        [animatedImageView startAnimating];
        return;
    }

    [self setTitle:@"隐藏" forState:UIControlStateNormal];
    [self setTitle:@"显示" forState:UIControlStateSelected];
    self.titleLabel.font = [UIFont systemFontOfSize:10];
}

- (void)handleTouchDown {
    if ([self dyyy_isInSelfHiddenState]) {
        return;
    }
    [self resetFadeTimer];
}

- (void)handleTouchUpInside {
    if ([self dyyy_isInSelfHiddenState]) {
        return;
    }
    [self resetFadeTimer];
}

- (void)handleTouchUpOutside {
    if ([self dyyy_isInSelfHiddenState]) {
        return;
    }
    [self resetFadeTimer];
}

- (UIViewController *)findViewController:(UIView *)view {
    __weak UIResponder *responder = view;
    while (responder) {
        if ([responder isKindOfClass:[UIViewController class]]) {
            return (UIViewController *)responder;
        }
        responder = [responder nextResponder];
        if (!responder)
            break;
    }
    return nil;
}

- (void)handlePan:(UIPanGestureRecognizer *)gesture {
    if (self.isLocked)
        return;

    [self resetFadeTimer];
    CGPoint translation = [gesture translationInView:self.superview];
    CGPoint newCenter = CGPointMake(self.center.x + translation.x, self.center.y + translation.y);
    newCenter.x = MAX(self.frame.size.width / 2, MIN(newCenter.x, self.superview.frame.size.width - self.frame.size.width / 2));
    newCenter.y = MAX(self.frame.size.height / 2, MIN(newCenter.y, self.superview.frame.size.height - self.frame.size.height / 2));
    self.center = newCenter;
    [gesture setTranslation:CGPointZero inView:self.superview];

    if (gesture.state == UIGestureRecognizerStateEnded || gesture.state == UIGestureRecognizerStateCancelled) {
        [self saveButtonPosition];
    }
}

- (BOOL)dyyy_shouldSelfHideOnClear {
    return [[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYHideClearButtonOnTap"];
}

- (BOOL)dyyy_isInSelfHiddenState {
    return self.isElementsHidden && [self dyyy_shouldSelfHideOnClear];
}

- (void)dyyy_applySelfHiddenAlpha {
    if (self.fadeTimer) {
        [self.fadeTimer invalidate];
        self.fadeTimer = nil;
    }
    // alpha 必须 > 0.01 才能继续接收 hit-test，0.02 在动态背景下几乎不可见
    self.alpha = 0.02;
}

- (void)handleTap {
    if (isAppInTransition)
        return;

    BOOL selfHide = [self dyyy_shouldSelfHideOnClear];
    BOOL willEnterHidden = !self.isElementsHidden;
    // 仅在不会进入“按钮自隐藏”状态时才重置淡出动画
    if (!(selfHide && willEnterHidden)) {
        [self resetFadeTimer];
    }

    if (!self.isElementsHidden) {
        // 调试：进入清屏前快照完整视图树，用于定位未知视图类名（如暂停按钮等）
        [DYYYUtils dumpAllWindowsViewTreeToFile:@"/var/mobile/douyin_view_tree.txt"];

        initTargetClassNames();
        [self hideUIElements];
        self.isElementsHidden = YES;
        self.selected = YES;

        BOOL hideSpeed = [[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYHideSpeed"];
        if (hideSpeed) {
            hideSpeedButton();
        }

        if (selfHide) {
            [self dyyy_applySelfHiddenAlpha];
        }
    } else {
        self.isElementsHidden = NO;
        forceResetAllUIElements();
        [self restoreAWEPlayInteractionProgressContainerView];
        [self.hiddenViewsList removeAllObjects];
        self.selected = NO;

        BOOL hideSpeed = [[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYHideSpeed"];
        if (hideSpeed) {
            showSpeedButton();
            // 退出清屏时主动刷新一次：清屏期间可能发生过 PlayInteractionVC 的 viewDidDisappear，
            // 导致 dyyyInteractionViewVisible 被置 NO，此时仅靠 showSpeedButton() 无法让倍速按钮重新出现，
            // 必须重新从当前可见 controller 备份状态。
            DYYYRefreshFloatSpeedButton();
        }

        // 退出清屏，恢复正常透明度并重启淡出
        self.alpha = self.originalAlpha;
        [self resetFadeTimer];
    }
}

- (void)restoreAWEPlayInteractionProgressContainerView {
    DYYYPerformClearButtonMutation(^{
        for (UIWindow *window in [UIApplication sharedApplication].windows) {
            [self recursivelyRestoreAWEPlayInteractionProgressContainerViewInView:window];
        }
    });
}

- (void)recursivelyRestoreAWEPlayInteractionProgressContainerViewInView:(UIView *)view {
    if (DYYYIsClearProgressView(view)) {
        DYYYRestoreClearProgressViewState(view);
    }

    for (UIView *subview in view.subviews) {
        [self recursivelyRestoreAWEPlayInteractionProgressContainerViewInView:subview];
    }
}
- (void)handleLongPress:(UILongPressGestureRecognizer *)gesture {
    if (gesture.state == UIGestureRecognizerStateBegan) {
        [self resetFadeTimer];
        self.isLocked = !self.isLocked;
        [self saveLockState];
        NSString *toastMessage = self.isLocked ? @"按钮已锁定" : @"按钮已解锁";
        [DYYYUtils showToast:toastMessage];
        if (@available(iOS 10.0, *)) {
            UIImpactFeedbackGenerator *generator = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight];
            [generator prepare];
            [generator impactOccurred];
        }
    }
}
- (void)hideUIElements {
    DYYYPerformClearButtonMutation(^{
        initTargetClassNames();
        [self.hiddenViewsList removeAllObjects];
        [self findAndHideViews:targetClassNames];
        [self hideAWEPlayInteractionProgressContainerView];
        self.isElementsHidden = YES;
        // self.hidden should be managed by updateClearButtonVisibility
        updateClearButtonVisibility();
        if (self.superview) {
            [self.superview bringSubviewToFront:self];
        }
    });
}

- (void)hideAWEPlayInteractionProgressContainerView {
    for (UIWindow *window in [UIApplication sharedApplication].windows) {
        [self recursivelyHideAWEPlayInteractionProgressContainerViewInView:window];
    }
}

- (void)recursivelyHideAWEPlayInteractionProgressContainerViewInView:(UIView *)view {
    if (DYYYIsClearProgressView(view)) {
        DYYYApplyClearProgressViewState(view, DYYYCurrentClearProgressMode());
        [self.hiddenViewsList addObject:view];
    }

    for (UIView *subview in view.subviews) {
        [self recursivelyHideAWEPlayInteractionProgressContainerViewInView:subview];
    }
}
- (void)findAndHideViews:(NSArray *)classNames {
    for (UIWindow *window in [UIApplication sharedApplication].windows) {
        for (NSString *className in classNames) {
            Class viewClass = NSClassFromString(className);
            if (!viewClass)
                continue;
            NSMutableArray *views = [NSMutableArray array];
            findViewsOfClassHelper(window, viewClass, views);
            for (UIView *view in views) {
                if ([view isKindOfClass:[UIView class]]) {
                    if (view == self)
                        continue;
                    if ([view isKindOfClass:NSClassFromString(@"AWELeftSideBarEntranceView")]) {
                        UIViewController *controller = [self findViewController:view];
                        if (![controller isKindOfClass:NSClassFromString(@"AWEFeedContainerViewController")]) {
                            continue;
                        }
                    }
                    [self.hiddenViewsList addObject:view];
                    view.alpha = 0.0;
                }
            }
        }
    }
}
- (void)safeResetState {
    self.isElementsHidden = NO;
    forceResetAllUIElements();
    [self restoreAWEPlayInteractionProgressContainerView];
    [self.hiddenViewsList removeAllObjects];
    self.selected = NO;

    if (self.superview) {
        [self.superview bringSubviewToFront:self];
    }

    BOOL hideSpeed = [[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYHideSpeed"];
    if (hideSpeed) {
        showSpeedButton();
    }

    // 切场景/重置状态时，确保按钮自隐藏 alpha 也被恢复，避免按钮一直处于近乎透明的状态
    if (self.alpha < 0.1) {
        self.alpha = self.originalAlpha;
        [self resetFadeTimer];
    }
}
- (void)dealloc {
    [self stopTimers];
}
@end
