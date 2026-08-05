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

@testable import ConnectNIO
import NIOPosix
import Testing

struct NIOHTTPClientTests {
    /// A client shuts down the group it created, but an injected group belongs to the caller and
    /// must outlive the client so that several clients can share one.
    @available(macOS 13, iOS 16, watchOS 9, tvOS 16, *)
    @Test(.timeLimit(.minutes(1)))
    func deinitDoesNotShutDownInjectedGroup() async {
        let group = NIOPosix.MultiThreadedEventLoopGroup(numberOfThreads: 1)

        // Scoped so the client is released before the group is exercised below.
        do {
            let client = NIOHTTPClient(host: "https://connectrpc.com", eventLoopGroup: group)
            #expect(client.eventLoopGroup as AnyObject === group as AnyObject)
        }

        await confirmation("the injected group still schedules") { confirm in
            await withCheckedContinuation { continuation in
                group.next().execute {
                    confirm()
                    continuation.resume()
                }
            }
        }

        try? await group.shutdownGracefully()
    }
}
