/// Type that wraps an action that can be canceled.
public struct Cancelable {
    /// Cancel the current action.
    public let cancel: () -> Void
}
