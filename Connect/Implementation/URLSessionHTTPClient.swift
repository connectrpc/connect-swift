// Copyright 2022 Buf Technologies, Inc.
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

import CFNetwork
import Foundation
import os.log

/// Concrete implementation of `HTTPClientInterface` backed by `URLSession`.
open class URLSessionHTTPClient: NSObject {
    /// Lock used for safely accessing stream storage.
    private let lock = Lock()
    /// Force unwrapped to allow using `self` as the delegate.
    private var session: URLSession!
    /// List of active streams.
    /// TODO: Remove in favor of simply setting
    /// `URLSessionTask.delegate = <URLSessionStream instance>` once we are able to set iOS 15
    /// as the base deployment target.
    private var streams = [Int: URLSessionStream]()

    public init(configuration: URLSessionConfiguration = .default) {
        super.init()
        self.session = URLSession(
            configuration: configuration,
            delegate: self,
            delegateQueue: .main
        )
    }
}

extension URLSessionHTTPClient: HTTPClientInterface {
    @discardableResult
    public func unary(
        request: HTTPRequest, completion: @escaping (HTTPResponse) -> Void
    ) -> Cancelable {
        let urlRequest = URLRequest(httpRequest: request)
        let task = self.session.dataTask(with: urlRequest) { data, urlResponse, error in
            if let httpURLResponse = urlResponse as? HTTPURLResponse {
                completion(HTTPResponse(
                    code: Code.fromURLSessionCode(httpURLResponse.statusCode),
                    headers: httpURLResponse.formattedLowercasedHeaders(),
                    message: data,
                    trailers: [:], // URLSession does not support trailers
                    error: error
                ))
            } else if let error = error {
                let code = Code.fromURLSessionCode((error as NSError).code)
                completion(HTTPResponse(
                    code: code, headers: [:], message: data, trailers: [:], error: ConnectError(
                        code: code,
                        message: error.localizedDescription,
                        exception: error, details: [], metadata: [:]
                    )
                ))
            } else {
                completion(HTTPResponse(
                    code: .unknown, headers: [:], message: data, trailers: [:], error: ConnectError(
                        code: .unknown,
                        message: "unexpected response type \(type(of: urlResponse))",
                        exception: error, details: [], metadata: [:]
                    )
                ))
            }
        }
        task.resume()
        return Cancelable(cancel: task.cancel)
    }

    public func stream(
        request: HTTPRequest, responseCallbacks: ResponseCallbacks
    ) -> RequestCallbacks {
        let urlSessionStream = URLSessionStream(
            request: URLRequest(httpRequest: request),
            session: self.session,
            responseCallbacks: responseCallbacks
        )
        self.lock.perform { self.streams[urlSessionStream.taskID] = urlSessionStream }
        return RequestCallbacks(
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
            sendClose: urlSessionStream.close
        )
    }
}

extension URLSessionHTTPClient: URLSessionDataDelegate {
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
}

extension URLSessionHTTPClient: URLSessionTaskDelegate {
    open func urlSession(
        _ session: URLSession, task: URLSessionTask, didCompleteWithError error: Swift.Error?
    ) {
        let stream = self.lock.perform { self.streams.removeValue(forKey: task.taskIdentifier) }
        stream?.handleCompletion(error: error)
    }
}

extension HTTPURLResponse {
    func formattedLowercasedHeaders() -> Headers {
        return self.allHeaderFields.reduce(into: Headers()) { headers, current in
            guard let headerName = (current.key as? String)?.lowercased() else {
                return
            }

            let headerValue = current.value as? String ?? String(describing: current.value)
            headers[headerName] = headerValue.components(separatedBy: ",")
        }
    }
}

extension Code {
    static func fromURLSessionCode(_ code: Int) -> Self {
        // https://developer.apple.com/documentation/cfnetwork/cfnetworkerrors?language=swift
        switch Int32(code) {
        case CFNetworkErrors.cfurlErrorUnknown.rawValue:
            return .unknown
        case CFNetworkErrors.cfurlErrorCancelled.rawValue:
            return .canceled
        case CFNetworkErrors.cfurlErrorBadURL.rawValue:
            return .invalidArgument
        case CFNetworkErrors.cfurlErrorTimedOut.rawValue:
            return .deadlineExceeded
        case CFNetworkErrors.cfurlErrorUnsupportedURL.rawValue:
            return .unimplemented
        case ...100:
            // URLSession can return errors in this range
            return .unknown
        default:
            return Code.fromHTTPStatus(code)
        }
    }
}

private extension URLRequest {
    init(httpRequest: HTTPRequest) {
        self.init(url: httpRequest.target)
        self.httpMethod = "POST"
        self.httpBody = httpRequest.message
        self.setValue(httpRequest.contentType, forHTTPHeaderField: HeaderConstants.contentType)
        for (headerName, headerValues) in httpRequest.headers {
            self.setValue(headerValues.joined(separator: ","), forHTTPHeaderField: headerName)
        }
    }
}
