//
//  ImageMessage.m
//  MessagesKit
//
//  Created by Kevin Wooten on 1/3/14.
//  Copyright (c) 2014 reTXT Labs, LLC. All rights reserved.
//

#import "ImageMessage.h"

#import "MessageDAO.h"
#import "ExternalFileDataReference.h"
#import "DataReferences.h"
#import "NSObject+Utils.h"
#import "Messages+Exts.h"
#import "NSMutableDictionary+Utils.h"
#import "NSURL+Utils.h"
#import "FMResultSet+Utils.h"
#import "CGSize+Utils.h"
#import "Log.h"

@import AVFoundation;
@import MobileCoreServices;
@import ImageIO;


const CGFloat MK_THUMBNAIL_MAX_PERCENT = 0.5f;


@interface ImageMessage ()

@end


@implementation ImageMessage

-(id) debugQuickLookObject
{
  UIImage *image = [UIImage imageWithData:self.thumbnailOrImageData];
  return image ? image : [@"Unable to load image for message " stringByAppendingString:self.id.description];
}

-(instancetype) initWithId:(Id *)id chat:(Chat *)chat data:(id<DataReference>)data thumbnailData:(nullable NSData *)thumbnailData
{
  self = [super initWithId:id chat:chat];
  if (self) {
    
    self.data = data;
    self.thumbnailData = thumbnailData;
    
  }
  return self;
}

-(instancetype) initWithId:(Id *)id chat:(Chat *)chat data:(id<DataReference>)data
{
  return [self initWithId:id chat:chat data:data thumbnailData:nil];
}

-(instancetype) initWithChat:(Chat *)chat data:(id<DataReference>)data thumbnailData:(nullable NSData *)thumbnailData
{
  return [self initWithId:[Id generate] chat:chat data:data thumbnailData:thumbnailData];
}

-(instancetype) initWithChat:(Chat *)chat data:(id<DataReference>)data
{
  return [self initWithId:[Id generate] chat:chat data:data];
}

-(id) copy
{
  ImageMessage *copy = [super copy];
  copy.data = [self.data copyWithZone:nil];;
  copy.thumbnailData = [self.thumbnailData copyWithZone:nil];
  copy.thumbnailSize = self.thumbnailSize;
  return copy;
}

-(BOOL) isEquivalent:(id)object
{
  if (![object isKindOfClass:[ImageMessage class]]) {
    return NO;
  }
  
  return [self isEquivalentToImageMessage:object];
}

-(BOOL) isEquivalentToImageMessage:(ImageMessage *)imageMessage
{
  return
  [super isEquivalentToMessage:imageMessage] &&
  [DataReferences isDataReference:_data equivalentToDataReference:imageMessage.data] &&
  isEqual(_thumbnailData, imageMessage.thumbnailData) &&
  CGSizeEqualToSize(_thumbnailSize, imageMessage.thumbnailSize);
}

-(void) setData:(id<DataReference>)data
{
  if ([self.data isKindOfClass:ExternalFileDataReference.class]) {
    [NSFileManager.defaultManager removeItemAtURL:[(id)self.data URL] error:nil];
  }
  _data = data;
}

-(NSData *) thumbnailOrImageData
{
  return self.thumbnailData ?: [DataReferences readAllDataFromReference:self.data error:nil];
}

-(NSString *) alertText
{
  return @"Sent you an image";
}

-(NSString *) summaryText
{
  return @"New image";
}

-(BOOL)internalizeDataReferenceWithDAO:(DAO *)dao error:(NSError **)error
{
  NSString *fileName = [NSUUID.UUID.UUIDString stringByAppendingPathExtension:[NSURL extensionForMimeType:self.data.MIMEType]];
  ExternalFileDataReference *externalFileRef = [ExternalFileDataReference.alloc initWithDBManager:dao.dbManager fileName:fileName];
  if (![self.data writeToURL:externalFileRef.URL error:error]) {
    return NO;
  }
  self.data = externalFileRef;
  return YES;
}

