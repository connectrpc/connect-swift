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

import Foundation

/// Stream implementation that wraps a `URLSession` stream.
///
/// Note: This class is `@unchecked Sendable` because the `Foundation.{Input|Output}Stream`
/// types do not conform to `Sendable`.
final class URLSessionStream: NSObject, @unchecked Sendable {
    private let closedByServer = Locked(false)
    private let readStream: Foundation.InputStream
    private let responseCallbacks: ResponseCallbacks
    private let task: URLSessionUploadTask
    private let writeStream: Foundation.OutputStream

    enum Error: Swift.Error {
        case unableToFindBaseAddress
        case unableToWriteData
    }

    // Shared thread with a run loop for stream scheduling.
    // Required because .current may not have an active run loop in async contexts.
    // nonisolated(unsafe) is safe: thread is immutable after initialization.
    nonisolated(unsafe) private static let streamThread: Thread = {
        let semaphore = DispatchSemaphore(value: 0)
        let thread = Thread {
            // Add a port to keep the run loop alive (run() exits if no sources)
            RunLoop.current.add(NSMachPort(), forMode: .default)
            // Signal that the run loop is ready
            semaphore.signal()
            RunLoop.current.run()
        }
        thread.name = "com.connectrpc.URLSessionStream"
        thread.start()
        // Wait for the thread's run loop to be ready
        semaphore.wait()
        return thread
    }()

    var requestBodyStream: Foundation.InputStream {
        return self.readStream
    }

    var taskID: Int {
        return self.task.taskIdentifier
    }

    init(
        request: URLRequest,
        session: URLSession,
        responseCallbacks: ResponseCallbacks
    ) {
        var readStream: Foundation.InputStream!
        var writeStream: Foundation.OutputStream!
        Foundation.Stream.getBoundStreams(
            withBufferSize: 2 * (1_024 * 1_024),
            inputStream: &readStream,
            outputStream: &writeStream
        )

        self.responseCallbacks = responseCallbacks
        self.readStream = readStream
        self.writeStream = writeStream
        self.task = session.uploadTask(withStreamedRequest: request)
        super.init()

        // Schedule on dedicated thread with guaranteed run loop.
        // Using .current fails in async contexts where no run loop is active.
        self.perform(
            #selector(scheduleStream),
            on: Self.streamThread,
            with: nil,
            waitUntilDone: true
        )
        self.task.resume()
    }

    @objc private func scheduleStream() {
        self.writeStream.schedule(in: .current, forMode: .default)
        self.writeStream.open()
    }

    // MARK: - Outbound

    /// Wrapper to pass data and receive error back from stream thread.
    private final class WriteOperation: NSObject {
        let data: Data
        var error: Swift.Error?

        init(data: Data) {
            self.data = data
        }
    }

    func sendData(_ data: Data) throws {
        // All stream operations must happen on the thread where the stream is scheduled.
        // Foundation streams are not thread-safe!
        let operation = WriteOperation(data: data)
        self.perform(
            #selector(executeWriteOperation(_:)),
            on: Self.streamThread,
            with: operation,
            waitUntilDone: true,
            modes: [RunLoop.Mode.default.rawValue]
        )
        if let error = operation.error {
            throw error
        }
    }

    @objc private func executeWriteOperation(_ operation: WriteOperation) {
        var remaining = operation.data
        while !remaining.isEmpty {
            let bytesWritten: Int
            do {
                bytesWritten = try remaining.withUnsafeBytes { pointer -> Int in
                    guard let baseAddress = pointer.baseAddress else {
                        throw Error.unableToFindBaseAddress
                    }

                    return self.writeStream.write(
                        baseAddress.assumingMemoryBound(to: UInt8.self),
                        maxLength: remaining.count
                    )
                }
            } catch {
                operation.error = error
                return
            }

            if bytesWritten > 0 {
                remaining = remaining.dropFirst(bytesWritten)
            } else if bytesWritten == 0 {
                // Stream is full, this shouldn't happen as write() should block
                operation.error = Error.unableToWriteData
                return
            } else {
                operation.error = Error.unableToWriteData
                return
            }
        }
    }

    func cancel() {
        self.task.cancel()
    }

    func close() {
        // Stream operations must happen on the thread where the stream is scheduled.
        self.perform(
            #selector(closeStream),
            on: Self.streamThread,
            with: nil,
            waitUntilDone: false
        )
    }

    @objc private func closeStream() {
        self.writeStream.close()
    }

    // MARK: - Inbound

    func handleResponse(_ response: HTTPURLResponse) {
        let code = Code.fromURLSessionCode(response.statusCode)
        self.responseCallbacks.receiveResponseHeaders(response.formattedLowercasedHeaders())
        if code != .ok {
            self.closedByServer.value = true
            self.responseCallbacks.receiveClose(code, [:], nil)
        }
    }

    func handleResponseData(_ data: Data) {
        if !self.closedByServer.value {
            self.responseCallbacks.receiveResponseData(data)
        }
    }

    func handleCompletion(error: Swift.Error?) {
        if self.closedByServer.value {
            return
        }

        self.closedByServer.value = true
        if let error = error {
            let code = Code.fromURLSessionCode((error as NSError).code)
            self.responseCallbacks.receiveClose(
                code,
                [:],
                ConnectError(code: code, message: error.localizedDescription)
            )
        } else {
            self.responseCallbacks.receiveClose(.ok, [:], nil)
        }
    }
}
