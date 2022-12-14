import Connect
import Foundation

/// HTTP client used by crosstests in order to handle SSL challenges with the crosstest server.
final class CrosstestHTTPClient: NSObject {
    private var client: URLSessionHTTPClient!

    init(timeout: TimeInterval) {
        super.init()

        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = timeout
        configuration.timeoutIntervalForResource = timeout
        let session = URLSession(
            configuration: configuration, delegate: self, delegateQueue: .main
        )
        self.client = URLSessionHTTPClient(session: session)
    }
}

extension CrosstestHTTPClient: HTTPClientInterface {
    func unary(request: HTTPRequest, completion: @escaping (HTTPResponse) -> Void) {
        self.client.unary(request: request, completion: completion)
    }

    func stream(request: HTTPRequest, responseCallbacks: ResponseCallbacks) -> RequestCallbacks {
        return self.client.stream(request: request, responseCallbacks: responseCallbacks)
    }
}

extension CrosstestHTTPClient: URLSessionDelegate {
    public func urlSession(
        _ session: URLSession, didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        // This codepath is executed when using HTTPS with the crosstest server.
        if challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
           let serverTrust = challenge.protectionSpace.serverTrust
        {
            completionHandler(.useCredential, URLCredential(trust: serverTrust))
        } else {
            completionHandler(.performDefaultHandling, nil)
        }
    }
}
