//
//  RTImageMessage.m
//  ReTxt
//
//  Created by Kevin Wooten on 1/3/14.
//  Copyright (c) 2014 reTXT Labs, LLC. All rights reserved.
//

#import "RTImageMessage.h"

#import "RTMessageDAO.h"
#import "MemoryDataReference.h"
#import "DataReferences.h"
#import "NSObject+Utils.h"
#import "RTMessages+Exts.h"
#import "NSMutableDictionary+Utils.h"
#import "FMResultSet+Utils.h"
#import "CGSize+Utils.h"
#import "RTLog.h"

@import AVFoundation;
@import MobileCoreServices;
@import ImageIO;


const CGFloat RT_THUMBNAIL_MAX_PERCENT = 0.5f;


@implementation RTImageMessage

-(id) debugQuickLookObject
{
  UIImage *image = [UIImage imageWithData:[DataReferences readAllDataFromReference:self.thumbnailOrImageData error:nil]];
  return image ? image : [@"Unable to load image for message " stringByAppendingString:self.id.description];
}

-(instancetype) initWithId:(RTId *)id chat:(RTChat *)chat data:(id<DataReference>)data mimeType:(NSString *)mimeType thumbnailData:(id<DataReference>)thumbnailData
{
  self = [super initWithId:id chat:chat];
  if (self) {
    
    self.data = data;
    self.dataMimeType = mimeType;
    self.thumbnailData = thumbnailData;
    
  }
  return self;
}

-(instancetype) initWithId:(RTId *)id chat:(RTChat *)chat data:(id<DataReference>)data mimeType:(NSString *)mimeType
{
  return [self initWithId:id chat:chat data:data mimeType:mimeType thumbnailData:nil];
}

-(instancetype) initWithChat:(RTChat *)chat data:(id<DataReference>)data mimeType:(NSString *)mimeType thumbnailData:(nullable id<DataReference>)thumbnailData
{
  return [self initWithId:[RTId generate] chat:chat data:data mimeType:mimeType thumbnailData:nil];
}

-(instancetype) initWithChat:(RTChat *)chat data:(id<DataReference>)data mimeType:(NSString *)mimeType
{
  return [self initWithId:[RTId generate] chat:chat data:data mimeType:mimeType];
}

-(id) copy
{
  RTImageMessage *copy = [super copy];
  copy.data = self.data;
  copy.dataMimeType = self.dataMimeType;
  copy.thumbnailData = self.thumbnailData;
  copy.thumbnailSize = self.thumbnailSize;
  return copy;
}

-(BOOL) isEquivalent:(id)object
{
  if (![object isKindOfClass:[RTImageMessage class]]) {
    return NO;
  }
  
  return [self isEquivalentToImageMessage:object];
}

-(BOOL) isEquivalentToImageMessage:(RTImageMessage *)imageMessage
{
  return [super isEquivalentToMessage:imageMessage] &&
    [DataReferences isDataReference:_data equivalentToDataReference:imageMessage.data] &&
    isEqual(_dataMimeType, imageMessage.dataMimeType) &&
    [DataReferences isDataReference:_thumbnailData equivalentToDataReference:imageMessage.thumbnailData] &&
    CGSizeEqualToSize(_thumbnailSize, imageMessage.thumbnailSize);
}

-(void) setData:(id<DataReference>)data
{
  if (_data == data) {
    return;
  }
  
  if (_data) {
    [_data deleteAndReturnError:nil];
  }
  
  _data = [data temporaryDuplicateFilteredBy:nil error:nil];
}

-(void) setOwnedData:(id<DataReference>)ownedData
{
  if (_data == ownedData) {
    return;
  }
  
  if (_data) {
    [_data deleteAndReturnError:nil];
  }
  
  _data = ownedData;
}

