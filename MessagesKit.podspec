Pod::Spec.new do |s|
  s.name = 'MessagesKit'
  s.version = '0.1'
  s.summary = 'reTXT messaging framework for iOS/OSX'
  s.homepage = 'https://github.com/reTXT/MessagesKit'
  s.license = 'MIT'
  s.author = { 'Kevin Wooten' => 'kevin@retxt.com' }
  s.source = { :git => 'https://github.com/reTXT/MessagesKit.git', :tag => "#{s.version}" }
  s.requires_arc = true

  s.source_files = 'MessagesKit/*.{h,m,swift}'
  s.exclude_files = 'src/fmdb.m'

  s.dependency 'OpenSSLCrypto'
  s.dependency 'CocoaLumberjack/Swift'
  s.dependency 'DeviceKit'
  s.dependency 'FMDB/standalone/swift'
  s.dependency 'FMDBMigrationManager'
  s.dependency 'HTMLReader'
  s.dependency 'PromiseKit/DietFoundation'
  s.dependency 'PromiseKit/AddressBook'
  s.dependency 'PromiseKit/AssetsLibrary'
  s.dependency 'PromiseKit/AVFoundation'
  s.dependency 'PSOperations'
  s.dependency 'SocketRocket'
  s.dependency 'SSKeychain'
  s.dependency 'Thrift'
  s.dependency 'YOLOKit'

end
