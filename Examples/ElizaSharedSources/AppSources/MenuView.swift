// Copyright 2022-2025 The Connect Authors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import Connect
#if !COCOAPODS
// SwiftNIO (and gRPC) support is not available via CocoaPods since SwiftNIO does not support it.
// This import is only necessary if using gRPC, not for Connect or gRPC-Web.
import ConnectNIO
#endif
import SwiftUI

private enum MessagingConnectionType: Int, CaseIterable {
    case connectUnary
    case connectStreaming
    case grpcUnary
    case grpcStreaming
    case grpcWebUnary
    case grpcWebStreaming
}

extension MessagingConnectionType: Identifiable {
    typealias ID = RawValue

    var id: ID {
        return self.rawValue
    }
}

struct MenuView: View {
    private static func createClient(withProtocol networkProtocol: NetworkProtocol)
        -> Connectrpc_Eliza_V1_ElizaServiceClient
    {
        let host = "https://demo.connectrpc.com"
        let config = ProtocolClientConfig(
            host: host,
            networkProtocol: networkProtocol,
            codec: ProtoCodec(), // Protobuf binary, or JSONCodec() for JSON
            unaryGET: .disabled // Can enable to use cacheable unary HTTP GET requests
        )
        #if !COCOAPODS
        // For gRPC (which is not supported by CocoaPods), use the NIO HTTP client:
        if case .custom = networkProtocol {
            return Connectrpc_Eliza_V1_ElizaServiceClient(
                client: ProtocolClient(
                    httpClient: NIOHTTPClient(host: host),
                    config: config
                )
            )
        }
        #endif
        return Connectrpc_Eliza_V1_ElizaServiceClient(
            client: ProtocolClient(
                httpClient: URLSessionHTTPClient(),
                config: config
            )
        )
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 15) {
                Text("Connect Demo")
                    .font(.title)

                Text("Select a protocol to use for chatting with Eliza, a conversational bot.")
                    .font(.body)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                    .padding([.leading, .trailing])

                List(MessagingConnectionType.allCases) { connectionType in
                    switch connectionType {
                    case .connectUnary:
                        NavigationLink(
                            "Connect (Unary)",
                            destination: LazyNavigationView {
                                MessagingView(
                                    viewModel: UnaryMessagingViewModel(
                                        client: Self.createClient(withProtocol: .connect)
                                    )
                                )
                            }
                            .navigationTitle("Eliza Chat (Unary)")
                        )

                    case .connectStreaming:
                        NavigationLink(
                            "Connect (Streaming)",
                            destination: LazyNavigationView {
                                MessagingView(
                                    viewModel: BidirectionalStreamingMessagingViewModel(
                                        client: Self.createClient(withProtocol: .connect)
                                    )
                                )
                            }
                            .navigationTitle("Eliza Chat (Streaming)")
                        )

                    case .grpcUnary:
                        #if !COCOAPODS
                        NavigationLink(
                            "gRPC (Unary)",
                            destination: LazyNavigationView {
                                MessagingView(
                                    viewModel: UnaryMessagingViewModel(
                                        client: Self.createClient(withProtocol: .grpc)
                                    )
                                )
                            }
                            .navigationTitle("Eliza Chat (gRPC Unary)")
                        )
                        #endif

                    case .grpcWebUnary:
                        NavigationLink(
                            "gRPC Web (Unary)",
                            destination: LazyNavigationView {
                                MessagingView(
                                    viewModel: UnaryMessagingViewModel(
                                        client: Self.createClient(withProtocol: .grpcWeb)
                                    )
                                )
                            }
                            .navigationTitle("Eliza Chat (gRPC-W Unary)")
                        )

                    case .grpcStreaming:
                        #if !COCOAPODS
                        NavigationLink(
                            "gRPC (Streaming)",
                            destination: LazyNavigationView {
                                MessagingView(
                                    viewModel: BidirectionalStreamingMessagingViewModel(
                                        client: Self.createClient(withProtocol: .grpc)
                                    )
                                )
                            }
                            .navigationTitle("Eliza Chat (gRPC Streaming)")
                        )
                        #endif

                    case .grpcWebStreaming:
                        NavigationLink(
                            "gRPC Web (Streaming)",
                            destination: LazyNavigationView {
                                MessagingView(
                                    viewModel: BidirectionalStreamingMessagingViewModel(
                                        client: Self.createClient(withProtocol: .grpcWeb)
                                    )
                                )
                            }
                            .navigationTitle("Eliza Chat (gRPC-W Streaming)")
                        )
                    }
                }
            }
        }
    }
}

/// Workaround wrapper that allows `NavigationLink` destinations to be instantiated only when
/// they are used, rather than all at once when the containing view is instantiated.
private struct LazyNavigationView<Content: View>: View {
    @ViewBuilder private let build: () -> Content

    init(@ViewBuilder _ build: @escaping () -> Content) {
        self.build = build
    }

    var body: Content {
        self.build()
    }
}