-(void) setThumbnailData:(id<DataReference>)thumbnailData
{
  if (_thumbnailData == thumbnailData) {
    return;
  }
  
  if (_thumbnailData) {
    [_thumbnailData deleteAndReturnError:nil];
  }
  
  _thumbnailData = [thumbnailData temporaryDuplicateFilteredBy:nil error:nil];
}

-(void) setOwnedThumbnailData:(id<DataReference>)ownedThumbnailData
{
  self.thumbnailData = nil;
  _thumbnailData = ownedThumbnailData;
}

-(id<DataReference>) thumbnailOrImageData
{
  return self.thumbnailData ? self.thumbnailData : self.data;
}

-(BOOL) load:(FMResultSet *)resultSet dao:(RTMessageDAO *)dao error:(NSError *__autoreleasing *)error
{
  if (![super load:resultSet dao:dao error:error]) {
    return NO;
  }

  self.thumbnailData = [resultSet dataReferenceForColumnIndex:dao.data1FieldIdx forOwner:self.id.description usingDB:dao.dbManager];
  self.data = [resultSet dataReferenceForColumnIndex:dao.data2FieldIdx forOwner:self.id.description usingDB:dao.dbManager];
  self.thumbnailSize = [resultSet sizeForColumnIndex:dao.data3FieldIdx];
  self.dataMimeType = [resultSet stringForColumnIndex:dao.data4FieldIdx];
  
  return YES;
}

-(BOOL) save:(NSMutableDictionary *)values dao:(RTDAO *)dao error:(NSError *__autoreleasing *)error
{
  if (![super save:values dao:dao error:error]) {
    return NO;
  }

  // Internalize data references
  if (_data && !(self.ownedData = [self internalizeData:_data dbManager:dao.dbManager error:error])) {
    return NO;
  }
  
  if (_thumbnailData && !(self.ownedThumbnailData = [self internalizeData:_thumbnailData dbManager:dao.dbManager error:error])) {
    return NO;
  }
  
  [values setNillableObject:self.thumbnailData forKey:@"data1"];
  [values setNillableObject:self.data forKey:@"data2"];
  [values setObject:NSStringFromCGSize(self.thumbnailSize) forKey:@"data3"];
  [values setNillableObject:self.dataMimeType forKey:@"data4"];
  
  return YES;
}

-(BOOL) deleteWithDAO:(RTDAO *)dao error:(NSError *__autoreleasing *)error
{
  if (_data && ![_data deleteAndReturnError:error]) {
    return NO;
  }
  
  if (_thumbnailData && ![_thumbnailData deleteAndReturnError:error]) {
    return NO;
  }
  
  return YES;
}

-(NSString *) alertText
{
  return @"Sent you an image";
}

-(NSString *) summaryText
{
  return @"New image";
}

-(BOOL) exportPayloadIntoData:(id<DataReference>  _Nonnull __autoreleasing *)payloadData withMetaData:(NSDictionary *__autoreleasing  _Nonnull *)metaData error:(NSError * _Nullable __autoreleasing *)error
{
  *metaData = @{RTMetaDataKey_MimeType : self.dataMimeType ?: @""};
  *payloadData = self.data;
  
  return YES;
}

-(BOOL) importPayloadFromData:(id<DataReference>)payloadData withMetaData:(NSDictionary *)metaData error:(NSError * _Nullable __autoreleasing *)error
{
  self.dataMimeType = metaData[RTMetaDataKey_MimeType];
  self.data = payloadData;

  _thumbnailData = [RTImageMessage generateThumbnailWithData:payloadData size:&_thumbnailSize error:error];
  if (!_thumbnailData) {
    return NO;
  }
  
  return YES;
}

