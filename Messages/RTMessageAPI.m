//
//  RTMessageAPI.m
//  ReTxt
//
//  Created by Kevin Wooten on 7/7/14.
//  Copyright (c) 2014 reTXT Labs, LLC. All rights reserved.
//

#import "RTMessageAPI.h"

#import "RTServerAPI.h"
#import "RTMessages+Exts.h"
#import "RTFetchedResultsController.h"
#import "RTChatDAO.h"
#import "RTMessageDAO.h"
#import "RTNotificationDAO.h"
#import "RTUserChat.h"
#import "RTGroupChat.h"
#import "RTNotification.h"
#import "RTCredentials.h"
#import "RTUserStatusInfo.h"
#import "RTWebSocket.h"
#import "RTPersistentCache.h"
#import "RTReachability.h"
#import "RTURLSessionSSLValidator.h"
#import "RTHTTPSessionTransportFactory.h"
#import "RTOpenSSLCertificateValidator.h"
#import "RTSettings.h"

#import "NSData+Random.h"
#import "NSData+Encoding.h"
#import "NSDate+Utils.h"
#import "NSData+CommonDigest.h"
#import "NSError+Utils.h"
#import "NSMutableURLRequest+Utils.h"
#import "NSURL+Utils.h"
#import "NSURLSessionConfiguration+RTMessageAPI.h"
#import "TBase+Utils.h"
#import "RTLog.h"

#import <PromiseKit/PromiseKit.h>
#import <PromiseKit/AnyPromise.h>

@import Thrift;
@import YOLOKit;
@import Operations;
@import JWTDecode;
@import AudioToolbox;
@import OMGHTTPURLRQ;
@import EZSwiftExtensions;


RT_LUMBERJACK_DECLARE_LOG_LEVEL()


NSString *RTMessageAPIUserMessageReceivedNotification = @"RTUserMessageReceived";
NSString *RTMessageAPIUserMessageReceivedNotification_MessageKey = @"message";

NSString *RTMessageAPIDirectMessageReceivedNotification = @"RTDirectMessageReceivedNotification";
NSString *RTMessageAPIDirectMessageReceivedNotification_MsgIdKey = @"msgId";
NSString *RTMessageAPIDirectMessageReceivedNotification_MsgTypeKey = @"msgType";
NSString *RTMessageAPIDirectMessageReceivedNotification_MsgDataKey = @"msgData";
NSString *RTMessageAPIDirectMessageReceivedNotification_SenderKey = @"sender";
NSString *RTMessageAPIDirectMessageReceivedNotification_SenderDeviceIdKey = @"senderDeviceId";

NSString *RTMessageAPIDirectMessageMsgTypeKeySet = @"keySet";

NSString *RTMessageAPIUserStatusDidChangeNotification = @"RTUserStatusDidChange";
NSString *RTMessageAPIUserStatusDidChangeNotification_InfoKey = @"info";

NSString *RTMessageAPISignedInNotification = @"RTMessageAPISignedInNotification";
NSString *RTMessageAPISignedOutNotification = @"RTMessageAPISignedOutNotification";

NSString *RTMessageAPIAccessTokenRefreshed = @"RTMessageAPIAccessTokenRefreshed";


static const int kRTUserInfoCacheTTL = 86400 * 7; // 7 days


@interface RTMessageAPI () <RTWebSocketDelegate> {

  BOOL _active;
  RTId *_activeChatId;
  RTId *_suspendedChatId;

  RTUserAPIClientAsync *_userAPIClient;

  RTDBManager *_dbManager;

  RTChatDAO *_chatDAO;
  RTMessageDAO *_messageDAO;
  RTNotificationDAO *_notificationDAO;

  RTPersistentCache<NSString *, RTUserInfo *> *_userInfoCache;

  RTWebSocket *_webSocket;

  NSMutableArray *_messageResultsControllers;

  NSCountedSet *_failingMessages;

  BOOL _signedOut;
}

@property (readonly, nonatomic) BOOL networkAvailable;

@property (strong, nonatomic) OperationQueue *queue;
@property (strong, nonatomic) NSURLSession *backgroundSession;

@property (strong, nonatomic) RTCredentials *credentials;
@property (strong, nonatomic) NSString *accessToken;

@property (strong, nonatomic) RTOpenSSLCertificateTrust *certificateTrust;

-(void) networkBecameAvailable;
-(void) networkBecameUnavailable;

@end




@implementation RTMessageAPI

RTPublicAPIClientAsync *_s_publicAPIClient;

+(void) initializeWithPublicAPIClient:(RTPublicAPIClientAsync *)publicAPIClient
{
  if (!publicAPIClient) {
    publicAPIClient = [self newPublicAPIClient];
  }
  _s_publicAPIClient = publicAPIClient;
}

+(RTPublicAPIClientAsync *) publicAPI
{
  if (_s_publicAPIClient == nil) {
    _s_publicAPIClient = [self newPublicAPIClient];
  }
  return _s_publicAPIClient;
}

-(RTPublicAPIClientAsync *) publicAPI
{
  return [RTMessageAPI publicAPI];
}

-(RTUserAPIClientAsync *) userAPI
{
  return _userAPIClient;
}

+(AnyPromise *) profileWithId:(RTId *)userId password:(NSString *)password
{
  return [self.publicAPI findProfileWithId:userId password:password].catch(^(NSError *error) {
    return [RTAPIErrorFactory translateError:error];
  });
}

+(AnyPromise *) profileWithAlias:(NSString *)alias password:(NSString *)password
{
  return [self.publicAPI findProfileWithAlias:alias password:password].catch(^(NSError *error) {
    return [RTAPIErrorFactory translateError:error];
  });
}

+(AnyPromise *) isDeviceRegistered:(RTUserProfile *)profile
{
  return dispatch_promise(^id {

    NSError *error;

    RTId *deviceId = [self _discoverDeviceIdWithError:&error];
    if (!deviceId) {
      return error;
    }

    BOOL validDevice = profile.devices.any(^(RTDeviceInfo *deviceInfo) {
      return [deviceInfo.id isEqual:deviceId];
    });

    return @(validDevice);
  });
}

+(AnyPromise *) signInWithProfile:(RTUserProfile *)profile password:(NSString *)password
{
  NSError *error;
  
  RTId *deviceId = [self _discoverDeviceIdWithError:&error];
  if (!deviceId) {
    return [AnyPromise promiseWithValue:error];
  }
  
  return [self signInWithProfile:profile deviceId:deviceId password:password];
}

