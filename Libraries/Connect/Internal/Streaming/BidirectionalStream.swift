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

/// Concrete implementation of `BidirectionalStreamInterface`.
final class BidirectionalStream<Message: ProtobufMessage>: Sendable {
    private let requestCallbacks: RequestCallbacks<Message>

    init(requestCallbacks: RequestCallbacks<Message>) {
        self.requestCallbacks = requestCallbacks
    }
}

extension BidirectionalStream: BidirectionalStreamInterface {
    typealias Input = Message

    @discardableResult
    func send(_ input: Input) -> Self {
        self.requestCallbacks.sendData(input)
        return self
    }

    func close() {
        self.requestCallbacks.sendClose()
    }

    func cancel() {
        self.requestCallbacks.cancel()
    }
}

// Conforms to the client-only interface since it matches exactly and the implementation is internal
extension BidirectionalStream: ClientOnlyStreamInterface {}
