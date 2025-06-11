#import "DYYYABTestHook.h"
#import <objc/runtime.h>

@interface AWEABTestManager : NSObject
@property(retain, nonatomic) NSDictionary *abTestData;
@property(retain, nonatomic) NSMutableDictionary *consistentABTestDic;
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

BOOL abTestBlockEnabled = NO;
NSDictionary *gFixedABTestData = nil;
dispatch_once_t onceToken;
BOOL gDataLoaded = NO;

static NSDate *lastLoadAttemptTime = nil;
static const NSTimeInterval kMinLoadInterval = 60.0;

/**
 * 判斷目前是否為覆寫模式
 * 透過DYYYABTestModeString判斷，返回YES表示覆寫模式，NO表示替換模式
 */
BOOL isPatchMode(void) {
    NSString *savedMode = [[NSUserDefaults standardUserDefaults] objectForKey:@"DYYYABTestModeString"];
    return [savedMode isEqualToString:@"覆寫模式：保留原設定，覆蓋同名項"];
}

/**
 * 載入本地ABTest設定資料
 * 根據不同模式（覆寫/替換）處理設定資料
 */
void ensureABTestDataLoaded(void) {
    dispatch_once(&onceToken, ^{
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
                // 成功載入資料，根據套用方式處理
                AWEABTestManager *manager = [%c(AWEABTestManager) sharedManager];
                BOOL usingPatchMode = isPatchMode();
                
                if (manager && usingPatchMode) {
                    // 覆寫模式：合併現有設定與本地設定
                    NSDictionary *currentABTestData = [manager abTestData];
                    NSMutableDictionary *mergedData = [NSMutableDictionary dictionaryWithDictionary:currentABTestData ?: @{}];
                    [mergedData addEntriesFromDictionary:loadedData];
                    gFixedABTestData = [mergedData copy];
                    NSLog(@"[DYYY] ABTest本地設定已載入(覆寫模式)");
                } else {
                    // 替換模式：直接使用本地設定
                    gFixedABTestData = [loadedData copy];
                    NSLog(@"[DYYY] ABTest本地設定已載入(替換模式)");
                }
                gDataLoaded = YES;
                return;
            } else {
                NSLog(@"[DYYY] ABTest本地設定解析失敗: %@", error.localizedDescription);
            }
        } else {
            NSLog(@"[DYYY] ABTest本地設定檔不存在或無法讀取");
        }
        
        // 載入失敗時的處理
        gFixedABTestData = nil;
        gDataLoaded = NO;
    });
}

/**
 * 取得目前的ABTest資料
 */
NSDictionary *getCurrentABTestData(void) {
    ensureABTestDataLoaded();
    
    AWEABTestManager *manager = [%c(AWEABTestManager) sharedManager];
    return manager ? [manager abTestData] : nil;
}

%hook AWEABTestManager

/**
 * Hook: 設定ABTest資料
 * 在禁止下發模式下阻止更新資料，除非資料來自本地設定
 */
- (void)setAbTestData:(id)data {
    if (abTestBlockEnabled && data != gFixedABTestData) {
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
    if (abTestBlockEnabled) {
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
    if (abTestBlockEnabled) {
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
    if (abTestBlockEnabled) {
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
    if (abTestBlockEnabled) {
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
    if (abTestBlockEnabled) {
        NSLog(@"[DYYY] 阻止儲存ABTest資料 (已啟用禁止下發設定)");
        return;
    }
    %orig;
}

%end

%ctor {
    %init;
    abTestBlockEnabled = [[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYABTestBlockEnabled"];
    
    NSString *currentMode = isPatchMode() ? @"覆寫模式" : @"替換模式";
    
    NSLog(@"[DYYY] ABTest Hook已啟動: 禁止下發=%@, 目前模式=%@", 
          abTestBlockEnabled ? @"開啟" : @"關閉", 
          currentMode);
    
    dispatch_async(dispatch_get_main_queue(), ^{
        AWEABTestManager *manager = [%c(AWEABTestManager) sharedManager];
        ensureABTestDataLoaded();
        
        if (manager && gDataLoaded && abTestBlockEnabled) {
            [manager setAbTestData:gFixedABTestData];
        }
    });
}