+(AnyPromise *) signInWithProfile:(RTUserProfile *)profile deviceId:(RTId *)deviceId password:(NSString *)password
{
  return dispatch_promise(^id {

    // See if we have some credentials saved from a previous install
    RTCredentials *savedCredentials = [RTCredentials loadFromKeychain:profile.id];

    return [self.publicAPI signIn:profile.id
                         password:password
                         deviceId:deviceId].thenInBackground(^id (NSData *refreshToken) {

      NSError *error;
      
      RTAsymmetricIdentity *encryptionIdentity;
      RTAsymmetricIdentity *signingIdentity;
      
      BOOL authorized = NO;
      
      if (savedCredentials) {
        
        NSError *error;
        
        RTOpenSSLCertificate *encryptionCert = [RTOpenSSLCertificate certificateWithDEREncodedData:profile.encryptionCert
                                                                                             error:&error];
        if (!encryptionCert) {
          return error;
        }
        
        RTOpenSSLCertificate *signingCert = [RTOpenSSLCertificate certificateWithDEREncodedData:profile.signingCert
                                                                                          error:&error];
        if (!signingCert) {
          return error;
        }

        authorized =
          [savedCredentials.encryptionIdentity privateKeyMatchesCertificate:encryptionCert] &&
          [savedCredentials.signingIdentity privateKeyMatchesCertificate:signingCert];
        
        if (authorized) {
          
          encryptionIdentity = savedCredentials.encryptionIdentity;
          signingIdentity = savedCredentials.signingIdentity;
          
        }
        
      }
      
      if (!authorized) {
        
        // Generate temporary keys for authorization
        //
        
        encryptionIdentity =
        [RTAsymmetricKeyPairGenerator generateSelfSignedIdentityNamed:@{@"UID":profile.id.UUIDString,@"CN":@"reTXT Encryption"}
                                                          withKeySize:2048
                                                                usage:RTAsymmetricKeyPairUsageKeyEncipherment|RTAsymmetricKeyPairUsageNonRepudiation
                                                                error:&error];
        if (!encryptionIdentity) {
          return error;
        }
        
        
        signingIdentity =
        [RTAsymmetricKeyPairGenerator generateSelfSignedIdentityNamed:@{@"UID":profile.id.UUIDString,@"CN":@"reTXT Signing"}
                                                          withKeySize:2048
                                                                usage:RTAsymmetricKeyPairUsageDigitalSignature|RTAsymmetricKeyPairUsageNonRepudiation
                                                                error:&error];
        if (!signingIdentity) {
          return error;
        }
        
      }
      
      return [RTCredentials.alloc initWithRefreshToken:refreshToken
                                                userId:profile.id
                                              deviceId:deviceId
                                            allAliases:profile.aliases.allObjects
                                        preferredAlias:[RTMessageAPI selectPreferredAlias:profile.aliases.allObjects]
                                    encryptionIdentity:encryptionIdentity
                                       signingIdentity:signingIdentity
                                            authorized:authorized];
      
    }).catch(^(NSError *error) {

      return [RTAPIErrorFactory translateError:error];

    });

  });
}

-(AnyPromise *) findUserWithId:(RTId *)userId
{
  return [self.publicAPI findUserWithId:userId];
}

-(AnyPromise *) findUserWithAlias:(NSString *)alias
{
  return dispatch_promise(^{
    return [_userInfoCache objectForKey:alias error:nil].id;
  });
}

+(AnyPromise *) requestAliasAuthentication:(NSString *)alias
{
  return [self.publicAPI requestAliasAuthentication:alias].catch(^(NSError *error) {

    return [RTAPIErrorFactory translateError:error];

  });
}

+(AnyPromise *) checkAliasAuthentication:(NSString *)alias pin:(NSString *)pin
{
  return [self.publicAPI checkAliasAuthentication:alias pin:pin].catch(^(NSError *error) {

    return [RTAPIErrorFactory translateError:error];

  });
}

+(AnyPromise *) registerUserWithAliases:(NSArray<RTAuthenticatedAlias *> *)authenticatedAliases
                               password:(NSString *)password
                   documentDirectoryURL:(NSURL *)documentDirectoryURL
{
  return dispatch_promise(^id {

    NSError *error = nil;

    NSArray *aliases = authenticatedAliases.map(^(RTAuthenticatedAlias *authAlias) { return authAlias.name; });

    // Generate device info

    RTDeviceInfo *deviceInfo = [RTMessageAPI _discoverDeviceInfoWithAliases:aliases error:&error];
    if (!deviceInfo) {
      return error;
    }

    // Generate keys/CSRs
    
    RTAsymmetricIdentityRequest *encryptionIdentityRequest =
    [RTAsymmetricKeyPairGenerator generateIdentityRequestNamed:@"reTXT Encryption"
                                                   withKeySize:2048
                                                         usage:RTAsymmetricKeyPairUsageKeyEncipherment|RTAsymmetricKeyPairUsageNonRepudiation
                                                         error:&error];
    if (!encryptionIdentityRequest) {
      return error;
    }
    
    RTAsymmetricIdentityRequest* signingIdentityRequest =
    [RTAsymmetricKeyPairGenerator generateIdentityRequestNamed:@"reTXT Signing"
                                                   withKeySize:2048
                                                         usage:RTAsymmetricKeyPairUsageDigitalSignature|RTAsymmetricKeyPairUsageNonRepudiation
                                                         error:&error];
    if (!signingIdentityRequest) {
      return error;
    }
    

    // Register user

    return [self.publicAPI registerUser:password
                         encryptionCSR:encryptionIdentityRequest.certificateSigningRequest.encoded
                             signingCSR:signingIdentityRequest.certificateSigningRequest.encoded
                   authenticatedAliases:authenticatedAliases
                             deviceInfo:deviceInfo]
    .thenInBackground(^id (RTUserProfile *userProfile) {
      
      // Sign in device

      return [self.publicAPI signIn:userProfile.id
                           password:password
                           deviceId:deviceInfo.id].thenInBackground(^id (NSData *refreshToken) {
        
        NSError *error = nil;
        
        // Load validation certificates
        
        NSBundle *bundle = [NSBundle bundleForClass:self.class];
        NSURL *rootsURL = [bundle URLForResource:@"roots" withExtension:@"pem" subdirectory:@"Certificates"];
        NSURL *intermediatesURL = [bundle URLForResource:@"inters" withExtension:@"pem" subdirectory:@"Certificates"];
        
        RTOpenSSLCertificateTrust * certificateTrust =
        [RTOpenSSLCertificateTrust.alloc initWithPEMEncodedRoots:[NSData dataWithContentsOfURL:rootsURL]
                                                   intermediates:[NSData dataWithContentsOfURL:intermediatesURL]
                                                           error:&error];
        if (!certificateTrust) {
          return error;
        }
        
        RTOpenSSLCertificate *encryptionCert =
        [RTOpenSSLCertificate certificateWithDEREncodedData:userProfile.encryptionCert
                                         validatedWithTrust:certificateTrust
                                                      error:&error];
        if (!encryptionCert) {
          return error;
        }
        
        RTAsymmetricIdentity *encryptionIdentity =
        [encryptionIdentityRequest buildIdentityWithCertificate:encryptionCert];
        if (!encryptionIdentity) {
          return error;
        }
        
        RTOpenSSLCertificate *signingCert =
        [RTOpenSSLCertificate certificateWithDEREncodedData:userProfile.signingCert
                                         validatedWithTrust:certificateTrust
                                                      error:&error];
        if (!signingCert) {
          return error;
        }
        
        RTAsymmetricIdentity *signingIdentity =
        [signingIdentityRequest buildIdentityWithCertificate:signingCert];
        if (!signingIdentity) {
          return error;
        }
        
        return [RTCredentials.alloc initWithRefreshToken:refreshToken
                                                  userId:userProfile.id
                                                deviceId:deviceInfo.id
                                              allAliases:userProfile.aliases.allObjects
                                          preferredAlias:[RTMessageAPI selectPreferredAlias:userProfile.aliases.allObjects]
                                      encryptionIdentity:encryptionIdentity
                                         signingIdentity:signingIdentity
                                              authorized:YES];
        
      });

    });

  }).catch(^(NSError *error) {

    return [RTAPIErrorFactory translateError:error];

  });
}

+(AnyPromise *) updateKeysForUserId:(RTId *)userId password:(NSString *)password encryptionKeyData:(NSData *)encryptionKeyData signingKeyData:(NSData *)signingKeyData
{
  return nil;
}

+(AnyPromise *) requestTemporaryPasswordForUser:(NSString *)alias
{
  return [self.publicAPI requestTemporaryPassword:alias].thenInBackground(^(RTId *userId) {

    if (userId.isNull) {
      userId = nil;
    }

    return userId;

  }).catch(^(NSError *error) {

    return [RTAPIErrorFactory translateError:error];

  });
}

