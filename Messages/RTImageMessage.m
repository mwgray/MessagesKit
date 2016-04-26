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
#import "NSMutableDictionary+Utils.h"
#import "FMResultSet+Utils.h"
#import "CGSize+Utils.h"
#import "RTLog.h"

@import AVFoundation;
@import MobileCoreServices;
@import CoreGraphics;
@import ImageIO;


RT_LUMBERJACK_DECLARE_LOG_LEVEL()


const CGFloat RT_THUMBNAIL_MAX_PERCENT = 0.5f;


@implementation RTImageMessage

-(id) debugQuickLookObject
{
  UIImage *image = [UIImage imageWithData:[DataReferences readAllDataFromReference:self.thumbnailOrImageData error:nil]];
  return image ? image : [@"Unable to load image for message " stringByAppendingString:self.id.description];
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
  if (self.data && !(self.data = [self internalizeData:self.data dbManager:dao.dbManager error:error])) {
    return NO;
  }
  if (self.thumbnailData && !(self.thumbnailData = [self internalizeData:self.thumbnailData dbManager:dao.dbManager error:error])) {
    return NO;
  }
  
  [values setNillableObject:self.thumbnailData forKey:@"data1"];
  [values setNillableObject:self.data forKey:@"data2"];
  [values setObject:NSStringFromCGSize(self.thumbnailSize) forKey:@"data3"];
  [values setNillableObject:self.dataMimeType forKey:@"data4"];
  
  return YES;
}

-(void) delete
{
  NSError *error;
  if (![_data deleteAndReturnError:&error]) {
    DDLogError(@"Unable to delete video data: %@", self.data);
  }
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
         isEqual(self.data, imageMessage.data) &&
         isEqual(self.dataMimeType, imageMessage.dataMimeType) &&
         isEqual(self.thumbnailData, imageMessage.thumbnailData) &&
         CGSizeEqualToSize(self.thumbnailSize, imageMessage.thumbnailSize);
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

-(NSString *) alertText
{
  return @"Sent you an image";
}

-(NSString *) summaryText
{
  return @"New image";
}

-(void) setData:(id<DataReference>)data
{
  if (_data) {
    [_data deleteAndReturnError:nil];
  }
  
  _data = data;
}

-(id<DataReference>) thumbnailOrImageData
{
  return self.thumbnailData ? self.thumbnailData : self.data;
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

  _thumbnailData = [RTImageMessage generateThumbnailWithData:payloadData size:&_thumbnailSize];
  
  return YES;
}

+(id<DataReference>) generateThumbnailWithData:(id<DataReference>)imageData size:(CGSize *)outSize
{
  CGSize maxSize = CGSizeScale(UIScreen.mainScreen.bounds.size, RT_THUMBNAIL_MAX_PERCENT);
  CGRect maxRect = {CGPointZero, maxSize};

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

      CGImageDestinationRef thumbnailDest = CGImageDestinationCreateWithData((__bridge CFMutableDataRef)thumbnailData, CGImageSourceGetType(imageSource), 1, NULL);
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