-(BOOL)willInsertIntoDAO:(DAO *)dao error:(NSError **)error
{
  return [self internalizeDataReferenceWithDAO:dao error:error];
}

-(BOOL)willUpdateInDAO:(DAO *)dao error:(NSError **)error
{
  return [self internalizeDataReferenceWithDAO:dao error:error];
}

-(BOOL)didDeleteFromDAO:(DAO *)dao error:(NSError **)error
{
  if ([self.data isKindOfClass:ExternalFileDataReference.class]) {
    ExternalFileDataReference *externalFileRef = self.data;
    return [NSFileManager.defaultManager removeItemAtURL:externalFileRef.URL error:error];
  }
  return YES;
}

-(BOOL) load:(FMResultSet *)resultSet dao:(MessageDAO *)dao error:(NSError *__autoreleasing *)error
{
  if (![super load:resultSet dao:dao error:error]) {
    return NO;
  }

  self.thumbnailData = [resultSet dataForColumnIndex:dao.data1FieldIdx];
  self.data = [resultSet dataReferenceForColumnIndex:dao.data2FieldIdx usingDBManager:dao.dbManager];
  self.thumbnailSize = [resultSet sizeForColumnIndex:dao.data3FieldIdx];
  
  return YES;
}

-(BOOL) save:(NSMutableDictionary *)values dao:(DAO *)dao error:(NSError *__autoreleasing *)error
{
  if (![super save:values dao:dao error:error]) {
    return NO;
  }
  
  [values setNillableObject:self.thumbnailData forKey:@"data1"];
  [values setNillableObject:[NSKeyedArchiver archivedDataWithRootObject:self.data] forKey:@"data2"];
  [values setObject:NSStringFromCGSize(self.thumbnailSize) forKey:@"data3"];
  
  return YES;
}

-(MsgType) payloadType
{
  return MsgTypeImage;
}

-(BOOL) exportPayloadIntoData:(id<DataReference>  _Nonnull __autoreleasing *)payloadData withMetaData:(NSDictionary **)metaData error:(NSError **)error
{
  *metaData = @{MetaDataKey_MimeType : self.data.MIMEType ?: @""};
  *payloadData = self.data;
  
  return YES;
}

-(BOOL) importPayloadFromData:(id<DataReference>)payloadData withMetaData:(NSDictionary *)metaData error:(NSError **)error
{
  NSString *MIMEType = metaData[MetaDataKey_MimeType];
  
  id<DataReference> data = [payloadData temporaryDuplicateFilteredBy:nil withMIMEType:MIMEType error:error];
  if (!data) {
    return NO;
  }
  
  self.data = data;
  
  NSData *thumbnailData = [ImageMessage generateThumbnailWithImageData:self.data size:&_thumbnailSize error:error];
  if (!thumbnailData) {
    return NO;
  }
  
  self.thumbnailData = thumbnailData;
  
  return YES;
}

+(NSData *) generateThumbnailWithImageData:(id<DataReference>)imageData size:(CGSize *)outSize error:(NSError **)error
{
  CGSize maxSize = CGSizeScale(UIScreen.mainScreen.bounds.size, MK_THUMBNAIL_MAX_PERCENT);
  CGRect maxRect = {CGPointZero, maxSize};
  
  CGImageSourceRef imageSource = [imageData openImageSourceAndReturnError:error];
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
        
        // Check if we want to draw straight from the image (for GIFs & small images)

        CGRect imageBounds = {CGPointZero, imageOrientedSize};
        CFStringRef imageSourceContainerType = CGImageSourceGetType(imageSource);
        BOOL isGIFData = UTTypeConformsTo(imageSourceContainerType, kUTTypeGIF);
        
        if (isGIFData || CGRectContainsRect(maxRect, imageBounds)) {
          if (outSize) {
            *outSize = imageSize;
          }
          return nil;
        }
        
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

        return thumbnailData;
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

@end
