import Foundation

/// Internal implementation of a lock. Wraps usage of `os_unfair_lock`.
final class Lock {
    private let underlyingLock: UnsafeMutablePointer<os_unfair_lock>

    init() {
        // Reasoning for allocating here: http://www.russbishop.net/the-law
        self.underlyingLock = .allocate(capacity: 1)
        self.underlyingLock.initialize(to: os_unfair_lock())
    }

    func perform<T>(action: @escaping () -> T) -> T {
        os_unfair_lock_lock(self.underlyingLock)
        defer { os_unfair_lock_unlock(self.underlyingLock) }
        return action()
    }
}
