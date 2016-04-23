//
//  RTSQLBuilder.m
//  ReTxt
//
//  Created by Kevin Wooten on 7/14/14.
//  Copyright (c) 2014 reTXT Labs, LLC. All rights reserved.
//

#import "RTSQLBuilder.h"

#import "RTModel.h"
#import "RTDAO.h"
#import "NSObject+Properties.h"
#import "RTLog.h"


RT_LUMBERJACK_DECLARE_LOG_LEVEL()


@class RTSQLTable;
@class RTSQLJoin;

@protocol RTSQLRelation <NSObject>

@property (nonatomic, readonly) NSString *alias;
@property (nonatomic, readonly) NSString *name;
@property (nonatomic, readonly) RTSQLTable *table;

@end

@interface RTSQLTable : NSObject <RTSQLRelation>

@property (nonatomic, strong) NSString *name;
@property (nonatomic, strong) NSString *alias;
@property (nonatomic, strong) Class modelClass;

-(instancetype) initWithName:(NSString *)name alias:(NSString *)alias modelClass:(Class)modelClass;

@end


@interface RTSQLJoin : NSObject <RTSQLRelation>

@property (nonatomic, readonly) NSString *alias;
@property (nonatomic, strong) RTSQLTable *leftTable;
@property (nonatomic, strong) NSString *leftColumn;
@property (nonatomic, strong) RTSQLTable *rightTable;
@property (nonatomic, strong) NSString *rightColumn;

@end


@implementation RTSQLTable

-(instancetype) initWithName:(NSString *)name alias:(NSString *)alias modelClass:(Class)modelClass
{
  if ((self = [super init])) {
    _name = name;
    _alias = alias;
    _modelClass = modelClass;
  }
  return self;
}

-(RTSQLTable *) table
{
  return self;
}

-(NSString *) description
{
  return [NSString stringWithFormat:@"FROM %@ AS %@", _name, _alias];
}

@end


@implementation RTSQLJoin

-(NSString *) alias
{
  return _leftTable.alias;
}

-(RTSQLTable *) table
{
  return _leftTable;
}

-(NSString *) name
{
  return _leftTable.alias;
}

-(NSString *) description
{
  return [NSString stringWithFormat:@"JOIN %@ AS %@ ON %@.%@ = %@.%@", _leftTable.name, _leftTable.alias, _leftTable.alias, _leftColumn, _rightTable.alias, _rightColumn];
}

@end


NSString *SQLNullValueString = @"NULL";

NSDictionary *setOperations;
NSDictionary *binaryFunctions;
NSDictionary *unaryFunctions;
NSDictionary *nullaryFunctions;


@interface RTSQLBuilder () {
  NSMutableDictionary *_parameters;
}

@property (nonatomic, strong) NSMutableArray *relationStack;
@property (nonatomic, strong) NSDictionary *classTableNames;
@property (nonatomic, strong) NSMutableSet *aliases;
@property (nonatomic, strong) NSMutableArray *relations;

@end


@implementation RTSQLBuilder

@dynamic parameters;

+(void) initialize
{
  nullaryFunctions = @{@"now"    : @"date('now')",
                       @"random"   : @"random()"};

  unaryFunctions = @{@"uppercase:" : @"upper",
                     @"lowercase:" : @"lower",
                     @"abs:"       : @"abs"};

  binaryFunctions = @{@"add:to:"              : @"+",
                      @"from:subtract:"       : @"-",
                      @"multiply:by:"         : @"*",
                      @"divide:by:"           : @"/",
                      @"modulus:by:"          : @"%",
                      @"leftshift:by"         : @"<<",
                      @"rightshift:by:"       : @">>"};

  setOperations = @{@"@avg" : @"avg",
                    @"@max" : @"max",
                    @"@min" : @"min",
                    @"@sum" : @"sum",
                    @"@distinctUnionOfObjects" : @"distinct"};
}

