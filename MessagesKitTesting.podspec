Pod::Spec.new do |s|
  s.name = 'MessagesKitTesting'
  s.version = '0.1'
  s.summary = 'reTXT messaging framework testing support for iOS/OSX'
  s.homepage = 'https://github.com/reTXT/MessagesKit'
  s.license = 'MIT'
  s.author = { 'Kevin Wooten' => 'kevin@retxt.com' }
  s.source = { :git => 'https://github.com/reTXT/MessagesKit.git', :tag => "#{s.version}" }
  s.requires_arc = true

  s.source_files = 'MessagesKitTests/Support/*.{h,m,swift}'

  s.dependency 'MessagesKit'
  s.dependency 'OMGHTTPURLRQ'

end
