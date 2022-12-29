// Copyright 2022 Buf Technologies, Inc.
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

import Combine
import Connect
import Dispatch
import Generated
import os.log

private typealias ConverseRequest = Buf_Connect_Demo_Eliza_V1_ConverseRequest
private typealias ConverseResponse = Buf_Connect_Demo_Eliza_V1_ConverseResponse

private typealias SayRequest = Buf_Connect_Demo_Eliza_V1_SayRequest
private typealias SayResponse = Buf_Connect_Demo_Eliza_V1_SayResponse

/// View model that can be injected into a `MessagingView`.
protocol MessagingViewModel: ObservableObject {
    /// The current set of messages. Observable by storing the view model as an `@ObservedObject`.
    @MainActor var messages: [Message] { get }

    /// Send a message to the upstream service.
    /// This message and any responses will be appended to `messages`.
    ///
    /// - parameter message: The message to send.
    func send(_ message: String) async

    /// End the chat session (and close connections if needed).
    func endChat()
}

/// View model that uses unary requests for messaging.
final class UnaryMessagingViewModel: MessagingViewModel {
    private let protocolClient: ProtocolClient
    private lazy var elizaClient = Buf_Connect_Demo_Eliza_V1_ElizaServiceClient(
        client: self.protocolClient
    )

    @MainActor @Published private(set) var messages = [Message]()

    init(protocolOption: ProtocolClientOption) {
        self.protocolClient = ProtocolClient(
            target: "https://demo.connect.build",
            httpClient: URLSessionHTTPClient(),
            ProtoClientOption(), // Send protobuf binary on the wire
            protocolOption // Specify the protocol to use for the client
        )
    }

    func send(_ sentence: String) async {
        let request = SayRequest.with { $0.sentence = sentence }
        await self.addMessage(Message(message: sentence, author: .user))

        let response = await self.elizaClient.say(request: request)
        os_log(.debug, "Eliza unary response: %@", String(describing: response))
        await self.addMessage(Message(
            message: response.message?.sentence ?? "No response", author: .eliza
        ))
     }

    func endChat() {}

    @MainActor
    private func addMessage(_ message: Message) {
        self.messages.append(message)
    }
}

/// View model that uses bidirectional streaming for messaging.
final class BidirectionalStreamingMessagingViewModel: MessagingViewModel {
    private let protocolClient: ProtocolClient
    private lazy var elizaClient = Buf_Connect_Demo_Eliza_V1_ElizaServiceClient(
        client: self.protocolClient
    )
    private lazy var elizaStream = self.elizaClient.converse()

    @MainActor @Published private(set) var messages = [Message]()

    init(protocolOption: ProtocolClientOption) {
        self.protocolClient = ProtocolClient(
            target: "https://demo.connect.build",
            httpClient: URLSessionHTTPClient(),
            ProtoClientOption(), // Send protobuf binary on the wire
            protocolOption // Specify the protocol to use for the client
        )
        self.observeResponses()
    }

    func send(_ sentence: String) async {
        do {
            let request = ConverseRequest.with { $0.sentence = sentence }
            await self.addMessage(Message(message: sentence, author: .user))
            try self.elizaStream.send(request)
        } catch let error {
            os_log(
                .error, "Failed to write message to stream: %@", error.localizedDescription
            )
        }
    }

    func endChat() {
        self.elizaStream.close()
    }

    private func observeResponses() {
        Task {
            for await result in self.elizaStream.results() {
                switch result {
                case .headers(let headers):
                    os_log(.debug, "Eliza headers: %@", headers)

                case .message(let message):
                    os_log(.debug, "Eliza message: %@", String(describing: message))
                    await self.addMessage(Message(message: message.sentence, author: .eliza))

                case .complete(_, let error, let trailers):
                    os_log(.debug, "Eliza completed with trailers: %@", trailers ?? [:])
                    let sentence: String
                    if let error = error {
                        os_log(.error, "Eliza error: %@", error.localizedDescription)
                        sentence = "[Error: \(error)]"
                    } else {
                        sentence = "[Conversation ended]"
                    }
                    await self.addMessage(Message(message: sentence, author: .eliza))
                }
            }
        }
    }

    @MainActor
    private func addMessage(_ message: Message) {
        self.messages.append(message)
        print(self.messages)
    }
}