-(instancetype) initWithRootClass:(NSString *)rootClassName tableNames:(NSDictionary *)tableNames;
{
  Class rootClass = NSClassFromString(rootClassName);
  if (!rootClass) {
    return nil;
  }

  if ((self = [super init])) {

    _classTableNames = tableNames;
    _parameters = [NSMutableDictionary dictionary];
    _relationStack = [NSMutableArray array];
    _relations = [NSMutableArray array];
    _aliases = [NSMutableSet set];

    [_relations addObject:[[RTSQLTable alloc] initWithName:tableNames[rootClassName]
                                                     alias:[self aliasForTable:tableNames[rootClassName]]
                                                modelClass:rootClass]];
    [_relationStack addObject:[_relations lastObject]];
  }

  return self;
}

-(NSDictionary *) parameters
{
  return _parameters;
}

-(Class) classForProperty:(NSString *)propertyName of:(Class)sourceClass
{
  NSString *type = [sourceClass typeOfPropertyNamed:propertyName];
  if (![type hasPrefix:@"T@"]) {
    return nil;
  }

  NSString *className = [type substringWithRange:NSMakeRange(3, type.length-4)];
  if ([className isEqualToString:@""]) {
    className = @"NSObject";
  }

  return NSClassFromString(className);
}

-(NSString *) aliasForTable:(NSString *)tableName
{
  NSArray *parts = [[tableName lowercaseString] componentsSeparatedByString:@"_"];

  NSString *prefix = @"";
  for (NSString *part in parts) {
    prefix = [prefix stringByAppendingString:[part substringToIndex:1]];
  }

  for (int c=1; c < 100; ++c) {
    NSString *test = [prefix stringByAppendingFormat:@"%ld", (long)c];
    if (![_aliases containsObject:test]) {
      [_aliases addObject:test];
      return test;
    }
  }
  return tableName;
}


-(NSString *) expressionForKeyPath:(NSString *)keyPath
{

  NSArray *keyPathParts = [keyPath componentsSeparatedByString:@"."];

  if (keyPathParts.count == 1) {

    id<RTSQLRelation> relation = [_relationStack lastObject];

    return [NSString stringWithFormat:@"%@.%@", relation.alias, keyPath];
  }

  // Is it an aggregate function?

  if (setOperations[[keyPathParts lastObject]]) {

    NSString *setOp = [keyPathParts lastObject];
    NSArray *setTargetParts = [keyPathParts subarrayWithRange:NSMakeRange(0, keyPathParts.count-1)];
    NSString *setTarget = [setTargetParts componentsJoinedByString:@"."];

    setTarget = [self expressionForKeyPath:setTarget];

    return [NSString stringWithFormat:@"%@(%@)", setOperations[setOp], setTarget];
  }

  // Join syntax

  NSString *joinColumn = [keyPathParts firstObject];

  NSArray *remainingKeyPathParts = [keyPathParts subarrayWithRange:NSMakeRange(1, keyPathParts.count-1)];
  NSString *remainingKeyPath = [remainingKeyPathParts componentsJoinedByString:@"."];

  Class tableModelClass = [self classForProperty:joinColumn of:[[_relationStack lastObject] modelClass]];
  if (!tableModelClass) {
    return nil;
  }

  NSString *tableName = _classTableNames[NSStringFromClass(tableModelClass)];
  NSString *tableAlias = [self aliasForTable:tableName];

  RTSQLTable *table = [RTSQLTable new];
  table.modelClass = tableModelClass;
  table.name = tableName;
  table.alias = tableAlias;

  RTSQLJoin *join = [RTSQLJoin new];
  join.leftTable = table;
  join.leftColumn = @"id";
  join.rightTable = [_relationStack lastObject];
  join.rightColumn = joinColumn;

  [_relations addObject:join];

  [_relationStack addObject:join];

  NSString *comparisonField = [self expressionForKeyPath:remainingKeyPath];

  [_relationStack removeLastObject];


  return comparisonField;
}

