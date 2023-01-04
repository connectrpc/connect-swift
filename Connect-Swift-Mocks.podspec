Pod::Spec.new do |spec|
  spec.name = 'Connect-Swift-Mocks'
  spec.module_name = 'ConnectMocks'
  spec.version = '0.0.1'
  spec.license = { :type => 'Apache 2.0', :file => 'LICENSE' }
  spec.summary = 'Mock types designed to be used for testing in conjunction with Connect-Swift.'
  spec.homepage = 'https://github.com/bufbuild/connect-swift'
  spec.author = 'Buf Technologies, Inc.'
  spec.source = { :git => 'https://github.com/bufbuild/connect-swift.git', :tag => spec.version }

  spec.ios.deployment_target = '14.0'
  spec.osx.deployment_target = '10.15'

  spec.dependency 'Connect-Swift', "#{spec.version.to_s}"
  spec.dependency 'SwiftProtobuf', '~> 1.20.3'

  spec.source_files = 'ConnectMocks/**/*.swift'

  spec.swift_versions = ['5.0']
end
