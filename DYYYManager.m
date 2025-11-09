#import "DYYYManager.h"
#import <CoreAudioTypes/CoreAudioTypes.h>
#import <CoreMedia/CMMetadata.h>
#import <ImageIO/ImageIO.h>
#import <MobileCoreServices/MobileCoreServices.h>
#import <MobileCoreServices/UTCoreTypes.h>
#import <Photos/Photos.h>
#import <libwebp/decode.h>
#import <libwebp/demux.h>
#import <libwebp/mux.h>
#import <objc/message.h>
#import <objc/runtime.h>
#ifndef kCGImagePropertyHEIFDictionary
#define kCGImagePropertyHEIFDictionary CFSTR("HEIFDictionary")
#endif
#ifndef kCGImagePropertyHEIFDelayTime
#define kCGImagePropertyHEIFDelayTime CFSTR("DelayTime")
#endif
#ifndef kUTTypeHEIC
#define kUTTypeHEIC CFSTR("public.heic")
#endif

#import "DYYYToast.h"
#import "DYYYUtils.h"

static const NSTimeInterval kDYYYDefaultFrameDelay = 0.1f;
static const CGFloat kDYYYMillisecondsPerSecond = 1000.0f;

static inline CGFloat DYYYFrameDelayForProperties(CFDictionaryRef properties) {
    if (!properties) {
        return kDYYYDefaultFrameDelay;
    }

    CGFloat delayTime = 0.1f;

    CFDictionaryRef gifDict = CFDictionaryGetValue(properties, kCGImagePropertyGIFDictionary);
    if (gifDict) {
        CFNumberRef unclampedDelayNum = CFDictionaryGetValue(gifDict, kCGImagePropertyGIFUnclampedDelayTime);
        if (unclampedDelayNum) {
            CFNumberGetValue(unclampedDelayNum, kCFNumberFloatType, &delayTime);
        } else {
            CFNumberRef delayNum = CFDictionaryGetValue(gifDict, kCGImagePropertyGIFDelayTime);
            if (delayNum) {
                CFNumberGetValue(delayNum, kCFNumberFloatType, &delayTime);
            }
        }
    }
    else {
        CFDictionaryRef pngDict = CFDictionaryGetValue(properties, kCGImagePropertyPNGDictionary);
        if (pngDict) {
            CFNumberRef unclampedDelayNum = CFDictionaryGetValue(pngDict, kCGImagePropertyAPNGUnclampedDelayTime);
            if (unclampedDelayNum) {
                CFNumberGetValue(unclampedDelayNum, kCFNumberFloatType, &delayTime);
            } else {
                CFNumberRef delayNum = CFDictionaryGetValue(pngDict, kCGImagePropertyAPNGDelayTime);
                if (delayNum) {
                    CFNumberGetValue(delayNum, kCFNumberFloatType, &delayTime);
                }
            }
        }
        else {
            CFDictionaryRef heifDict = CFDictionaryGetValue(properties, kCGImagePropertyHEIFDictionary);
            if (heifDict) {
                CFNumberRef delayNum = CFDictionaryGetValue(heifDict, kCGImagePropertyHEIFDelayTime);
                if (delayNum) {
                    CFNumberGetValue(delayNum, kCFNumberFloatType, &delayTime);
                }
            }
        }
    }
    return delayTime;
}

@interface DYYYManager () {
    AVAssetExportSession *session;
    AVURLAsset *asset;
    AVAssetReader *reader;
    AVAssetWriter *writer;
    dispatch_queue_t queue;
    dispatch_group_t group;
}
@end

@interface DYYYManager () <NSURLSessionDownloadDelegate>
@property(nonatomic, strong) NSMutableDictionary<NSString *, NSURLSessionDownloadTask *> *downloadTasks;
@property(nonatomic, strong) NSMutableDictionary<NSString *, DYYYToast *> *progressViews;
@property(nonatomic, strong) NSOperationQueue *downloadQueue;
@property(nonatomic, strong) NSMutableDictionary<NSString *, NSNumber *> *taskProgressMap;
@property(nonatomic, strong) NSMutableDictionary<NSString *, void (^)(BOOL success, NSURL *fileURL)> *completionBlocks;
@property(nonatomic, strong) NSMutableDictionary<NSString *, NSNumber *> *mediaTypeMap;
@property(nonatomic, strong) NSMutableDictionary<NSString *, NSString *> *filePathToDownloadID;

// 批量下载相关属性
@property(nonatomic, strong) NSMutableDictionary<NSString *, NSString *> *downloadToBatchMap;                                                 // 下载ID到批量ID的映射
@property(nonatomic, strong) NSMutableDictionary<NSString *, NSNumber *> *batchCompletedCountMap;                                             // 批量ID到已完成数量的映射
@property(nonatomic, strong) NSMutableDictionary<NSString *, NSNumber *> *batchSuccessCountMap;                                               // 批量ID到成功数量的映射
@property(nonatomic, strong) NSMutableDictionary<NSString *, NSNumber *> *batchTotalCountMap;                                                 // 批量ID到总数量的映射
@property(nonatomic, strong) NSMutableDictionary<NSString *, void (^)(NSInteger current, NSInteger total)> *batchProgressBlocks;              // 批量进度回调
@property(nonatomic, strong) NSMutableDictionary<NSString *, void (^)(NSInteger successCount, NSInteger totalCount)> *batchCompletionBlocks;  // 批量完成回调
@end

@implementation DYYYManager

+ (instancetype)shared {
    static DYYYManager *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
      sharedInstance = [[self alloc] init];
    });
    return sharedInstance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _fileLinks = [NSMutableDictionary dictionary];
        _downloadTasks = [NSMutableDictionary dictionary];
        _progressViews = [NSMutableDictionary dictionary];
        _downloadQueue = [[NSOperationQueue alloc] init];
        _downloadQueue.maxConcurrentOperationCount = 3;
        _taskProgressMap = [NSMutableDictionary dictionary];
        _completionBlocks = [NSMutableDictionary dictionary];
        _mediaTypeMap = [NSMutableDictionary dictionary];
        _filePathToDownloadID = [NSMutableDictionary dictionary];

        // 初始化批量下载相关字典
        _downloadToBatchMap = [NSMutableDictionary dictionary];
        _batchCompletedCountMap = [NSMutableDictionary dictionary];
        _batchSuccessCountMap = [NSMutableDictionary dictionary];
        _batchTotalCountMap = [NSMutableDictionary dictionary];
        _batchProgressBlocks = [NSMutableDictionary dictionary];
        _batchCompletionBlocks = [NSMutableDictionary dictionary];
    }
    return self;
}

+ (void)saveMedia:(NSURL *)mediaURL mediaType:(MediaType)mediaType completion:(void (^)(BOOL success))completion {
    if (mediaType == MediaTypeAudio) {
        if (completion) {
            dispatch_async(dispatch_get_main_queue(), ^{
              completion(NO);
            });
        }
        return;
    }

    [PHPhotoLibrary requestAuthorization:^(PHAuthorizationStatus status) {
      if (status != PHAuthorizationStatusAuthorized) {
          dispatch_async(dispatch_get_main_queue(), ^{
            [DYYYUtils showToast:@"請允許取用照片App權限後重試"];
            [[NSFileManager defaultManager] removeItemAtPath:mediaURL.path error:nil];
            [[DYYYManager shared] finalizeDownloadWithFileURL:mediaURL success:NO];
            if (completion) {
                completion(NO);
            }
          });
          return;
      }

      void (^reportResult)(BOOL) = ^(BOOL success) {
          dispatch_async(dispatch_get_main_queue(), ^{
            [[DYYYManager shared] finalizeDownloadWithFileURL:mediaURL success:success];
            if (completion) {
                completion(success);
            }
          });
      };

      if (mediaType == MediaTypeHeic) {
          NSString *actualFormat = [self detectFileFormat:mediaURL];

          if ([actualFormat isEqualToString:@"webp"]) {
              [self convertWebpToGifSafely:mediaURL
                                completion:^(NSURL *gifURL, BOOL success) {
                                  if (success && gifURL) {
                                      [self saveGifToPhotoLibrary:gifURL
                                                        mediaType:mediaType
                                                       completion:^(BOOL gifSuccess) {
                                                         [[NSFileManager defaultManager] removeItemAtPath:mediaURL.path error:nil];
                                                         reportResult(gifSuccess);
                                                       }];
                                  } else {
                                      dispatch_async(dispatch_get_main_queue(), ^{
                                        [DYYYUtils showToast:@"轉換失敗"];
                                        [[NSFileManager defaultManager] removeItemAtPath:mediaURL.path error:nil];
                                        reportResult(NO);
                                      });
                                  }
                                }];
              return;
          }

          if ([actualFormat isEqualToString:@"heic"] || [actualFormat isEqualToString:@"heif"]) {
              [self convertHeicToGif:mediaURL
                          completion:^(NSURL *gifURL, BOOL success) {
                            if (success && gifURL) {
                                [self saveGifToPhotoLibrary:gifURL
                                                  mediaType:mediaType
                                                 completion:^(BOOL gifSuccess) {
                                                   [[NSFileManager defaultManager] removeItemAtPath:mediaURL.path error:nil];
                                                   reportResult(gifSuccess);
                                                 }];
                            } else {
                                dispatch_async(dispatch_get_main_queue(), ^{
                                  [DYYYUtils showToast:@"轉換失敗"];
                                  [[NSFileManager defaultManager] removeItemAtPath:mediaURL.path error:nil];
                                  reportResult(NO);
                                });
                            }
                          }];
              return;
          }

          if ([actualFormat isEqualToString:@"gif"]) {
              [self saveGifToPhotoLibrary:mediaURL
                                mediaType:mediaType
                               completion:^(BOOL gifSuccess) {
                                 reportResult(gifSuccess);
                               }];
              return;
          }

          [[PHPhotoLibrary sharedPhotoLibrary]
              performChanges:^{
                UIImage *image = [UIImage imageWithContentsOfFile:mediaURL.path];
                if (image) {
                    [PHAssetChangeRequest creationRequestForAssetFromImage:image];
                }
              }
              completionHandler:^(BOOL success, NSError *_Nullable error) {
                dispatch_async(dispatch_get_main_queue(), ^{
                  if (!success) {
                      [DYYYUtils showToast:@"儲存失敗"];
                  }
                  [[NSFileManager defaultManager] removeItemAtPath:mediaURL.path error:nil];
                  reportResult(success);
                });
              }];
          return;
      }

      [[PHPhotoLibrary sharedPhotoLibrary]
          performChanges:^{
            if (mediaType == MediaTypeVideo) {
                [PHAssetChangeRequest creationRequestForAssetFromVideoAtFileURL:mediaURL];
            } else {
                UIImage *image = [UIImage imageWithContentsOfFile:mediaURL.path];
                if (image) {
                    [PHAssetChangeRequest creationRequestForAssetFromImage:image];
                }
            }
          }
          completionHandler:^(BOOL success, NSError *_Nullable error) {
            dispatch_async(dispatch_get_main_queue(), ^{
              if (!success) {
                  [DYYYUtils showToast:@"儲存失敗"];
              }
              [[NSFileManager defaultManager] removeItemAtPath:mediaURL.path error:nil];
              reportResult(success);
            });
          }];
    }];
}

// 检测文件格式的方法
+ (NSString *)detectFileFormat:(NSURL *)fileURL {
    // 读取文件的整个数据或足够的字节用于识别
    NSData *fileData = [NSData dataWithContentsOfURL:fileURL options:NSDataReadingMappedIfSafe error:nil];
    if (!fileData || fileData.length < 12) {
        return @"unknown";
    }

    // 转换为字节数组以便检查
    const unsigned char *bytes = [fileData bytes];

    // 检查WebP格式："RIFF" + 4字节 + "WEBP"
    if (bytes[0] == 'R' && bytes[1] == 'I' && bytes[2] == 'F' && bytes[3] == 'F' && bytes[8] == 'W' && bytes[9] == 'E' && bytes[10] == 'B' && bytes[11] == 'P') {
        return @"webp";
    }

    // 检查HEIF/HEIC格式："ftyp" 在第4-7字节位置
    if (bytes[4] == 'f' && bytes[5] == 't' && bytes[6] == 'y' && bytes[7] == 'p') {
        if (fileData.length >= 16) {
            // 检查HEIC品牌
            if (bytes[8] == 'h' && bytes[9] == 'e' && bytes[10] == 'i' && bytes[11] == 'c') {
                return @"heic";
            }
            // 检查HEIF品牌
            if (bytes[8] == 'h' && bytes[9] == 'e' && bytes[10] == 'i' && bytes[11] == 'f') {
                return @"heif";
            }
            // 可能是其他HEIF变体
            return @"heif";
        }
    }

    // 检查GIF格式："GIF87a"或"GIF89a"
    if (bytes[0] == 'G' && bytes[1] == 'I' && bytes[2] == 'F') {
        return @"gif";
    }

    // 检查PNG格式
    if (bytes[0] == 0x89 && bytes[1] == 'P' && bytes[2] == 'N' && bytes[3] == 'G') {
        return @"png";
    }

    // 检查JPEG格式
    if (bytes[0] == 0xFF && bytes[1] == 0xD8) {
        return @"jpeg";
    }

    return @"unknown";
}

// 保存GIF到相册的方法
+ (void)saveGifToPhotoLibrary:(NSURL *)gifURL mediaType:(MediaType)mediaType completion:(void (^)(BOOL success))completion {
    (void)mediaType;
    [[PHPhotoLibrary sharedPhotoLibrary]
        performChanges:^{
          NSData *gifData = [NSData dataWithContentsOfURL:gifURL];
          PHAssetCreationRequest *request = [PHAssetCreationRequest creationRequestForAsset];
          PHAssetResourceCreationOptions *options = [[PHAssetResourceCreationOptions alloc] init];
          options.uniformTypeIdentifier = @"com.compuserve.gif";
          [request addResourceWithType:PHAssetResourceTypePhoto data:gifData options:options];
        }
        completionHandler:^(BOOL success, NSError *_Nullable error) {
          dispatch_async(dispatch_get_main_queue(), ^{
            if (!success) {
                [DYYYUtils showToast:@"儲存失敗"];
            }
            [[NSFileManager defaultManager] removeItemAtPath:gifURL.path error:nil];
            if (completion) {
                completion(success);
            }
          });
        }];
}

static void ReleaseWebPData(void *info, const void *data, size_t size) {
    free((void *)data);
}

