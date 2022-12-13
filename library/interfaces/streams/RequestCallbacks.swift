import Foundation

public final class RequestCallbacks {
    public let sendData: (Data) -> Void
    public let sendClose: () -> Void

    public init(sendData: @escaping (Data) -> Void, sendClose: @escaping () -> Void) {
        self.sendData = sendData
        self.sendClose = sendClose
    }
}
