// Copyright 2022-2023 Buf Technologies, Inc.
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
import ConnectGRPC
import SwiftUI

private enum MessagingConnectionType: Int, CaseIterable {
    case connectUnary
    case connectStreaming
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
    private func createClient(withProtocol networkProtocol: NetworkProtocol)
        -> Buf_Connect_Demo_Eliza_V1_ElizaServiceClient
    {
        let protocolClient = ProtocolClient(
            httpClient: NIOHTTPClient(host: "demo.connect.build"),
            config: ProtocolClientConfig(
                host: "https://demo.connect.build",
                networkProtocol: networkProtocol,
                codec: ProtoCodec() // Protobuf binary, or JSONCodec() for JSON
            )
        )
        return Buf_Connect_Demo_Eliza_V1_ElizaServiceClient(client: protocolClient)
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 15) {
                Text("Buf Demo")
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
                                        client: self.createClient(withProtocol: .connect)
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
                                        client: self.createClient(withProtocol: .connect)
                                    )
                                )
                            }
                            .navigationTitle("Eliza Chat (Streaming)")
                        )

                    case .grpcWebUnary:
                        NavigationLink(
                            "gRPC Web (Unary)",
                            destination: LazyNavigationView {
                                MessagingView(
                                    viewModel: UnaryMessagingViewModel(
                                        client: self.createClient(withProtocol: .grpcWeb)
                                    )
                                )
                            }
                            .navigationTitle("Eliza Chat (gRPC-W Unary)")
                        )

                    case .grpcWebStreaming:
                        NavigationLink(
                            "gRPC Web (Streaming)",
                            destination: LazyNavigationView {
                                MessagingView(
                                    viewModel: BidirectionalStreamingMessagingViewModel(
                                        client: self.createClient(withProtocol: .grpcWeb)
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