+ (void)convertWebpToGifSafely:(NSURL *)webpURL completion:(void (^)(NSURL *gifURL, BOOL success))completion {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
      // 創建GIF檔案路徑
      NSString *gifFileName = [[webpURL.lastPathComponent stringByDeletingPathExtension] stringByAppendingPathExtension:@"gif"];
      NSURL *gifURL = [NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:gifFileName]];

      // 讀取WebP檔案資料
      NSData *webpData = [NSData dataWithContentsOfURL:webpURL];
      if (!webpData) {
          dispatch_async(dispatch_get_main_queue(), ^{
            if (completion) {
                completion(nil, NO);
            }
          });
          return;
      }

      // 初始化WebP解碼器
      WebPData webp_data;
      webp_data.bytes = webpData.bytes;
      webp_data.size = webpData.length;

      // 創建WebP動畫解碼器
      WebPDemuxer *demux = WebPDemux(&webp_data);
      if (!demux) {
          // 如果無法解碼為動畫，嘗試直接解碼為靜態圖像
          WebPDecoderConfig config;
          WebPInitDecoderConfig(&config);

          // 設置解碼選項，支援透明度
          config.output.colorspace = MODE_RGBA;
          config.options.use_threads = 1;

          // 嘗試解碼
          VP8StatusCode status = WebPDecode(webpData.bytes, webpData.length, &config);

          if (status != VP8_STATUS_OK) {
              // 解碼失敗
              dispatch_async(dispatch_get_main_queue(), ^{
                if (completion) {
                    completion(nil, NO);
                }
              });
              return;
          }

          // 成功解碼為靜態圖像，創建UIImage
          CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
          CGDataProviderRef provider = CGDataProviderCreateWithData(NULL, config.output.u.RGBA.rgba, config.output.width * config.output.height * 4,
                                                                    ReleaseWebPData);  // 使用定義的C函數作為回調

          CGImageRef imageRef = CGImageCreate(config.output.width, config.output.height, 8, 32, config.output.width * 4, colorSpace, kCGBitmapByteOrderDefault | kCGImageAlphaPremultipliedLast,
                                              provider, NULL, false, kCGRenderingIntentDefault);

          // 創建靜態GIF
          NSDictionary *gifProperties = @{
              (__bridge NSString *)kCGImagePropertyGIFDictionary : @{
                  (__bridge NSString *)kCGImagePropertyGIFLoopCount : @0,
              }
          };

          CGImageDestinationRef destination = CGImageDestinationCreateWithURL((__bridge CFURLRef)gifURL, kUTTypeGIF, 1, NULL);
          if (!destination) {
              CGImageRelease(imageRef);
              CGDataProviderRelease(provider);
              CGColorSpaceRelease(colorSpace);

              dispatch_async(dispatch_get_main_queue(), ^{
                if (completion) {
                    completion(nil, NO);
                }
              });
              return;
          }

          CGImageDestinationSetProperties(destination, (__bridge CFDictionaryRef)gifProperties);

          NSDictionary *frameProperties = @{
              (__bridge NSString *)kCGImagePropertyGIFDictionary : @{
                  (__bridge NSString *)kCGImagePropertyGIFDelayTime : @(kDYYYDefaultFrameDelay),
              }
          };

          CGImageDestinationAddImage(destination, imageRef, (__bridge CFDictionaryRef)frameProperties);
          BOOL success = CGImageDestinationFinalize(destination);

          CGImageRelease(imageRef);
          CGDataProviderRelease(provider);
          CGColorSpaceRelease(colorSpace);
          CFRelease(destination);

          dispatch_async(dispatch_get_main_queue(), ^{
            if (completion) {
                completion(gifURL, success);
            }
          });
          return;
      }

      // 獲取WebP資訊
      uint32_t frameCount = WebPDemuxGetI(demux, WEBP_FF_FRAME_COUNT);
      int canvasWidth = WebPDemuxGetI(demux, WEBP_FF_CANVAS_WIDTH);
      int canvasHeight = WebPDemuxGetI(demux, WEBP_FF_CANVAS_HEIGHT);
      BOOL isAnimated = (frameCount > 1);
      BOOL hasAlpha = WebPDemuxGetI(demux, WEBP_FF_FORMAT_FLAGS) & ALPHA_FLAG;

      // 設置GIF屬性
      NSDictionary *gifProperties = @{
          (__bridge NSString *)kCGImagePropertyGIFDictionary : @{
              (__bridge NSString *)kCGImagePropertyGIFLoopCount : @0,  // 0表示無限循環
          }
      };

      // 創建GIF圖像目標
      CGImageDestinationRef destination = CGImageDestinationCreateWithURL((__bridge CFURLRef)gifURL, kUTTypeGIF, isAnimated ? frameCount : 1, NULL);
      if (!destination) {
          WebPDemuxDelete(demux);
          dispatch_async(dispatch_get_main_queue(), ^{
            if (completion) {
                completion(nil, NO);
            }
          });
          return;
      }

      // 設置GIF屬性
      CGImageDestinationSetProperties(destination, (__bridge CFDictionaryRef)gifProperties);

      // 解碼每一幀並添加到GIF
      BOOL allFramesAdded = YES;
      CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();

      // 用於保存上一幀的畫布
      CGContextRef prevCanvas = CGBitmapContextCreate(NULL, canvasWidth, canvasHeight, 8, canvasWidth * 4, colorSpace, kCGImageAlphaPremultipliedLast | kCGBitmapByteOrderDefault);

      // 用於目前繪製的畫布
      CGContextRef currCanvas = CGBitmapContextCreate(NULL, canvasWidth, canvasHeight, 8, canvasWidth * 4, colorSpace, kCGImageAlphaPremultipliedLast | kCGBitmapByteOrderDefault);

      // 如果畫布創建失敗，則返回錯誤
      if (!prevCanvas || !currCanvas) {
          if (prevCanvas)
              CGContextRelease(prevCanvas);
          if (currCanvas)
              CGContextRelease(currCanvas);
          CGColorSpaceRelease(colorSpace);
          WebPDemuxDelete(demux);
          CFRelease(destination);

          dispatch_async(dispatch_get_main_queue(), ^{
            if (completion) {
                completion(nil, NO);
            }
          });
          return;
      }

      // 初始化為透明背景
      CGContextClearRect(prevCanvas, CGRectMake(0, 0, canvasWidth, canvasHeight));

      for (uint32_t i = 0; i < frameCount; i++) {
          WebPIterator iter;
          if (WebPDemuxGetFrame(demux, i + 1, &iter)) {
              // 解碼目前幀
              WebPDecoderConfig config;
              WebPInitDecoderConfig(&config);

              // 設置解碼配置，強制處理透明度
              config.output.colorspace = MODE_RGBA;
              config.output.is_external_memory = 0;
              config.options.use_threads = 1;

              // 解碼
              VP8StatusCode status = WebPDecode(iter.fragment.bytes, iter.fragment.size, &config);

              if (status != VP8_STATUS_OK) {
                  WebPDemuxReleaseIterator(&iter);
                  continue;
              }

              // 創建幀圖像
              CGDataProviderRef frameProvider = CGDataProviderCreateWithData(NULL, config.output.u.RGBA.rgba, config.output.width * config.output.height * 4, ReleaseWebPData);

              if (!frameProvider) {
                  WebPFreeDecBuffer(&config.output);
                  WebPDemuxReleaseIterator(&iter);
                  continue;
              }

              CGImageRef frameImageRef = CGImageCreate(config.output.width, config.output.height, 8, 32, config.output.width * 4, colorSpace,
                                                       kCGBitmapByteOrderDefault | (hasAlpha ? kCGImageAlphaLast : kCGImageAlphaNoneSkipLast), frameProvider, NULL, false, kCGRenderingIntentDefault);

              if (!frameImageRef) {
                  CGDataProviderRelease(frameProvider);
                  WebPDemuxReleaseIterator(&iter);
                  continue;
              }

              // 準備目前幀畫布 - 根據合成模式處理
              // 首先拷貝上一幀的狀態到目前幀
              CGContextCopyBytes(currCanvas, prevCanvas, canvasWidth, canvasHeight);

              // 根據混合模式處理目前幀
              if (iter.blend_method == WEBP_MUX_BLEND) {
                  // 使用Alpha混合模式，將目前幀混合到背景上
                  CGContextDrawImage(currCanvas, CGRectMake(iter.x_offset, canvasHeight - iter.y_offset - config.output.height, config.output.width, config.output.height), frameImageRef);
              } else {
                  // 不混合模式，清除目標區域後再繪製
                  CGContextClearRect(currCanvas, CGRectMake(iter.x_offset, canvasHeight - iter.y_offset - config.output.height, config.output.width, config.output.height));

                  CGContextDrawImage(currCanvas, CGRectMake(iter.x_offset, canvasHeight - iter.y_offset - config.output.height, config.output.width, config.output.height), frameImageRef);
              }

              // 從目前畫布創建幀圖像
              CGImageRef canvasImageRef = CGBitmapContextCreateImage(currCanvas);

              // 處理幀間延遲
              CGFloat delayTime = iter.duration > 0 ? iter.duration / kDYYYMillisecondsPerSecond : kDYYYDefaultFrameDelay;

              // 創建幀屬性
              NSDictionary *frameProperties = @{
                  (__bridge NSString *)kCGImagePropertyGIFDictionary : @{
                      (__bridge NSString *)kCGImagePropertyGIFDelayTime : @(delayTime),
                      (__bridge NSString *)kCGImagePropertyGIFHasGlobalColorMap : @YES,
                      (__bridge NSString *)kCGImagePropertyColorModel : hasAlpha ? @"RGBA" : @"RGB",
                  }
              };

              // 添加幀到GIF
              CGImageDestinationAddImage(destination, canvasImageRef, (__bridge CFDictionaryRef)frameProperties);

              // 根據處理模式更新上一幀畫布
              if (iter.dispose_method == WEBP_MUX_DISPOSE_BACKGROUND) {
                  // 處理背景處理模式 - 清除目前幀區域
                  CGContextClearRect(prevCanvas, CGRectMake(iter.x_offset, canvasHeight - iter.y_offset - config.output.height, config.output.width, config.output.height));
              } else if (iter.dispose_method == WEBP_MUX_DISPOSE_NONE) {
                  // 保持目前幀，複製目前畫布到上一幀
                  CGContextCopyBytes(prevCanvas, currCanvas, canvasWidth, canvasHeight);
              }

              // 釋放資源
              CGImageRelease(canvasImageRef);
              CGImageRelease(frameImageRef);
              CGDataProviderRelease(frameProvider);
              WebPDemuxReleaseIterator(&iter);
          } else {
              allFramesAdded = NO;
          }
      }

      // 釋放畫布
      CGContextRelease(prevCanvas);
      CGContextRelease(currCanvas);
      CGColorSpaceRelease(colorSpace);

      // 完成GIF生成
      BOOL success = CGImageDestinationFinalize(destination) && allFramesAdded;

      // 釋放資源
      WebPDemuxDelete(demux);
      CFRelease(destination);

      dispatch_async(dispatch_get_main_queue(), ^{
        if (completion) {
            completion(gifURL, success);
        }
      });
    });
}

// 輔助函數：複製上下文像素資料
static void CGContextCopyBytes(CGContextRef dst, CGContextRef src, int width, int height) {
    size_t bytesPerRow = CGBitmapContextGetBytesPerRow(src);
    void *srcData = CGBitmapContextGetData(src);
    void *dstData = CGBitmapContextGetData(dst);

    if (srcData && dstData) {
        memcpy(dstData, srcData, bytesPerRow * height);
    }
}

// 将HEIC转换为GIF的方法
+ (void)convertHeicToGif:(NSURL *)heicURL completion:(void (^)(NSURL *gifURL, BOOL success))completion {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
      // 1. 创建ImageSource
      NSDictionary *options = @{(__bridge NSString *)kCGImageSourceTypeIdentifierHint : (__bridge NSString *)kUTTypeHEIC, (__bridge NSString *)kCGImageSourceShouldCache : @NO};
      CGImageSourceRef src = CGImageSourceCreateWithURL((__bridge CFURLRef)heicURL, (__bridge CFDictionaryRef)options);
      if (!src) {
          dispatch_async(dispatch_get_main_queue(), ^{
            if (completion)
                completion(nil, NO);
          });
          return;
      }

      // 2. 获取帧数
      size_t count = CGImageSourceGetCount(src);

      // 3. 生成GIF路径
      NSString *gifFileName = [[heicURL.lastPathComponent stringByDeletingPathExtension] stringByAppendingPathExtension:@"gif"];
      NSURL *gifURL = [NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:gifFileName]];

      // 4. GIF属性
      NSDictionary *gifProperties = @{(__bridge NSString *)kCGImagePropertyGIFDictionary : @{(__bridge NSString *)kCGImagePropertyGIFLoopCount : @0}};

      // 5. 创建GIF目标
      CGImageDestinationRef dest = CGImageDestinationCreateWithURL((__bridge CFURLRef)gifURL, kUTTypeGIF, count, NULL);
      if (!dest) {
          CFRelease(src);
          dispatch_async(dispatch_get_main_queue(), ^{
            if (completion)
                completion(nil, NO);
          });
          return;
      }
      CGImageDestinationSetProperties(dest, (__bridge CFDictionaryRef)gifProperties);

      // 6. 遍历帧并写入GIF
      for (size_t i = 0; i < count; i++) {
          CGImageRef imgRef = CGImageSourceCreateImageAtIndex(src, i, NULL);

          // 获取帧延迟
          CFDictionaryRef properties = CGImageSourceCopyPropertiesAtIndex(src, i, NULL);
          CGFloat delayTime = DYYYFrameDelayForProperties(properties);
          if (properties)
              CFRelease(properties);

          NSDictionary *frameProps = @{(__bridge NSString *)kCGImagePropertyGIFDictionary : @{(__bridge NSString *)kCGImagePropertyGIFDelayTime : @(delayTime)}};

          if (imgRef) {
              CGImageDestinationAddImage(dest, imgRef, (__bridge CFDictionaryRef)frameProps);
              CGImageRelease(imgRef);
          }
      }

      // 7. 完成GIF生成
      BOOL success = CGImageDestinationFinalize(dest);
      CFRelease(dest);
      CFRelease(src);

      dispatch_async(dispatch_get_main_queue(), ^{
        if (completion)
            completion(gifURL, success);
      });
    });
}

+ (void)downloadLivePhoto:(NSURL *)imageURL videoURL:(NSURL *)videoURL completion:(void (^)(void))completion {
    // 獲取共享實例，確保FileLinks字典存在
    DYYYManager *manager = [DYYYManager shared];
    if (!manager.fileLinks) {
        manager.fileLinks = [NSMutableDictionary dictionary];
    }

    // 為圖片和影片URL創建唯一的鍵
    NSString *uniqueKey = [NSString stringWithFormat:@"%@_%@", imageURL.absoluteString, videoURL.absoluteString];

    // 檢查是否已經存在此下載任務
    NSDictionary *existingPaths = manager.fileLinks[uniqueKey];
    if (existingPaths) {
        NSString *imagePath = existingPaths[@"image"];
        NSString *videoPath = existingPaths[@"video"];

        // 使用非同步檢查以避免主線程阻塞
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
          BOOL imageExists = [[NSFileManager defaultManager] fileExistsAtPath:imagePath];
          BOOL videoExists = [[NSFileManager defaultManager] fileExistsAtPath:videoPath];

          dispatch_async(dispatch_get_main_queue(), ^{
            if (imageExists && videoExists) {
                [[DYYYManager shared] saveLivePhoto:imagePath videoUrl:videoPath];
                if (completion) {
                    completion();
                }
                return;
            } else {
                // 檔案不完整，需要重新下載
                [self startDownloadLivePhotoProcess:imageURL videoURL:videoURL uniqueKey:uniqueKey completion:completion];
            }
          });
        });
    } else {
        // 沒有快取，直接開始下載
        [self startDownloadLivePhotoProcess:imageURL videoURL:videoURL uniqueKey:uniqueKey completion:completion];
    }
}

+ (void)startDownloadLivePhotoProcess:(NSURL *)imageURL videoURL:(NSURL *)videoURL uniqueKey:(NSString *)uniqueKey completion:(void (^)(void))completion {
    // 創建臨時目錄
    NSString *livePhotoPath = [NSTemporaryDirectory() stringByAppendingPathComponent:@"LivePhoto"];

    NSFileManager *fileManager = [NSFileManager defaultManager];
    if (![fileManager fileExistsAtPath:livePhotoPath]) {
        [fileManager createDirectoryAtPath:livePhotoPath withIntermediateDirectories:YES attributes:nil error:nil];
    }

    // 生成唯一識別符，防止多次調用時檔案衝突
    NSString *uniqueID = [NSUUID UUID].UUIDString;
    NSString *imagePath = [livePhotoPath stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.heic", uniqueID]];
    NSString *videoPath = [livePhotoPath stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.mp4", uniqueID]];

    // 儲存檔案路徑，以便下次下載相同的URL時可以復用
    DYYYManager *manager = [DYYYManager shared];
    [manager.fileLinks setObject:@{@"image" : imagePath, @"video" : videoPath} forKey:uniqueKey];

    dispatch_async(dispatch_get_main_queue(), ^{
      // 創建進度視圖
      CGRect screenBounds = [UIScreen mainScreen].bounds;
      DYYYToast *progressView = [[DYYYToast alloc] initWithFrame:screenBounds];
      [progressView show];

      // 最佳化會話配置
      NSURLSessionConfiguration *configuration = [NSURLSessionConfiguration defaultSessionConfiguration];
      configuration.timeoutIntervalForRequest = 60.0;  // 增加超時時間
      configuration.timeoutIntervalForResource = 60.0;
      configuration.HTTPMaximumConnectionsPerHost = 10;                             // 增加併發連線數
      configuration.requestCachePolicy = NSURLRequestReloadIgnoringLocalCacheData;  // 強制從網路重新下載

      // 使用共享委託的session以節省資源
      NSURLSession *session = [NSURLSession sessionWithConfiguration:configuration delegate:[DYYYManager shared] delegateQueue:[NSOperationQueue mainQueue]];

      dispatch_group_t group = dispatch_group_create();
      __block BOOL imageDownloaded = NO;
      __block BOOL videoDownloaded = NO;
      __block float imageProgress = 0.0;
      __block float videoProgress = 0.0;

      // 設置單獨的下載觀察者ID用於進度追蹤
      NSString *imageDownloadID = [NSString stringWithFormat:@"image_%@", uniqueID];
      NSString *videoDownloadID = [NSString stringWithFormat:@"video_%@", uniqueID];

      // 更新合併進度的計時器
      __block NSTimer *progressTimer = [NSTimer scheduledTimerWithTimeInterval:0.1
                                                                       repeats:YES
                                                                         block:^(NSTimer *_Nonnull timer) {
                                                                           float totalProgress = (imageProgress + videoProgress) / 2.0;
                                                                           [progressView setProgress:totalProgress];

                                                                           // 更新進度文字
                                                                           NSString *statusText = @"正在下載原況照片...";
                                                                           if (imageDownloaded && !videoDownloaded) {
                                                                               statusText = @"圖片下載完成，等待影片...";
                                                                           } else if (!imageDownloaded && videoDownloaded) {
                                                                               statusText = @"影片下載完成，等待圖片...";
                                                                           } else if (imageDownloaded && videoDownloaded) {
                                                                               statusText = @"下載完成，準備儲存...";
                                                                               [timer invalidate];  // 全部完成時停止計時器
                                                                           }
                                                                         }];

      // 下載圖片
      dispatch_group_enter(group);
      NSURLRequest *imageRequest = [NSURLRequest requestWithURL:imageURL];
      NSURLSessionDataTask *imageTask = [session dataTaskWithRequest:imageRequest
                                                   completionHandler:^(NSData *_Nullable data, NSURLResponse *_Nullable response, NSError *_Nullable error) {
                                                     if (!error && data) {
                                                         // 直接寫入檔案，避免臨時檔案移動操作
                                                         if ([data writeToFile:imagePath atomically:YES]) {
                                                             imageDownloaded = YES;
                                                             imageProgress = 1.0;
                                                         }
                                                     }
                                                     dispatch_group_leave(group);
                                                   }];

      // 設置圖片下載進度觀察
      if ([imageTask respondsToSelector:@selector(taskIdentifier)]) {
          [[manager taskProgressMap] setObject:@(0.0) forKey:imageDownloadID];

          // 使用系統API觀察進度 (iOS 11+)
          if (@available(iOS 11.0, *)) {
              [imageTask.progress addObserver:manager forKeyPath:@"fractionCompleted" options:NSKeyValueObservingOptionNew context:(__bridge void *)(imageDownloadID)];
          }
      }

      // 下載影片
      dispatch_group_enter(group);
      NSURLRequest *videoRequest = [NSURLRequest requestWithURL:videoURL];
      NSURLSessionDataTask *videoTask = [session dataTaskWithRequest:videoRequest
                                                   completionHandler:^(NSData *_Nullable data, NSURLResponse *_Nullable response, NSError *_Nullable error) {
                                                     if (!error && data) {
                                                         // 直接寫入檔案，避免臨時檔案移動操作
                                                         if ([data writeToFile:videoPath atomically:YES]) {
                                                             videoDownloaded = YES;
                                                             videoProgress = 1.0;
                                                         }
                                                     }
                                                     dispatch_group_leave(group);
                                                   }];

      // 設置影片下載進度觀察
      if ([videoTask respondsToSelector:@selector(taskIdentifier)]) {
          [[manager taskProgressMap] setObject:@(0.0) forKey:videoDownloadID];

          // 使用系統API觀察進度 (iOS 11+)
          if (@available(iOS 11.0, *)) {
              [videoTask.progress addObserver:manager forKeyPath:@"fractionCompleted" options:NSKeyValueObservingOptionNew context:(__bridge void *)(videoDownloadID)];
          }
      }

      // 啟動下載任務
      [imageTask resume];
      [videoTask resume];

      // 當兩個下載都完成後，儲存原況照片
      dispatch_group_notify(group, dispatch_get_main_queue(), ^{
        // 停止進度計時器
        [progressTimer invalidate];

        // 移除進度觀察
        if (@available(iOS 11.0, *)) {
            if ([imageTask respondsToSelector:@selector(progress)]) {
                [imageTask.progress removeObserver:manager forKeyPath:@"fractionCompleted"];
            }
            if ([videoTask respondsToSelector:@selector(progress)]) {
                [videoTask.progress removeObserver:manager forKeyPath:@"fractionCompleted"];
            }
        }

        // 檢查檔案是否真的存在
        BOOL imageExists = [[NSFileManager defaultManager] fileExistsAtPath:imagePath];
        BOOL videoExists = [[NSFileManager defaultManager] fileExistsAtPath:videoPath];

        BOOL downloadSucceeded = imageExists && videoExists;
        progressView.allowSuccessAnimation = downloadSucceeded;
        [progressView dismiss];

        if (downloadSucceeded) {
            @try {
                // 添加iOS版本檢查
                if (@available(iOS 15.0, *)) {
                    [[DYYYManager shared] saveLivePhoto:imagePath videoUrl:videoPath];
                }
            } @catch (NSException *exception) {
                // 刪除失敗的檔案
                [[NSFileManager defaultManager] removeItemAtPath:imagePath error:nil];
                [[NSFileManager defaultManager] removeItemAtPath:videoPath error:nil];
                [manager.fileLinks removeObjectForKey:uniqueKey];
                [DYYYUtils showToast:@"儲存原況照片失敗"];
            }
        } else {
            // 清理不完整的檔案
            if (imageExists)
                [[NSFileManager defaultManager] removeItemAtPath:imagePath error:nil];
            if (videoExists)
                [[NSFileManager defaultManager] removeItemAtPath:videoPath error:nil];
            [manager.fileLinks removeObjectForKey:uniqueKey];
            [DYYYUtils showToast:@"下載原況照片失敗"];
        }

        if (completion) {
            completion();
        }
      });
    });
}

// 需要添加KVO回調方法來處理下載進度
- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSKeyValueChangeKey, id> *)change context:(void *)context {
    if ([keyPath isEqualToString:@"fractionCompleted"] && [object isKindOfClass:[NSProgress class]]) {
        NSString *downloadID = (__bridge NSString *)context;
        if (downloadID) {
            NSProgress *progress = (NSProgress *)object;
            float fractionCompleted = progress.fractionCompleted;
            [self.taskProgressMap setObject:@(fractionCompleted) forKey:downloadID];
        }
    } else {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}

+ (void)downloadMedia:(NSURL *)url mediaType:(MediaType)mediaType audio:(NSURL *)audioURL completion:(void (^)(BOOL success))completion {
    [self downloadMediaWithProgress:url
                          mediaType:mediaType
                              audio:audioURL
                           progress:nil
                         completion:^(BOOL success, NSURL *fileURL) {
                           void (^notifyCompletion)(BOOL) = ^(BOOL result) {
                               if (completion) {
                                   completion(result);
                               }
                           };

                           if (success) {
                               if (mediaType == MediaTypeAudio) {
                                   dispatch_async(dispatch_get_main_queue(), ^{
                                     [[DYYYManager shared] finalizeDownloadWithFileURL:fileURL success:YES];
                                     UIActivityViewController *activityVC = [[UIActivityViewController alloc] initWithActivityItems:@[ fileURL ] applicationActivities:nil];

                                     [activityVC setCompletionWithItemsHandler:^(UIActivityType _Nullable activityType, BOOL completed, NSArray *_Nullable returnedItems, NSError *_Nullable error) {
                                       dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5 * NSEC_PER_SEC)), dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                                         [[NSFileManager defaultManager] removeItemAtURL:fileURL error:nil];
                                       });
                                     }];
                                     UIViewController *rootVC = [UIApplication sharedApplication].keyWindow.rootViewController;
                                     [rootVC presentViewController:activityVC animated:YES completion:nil];
                                     notifyCompletion(YES);
                                   });
                               } else {
                                   if (mediaType == MediaTypeVideo && audioURL) {
                                       if (![self videoHasAudio:fileURL]) {
                                           [self downloadAudioAndMergeWithVideo:fileURL
                                                                       audioURL:audioURL
                                                                     completion:^(BOOL mergeSuccess, NSURL *mergedURL) {
                                                                       if (mergeSuccess) {
                                                                           [[DYYYManager shared] replaceFileURL:fileURL withFileURL:mergedURL];
                                                                           [[NSFileManager defaultManager] removeItemAtURL:fileURL error:nil];
                                                                           [self saveMedia:mergedURL
                                                                                 mediaType:mediaType
                                                                                completion:^(BOOL saveSuccess) {
                                                                                  notifyCompletion(saveSuccess);
                                                                                }];
                                                                       } else {
                                                                           [self saveMedia:fileURL
                                                                                 mediaType:mediaType
                                                                                completion:^(BOOL saveSuccess) {
                                                                                  notifyCompletion(saveSuccess);
                                                                                }];
                                                                       }
                                                                     }];
                                           return;
                                       }
                                   }
                                   [self saveMedia:fileURL
                                         mediaType:mediaType
                                        completion:^(BOOL saveSuccess) {
                                          notifyCompletion(saveSuccess);
                                        }];
                               }
                           } else {
                               notifyCompletion(NO);
                               if (fileURL) {
                                   [[DYYYManager shared] finalizeDownloadWithFileURL:fileURL success:NO];
                               }
                           }
                         }];
}

