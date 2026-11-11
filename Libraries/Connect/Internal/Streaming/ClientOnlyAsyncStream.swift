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

import SwiftProtobuf

/// Concrete **internal** implementation of `ClientOnlyAsyncStreamInterface`.
/// Overlays additional client-only validation on top of a `BidirectionalAsyncStream`, which
/// provides the wiring from closures/callbacks to Swift's `AsyncStream`.
final class ClientOnlyAsyncStream<
    Input: ProtobufMessage, Output: ProtobufMessage
>: Sendable {
    private let bidirectionalStream: BidirectionalAsyncStream<Input, Output>
    private let receivedResults = Locked([StreamResult<Output>]())

    init(bidirectionalStream: BidirectionalAsyncStream<Input, Output>) {
        self.bidirectionalStream = bidirectionalStream
    }

    /// Send a result to the consumer after doing additional validations for client-only streams.
    /// Should be called by the protocol client when a result is received from the network.
    ///
    /// - parameter result: The new result that was received.
    func handleResultFromServer(_ result: StreamResult<Output>) {
        let (isComplete, results) = self.receivedResults.perform { results in
            results.append(result)
            if case .complete = result {
                return (true, ClientOnlyStreamValidation.validatedFinalClientStreamResults(results))
            } else {
                return (false, [])
            }
        }
        guard isComplete else {
            return
        }
        results.forEach(self.bidirectionalStream.handleResultFromServer)
    }
}

extension ClientOnlyAsyncStream: ClientOnlyAsyncStreamInterface {
    @discardableResult
    func send(_ input: Input) throws -> Self {
        try self.bidirectionalStream.send(input)
        return self
    }

    func results() -> AsyncStream<StreamResult<Output>> {
        return self.bidirectionalStream.results()
    }

    func closeAndReceive() {
        self.bidirectionalStream.close()
    }

    func cancel() {
        self.bidirectionalStream.cancel()
    }
}