+(AnyPromise *) checkTemporaryPasswordForUser:(RTId *)userId temporaryPassword:(NSString *)temporaryPassword
{
  return [self.publicAPI checkTemporaryPassword:userId
                                   tempPassword:temporaryPassword].catch(^(NSError *error) {

    return [RTAPIErrorFactory translateError:error];

  });
}

+(AnyPromise *) resetPasswordForUser:(RTId *)userId
                   temporaryPassword:(NSString *)temporaryPassword
                            password:(NSString *)password
{
  return dispatch_promise(^{

    return [self.publicAPI resetPassword:userId
                            tempPassword:temporaryPassword
                                password:password];

  }).catch(^(NSError *error) {

    return [RTAPIErrorFactory translateError:error];

  });
}

-(AnyPromise *) changePasswordWithOldPassword:(NSString *)oldPassword
                                  newPassword:(NSString *)newPassword
{
  return [self.publicAPI changePassword:_credentials.userId
                            oldPassword:oldPassword
                            newPassword:newPassword].catch(^(NSError *error) {

    return [self translateError:error];

  });
}

+(NSString *) selectPreferredAlias:(NSArray *)aliases
                         suggested:(NSString *)suggested
{
  if ([aliases containsObject:suggested]) {
    return suggested;
  }
  return [self selectPreferredAlias:aliases];
}

+(NSString *) selectPreferredAlias:(NSArray *)aliases
{
  //FIXME
//  for (NSString *alias in aliases) {
//    if ([alias isValidPhoneNumberAlias]) {
//      return alias;
//    }
//  }
  return [aliases firstObject];
}

+(RTPublicAPIClientAsync *) newPublicAPIClient
{
  // SSL validator
  RTURLSessionSSLValidator *validator= [RTURLSessionSSLValidator.alloc initWithTrustedCertificates:RTServerAPI.pinnedCerts];

  NSOperationQueue *sessionQueue = [NSOperationQueue new];
  sessionQueue.maxConcurrentOperationCount = NSOperationQueueDefaultMaxConcurrentOperationCount;

  // Build a configured session configured for PublicAPI usage

  id<TProtocolFactory> protocolFactory = TCompactProtocolFactory.sharedFactory;

  NSURLSessionConfiguration *sessionConfig =
    [NSURLSessionConfiguration clientSessionCofigurationWithProtcolFactory:protocolFactory];

  NSURLSession *session = [NSURLSession sessionWithConfiguration:sessionConfig
                                                        delegate:validator
                                                   delegateQueue:sessionQueue];

  // Build a client for the new session

  id<TAsyncTransportFactory> transportFactory = [THTTPSessionTransportFactory.alloc initWithSession:session
                                                                                                URL:RTServerAPI.publicURL];

  return [RTPublicAPIClientAsync.alloc initWithProtocolFactory:protocolFactory
                                              transportFactory:transportFactory];
}

-(RTUserAPIClientAsync *) newUserAPIClient
{
  // Build an SSL validator

  RTURLSessionSSLValidator *validator = [RTURLSessionSSLValidator.alloc initWithTrustedCertificates:RTServerAPI.pinnedCerts];

  NSOperationQueue *sessionQueue = [NSOperationQueue new];
  sessionQueue.maxConcurrentOperationCount = NSOperationQueueDefaultMaxConcurrentOperationCount;

  // Build a session configured for UserAPI usage

  id<TProtocolFactory> protocolFactory = TCompactProtocolFactory.sharedFactory;

  NSURLSessionConfiguration *sessionConfig =
    [NSURLSessionConfiguration clientSessionCofigurationWithProtcolFactory:protocolFactory];

  NSURLSession *session = [NSURLSession sessionWithConfiguration:sessionConfig
                                                        delegate:validator
                                                   delegateQueue:sessionQueue];

  // Build a client for the new session

  RTHTTPSessionTransportFactory *transportFactory = [RTHTTPSessionTransportFactory.alloc initWithSession:session
                                                                                                     URL:RTServerAPI.userURL];
  
  // Add interceptor to add bearer authorization token
  transportFactory.requestInterceptor = ^NSError * (NSMutableURLRequest *request) {

    [request addHTTPBearerAuthorizationWithToken:_accessToken];
    
    return nil;
  };
  
  // Add interceptor to inspect for refreshed bearer tokens
  transportFactory.responseValidate = ^NSError * (NSHTTPURLResponse *response, NSData *responseData) {
    
    NSString *updatedAccessToken = response.allHeaderFields[RTBearerRefreshHTTPHeader];
    if (updatedAccessToken.length) {
      [self updateAccessToken:updatedAccessToken];
    }
    
    return nil;
  };

  RTUserAPIClientAsync *client = [RTUserAPIClientAsync.alloc initWithProtocolFactory:protocolFactory
                                                                    transportFactory:transportFactory];
  
  return client;
}

-(RTWebSocket *) newWebSocket
{
  NSMutableURLRequest *connectURLRequest = [NSMutableURLRequest requestWithURL:RTServerAPI.userConnectURL];
  [connectURLRequest addBuildNumber];

  RTWebSocket *webSocket = [RTWebSocket new];
  webSocket.URLRequest = connectURLRequest;
  webSocket.delegate = self;
  return webSocket;
}

+(RTDBManager *) dbManagerWithURL:(NSURL *)dbURL
{
  return [RTDBManager.alloc initWithPath:dbURL.path
                                    kind:@"Message"
                              daoClasses:@[[RTChatDAO class], [RTMessageDAO class], [RTNotificationDAO class]]];
}

+(RTMessageAPI *) APIWithCredentials:(RTCredentials *)credentials
                documentDirectoryURL:(NSURL *)docDirURL
                               error:(NSError **)error
{
  return [RTMessageAPI.alloc initWithCredentials:credentials
                            documentDirectoryURL:docDirURL
                                           error:error];
}