-(NSString *) declaredExpressionForKeyPath:(NSString *)keyPath
{

  NSArray *keyPathParts = [keyPath componentsSeparatedByString:@"."];

  if (keyPathParts.count == 1) {

    id<RTSQLRelation> relation = [_relationStack lastObject];

    return [NSString stringWithFormat:@"%@.%@", relation.alias, keyPath];
  }

  // Join syntax

  NSString *joinColumn = [keyPathParts firstObject];

  NSArray *remainingKeyPathParts = [keyPathParts subarrayWithRange:NSMakeRange(1, keyPathParts.count-1)];
  NSString *remainingKeyPath = [remainingKeyPathParts componentsJoinedByString:@"."];

  Class tableModelClass = [self classForProperty:joinColumn of:[[_relationStack lastObject] modelClass]];
  if (!tableModelClass) {
    return nil;
  }

  NSString *tableName = _classTableNames[NSStringFromClass(tableModelClass)];

  for (id<RTSQLRelation> relation in _relations) {

    if ([relation.table.name isEqualToString:tableName]) {

      [_relationStack addObject:relation];

      NSString *res = [self declaredExpressionForKeyPath:remainingKeyPath];

      [_relationStack removeLastObject];

      return res;

    }
  }

  // Try and build a new one since we couldn't find an already declared one
  return [self expressionForKeyPath:keyPath];
}

-(NSString *) selectClauseForSubqueryExpression:(NSExpression *)expression
{
  NSString *retStr = nil;
  return retStr;
}

-(NSString *) literalListForArray:(NSArray *)array
{

  NSMutableArray *retArray = [NSMutableArray array];

  for (NSExpression *obj in array) {
    [retArray addObject:[self expressionForNSExpression:obj]];
  }

  return [NSString stringWithFormat:@"(%@)", [retArray componentsJoinedByString:@","]];
}

-(NSString *) namedReplacementVariableForVariable:(NSString *)var
{
  return var;
}

-(id) convertValue:(id)val
{
  if ([val isKindOfClass:[RTModel class]]) {
    return [val dbId];
  }

  if ([val isKindOfClass:[RTId class]]) {
    return [val data];
  }

  if (class_isMetaClass(object_getClass(val))) {
    if ([val respondsToSelector:@selector(typeCode)]) {
      return @([val typeCode]);
    }
    DDLogWarn(@"Class does not support typeCode using name");
    return NSStringFromClass(val);
  }

  return val;
}

-(NSString *) constantForValue:(id)val
{
  NSString *key = @(_parameters.count).stringValue;
  val = [self convertValue:val];

  [_parameters setObject:val ? val : [NSNull null] forKey:key];

  return [@":" stringByAppendingString:key];
}

-(NSString *) functionLiteralForFunctionExpression:(NSExpression *)exp
{

  NSString *retStr = nil;

  if (nullaryFunctions[[exp function]]) {

    retStr = nullaryFunctions[[exp function]];
  }
  else if (unaryFunctions[[exp function]]) {

    retStr = [NSString stringWithFormat:@"%@(%@)",
              unaryFunctions[[exp function]],
              [self expressionForNSExpression:exp.arguments[0]]];
  }
  else if (binaryFunctions[[exp function]]) {

    retStr = [NSString stringWithFormat:@"(%@ %@ %@)",
              [self expressionForNSExpression:exp.arguments[0]],
              binaryFunctions[[exp function]],
              [self expressionForNSExpression:exp.arguments[1]]];
  }
  else {
    DDLogError(@"the expression %@ could not be converted because "
               "it uses an unconvertible function %@", exp, [exp function]);
  }

  return retStr;
}

