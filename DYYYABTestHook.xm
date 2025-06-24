#import "DYYYABTestHook.h"
#import <objc/runtime.h>

@interface AWEABTestManager : NSObject
@property(retain, nonatomic) NSMutableDictionary *consistentABTestDic;
@property(copy, nonatomic) NSDictionary *abTestData;
@property(copy, nonatomic) NSDictionary *performanceReversalDic;
@property(nonatomic) BOOL performanceReversalEnabled;
@property(nonatomic) BOOL handledNetFirstBackNotification;
@property(nonatomic) BOOL lastUpdateByIncrement;
@property(nonatomic) BOOL shouldPrintLog;
@property(nonatomic) BOOL localABSettingEnabled;
- (void)fetchConfiguration:(id)arg1;
- (void)fetchConfigurationWithRetry:(BOOL)arg1 completion:(id)arg2;
- (void)incrementalUpdateData:(id)arg1 unchangedKeyList:(id)arg2;
- (void)overrideABTestData:(id)arg1 needCleanCache:(BOOL)arg2;
- (void)setAbTestData:(id)arg1;
- (void)_saveABTestData:(id)arg1;
- (id)getValueOfConsistentABTestWithKey:(id)arg1;
+ (id)sharedManager;
@end

static BOOL s_dataLoaded = NO;
static BOOL s_abTestBlockEnabled = NO;
static NSDictionary *s_localABTestData = nil;
static NSDictionary *s_appliedFixedABTestData = nil;
static dispatch_once_t s_loadOnceToken;

@implementation DYYYABTestHook

/**
 * 判斷目前是否為覆寫模式
 * 透過DYYYABTestModeString判斷，返回YES表示覆寫模式，NO表示替換模式
 * 转换为类方法
 */
+ (BOOL)isPatchMode {
    NSString *savedMode = [[NSUserDefaults standardUserDefaults] objectForKey:@"DYYYABTestModeString"];
    return ![savedMode isEqualToString:@"替換模式：忽略原設定，寫入新數據"];
}

/**
 * 获取本地文件是否已加载的状态
 * 转换为类方法
 */
+ (BOOL)isLocalConfigLoaded {
    return s_dataLoaded;
}

/**
 * 获取禁止下发配置的状态
 * 新增类方法
 */
+ (BOOL)isABTestBlockEnabled {
    return s_abTestBlockEnabled;
}

/**
 * 设置禁止下发配置的状态
 * 转换为类方法
 */
+ (void)setABTestBlockEnabled:(BOOL)enabled {
    s_abTestBlockEnabled = enabled;
}

/**
 * 清除本地加载的ABTest数据，为下次调用 loadLocalABTestConfig 做准备
 * 新增类方法
 */
+ (void)cleanLocalABTestData {
    s_appliedFixedABTestData = nil;
    s_localABTestData = nil;
    s_dataLoaded = NO;
    s_loadOnceToken = 0;
    NSLog(@"[DYYY] 本機ABTest設定已清除");
}

/**
 * 加载本地ABTest配置文件
 * 只加载文件和处理数据，不负责应用
 * 使用 dispatch_once 确保只加载一次
 * 转换为类方法
 */
+ (void)loadLocalABTestConfig {
    dispatch_once(&s_loadOnceToken, ^{
        // 取得儲存路徑
        NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
        NSString *documentsDirectory = [paths firstObject];
        NSString *dyyyFolderPath = [documentsDirectory stringByAppendingPathComponent:@"DYYY"];
        NSString *jsonFilePath = [dyyyFolderPath stringByAppendingPathComponent:@"abtest_data_fixed.json"];

        // 確保目錄存在
        NSFileManager *fileManager = [NSFileManager defaultManager];
        if (![fileManager fileExistsAtPath:dyyyFolderPath]) {
            NSError *error = nil;
            [fileManager createDirectoryAtPath:dyyyFolderPath withIntermediateDirectories:YES attributes:nil error:&error];
            if (error) {
                NSLog(@"[DYYY] 建立DYYY目錄失敗: %@", error.localizedDescription);
            }
        }

        // 讀取本地設定檔
        NSError *error = nil;
        NSData *jsonData = [NSData dataWithContentsOfFile:jsonFilePath options:0 error:&error];

        if (jsonData) {
            NSDictionary *loadedData = [NSJSONSerialization JSONObjectWithData:jsonData options:0 error:&error];
            if (loadedData && !error) {
                s_localABTestData = [loadedData copy];
                s_dataLoaded = YES;
                NSLog(@"[DYYY] ABTest本機設定已從檔案載入成功");				
                return;
            } else {
                NSLog(@"[DYYY] ABTest本地設定解析失敗: %@", error.localizedDescription);
            }
        } else {
            NSLog(@"[DYYY] ABTest本地設定檔不存在或無法讀取");
        }
        
        // 載入失敗時的處理
        s_localABTestData = nil;
        s_dataLoaded = NO;
    });
}

/**
 * 应用本地ABTest配置数据 (负责根据模式处理并应用到 Manager)
 * 包含是否应该应用的条件判断
 * 新增类方法
 */