-(instancetype) initWithCredentials:(RTCredentials *)credentials
               documentDirectoryURL:(NSURL *)docDirURL
                              error:(NSError **)error
{
  if ((self = [super init])) {

    _queue = [OperationQueue new];
    
    _credentials = credentials;
    _accessToken = nil;
    
    NSString *dbName = [[_credentials.userId UUIDString] stringByAppendingString:@".sqlite"];
    NSURL *dbURL = [docDirURL URLByAppendingPathComponent:dbName];

    if ([NSUserDefaults.standardUserDefaults boolForKey:@"io.retxt.debug.ClearData"]) {
      [NSFileManager.defaultManager removeItemAtPath:dbURL.path error:nil];
    }

    _dbManager = [RTMessageAPI dbManagerWithURL:dbURL];
    if (!_dbManager) {
      return nil;
    }

    _messageDAO = _dbManager[@"Message"];
    _chatDAO = _dbManager[@"Chat"];
    _notificationDAO = _dbManager[@"Notification"];


    // Initialize the user information cache

    _userInfoCache = [RTPersistentCache.alloc initWithName:@"UserInfo"
                                                    loader:^id < NSCoding > (NSString *userAlias, NSDate *__autoreleasing *expires, NSError *__autoreleasing *errorResult) {

      dispatch_semaphore_t wait = dispatch_semaphore_create(0);

      __block NSError *error;
      __block RTUserInfo *userInfo;

      [self.publicAPI findUserWithAlias:userAlias response:^(RTUserInfo *response) {

        userInfo = response;

        dispatch_semaphore_signal(wait);

      } failure:^(NSError *resolveError) {

        error = [self translateError:resolveError];

        dispatch_semaphore_signal(wait);
      }];

      dispatch_semaphore_wait(wait, DISPATCH_TIME_FOREVER);

      if (userInfo) {
        *expires = [NSDate dateWithTimeIntervalSinceNow:kRTUserInfoCacheTTL];
      }

      if (errorResult) {
        *errorResult = error;
      }

      return userInfo;
    }];

    // Build API & WebSocket
    
    _userAPIClient = [self newUserAPIClient];
    
    _webSocket = [self newWebSocket];
    
    // Build the background session

    BackgroundSessionOperations *backgroundSessionOperations =
      [BackgroundSessionOperations.alloc initWithTrustedCertificates:RTServerAPI.pinnedCerts
                                                                   api:self
                                                                   dao:_messageDAO
                                                                 queue:_queue];

    NSURLSessionConfiguration *backgroundSessionConfig =
      [NSURLSessionConfiguration backgroundSessionConfigurationWithUserId:_credentials.userId];
    
    _backgroundSession = [NSURLSession sessionWithConfiguration:backgroundSessionConfig
                                                       delegate:backgroundSessionOperations
                                                  delegateQueue:_queue];

    [backgroundSessionOperations resurrectOperationsForSession:_backgroundSession withCompletion:^(NSArray *transferringMsgIds) {

      // Cleanup messages caught in Sending state but not in background
      //  transfers

      [_messageDAO failAllSendingMessagesExcluding:transferringMsgIds];

      [_queue addOperation:[ResendUnsentMessages.alloc initWithApi:self]];

    }];


    // Listen to required notifications

    [NSNotificationCenter.defaultCenter addObserver:self
                                           selector:@selector(networkBecameAvailable)
                                               name:RTNetworkConnectivityAvailable
                                             object:nil];

    [NSNotificationCenter.defaultCenter addObserver:self
                                           selector:@selector(networkBecameUnavailable)
                                               name:RTNetworkConnectivityLost
                                             object:nil];

    [NSNotificationCenter.defaultCenter addObserver:self
                                           selector:@selector(applicationActive)
                                               name:UIApplicationDidBecomeActiveNotification
                                             object:nil];

    [NSNotificationCenter.defaultCenter addObserver:self
                                           selector:@selector(applicationInactive)
                                               name:UIApplicationWillResignActiveNotification
                                             object:nil];

    dispatch_async(dispatch_get_main_queue(), ^{

      [NSNotificationCenter.defaultCenter postNotificationName:RTMessageAPISignedInNotification
                                                        object:self];


    });

    // Activate API if the app is already in the foreground

    if ([UIApplication sharedApplication].applicationState == UIApplicationStateActive) {
      [self activate];
    }

  }

  return self;
}

-(void) requestAuthorization
{
  [_queue addOperation:[RequestAuthorizationOperation.alloc initWithAlias:_credentials.preferredAlias
                                                                 deviceId:_credentials.deviceId
                                                               deviceName:UIDevice.currentDevice.name
                                                                      api:self]];
}

-(AnyPromise *) resetKeys
{
  return dispatch_promise(^id {

    NSError *error;
    
    // Generate new keys identity's and update server
    //
    
    RTAsymmetricIdentityRequest *encryptionIdentityRequest =
    [RTAsymmetricKeyPairGenerator generateIdentityRequestNamed:@"reTXT Encryption"
                                                   withKeySize:2048
                                                         usage:RTAsymmetricKeyPairUsageKeyEncipherment|RTAsymmetricKeyPairUsageNonRepudiation
                                                         error:&error];
    if (!encryptionIdentityRequest) {
      return error;
    }
    
    
    RTAsymmetricIdentityRequest *signingIdentityRequest =
    [RTAsymmetricKeyPairGenerator generateIdentityRequestNamed:@"reTXT Signing"
                                                   withKeySize:2048
                                                         usage:RTAsymmetricKeyPairUsageDigitalSignature|RTAsymmetricKeyPairUsageNonRepudiation
                                                         error:&error];
    if (!signingIdentityRequest) {
      return error;
    }
    
    return [self.userAPI updateCertificates:encryptionIdentityRequest.certificateSigningRequest.encoded
                                 signingCSR:signingIdentityRequest.certificateSigningRequest.encoded]
    .then(^id (RTCertificateSet *certs) {
      
      NSError *error;
      
      RTOpenSSLCertificate *encryptionCert = [RTOpenSSLCertificate certificateWithDEREncodedData:certs.encryptionCert
                                                                              validatedWithTrust:_certificateTrust
                                                                                           error:&error];
      
      RTOpenSSLCertificate *signingCert = [RTOpenSSLCertificate certificateWithDEREncodedData:certs.signingCert
                                                                           validatedWithTrust:_certificateTrust
                                                                                        error:&error];
      
      return [_credentials authorizeWithEncryptionIdentity:[encryptionIdentityRequest buildIdentityWithCertificate:encryptionCert]
                                           signingIdentity:[signingIdentityRequest buildIdentityWithCertificate:signingCert]];
      
    });
    
  });
}

-(void) checkIn
{
  if (!self.accessTokenValid) {

    // Refresh token and update accordingly
    [self.publicAPI generateAccessToken:_credentials.userId
                               deviceId:_credentials.deviceId
                           refreshToken:_credentials.refreshToken]
    .thenInBackground(^(NSString *refreshedAccessToken) {
      
      [self updateAccessToken:refreshedAccessToken];

    }).catch(^(NSError *error) {

      [self translateError:error];

    });

  }

}

-(BOOL) accessTokenValid
{
  if (!_accessToken) {
    return NO;
  }
  
  NSError *error;
  A0JWT *jwt = [A0JWT decode:_accessToken error:&error];
  
  if (!jwt) {
    DDLogError(@"MessageAPI: JWT: Decoding error: %@", error);
    return NO;
  }
  
  if (!jwt.expiresAt) {
    DDLogError(@"MessageAPI: JWT: Invalid expiration");
    return NO;
  }
  
  // If token expires in next 5 minutes refresh it
  return [jwt.expiresAt compare:[NSDate dateWithTimeIntervalSinceNow:5 * 60]] != NSOrderedAscending;
}

-(void) updateAccessToken:(NSString *)accessToken
{
  _accessToken = accessToken;
  
  [NSNotificationCenter.defaultCenter postNotificationName:RTMessageAPIAccessTokenRefreshed
                                                    object:self];
}

-(void) setMessageNotificationToken:(NSData *)messageNotificationToken
{
  if (![_messageNotificationToken isEqualToData:messageNotificationToken]) {

    _messageNotificationToken = messageNotificationToken;

    [self.userAPI registerNotifications:RTNotificationTypeMessage platform:@"APN_iOS_VoIP" token:messageNotificationToken];

  }
}

-(void) setInformationNotificationToken:(NSData *)informationNotificationToken
{
  if (![_informationNotificationToken isEqualToData:informationNotificationToken]) {

    _informationNotificationToken = informationNotificationToken;

    [self.userAPI registerNotifications:RTNotificationTypeInformation platform:@"APN_iOS" token:informationNotificationToken];

  }
}

-(void) dealloc
{
  [NSNotificationCenter.defaultCenter removeObserver:self];

  _dbManager = nil;
}

-(void) signOut
{
  if (_signedOut) {
    return;
  }

  _signedOut = true;

  [self deactivate];

  [_webSocket disconnect];
  _webSocket = nil;

  _queue.suspended = YES;
  [_queue cancelAllOperations];

  dispatch_async(dispatch_get_main_queue(), ^{

    [NSNotificationCenter.defaultCenter postNotificationName:RTMessageAPISignedOutNotification
                                                      object:self];

  });

  dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{

    [self clearUnreadMessageCount];

  });
}

-(void) applicationActive
{
  [self activate];

  [self checkIn];
}

-(void) applicationInactive
{
  [self deactivate];
}

-(void) networkBecameAvailable
{
  _networkAvailable = YES;

  [_queue addOperation:[ResendUnsentMessages.alloc initWithApi:self]];

}