+ (void)downloadMediaWithProgress:(NSURL *)url
                        mediaType:(MediaType)mediaType
                            audio:(NSURL *)audioURL
                         progress:(void (^)(float progress))progressBlock
                       completion:(void (^)(BOOL success, NSURL *fileURL))completion {
    // 創建自訂進度條介面
    dispatch_async(dispatch_get_main_queue(), ^{
      // 創建進度視圖
      CGRect screenBounds = [UIScreen mainScreen].bounds;
      DYYYToast *progressView = [[DYYYToast alloc] initWithFrame:screenBounds];

      // 生成下載ID並保存進度視圖
      NSString *downloadID = [NSUUID UUID].UUIDString;
      [[DYYYManager shared].progressViews setObject:progressView forKey:downloadID];

      [progressView show];

      // 儲存回調
      [[DYYYManager shared] setCompletionBlock:completion forDownloadID:downloadID];
      [[DYYYManager shared] setMediaType:mediaType forDownloadID:downloadID];

      // 配置下載會話 - 使用帶委託的會話以獲取進度更新
      NSURLSessionConfiguration *configuration = [NSURLSessionConfiguration defaultSessionConfiguration];
      NSURLSession *session = [NSURLSession sessionWithConfiguration:configuration delegate:[DYYYManager shared] delegateQueue:[NSOperationQueue mainQueue]];

      // 創建下載任務 - 不使用completionHandler，使用代理方法
      NSURLSessionDownloadTask *downloadTask = [session downloadTaskWithURL:url];
      downloadTask.taskDescription = downloadID;

      // 儲存下載任務
      [[DYYYManager shared].downloadTasks setObject:downloadTask forKey:downloadID];
      [[DYYYManager shared].taskProgressMap setObject:@0.0 forKey:downloadID];  // 初始化進度為0

      // 開始下載
      [downloadTask resume];
    });
}

+ (NSString *)getMediaTypeDescription:(MediaType)mediaType {
    switch (mediaType) {
        case MediaTypeVideo:
            return @"影片";
        case MediaTypeImage:
            return @"圖片";
        case MediaTypeAudio:
            return @"音訊";
        case MediaTypeHeic:
            return @"表情包";
        default:
            return @"檔案";
    }
}

// 判斷影片是否包含音訊軌道
+ (BOOL)videoHasAudio:(NSURL *)videoURL {
    AVAsset *asset = [AVAsset assetWithURL:videoURL];
    NSArray *audioTracks = [asset tracksWithMediaType:AVMediaTypeAudio];
    return audioTracks.count > 0;
}

// 下載音訊並與影片合併
+ (void)downloadAudioAndMergeWithVideo:(NSURL *)videoURL audioURL:(NSURL *)audioURL completion:(void (^)(BOOL success, NSURL *mergedURL))completion {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
      NSData *audioData = [NSData dataWithContentsOfURL:audioURL];
      if (!audioData) {
          dispatch_async(dispatch_get_main_queue(), ^{
            if (completion)
                completion(NO, nil);
          });
          return;
      }

      NSString *audioPath = [DYYYUtils cachePathForFilename:[NSString stringWithFormat:@"temp_%@", audioURL.lastPathComponent]];
      NSURL *audioFile = [NSURL fileURLWithPath:audioPath];
      if (![audioData writeToURL:audioFile atomically:YES]) {
          dispatch_async(dispatch_get_main_queue(), ^{
            if (completion)
                completion(NO, nil);
          });
          return;
      }

      [self mergeVideo:videoURL
             withAudio:audioFile
            completion:^(BOOL success, NSURL *merged) {
              [[NSFileManager defaultManager] removeItemAtURL:audioFile error:nil];
              dispatch_async(dispatch_get_main_queue(), ^{
                if (completion)
                    completion(success, merged);
              });
            }];
    });
}

// 合併影片和音訊
+ (void)mergeVideo:(NSURL *)videoURL withAudio:(NSURL *)audioURL completion:(void (^)(BOOL success, NSURL *mergedURL))completion {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
      AVURLAsset *videoAsset = [AVURLAsset URLAssetWithURL:videoURL options:nil];
      AVURLAsset *audioAsset = [AVURLAsset URLAssetWithURL:audioURL options:nil];
      AVAssetTrack *videoTrack = [[videoAsset tracksWithMediaType:AVMediaTypeVideo] firstObject];
      AVAssetTrack *audioTrack = [[audioAsset tracksWithMediaType:AVMediaTypeAudio] firstObject];
      if (!videoTrack || !audioTrack) {
          dispatch_async(dispatch_get_main_queue(), ^{
            if (completion)
                completion(NO, nil);
          });
          return;
      }

      AVMutableComposition *composition = [AVMutableComposition composition];
      AVMutableCompositionTrack *compVideoTrack = [composition addMutableTrackWithMediaType:AVMediaTypeVideo preferredTrackID:kCMPersistentTrackID_Invalid];
      [compVideoTrack insertTimeRange:CMTimeRangeMake(kCMTimeZero, videoAsset.duration) ofTrack:videoTrack atTime:kCMTimeZero error:nil];

      AVMutableCompositionTrack *compAudioTrack = [composition addMutableTrackWithMediaType:AVMediaTypeAudio preferredTrackID:kCMPersistentTrackID_Invalid];
      [compAudioTrack insertTimeRange:CMTimeRangeMake(kCMTimeZero, videoAsset.duration) ofTrack:audioTrack atTime:kCMTimeZero error:nil];

      NSString *outputPath = [DYYYUtils cachePathForFilename:[NSString stringWithFormat:@"merged_%@", videoURL.lastPathComponent]];
      NSURL *outputURL = [NSURL fileURLWithPath:outputPath];
      if ([[NSFileManager defaultManager] fileExistsAtPath:outputPath]) {
          [[NSFileManager defaultManager] removeItemAtPath:outputPath error:nil];
      }

      AVAssetExportSession *exportSession = [[AVAssetExportSession alloc] initWithAsset:composition presetName:AVAssetExportPresetPassthrough];
      exportSession.outputURL = outputURL;
      exportSession.outputFileType = AVFileTypeMPEG4;
      [exportSession exportAsynchronouslyWithCompletionHandler:^{
        BOOL success = exportSession.status == AVAssetExportSessionStatusCompleted;
        if (!success) {
            NSLog(@"Merge export failed: %@", exportSession.error);
        } else {
            [[NSFileManager defaultManager] removeItemAtURL:videoURL error:nil];
        }
        dispatch_async(dispatch_get_main_queue(), ^{
          if (completion)
              completion(success, success ? outputURL : nil);
        });
      }];
    });
}

// 取消所有下載
+ (void)cancelAllDownloads {
    NSArray *downloadIDs = [[DYYYManager shared].downloadTasks allKeys];

    for (NSString *downloadID in downloadIDs) {
        NSURLSessionDownloadTask *task = [[DYYYManager shared].downloadTasks objectForKey:downloadID];
        if (task) {
            [task cancel];
        }

        DYYYToast *progressView = [[DYYYManager shared].progressViews objectForKey:downloadID];
        if (progressView) {
            progressView.isCancelled = YES;
            [progressView dismiss];
        }
    }

    NSString *livePhotoPath = [NSTemporaryDirectory() stringByAppendingPathComponent:@"LivePhotoBatch"];
    NSFileManager *fileManager = [NSFileManager defaultManager];
    if ([fileManager fileExistsAtPath:livePhotoPath]) {
        NSError *error = nil;
        [fileManager removeItemAtPath:livePhotoPath error:&error];
        if (error) {
            NSLog(@"清理原況照片臨時目錄失敗: %@", error.localizedDescription);
        }
    }

    NSString *generalLivePhotoPath = [NSTemporaryDirectory() stringByAppendingPathComponent:@"LivePhoto"];
    if ([fileManager fileExistsAtPath:generalLivePhotoPath]) {
        NSError *error = nil;
        [fileManager removeItemAtPath:generalLivePhotoPath error:&error];
        if (error) {
            NSLog(@"清理LivePhoto臨時目錄失敗: %@", error.localizedDescription);
        }
    }

    [[DYYYManager shared].downloadTasks removeAllObjects];
    [[DYYYManager shared].progressViews removeAllObjects];
}

+ (void)downloadAllImages:(NSMutableArray *)imageURLs {
    if (imageURLs.count == 0) {
        return;
    }

    [self downloadAllImagesWithProgress:imageURLs
                               progress:nil
                             completion:^(NSInteger successCount, NSInteger totalCount){
                             }];
}

+ (void)downloadAllImagesWithProgress:(NSMutableArray *)imageURLs
                             progress:(void (^)(NSInteger current, NSInteger total))progressBlock
                           completion:(void (^)(NSInteger successCount, NSInteger totalCount))completion {
    if (imageURLs.count == 0) {
        if (completion) {
            completion(0, 0);
        }
        return;
    }

    dispatch_async(dispatch_get_main_queue(), ^{
      CGRect screenBounds = [UIScreen mainScreen].bounds;
      DYYYToast *progressView = [[DYYYToast alloc] initWithFrame:screenBounds];
      NSString *batchID = [NSUUID UUID].UUIDString;
      [[DYYYManager shared].progressViews setObject:progressView forKey:batchID];

      [progressView show];

      __block NSInteger completedCount = 0;
      __block NSInteger successCount = 0;
      NSInteger totalCount = imageURLs.count;

      progressView.cancelBlock = ^{
        [self cancelAllDownloads];
        if (completion) {
            completion(successCount, totalCount);
        }
      };

      // 儲存批量下載的相關資訊
      [[DYYYManager shared] setBatchInfo:batchID totalCount:totalCount progressBlock:progressBlock completionBlock:completion];

      // 為每個URL創建下載任務
      for (NSString *urlString in imageURLs) {
          NSURL *url = [NSURL URLWithString:urlString];
          if (!url) {
              [[DYYYManager shared] incrementCompletedAndUpdateProgressForBatch:batchID success:NO];
              continue;
          }

          // 創建單個下載任務ID
          NSString *downloadID = [NSUUID UUID].UUIDString;
          [[DYYYManager shared] associateDownload:downloadID withBatchID:batchID];
          NSURLSessionConfiguration *configuration = [NSURLSessionConfiguration defaultSessionConfiguration];
          NSURLSession *session = [NSURLSession sessionWithConfiguration:configuration delegate:[DYYYManager shared] delegateQueue:[NSOperationQueue mainQueue]];

          // 創建下載任務 - 使用代理方法
          NSURLSessionDownloadTask *downloadTask = [session downloadTaskWithURL:url];
          [[DYYYManager shared].downloadTasks setObject:downloadTask forKey:downloadID];
          [[DYYYManager shared].taskProgressMap setObject:@0.0 forKey:downloadID];
          [[DYYYManager shared] setMediaType:MediaTypeImage forDownloadID:downloadID];
          [downloadTask resume];
      }
    });
}

// 設置批量下載資訊
- (void)setBatchInfo:(NSString *)batchID
          totalCount:(NSInteger)totalCount
       progressBlock:(void (^)(NSInteger current, NSInteger total))progressBlock
     completionBlock:(void (^)(NSInteger successCount, NSInteger totalCount))completionBlock {
    [self.batchTotalCountMap setObject:@(totalCount) forKey:batchID];
    [self.batchCompletedCountMap setObject:@(0) forKey:batchID];
    [self.batchSuccessCountMap setObject:@(0) forKey:batchID];

    if (progressBlock) {
        [self.batchProgressBlocks setObject:[progressBlock copy] forKey:batchID];
    }

    if (completionBlock) {
        [self.batchCompletionBlocks setObject:[completionBlock copy] forKey:batchID];
    }
}

// 關聯單個下載到批量下載
- (void)associateDownload:(NSString *)downloadID withBatchID:(NSString *)batchID {
    [self.downloadToBatchMap setObject:batchID forKey:downloadID];
}

// 批量下載完成計數並更新進度
- (void)incrementCompletedAndUpdateProgressForBatch:(NSString *)batchID success:(BOOL)success {
    @synchronized(self) {
        NSNumber *completedCountNum = self.batchCompletedCountMap[batchID];
        NSInteger completedCount = completedCountNum ? [completedCountNum integerValue] + 1 : 1;
        [self.batchCompletedCountMap setObject:@(completedCount) forKey:batchID];

        if (success) {
            NSNumber *successCountNum = self.batchSuccessCountMap[batchID];
            NSInteger successCount = successCountNum ? [successCountNum integerValue] + 1 : 1;
            [self.batchSuccessCountMap setObject:@(successCount) forKey:batchID];
        }

        NSNumber *totalCountNum = self.batchTotalCountMap[batchID];
        NSInteger totalCount = totalCountNum ? [totalCountNum integerValue] : 0;

        DYYYToast *progressView = self.progressViews[batchID];
        if (progressView) {
            float progress = totalCount > 0 ? (float)completedCount / totalCount : 0;
            [progressView setProgress:progress];
        }

        void (^progressBlock)(NSInteger current, NSInteger total) = self.batchProgressBlocks[batchID];
        if (progressBlock) {
            progressBlock(completedCount, totalCount);
        }

        if (completedCount >= totalCount) {
            NSInteger successCount = [self.batchSuccessCountMap[batchID] integerValue];

            void (^completionBlock)(NSInteger successCount, NSInteger totalCount) = self.batchCompletionBlocks[batchID];
            if (completionBlock) {
                completionBlock(successCount, totalCount);
            }

            if (progressView) {
                progressView.allowSuccessAnimation = (successCount == totalCount);
                [progressView dismiss];
            }
            [self.progressViews removeObjectForKey:batchID];

            // 清理批量下載相關資訊
            [self.batchCompletedCountMap removeObjectForKey:batchID];
            [self.batchSuccessCountMap removeObjectForKey:batchID];
            [self.batchTotalCountMap removeObjectForKey:batchID];
            [self.batchProgressBlocks removeObjectForKey:batchID];
            [self.batchCompletionBlocks removeObjectForKey:batchID];

            // 移除關聯的下載ID
            NSArray *downloadIDs = [self.downloadToBatchMap allKeysForObject:batchID];
            for (NSString *downloadID in downloadIDs) {
                [self.downloadToBatchMap removeObjectForKey:downloadID];
            }
        }
    }
}

// 儲存完成回調
- (void)setCompletionBlock:(void (^)(BOOL success, NSURL *fileURL))completion forDownloadID:(NSString *)downloadID {
    if (completion) {
        [self.completionBlocks setObject:[completion copy] forKey:downloadID];
    }
}

// 儲存媒體類型
- (void)setMediaType:(MediaType)mediaType forDownloadID:(NSString *)downloadID {
    [self.mediaTypeMap setObject:@(mediaType) forKey:downloadID];
}

- (void)associateFileURL:(NSURL *)fileURL withDownloadID:(NSString *)downloadID {
    if (!fileURL || downloadID.length == 0) {
        return;
    }
    NSString *filePath = fileURL.path;
    if (filePath.length == 0) {
        return;
    }
    @synchronized(self.filePathToDownloadID) {
        self.filePathToDownloadID[filePath] = downloadID;
    }
}

- (NSString *)downloadIDForFileURL:(NSURL *)fileURL {
    if (!fileURL) {
        return nil;
    }
    NSString *filePath = fileURL.path;
    if (filePath.length == 0) {
        return nil;
    }
    @synchronized(self.filePathToDownloadID) {
        return self.filePathToDownloadID[filePath];
    }
}

- (void)replaceFileURL:(NSURL *)oldURL withFileURL:(NSURL *)newURL {
    if (!newURL) {
        return;
    }
    NSString *downloadID = [self downloadIDForFileURL:oldURL];
    if (downloadID.length == 0) {
        return;
    }
    NSString *newPath = newURL.path;
    if (newPath.length == 0) {
        return;
    }
    @synchronized(self.filePathToDownloadID) {
        if (oldURL.path.length > 0) {
            [self.filePathToDownloadID removeObjectForKey:oldURL.path];
        }
        self.filePathToDownloadID[newPath] = downloadID;
    }
}

- (void)removeMappingsForDownloadID:(NSString *)downloadID {
    if (downloadID.length == 0) {
        return;
    }
    @synchronized(self.filePathToDownloadID) {
        NSArray *keys = [self.filePathToDownloadID allKeysForObject:downloadID];
        for (NSString *key in keys) {
            [self.filePathToDownloadID removeObjectForKey:key];
        }
    }
}

