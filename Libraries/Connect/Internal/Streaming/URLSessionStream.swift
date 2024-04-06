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

        writeStream.schedule(in: .current, forMode: .default)
        writeStream.open()
        self.task.resume()
    }

    // MARK: - Outbound

    func sendData(_ data: Data) throws {
        var remaining = Data(data)
        while !remaining.isEmpty {
            let bytesWritten = try remaining.withUnsafeBytes { pointer -> Int in
                guard let baseAddress = pointer.baseAddress else {
                    throw Error.unableToFindBaseAddress
                }

                return self.writeStream.write(
                    baseAddress.assumingMemoryBound(to: UInt8.self),
                    maxLength: remaining.count
                )
            }

            if bytesWritten >= 0 {
                remaining = remaining.dropFirst(bytesWritten)
            } else {
                throw Error.unableToWriteData
            }
        }
    }

    func cancel() {
        self.task.cancel()
    }

    func close() {
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
                ConnectError(
                    code: code,
                    message: error.localizedDescription,
                    exception: nil,
                    details: [],
                    metadata: [:]
                )
            )
        } else {
            self.responseCallbacks.receiveClose(.ok, [:], nil)
        }
    }
}