-(void) networkBecameUnavailable
{
  _networkAvailable = NO;
}

-(void) activate
{
  if (_active) {
    return;
  }

  _active = YES;
  
  if (_credentials.authorized) {

    [_queue addOperation:[ConnectWebSocket.alloc initWithApi:self]];
    [_queue addOperation:[FetchWaitingOperation.alloc initWithApi:self]];
    [_queue addOperation:[ResendUnsentMessages.alloc initWithApi:self]];
    
  }

  if (_suspendedChatId) {
    
    [self activateChat:[_chatDAO fetchChatWithId:_suspendedChatId]];
    
    _suspendedChatId = nil;
  }
}

-(RTWebSocket *) webSocket
{
  return _webSocket;
}

-(RTMessageDAO *) messageDAO
{
  return _messageDAO;
}

-(RTChatDAO *) chatDAO
{
  return _chatDAO;
}

-(RTNotificationDAO *) notificationDAO
{
  return _notificationDAO;
}

-(RTPersistentCache<NSString *, RTUserInfo *> *) userInfoCache
{
  return _userInfoCache;
}

-(NSURLSession *) backgroundSession
{
  return _backgroundSession;
}

-(BOOL) isActive
{
  return _active;
}

-(RTId *) activeChatId
{
  return _activeChatId;
}

-(BOOL) isChatActive:(RTChat *)chat
{
  return [_activeChatId isEqual:chat.id];
}

-(BOOL) isOtherChatActive:(RTChat *)chat
{
  return _activeChatId != nil && ![self isChatActive:chat];
}

-(void) activateChat:(RTChat *)chat
{
  if ([_activeChatId isEqual:chat.id]) {
    return;
  }

  _activeChatId = chat.id;
  _suspendedChatId = nil;

  [self activate];

  [_queue addOperationWithBlock:^{

    [_chatDAO resetUnreadCountsForChat:chat];

    int unreadCount = [_messageDAO readAllMessagesForChat:chat];
    [self adjustUnreadWithDelta:-unreadCount];

    [self hideNotificationsForChat:chat];

    [self sendReceiptForChat:chat];

  }];

}

-(void) deactivateChat
{
  _activeChatId = nil;
}

-(void) deactivate
{
  _suspendedChatId = _activeChatId;

  [self deactivateChat];

  [_webSocket disconnect];

  _active = NO;
}

-(AnyPromise *) backgroundPoll
{
  return [AnyPromise promiseWithResolverBlock:^(PMKResolver resolver) {

    FetchWaitingOperation *waiting = [FetchWaitingOperation.alloc initWithApi:self];
    waiting.resolver = resolver;

    [_queue addOperation:waiting];

  }];
}

-(void) adjustUnreadMessageCountWithDelta:(NSInteger)delta
{
  NSInteger unread = [NSUserDefaults.standardUserDefaults integerForKey:@"io.retxt.unread"];
  unread = MAX(unread + delta, 0);
  [NSUserDefaults.standardUserDefaults setInteger:unread forKey:@"io.retxt.unread"];
  
  UIApplication.sharedApplication.applicationIconBadgeNumber = unread;
}

-(NSUInteger) updateUnreadMessageCount
{
  NSUInteger count = _messageDAO.countOfUnreadMessages;
  [NSUserDefaults.standardUserDefaults setInteger:count forKey:@"io.retxt.unread"];
  return count;
}

-(void) clearUnreadMessageCount
{
  [NSUserDefaults.standardUserDefaults setInteger:0 forKey:@"io.retxt.unread"];
  UIApplication.sharedApplication.applicationIconBadgeNumber = 0;
}

-(AnyPromise *) findMessageById:(RTId *)messageId
{
  return dispatch_promise(^id {

    NSError *error = nil;
    RTMessage *msg = nil;
    if (![_messageDAO fetchMessageWithId:messageId returning:&msg error:&error]) {
      return error;
    }
    
    return msg;
  });
}

-(AnyPromise *) findMessagesMatching:(NSPredicate *)predicate
                              offset:(NSUInteger)offset
                               limit:(NSUInteger)limit
                            sortedBy:(NSArray *)sortDescriptors
{
  return dispatch_promise(^id {

    NSError *error = nil;
    NSArray *res = [_messageDAO fetchAllMessagesMatching:predicate
                                                  offset:offset
                                                   limit:limit
                                                sortedBy:sortDescriptors
                                                   error:&error];
    if (!res) {
      return error;
    }
    
    return res;
  });
}

-(RTFetchedResultsController *) fetchMessagesMatching:(NSPredicate *)predicate
                                               offset:(NSUInteger)offset
                                                limit:(NSUInteger)limit
                                             sortedBy:(NSArray *)sortDescriptors
{
  RTFetchRequest *request = [RTFetchRequest new];
  request.resultClass = [RTMessage class];
  request.predicate = predicate;
  request.includeSubentities = YES;
  request.sortDescriptors = sortDescriptors;
  request.fetchOffset = offset;
  request.fetchLimit = limit;
  request.fetchBatchSize = 0;

  RTFetchedResultsController *controller = [RTFetchedResultsController.alloc initWithDBManager:_dbManager
                                                                                       request:request];

  return controller;
}

-(BOOL) saveMessage:(RTMessage *)message
{
  // Ensure certain fields are not set
  if (message.sender || message.sent ||
      message.statusTimestamp)
  {
    return NO;
  }

  // Ensure other important fields are set
  if (!message.chat) {
    return NO;
  }

  // Update fields for new message
  message.id = [RTId generate];
  message.sender = message.chat.localAlias;
  message.sent = [NSDate date];
  message.status = RTMessageStatusSending;
  message.statusTimestamp = [NSDate date];
  message.flags = 0;

  //FIXME error handling
  if (![_messageDAO insertMessage:message error:nil]) {
    return NO;
  }

  [_chatDAO updateChat:message.chat withLastSentMessage:message];

  [_queue addOperation:[MessageSendOperation.alloc initWithMessage:message api:self]];

  return YES;
}

-(BOOL) updateMessageLocally:(RTMessage *)message;
{
  return [_messageDAO updateMessage:message error:nil]; //FIXME error handling
}

-(BOOL) updateMessage:(RTMessage *)message
{
  // Ensure all required fields are already set
  if (!message.id || !message.chat ||
      !message.sender || !message.sent)
  {
    return NO;
  }

  // Ensure we are only updating messages we sent
  if (!message.sentByMe) {
    return NO;
  }

  // Update status for resend
  message.status = RTMessageStatusUnsent;
  message.statusTimestamp = [NSDate date];
  message.updated = [NSDate date];
  message.flags = 0;

  //FIXME error handling
  if (![_messageDAO updateMessage:message error:nil]) {
    return NO;
  }

  [_queue addOperation:[MessageSendOperation.alloc initWithMessage:message api:self]];

  return YES;
}

-(void) clarifyMessage:(RTMessage *)message
{
  NSOperation *save = [NSBlockOperation blockOperationWithBlock:^{

    [_messageDAO updateMessage:message withFlags:message.flags | RTMessageFlagClarify];

  }];

  NSOperation *send = [MessageSendSystemOperation.alloc initWithMsgType:RTMsgTypeClarify
                                                                   chat:message.chat
                                                               metaData:@{@"msgId": message.id.UUIDString}
                                                                 target:RTSystemMsgTargetAll
                                                                    api:self];
  [send addDependency:save];

  [_queue addOperations:@[save, send]];
}

-(BOOL) deleteMessageLocally:(RTMessage *)message
{
  BOOL deleted = [_messageDAO deleteMessage:message error:nil]; //FIXME error handling

  if (deleted) {

    if ([message isEqual:message.chat.lastMessage]) {

      RTMessage *lastMessage = [_messageDAO fetchLastMessageForChat:message.chat];

      [_chatDAO updateChat:message.chat withLastMessage:lastMessage];

    }

    [self hideNotificationForMessage:message];
  }

  return deleted;
}