- (void)finalizeDownloadWithFileURL:(NSURL *)fileURL success:(BOOL)success {
    NSString *downloadID = [self downloadIDForFileURL:fileURL];
    if (downloadID.length == 0) {
        dispatch_async(dispatch_get_main_queue(), ^{
          if (!success) {
              [DYYYUtils showToast:@"保存失败"];
          }
        });
        return;
    }
    [self finalizeDownloadWithID:downloadID success:success fileURL:fileURL];
}

- (void)finalizeDownloadWithID:(NSString *)downloadID success:(BOOL)success fileURL:(NSURL *_Nullable)fileURL {
    if (downloadID.length == 0) {
        return;
    }

    [self removeMappingsForDownloadID:downloadID];

    dispatch_async(dispatch_get_main_queue(), ^{
      DYYYToast *progressView = self.progressViews[downloadID];
      if (progressView) {
          progressView.allowSuccessAnimation = success;
          if (success) {
              [progressView setProgress:1.0f];
          }
          [progressView dismiss];
          [self.progressViews removeObjectForKey:downloadID];
      }

      [self.taskProgressMap removeObjectForKey:downloadID];
      [self.completionBlocks removeObjectForKey:downloadID];
      [self.mediaTypeMap removeObjectForKey:downloadID];
      [self.downloadTasks removeObjectForKey:downloadID];
      [self.downloadToBatchMap removeObjectForKey:downloadID];
    });

    if (fileURL) {
        NSString *filePath = fileURL.path;
        if (filePath.length > 0) {
            @synchronized(self.filePathToDownloadID) {
                [self.filePathToDownloadID removeObjectForKey:filePath];
            }
        }
    }
}

#pragma mark - NSURLSessionDownloadDelegate

- (void)URLSession:(NSURLSession *)session
                 downloadTask:(NSURLSessionDownloadTask *)downloadTask
                 didWriteData:(int64_t)bytesWritten
            totalBytesWritten:(int64_t)totalBytesWritten
    totalBytesExpectedToWrite:(int64_t)totalBytesExpectedToWrite {
    // 確保不會除以0
    if (totalBytesExpectedToWrite <= 0) {
        return;
    }

    // 計算進度
    float progress = (float)totalBytesWritten / totalBytesExpectedToWrite;

    dispatch_async(dispatch_get_main_queue(), ^{
      NSString *downloadIDForTask = nil;

      for (NSString *key in self.downloadTasks.allKeys) {
          NSURLSessionDownloadTask *task = self.downloadTasks[key];
          if (task == downloadTask) {
              downloadIDForTask = key;
              break;
          }
      }

      // 如果找到對應的進度視圖，更新進度
      if (downloadIDForTask) {
          [self.taskProgressMap setObject:@(progress) forKey:downloadIDForTask];

          DYYYToast *progressView = self.progressViews[downloadIDForTask];
          if (progressView) {
              if (!progressView.isCancelled) {
                  [progressView setProgress:progress];
              }
          }
      }
    });
}

// 下載完成的代理方法
- (void)URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)downloadTask didFinishDownloadingToURL:(NSURL *)location {
    // 找到對應的下載ID
    NSString *downloadIDForTask = nil;
    for (NSString *key in self.downloadTasks.allKeys) {
        NSURLSessionDownloadTask *task = self.downloadTasks[key];
        if (task == downloadTask) {
            downloadIDForTask = key;
            break;
        }
    }

    if (!downloadIDForTask) {
        return;
    }

    // 檢查是否屬於批量下載
    NSString *batchID = self.downloadToBatchMap[downloadIDForTask];
    BOOL isBatchDownload = (batchID != nil);

    // 獲取該下載任務的mediaType
    NSNumber *mediaTypeNumber = self.mediaTypeMap[downloadIDForTask];
    MediaType mediaType = MediaTypeImage;  // 預設為圖片
    if (mediaTypeNumber) {
        mediaType = (MediaType)[mediaTypeNumber integerValue];
    }

    // 處理下載的檔案
    NSString *fileName = [downloadTask.originalRequest.URL lastPathComponent];

    if (!fileName.pathExtension.length) {
        switch (mediaType) {
            case MediaTypeVideo:
                fileName = [fileName stringByAppendingPathExtension:@"mp4"];
                break;
            case MediaTypeImage:
                fileName = [fileName stringByAppendingPathExtension:@"jpg"];
                break;
            case MediaTypeAudio:
                fileName = [fileName stringByAppendingPathExtension:@"mp3"];
                break;
            case MediaTypeHeic:
                fileName = [fileName stringByAppendingPathExtension:@"heic"];
                break;
        }
    }

    NSURL *tempDir = [NSURL fileURLWithPath:NSTemporaryDirectory()];
    NSURL *destinationURL = [tempDir URLByAppendingPathComponent:fileName];

    NSError *moveError;
    if ([[NSFileManager defaultManager] fileExistsAtPath:destinationURL.path]) {
        [[NSFileManager defaultManager] removeItemAtURL:destinationURL error:nil];
    }

    [[NSFileManager defaultManager] moveItemAtURL:location toURL:destinationURL error:&moveError];

    if (isBatchDownload) {
        if (!moveError) {
            [DYYYManager saveMedia:destinationURL
                         mediaType:mediaType
                        completion:^(BOOL success) {
                          [[DYYYManager shared] incrementCompletedAndUpdateProgressForBatch:batchID success:success];
                        }];
        } else {
            [[DYYYManager shared] incrementCompletedAndUpdateProgressForBatch:batchID success:NO];
        }

        [self.downloadTasks removeObjectForKey:downloadIDForTask];
        [self.taskProgressMap removeObjectForKey:downloadIDForTask];
        [self.mediaTypeMap removeObjectForKey:downloadIDForTask];
    } else {
        void (^completionBlock)(BOOL success, NSURL *fileURL) = self.completionBlocks[downloadIDForTask];

        if (!moveError) {
            [self associateFileURL:destinationURL withDownloadID:downloadIDForTask];
            [self.downloadTasks removeObjectForKey:downloadIDForTask];
            [self.taskProgressMap setObject:@1.0f forKey:downloadIDForTask];

            if (completionBlock) {
                dispatch_async(dispatch_get_main_queue(), ^{
                  completionBlock(YES, destinationURL);
                });
            } else {
                [[DYYYManager shared] finalizeDownloadWithFileURL:destinationURL success:YES];
            }
        } else {
            [self.downloadTasks removeObjectForKey:downloadIDForTask];
            if (completionBlock) {
                dispatch_async(dispatch_get_main_queue(), ^{
                  completionBlock(NO, nil);
                });
            }
            [self finalizeDownloadWithID:downloadIDForTask success:NO fileURL:nil];
        }
    }
}

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error {
    if (!error) {
        return;  // 成功完成的情況已在didFinishDownloadingToURL處理
    }

    // 處理錯誤情況
    NSString *downloadIDForTask = nil;
    for (NSString *key in self.downloadTasks.allKeys) {
        NSURLSessionTask *existingTask = self.downloadTasks[key];
        if (existingTask == task) {
            downloadIDForTask = key;
            break;
        }
    }

    if (!downloadIDForTask) {
        return;
    }

    // 檢查是否屬於批量下載
    NSString *batchID = self.downloadToBatchMap[downloadIDForTask];
    BOOL isBatchDownload = (batchID != nil);

    if (isBatchDownload) {
        // 批量下載錯誤處理
        [[DYYYManager shared] incrementCompletedAndUpdateProgressForBatch:batchID success:NO];

        // 清理下載任務
        [self.downloadTasks removeObjectForKey:downloadIDForTask];
        [self.taskProgressMap removeObjectForKey:downloadIDForTask];
        [self.mediaTypeMap removeObjectForKey:downloadIDForTask];
        [self.downloadToBatchMap removeObjectForKey:downloadIDForTask];
    } else {
        // 單個下載錯誤處理
        void (^completionBlock)(BOOL success, NSURL *fileURL) = self.completionBlocks[downloadIDForTask];

        if (error.code != NSURLErrorCancelled) {
            dispatch_async(dispatch_get_main_queue(), ^{
              [DYYYUtils showToast:@"下載失敗"];
            });
        }

        if (completionBlock) {
            dispatch_async(dispatch_get_main_queue(), ^{
              completionBlock(NO, nil);
            });
        }

        [self finalizeDownloadWithID:downloadIDForTask success:NO fileURL:nil];
    }
}

// MARK: 以下都是創建儲存原況的調用方法
- (void)saveLivePhoto:(NSString *)imageSourcePath videoUrl:(NSString *)videoSourcePath {
    // 首先檢查iOS版本
    if (@available(iOS 15.0, *)) {
        // iOS 15及更高版本使用原有的實現
        NSURL *photoURL = [NSURL fileURLWithPath:imageSourcePath];
        NSURL *videoURL = [NSURL fileURLWithPath:videoSourcePath];
        BOOL available = [PHAssetCreationRequest supportsAssetResourceTypes:@[ @(PHAssetResourceTypePhoto), @(PHAssetResourceTypePairedVideo) ]];
        if (!available) {
            return;
        }
        [PHPhotoLibrary requestAuthorization:^(PHAuthorizationStatus status) {
          if (status != PHAuthorizationStatusAuthorized) {
              return;
          }
          NSString *identifier = [NSUUID UUID].UUIDString;
          [self useAssetWriter:photoURL
                         video:videoURL
                    identifier:identifier
                      complete:^(BOOL success, NSString *photoFile, NSString *videoFile, NSError *error) {
                        NSURL *photo = [NSURL fileURLWithPath:photoFile];
                        NSURL *video = [NSURL fileURLWithPath:videoFile];
                        [[PHPhotoLibrary sharedPhotoLibrary]
                            performChanges:^{
                              PHAssetCreationRequest *request = [PHAssetCreationRequest creationRequestForAsset];
                              [request addResourceWithType:PHAssetResourceTypePhoto fileURL:photo options:nil];
                              [request addResourceWithType:PHAssetResourceTypePairedVideo fileURL:video options:nil];
                            }
                            completionHandler:^(BOOL success, NSError *_Nullable error) {
                              dispatch_async(dispatch_get_main_queue(), ^{
                                if (success) {
                                    // 刪除臨時檔案
                                    [[NSFileManager defaultManager] removeItemAtPath:imageSourcePath error:nil];
                                    [[NSFileManager defaultManager] removeItemAtPath:videoSourcePath error:nil];
                                    [[NSFileManager defaultManager] removeItemAtPath:photoFile error:nil];
                                    [[NSFileManager defaultManager] removeItemAtPath:videoFile error:nil];
                                }
                              });
                            }];
                      }];
        }];
    } else {
        dispatch_async(dispatch_get_main_queue(), ^{
          [DYYYUtils showToast:@"目前iOS版本不支援原況照片，將分別儲存圖片和影片"];
        });
    }
}

- (void)useAssetWriter:(NSURL *)photoURL video:(NSURL *)videoURL identifier:(NSString *)identifier complete:(void (^)(BOOL success, NSString *photoFile, NSString *videoFile, NSError *error))complete {
    NSString *photoName = [photoURL lastPathComponent];
    NSString *photoFile = [self filePathFromTmp:photoName];
    [self addMetadataToPhoto:photoURL outputFile:photoFile identifier:identifier];
    NSString *videoName = [videoURL lastPathComponent];
    NSString *videoFile = [self filePathFromTmp:videoName];
    [self addMetadataToVideo:videoURL outputFile:videoFile identifier:identifier];
    if (!DYYYManager.shared->group)
        return;
    dispatch_group_notify(DYYYManager.shared->group, dispatch_get_main_queue(), ^{
      [self finishWritingTracksWithPhoto:photoFile video:videoFile complete:complete];
    });
}
- (void)finishWritingTracksWithPhoto:(NSString *)photoFile video:(NSString *)videoFile complete:(void (^)(BOOL success, NSString *photoFile, NSString *videoFile, NSError *error))complete {
    [DYYYManager.shared->reader cancelReading];
    [DYYYManager.shared->writer finishWritingWithCompletionHandler:^{
      if (complete)
          complete(YES, photoFile, videoFile, nil);
    }];
}
- (void)addMetadataToPhoto:(NSURL *)photoURL outputFile:(NSString *)outputFile identifier:(NSString *)identifier {
    NSMutableData *data = [NSData dataWithContentsOfURL:photoURL].mutableCopy;
    UIImage *image = [UIImage imageWithData:data];
    CGImageRef imageRef = image.CGImage;
    NSDictionary *imageMetadata = @{(NSString *)kCGImagePropertyMakerAppleDictionary : @{@"17" : identifier}};
    CGImageDestinationRef dest = CGImageDestinationCreateWithData((CFMutableDataRef)data, kUTTypeJPEG, 1, nil);
    CGImageDestinationAddImage(dest, imageRef, (CFDictionaryRef)imageMetadata);
    CGImageDestinationFinalize(dest);
    [data writeToFile:outputFile atomically:YES];
}

- (void)addMetadataToVideo:(NSURL *)videoURL outputFile:(NSString *)outputFile identifier:(NSString *)identifier {
    NSError *error = nil;
    AVAsset *asset = [AVAsset assetWithURL:videoURL];
    AVAssetReader *reader = [AVAssetReader assetReaderWithAsset:asset error:&error];
    if (error) {
        return;
    }
    NSMutableArray<AVMetadataItem *> *metadata = asset.metadata.mutableCopy;
    AVMetadataItem *item = [self createContentIdentifierMetadataItem:identifier];
    [metadata addObject:item];
    NSURL *videoFileURL = [NSURL fileURLWithPath:outputFile];
    [self deleteFile:outputFile];
    AVAssetWriter *writer = [AVAssetWriter assetWriterWithURL:videoFileURL fileType:AVFileTypeQuickTimeMovie error:&error];
    if (error) {
        return;
    }
    [writer setMetadata:metadata];
    NSArray<AVAssetTrack *> *tracks = [asset tracks];
    for (AVAssetTrack *track in tracks) {
        NSDictionary *readerOutputSettings = nil;
        NSDictionary *writerOuputSettings = nil;
        if ([track.mediaType isEqualToString:AVMediaTypeAudio]) {
            readerOutputSettings = @{AVFormatIDKey : @(kAudioFormatLinearPCM)};
            writerOuputSettings = @{AVFormatIDKey : @(kAudioFormatMPEG4AAC), AVSampleRateKey : @(44100), AVNumberOfChannelsKey : @(2), AVEncoderBitRateKey : @(128000)};
        }
        AVAssetReaderTrackOutput *output = [AVAssetReaderTrackOutput assetReaderTrackOutputWithTrack:track outputSettings:readerOutputSettings];
        AVAssetWriterInput *input = [AVAssetWriterInput assetWriterInputWithMediaType:track.mediaType outputSettings:writerOuputSettings];
        if ([reader canAddOutput:output] && [writer canAddInput:input]) {
            [reader addOutput:output];
            [writer addInput:input];
        }
    }
    AVAssetWriterInput *input = [self createStillImageTimeAssetWriterInput];
    AVAssetWriterInputMetadataAdaptor *adaptor = [AVAssetWriterInputMetadataAdaptor assetWriterInputMetadataAdaptorWithAssetWriterInput:input];
    if ([writer canAddInput:input]) {
        [writer addInput:input];
    }
    [writer startWriting];
    [writer startSessionAtSourceTime:kCMTimeZero];
    [reader startReading];
    AVMetadataItem *timedItem = [self createStillImageTimeMetadataItem];
    CMTimeRange timedRange = CMTimeRangeMake(kCMTimeZero, CMTimeMake(1, 100));
    AVTimedMetadataGroup *timedMetadataGroup = [[AVTimedMetadataGroup alloc] initWithItems:@[ timedItem ] timeRange:timedRange];
    [adaptor appendTimedMetadataGroup:timedMetadataGroup];
    DYYYManager.shared->reader = reader;
    DYYYManager.shared->writer = writer;
    DYYYManager.shared->queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    DYYYManager.shared->group = dispatch_group_create();
    for (NSInteger i = 0; i < reader.outputs.count; ++i) {
        dispatch_group_enter(DYYYManager.shared->group);
        [self writeTrack:i];
    }
}

- (void)writeTrack:(NSInteger)trackIndex {
    AVAssetReaderOutput *output = DYYYManager.shared->reader.outputs[trackIndex];
    AVAssetWriterInput *input = DYYYManager.shared->writer.inputs[trackIndex];

    [input requestMediaDataWhenReadyOnQueue:DYYYManager.shared->queue
                                 usingBlock:^{
                                   while (input.readyForMoreMediaData) {
                                       AVAssetReaderStatus status = DYYYManager.shared->reader.status;
                                       CMSampleBufferRef buffer = NULL;
                                       if ((status == AVAssetReaderStatusReading) && (buffer = [output copyNextSampleBuffer])) {
                                           BOOL success = [input appendSampleBuffer:buffer];
                                           CFRelease(buffer);
                                           if (!success) {
                                               [input markAsFinished];
                                               dispatch_group_leave(DYYYManager.shared->group);
                                               return;
                                           }
                                       } else {
                                           if (status == AVAssetReaderStatusReading) {
                                           } else if (status == AVAssetReaderStatusCompleted) {
                                           } else if (status == AVAssetReaderStatusCancelled) {
                                           } else if (status == AVAssetReaderStatusFailed) {
                                           }
                                           [input markAsFinished];
                                           dispatch_group_leave(DYYYManager.shared->group);
                                           return;
                                       }
                                   }
                                 }];
}
- (AVMetadataItem *)createContentIdentifierMetadataItem:(NSString *)identifier {
    AVMutableMetadataItem *item = [AVMutableMetadataItem metadataItem];
    item.keySpace = AVMetadataKeySpaceQuickTimeMetadata;
    item.key = AVMetadataQuickTimeMetadataKeyContentIdentifier;
    item.value = identifier;
    return item;
}

- (AVAssetWriterInput *)createStillImageTimeAssetWriterInput {
    NSArray *spec = @[ @{
        (NSString *)kCMMetadataFormatDescriptionMetadataSpecificationKey_Identifier : @"mdta/com.apple.quicktime.still-image-time",
        (NSString *)kCMMetadataFormatDescriptionMetadataSpecificationKey_DataType : (NSString *)kCMMetadataBaseDataType_SInt8
    } ];
    CMFormatDescriptionRef desc = NULL;
    CMMetadataFormatDescriptionCreateWithMetadataSpecifications(kCFAllocatorDefault, kCMMetadataFormatType_Boxed, (__bridge CFArrayRef)spec, &desc);
    AVAssetWriterInput *input = [AVAssetWriterInput assetWriterInputWithMediaType:AVMediaTypeMetadata outputSettings:nil sourceFormatHint:desc];
    return input;
}

- (AVMetadataItem *)createStillImageTimeMetadataItem {
    AVMutableMetadataItem *item = [AVMutableMetadataItem metadataItem];
    item.keySpace = AVMetadataKeySpaceQuickTimeMetadata;
    item.key = @"com.apple.quicktime.still-image-time";
    item.value = @(-1);
    item.dataType = (NSString *)kCMMetadataBaseDataType_SInt8;
    return item;
}
- (NSString *)filePathFromTmp:(NSString *)filename {
    NSString *tempPath = NSTemporaryDirectory();
    NSString *filePath = [tempPath stringByAppendingPathComponent:filename];
    return filePath;
}

- (void)deleteFile:(NSString *)file {
    NSFileManager *fm = [NSFileManager defaultManager];
    if ([fm fileExistsAtPath:file]) {
        [fm removeItemAtPath:file error:nil];
    }
}

