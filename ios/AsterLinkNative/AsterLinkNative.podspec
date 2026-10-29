Pod::Spec.new do |s|
  s.name             = 'AsterLinkNative'
  s.version          = '1.0.0'
  s.summary          = 'AsterLink iOS platform bridge and download engine.'
  s.homepage         = 'https://github.com/7QUcc/wenxi'
  s.license          = { :type => 'AGPL-3.0' }
  s.author           = 'AsterLink'
  s.source           = { :path => '.' }
  s.platform         = :ios, '15.0'
  s.swift_version    = '5.0'
  s.source_files     = 'Classes/**/*.swift'
  # Gopeed.xcframework is produced by tool/build-ios.sh and never committed.
  s.vendored_frameworks = 'Frameworks/Gopeed.xcframework'
  s.frameworks       = 'AVFoundation', 'UIKit'
  s.dependency 'Flutter'
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES' }
end
