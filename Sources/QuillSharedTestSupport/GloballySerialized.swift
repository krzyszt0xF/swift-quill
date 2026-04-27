import Testing

/// Test trait that serializes execution across every suite that opts in.
///
/// `.serialized` only orders tests within a single suite. Tests in different suites can still
/// interleave on the main actor at every `await`, which lets concurrent UI hosting tests
/// stomp on each other's UIWindow / runloop / layout state. This trait wraps each test in a
/// shared global lock so opted-in suites run strictly one at a time, regardless of suite.
public struct GloballySerialized: TestTrait, SuiteTrait, TestScoping {
    public init() {}

    public func scopeProvider(for test: Test, testCase: Test.Case?) -> Self? {
        self
    }

    public func provideScope(
        for test: Test,
        testCase: Test.Case?,
        performing function: @Sendable () async throws -> Void
    ) async throws {
        await GlobalTestSerialQueue.shared.acquire()
        defer {
            Task { await GlobalTestSerialQueue.shared.release() }
        }
        try await function()
    }
}

actor GlobalTestSerialQueue {
    static let shared = GlobalTestSerialQueue()

    private var busy = false
    private var waiters: [CheckedContinuation<Void, Never>] = []

    func acquire() async {
        if !busy {
            busy = true
            return
        }
        await withCheckedContinuation { waiters.append($0) }
    }

    func release() {
        if waiters.isEmpty {
            busy = false
        } else {
            let next = waiters.removeFirst()
            next.resume()
        }
    }
}
