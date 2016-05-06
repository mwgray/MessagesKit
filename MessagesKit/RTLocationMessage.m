//
//  RTLocationMessage.m
//  MessagesKit
//
//  Created by Kevin Wooten on 1/3/14.
//  Copyright (c) 2014 reTXT Labs, LLC. All rights reserved.
//

#import "RTLocationMessage.h"

#import "MemoryDataReference.h"
#import "DataReferences.h"

#import "TBase+Utils.h"
#import "RTMessageDAO.h"
#import "RTMessages+Exts.h"
#import "NSObject+Utils.h"
#import "NSMutableDictionary+Utils.h"

@import MapKit;


const CGSize kRTLocationMessageThumbnailSize = {110, 150};

const CGFloat kRTLocationMessageThumbnailCompressionQuality = 1.0f; // 1.0 max, 0.0 min


@implementation RTLocationMessage

-(instancetype) initWithId:(RTId *)id chat:(RTChat *)chat longitude:(double)longitude latitude:(double)latitude
{
  self = [super init];
  if (self) {
    
    self.longitude = longitude;
    self.latitude = latitude;
    
  }
  return self;
}

-(instancetype) initWithChat:(RTChat *)chat longitude:(double)longitude latitude:(double)latitude
{
  return [self initWithId:[RTId generate] chat:chat longitude:longitude latitude:latitude];
}

-(BOOL) load:(FMResultSet *)resultSet dao:(RTMessageDAO *)dao error:(NSError *__autoreleasing *)error
{
  if (![super load:resultSet dao:dao error:error]) {
    return NO;
  }

  self.latitude = [resultSet doubleForColumnIndex:dao.data1FieldIdx];
  self.longitude = [resultSet doubleForColumnIndex:dao.data2FieldIdx];
  self.thumbnailData = [resultSet dataForColumnIndex:dao.data3FieldIdx];
  self.title = [resultSet stringForColumnIndex:dao.data4FieldIdx];
  
  return YES;
}

-(BOOL) save:(NSMutableDictionary *)values dao:(RTDAO *)dao error:(NSError *__autoreleasing *)error
{
  if (![super save:values dao:dao error:error]) {
    return NO;
  }

  [values setNillableObject:@(self.latitude) forKey:@"data1"];
  [values setNillableObject:@(self.longitude) forKey:@"data2"];
  [values setNillableObject:self.thumbnailData forKey:@"data3"];
  [values setNillableObject:self.title forKey:@"data4"];
  
  return YES;
}

-(BOOL) isEquivalent:(id)object
{
  if (![object isKindOfClass:[RTLocationMessage class]]) {
    return NO;
  }

  return [self isEquivalentToLocationMessage:object];
}

-(BOOL) isEquivalentToLocationMessage:(RTLocationMessage *)locationMessage
{
  return [super isEquivalentToMessage:locationMessage] &&
         (self.latitude == locationMessage.latitude) &&
         (self.longitude == locationMessage.longitude) &&
         isEqual(self.thumbnailData, locationMessage.thumbnailData) &&
         isEqual(self.title, locationMessage.title);
}

-(id) copy
{
  RTLocationMessage *copy = [super copy];
  copy.latitude = self.latitude;
  copy.longitude = self.longitude;
  copy.thumbnailData = self.thumbnailData;
  copy.title = self.title;
  return copy;
}

-(NSString *) alertText
{
  return @"Sent you a location";
}

-(NSString *) summaryText
{
  return @"New location";
}

-(BOOL) exportPayloadIntoData:(id<DataReference>  _Nonnull __autoreleasing *)payloadData withMetaData:(NSDictionary *__autoreleasing  _Nonnull *)metaData error:(NSError * _Nullable __autoreleasing *)error
{

  *metaData = nil;

  RTLocation *location = [RTLocation new];
  location.title = self.title;
  location.longitude = self.longitude;
  location.latitude = self.latitude;

  NSData *data = [TBaseUtils serializeToData:location error:error];
  if (!data) {
    return NO;
  }
  
  *payloadData = [[MemoryDataReference alloc] initWithData:data];
  
  return YES;
}

-(BOOL) importPayloadFromData:(id<DataReference>)payloadData withMetaData:(NSDictionary *)metaData error:(NSError * _Nullable __autoreleasing *)error
{
  NSData *data = [DataReferences readAllDataFromReference:payloadData error:error];
  if (!data) {
    return NO;
  }
  
  RTLocation *location = [TBaseUtils deserialize:[RTLocation new]
                                        fromData:data
                                           error:error];
  if (!location) {
    return NO;
  }

  self.longitude = location.longitude;
  self.latitude = location.latitude;
  self.title = location.title;
  self.thumbnailData = nil;
  
  return YES;
}

-(enum RTMsgType) payloadType
{
  return RTMsgTypeLocation;
}

+(void) generateThumbnailData:(RTLocationMessage *)msg completion:(void (^)(NSData *data, NSError *error))completionBlock
{
  [self generateThumbnailData:msg try:0 completion:completionBlock];
}

+(void) generateThumbnailData:(RTLocationMessage *)msg try:(NSInteger)try completion:(void (^)(NSData *data, NSError *error))completionBlock
{
  MKCoordinateRegion viewRegion = MKCoordinateRegionMakeWithDistance(CLLocationCoordinate2DMake(msg.latitude, msg.longitude), 300, 300);

  MKMapSnapshotOptions *options = [[MKMapSnapshotOptions alloc] init];
  options.region = viewRegion;
  options.scale = [UIScreen mainScreen].scale;
  options.size = CGSizeMake(kRTLocationMessageThumbnailSize.width * options.scale,
                            kRTLocationMessageThumbnailSize.height * options.scale);

  MKMapSnapshotter *snapshotter = [[MKMapSnapshotter alloc] initWithOptions:options];
  [snapshotter startWithQueue:dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0) completionHandler:^(MKMapSnapshot *snapshot, NSError *error) {

    if (!error) {

      UIImage *image = snapshot.image;
      __block MKAnnotationView *pin;
      dispatch_sync(dispatch_get_main_queue(), ^{ pin = [[MKPinAnnotationView alloc] initWithAnnotation:nil reuseIdentifier:@""]; });

      UIImage *pinImage = pin.image;
      UIGraphicsBeginImageContextWithOptions(image.size, YES, image.scale);

      [image drawAtPoint:CGPointMake(0, 0)];

      CGPoint point = [snapshot pointForCoordinate:CLLocationCoordinate2DMake(msg.latitude, msg.longitude)];
      CGPoint pinCenterOffset = pin.centerOffset;
      point.x -= pin.bounds.size.width / 2.0;
      point.y -= pin.bounds.size.height / 2.0;
      point.x += pinCenterOffset.x;
      point.y += pinCenterOffset.y;
      [pinImage drawAtPoint:point];

      UIImage *finalImage = UIGraphicsGetImageFromCurrentImageContext();
      UIGraphicsEndImageContext();

      NSData *data = UIImageJPEGRepresentation(finalImage, kRTLocationMessageThumbnailCompressionQuality);

      completionBlock(data, nil);

    }
    else if (try < 3) {

      NSInteger nextTry = try+1;

      dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
        [self generateThumbnailData:msg try:nextTry completion:completionBlock];
      });

    }
    else {

      completionBlock(nil, error);

    }

  }];

}

@end