-(NSString *) expressionForNSExpression:(NSExpression *)expression
{
  NSString *retStr = nil;

  switch ([expression expressionType]) {
  case NSConstantValueExpressionType:
    retStr = [self constantForValue:[expression constantValue]];
    break;

  case NSVariableExpressionType:
    retStr = [self namedReplacementVariableForVariable:[expression variable]];
    break;

  case NSKeyPathExpressionType:
    retStr = [self expressionForKeyPath:[expression keyPath]];
    break;

  case NSFunctionExpressionType:
    retStr = [self functionLiteralForFunctionExpression:expression];
    break;

  case NSSubqueryExpressionType:
    retStr = [self selectClauseForSubqueryExpression:expression];
    break;

  case NSAggregateExpressionType:
    retStr = [self literalListForArray:[expression collection]];
    break;

  case NSUnionSetExpressionType:
  case NSIntersectSetExpressionType:
  case NSMinusSetExpressionType:
  case NSAnyKeyExpressionType:
  case NSConditionalExpressionType:
    // TODO
    break;

  /* these can't be converted */
  case NSEvaluatedObjectExpressionType:
  case NSBlockExpressionType:
    DDLogError(@"the expression could not be converted because "
               "it is a selector or block expression");
    break;
  }
  return retStr;
}

-(NSString *) infixOperatorForOperatorType:(NSPredicateOperatorType)type
{
  NSString *comparator = nil;
  switch (type) {
  case NSLessThanPredicateOperatorType:               comparator = @"<";      break;

  case NSLessThanOrEqualToPredicateOperatorType:      comparator = @"<=";     break;

  case NSGreaterThanPredicateOperatorType:            comparator = @">";      break;

  case NSGreaterThanOrEqualToPredicateOperatorType:   comparator = @">=";     break;

  case NSEqualToPredicateOperatorType:                comparator = @"IS";     break;

  case NSNotEqualToPredicateOperatorType:             comparator = @"IS NOT"; break;

  case NSMatchesPredicateOperatorType:                comparator = @"MATCH";  break;

  case NSInPredicateOperatorType:                     comparator = @"IN";     break;

  case NSBetweenPredicateOperatorType:                comparator = @"BETWEEN"; break;

  case NSLikePredicateOperatorType:                   comparator = @"LIKE";   break;

  case NSContainsPredicateOperatorType:               comparator = @"CONTAINS";   break;

  case NSBeginsWithPredicateOperatorType:             comparator = @"BEGINSWITH"; break;

  case NSEndsWithPredicateOperatorType:               comparator = @"ENDSWITH";   break;

  case NSCustomSelectorPredicateOperatorType:         break;
  }
  return comparator;
}

-(NSString *) expressionForSelfSelector:(SEL)sel
{
  if (sel == @selector(isMemberOfClass:)) {
    return @"_type =";
  }

  DDLogError(@"Unsupport self selector");

  return nil;
}

-(NSString *) whereClauseForComparisonPredicate:(NSComparisonPredicate *)predicate
{
  NSString *retStr = nil;

  NSString *comparator = nil;
  if (!retStr) {
    comparator = [self infixOperatorForOperatorType:predicate.predicateOperatorType];

    // Special cases
    if (!comparator) {

      if (predicate.predicateOperatorType == NSCustomSelectorPredicateOperatorType) {

        // Self selectors
        if (predicate.leftExpression.expressionType == NSEvaluatedObjectExpressionType) {

          NSString *selfSel = [self expressionForSelfSelector:predicate.customSelector];
          if (selfSel) {

            NSString *right = [self expressionForNSExpression:predicate.rightExpression];
            return [NSString stringWithFormat:@"%@ %@", selfSel, right];
          }

        }

      }

    }
  }

  if (!retStr) {
    if ([comparator isEqualToString:@"CONTAINS"] ||
        [comparator isEqualToString:@"BEGINSWITH"] ||
        [comparator isEqualToString:@"ENDSWITH"])
    {
      BOOL caseInsensitive = predicate.options & NSCaseInsensitivePredicateOption;
      BOOL diaInsensitive = predicate.options & NSDiacriticInsensitivePredicateOption;
      retStr = [NSString stringWithFormat:@"%@(%@, %@, %d, %d)",
                comparator,
                [self expressionForNSExpression:[predicate leftExpression]],
                [self expressionForNSExpression:[predicate rightExpression]],
                caseInsensitive, diaInsensitive];
    }
    else if ([comparator isEqualToString:@"BETWEEN"]) {
      retStr = [NSString stringWithFormat:@"(%@ %@ %@ AND %@)",
                [self expressionForNSExpression:[predicate leftExpression]],
                comparator,
                [self expressionForNSExpression:[[predicate rightExpression] collection][0]],
                [self expressionForNSExpression:[[predicate rightExpression] collection][1]]];
    }
    else {
      retStr = [NSString stringWithFormat:@"(%@ %@ %@)",
                [self expressionForNSExpression:[predicate leftExpression]],
                comparator,
                [self expressionForNSExpression:[predicate rightExpression]]];
    }
  }

  return retStr;
}

