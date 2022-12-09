import CFNetwork
import Foundation
import os.log

/// Concrete implementation of `HTTPClientInterface` backed by `URLSession`.
open class URLSessionHTTPClient: NSObject {
    private let session: URLSession

    public required init(session: URLSession = .shared) {
        self.session = session
        super.init()
    }
}

extension URLSessionHTTPClient: URLSessionDelegate, URLSessionTaskDelegate {
    public func urlSession(
        _ session: URLSession, didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        print("**Challenged")
        if (challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust) {
            if let serverTrust = challenge.protectionSpace.serverTrust {
                completionHandler(.useCredential, URLCredential(trust: serverTrust))
            }
        }
    }
}

extension URLSessionHTTPClient: HTTPClientInterface {
    public func unary(request: HTTPRequest, completion: @escaping (HTTPResponse) -> Void) {
        let urlRequest = URLRequest(httpRequest: request)
        let task = self.session.dataTask(with: urlRequest) { data, urlResponse, error in
            guard let httpURLResponse = urlResponse as? HTTPURLResponse else {
                return completion(HTTPResponse(
                    code: .unknown, headers: [:], message: data, trailers: [:], error: ConnectError(
                        code: .unknown,
                        message: "unexpected response type \(type(of: urlResponse))",
                        exception: error, details: [], metadata: [:]
                    )
                ))
            }

            completion(HTTPResponse(
                code: Code.fromURLSessionCode(httpURLResponse.statusCode),
                headers: httpURLResponse.formattedLowercasedHeaders(),
                message: data,
                trailers: [:], // URLSession does not support trailers
                error: error
            ))
        }
        task.delegate = self
        task.resume()
    }

    public func stream(
        request: HTTPRequest, responseCallbacks: ResponseCallbacks
    ) -> RequestCallbacks {
        let urlSessionStream = URLSessionStream(
            request: URLRequest(httpRequest: request),
            session: self.session,
            responseCallbacks: responseCallbacks
        )
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
