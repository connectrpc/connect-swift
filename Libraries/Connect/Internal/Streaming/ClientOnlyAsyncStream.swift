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

import Foundation

/// Concrete **internal** implementation of `ClientOnlyAsyncStreamInterface`.
/// Provides the necessary wiring to bridge from closures/callbacks to Swift's `AsyncStream`
/// to work with async/await.
///
/// This subclasses `BidirectionalAsyncStream` since its behavior is purely additive (it overlays
/// some additional validation) and both types are internal to the package, not public.
@available(iOS 13, *)
final class ClientOnlyAsyncStream<
    Input: ProtobufMessage, Output: ProtobufMessage
>: BidirectionalAsyncStream<Input, Output> {
    private let receivedMessageCount = Locked(0)

    override func handleResultFromServer(_ result: StreamResult<Output>) {
        let receivedMessageCount = self.receivedMessageCount.perform { value in
            if case .message = result {
                value += 1
            }
            return value
        }
        super.handleResultFromServer(
            result.validatedForClientStream(receivedMessageCount: receivedMessageCount)
        )
    }
}

@available(iOS 13, *)
extension ClientOnlyAsyncStream: ClientOnlyAsyncStreamInterface {
    func closeAndReceive() {
        self.close()
    }
}
