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

end