-(BOOL) deleteMessage:(RTMessage *)message
{
  BOOL deleted = [self deleteMessageLocally:message];

  if (deleted) {

    [_queue addOperation:[MessageSendSystemOperation.alloc initWithMsgType:RTMsgTypeDelete
                                                                      chat:message.chat
                                                                  metaData:@{@"msgId": message.id.UUIDString,
                                                                             @"type": @"message"}
                                                                    target:RTSystemMsgTargetAll
                                                                       api:self]];

  }

  return deleted;
}

-(BOOL) updateChatLocally:(RTChat *)chat
{
  return [_chatDAO updateChat:chat error:nil]; //FIXME error handling
}

-(BOOL) deleteChatLocally:(RTChat *)chat
{
  BOOL deleted = [_chatDAO deleteChat:chat error:nil]; //FIXME error handling

  if (deleted) {

    [self hideNotificationsForChat:chat];

  }

  return deleted;
}

-(BOOL) deleteChat:(RTChat *)chat
{
  BOOL deleted = [self deleteChatLocally:chat];

  if (deleted) {

    [_queue addOperation:[MessageSendSystemOperation.alloc initWithMsgType:RTMsgTypeDelete
                                                                      chat:chat
                                                                  metaData:@{@"type": @"chat"}
                                                                    target:RTSystemMsgTargetCC
                                                                       api:self]];

  }

  return deleted;
}

-(AnyPromise *) reportDirectMessage:(RTDirectMsg *)msg
{
  return [AnyPromise promiseWithResolverBlock:^(PMKResolver resolve) {

    MessageProcessDirectOperation *op = [MessageProcessDirectOperation.alloc initWithMsg:msg api:self];
    op.resolver = resolve;

    [_queue addOperation:op];

  }];
}

-(AnyPromise *) reportWaitingMessage:(RTId *)msgId type:(enum RTMsgType)msgType dataLength:(int)msgDataLength
{
  if (!_credentials.authorized) {
    return [AnyPromise promiseWithValue:nil];
  }
  
  return [AnyPromise promiseWithResolverBlock:^(PMKResolver resolver) {

    RTMsgHdr *msgHdr = [RTMsgHdr.alloc initWithId:msgId type:msgType dataLength:msgDataLength];

    MessageRecvOperation *recv = [MessageRecvOperation.alloc initWithMsgHdr:msgHdr api:self];
    recv.resolver = resolver;

    [_queue addOperation:recv];

  }];
}

-(AnyPromise *) findChatsMatching:(NSPredicate *)predicate
                           offset:(NSUInteger)offset
                            limit:(NSUInteger)limit
                         sortedBy:(NSArray *)sortDescriptors
{
  return dispatch_promise(^id {

    NSError *error = nil;
    NSArray *res = [_chatDAO fetchAllChatsMatching:predicate
                                            offset:offset
                                             limit:limit
                                          sortedBy:sortDescriptors
                                             error:&error];
    if (!res) {
      return error;
    }

    return res;
  });
}

-(RTFetchedResultsController *) fetchChatsMatching:(NSPredicate *)predicate
                                            offset:(NSUInteger)offset
                                             limit:(NSUInteger)limit
                                          sortedBy:(NSArray *)sortDescriptors
{
  RTFetchRequest *request = [RTFetchRequest new];
  request.resultClass = [RTChat class];
  request.predicate = predicate;
  request.includeSubentities = YES;
  request.sortDescriptors = sortDescriptors;
  request.fetchOffset = offset;
  request.fetchLimit = limit;
  request.fetchBatchSize = 0;

  RTFetchedResultsController *controller = [RTFetchedResultsController.alloc initWithDBManager:_dbManager
                                                                                       request:request];

  return controller;
}

-(RTUserChat *) loadUserChatForAlias:(NSString *)alias localAlias:(NSString *)localAlias
{

  RTUserChat *chat = (id)[_chatDAO fetchChatForAlias:alias localAlias:localAlias];
  if (!chat) {

    chat = [RTUserChat new];
    chat.id = [RTId generate];
    chat.alias = alias;
    chat.localAlias = localAlias;
    chat.startedDate = [NSDate date];

    //FIXME error handling
    if (![_chatDAO insertChat:chat error:nil]) {
      return nil;
    }
  }

  return chat;
}

-(RTGroupChat *) loadGroupChatForId:(RTId *)chatId members:(NSSet *)members localAlias:(NSString *)localAlias
{

  RTGroupChat *chat = (id)[_chatDAO fetchChatForAlias:[chatId UUIDString] localAlias:localAlias];
  if (!chat) {

    chat = [RTGroupChat new];
    chat.id = chatId;
    chat.alias = [chatId UUIDString];
    chat.localAlias = localAlias;
    chat.members = [members setByAddingObject:localAlias];
    chat.startedDate = [NSDate date];

    //FIXME error handling
    if (![_chatDAO insertChat:chat error:nil]) {
      return nil;
    }
  }

  return chat;
}

-(void) sendUserStatusWithSender:(NSString *)sender recipient:(NSString *)recipient status:(enum RTUserStatus)status
{
  [_queue addOperationWithBlock:^{

  }];
  [self.userAPI sendUserStatus:sender
                     recipient:recipient
                        status:status].catch(^(NSError *error) {

    return [self translateError:error];

  });
}

-(void) sendGroupStatusWithSender:(NSString *)sender chat:(RTId *)chat members:(NSSet *)members status:(enum RTUserStatus)status
{
  RTGroup *group = [RTGroup.alloc initWithChat:chat members:[members mutableCopy]];

  [self.userAPI sendGroupStatus:sender
                          group:group
                         status:status].catch(^(NSError *error) {

    return [self translateError:error];

  });
}

-(void) enterChat:(RTGroupChat *)chat
{
  if (chat.includesMe) {
    return;
  }

  if ([_chatDAO updateChat:chat addGroupMember:chat.localAlias]) {

    [_queue addOperation:[MessageSendSystemOperation.alloc initWithMsgType:RTMsgTypeEnter
                                                                      chat:chat
                                                                  metaData:@{@"member": chat.localAlias}
                                                                    target:RTSystemMsgTargetAll
                                                                       api:self]];

  }

}

-(void) exitChat:(RTGroupChat *)chat
{
  if (!chat.includesMe) {
    return;
  }

  if ([_chatDAO updateChat:chat removeGroupMember:chat.localAlias]) {

    [_queue addOperation:[MessageSendSystemOperation.alloc initWithMsgType:RTMsgTypeExit
                                                                      chat:chat
                                                                  metaData:@{@"member": chat.localAlias}
                                                                    target:RTSystemMsgTargetAll
                                                                       api:self]];

  }

}

-(void) setPreferredAlias:(NSString *)preferredAlias
{
  _credentials = [_credentials updatePreferredAlias:preferredAlias];
}

-(AnyPromise *) listAliases
{
  return [self.userAPI listAliases].catch(^(NSError *error) {

    return [self translateError:error];

  });
}

-(AnyPromise *) addAlias:(NSString *)alias pin:(NSString *)pin
{
  RTAuthenticatedAlias *aliasAndPin = [RTAuthenticatedAlias.alloc initWithName:alias pin:pin];

  return [self.userAPI registerAlias:aliasAndPin].thenInBackground(^{

    _credentials = [_credentials updateAllAliases:[_credentials.allAliases arrayByAddingObject:alias]
                                   preferredAlias:_credentials.preferredAlias];

  }).catch(^(NSError *error) {

    return [self translateError:error];

  });
}

