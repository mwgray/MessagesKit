//
//  RTVideoMessage.m
//  ReTxt
//
//  Created by Kevin Wooten on 1/3/14.
//  Copyright (c) 2014 reTXT Labs, LLC. All rights reserved.
//

#import "RTVideoMessage.h"

#import "RTMessageDAO.h"
#import "DataReferences.h"
#import "MemoryDataReference.h"
#import "TBase+Utils.h"
#import "NSURL+Utils.h"
#import "NSObject+Utils.h"
#import "NSMutableDictionary+Utils.h"
#import "FMResultSet+Utils.h"
#import "RTLog.h"

@import ImageIO;
@import MobileCoreServices;
@import AVFoundation;
@import AssetsLibrary;


@interface RTVideoMessage ()

@end


@implementation RTVideoMessage

-(id) copy
{
  RTVideoMessage *copy = [super copy];
  copy.data = self.data;
  copy.dataMimeType = self.dataMimeType;
  copy.thumbnailData = self.thumbnailData;
  copy.thumbnailSize = self.thumbnailSize;
  return copy;
}

-(BOOL) isEquivalent:(id)object
{
  if (![object isKindOfClass:[RTVideoMessage class]]) {
    return NO;
  }
  
  return [self isEquivalentToVideoMessage:object];
}

-(BOOL) isEquivalentToVideoMessage:(RTVideoMessage *)videoMessage
{
  return [super isEquivalentToMessage:videoMessage] &&
    [DataReferences isDataReference:_data equivalentToDataReference:videoMessage.data] &&
    isEqual(_dataMimeType, videoMessage.dataMimeType) &&
    [DataReferences isDataReference:_thumbnailData equivalentToDataReference:videoMessage.thumbnailData] &&
    CGSizeEqualToSize(self.thumbnailSize, videoMessage.thumbnailSize);
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
  return @"Sent you a video";
}

-(NSString *) summaryText
{
  return @"New video";
}

-(BOOL)exportPayloadIntoData:(id<DataReference>  _Nonnull __autoreleasing *)payloadData withMetaData:(NSDictionary *__autoreleasing  _Nonnull *)metaData error:(NSError * _Nullable __autoreleasing *)error
{
  //FIXME move to AVAssetDataReference
//  NSURL *srcVideoURL = self.dataURL;
//  NSURL *dstVideoURL = [NSURL URLForTemporaryFile];
//
//  AVURLAsset *videoAsset = [AVURLAsset URLAssetWithURL:srcVideoURL options:nil];
//
//  AVAssetExportSession *exportSession = [[AVAssetExportSession alloc] initWithAsset:videoAsset presetName:AVAssetExportPresetMediumQuality];
//  exportSession.outputURL = dstVideoURL;
//  exportSession.outputFileType = AVFileTypeMPEG4;
//
//  [exportSession exportSynchronously];
//
  
  *metaData = @{RTMetaDataKey_MimeType: self.dataMimeType ?: @"",
                RTMetaDataKey_ThumbnailFrameTime: @"0"};
  *payloadData = self.data;
  
  return YES;
}

-(BOOL)importPayloadFromData:(id<DataReference>)payloadData withMetaData:(NSDictionary *)metaData error:(NSError * _Nullable __autoreleasing *)error
{
  self.dataMimeType = metaData[RTMetaDataKey_MimeType];

  NSString *thumbnailFrameTime = metaData[RTMetaDataKey_ThumbnailFrameTime];

  self.data = payloadData;
  self.thumbnailData = [RTVideoMessage generateThumbnailWithData:payloadData
                                                     atFrameTime:thumbnailFrameTime
                                                            size:&_thumbnailSize error:error];
  if (!self.thumbnailData) {
    return NO;
  }
  
  return YES;
}

-(enum RTMsgType) payloadType
{
  return RTMsgTypeVideo;
}

+(nullable id<DataReference>) generateThumbnailWithData:(id<DataReference>)videoData atFrameTime:(NSString *)frameTime size:(CGSize *)size error:(NSError * _Nullable __autoreleasing * _Nullable)error
{
  FileDataReference *tempRef = [DataReferences duplicateDataReferenceToTemporaryFile:videoData withExtension:@"mp4" error:error];
  if (!tempRef) {
    return nil;
  }
  
  @try {
  
    AVURLAsset *as = [[AVURLAsset alloc] initWithURL:tempRef.URL options:nil];
    AVAssetImageGenerator *ima = [[AVAssetImageGenerator alloc] initWithAsset:as];
    ima.appliesPreferredTrackTransform = YES;

    CMTime time = frameTime ? CMTimeMake([frameTime doubleValue] * 1000, 1000) : kCMTimeZero;

    CGImageRef imgRef = [ima copyCGImageAtTime:time actualTime:NULL error:error];
    if (!imgRef) {
      return nil;
    }

    size->width = CGImageGetWidth(imgRef);
    size->height = CGImageGetHeight(imgRef);

    NSMutableData *imgData = [NSMutableData data];
    CGImageDestinationRef imgDest = CGImageDestinationCreateWithData((__bridge CFMutableDataRef)(imgData), kUTTypeJPEG, 1, NULL);
    @try {

      CGImageDestinationAddImage(imgDest, imgRef, NULL);
      if (!CGImageDestinationFinalize(imgDest)) {
        return nil;
      }

      return [MemoryDataReference.alloc initWithData:imgData.copy];
    }
    @finally {
      CFRelease(imgDest);
      CFRelease(imgRef);
    }
    
  }
  @finally {
    [tempRef deleteAndReturnError:nil];
  }
  
}

@end
