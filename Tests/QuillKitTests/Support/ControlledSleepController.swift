import Foundation

@MainActor
final class ControlledSleepController {
    private(set) var completedSleepCount = 0
    private(set) var requestedDurations: [Duration] = []
    private var continuations: [CheckedContinuation<Void, Never>] = []

    var requestCount: Int { requestedDurations.count }

    func resumeNext() {
        guard continuations.isEmpty == false else { return }

        continuations.removeFirst().resume()
    }

    func sleep(for duration: Duration) async {
        requestedDurations.append(duration)

        await withCheckedContinuation { continuation in
            continuations.append(continuation)
        }

        completedSleepCount += 1
    }
}
