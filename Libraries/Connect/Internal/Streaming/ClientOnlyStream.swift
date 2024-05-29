// Copyright 2022-2024 The Connect Authors
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

import SwiftProtobuf

/// Concrete implementation of `ClientOnlyStreamInterface`.
final class ClientOnlyStream<Input: ProtobufMessage, Output: ProtobufMessage>: @unchecked Sendable {
    private let onResult: @Sendable (StreamResult<Output>) -> Void
    /// Callbacks used to send outbound data and close the stream.
    /// Optional because these callbacks are not available until the stream is initialized.
    private var requestCallbacks: RequestCallbacks<Input>?
    private let receivedMessageCount = Locked(0)

    private struct NotConfiguredForSendingError: Swift.Error {}

    init(onResult: @escaping @Sendable (StreamResult<Output>) -> Void) {
        self.onResult = onResult
    }

    /// Enable sending data over this stream by providing a set of request callbacks to route data
    /// to the network client. Must be called before calling `send()`.
    ///
    /// - parameter requestCallbacks: Callbacks to use for sending request data and closing the
    ///                               stream.
    ///
    /// - returns: This instance of the stream (useful for chaining).
    @discardableResult
    func configureForSending(with requestCallbacks: RequestCallbacks<Input>) -> Self {
        self.requestCallbacks = requestCallbacks
        return self
    }

    /// Send a result to the consumer after doing additional validations for client-only streams.
    /// Should be called by the protocol client when a result is received.
    ///
    /// - parameter result: The new result that was received.
    func receive(_ result: StreamResult<Output>) {
        let receivedMessageCount = self.receivedMessageCount.perform { value in
            if case .message = result {
                value += 1
            }
            return value
        }
        self.onResult(result.validatedForClientStream(receivedMessageCount: receivedMessageCount))
    }
}

extension ClientOnlyStream: ClientOnlyStreamInterface {
    @discardableResult
    func send(_ input: Input) throws -> Self {
        guard let sendData = self.requestCallbacks?.sendData else {
            throw NotConfiguredForSendingError()
        }

        sendData(input)
        return self
    }

    func closeAndReceive() {
        self.requestCallbacks?.sendClose()
    }

    func cancel() {
        self.requestCallbacks?.cancel()
    }
}