+ (void)downloadAllLivePhotos:(NSArray<NSDictionary *> *)livePhotos {
    if (livePhotos.count == 0) {
        return;
    }

    [self downloadAllLivePhotosWithProgress:livePhotos
                                   progress:nil
                                 completion:^(NSInteger successCount, NSInteger totalCount){
                                 }];
}
+ (void)downloadAllLivePhotosWithProgress:(NSArray<NSDictionary *> *)livePhotos
                                 progress:(void (^)(NSInteger current, NSInteger total))progressBlock
                               completion:(void (^)(NSInteger successCount, NSInteger totalCount))completion {
    if (livePhotos.count == 0) {
        if (completion) {
            completion(0, 0);
        }
        return;
    }

    // 檢查iOS版本是否支援原況照片
    BOOL supportsLivePhoto = NO;
    if (@available(iOS 15.0, *)) {
        supportsLivePhoto = YES;
    }

    if (!supportsLivePhoto) {
        dispatch_async(dispatch_get_main_queue(), ^{
          [DYYYUtils showToast:@"目前iOS版本不支援原況照片"];
          if (completion) {
              completion(0, livePhotos.count);
          }
        });
        return;
    }

    // 建立進度顯示UI
    dispatch_async(dispatch_get_main_queue(), ^{
      CGRect screenBounds = [UIScreen mainScreen].bounds;
      DYYYToast *progressView = [[DYYYToast alloc] initWithFrame:screenBounds];
      [progressView show];

      progressView.cancelBlock = ^{
        [self cancelAllDownloads];
        if (completion) {
            completion(0, livePhotos.count);
        }
      };

      NSMutableArray<NSDictionary *> *downloadedFiles = [NSMutableArray arrayWithCapacity:livePhotos.count];
      for (int i = 0; i < livePhotos.count; i++) {
          [downloadedFiles addObject:@{@"imageURL" : livePhotos[i][@"imageURL"], @"videoURL" : livePhotos[i][@"videoURL"], @"imagePath" : [NSNull null], @"videoPath" : [NSNull null]}];
      }

      // 进度计算 - 为三个阶段分配权重
      NSInteger totalSteps = livePhotos.count * 10;  // 每个实况照片总共10步(4+4+2)
      __block NSInteger completedSteps = 0;
      __block NSInteger phase = 0;  // 0:下載圖片階段，1:下載影片階段，2:合成階段

      // 建立暫存目錄
      NSString *livePhotoPath = [NSTemporaryDirectory() stringByAppendingPathComponent:@"LivePhotoBatch"];
      NSFileManager *fileManager = [NSFileManager defaultManager];
      [fileManager createDirectoryAtPath:livePhotoPath withIntermediateDirectories:YES attributes:nil error:nil];

      // 更新進度的block
      void (^updateProgress)(NSString *) = ^(NSString *statusText) {
        float progress = (float)completedSteps / totalSteps;

        dispatch_async(dispatch_get_main_queue(), ^{
          [progressView setProgress:progress];
          if (progressBlock) {
              progressBlock(completedSteps, totalSteps);
          }
        });
      };

      // 下載完成後的處理
      void (^finishProcess)(void) = ^{
        __block NSInteger successCount = 0;

        // 請求相簿權限
        [PHPhotoLibrary requestAuthorization:^(PHAuthorizationStatus status) {
          if (status == PHAuthorizationStatusAuthorized) {
              dispatch_queue_t processQueue = dispatch_queue_create("com.dyyy.livephoto.process", DISPATCH_QUEUE_SERIAL);
              dispatch_group_t saveGroup = dispatch_group_create();

              NSInteger validFileCount = 0;
              for (NSDictionary *fileInfo in downloadedFiles) {
                  NSString *imagePath = fileInfo[@"imagePath"];
                  NSString *videoPath = fileInfo[@"videoPath"];

                  if (![imagePath isKindOfClass:[NSNull class]] && ![videoPath isKindOfClass:[NSNull class]] && [fileManager fileExistsAtPath:imagePath] && [fileManager fileExistsAtPath:videoPath]) {
                      validFileCount++;
                  }
              }

              if (validFileCount == 0) {
                  dispatch_async(dispatch_get_main_queue(), ^{
                    progressView.allowSuccessAnimation = NO;
                    [progressView dismiss];
                    [fileManager removeItemAtPath:livePhotoPath error:nil];
                    if (completion) {
                        completion(0, livePhotos.count);
                    }
                  });
                  return;
              }

              float progressPerItem = (float)(livePhotos.count * 2) / totalSteps;
              __block NSInteger processedCount = 0;

              for (NSDictionary *fileInfo in downloadedFiles) {
                  NSString *imagePath = fileInfo[@"imagePath"];
                  NSString *videoPath = fileInfo[@"videoPath"];

                  if (![imagePath isKindOfClass:[NSNull class]] && ![videoPath isKindOfClass:[NSNull class]] && [fileManager fileExistsAtPath:imagePath] && [fileManager fileExistsAtPath:videoPath]) {
                      dispatch_group_enter(saveGroup);

                      dispatch_async(processQueue, ^{
                        // 產生唯一識別碼
                        NSString *identifier = [NSUUID UUID].UUIDString;

                        // 建立每個任務的專屬實例變數，避免共享變數衝突
                        AVAssetReader *localReader = nil;
                        AVAssetWriter *localWriter = nil;
                        dispatch_queue_t localQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
                        dispatch_group_t localGroup = dispatch_group_create();

                        // 處理照片和元資料
                        NSString *photoName = [imagePath lastPathComponent];
                        NSString *photoFile = [[DYYYManager shared] filePathFromTmp:photoName];
                        [[DYYYManager shared] addMetadataToPhoto:[NSURL fileURLWithPath:imagePath] outputFile:photoFile identifier:identifier];

                        // 處理影片和元資料
                        NSString *videoName = [videoPath lastPathComponent];
                        NSString *videoFile = [[DYYYManager shared] filePathFromTmp:videoName];

                        // 使用本地變數而非全域共享變數
                        [[DYYYManager shared] addMetadataToVideoWithLocalVars:[NSURL fileURLWithPath:videoPath]
                                                                   outputFile:videoFile
                                                                   identifier:identifier
                                                                       reader:&localReader
                                                                       writer:&localWriter
                                                                        queue:localQueue
                                                                        group:localGroup
                                                                     complete:^(BOOL success, NSString *photoFile, NSString *videoFile, NSError *error) {
                                                                       if (success) {
                                                                           NSURL *photo = [NSURL fileURLWithPath:photoFile];
                                                                           NSURL *video = [NSURL fileURLWithPath:videoFile];

                                                                           [[PHPhotoLibrary sharedPhotoLibrary]
                                                                               performChanges:^{
                                                                                 PHAssetCreationRequest *request = [PHAssetCreationRequest creationRequestForAsset];
                                                                                 [request addResourceWithType:PHAssetResourceTypePhoto fileURL:photo options:nil];
                                                                                 [request addResourceWithType:PHAssetResourceTypePairedVideo fileURL:video options:nil];
                                                                               }
                                                                               completionHandler:^(BOOL success, NSError *_Nullable error) {
                                                                                 if (success) {
                                                                                     successCount++;
                                                                                 }

                                                                                 NSArray *filesToDelete = @[ imagePath, videoPath, photoFile, videoFile ];
                                                                                 for (NSString *path in filesToDelete) {
                                                                                     [fileManager removeItemAtPath:path error:nil];
                                                                                 }

                                                                                 // 增加進度步數
                                                                                 processedCount++;
                                                                                 completedSteps += 2;  // 每完成一個合成任務增加2步
                                                                                 updateProgress([NSString stringWithFormat:@"已合成 %ld/%ld", (long)processedCount, (long)validFileCount]);

                                                                                 dispatch_group_leave(saveGroup);
                                                                               }];
                                                                       } else {
                                                                           [fileManager removeItemAtPath:imagePath error:nil];
                                                                           [fileManager removeItemAtPath:videoPath error:nil];
                                                                           if (photoFile)
                                                                               [fileManager removeItemAtPath:photoFile error:nil];
                                                                           if (videoFile)
                                                                               [fileManager removeItemAtPath:videoFile error:nil];

                                                                           // 增加進度步數（即使失敗也增加）
                                                                           processedCount++;
                                                                           completedSteps += 2;
                                                                           updateProgress([NSString stringWithFormat:@"已合成 %ld/%ld", (long)processedCount, (long)validFileCount]);

                                                                           dispatch_group_leave(saveGroup);
                                                                       }
                                                                     }];
                      });
                  }
              }

              dispatch_group_notify(saveGroup, dispatch_get_main_queue(), ^{
                progressView.allowSuccessAnimation = (successCount > 0 && successCount == validFileCount);
                [progressView dismiss];

                [fileManager removeItemAtPath:livePhotoPath error:nil];

                if (completion) {
                    completion(successCount, livePhotos.count);
                }
              });
          } else {
              // 沒有相簿權限
              dispatch_async(dispatch_get_main_queue(), ^{
                progressView.allowSuccessAnimation = NO;
                [progressView dismiss];
                [DYYYUtils showToast:@"沒有照片App，無法儲存原況照片"];

                [fileManager removeItemAtPath:livePhotoPath error:nil];

                if (completion) {
                    completion(0, livePhotos.count);
                }
              });
          }
        }];
      };

      // 第一階段：批量下載所有圖片
      dispatch_group_t imageDownloadGroup = dispatch_group_create();
      updateProgress(@"正在下載圖片...");

      for (NSInteger i = 0; i < livePhotos.count; i++) {
          NSDictionary *livePhoto = downloadedFiles[i];
          NSString *imageURLString = livePhoto[@"imageURL"];
          NSURL *imageURL = [NSURL URLWithString:imageURLString];

          if (!imageURL) {
              completedSteps += 4;  // 圖片下載占4步
              continue;
          }

          dispatch_group_enter(imageDownloadGroup);

          // 建立檔案路徑
          NSString *uniqueID = [NSUUID UUID].UUIDString;
          NSString *imagePath = [livePhotoPath stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.heic", uniqueID]];

          // 配置下載會話
          NSURLSessionConfiguration *configuration = [NSURLSessionConfiguration defaultSessionConfiguration];
          configuration.timeoutIntervalForRequest = 60.0;
          NSURLSession *session = [NSURLSession sessionWithConfiguration:configuration];

          NSURLSessionDataTask *imageTask = [session dataTaskWithURL:imageURL
                                                   completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
                                                     if (!error && data) {
                                                         if ([data writeToFile:imagePath atomically:YES]) {
                                                             NSMutableDictionary *updatedInfo = [downloadedFiles[i] mutableCopy];
                                                             updatedInfo[@"imagePath"] = imagePath;
                                                             downloadedFiles[i] = updatedInfo;
                                                         }
                                                     }

                                                     completedSteps += 4;  // 圖片下載占4步
                                                     updateProgress([NSString stringWithFormat:@"已下載圖片 %ld/%ld", (long)(i + 1), (long)livePhotos.count]);
                                                     dispatch_group_leave(imageDownloadGroup);
                                                   }];

          [imageTask resume];
      }

      // 所有圖片下載完成後，開始下載影片
      dispatch_group_notify(imageDownloadGroup, dispatch_get_main_queue(), ^{
        phase = 1;  // 進入影片下載階段
        updateProgress(@"正在下載影片...");

        dispatch_group_t videoDownloadGroup = dispatch_group_create();

        for (NSInteger i = 0; i < livePhotos.count; i++) {
            NSDictionary *fileInfo = downloadedFiles[i];

            // 只處理圖片下載成功的項
            if ([fileInfo[@"imagePath"] isKindOfClass:[NSNull class]]) {
                completedSteps += 4;  // 影片下載占4步
                continue;
            }

            NSString *videoURLString = fileInfo[@"videoURL"];
            NSURL *videoURL = [NSURL URLWithString:videoURLString];

            if (!videoURL) {
                completedSteps += 4;  // 影片下載占4步
                continue;
            }

            dispatch_group_enter(videoDownloadGroup);

            // 使用與圖片相同的ID但不同的副檔名
            NSString *imagePath = fileInfo[@"imagePath"];
            NSString *baseName = [[imagePath lastPathComponent] stringByDeletingPathExtension];
            NSString *videoPath = [livePhotoPath stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.mp4", baseName]];

            // 配置下載會話
            NSURLSessionConfiguration *configuration = [NSURLSessionConfiguration defaultSessionConfiguration];
            configuration.timeoutIntervalForRequest = 60.0;
            NSURLSession *session = [NSURLSession sessionWithConfiguration:configuration];

            NSURLSessionDataTask *videoTask = [session dataTaskWithURL:videoURL
                                                     completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
                                                       if (!error && data) {
                                                           if ([data writeToFile:videoPath atomically:YES]) {
                                                               NSMutableDictionary *updatedInfo = [downloadedFiles[i] mutableCopy];
                                                               updatedInfo[@"videoPath"] = videoPath;
                                                               downloadedFiles[i] = updatedInfo;
                                                           }
                                                       }

                                                       completedSteps += 4;  // 影片下載占4步
                                                       updateProgress([NSString stringWithFormat:@"已下載影片 %ld/%ld", (long)(i + 1), (long)livePhotos.count]);
                                                       dispatch_group_leave(videoDownloadGroup);
                                                     }];

            [videoTask resume];
        }

        // 所有影片下載完成後，開始合成原況照片
        dispatch_group_notify(videoDownloadGroup, dispatch_get_main_queue(), ^{
          phase = 2;  // 進入合成階段
          finishProcess();
        });
      });
    });
}

// 使用本地變數處理影片
- (void)addMetadataToVideoWithLocalVars:(NSURL *)videoURL
                             outputFile:(NSString *)outputFile
                             identifier:(NSString *)identifier
                                 reader:(AVAssetReader **)readerPtr
                                 writer:(AVAssetWriter **)writerPtr
                                  queue:(dispatch_queue_t)queue
                                  group:(dispatch_group_t)group
                               complete:(void (^)(BOOL success, NSString *photoFile, NSString *videoFile, NSError *error))complete {
    NSError *error = nil;
    AVAsset *asset = [AVAsset assetWithURL:videoURL];
    AVAssetReader *reader = [AVAssetReader assetReaderWithAsset:asset error:&error];
    if (error) {
        if (complete)
            complete(NO, nil, nil, error);
        return;
    }

    *readerPtr = reader;

    NSMutableArray<AVMetadataItem *> *metadata = asset.metadata.mutableCopy;
    AVMetadataItem *item = [self createContentIdentifierMetadataItem:identifier];
    [metadata addObject:item];
    NSURL *videoFileURL = [NSURL fileURLWithPath:outputFile];
    [self deleteFile:outputFile];

    AVAssetWriter *writer = [AVAssetWriter assetWriterWithURL:videoFileURL fileType:AVFileTypeQuickTimeMovie error:&error];
    if (error) {
        if (complete)
            complete(NO, nil, nil, error);
        return;
    }

    *writerPtr = writer;
    [writer setMetadata:metadata];

    NSArray<AVAssetTrack *> *tracks = [asset tracks];
    for (AVAssetTrack *track in tracks) {
        NSDictionary *readerOutputSettings = nil;
        NSDictionary *writerOuputSettings = nil;
        if ([track.mediaType isEqualToString:AVMediaTypeAudio]) {
            readerOutputSettings = @{AVFormatIDKey : @(kAudioFormatLinearPCM)};
            writerOuputSettings = @{AVFormatIDKey : @(kAudioFormatMPEG4AAC), AVSampleRateKey : @(44100), AVNumberOfChannelsKey : @(2), AVEncoderBitRateKey : @(128000)};
        }

        AVAssetReaderTrackOutput *output = [AVAssetReaderTrackOutput assetReaderTrackOutputWithTrack:track outputSettings:readerOutputSettings];
        AVAssetWriterInput *input = [AVAssetWriterInput assetWriterInputWithMediaType:track.mediaType outputSettings:writerOuputSettings];

        if ([reader canAddOutput:output] && [writer canAddInput:input]) {
            [reader addOutput:output];
            [writer addInput:input];
        }
    }

    AVAssetWriterInput *input = [self createStillImageTimeAssetWriterInput];
    AVAssetWriterInputMetadataAdaptor *adaptor = [AVAssetWriterInputMetadataAdaptor assetWriterInputMetadataAdaptorWithAssetWriterInput:input];
    if ([writer canAddInput:input]) {
        [writer addInput:input];
    }

    [writer startWriting];
    [writer startSessionAtSourceTime:kCMTimeZero];
    [reader startReading];

    AVMetadataItem *timedItem = [self createStillImageTimeMetadataItem];
    CMTimeRange timedRange = CMTimeRangeMake(kCMTimeZero, CMTimeMake(1, 100));
    AVTimedMetadataGroup *timedMetadataGroup = [[AVTimedMetadataGroup alloc] initWithItems:@[ timedItem ] timeRange:timedRange];
    [adaptor appendTimedMetadataGroup:timedMetadataGroup];

    for (NSInteger i = 0; i < reader.outputs.count; ++i) {
        dispatch_group_enter(group);
        [self writeTrackWithLocalVars:i reader:reader writer:writer queue:queue group:group];
    }

    dispatch_group_notify(group, dispatch_get_main_queue(), ^{
      [reader cancelReading];
      [writer finishWritingWithCompletionHandler:^{
        AVAssetWriterStatus status = writer.status;
        if (status == AVAssetWriterStatusCompleted) {
            NSString *photoName = [[videoURL lastPathComponent] stringByDeletingPathExtension];
            NSString *photoFile = [self filePathFromTmp:[photoName stringByAppendingPathExtension:@"heic"]];
            if (complete)
                complete(YES, photoFile, outputFile, nil);
        } else {
            if (complete)
                complete(NO, nil, nil, writer.error);
        }
      }];
    });
}

// 處理影片曲目的寫入
- (void)writeTrackWithLocalVars:(NSInteger)trackIndex reader:(AVAssetReader *)reader writer:(AVAssetWriter *)writer queue:(dispatch_queue_t)queue group:(dispatch_group_t)group {
    AVAssetReaderOutput *output = reader.outputs[trackIndex];
    AVAssetWriterInput *input = writer.inputs[trackIndex];

    [input requestMediaDataWhenReadyOnQueue:queue
                                 usingBlock:^{
                                   while (input.readyForMoreMediaData) {
                                       AVAssetReaderStatus status = reader.status;
                                       CMSampleBufferRef buffer = NULL;
                                       if ((status == AVAssetReaderStatusReading) && (buffer = [output copyNextSampleBuffer])) {
                                           BOOL success = [input appendSampleBuffer:buffer];
                                           CFRelease(buffer);
                                           if (!success) {
                                               [input markAsFinished];
                                               dispatch_group_leave(group);
                                               return;
                                           }
                                       } else {
                                           [input markAsFinished];
                                           dispatch_group_leave(group);
                                           return;
                                       }
                                   }
                                 }];
}

