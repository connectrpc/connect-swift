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
import Dispatch
import NIOPosix
import Testing

struct NIOHTTPClientTests {
    /// A client which creates its own event loop group shuts that group down on deallocation, but
    /// an injected group belongs to the caller and must outlive the client so that several clients
    /// can share one group.
    @Test
    func deinitDoesNotShutDownInjectedGroup() {
        let group = NIOPosix.MultiThreadedEventLoopGroup(numberOfThreads: 1)
        defer { try? group.syncShutdownGracefully() }

        // Scoped so that the client is released before the group is exercised below.
        do {
            let client = NIOHTTPClient(host: "https://connectrpc.com", eventLoopGroup: group)
            #expect(client.eventLoopGroup as AnyObject === group as AnyObject)
        }

        let didRun = DispatchSemaphore(value: 0)
        group.next().execute { didRun.signal() }
        #expect(didRun.wait(timeout: .now() + .seconds(5)) == .success)
    }
}
