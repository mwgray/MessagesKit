Pod::Spec.new do |s|
  s.name = 'Messages'
  s.version = '0.1'
  s.summary = 'reTXT Messages SDK for iOS/OSX'
  s.homepage = 'https://github.com/reTXT/Messages'
  s.license = 'MIT'
  s.author = { 'Kevin Wooten' => 'kevin@retxt.com' }
  s.source = { :git => 'https://github.com/reTXT/Messages.git', :tag => "#{s.version}" }
  s.requires_arc = true

  s.source_files = 'Messages/*.{h,m,swift}'
  s.exclude_files = 'src/fmdb.m'

  s.dependency 'CocoaLumberjack/Swift'
  s.dependency 'OpenSSL'
  s.dependency 'JWTDecode'
  s.dependency 'HTMLReader'
  s.dependency 'SSKeychain'
  s.dependency 'SocketRocket'
  s.dependency 'FMDB/standalone/swift'
  s.dependency 'FMDBMigrationManager'
  s.dependency 'YOLOKit'
  s.dependency 'Operations'
  s.dependency 'Thrift'
  s.dependency 'PromiseKit'
  s.dependency 'PromiseKit/AddressBook'
  s.dependency 'PromiseKit/AssetsLibrary'
  s.dependency 'PromiseKit/AVFoundation'

end