+ (void)parseAndDownloadVideoWithShareLink:(NSString *)shareLink apiKey:(NSString *)apiKey {
    if (shareLink.length == 0 || apiKey.length == 0) {
        [DYYYUtils showToast:@"分享連結或API金鑰無效"];
        return;
    }

    NSString *apiUrl = [NSString stringWithFormat:@"%@%@", apiKey, [shareLink stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]]];

    NSURL *url = [NSURL URLWithString:apiUrl];
    NSURLRequest *request = [NSURLRequest requestWithURL:url];
    NSURLSession *session = [NSURLSession sharedSession];

    NSURLSessionDataTask *dataTask = [session dataTaskWithRequest:request
                                                completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
                                                  dispatch_async(dispatch_get_main_queue(), ^{
                                                    if (error) {
                                                        [DYYYUtils showToast:[NSString stringWithFormat:@"接口請求失敗: %@", error.localizedDescription]];
                                                        return;
                                                    }

                                                    NSError *jsonError;
                                                    NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:&jsonError];
                                                    if (jsonError) {
                                                        [DYYYUtils showToast:@"解析接口回傳資料失敗"];
                                                        return;
                                                    }

                                                    NSInteger code = [json[@"code"] integerValue];
                                                    if (code != 0 && code != 200) {
                                                        [DYYYUtils showToast:[NSString stringWithFormat:@"接口回傳錯誤: %@", json[@"msg"] ?: @"未知錯誤"]];
                                                        return;
                                                    }

                                                    NSDictionary *dataDict = json[@"data"];
                                                    if (!dataDict) {
                                                        [DYYYUtils showToast:@"接口回傳資料為空"];
                                                        return;
                                                    }

                                                    // 交給handleVideoData處理資料
                                                    [self handleVideoData:dataDict];
                                                  });
                                                }];

    [dataTask resume];
}

+ (void)handleVideoData:(NSDictionary *)dataDict {
    // 首先檢查videos和images陣列
    NSArray *videoList = dataDict[@"video_list"];
    NSArray *videos = dataDict[@"videos"];
    NSArray *images = dataDict[@"images"];
    NSArray *imgArray = dataDict[@"img"];

    // 取得封面URL
    NSString *coverURL = nil;
    if (dataDict[@"cover"] && [dataDict[@"cover"] length] > 0) {
        coverURL = dataDict[@"cover"];
    } else if (dataDict[@"pics"] && [dataDict[@"pics"] length] > 0) {
        coverURL = dataDict[@"pics"];
    }

    // 嘗試取得音樂URL（供後續下載影片時合併音訊使用）
    NSString *musicURL = nil;
    if (dataDict[@"music"] && [dataDict[@"music"] length] > 0) {
        musicURL = dataDict[@"music"];
    } else if (dataDict[@"music_url"] && [dataDict[@"music_url"] length] > 0) {
        musicURL = dataDict[@"music_url"];
    }

    // 檢查是否有影片列表(優先處理)
    BOOL hasVideoList = [videoList isKindOfClass:[NSArray class]] && videoList.count > 0;
    if (hasVideoList) {
        AWEUserActionSheetView *actionSheet = [[NSClassFromString(@"AWEUserActionSheetView") alloc] init];
        NSMutableArray *actions = [NSMutableArray array];

        for (NSDictionary *videoDict in videoList) {
            NSString *url = videoDict[@"url"];
            NSString *level = videoDict[@"level"];
            if (url.length > 0 && level.length > 0) {
                AWEUserSheetAction *qualityAction = [NSClassFromString(@"AWEUserSheetAction") actionWithTitle:level
                                                                                                      imgName:nil
                                                                                                      handler:^{
                                                                                                        NSURL *videoDownloadUrl = [NSURL URLWithString:url];
                                                                                                        NSURL *optionalAudioURL = nil;
                                                                                                        if (musicURL.length > 0) {
                                                                                                            optionalAudioURL = [NSURL URLWithString:musicURL];
                                                                                                        }
                                                                                                        [self downloadMedia:videoDownloadUrl
                                                                                                                  mediaType:MediaTypeVideo
                                                                                                                      audio:optionalAudioURL
                                                                                                                 completion:^(BOOL success) {
                                                                                                                   if (!success) {
                                                                                                                   }
                                                                                                                 }];
                                                                                                      }];
                [actions addObject:qualityAction];
            }
        }

        if (actions.count > 0) {
            [actionSheet setActions:actions];
            [actionSheet show];
            return;
        }
    }

    // 嘗試取得影片URL
    NSString *singleVideoURL = nil;
    if (dataDict[@"url"] && [dataDict[@"url"] length] > 0) {
        singleVideoURL = dataDict[@"url"];
    } else if (dataDict[@"video"] && [dataDict[@"video"] length] > 0) {
        singleVideoURL = dataDict[@"video"];
    } else if (dataDict[@"video_url"] && [dataDict[@"video_url"] length] > 0) {
        singleVideoURL = dataDict[@"video_url"];
    }

    // 確保處理空的videos陣列
    BOOL hasVideos = [videos isKindOfClass:[NSArray class]] && videos.count > 0;
    BOOL hasImages = [images isKindOfClass:[NSArray class]] && images.count > 0;
    BOOL hasImgArray = [imgArray isKindOfClass:[NSArray class]] && imgArray.count > 0;

    BOOL shouldShowQualityOptions = [[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYShowAllVideoQuality"];

    // 如果只有圖片沒有影片，直接處理圖片下載
    if (!hasVideos && singleVideoURL == nil && (hasImages || hasImgArray || coverURL != nil)) {
        NSMutableArray *allImages = [NSMutableArray array];
        if (hasImages)
            [allImages addObjectsFromArray:images];
        if (hasImgArray)
            [allImages addObjectsFromArray:imgArray];
        if (coverURL && coverURL.length > 0 && ![allImages containsObject:coverURL]) {
            [allImages addObject:coverURL];
        }

        if (allImages.count > 0) {
            if (allImages.count == 1) {
                // 單張圖片直接下載
                NSURL *imageDownloadUrl = [NSURL URLWithString:allImages[0]];
                [self downloadMedia:imageDownloadUrl
                          mediaType:MediaTypeImage
                              audio:nil
                         completion:^(BOOL success) {
                           if (!success) {
                               [DYYYUtils showToast:@"圖片下載失敗"];
                           }
                         }];
            } else {
                // 多張圖片批量下載
                [self downloadAllImages:allImages];
            }
            return;
        }
    }

    // 單個影片情況下的處理
    if (shouldShowQualityOptions && singleVideoURL && singleVideoURL.length > 0) {
        AWEUserActionSheetView *actionSheet = [[NSClassFromString(@"AWEUserActionSheetView") alloc] init];
        NSMutableArray *actions = [NSMutableArray array];

        AWEUserSheetAction *videoAction = [NSClassFromString(@"AWEUserSheetAction") actionWithTitle:@"下載影片"
                                                                                            imgName:nil
                                                                                            handler:^{
                                                                                              NSURL *videoDownloadUrl = [NSURL URLWithString:singleVideoURL];
                                                                                              NSURL *optionalAudioURL = nil;
                                                                                              if (musicURL.length > 0) {
                                                                                                  optionalAudioURL = [NSURL URLWithString:musicURL];
                                                                                              }
                                                                                              [self downloadMedia:videoDownloadUrl
                                                                                                        mediaType:MediaTypeVideo
                                                                                                            audio:optionalAudioURL
                                                                                                       completion:^(BOOL success) {
                                                                                                         if (!success) {
                                                                                                         }
                                                                                                       }];
                                                                                            }];
        [actions addObject:videoAction];

        if (coverURL && coverURL.length > 0) {
            AWEUserSheetAction *coverAction = [NSClassFromString(@"AWEUserSheetAction") actionWithTitle:@"下載封面圖"
                                                                                                imgName:nil
                                                                                                handler:^{
                                                                                                  NSURL *imageDownloadUrl = [NSURL URLWithString:coverURL];
                                                                                                  [self downloadMedia:imageDownloadUrl
                                                                                                            mediaType:MediaTypeImage
                                                                                                                audio:nil
                                                                                                           completion:^(BOOL success) {
                                                                                                             if (!success) {
                                                                                                             }
                                                                                                           }];
                                                                                                }];
            [actions addObject:coverAction];
        }

        if (musicURL && musicURL.length > 0) {
            AWEUserSheetAction *musicAction = [NSClassFromString(@"AWEUserSheetAction") actionWithTitle:@"下載背景音樂"
                                                                                                imgName:nil
                                                                                                handler:^{
                                                                                                  NSURL *audioDownloadUrl = [NSURL URLWithString:musicURL];
                                                                                                  [self downloadMedia:audioDownloadUrl
                                                                                                            mediaType:MediaTypeAudio
                                                                                                                audio:nil
                                                                                                           completion:^(BOOL success) {
                                                                                                             if (!success) {
                                                                                                             }
                                                                                                           }];
                                                                                                }];
            [actions addObject:musicAction];
        }

        // 新增批量下載選項
        NSMutableArray *allImages = [NSMutableArray array];
        if (hasImages)
            [allImages addObjectsFromArray:images];
        if (hasImgArray)
            [allImages addObjectsFromArray:imgArray];
        if (coverURL && coverURL.length > 0 && ![allImages containsObject:coverURL]) {
            [allImages addObject:coverURL];
        }

        if (allImages.count > 0 || singleVideoURL.length > 0) {
            AWEUserSheetAction *batchDownloadAction = [NSClassFromString(@"AWEUserSheetAction") actionWithTitle:@"批次下載所有資源"
                                                                                                        imgName:nil
                                                                                                        handler:^{
                                                                                                          NSMutableArray *singleVideoArray = nil;
                                                                                                          if (singleVideoURL.length > 0) {
                                                                                                              singleVideoArray = [NSMutableArray arrayWithObject:@{@"url" : singleVideoURL}];
                                                                                                          }
                                                                                                          [self batchDownloadResources:singleVideoArray images:allImages];
                                                                                                        }];
            [actions addObject:batchDownloadAction];
        }

        if (actions.count > 0) {
            [actionSheet setActions:actions];
            [actionSheet show];
            return;
        }
    }

    if (!shouldShowQualityOptions && singleVideoURL && singleVideoURL.length > 0) {
        NSURL *videoDownloadUrl = [NSURL URLWithString:singleVideoURL];
        NSURL *optionalAudioURL = nil;
        if (musicURL.length > 0) {
            optionalAudioURL = [NSURL URLWithString:musicURL];
        }
        [self downloadMedia:videoDownloadUrl
                  mediaType:MediaTypeVideo
                      audio:optionalAudioURL
                 completion:^(BOOL success) {
                   if (!success) {
                   }
                 }];
        return;
    }

    // 如果前面的條件都不滿足，嘗試批量下載所有資源
    NSMutableArray *allImages = [NSMutableArray array];
    if (hasImages)
        [allImages addObjectsFromArray:images];
    if (hasImgArray)
        [allImages addObjectsFromArray:imgArray];
    if (coverURL && coverURL.length > 0 && ![allImages containsObject:coverURL]) {
        [allImages addObject:coverURL];
    }

    if (allImages.count > 0 || hasVideos) {
        [self batchDownloadResources:videos images:allImages];
    } else {
        [DYYYUtils showToast:@"沒有找到可下載的資源"];
    }
}

#define DYYYLogVideo(format, ...) NSLog((@"[DYYY影片合成] " format), ##__VA_ARGS__)
// 建立影片合成器從多種媒體來源
+ (void)createVideoFromMedia:(NSArray<NSString *> *)imageURLs
                  livePhotos:(NSArray<NSDictionary *> *)livePhotos
                      bgmURL:(NSString *)bgmURL
                    progress:(void (^)(NSInteger current, NSInteger total, NSString *status))progressBlock
                  completion:(void (^)(BOOL success, NSString *message))completion {
    DYYYLogVideo(@"開始建立影片 - 圖片數量: %lu, 原況照片數量: %lu, 背景音樂: %@", (unsigned long)imageURLs.count, (unsigned long)livePhotos.count, bgmURL.length > 0 ? @"有" : @"無");

    if ((imageURLs.count == 0 && livePhotos.count == 0) || (imageURLs == nil && livePhotos == nil)) {
        DYYYLogVideo(@"錯誤: 沒有提供媒體資源");
        if (completion) {
            completion(NO, @"沒有提供媒體資源");
        }
        return;
    }

    dispatch_async(dispatch_get_main_queue(), ^{
      CGRect screenBounds = [UIScreen mainScreen].bounds;
      DYYYToast *progressView = [[DYYYToast alloc] initWithFrame:screenBounds];
      [progressView show];

      progressView.cancelBlock = ^{
        DYYYLogVideo(@"使用者取消了影片合成");
        [self cancelAllDownloads];
        if (completion) {
            completion(NO, @"使用者取消了操作");
        }
      };

      // 建立暫存目錄
      NSString *mediaPath = [NSTemporaryDirectory() stringByAppendingPathComponent:@"VideoComposition"];
      NSFileManager *fileManager = [NSFileManager defaultManager];
      if ([fileManager fileExistsAtPath:mediaPath]) {
          DYYYLogVideo(@"正在清理舊的暫存目錄: %@", mediaPath);
          [fileManager removeItemAtPath:mediaPath error:nil];
      }

      NSError *dirError = nil;
      [fileManager createDirectoryAtPath:mediaPath withIntermediateDirectories:YES attributes:nil error:&dirError];
      if (dirError) {
          DYYYLogVideo(@"建立暫存目錄失敗: %@", dirError);
          if (completion) {
              completion(NO, @"建立暫存資料夾失敗");
          }
          return;
      }
      DYYYLogVideo(@"成功建立暫存目錄: %@", mediaPath);

      // 計算總共需要下載的檔案數和合成步驟
      NSInteger totalImages = imageURLs.count;
      NSInteger totalLivePhotos = livePhotos.count * 2;  // 每個原況照片有2個檔案
      NSInteger hasBGM = (bgmURL.length > 0) ? 1 : 0;

      // 總步驟：下載所有媒體 + 合成影片 + 儲存影片
      NSInteger totalSteps = totalImages + totalLivePhotos + hasBGM + 2;
      __block NSInteger completedSteps = 0;

      // 儲存下載的媒體檔案路徑
      NSMutableArray *imageFilePaths = [NSMutableArray array];
      NSMutableArray<NSDictionary *> *livePhotoFilePaths = [NSMutableArray array];
      __block NSString *bgmFilePath = nil;

      void (^updateProgress)(NSString *) = ^(NSString *status) {
        float progress = (float)completedSteps / totalSteps;
        dispatch_async(dispatch_get_main_queue(), ^{
          [progressView setProgress:progress];
          DYYYLogVideo(@"進度更新: %.2f%% - %@", progress * 100, status);
          if (progressBlock) {
              progressBlock(completedSteps, totalSteps, status);
          }
        });
      };

      // 第一階段：下載所有普通圖片
      dispatch_group_t imageDownloadGroup = dispatch_group_create();
      updateProgress(@"正在下載圖片...");

      for (NSInteger i = 0; i < imageURLs.count; i++) {
          NSString *imageURLString = imageURLs[i];
          NSURL *imageURL = [NSURL URLWithString:imageURLString];

          if (!imageURL) {
              DYYYLogVideo(@"圖片URL無效: %@", imageURLString);
              completedSteps++;
              updateProgress(@"圖片URL無效");
              continue;
          }

          dispatch_group_enter(imageDownloadGroup);

          // 建立檔案路徑
          NSString *uniqueID = [NSUUID UUID].UUIDString;
          NSString *imagePath = [mediaPath stringByAppendingPathComponent:[NSString stringWithFormat:@"image_%@.jpg", uniqueID]];
          DYYYLogVideo(@"開始下載圖片 %ld/%ld: %@", (long)(i + 1), (long)imageURLs.count, imageURLString);

          // 配置下載會話
          NSURLSessionConfiguration *configuration = [NSURLSessionConfiguration defaultSessionConfiguration];
          NSURLSession *session = [NSURLSession sessionWithConfiguration:configuration];

          NSURLSessionDataTask *imageTask = [session dataTaskWithURL:imageURL
                                                   completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
                                                     if (error) {
                                                         DYYYLogVideo(@"下載圖片失敗 %ld/%ld: %@", (long)(i + 1), (long)imageURLs.count, error);
                                                     } else if (!data) {
                                                         DYYYLogVideo(@"下載圖片資料為空 %ld/%ld", (long)(i + 1), (long)imageURLs.count);
                                                     } else {
                                                         NSInteger dataSize = data.length;
                                                         if ([data writeToFile:imagePath atomically:YES]) {
                                                             DYYYLogVideo(@"成功下載並儲存圖片 %ld/%ld: %@ (大小: %.2f KB)", (long)(i + 1), (long)imageURLs.count, imagePath, dataSize / 1024.0);
                                                             [imageFilePaths addObject:imagePath];
                                                         } else {
                                                             DYYYLogVideo(@"儲存圖片檔案失敗 %ld/%ld: %@", (long)(i + 1), (long)imageURLs.count, imagePath);
                                                         }
                                                     }

                                                     completedSteps++;
                                                     updateProgress([NSString stringWithFormat:@"已下載圖片 %ld/%ld", (long)(i + 1), (long)imageURLs.count]);
                                                     dispatch_group_leave(imageDownloadGroup);
                                                   }];

          [imageTask resume];
      }

      // 第二阶段：下载所有实况照片
      dispatch_group_t livePhotoDownloadGroup = dispatch_group_create();

      dispatch_group_notify(imageDownloadGroup, dispatch_get_main_queue(), ^{
        DYYYLogVideo(@"第一階段完成，已下載 %ld 張圖片", (long)imageFilePaths.count);
        updateProgress(@"正在下載原況照片...");
        DYYYLogVideo(@"開始第二階段: 下載原況照片 (%ld 項)", (long)livePhotos.count);

        for (NSInteger i = 0; i < livePhotos.count; i++) {
            NSDictionary *livePhoto = livePhotos[i];
            NSString *imageURLString = livePhoto[@"imageURL"];
            NSString *videoURLString = livePhoto[@"videoURL"];
            NSURL *imageURL = [NSURL URLWithString:imageURLString];
            NSURL *videoURL = [NSURL URLWithString:videoURLString];

            if (!imageURL || !videoURL) {
                DYYYLogVideo(@"原況照片URL無效: 圖片=%@, 影片=%@", imageURLString, videoURLString);
                completedSteps += 2;
                updateProgress(@"原況照片URL無效");
                continue;
            }

            NSString *uniqueID = [NSUUID UUID].UUIDString;
            NSString *imagePath = [mediaPath stringByAppendingPathComponent:[NSString stringWithFormat:@"livephoto_img_%@.jpg", uniqueID]];
            NSString *videoPath = [mediaPath stringByAppendingPathComponent:[NSString stringWithFormat:@"livephoto_vid_%@.mp4", uniqueID]];

            // 下载图片部分
            dispatch_group_enter(livePhotoDownloadGroup);
            NSURLSessionConfiguration *imgConfig = [NSURLSessionConfiguration defaultSessionConfiguration];
            NSURLSession *imgSession = [NSURLSession sessionWithConfiguration:imgConfig];

            DYYYLogVideo(@"開始下載原況照片圖片部分 %ld/%ld: %@", (long)(i + 1), (long)livePhotos.count, imageURLString);
            NSURLSessionDataTask *imageTask =
                [imgSession dataTaskWithURL:imageURL
                          completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
                            if (error) {
                                DYYYLogVideo(@"下載原況照片圖片部分失敗 %ld/%ld: %@", (long)(i + 1), (long)livePhotos.count, error);
                            } else if (!data) {
                                DYYYLogVideo(@"下載原況照片圖片資料為空 %ld/%ld", (long)(i + 1), (long)livePhotos.count);
                            } else if ([data writeToFile:imagePath atomically:YES]) {
                                DYYYLogVideo(@"成功儲存原況照片圖片部分 %ld/%ld: %@ (大小: %.2f KB)", (long)(i + 1), (long)livePhotos.count, imagePath, data.length / 1024.0);
                            } else {
                                DYYYLogVideo(@"儲存原況照片圖片檔案失敗 %ld/%ld: %@", (long)(i + 1), (long)livePhotos.count, imagePath);
                            }

                            completedSteps++;
                            updateProgress([NSString stringWithFormat:@"已下載原況照片(圖片) %ld/%ld", (long)(i + 1), (long)livePhotos.count]);
                            dispatch_group_leave(livePhotoDownloadGroup);
                          }];
						  
            // 下载视频部分
            dispatch_group_enter(livePhotoDownloadGroup);
            NSURLSessionConfiguration *vidConfig = [NSURLSessionConfiguration defaultSessionConfiguration];
            NSURLSession *vidSession = [NSURLSession sessionWithConfiguration:vidConfig];

            DYYYLogVideo(@"開始下載原況照片影片部分 %ld/%ld: %@", (long)(i + 1), (long)livePhotos.count, videoURLString);
            NSURLSessionDataTask *videoTask =
                [vidSession dataTaskWithURL:videoURL
                          completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
                            if (error) {
                                DYYYLogVideo(@"下載原況照片影片部分失敗 %ld/%ld: %@", (long)(i + 1), (long)livePhotos.count, error);
                            } else if (!data) {
                                DYYYLogVideo(@"下載原況照片影片資料為空 %ld/%ld", (long)(i + 1), (long)livePhotos.count);
                            } else if ([data writeToFile:videoPath atomically:YES]) {
                                DYYYLogVideo(@"成功儲存原況照片影片部分 %ld/%ld: %@ (大小: %.2f MB)", (long)(i + 1), (long)livePhotos.count, videoPath, data.length / (1024.0 * 1024.0));
                                @synchronized(livePhotoFilePaths) {
                                    [livePhotoFilePaths addObject:@{@"image" : imagePath, @"video" : videoPath}];
                                    DYYYLogVideo(@"成功記錄原況照片對: 圖片=%@, 影片=%@", imagePath, videoPath);
                                }
                            } else {
                                DYYYLogVideo(@"儲存原況照片影片檔案失敗 %ld/%ld: %@", (long)(i + 1), (long)livePhotos.count, videoPath);
                            }

                            completedSteps++;
                            updateProgress([NSString stringWithFormat:@"已下載原況照片(影片) %ld/%ld", (long)(i + 1), (long)livePhotos.count]);
                            dispatch_group_leave(livePhotoDownloadGroup);
                          }];

            [imageTask resume];
            [videoTask resume];
        }

        // 第三阶段：下载背景音乐
        dispatch_group_t bgmDownloadGroup = dispatch_group_create();

        dispatch_group_notify(livePhotoDownloadGroup, dispatch_get_main_queue(), ^{
          DYYYLogVideo(@"第二階段完成，已下載 %ld 組原況照片", (long)livePhotoFilePaths.count);

          if (bgmURL.length > 0) {
              DYYYLogVideo(@"開始第三階段: 下載背景音樂 %@", bgmURL);
              updateProgress(@"正在下載背景音樂...");
              NSURL *bgmURL_obj = [NSURL URLWithString:bgmURL];

              if (!bgmURL_obj) {
                  DYYYLogVideo(@"背景音樂URL無效: %@", bgmURL);
                  completedSteps++;
                  updateProgress(@"背景音樂URL無效");
              } else {
                  dispatch_group_enter(bgmDownloadGroup);

                  // 创建文件路径
                  NSString *uniqueID = [NSUUID UUID].UUIDString;
                  NSString *audioPath = [mediaPath stringByAppendingPathComponent:[NSString stringWithFormat:@"bgm_%@.mp3", uniqueID]];

                  // 配置下载会话
                  NSURLSessionConfiguration *configuration = [NSURLSessionConfiguration defaultSessionConfiguration];
                  NSURLSession *session = [NSURLSession sessionWithConfiguration:configuration];

                  NSURLSessionDataTask *audioTask = [session dataTaskWithURL:bgmURL_obj
                                                           completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
                                                             if (error) {
                                                                 DYYYLogVideo(@"下載背景音樂失敗: %@", error);
                                                             } else if (!data) {
                                                                 DYYYLogVideo(@"下載背景音樂資料為空");
                                                             } else if ([data writeToFile:audioPath atomically:YES]) {
                                                                 DYYYLogVideo(@"成功儲存背景音樂: %@ (大小: %.2f MB)", audioPath, data.length / (1024.0 * 1024.0));
                                                                 bgmFilePath = audioPath;
                                                             } else {
                                                                 DYYYLogVideo(@"儲存背景音樂檔案失敗: %@", audioPath);
                                                             }

                                                             completedSteps++;
                                                             updateProgress(@"背景音樂下載完成");
                                                             dispatch_group_leave(bgmDownloadGroup);
                                                           }];

                  [audioTask resume];
              }
          }

          // 第四阶段：合成视频
          dispatch_group_notify(bgmDownloadGroup, dispatch_get_main_queue(), ^{
            DYYYLogVideo(@"第三階段完成，背景音樂狀態: %@", bgmFilePath ? @"已下載" : @"無或下載失敗");
            DYYYLogVideo(@"開始第四階段: 合成影片");
            updateProgress(@"正在合成影片...");

            // 如果没有成功下载任何媒体，则退出
            if (imageFilePaths.count == 0 && livePhotoFilePaths.count == 0) {
                DYYYLogVideo(@"錯誤: 沒有成功下載任何媒體檔案，取消合成");
                progressView.allowSuccessAnimation = NO;
                [progressView dismiss];
                if (completion) {
                    completion(NO, @"沒有成功下載任何媒體檔案");
                }
                [fileManager removeItemAtPath:mediaPath error:nil];
                return;
            }

            DYYYLogVideo(@"媒體檔案統計: %ld張圖片, %ld組原況照片, 背景音樂: %@", (long)imageFilePaths.count, (long)livePhotoFilePaths.count, bgmFilePath ? @"有" : @"无");

            NSString *outputPath = [mediaPath stringByAppendingPathComponent:[NSString stringWithFormat:@"final_%@.mp4", [NSUUID UUID].UUIDString]];
            DYYYLogVideo(@"视频输出路径: %@", outputPath);

            // 使用AVFoundation合成视频
            [self composeVideo:imageFilePaths
                    livePhotos:livePhotoFilePaths
                       bgmPath:bgmFilePath
                    outputPath:outputPath
                    completion:^(BOOL success) {
                      completedSteps++;
                      if (success) {
                          DYYYLogVideo(@"影片合成成功");
                      } else {
                          DYYYLogVideo(@"影片合成失敗");
                      }
                      updateProgress(@"影片合成完成");

                      if (success) {
                          DYYYLogVideo(@"開始儲存影片到照片App");
                          [[PHPhotoLibrary sharedPhotoLibrary]
                              performChanges:^{
                                [PHAssetChangeRequest creationRequestForAssetFromVideoAtFileURL:[NSURL fileURLWithPath:outputPath]];
                              }
                              completionHandler:^(BOOL success, NSError *_Nullable error) {
                                completedSteps++;

                                dispatch_async(dispatch_get_main_queue(), ^{
                                  progressView.allowSuccessAnimation = success;
                                  [progressView dismiss];

                                  if (success) {
                                      DYYYLogVideo(@"影片已成功儲存到照片App");
                                      if (completion) {
                                          completion(YES, @"影片已成功儲存到照片App");
                                      }
                                  } else {
                                      DYYYLogVideo(@"儲存影片到照片App失敗: %@", error);
                                      if (completion) {
                                          completion(NO, [NSString stringWithFormat:@"儲存影片到照片App失敗: %@", error.localizedDescription]);
                                      }
                                  }

                                  DYYYLogVideo(@"清理暫存檔案: %@", mediaPath);
                                  [fileManager removeItemAtPath:mediaPath error:nil];
                                });
                              }];
                      } else {
                          dispatch_async(dispatch_get_main_queue(), ^{
                            progressView.allowSuccessAnimation = NO;
                            [progressView dismiss];
                            if (completion) {
                                completion(NO, @"影片合成失敗");
                            }

                            DYYYLogVideo(@"清理暫存檔案: %@", mediaPath);
                            [fileManager removeItemAtPath:mediaPath error:nil];
                          });
                      }
                    }];
          });
        });
      });
    });
}

