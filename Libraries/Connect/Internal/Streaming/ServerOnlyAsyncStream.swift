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

/// Concrete implementation of `ServerOnlyAsyncStreamInterface`.
@available(iOS 13, *)
final class ServerOnlyAsyncStream<Input: ProtobufMessage, Output: ProtobufMessage>: Sendable {
    private let bidirectionalStream: BidirectionalAsyncStream<Input, Output>

    init(bidirectionalStream: BidirectionalAsyncStream<Input, Output>) {
        self.bidirectionalStream = bidirectionalStream
    }
}

@available(iOS 13, *)
extension ServerOnlyAsyncStream: ServerOnlyAsyncStreamInterface {
    func send(_ input: Input) throws {
        try self.bidirectionalStream.send(input)
        self.bidirectionalStream.close()
    }

    func results() -> AsyncStream<StreamResult<Output>> {
        return self.bidirectionalStream.results()
    }

    func cancel() {
        self.bidirectionalStream.cancel()
    }
}
