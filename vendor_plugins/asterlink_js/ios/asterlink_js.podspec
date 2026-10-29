Pod::Spec.new do |s|
  s.name             = 'asterlink_js'
  s.version          = '1.0.0'
  s.summary          = 'Bounded QuickJS runtime for signed AsterLink source packages.'
  s.homepage         = 'https://github.com/quickjs-ng/quickjs'
  s.license          = { :type => 'MIT', :file => '../src/quickjs/LICENSE' }
  s.author           = 'AsterLink'
  s.source           = { :path => '.' }
  s.source_files     = 'Classes/**/*'
  s.dependency 'Flutter'
  s.platform         = :ios, '13.0'
  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
    'HEADER_SEARCH_PATHS' => '"${PODS_TARGET_SRCROOT}/../src/quickjs"',
    'GCC_C_LANGUAGE_STANDARD' => 'gnu11',
    'GCC_WARN_INHIBIT_ALL_WARNINGS' => 'YES',
  }
end
