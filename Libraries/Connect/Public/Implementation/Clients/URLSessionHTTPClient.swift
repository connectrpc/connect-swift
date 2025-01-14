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
import os.log

/// Concrete implementation of `HTTPClientInterface` backed by `URLSession`.
///
/// This class is thread-safe as-is through the use of an internal lock. It is marked as
/// `open` and `@unchecked Sendable` so that consumers can subclass it if necessary, but
/// subclasses must handle their own thread safety for added functionality.
open class URLSessionHTTPClient: NSObject, HTTPClientInterface, @unchecked Sendable {
    /// Lock used for safely accessing stream storage.
    private let lock = Lock()
    /// Closures stored for notifying when metrics are available.
    private var metricsClosures = [Int: @Sendable (HTTPMetrics) -> Void]()
    /// Session used for performing requests.
    private let session: URLSession
    /// List of active streams.
    /// TODO: Remove in favor of simply setting
    /// `URLSessionTask.delegate = <URLSessionStream instance>` once we are able to set iOS 15
    /// as the base deployment target.
    private var streams = [Int: URLSessionStream]()

    public init(configuration: URLSessionConfiguration = .default) {
        let delegate = URLSessionDelegateWrapper()
        self.session = URLSession(
            configuration: configuration,
            delegate: delegate,
            delegateQueue: .main
        )
        super.init()
        delegate.client = self
    }

    deinit {
        self.session.finishTasksAndInvalidate()
    }

    @discardableResult
    open func unary(
        request: HTTPRequest<Data?>,
        onMetrics: @escaping @Sendable (HTTPMetrics) -> Void,
        onResponse: @escaping @Sendable (HTTPResponse) -> Void
    ) -> Cancelable {
        assert(!request.isGRPC, "URLSessionHTTPClient does not support gRPC, use NIOHTTPClient")
        let urlRequest = URLRequest(httpRequest: request)
        let task = self.session.dataTask(with: urlRequest) { data, urlResponse, error in
            if let httpURLResponse = urlResponse as? HTTPURLResponse {
                onResponse(HTTPResponse(
                    code: Code.fromURLSessionCode(httpURLResponse.statusCode),
                    headers: httpURLResponse.formattedLowercasedHeaders(),
                    message: data,
                    trailers: [:], // URLSession does not support trailers
                    error: error,
                    tracingInfo: .init(httpStatus: httpURLResponse.statusCode)
                ))
            } else if let error = error {
                let code = Code.fromURLSessionCode((error as NSError).code)
                onResponse(HTTPResponse(
                    code: code,
                    headers: [:],
                    message: data,
                    trailers: [:],
                    error: ConnectError(
                        code: code,
                        message: error.localizedDescription,
                        exception: error
                    ),
                    tracingInfo: nil
                ))
            } else {
                onResponse(HTTPResponse(
                    code: .unknown,
                    headers: [:],
                    message: data,
                    trailers: [:],
                    error: ConnectError(
                        code: .unknown,
                        message: "unexpected response type \(type(of: urlResponse))",
                        exception: error
                    ),
                    tracingInfo: nil
                ))
            }
        }
        self.lock.perform { self.metricsClosures[task.taskIdentifier] = onMetrics }
        task.resume()
        return Cancelable { task.cancel() }
    }

    open func stream(
        request: HTTPRequest<Data?>, responseCallbacks: ResponseCallbacks
    ) -> RequestCallbacks<Data> {
        assert(!request.isGRPC, "URLSessionHTTPClient does not support gRPC, use NIOHTTPClient")
        let urlSessionStream = URLSessionStream(
            request: URLRequest(httpRequest: request),
            session: self.session,
            responseCallbacks: responseCallbacks
        )
        self.lock.perform {
            self.streams[urlSessionStream.taskID] = urlSessionStream
            self.metricsClosures[urlSessionStream.taskID] = responseCallbacks.receiveResponseMetrics
        }
        return RequestCallbacks(
            cancel: { urlSessionStream.cancel() },
            sendData: { data in
                do {
                    try urlSessionStream.sendData(data)
                } catch let error {
                    os_log(
                        .error,
                        "Failed to write data to stream - closing connection: %@",
                        error.localizedDescription
                    )
                    urlSessionStream.close()
                }
            },
            sendClose: { urlSessionStream.close() }
        )
    }

    // MARK: - URLSession delegate functions

    open func urlSession(
        _ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse,
        completionHandler: @escaping (URLSession.ResponseDisposition) -> Void
    ) {
        defer { completionHandler(.allow) }

        guard let httpURLResponse = response as? HTTPURLResponse else {
            return
        }

        let stream = self.lock.perform { self.streams[dataTask.taskIdentifier] }
        stream?.handleResponse(httpURLResponse)
    }

    open func urlSession(
        _ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data
    ) {
        let stream = self.lock.perform { self.streams[dataTask.taskIdentifier] }
        stream?.handleResponseData(data)
    }

