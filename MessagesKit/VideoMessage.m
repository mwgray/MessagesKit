//
//  VideoMessage.m
//  MessagesKit
//
//  Created by Kevin Wooten on 1/3/14.
//  Copyright (c) 2014 reTXT Labs, LLC. All rights reserved.
//

#import "VideoMessage.h"

#import "MessageDAO.h"
#import "ExternalFileDataReference.h"
#import "DataReferences.h"
#import "TBase+Utils.h"
#import "NSURL+Utils.h"
#import "NSObject+Utils.h"
#import "NSMutableDictionary+Utils.h"
#import "FMResultSet+Utils.h"
#import "Messages+Exts.h"
#import "Log.h"

@import ImageIO;
@import MobileCoreServices;
@import AVFoundation;
@import AssetsLibrary;


@interface VideoMessage ()

@end


@implementation VideoMessage

-(instancetype) initWithId:(Id *)id chat:(Chat *)chat data:(id<DataReference>)data thumbnailData:(NSData *)thumbnailData
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

-(instancetype) initWithChat:(Chat *)chat data:(id<DataReference>)data thumbnailData:(NSData *)thumbnailData
{
  return [self initWithId:[Id generate] chat:chat data:data thumbnailData:thumbnailData];
}

-(instancetype) initWithChat:(Chat *)chat data:(id<DataReference>)data
{
  return [self initWithId:[Id generate] chat:chat data:data];
}

-(id) copy
{
  VideoMessage *copy = [super copy];
  copy.data = self.data;
  copy.thumbnailData = self.thumbnailData;
  copy.thumbnailSize = self.thumbnailSize;
  return copy;
}

-(BOOL) isEquivalent:(id)object
{
  if (![object isKindOfClass:[VideoMessage class]]) {
    return NO;
  }
  
  return [self isEquivalentToVideoMessage:object];
}

-(BOOL) isEquivalentToVideoMessage:(VideoMessage *)videoMessage
{
  return
  [super isEquivalentToMessage:videoMessage] &&
  [DataReferences isDataReference:self.data equivalentToDataReference:videoMessage.data] &&
  isEqual(self.thumbnailData, videoMessage.thumbnailData) &&
  CGSizeEqualToSize(self.thumbnailSize, videoMessage.thumbnailSize);
}

-(NSString *) alertText
{
  return @"Sent you a video";
}

-(NSString *) summaryText
{
  return @"New video";
}

-(void) setData:(id<DataReference>)data
{
  if ([self.data isKindOfClass:ExternalFileDataReference.class]) {
    [NSFileManager.defaultManager removeItemAtURL:[(id)self.data URL] error:nil];
  }
  _data = data;
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

-(enum MsgType) payloadType
{
  return MsgTypeVideo;
}

-(BOOL)exportPayloadIntoData:(id<DataReference> *)payloadData withMetaData:(NSDictionary **)metaData error:(NSError **)error
{
  NSURL *srcVideoURL = [NSURL URLForTemporaryFileWithExtension:[NSURL extensionForMimeType:self.data.MIMEType]];
  if (![self.data writeToURL:srcVideoURL error:error]) {
    return NO;
  }
  
  URLDataReference *srcVideoDataRef = [URLDataReference.alloc initWithURL:srcVideoURL];
  
  NSURL *dstVideoURL = [NSURL URLForTemporaryFile];

  [AVURLAsset URLAssetWithURL:srcVideoURL options:nil];
  AVURLAsset *videoAsset = [AVURLAsset URLAssetWithURL:srcVideoURL options:nil];

  AVAssetExportSession *exportSession = [[AVAssetExportSession alloc] initWithAsset:videoAsset presetName:AVAssetExportPresetMediumQuality];
  exportSession.outputURL = dstVideoURL;
  exportSession.outputFileType = AVFileTypeMPEG4;

  //FIXME: [exportSession exportSynchronously];
  
  *metaData = @{MetaDataKey_MimeType: self.data.MIMEType,
                MetaDataKey_ThumbnailFrameTime: @"0"};
  *payloadData = self.data;
  
  [srcVideoDataRef self]; // Extend reference lifetime until here
  
  return YES;
}

-(BOOL)importPayloadFromData:(id<DataReference>)payloadData withMetaData:(NSDictionary *)metaData error:(NSError * _Nullable __autoreleasing *)error
{
  NSString *MIMEType = metaData[MetaDataKey_MimeType];

  NSString *thumbnailFrameTime = metaData[MetaDataKey_ThumbnailFrameTime];

  id<DataReference> data = [payloadData temporaryDuplicateFilteredBy:nil withMIMEType:MIMEType error:error];
  if (!data) {
    return NO;
  }
  
  self.data = data;

  NSData *thumbnailData = [VideoMessage generateThumbnailWithVideoData:self.data
                                                           atFrameTime:thumbnailFrameTime
                                                                  size:&_thumbnailSize
                                                                 error:error];
  if (!thumbnailData) {
    return NO;
  }
  
  return YES;
}

+(NSData *) generateThumbnailWithVideoData:(id<DataReference>)videoData atFrameTime:(NSString *)frameTime size:(CGSize *)size error:(NSError **)error
{
  NSURL *tmpVideoURL = [NSURL URLForTemporaryFileWithExtension:[NSURL extensionForMimeType:videoData.MIMEType]];
  if (![videoData writeToURL:tmpVideoURL error:error]) {
    return nil;
  }
  
  URLDataReference *tmpVideoDataRef = [URLDataReference.alloc initWithURL:tmpVideoURL];
  
  AVURLAsset *as = [AVURLAsset.alloc initWithURL:tmpVideoURL options:nil];
  AVAssetImageGenerator *ima = [AVAssetImageGenerator.alloc initWithAsset:as];
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

    return imgData.copy;
  }
  @finally {
    CFRelease(imgDest);
    CFRelease(imgRef);
  }

  [tmpVideoDataRef self]; // Extend reference lifetime until here
}

@end
