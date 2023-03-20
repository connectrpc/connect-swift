Pod::Spec.new do |spec|
  spec.name = 'Connect-Swift-GRPC'
  spec.module_name = 'ConnectGRPC'
  spec.version = '0.4.0'
  spec.license = { :type => 'Apache 2.0', :file => 'LICENSE' }
  spec.summary = 'Idiomatic gRPC & Connect RPCs for Swift.'
  spec.homepage = 'https://github.com/bufbuild/connect-swift'
  spec.author = 'Buf Technologies, Inc.'
  spec.source = { :git => 'https://github.com/bufbuild/connect-swift.git', :tag => spec.version }

  spec.ios.deployment_target = '14.0'
  spec.osx.deployment_target = '10.15'

  spec.dependency 'Connect-Swift', "#{spec.version.to_s}"
  # TODO: Update NIO dependencies once available https://github.com/apple/swift-nio/issues/2393
  spec.dependency 'SwiftNIO', '~> 2.40.0'
  spec.dependency 'SwiftNIOFoundationCompat', '~> 2.40.0'
  spec.dependency 'SwiftNIOHTTP2', '~> 1.22.0'
  spec.dependency 'SwiftNIOSSL', '~> 2.19.0'
  spec.dependency 'SwiftProtobuf', '~> 1.21.0'

  spec.source_files = 'Libraries/ConnectGRPC/**/*.swift'

  spec.swift_versions = ['5.0']
end
