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
  s.dependency 'DeviceKit'
  s.dependency 'FMDB/standalone/swift'
  s.dependency 'FMDBMigrationManager'
  s.dependency 'HTMLReader'
  s.dependency 'OpenSSL', '1.0.207'
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
