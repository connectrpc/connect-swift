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
final class URLSessionStream: NSObject, StreamDelegate, @unchecked Sendable {
    private let closedByServer = Locked(false)
    private let readStream: Foundation.InputStream
    private let responseCallbacks: ResponseCallbacks
    private let task: URLSessionUploadTask
    private let writeStream: Foundation.OutputStream
    private var pendingWriteData = Data()

    enum Error: Swift.Error {
        case unableToFindBaseAddress
        case unableToWriteData
    }

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

        if Thread.isMainThread {
            writeStream.schedule(in: .main, forMode: .default)
            writeStream.open()
            writeStream.delegate = self
        } else {
            DispatchQueue.main.sync {
                writeStream.schedule(in: .main, forMode: .default)
                writeStream.open()
                writeStream.delegate = self
            }
        }
        self.task.resume()
    }

    // MARK: - Outbound

    func sendData(_ data: Data) throws {
        if Thread.isMainThread {
            self.pendingWriteData.append(data)
            self.drainWriteBuffer()
        } else {
            let copied = Data(data) // ensure the buffer outlives this call
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.pendingWriteData.append(copied)
                self.drainWriteBuffer()
            }
        }
    }

    func cancel() {
        self.task.cancel()
    }

    func close() {
        if Thread.isMainThread {
            self.writeStream.close()
        } else {
            DispatchQueue.main.async { [weak self] in self?.writeStream.close() }
        }
    }

    private func drainWriteBuffer() {
        guard !self.pendingWriteData.isEmpty else { return }
        while self.writeStream.hasSpaceAvailable && !self.pendingWriteData.isEmpty {
            let written: Int = self.pendingWriteData.withUnsafeBytes { ptr in
                guard let base = ptr.baseAddress else { return -1 }
                return self.writeStream.write(base.assumingMemoryBound(to: UInt8.self), maxLength: self.pendingWriteData.count)
            }
            if written > 0 {
                self.pendingWriteData.removeFirst(written)
            } else if written == 0 {
                // Not currently writable; wait for the next .hasSpaceAvailable event.
                break
            } else {
                // Error writing to stream; close and let URLSession surface the failure.
                self.writeStream.close()
                break
            }
        }
    }

    func stream(_ aStream: Stream, handle eventCode: Stream.Event) {
        guard aStream === self.writeStream else { return }
        switch eventCode {
        case .hasSpaceAvailable:
            self.drainWriteBuffer()
        default:
            break
        }
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

