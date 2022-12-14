import Foundation

/// Stream implementation that wraps a `URLSession` stream.
final class URLSessionStream: NSObject {
    private var closedByServer = false
    private let responseCallbacks: ResponseCallbacks
    private let task: URLSessionUploadTask
    private let writeStream: Foundation.OutputStream

    enum Error: Swift.Error {
        case unableToFindBaseAddress
        case unableToWriteData
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
        self.writeStream = writeStream

        var request = request
        request.httpBodyStream = readStream

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

    func close() {
        self.writeStream.close()
    }

    // MARK: - Inbound

    func handleResponse(_ response: HTTPURLResponse) {
        let code = Code.fromURLSessionCode(response.statusCode)
        self.responseCallbacks.receiveResponseHeaders(response.formattedLowercasedHeaders())
        if code != .ok {
            self.closedByServer = true
            self.responseCallbacks.receiveClose(code, nil)
        }
    }

    func handleResponseData(_ data: Data) {
        if !self.closedByServer {
            self.responseCallbacks.receiveResponseData(data)
        }
    }

    func handleCompletion(error: Swift.Error?) {
        if self.closedByServer {
            return
        }

        self.closedByServer = true
        if let error = error {
            self.responseCallbacks.receiveClose(
                Code.fromURLSessionCode((error as NSError).code), error
            )
        } else {
            self.responseCallbacks.receiveClose(.ok, nil)
        }
    }
}
