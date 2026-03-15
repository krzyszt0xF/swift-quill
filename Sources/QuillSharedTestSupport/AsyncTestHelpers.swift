import Foundation

@MainActor
package func eventually(
    timeout: Duration = .milliseconds(800),
    poll: Duration = .milliseconds(10),
    _ condition: @escaping () -> Bool
) async -> Bool {
    let clock = ContinuousClock()
    let deadline = clock.now.advanced(by: timeout)

    while clock.now < deadline {
        if condition() {
            return true
        }

        try? await Task.sleep(for: poll)
    }

    return condition()
}

@MainActor
package func wait(for duration: Duration) async {
    try? await Task.sleep(for: duration)
}
