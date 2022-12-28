//
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
//

import SwiftProtobuf

/// Concrete implementation of `ServerOnlyAsyncStreamInterface`.
final class ServerOnlyAsyncStream<Input: SwiftProtobuf.Message, Output: SwiftProtobuf.Message> {
    private let bidirectionalStream: BidirectionalAsyncStream<Input, Output>

    init(bidirectionalStream: BidirectionalAsyncStream<Input, Output>) {
        self.bidirectionalStream = bidirectionalStream
    }
}

extension ServerOnlyAsyncStream: ServerOnlyAsyncStreamInterface {
    func send(_ input: Input) throws {
        try self.bidirectionalStream.send(input)
        self.bidirectionalStream.close()
    }

    func results() -> AsyncStream<StreamResult<Output>> {
        return self.bidirectionalStream.results()
    }
}
