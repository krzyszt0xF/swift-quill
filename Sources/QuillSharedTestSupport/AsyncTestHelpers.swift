import Foundation

@MainActor
package func eventually<C: Clock>(
    timeout: Duration = .seconds(3),
    poll: Duration = .milliseconds(10),
    clock: C,
    _ condition: @escaping () -> Bool
) async -> Bool where C.Duration == Duration {
    let deadline = clock.now.advanced(by: timeout)

    while clock.now < deadline {
        if condition() {
            return true
        }

        try? await clock.sleep(
            until: clock.now.advanced(by: poll),
            tolerance: nil
        )
    }

    return condition()
}

@MainActor
package func eventually(
    timeout: Duration = .seconds(3),
    poll: Duration = .milliseconds(10),
    _ condition: @escaping () -> Bool
) async -> Bool {
    await eventually(
        timeout: timeout,
        poll: poll,
        clock: SuspendingClock(),
        condition
    )
}

@MainActor
package func eventually<C: Clock>(
    timeout: Duration = .seconds(3),
    poll: Duration = .milliseconds(10),
    clock: C,
    _ condition: @escaping () async -> Bool
) async -> Bool where C.Duration == Duration {
    let deadline = clock.now.advanced(by: timeout)

    while clock.now < deadline {
        if await condition() {
            return true
        }

        try? await clock.sleep(
            until: clock.now.advanced(by: poll),
            tolerance: nil
        )
    }

    return await condition()
}

@MainActor
package func eventually(
    timeout: Duration = .seconds(3),
    poll: Duration = .milliseconds(10),
    _ condition: @escaping () async -> Bool
) async -> Bool {
    await eventually(
        timeout: timeout,
        poll: poll,
        clock: SuspendingClock(),
        condition
    )
}

@MainActor
package func wait<C: Clock>(
    for duration: Duration,
    clock: C
) async where C.Duration == Duration {
    try? await clock.sleep(
        until: clock.now.advanced(by: duration),
        tolerance: nil
    )
}

@MainActor
package func wait(for duration: Duration) async {
    await wait(for: duration, clock: SuspendingClock())
}