-(NSString *) whereClauseForCompoundPredicate:(NSCompoundPredicate *)predicate
{

  NSMutableArray *subs = [NSMutableArray array];
  for (NSPredicate *sub in [predicate subpredicates]) {
    [subs addObject:[self whereClauseForPredicate:sub]];
  }

  NSString *conjunction;
  switch ([(NSCompoundPredicate *)predicate compoundPredicateType]) {
  case NSAndPredicateType:
    conjunction = @" AND ";
    break;

  case NSOrPredicateType:
    conjunction = @" OR ";
    break;

  case NSNotPredicateType:
    conjunction = @" NOT ";
    break;
  }

  return [NSString stringWithFormat:@"( %@ )", [subs componentsJoinedByString:conjunction]];
}

-(NSString *) whereClauseForPredicate:(NSPredicate *)predicate
{
  NSString *retVal = nil;

  if ([predicate respondsToSelector:@selector(compoundPredicateType)]) {
    retVal = [self whereClauseForCompoundPredicate:(id)predicate];
  }
  else if ([predicate respondsToSelector:@selector(predicateOperatorType)]) {
    retVal = [self whereClauseForComparisonPredicate:(id)predicate];
  }
  else if ([predicate.predicateFormat isEqualToString:@"TRUEPREDICATE"]) {
    retVal = @"1";
  }
  else if ([predicate.predicateFormat isEqualToString:@"FALSEPREDICATE"]) {
    retVal = @"0";
  }
  else {
    DDLogError(@"predicate %@ cannot be converted to SQL because it is not of a convertible class", predicate);
  }

  return retVal;
}

-(NSString *) processSortDescriptors:(NSArray *)sortDescriptors
{
  NSMutableArray *all = [NSMutableArray array];

  for (NSSortDescriptor *sortDescriptor in sortDescriptors) {

    NSString *orderKey = [self declaredExpressionForKeyPath:sortDescriptor.key];

    NSString *order = [NSString stringWithFormat:@"ORDER BY %@", orderKey];
    if (!sortDescriptor.ascending) {
      order = [order stringByAppendingString:@" DESC"];
    }

    [all addObject:order];
  }

  return [all componentsJoinedByString:@" "];
}

-(NSString *) processLimit:(NSUInteger)limit withOffset:(NSUInteger)offset
{
  NSMutableArray *all = [NSMutableArray array];

  if (offset != 0) {
    [all addObject:[NSString stringWithFormat:@"OFFSET %ld", (unsigned long)offset]];
  }

  if (limit != 0) {
    [all addObject:[NSString stringWithFormat:@"LIMIT %ld", (unsigned long)limit]];
  }

  return [all componentsJoinedByString:@" "];
}

-(NSString *) processPredicate:(NSPredicate *)predicate sortedBy:(NSArray *)sortDescriptors offset:(NSUInteger)offset limit:(NSUInteger)limit
{
  NSString *select = [@"SELECT " stringByAppendingString:_selectFields ? _selectFields : @"*"];
  NSString *where = [@"WHERE " stringByAppendingString:[self whereClauseForPredicate:predicate]];
  NSString *order = [self processSortDescriptors:sortDescriptors];
  NSString *from = [_relations componentsJoinedByString:@" "];
  NSString *fetch = [self processLimit:limit withOffset:offset];

  NSArray *parts = @[select, from, where, order, fetch];

  return [parts componentsJoinedByString:@" "];
}

@end
