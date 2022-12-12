import Connect
import Foundation

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
        print("**Challenged")
        if challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
            let serverTrust = challenge.protectionSpace.serverTrust
        {
            completionHandler(.useCredential, URLCredential(trust: serverTrust))
        } else {
            print("**failed")
            completionHandler(.performDefaultHandling, nil)
        }
//        completionHandler(.performDefaultHandling, nil)
//                var secresult = SecTrustResultType.invalid
//                let status = SecTrustEvaluate(serverTrust, &secresult)
//                if(errSecSuccess == status) {
//                    if let serverCertificate = SecTrustGetCertificateAtIndex(serverTrust, 0) {
//                        let serverCertificateData = SecCertificateCopyData(serverCertificate)
//                        let data = CFDataGetBytePtr(serverCertificateData);
//                        let size = CFDataGetLength(serverCertificateData);
//                        let certificateOne = NSData(bytes: data, length: size)
//                        let filePath = Bundle.main.path(forResource: self.certFileName,
//                                                        ofType: self.certFileType)
//                        if let file = filePath {
//                            if let certificateTwo = NSData(contentsOfFile: file) {
//                                completionHandler(URLSession.AuthChallengeDisposition.useCredential,
//                                                  URLCredential(trust:serverTrust))
//                                return
//                            }
//                        }
//                    }
//                }
//            }
//        }
//        let certificate = self.pinnedCert()
//        var identity: SecIdentity?
//        let status = secidentity SecIdentityCreateWithCertificate(nil, certificate, &identity)
//        let credential = URLCredential(
//            identity: <#T##SecIdentity#>,
//            certificates: <#T##[Any]?#>,
//            persistence: .forSession
//        )
//        completionHandler(.useCredential, credential)
//        let trust = challenge.protectionSpace.serverTrust!
//        if trust.evaluateAllowing(rootCertificates: [customRoot]) {
//            completionHandler(.useCredential, URLCredential(trust: trust))
//        } else {
//            completionHandler(.cancelAuthenticationChallenge, nil)
//        }
    }

//    private func pinnedCert() -> SecCertificate {
//        let crosstestCACert = """
//        -----BEGIN CERTIFICATE-----
//        MIIE7DCCAtSgAwIBAgIBATANBgkqhkiG9w0BAQsFADAWMRQwEgYDVQQDEwtDcm9z
//        c3Rlc3RDQTAeFw0yMjA1MDMxNzA5NTlaFw0yMzExMDMxNzE5NTZaMBYxFDASBgNV
//        BAMTC0Nyb3NzdGVzdENBMIICIjANBgkqhkiG9w0BAQEFAAOCAg8AMIICCgKCAgEA
//        qEUpIjCMAu5K7GuFrAu4cUtKMZaX78L9DbCtq7tkwPX9JLgNUxrfgN1qdIFsxRfw
//        /XaRjK+A3Gbech4z1U5ujeImAqg6IzpdFvQg9NVlIXpaEhsTk/oU8YXJAouXzBCZ
//        LBteiK3L5410/O95dVNUKpPlX0qHPkxr+ZUeV+8+MRVge7xDwceBpnAUj1gSMmcE
//        93i6CnVr75cF2aScB37rquuCpYcjibAQq0V9qvlG7DtEPg1gMt2Hluc5Vjf/sWI3
//        HTxoBaWxQ4iqdwNRrNO+yjZ97IHe92bnEXzkynhWyd0hCcdwDaU4Gb33xcFjMlWr
//        cYtVmhHIIN3L/v/P69uhskEGqGRICcOHI+Y0jRz5eVwln87waMosM4ecSCnygmTf
//        RNRL3eRzZYZj5/eqJYPpErswdtoOiix5cStNpXU8GqmxMqAtrStgl86gLtJXtZgn
//        LETquRfHSQvNFbuDO6bm56eWf/PqXeCJYZkb3wuBVK8uU8BUSH1wCnhDdpaJIpR+
//        zY93XrRiVXFka0ZNvaAHZsHnHtuxKaP+fOSIhrCWqa2hhpUEw4ykKFZfznqOk+UU
//        jwgnRRZN6rZaRQQGuoR94WNoP2cy3JJOpnEzRsTfwG+FL+gJSEN4tg2DbO7th/Ae
//        fHvAJ0VfCllabvQbLGjJFkI4ddMSj5lhJyIBfu6YWlsCAwEAAaNFMEMwDgYDVR0P
//        AQH/BAQDAgEGMBIGA1UdEwEB/wQIMAYBAf8CAQAwHQYDVR0OBBYEFKYOjJ8Yz1ZX
//        NkBIw1nAAtKsYq+SMA0GCSqGSIb3DQEBCwUAA4ICAQByUDpOqgviWV/d3U9+84Sv
//        tkaL3Z4niKJxmGWwdzMhZFBlgEEsy5vBZ08uYkuel5Gg8Fl6pKVi2hPMU8NSZIMB
//        7OvomHfV6ag1CInbRozs7+ef/MKIC4ic7Tqmzf0zRpFjogkhUghMzYLmjjsPXwOb
//        JwJGmdyytHZ30qATIsoaR17/FRedl/FVlLoV48eMDIiu9ZuBqRLXqvJ4Xar0i/Td
//        TQdvFU5v4x785th5I9gWcKHZR1Frx4j4bfWWNi8m6cPp4i1R8prq5z+8lnIq/yJR
//        /QERkHQRZ1X6FK9aOnbMBFu+gLXcKSql7goGTIXVzqFeKmrZgqblu3axRQ8brs7p
//        1Va6Ha8yQyawV0FQKCcVEmXxpjSONWc9qyBDBx32/praLOET3UHmYcJilVAgZufR
//        9pAuCRf+7nDx9t2vynmT0C8MeFNjDRcN8QYr9lO9CUbcV+nOqiEG128XMhjsLj7m
//        lEP/lCyEGGVB+/LuxbRxOGzoZDb0WVan41zSNaFfnvXGMuTxLOhY6upiljL8k6Jm
//        eqI0hZhMnLbJFVnKgqaMpV+h2UvmEPXNx9oSKSG+11awVPdJjf4MLVOVVTPeLEv6
//        AsJXGUNptIhuKblQ0afNGOF37CCbDhdajKnMFVbXZWxFsDEs0J4EW0donSiJEGFF
//        iQ8d6tGEgzeekht617JMvQ==
//        -----END CERTIFICATE-----
//        """
//        let certData = crosstestCACert.data(using: .utf8)! as CFData
//        return SecCertificateCreateWithData(nil, certData)!
//    }
}
