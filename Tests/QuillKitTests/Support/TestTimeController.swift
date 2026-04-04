import Foundation

@MainActor
final class TestTimeController {
    private(set) var currentTime: TimeInterval
    private(set) var recordedSleeps: [Duration] = []

    init(now: TimeInterval = 0) {
        currentTime = now
    }

    func now() -> TimeInterval {
        currentTime
    }

    func sleep(for duration: Duration) async {
        recordedSleeps.append(duration)
        currentTime += duration.timeInterval
        await Task.yield()
    }
}

private extension Duration {
    var timeInterval: TimeInterval {
        let components = self.components
        let seconds = Double(components.seconds)
        let attoseconds = Double(components.attoseconds) / 1_000_000_000_000_000_000
        return seconds + attoseconds
    }
}