-(AnyPromise *) removeAlias:(NSString *)alias
{
  return [self.userAPI unregisterAlias:alias].thenInBackground(^{

    NSArray *allAliases = _credentials.allAliases.without(alias);

    NSString *preferredAlias;
    if ([_credentials.preferredAlias isEqualToString:alias]) {
      preferredAlias = [RTMessageAPI selectPreferredAlias:allAliases];
    }
    else {
      preferredAlias = _credentials.preferredAlias;
    }
    
    _credentials = [_credentials updateAllAliases:allAliases
                                   preferredAlias:preferredAlias];

    
  }).catch(^(NSError *error) {

    return [self translateError:error];

  });
}

-(AnyPromise *) listDevices
{
  return [self.userAPI listDevices].catch(^(NSError *error) {

    return [self translateError:error];

  });
}

+(AnyPromise *) addDeviceNamed:(NSString *)deviceName toProfile:(RTUserProfile *)userProfile withPassword:(NSString *)password
{
  return dispatch_promise(^id {

    NSError *error;

    RTDeviceInfo *deviceInfo = [RTMessageAPI _discoverDeviceInfoWithAliases:userProfile.aliases.allObjects error:&error];
    if (!deviceInfo) {
      return error;
    }
    
    if (deviceName.length) {
      deviceInfo.name = deviceName;
    }

    return [self.publicAPI registerDevice:userProfile.id password:password deviceInfo:deviceInfo];

  }).catch(^(NSError *error) {

    return [RTAPIErrorFactory translateError:error];

  });
}

+(AnyPromise *) replaceDeviceWithId:(RTId *)deviceId withDeviceNamed:(NSString *)deviceName inProfile:(RTUserProfile *)userProfile withPassword:(NSString *)password
{
  return dispatch_promise(^id {

    NSError *error;

    RTDeviceInfo *deviceInfo = [RTMessageAPI _discoverDeviceInfoWithAliases:userProfile.aliases.allObjects error:&error];
    if (!deviceInfo) {
      return error;
    }
    
    if (deviceName.length) {
      deviceInfo.name = deviceName;
    }

    return [self.publicAPI replaceRegisteredDevice:userProfile.id password:password deviceInfo:deviceInfo currentDeviceId:deviceId];

  }).catch(^(NSError *error) {

    return [RTAPIErrorFactory translateError:error];

  });
}

+(AnyPromise *) removeDeviceWithId:(RTId *)deviceId fromProfile:(RTUserProfile *)userProfile withPassword:(NSString *)password
{
  return [self.publicAPI unregisterDevice:deviceId
                                 password:password
                                 deviceId:deviceId].catch(^(NSError *error) {

    return [RTAPIErrorFactory translateError:error];

  });
}

+(RTId *) _discoverDeviceIdWithError:(NSError **)error
{
#if !defined(RELEASE)
  if ([NSUserDefaults.standardUserDefaults boolForKey:@"io.retxt.debug.UniqueDeviceId"]) {
    static RTId *_s_uniqueDeviceId;
    static dispatch_once_t _s_uniqueDeviceIdToken;
    dispatch_once(&_s_uniqueDeviceIdToken, ^{
      _s_uniqueDeviceId = [RTId idWithUUID:[NSUUID UUID]];
    });
    return _s_uniqueDeviceId;
  }
#endif
  
  UIDevice *device = [UIDevice currentDevice];
  NSUUID *vendorDeviceId = device.identifierForVendor;
  if (!vendorDeviceId) {
    if (error) {
      *error = [RTAPIErrorFactory deviceNotReadyError];
    }
    return nil;
  }

  return [RTId idWithUUID:vendorDeviceId];
}

+(RTDeviceInfo *) _discoverDeviceInfoWithAliases:(NSArray *)activeAliases error:(NSError **)error
{
  UIDevice *device = [UIDevice currentDevice];

  RTId *deviceId = [self _discoverDeviceIdWithError:error];
  if (!deviceId) {
    return nil;
  }

  NSString *deviceVersion;
  NSArray<NSString *> *deviceModelParts = [UIDevice.deviceModelReadable componentsSeparatedByCharactersInSet:NSCharacterSet.whitespaceCharacterSet];
  if (deviceModelParts.count > 1) {
    deviceModelParts = [deviceModelParts subarrayWithRange:NSMakeRange(1, deviceModelParts.count-1)];
    deviceVersion = deviceModelParts.join(@" ");
  }
  else {
    deviceVersion = deviceModelParts.firstObject ?: @"Unknown";
  }

  RTDeviceInfo *deviceInfo = [RTDeviceInfo new];

  deviceInfo.id = deviceId;
  deviceInfo.name = device.name;
  deviceInfo.manufacturer = @"Apple";
  deviceInfo.model = device.model;
  deviceInfo.version = deviceVersion;
  deviceInfo.osVersion = device.systemVersion;
  deviceInfo.activeAliases = [NSMutableSet setWithArray:activeAliases];

  return deviceInfo;
}

+(RTDeviceInfo *) _matchDeviceInfo:(RTDeviceInfo *)currentDevice toDevices:(NSArray *)devices
{

  RTDeviceInfo *idMatched, *nameMatched;

  // Attempt to match on something

  for (RTDeviceInfo *device in devices) {

    if ([device.id isEqual:currentDevice.id]) {
      idMatched = device;
    }

    if ([device.name isEqualToString:currentDevice.name]) {
      nameMatched = device;
    }

  }

  if (idMatched) {
    return idMatched;
  }

  if (nameMatched) {
    return nameMatched;
  }

  return nil;
}

-(AnyPromise *) updateDevice:(RTId *)deviceId withActiveAliases:(NSSet *)activeAliases
{
  return [self.userAPI updateDeviceActiveAliases:deviceId
                                   activeAliases:activeAliases].catch(^(NSError *error) {

    return [self translateError:error];

  });
}

-(void) sendDirectFrom:(NSString *)sender toRecipientDevices:(NSDictionary *)recipientDevices msgId:(RTId *)msgId msgType:(NSString *)msgType data:(id)data
{
  NSError *error;
  NSData *msgData = [NSJSONSerialization dataWithJSONObject:data options:0 error:&error];

  if (error) {
    DDLogError(@"Send Direct Error: Unable to serialize data: %@", error);
    return;
  }

  [_queue addOperation:[MessageSendDirectOperation.alloc initWithSender:sender
                                                       recipientDevices:recipientDevices
                                                                  msgId:msgId
                                                                msgType:msgType
                                                                msgData:msgData
                                                                    api:self]];

}

-(void) sendReceiptForChat:(RTChat *)chat
{
  RTMessage *message = [_messageDAO fetchLatestUnviewedMessageForChat:chat];
  if (!message) {
    return;
  }

  return [self sendReceiptForChatStartingWithMessage:message];
}

-(void) sendReceiptForChatStartingWithMessage:(RTMessage *)message
{
  [_messageDAO viewAllMessagesForChat:message.chat before:message.sent];

  [self sendReceiptForMessage:message];
}

-(void) sendReceiptForMessage:(RTMessage *)message
{
  // We don't send receipts for enter/exit messages
  if ([message isKindOfClass:[RTEnterMessage class]] || [message isKindOfClass:[RTExitMessage class]]) {
    return;
  }

  if (message.sentByMe) {
    return;
  }

  [_queue addOperation:[MessageSendSystemOperation.alloc initWithMsgType:RTMsgTypeView
                                                                    chat:message.chat
                                                                metaData:@{@"msgId": message.id.UUIDString}
                                                                  target:RTSystemMsgTargetAll
                                                                     api:self]];
}