    open func urlSession(
        _ session: URLSession, task: URLSessionTask,
        needNewBodyStream completionHandler: @escaping (InputStream?) -> Void
    ) {
        completionHandler(
            self.lock.perform { self.streams[task.taskIdentifier]?.requestBodyStream }
        )
    }

    open func urlSession(
        _ session: URLSession, task: URLSessionTask, didCompleteWithError error: Swift.Error?
    ) {
        let stream = self.lock.perform { self.streams.removeValue(forKey: task.taskIdentifier) }
        stream?.handleCompletion(error: error)
    }

    open func urlSession(
        _ session: URLSession, task: URLSessionTask,
        didFinishCollecting metrics: URLSessionTaskMetrics
    ) {
        if let metricsClosure = self.lock.perform(
            action: { self.metricsClosures.removeValue(forKey: task.taskIdentifier) }
        ) {
            metricsClosure(HTTPMetrics(taskMetrics: metrics))
        }
    }
}

// MARK: - URLSession delegate wrapper

/// This class exists to avoid a retain cycle between `URLSessionHTTPClient` and its underlying
/// `URLSession.delegate`. Since `URLSession` retains its `delegate` strongly, setting the
/// `URLSessionHTTPClient` directly as the `delegate` will cause a retain cycle:
/// https://developer.apple.com/documentation/foundation/urlsession/1411597-init#parameters
///
/// To work around this, `URLSessionDelegateWrapper` maintains a `weak` reference to the
/// `URLSessionHTTPClient` and passes delegate calls through to it, avoiding the retain cycle.
private final class URLSessionDelegateWrapper: NSObject, @unchecked Sendable {
    weak var client: URLSessionHTTPClient?
}

extension URLSessionDelegateWrapper: URLSessionDataDelegate {
    func urlSession(
        _ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse,
        completionHandler: @escaping (URLSession.ResponseDisposition) -> Void
    ) {
        self.client?.urlSession(
            session, dataTask: dataTask, didReceive: response, completionHandler: completionHandler
        )
    }

    func urlSession(
        _ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data
    ) {
        self.client?.urlSession(session, dataTask: dataTask, didReceive: data)
    }

    func urlSession(
        _ session: URLSession, task: URLSessionTask,
        needNewBodyStream completionHandler: @escaping (InputStream?) -> Void
    ) {
        self.client?.urlSession(session, task: task, needNewBodyStream: completionHandler)
    }
}

extension URLSessionDelegateWrapper: URLSessionTaskDelegate {
    func urlSession(
        _ session: URLSession, task: URLSessionTask, didCompleteWithError error: Swift.Error?
    ) {
        self.client?.urlSession(session, task: task, didCompleteWithError: error)
    }

    func urlSession(
        _ session: URLSession, task: URLSessionTask,
        didFinishCollecting metrics: URLSessionTaskMetrics
    ) {
        self.client?.urlSession(session, task: task, didFinishCollecting: metrics)
    }
}

// MARK: - Extensions

extension HTTPURLResponse {
    func formattedLowercasedHeaders() -> Headers {
        return self.allHeaderFields.reduce(into: Headers()) { headers, current in
            guard let headerName = (current.key as? String)?.lowercased() else {
                return
            }

            let headerValues = current.value as? String ?? String(describing: current.value)
            for value in headerValues.components(separatedBy: ",") {
                headers[headerName, default: []].append(value.trimmingCharacters(in: .whitespaces))
            }
        }
    }
}

extension Code {
    static func fromURLSessionCode(_ code: Int) -> Self {
        // https://developer.apple.com/documentation/cfnetwork/cfnetworkerrors?language=swift
        switch code {
        case URLError.unknown.rawValue:
            return .unknown
        case URLError.cancelled.rawValue:
            return .canceled
        case URLError.badURL.rawValue:
            return .invalidArgument
        case URLError.timedOut.rawValue, NSURLErrorTimedOut:
            return .deadlineExceeded
        case URLError.unsupportedURL.rawValue:
            return .unimplemented
        case NSURLErrorCannotConnectToHost,
            NSURLErrorCannotFindHost,
            NSURLErrorDataNotAllowed,
            NSURLErrorInternationalRoamingOff,
            NSURLErrorNetworkConnectionLost,
            NSURLErrorNotConnectedToInternet,
            NSURLErrorSecureConnectionFailed:
            return .unavailable
        case ...100: // URLSession can return errors in this range
            return .unknown
        default:
            return Code.fromHTTPStatus(code)
        }
    }
}

private extension HTTPRequest {
    var isGRPC: Bool {
        return self.headers[HeaderConstants.contentType]?.first.map { contentType in
            return contentType.hasPrefix("application/grpc")
                && !contentType.hasPrefix("application/grpc-web")
        } ?? false
    }
}

private extension URLRequest {
    init(httpRequest: HTTPRequest<Data?>) {
        self.init(url: httpRequest.url)
        self.httpMethod = httpRequest.method.rawValue
        self.httpBody = httpRequest.message
        for (headerName, headerValues) in httpRequest.headers {
            self.setValue(headerValues.joined(separator: ","), forHTTPHeaderField: headerName)
        }
    }
}