+(id<DataReference>) generateThumbnailWithData:(id<DataReference>)imageData size:(CGSize *)outSize error:(NSError **)error
{
  CGSize maxSize = CGSizeScale(UIScreen.mainScreen.bounds.size, RT_THUMBNAIL_MAX_PERCENT);
  CGRect maxRect = {CGPointZero, maxSize};

  NSData *imageSourceData = [DataReferences readAllDataFromReference:imageData error:error];
  if (!imageSourceData) {
    return nil;
  }
  
  CGImageSourceRef imageSource = CGImageSourceCreateWithData((__bridge CFDataRef)[DataReferences readAllDataFromReference:imageData error:nil], NULL);
  if (!imageSource) {
    return nil;
  }
  @try {

    NSDictionary *imageProps = CFBridgingRelease(CGImageSourceCopyPropertiesAtIndex(imageSource, 0, NULL));

    CGSize imageSize = CGSizeMake([imageProps[(__bridge NSString *)kCGImagePropertyPixelWidth] floatValue],
                                  [imageProps[(__bridge NSString *)kCGImagePropertyPixelHeight] floatValue]);

    NSNumber *imageOrientation = imageProps[(__bridge NSString *)kCGImagePropertyOrientation];
    if (!imageOrientation) {
      imageOrientation = @(kCGImagePropertyOrientationUp);
    }

    CGSize imageOrientedSize;

    switch (imageOrientation.intValue) {
    case kCGImagePropertyOrientationUp:
    case kCGImagePropertyOrientationUpMirrored:
    case kCGImagePropertyOrientationDown:
    case kCGImagePropertyOrientationDownMirrored:

      imageOrientedSize = CGSizeMake(imageSize.width, imageSize.height);

      // Check if we want to draw straight from the image

//FIXME
//      CGRect imageBounds = {CGPointZero, imageOrientedSize};
//      if ([FLAnimatedImage isAnimatedGIF:imageSource] || CGRectContainsRect(maxRect, imageBounds)) {
//        if (outSize) {
//          *outSize = imageSize;
//        }
//        return nil;
//      }

      break;

    case kCGImagePropertyOrientationLeftMirrored:
    case kCGImagePropertyOrientationRight:
    case kCGImagePropertyOrientationRightMirrored:
    case kCGImagePropertyOrientationLeft:
      imageOrientedSize = CGSizeMake(imageSize.height, imageSize.width);
      break;
    }

    CGSize imageSizeTarget = AVMakeRectWithAspectRatioInsideRect(imageOrientedSize, maxRect).size;

    // Use file data if it's an animated GIF or its small enough to be a
    //  thumbnail already
    NSDictionary *thumbnailOptions = @{
      (id)kCGImageSourceCreateThumbnailWithTransform : @YES,
      (id)kCGImageSourceThumbnailMaxPixelSize : @(MAX(imageSizeTarget.width, imageSizeTarget.height)),
      (id)kCGImageSourceCreateThumbnailFromImageAlways : @YES,
    };

    CGImageRef thumbnail = CGImageSourceCreateThumbnailAtIndex(imageSource, 0, (__bridge CFDictionaryRef)thumbnailOptions);
    if (!thumbnail) {
      return nil;
    }
    @try {

      if (outSize) {
        outSize->width = CGImageGetWidth(thumbnail);
        outSize->height = CGImageGetHeight(thumbnail);
      }

      NSMutableData *thumbnailData = [NSMutableData data];

      CGImageDestinationRef thumbnailDest = CGImageDestinationCreateWithData((__bridge CFMutableDataRef)thumbnailData, kUTTypePNG, 1, NULL);
      if (!thumbnailDest) {
        return nil;
      }
      @try {

        CGImageDestinationAddImage(thumbnailDest, thumbnail, NULL);

        if (!CGImageDestinationFinalize(thumbnailDest)) {
          return nil;
        }

        return [[MemoryDataReference alloc] initWithData:thumbnailData];
      }
      @finally {
        CFRelease(thumbnailDest);
      }

    }
    @finally {
      CFRelease(thumbnail);
    }
  }
  @finally {
    CFRelease(imageSource);
  }

}

-(RTMsgType) payloadType
{
  return RTMsgTypeImage;
}

@end
