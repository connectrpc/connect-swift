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

/// Internal actor used to wrap closure-based unary API calls in a way that allows them
/// to be used with async/await while properly supporting cancelation.
///
/// For discussions on why this is necessary, see:
/// https://forums.swift.org/t/how-to-use-withtaskcancellationhandler-properly/54341/37
/// https://stackoverflow.com/q/71898080
@available(iOS 13, *)
actor UnaryAsyncWrapper<Output: ProtobufMessage>: Sendable {
    private var cancelable: Cancelable?
    private let sendUnary: PerformClosure

    /// Accepts a closure to be called upon completion of a request and returns a cancelable which,
    /// when invoked, will cancel the underlying request.
    typealias PerformClosure = @Sendable (
        @escaping @Sendable (ResponseMessage<Output>) -> Void
    ) -> Cancelable

    init(sendUnary: @escaping PerformClosure) {
        self.sendUnary = sendUnary
    }

    /// Provides an `async` interface for performing the `sendUnary` request.
    /// Canceling the request in the context of an async `Task` will appropriately cancel the
    /// outbound request and return a response with a `.canceled` status code.
    ///
    /// - returns: The response/result of the request.
    func send() async -> ResponseMessage<Output> {
        return await withTaskCancellationHandler(operation: {
            return await withCheckedContinuation { continuation in
                if Task.isCancelled {
                    continuation.resume(
                        returning: .init(code: .canceled, result: .failure(.canceled()))
                    )
                } else {
                    self.cancelable = self.sendUnary { response in
                        continuation.resume(returning: response)
                    }
                }
            }
        }, onCancel: {
            Task { await self.cancelable?.cancel() }
        })
    }
}
