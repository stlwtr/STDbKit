Pod::Spec.new do |s|
  s.name             = 'STDbKit'
  s.version          = '2.3.0'
  s.summary          = 'Like CoreData, object auto convert to sqlite3.'
  s.homepage         = 'https://github.com/stlwtr/STDbKit.git'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.authors           = { 'stlwtr' => '2008.yls@163.com' }
  s.source           = { :git => 'https://github.com/stlwtr/STDbKit.git', :tag => s.version }

  s.ios.deployment_target = '8.0'

  s.source_files = 'STDbKit/**/*.{h,m}'
  s.public_header_files = 'STDbKit/**/*.h'
  s.library = 'sqlite3'
end
