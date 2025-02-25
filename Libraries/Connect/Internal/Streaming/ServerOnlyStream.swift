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

/// Concrete **internal** implementation of `ServerOnlyStreamInterface`.
final class ServerOnlyStream<Message: ProtobufMessage>: Sendable {
    private let bidirectionalStream: BidirectionalStream<Message>

    init(bidirectionalStream: BidirectionalStream<Message>) {
        self.bidirectionalStream = bidirectionalStream
    }
}

extension ServerOnlyStream: ServerOnlyStreamInterface {
    typealias Input = Message

    func send(_ input: Message) {
        self.bidirectionalStream.send(input)
        self.bidirectionalStream.close()
    }

    func cancel() {
        self.bidirectionalStream.cancel()
    }
}