// 视频合成核心方法
+ (void)composeVideo:(NSArray<NSString *> *)imageFiles
          livePhotos:(NSArray<NSDictionary *> *)livePhotoFiles
             bgmPath:(NSString *)bgmPath
          outputPath:(NSString *)outputPath
          completion:(void (^)(BOOL success))completion {
    // 影片尺寸（標準1080p）
    CGSize videoSize = CGSizeMake(1080, 1920);
    DYYYLogVideo(@"開始合成影片 - 目標尺寸: %.0fx%.0f", videoSize.width, videoSize.height);
    DYYYLogVideo(@"媒體源: %ld張圖片, %ld組原況照片, 背景音樂: %@", (long)imageFiles.count, (long)livePhotoFiles.count, bgmPath ? @"有" : @"無");

    dispatch_group_t processingGroup = dispatch_group_create();

    // 儲存所有媒體片段資訊
    NSMutableArray *mediaSegments = [NSMutableArray array];

    // 處理靜態圖片 - 先將所有圖片轉換為暫存影片片段
    for (NSInteger i = 0; i < imageFiles.count; i++) {
        NSString *imagePath = imageFiles[i];
        if (![[NSFileManager defaultManager] fileExistsAtPath:imagePath]) {
            DYYYLogVideo(@"錯誤: 圖片檔案不存在: %@", imagePath);
            continue;
        }

        UIImage *image = [UIImage imageWithContentsOfFile:imagePath];
        if (!image) {
            DYYYLogVideo(@"錯誤: 無法載入圖片: %@", imagePath);
            continue;
        }
        DYYYLogVideo(@"處理圖片 %ld/%ld: 尺寸 %.0fx%.0f", (long)(i + 1), (long)imageFiles.count, image.size.width, image.size.height);

        // 創建暫存影片檔案路徑
        NSString *tempVideoPath = [NSTemporaryDirectory() stringByAppendingPathComponent:[NSString stringWithFormat:@"temp_img_%@.mp4", [NSUUID UUID].UUIDString]];

        dispatch_group_enter(processingGroup);

        // 使用Core Animation創建靜態圖片影片
        [self createVideoFromImage:image
                          duration:5.0
                        outputPath:tempVideoPath
                        completion:^(BOOL success) {
                          if (success) {
                              @synchronized(mediaSegments) {
                                  [mediaSegments addObject:@{@"type" : @"image", @"path" : tempVideoPath, @"duration" : @5.0}];
                                  DYYYLogVideo(@"成功建立圖片影片片段 %ld/%ld: %@", (long)(i + 1), (long)imageFiles.count, tempVideoPath);
                              }
                          } else {
                              DYYYLogVideo(@"錯誤: 建立圖片影片片段失敗 %ld/%ld", (long)(i + 1), (long)imageFiles.count);
                          }
                          dispatch_group_leave(processingGroup);
                        }];
    }

    // 處理原況照片 - 收集所有影片路徑資訊
    for (NSInteger i = 0; i < livePhotoFiles.count; i++) {
        NSDictionary *livePhoto = livePhotoFiles[i];
        NSString *imagePath = livePhoto[@"image"];
        NSString *videoPath = livePhoto[@"video"];

        DYYYLogVideo(@"處理原況照片 %ld/%ld: 圖片=%@, 影片=%@", (long)(i + 1), (long)livePhotoFiles.count, imagePath, videoPath);

        if (![[NSFileManager defaultManager] fileExistsAtPath:videoPath]) {
            DYYYLogVideo(@"錯誤: 原況照片影片不存在: %@", videoPath);
            continue;
        }

        [mediaSegments addObject:@{@"type" : @"video", @"path" : videoPath}];
        DYYYLogVideo(@"成功新增原況照片影片片段 %ld/%ld", (long)(i + 1), (long)livePhotoFiles.count);
    }

    // 等待所有暫存影片處理完成
    dispatch_group_notify(processingGroup, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
      DYYYLogVideo(@"所有媒體處理完成，共有 %ld 個可用片段", (long)mediaSegments.count);

      if (mediaSegments.count == 0) {
          DYYYLogVideo(@"錯誤: 沒有有效的媒體片段可以合成");
          if (completion) {
              dispatch_async(dispatch_get_main_queue(), ^{
                completion(NO);
              });
          }
          return;
      }

      // 创建AVMutableComposition作为容器
      DYYYLogVideo(@"開始建立影片合成容器");
      AVMutableComposition *composition = [AVMutableComposition composition];
      AVMutableVideoComposition *videoComposition = [AVMutableVideoComposition videoComposition];
      videoComposition.frameDuration = CMTimeMake(1, 30);  // 30fps
      videoComposition.renderSize = videoSize;

      // 創建影片軌道
      AVMutableCompositionTrack *videoTrack = [composition addMutableTrackWithMediaType:AVMediaTypeVideo preferredTrackID:kCMPersistentTrackID_Invalid];
      if (!videoTrack) {
          DYYYLogVideo(@"錯誤: 無法建立影片軌道");
          if (completion) {
              dispatch_async(dispatch_get_main_queue(), ^{
                completion(NO);
              });
          }
          return;
      }

      // 創建音訊軌道
      AVMutableCompositionTrack *audioTrack = [composition addMutableTrackWithMediaType:AVMediaTypeAudio preferredTrackID:kCMPersistentTrackID_Invalid];
      if (!audioTrack) {
          DYYYLogVideo(@"錯誤: 無法建立音訊軌道");
          if (completion) {
              dispatch_async(dispatch_get_main_queue(), ^{
                completion(NO);
              });
          }
          return;
      }

      // 新增背景音樂
      __block CMTime currentTime = kCMTimeZero;
      if (bgmPath && [[NSFileManager defaultManager] fileExistsAtPath:bgmPath]) {
          DYYYLogVideo(@"新增背景音樂: %@", bgmPath);
          AVAsset *audioAsset = [AVAsset assetWithURL:[NSURL fileURLWithPath:bgmPath]];
          AVAssetTrack *audioAssetTrack = [[audioAsset tracksWithMediaType:AVMediaTypeAudio] firstObject];

          if (audioAssetTrack) {
              // 先處理所有影片片段以確定總時長
              CMTime totalDuration = kCMTimeZero;
              for (NSDictionary *segment in mediaSegments) {
                  NSString *segmentPath = segment[@"path"];
                  AVAsset *asset = [AVAsset assetWithURL:[NSURL fileURLWithPath:segmentPath]];
                  totalDuration = CMTimeAdd(totalDuration, asset.duration);
              }

              // 循環播放背景音樂直到覆蓋整個影片時長
              CMTime audioDuration = audioAsset.duration;
              CMTime currentAudioTime = kCMTimeZero;

              if (CMTimeCompare(audioDuration, totalDuration) < 0) {
                  DYYYLogVideo(@"背景音樂時長(%.2f秒)小於影片時長(%.2f秒)，將循環播放", CMTimeGetSeconds(audioDuration), CMTimeGetSeconds(totalDuration));

                  while (CMTimeCompare(currentAudioTime, totalDuration) < 0) {
                      // 確定當前片段的時長（如果到達影片末尾則截斷）
                      CMTime remainingTime = CMTimeSubtract(totalDuration, currentAudioTime);
                      CMTime segmentDuration = audioDuration;

                      if (CMTimeCompare(remainingTime, audioDuration) < 0) {
                          segmentDuration = remainingTime;
                      }

                      // 插入音訊片段
                      NSError *audioError = nil;
                      [audioTrack insertTimeRange:CMTimeRangeMake(kCMTimeZero, segmentDuration) ofTrack:audioAssetTrack atTime:currentAudioTime error:&audioError];

                      if (audioError) {
                          DYYYLogVideo(@"新增背景音樂循環片段失敗: %@", audioError);
                          break;
                      }

                      DYYYLogVideo(@"新增背景音樂循環片段 - 位置: %.2f秒, 時長: %.2f秒", CMTimeGetSeconds(currentAudioTime), CMTimeGetSeconds(segmentDuration));

                      // 更新當前音訊時間點
                      currentAudioTime = CMTimeAdd(currentAudioTime, segmentDuration);
                  }

                  DYYYLogVideo(@"成功新增循環背景音樂，總時長: %.2f秒", CMTimeGetSeconds(currentAudioTime));
              } else {
                  // 音樂長度足夠，直接新增
                  NSError *audioError = nil;
                  [audioTrack insertTimeRange:CMTimeRangeMake(kCMTimeZero, totalDuration) ofTrack:audioAssetTrack atTime:kCMTimeZero error:&audioError];

                  if (audioError) {
                      DYYYLogVideo(@"新增背景音樂失敗: %@", audioError);
                  } else {
                      DYYYLogVideo(@"成功新增背景音樂，時長: %.2f秒", CMTimeGetSeconds(totalDuration));
                  }
              }
          } else {
              DYYYLogVideo(@"錯誤: 背景音樂沒有有效的音軌");
          }
      }

      NSMutableArray *instructions = [NSMutableArray array];

      // 處理所有媒體片段（按順序）
      DYYYLogVideo(@"開始按順序處理 %ld 個媒體片段", (long)mediaSegments.count);
      for (NSInteger i = 0; i < mediaSegments.count; i++) {
          NSDictionary *segment = mediaSegments[i];
          NSString *segmentType = segment[@"type"];
          NSString *segmentPath = segment[@"path"];

          DYYYLogVideo(@"處理片段 %ld/%ld: 類型=%@, 路徑=%@", (long)(i + 1), (long)mediaSegments.count, segmentType, segmentPath);

          AVAsset *asset = [AVAsset assetWithURL:[NSURL fileURLWithPath:segmentPath]];
          NSArray<AVAssetTrack *> *videoTracks = [asset tracksWithMediaType:AVMediaTypeVideo];

          if (videoTracks.count == 0) {
              DYYYLogVideo(@"錯誤: 媒體片段沒有影片軌道: %@", segmentPath);
              continue;
          }

          AVAssetTrack *assetVideoTrack = videoTracks.firstObject;
          CMTime assetDuration = asset.duration;
          DYYYLogVideo(@"片段 %ld/%ld: 時長=%.2f秒, 尺寸=%.0fx%.0f", (long)(i + 1), (long)mediaSegments.count, CMTimeGetSeconds(assetDuration), assetVideoTrack.naturalSize.width,
                       assetVideoTrack.naturalSize.height);

          // 插入影片片段
          NSError *insertError = nil;
          [videoTrack insertTimeRange:CMTimeRangeMake(kCMTimeZero, assetDuration) ofTrack:assetVideoTrack atTime:currentTime error:&insertError];

          if (insertError) {
              DYYYLogVideo(@"插入影片片段失敗: %@", insertError);
              continue;
          } else {
              DYYYLogVideo(@"成功插入影片片段 %ld/%ld 到位置 %.2f秒", (long)(i + 1), (long)mediaSegments.count, CMTimeGetSeconds(currentTime));
          }

          // 創建影片合成指令
          AVMutableVideoCompositionInstruction *instruction = [AVMutableVideoCompositionInstruction videoCompositionInstruction];
          instruction.timeRange = CMTimeRangeMake(currentTime, assetDuration);

          AVMutableVideoCompositionLayerInstruction *layerInstruction = [AVMutableVideoCompositionLayerInstruction videoCompositionLayerInstructionWithAssetTrack:videoTrack];

          // 計算適當的影片變換
          CGAffineTransform transform = [self transformForAssetTrack:assetVideoTrack targetSize:videoSize];
          [layerInstruction setTransform:transform atTime:currentTime];

          instruction.layerInstructions = @[ layerInstruction ];
          [instructions addObject:instruction];
          DYYYLogVideo(@"新增合成指令: 時間範圍=%.2f到%.2f秒", CMTimeGetSeconds(currentTime), CMTimeGetSeconds(CMTimeAdd(currentTime, assetDuration)));

          // 更新時間點
          currentTime = CMTimeAdd(currentTime, assetDuration);
      }

      // 設定合成指令
      videoComposition.instructions = instructions;
      DYYYLogVideo(@"設定了 %ld 個影片合成指令，總時長: %.2f秒", (long)instructions.count, CMTimeGetSeconds(currentTime));

      // 檢查是否有內容需要匯出
      if (instructions.count == 0 || CMTimeGetSeconds(currentTime) < 0.1) {
          DYYYLogVideo(@"錯誤: 沒有足夠的內容可以匯出");
          if (completion) {
              dispatch_async(dispatch_get_main_queue(), ^{
                completion(NO);
              });
          }

          for (NSDictionary *segment in mediaSegments) {
              if ([segment[@"type"] isEqualToString:@"image"]) {
                  [[NSFileManager defaultManager] removeItemAtPath:segment[@"path"] error:nil];
                  DYYYLogVideo(@"清理暫存圖片影片檔案: %@", segment[@"path"]);
              }
          }
          return;
      }

      // 設定匯出會話
      DYYYLogVideo(@"建立影片匯出會話，使用最高品質編碼");
      AVAssetExportSession *exportSession = [[AVAssetExportSession alloc] initWithAsset:composition presetName:AVAssetExportPresetHighestQuality];
      if (!exportSession) {
          DYYYLogVideo(@"錯誤: 建立匯出會話失敗");
          if (completion) {
              dispatch_async(dispatch_get_main_queue(), ^{
                completion(NO);
              });
          }
          return;
      }

      exportSession.videoComposition = videoComposition;
      exportSession.outputURL = [NSURL fileURLWithPath:outputPath];
      exportSession.outputFileType = AVFileTypeMPEG4;
      exportSession.shouldOptimizeForNetworkUse = YES;

      // 匯出影片
      DYYYLogVideo(@"開始匯出影片到: %@", outputPath);
      [exportSession exportAsynchronouslyWithCompletionHandler:^{
        for (NSDictionary *segment in mediaSegments) {
            if ([segment[@"type"] isEqualToString:@"image"]) {
                NSError *removeError = nil;
                [[NSFileManager defaultManager] removeItemAtPath:segment[@"path"] error:&removeError];
                if (removeError) {
                    DYYYLogVideo(@"清理暫存檔案失敗: %@, 錯誤: %@", segment[@"path"], removeError);
                } else {
                    DYYYLogVideo(@"清理暫存圖片影片檔案: %@", segment[@"path"]);
                }
            }
        }
        switch (exportSession.status) {
            case AVAssetExportSessionStatusCompleted: {
                DYYYLogVideo(@"影片匯出成功: %@", outputPath);

                NSDictionary *fileAttrs = [[NSFileManager defaultManager] attributesOfItemAtPath:outputPath error:nil];
                if (fileAttrs) {
                    unsigned long long fileSize = [fileAttrs fileSize];
                    DYYYLogVideo(@"匯出影片大小: %.2f MB", fileSize / (1024.0 * 1024.0));
                }

                if (completion) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                      completion(YES);
                    });
                }
                break;
            }

            case AVAssetExportSessionStatusFailed: {
                DYYYLogVideo(@"匯出影片失敗: %@", exportSession.error);
                if (completion) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                      completion(NO);
                    });
                }
                break;
            }

            case AVAssetExportSessionStatusCancelled: {
                DYYYLogVideo(@"匯出影片被取消");
                if (completion) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                      completion(NO);
                    });
                }
                break;
            }

            default: {
                DYYYLogVideo(@"匯出影片結束，狀態碼: %ld", (long)exportSession.status);
                if (completion) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                      completion(NO);
                    });
                }
                break;
            }
        }
      }];
    });
}

