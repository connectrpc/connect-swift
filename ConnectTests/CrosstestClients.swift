import Connect
import Foundation

final class CrosstestClients {
    let connectJSONClient: ProtocolClient
    let connectProtoClient: ProtocolClient
    let grpcWebJSONClient: ProtocolClient
    let grpcWebProtoClient: ProtocolClient

    init(timeout: TimeInterval, responseDelay: TimeInterval?) {
        let httpClient = CrosstestHTTPClient(
            timeout: timeout, delayAfterChallenge: responseDelay
        )
        let target = "https://localhost:8081"

        self.connectJSONClient = ProtocolClient(
            target: target,
            httpClient: httpClient,
            ConnectClientOption(),
            JSONClientOption(),
            GzipRequestOption(compressionMinBytes: 10),
            GzipCompressionOption()
        )
        self.connectProtoClient = ProtocolClient(
            target: target,
            httpClient: httpClient,
            ConnectClientOption(),
            ProtoClientOption(),
            GzipRequestOption(compressionMinBytes: 10),
            GzipCompressionOption()
        )
        self.grpcWebJSONClient = ProtocolClient(
            target: target,
            httpClient: httpClient,
            GRPCWebClientOption(),
            JSONClientOption(),
            GzipRequestOption(compressionMinBytes: 10),
            GzipCompressionOption()
        )
        self.grpcWebProtoClient = ProtocolClient(
            target: target,
            httpClient: httpClient,
            GRPCWebClientOption(),
            ProtoClientOption(),
            GzipRequestOption(compressionMinBytes: 10),
            GzipCompressionOption()
        )
    }
}
