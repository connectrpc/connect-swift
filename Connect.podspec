Pod::Spec.new do |spec|
  spec.name = 'Connect'
  spec.version = '0.0.1'
  spec.license = { :type => 'Apache 2.0', :file => 'LICENSE' }
  spec.summary = 'Connect is a slim library for building Protobuf- and gRPC-compatible HTTP APIs.'
  spec.homepage = 'https://github.com/bufbuild/connect-swift'
  spec.author = 'Buf Technologies, Inc.'
  spec.source = { :git => 'https://github.com/bufbuild/connect-swift.git', :tag => spec.version }

  spec.ios.deployment_target = '14.0'
  spec.osx.deployment_target = '10.15'

  spec.dependency 'SwiftProtobuf', '~> 1.20.3'

  spec.source_files = 'Connect/**/*.swift'

  spec.swift_versions = ['5.0']
end