-(void) showNotificationForMessage:(RTMessage *)message
{
  DDLogDebug(@"SHOWING NOTIFICATION: %@", message.id);

  //FIXME
  //NSString *title = message.chat.title;
  NSString *title = message.chat.activeRecipients.join(@", ");
  
  NSString *body;
  if (RTSettings.sharedSettings.privacyShowPreviews) {

    if (message.clarifyFlag) {

      body = [NSString stringWithFormat:@"%@ %@", title, @"doesn't understand your message"];
    }
    else {

      body = [NSString stringWithFormat:@"%@: %@", title, message.alertText];
    }

  }
  else {

    body = [NSString stringWithFormat:@"%@: %@", title, @"New message"];

  }

  //FIXME
  //NSString *sound = message.clarifyFlag ? RTSound_Message_Clarify : (message.updated ? RTSound_Message_Update : RTSound_Message_Receive);

  UILocalNotification *localNotification = [UILocalNotification new];
  localNotification.category = @"message";
  localNotification.alertBody = body;
  //localNotification.soundName = [RTAppDelegate soundNameForAlert:sound]; //FIXME
  localNotification.userInfo = @{@"msgId" : [message.id description]};
  localNotification.fireDate = [NSDate dateWithTimeIntervalSinceNow:.5];
  localNotification.applicationIconBadgeNumber = [NSUserDefaults.standardUserDefaults integerForKey:@"io.retxt.unread"];

  [self saveAndScheduleNotification:localNotification forMessage:message];
}

-(void) showFailNotificationForMessage:(RTMessage *)message
{
  DDLogDebug(@"SHOWING FAIL NOTIFICATION: %@", message.id);

  //FIXME
  //NSString *title = message.chat.title;
  NSString *title = message.chat.activeRecipients.join(@", ");
  
  NSString *body = [NSString stringWithFormat:@"Failed to send message to: %@", title];

  UILocalNotification *localNotification = [UILocalNotification new];
  localNotification.alertBody = body;
  localNotification.soundName = UILocalNotificationDefaultSoundName;
  localNotification.userInfo = @{@"msgId" : [message.id description]};

  [self saveAndScheduleNotification:localNotification forMessage:message];
}

-(void) saveAndScheduleNotification:(UILocalNotification *)localNotification forMessage:(RTMessage *)message
{
  [UIApplication.sharedApplication scheduleLocalNotification:localNotification];

  RTNotification *notification = [_notificationDAO fetchNotificationWithId:message.id];
  if (!notification) {
    notification = [RTNotification new];
    notification.msgId = message.id;
    notification.chatId = message.chat.id;
  }
  else {
    [self deleteAndCancelNotification:notification ifOnOrBefore:NSDate.date];
  }

  notification.data = [NSKeyedArchiver archivedDataWithRootObject:notification];

  //FIXME error handling
  [_notificationDAO upsertNotification:notification error:nil];
}

-(void) hideNotificationsForChat:(RTChat *)chat
{

  DDLogDebug(@"HIDING NOTIFICATIONS FOR CHAT: %@", chat.id);

  //FIXME error handling
  for (RTNotification *notification in [_notificationDAO fetchAllNotificationsForChat:chat error:nil]) {

    [self deleteAndCancelNotification:notification ifOnOrBefore:NSDate.date];
  }
}


-(void) hideNotificationForMessage:(RTMessage *)message
{

  DDLogDebug(@"HIDING NOTIFICATION FOR MESSAGE: %@", message.id);

  //FIXME error handling
  NSArray *notifications = [_notificationDAO fetchAllNotificationsMatching:@"chatId = ?"
                                                                parameters:@[message.chat.id]
                                                                     error:nil];
  for (RTNotification *notification in notifications) {

    [self deleteAndCancelNotification:notification ifOnOrBefore:message.statusTimestamp];
  }

}

-(void) deleteAndCancelNotification:(RTNotification *)notification ifOnOrBefore:(NSDate *)sent
{
  UILocalNotification *localNotification = [NSKeyedUnarchiver unarchiveObjectWithData:notification.data];
  if ([localNotification.fireDate compare:sent] <= NSOrderedSame) {

    [[UIApplication sharedApplication] cancelLocalNotification:localNotification];

    [_notificationDAO delete:notification];

  }
}

-(void) webSocket:(RTWebSocket *)webSocket willConnect:(NSMutableURLRequest *)request
{
  [request addHTTPBearerAuthorizationWithToken:_accessToken];
  [request addBuildNumber];
}

-(void) webSocket:(RTWebSocket *)webSocket didReceiveUserStatus:(NSString *)sender recipient:(NSString *)recipient status:(enum RTUserStatus)status
{
  DDLogDebug(@"USER STATUS: %@, %@, %d", sender, recipient, (int)status);

  RTChat *chat =  [_chatDAO fetchChatForAlias:sender localAlias:recipient];
  if (chat) {

    RTUserStatusInfo *info = [RTUserStatusInfo userStatus:status forUser:sender inChat:chat];

    dispatch_async(dispatch_get_main_queue(), ^{

      [[NSNotificationCenter defaultCenter] postNotificationName:RTMessageAPIUserStatusDidChangeNotification
                                                          object:self
                                                        userInfo:@{RTMessageAPIUserStatusDidChangeNotification_InfoKey:info}];

    });

  }
}

-(void) webSocket:(RTWebSocket *)webSocket didReceiveGroupStatus:(NSString *)sender chatId:(RTId *)chatId status:(enum RTUserStatus)status
{
  DDLogDebug(@"GROUP STATUS: %@, %@, %d", sender, chatId, (int)status);

  RTChat *chat = [_chatDAO fetchChatWithId:chatId];
  if (chat) {

    RTUserStatusInfo *info = [RTUserStatusInfo userStatus:status forUser:sender inChat:chat];

    dispatch_async(dispatch_get_main_queue(), ^{

      [[NSNotificationCenter defaultCenter] postNotificationName:RTMessageAPIUserStatusDidChangeNotification
                                                          object:self
                                                        userInfo:@{RTMessageAPIUserStatusDidChangeNotification_InfoKey:info}];

    });

  }
}

-(void) webSocket:(RTWebSocket *)webSocket didReceiveMsgReady:(RTMsgHdr *)msgHdr
{
  DDLogDebug(@"MSG READY: %@", msgHdr);

  [_queue addOperation:[MessageRecvOperation.alloc initWithMsgHdr:msgHdr api:self]];
}

-(void) webSocket:(RTWebSocket *)webSocket didReceiveMsgDelivery:(RTMsg *)msg
{
  DDLogDebug(@"MSG DELIVERY: %@, %d, %lld", msg.id, (int)msg.type, msg.sent);

  [_queue addOperation:[MessageRecvOperation.alloc initWithMsg:msg api:self]];
}

-(void) webSocket:(RTWebSocket *)webSocket didReceiveMsgDelivered:(RTId *)msgId recipient:(NSString *)recipient
{
  DDLogDebug(@"MSG DELIVERED: %@, %@", msgId, recipient);

  [_queue addOperation:[MessageDeliveredOperation.alloc initWithMsgId:msgId api:self]];
}

-(void) webSocket:(RTWebSocket *)webSocket didReceiveMsgDirect:(RTDirectMsg *)msg
{
  DDLogDebug(@"MSG DIRECT: %@, %@, %@, %@", msg.id, msg.type, msg.sender, msg.senderDevice);

  [self reportDirectMessage:msg];

}

-(NSError *) translateError:(NSError *)error
{
  error = [RTAPIErrorFactory translateError:error];

  if ([error checkAPIError:RTAPIErrorAuthenticationError]) {

    [self signOut];

  }

  if (error.code == RTAPIErrorInvalidCredentials) {

    [self invalidateUserWithAlias:error.userInfo[@"recipient"]];

  }

  return error;
}

@end
