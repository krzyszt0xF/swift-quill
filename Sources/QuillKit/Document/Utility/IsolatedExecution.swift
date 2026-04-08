import Foundation

// Executes a `@MainActor`-isolated closure synchronously, regardless of the calling thread.
/// - If already on the main thread, runs immediately via `MainActor.assumeIsolated`.
/// - Otherwise, dispatches synchronously to the main queue.
@discardableResult
func executeIsolated<T: Sendable>(_ work: @MainActor () -> T) -> T {
    if Thread.isMainThread {
        return MainActor.assumeIsolated(work)
    } else {
        return DispatchQueue.main.asyncAndWait {
            MainActor.assumeIsolated(work)
        }
    }
}
