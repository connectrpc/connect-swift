import Combine
import Connect
import Dispatch
import os.log
import SwiftGenerated

private typealias ConverseRequest = Buf_Connect_Demo_Eliza_V1_ConverseRequest
private typealias ConverseResponse = Buf_Connect_Demo_Eliza_V1_ConverseResponse

private typealias SayRequest = Buf_Connect_Demo_Eliza_V1_SayRequest
private typealias SayResponse = Buf_Connect_Demo_Eliza_V1_SayResponse

/// View model that can be injected into a `MessagingView`.
protocol MessagingViewModel: ObservableObject {
    /// The current set of messages. Observable by storing the view model as an `@ObservedObject`.
    var messages: [Message] { get }

    /// Send a message to the upstream service.
    /// This message and any responses will be appended to `messages`.
    ///
    /// - parameter message: The message to send.
    func send(_ message: String)

    /// End the chat session (and close connections if needed).
    func endChat()
}

/// View model that uses unary requests for messaging.
final class UnaryMessagingViewModel: MessagingViewModel {
    private let protocolClient: ProtocolClient
    private lazy var elizaClient = ElizaServiceClient(client: self.protocolClient)

    @Published private(set) var messages = [Message]()

    init(protocolOption: ProtocolClientOption) {
        self.protocolClient = ProtocolClient(
            target: "https://demo.connect.build",
            httpClient: URLSessionHTTPClient(),
            ProtoClientOption(), // Send protobuf binary on the wire
            protocolOption // Specify the protocol to use for the client
        )
    }

    func send(_ sentence: String) {
        let request = SayRequest.with { $0.sentence = sentence }
        self.messages.append(Message(message: sentence, author: .user))
        self.elizaClient.say(request: request) { [weak self] response in
            os_log(.debug, "Eliza unary response: %@", String(describing: response))

            // UI updates must be performed on the main thread.
            DispatchQueue.main.async {
                self?.messages.append(Message(
                    message: response.message?.sentence ?? "No response", author: .eliza
                ))
            }
        }
    }

    func endChat() {}
}

/// View model that uses bidirectional streaming for messaging.
final class BidirectionalStreamingMessagingViewModel: MessagingViewModel {
    private let protocolClient: ProtocolClient
    private lazy var elizaClient = ElizaServiceClient(client: self.protocolClient)
    private var elizaStream: (any BidirectionalStreamInterface<ConverseRequest>)?

    @Published private(set) var messages = [Message]()

    init(protocolOption: ProtocolClientOption) {
        self.protocolClient = ProtocolClient(
            target: "https://demo.connect.build",
            httpClient: URLSessionHTTPClient(),
            ProtoClientOption(), // Send protobuf binary on the wire
            protocolOption // Specify the protocol to use for the client
        )
    }

    func send(_ sentence: String) {
        do {
            let request = ConverseRequest.with { $0.sentence = sentence }
            self.messages.append(Message(message: sentence, author: .user))
            try self.getOrCreateStream().send(request)
        } catch let error {
            os_log(
                .error, "Failed to write message to stream: %@", error.localizedDescription
            )
        }
    }

    func endChat() {
        self.elizaStream?.close()
        self.elizaStream = nil
    }

    private func getOrCreateStream() -> any BidirectionalStreamInterface<ConverseRequest> {
        if let activeStream = self.elizaStream {
            return activeStream
        }

        let newStream = self.elizaClient.converse { [weak self] result in
            switch result {
            case .headers(let headers):
                os_log(.debug, "Eliza headers: %@", headers)

            case .message(let message):
                os_log(.debug, "Eliza message: %@", String(describing: message))

                // UI updates must be performed on the main thread.
                DispatchQueue.main.async {
                    self?.messages.append(Message(message: message.sentence, author: .eliza))
                }

            case .complete(_, let error, let trailers):
                os_log(.debug, "Eliza completed with trailers: %@", trailers ?? [:])

                // UI updates must be performed on the main thread.
                DispatchQueue.main.async {
                    let sentence: String
                    if let error = error {
                        os_log(.error, "Eliza error: %@", error.localizedDescription)
                        sentence = "[Error: \(error)]"
                    } else {
                        sentence = "[Conversation ended]"
                    }
                    self?.messages.append(Message(message: sentence, author: .eliza))
                    self?.elizaStream = nil
                }
            }
        }
        self.elizaStream = newStream
        return newStream
    }
}