+ (void)applyFixedABTestData {
    if (!s_abTestBlockEnabled || !s_dataLoaded) {Add commentMore actions
        NSLog(@"[DYYY] 不符合應用本機設定的條件 (禁止下發=%@, 資料載入=%@, 資料是否為空=%@)",
            s_abTestBlockEnabled ? @"開啟" : @"關閉",
            s_dataLoaded ? @"成功" : @"失敗",
            s_localABTestData ? @"否" : @"是");
        s_appliedFixedABTestData = nil;
        return;
    }

    AWEABTestManager *manager = [%c(AWEABTestManager) sharedManager];
    if (!manager) {
        NSLog(@"[DYYY] 無法套用本機設定：AWEABTestManager 实例不可用");
        s_appliedFixedABTestData = nil;
        return;
    }

    BOOL usingPatchMode = [self isPatchMode];
    NSDictionary *dataToApply = nil;

    if (usingPatchMode) {
        // 覆写模式：本地配置合并现有配置
        NSMutableDictionary *mergedData = [NSMutableDictionary dictionaryWithDictionary:[manager abTestData] ?: @{}];
        [mergedData addEntriesFromDictionary:s_localABTestData];
        dataToApply = [mergedData copy];
    } else {
        // 替换模式：直接使用本地配置
        dataToApply = [s_localABTestData copy];
    }

    // 应用数据到 Manager
    [manager setAbTestData:dataToApply];
    // 记录下这个被应用的数据实例，供 Hook 中判断使用
    s_appliedFixedABTestData = dataToApply;

    NSLog(@"[DYYY] ABTest本機設定已套用");
}

/**
 * 取得目前的ABTest資料
 * 转换为类方法
 */
+ (NSDictionary *)getCurrentABTestData {   
    AWEABTestManager *manager = [%c(AWEABTestManager) sharedManager];
    return manager ? [manager abTestData] : nil;
}

@end

%hook AWEABTestManager

/**
 * Hook: 設定ABTest資料
 * 在禁止下發模式下阻止更新資料，除非資料來自本地設定
 */
- (void)setAbTestData:(id)data {
    if (s_abTestBlockEnabled && data != s_appliedFixedABTestData) {
        NSLog(@"[DYYY] 阻止ABTest資料更新 (已啟用禁止下發設定)");
        return;
    }
    %orig;
}

/**
 * Hook: 增量更新ABTest資料
 * 在禁止下發模式下阻止增量更新
 */
- (void)incrementalUpdateData:(id)data unchangedKeyList:(id)keyList {
    if (s_abTestBlockEnabled) {
        NSLog(@"[DYYY] 阻止增量更新ABTest資料 (已啟用禁止下發設定)");
        return;
    }
    %orig;
}

/**
 * Hook: 從網路取得設定(帶重試)
 * 在禁止下發模式下攔截網路請求，並立即返回空結果
 */
- (void)fetchConfigurationWithRetry:(BOOL)retry completion:(id)completion {
    if (s_abTestBlockEnabled) {
        NSLog(@"[DYYY] 阻止從網路取得ABTest設定 (已啟用禁止下發設定)");
        if (completion && [completion isKindOfClass:%c(NSBlock)]) {
            dispatch_async(dispatch_get_main_queue(), ^{
                ((void (^)(id))completion)(nil);
            });
        }
        return;
    }
    %orig;
}

/**
 * Hook: 從網路取得設定
 * 在禁止下發模式下阻止網路請求
 */
- (void)fetchConfiguration:(id)arg1 {
    if (s_abTestBlockEnabled) {
        NSLog(@"[DYYY] 阻止從網路取得ABTest設定 (已啟用禁止下發設定)");
        return;
    }
    %orig;
}

/**
 * Hook: 覆寫ABTest資料
 * 在禁止下發模式下阻止覆蓋資料
 */
- (void)overrideABTestData:(id)data needCleanCache:(BOOL)cleanCache {
    if (s_abTestBlockEnabled) {
        NSLog(@"[DYYY] 阻止覆寫ABTest資料 (已啟用禁止下發設定)");
        return;
    }
    %orig;
}

/**
 * Hook: 儲存ABTest資料
 * 在禁止下發模式下阻止儲存
 */
- (void)_saveABTestData:(id)data {
    if (s_abTestBlockEnabled) {
        NSLog(@"[DYYY] 阻止儲存ABTest資料 (已啟用禁止下發設定)");
        return;
    }
    %orig;
}

%end

%ctor {
    %init;
    s_abTestBlockEnabled = [[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYABTestBlockEnabled"];

    NSString *currentMode = [DYYYABTestHook isPatchMode] ? @"覆寫模式" : @"替換模式";

    NSLog(@"[DYYY] ABTest Hook已啟動: 禁止下發=%@, 目前模式=%@", 
          s_abTestBlockEnabled ? @"開啟" : @"關閉",
          currentMode);
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [DYYYABTestHook loadLocalABTestConfig];
        [DYYYABTestHook applyFixedABTestData];
    });
}