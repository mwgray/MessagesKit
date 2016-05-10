//
//  DBCodeMigrations.m
//  MessagesKit
//
//  Created by Kevin Wooten on 1/20/15.
//  Copyright (c) 2015 reTXT Labs, LLC. All rights reserved.
//

#import "DBCodeMigrations.h"


@implementation DBRelativizeDocumentURLs

-(NSString *) path
{
  return @"Migrations/Message";
}

-(NSString *) name
{
  return @"relativize_document_urls";
}

-(uint64_t) version
{
  return 3;
}

-(BOOL) migrateDatabase:(FMDatabase *)database error:(out NSError *__autoreleasing *)error
{
  [self executeForField:@"data1" withDatabase:database];
  [self executeForField:@"data2" withDatabase:database];
  [self executeForField:@"data3" withDatabase:database];
  [self executeForField:@"data4" withDatabase:database];
  return YES;
}

-(void) executeForField:(NSString *)field withDatabase:(FMDatabase *)database
{
  NSString *getSQL = [NSString stringWithFormat:@"SELECT id, %@ FROM message WHERE %@ LIKE ?", field, field];
  NSString *putSQL = [NSString stringWithFormat:@"UPDATE message SET %@=? WHERE id=?", field];

  NSString *docURLPattern = @"file:///var/mobile/Containers/Data/Application/________-____-____-____-____________/Documents/%";

  FMResultSet *resultSet = [database executeQuery:getSQL, docURLPattern];

  while ([resultSet next]) {

    NSData *dbId = [resultSet dataForColumnIndex:0];
    NSString *docURL = [resultSet stringForColumnIndex:1];
    NSString *docRelPath = [docURL substringFromIndex:docURLPattern.length-1];

    [database executeUpdate:putSQL, docRelPath, dbId];
  }

  [resultSet close];
}

@end