// 創建從靜態圖片生成的影片片段
+ (void)createVideoFromImage:(UIImage *)image duration:(float)duration outputPath:(NSString *)outputPath completion:(void (^)(BOOL success))completion {
    // 影片尺寸和參數
    CGSize videoSize = CGSizeMake(1080, 1920);
    NSInteger frameRate = 30;

    NSError *error = nil;
    // 設定影片寫入器
    AVAssetWriter *videoWriter = [[AVAssetWriter alloc] initWithURL:[NSURL fileURLWithPath:outputPath] fileType:AVFileTypeMPEG4 error:&error];
    if (error) {
        NSLog(@"建立影片寫入器失敗: %@", error);
        if (completion)
            completion(NO);
        return;
    }

    // 配置影片設定
    NSDictionary *videoSettings = @{
        AVVideoCodecKey : AVVideoCodecTypeH264,
        AVVideoWidthKey : @(videoSize.width),
        AVVideoHeightKey : @(videoSize.height),
        AVVideoCompressionPropertiesKey : @{AVVideoAverageBitRateKey : @(6000000), AVVideoProfileLevelKey : AVVideoProfileLevelH264HighAutoLevel}
    };

    AVAssetWriterInput *writerInput = [AVAssetWriterInput assetWriterInputWithMediaType:AVMediaTypeVideo outputSettings:videoSettings];
    writerInput.expectsMediaDataInRealTime = YES;

    // 創建像素緩衝區適配器
    NSDictionary *sourcePixelBufferAttributes = @{
        (NSString *)kCVPixelBufferPixelFormatTypeKey : @(kCVPixelFormatType_32ARGB),
        (NSString *)kCVPixelBufferWidthKey : @(videoSize.width),
        (NSString *)kCVPixelBufferHeightKey : @(videoSize.height)
    };

    AVAssetWriterInputPixelBufferAdaptor *adaptor = [AVAssetWriterInputPixelBufferAdaptor assetWriterInputPixelBufferAdaptorWithAssetWriterInput:writerInput
                                                                                                                     sourcePixelBufferAttributes:sourcePixelBufferAttributes];

    [videoWriter addInput:writerInput];
    [videoWriter startWriting];
    [videoWriter startSessionAtSourceTime:kCMTimeZero];

    // 不再調整圖片大小，只在需要時適配
    // UIImage *resizedImage = [self resizeImage:image toSize:videoSize];

    // 創建上下文並繪製圖像
    CVPixelBufferRef pixelBuffer = NULL;
    CVPixelBufferPoolCreatePixelBuffer(NULL, adaptor.pixelBufferPool, &pixelBuffer);

    if (pixelBuffer == NULL) {
        // 如果池創建失敗，手動創建像素緩衝區
        NSDictionary *pixelBufferAttributes = @{
            (NSString *)kCVPixelBufferCGImageCompatibilityKey : @YES,
            (NSString *)kCVPixelBufferCGBitmapContextCompatibilityKey : @YES,
            (NSString *)kCVPixelBufferWidthKey : @(videoSize.width),
            (NSString *)kCVPixelBufferHeightKey : @(videoSize.height)
        };
        CVPixelBufferCreate(kCFAllocatorDefault, videoSize.width, videoSize.height, kCVPixelFormatType_32ARGB, (__bridge CFDictionaryRef)pixelBufferAttributes, &pixelBuffer);
    }

    CVPixelBufferLockBaseAddress(pixelBuffer, 0);
    void *pxdata = CVPixelBufferGetBaseAddress(pixelBuffer);

    CGColorSpaceRef rgbColorSpace = CGColorSpaceCreateDeviceRGB();
    CGContextRef context = CGBitmapContextCreate(pxdata, videoSize.width, videoSize.height, 8, CVPixelBufferGetBytesPerRow(pixelBuffer), rgbColorSpace, kCGImageAlphaPremultipliedFirst);

    // 填充背景
    CGContextSetFillColorWithColor(context, [UIColor blackColor].CGColor);
    CGContextFillRect(context, CGRectMake(0, 0, videoSize.width, videoSize.height));

    // 居中繪製圖像，保持原始比例
    CGRect drawRect = [self rectForImageAspectFit:image.size inSize:videoSize];
    CGContextDrawImage(context, drawRect, image.CGImage);

    CGColorSpaceRelease(rgbColorSpace);
    CGContextRelease(context);
    CVPixelBufferUnlockBaseAddress(pixelBuffer, 0);

    // 計算幀數
    NSInteger totalFrames = duration * frameRate;

    // 寫入每一幀
    dispatch_queue_t queue = dispatch_queue_create("com.dyyy.videoframe", DISPATCH_QUEUE_SERIAL);
    dispatch_async(queue, ^{
      BOOL success = YES;
      for (int i = 0; i < totalFrames; i++) {
          if (writerInput.readyForMoreMediaData) {
              CMTime frameTime = CMTimeMake(i, frameRate);
              success = [adaptor appendPixelBuffer:pixelBuffer withPresentationTime:frameTime];
              if (!success) {
                  NSLog(@"無法寫入像素緩衝區");
                  break;
              }
          } else {
              // 如果寫入器未準備好，等待
              usleep(10000);
              i--;
          }
      }

      // 完成影片寫入
      [writerInput markAsFinished];
      [videoWriter finishWritingWithCompletionHandler:^{
        if (pixelBuffer) {
            CVPixelBufferRelease(pixelBuffer);
        }

        if (videoWriter.status == AVAssetWriterStatusCompleted) {
            if (completion)
                completion(YES);
        } else {
            NSLog(@"寫入影片失敗: %@", videoWriter.error);
            if (completion)
                completion(NO);
        }
      }];
    });
}

// 縮放圖片到指定尺寸
+ (UIImage *)resizeImage:(UIImage *)image toSize:(CGSize)size {
    UIGraphicsBeginImageContextWithOptions(size, NO, 0.0);
    [image drawInRect:CGRectMake(0, 0, size.width, size.height)];
    UIImage *resizedImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return resizedImage ?: image;
}

+ (CGRect)rectForImageAspectFit:(CGSize)imageSize inSize:(CGSize)containerSize {
    CGFloat hScale = containerSize.width / imageSize.width;
    CGFloat vScale = containerSize.height / imageSize.height;
    CGFloat scale = MIN(hScale, vScale);  // 使用MIN而不是MAX來保持原始比例

    CGFloat newWidth = imageSize.width * scale;
    CGFloat newHeight = imageSize.height * scale;

    CGFloat x = (containerSize.width - newWidth) / 2.0;
    CGFloat y = (containerSize.height - newHeight) / 2.0;

    return CGRectMake(x, y, newWidth, newHeight);
}

// 計算影片軌道的變換（保持原始比例）
+ (CGAffineTransform)transformForAssetTrack:(AVAssetTrack *)track targetSize:(CGSize)targetSize {
    CGSize trackSize = CGSizeApplyAffineTransform(track.naturalSize, track.preferredTransform);
    trackSize = CGSizeMake(fabs(trackSize.width), fabs(trackSize.height));

    CGFloat xScale = targetSize.width / trackSize.width;
    CGFloat yScale = targetSize.height / trackSize.height;
    CGFloat scale = MIN(xScale, yScale);  // 使用MIN而不是MAX來保持原始比例

    CGAffineTransform transform = track.preferredTransform;
    transform = CGAffineTransformConcat(transform, CGAffineTransformMakeScale(scale, scale));

    // 居中顯示
    CGFloat xOffset = (targetSize.width - trackSize.width * scale) / 2.0;
    CGFloat yOffset = (targetSize.height - trackSize.height * scale) / 2.0;
    transform = CGAffineTransformConcat(transform, CGAffineTransformMakeTranslation(xOffset, yOffset));

    return transform;
}

// 計算圖片的變換（保持原始比例）
+ (CGAffineTransform)transformForImage:(UIImage *)image targetSize:(CGSize)targetSize {
    CGSize imageSize = image.size;

    CGFloat xScale = targetSize.width / imageSize.width;
    CGFloat yScale = targetSize.height / imageSize.height;
    CGFloat scale = MIN(xScale, yScale);

    CGAffineTransform transform = CGAffineTransformIdentity;
    transform = CGAffineTransformScale(transform, scale, scale);

    // 居中顯示
    CGFloat xOffset = (targetSize.width - imageSize.width * scale) / 2.0;
    CGFloat yOffset = (targetSize.height - imageSize.height * scale) / 2.0;
    transform = CGAffineTransformTranslate(transform, xOffset / scale, yOffset / scale);

    return transform;
}

// 動畫貼紙和GIF相關方法遷移自 DYYYUtils.m
+ (void)saveAnimatedSticker:(YYAnimatedImageView *)targetStickerView {
    if (!targetStickerView) {
        [DYYYUtils showToast:@"無法取得表情視圖"];
        return;
    }
    [PHPhotoLibrary requestAuthorization:^(PHAuthorizationStatus status) {
      dispatch_async(dispatch_get_main_queue(), ^{
        if (status != PHAuthorizationStatusAuthorized) {
            [DYYYUtils showToast:@"需要照片App權限才能儲存"];
            return;
        }
        if ([self isBDImageWithHeifURL:targetStickerView.image]) {
            [self saveHeifSticker:targetStickerView];
            return;
        }
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
          NSArray *images = [self getImagesFromYYAnimatedImageView:targetStickerView];
          CGFloat duration = [self getDurationFromYYAnimatedImageView:targetStickerView];
          if (!images || images.count == 0) {
              dispatch_async(dispatch_get_main_queue(), ^{
                [DYYYUtils showToast:@"無法取得表情幀"];
              });
              return;
          }
          NSString *tempPath = [NSTemporaryDirectory() stringByAppendingPathComponent:[NSString stringWithFormat:@"sticker_%ld.gif", (long)[[NSDate date] timeIntervalSince1970]]];
          BOOL success = [self createGIFWithImages:images
                                          duration:duration
                                              path:tempPath
                                          progress:^(float progress){
                                          }];
          dispatch_async(dispatch_get_main_queue(), ^{
            if (!success) {
                return;
            }
            [self saveGIFToPhotoLibrary:tempPath
                             completion:^(BOOL saved, NSError *error) {
                               if (saved) {
                                   [DYYYToast showSuccessToastWithMessage:@"已儲存到照片App"];
                               } else {
                                   NSString *errorMsg = error ? error.localizedDescription : @"未知錯誤";
                                   [DYYYUtils showToast:[NSString stringWithFormat:@"儲存失敗: %@", errorMsg]];
                               }
                             }];
          });
        });
      });
    }];
}
+ (BOOL)isBDImageWithHeifURL:(UIImage *)image {
    if (!image)
        return NO;
    if ([NSStringFromClass([image class]) containsString:@"BDImage"]) {
        if ([image respondsToSelector:@selector(bd_webURL)]) {
            NSURL *webURL = [image performSelector:@selector(bd_webURL)];
            if (webURL) {
                NSString *urlString = webURL.absoluteString;
                return [urlString containsString:@".heif"] || [urlString containsString:@".heic"];
            }
        }
    }
    return NO;
}
+ (void)saveHeifSticker:(YYAnimatedImageView *)stickerView {
    UIImage *image = stickerView.image;
    NSURL *heifURL = [image performSelector:@selector(bd_webURL)];
    if (!heifURL) {
        [DYYYUtils showToast:@"無法取得表情URL"];
        return;
    }
    [DYYYManager convertHeicToGif:heifURL
                       completion:^(NSURL *gifURL, BOOL success) {
                         if (!success || !gifURL) {
                             [DYYYUtils showToast:@"表情轉換失敗"];
                             return;
                         }
                         [[PHPhotoLibrary sharedPhotoLibrary]
                             performChanges:^{
                               PHAssetCreationRequest *request = [PHAssetCreationRequest creationRequestForAsset];
                               [request addResourceWithType:PHAssetResourceTypePhoto fileURL:gifURL options:nil];
                             }
                             completionHandler:^(BOOL success, NSError *_Nullable error) {
                               dispatch_async(dispatch_get_main_queue(), ^{
                                 if (success) {
                                     [DYYYToast showSuccessToastWithMessage:@"已儲存到照片App"];
                                 } else {
                                     NSString *errorMsg = error ? error.localizedDescription : @"未知錯誤";
                                     [DYYYUtils showToast:[NSString stringWithFormat:@"儲存失敗: %@", errorMsg]];
                                 }
                                 NSError *removeError = nil;
                                 [[NSFileManager defaultManager] removeItemAtURL:gifURL error:&removeError];
                                 if (removeError) {
                                     NSLog(@"刪除暫存轉換檔案失敗: %@", removeError);
                                 }
                               });
                             }];
                       }];
}
+ (NSArray *)getImagesFromYYAnimatedImageView:(YYAnimatedImageView *)imageView {
    if (!imageView || !imageView.image) {
        return nil;
    }
    if ([imageView.image respondsToSelector:@selector(images)]) {
        return [imageView.image performSelector:@selector(images)];
    }
    return nil;
}
+ (CGFloat)getDurationFromYYAnimatedImageView:(YYAnimatedImageView *)imageView {
    if (!imageView || !imageView.image) {
        return 0;
    }

    id duration = [imageView.image valueForKey:@"duration"];
    return [duration respondsToSelector:@selector(floatValue)] ? [duration floatValue] : 0;
}
+ (BOOL)createGIFWithImages:(NSArray *)images duration:(CGFloat)duration path:(NSString *)path progress:(void (^)(float progress))progressBlock {
    if (images.count == 0)
        return NO;
    float frameDuration = duration / images.count;
    CGImageDestinationRef destination = CGImageDestinationCreateWithURL((__bridge CFURLRef)[NSURL fileURLWithPath:path], kUTTypeGIF, images.count, NULL);
    if (!destination)
        return NO;
    NSDictionary *gifProperties = @{(__bridge NSString *)kCGImagePropertyGIFDictionary : @{(__bridge NSString *)kCGImagePropertyGIFLoopCount : @0}};
    CGImageDestinationSetProperties(destination, (__bridge CFDictionaryRef)gifProperties);
    for (NSUInteger i = 0; i < images.count; i++) {
        UIImage *image = images[i];
        NSDictionary *frameProperties = @{(__bridge NSString *)kCGImagePropertyGIFDictionary : @{(__bridge NSString *)kCGImagePropertyGIFDelayTime : @(frameDuration)}};
        CGImageDestinationAddImage(destination, image.CGImage, (__bridge CFDictionaryRef)frameProperties);
        if (progressBlock) {
            progressBlock((float)(i + 1) / images.count);
        }
    }
    BOOL success = CGImageDestinationFinalize(destination);
    CFRelease(destination);
    return success;
}
+ (void)saveGIFToPhotoLibrary:(NSString *)path completion:(void (^)(BOOL success, NSError *error))completion {
    NSURL *fileURL = [NSURL fileURLWithPath:path];
    [[PHPhotoLibrary sharedPhotoLibrary]
        performChanges:^{
          PHAssetCreationRequest *request = [PHAssetCreationRequest creationRequestForAsset];
          [request addResourceWithType:PHAssetResourceTypePhoto fileURL:fileURL options:nil];
        }
        completionHandler:^(BOOL success, NSError *_Nullable error) {
          dispatch_async(dispatch_get_main_queue(), ^{
            if (completion) {
                completion(success, error);
            }
            NSError *removeError = nil;
            [[NSFileManager defaultManager] removeItemAtPath:path error:&removeError];
            if (removeError) {
                NSLog(@"刪除暫存GIF檔案失敗: %@", removeError);
            }
          });
        }];
}
@end