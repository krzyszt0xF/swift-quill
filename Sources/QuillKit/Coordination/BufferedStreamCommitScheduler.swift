import Foundation
import QuillCore

@MainActor
final class BufferedStreamCommitScheduler {
    private var flushTask: Task<Void, Never>?
    private var moduleStreamGate: ModuleStreamGate
    private let now: () -> TimeInterval
    private let sleep: (Duration) async -> Void

    init(
        moduleStreamGate: ModuleStreamGate,
        now: @escaping () -> TimeInterval,
        sleep: @escaping (Duration) async -> Void
    ) {
        self.moduleStreamGate = moduleStreamGate
        self.now = now
        self.sleep = sleep
    }

    func append(
        _ chunk: String,
        generation: Int,
        commitChunks: ([String]) -> Void,
        onFlushDue: @escaping @MainActor @Sendable (Int) -> Void
    ) {
        let currentTime = now()
        let result = moduleStreamGate.append(chunk, now: currentTime)
        commitChunks(result.committedChunks)

        if result.hasPendingText {
            scheduleFlushIfNeeded(generation: generation, now: currentTime, onFlushDue: onFlushDue)
        } else {
            cancel()
        }
    }

    func applyConfiguration(_ configuration: RenderConfiguration) {
        moduleStreamGate.updateConfiguration(
            ModuleStreamGateConfiguration(
                minModuleLength: configuration.bufferedStream.minModuleLength,
                maxBufferingDelay: configuration.bufferedStream.maxBufferingDelay
            )
        )

        guard configuration.streamingMode == .bufferedModules else {
            reset()
            return
        }
    }

    func cancel() {
        flushTask?.cancel()
        flushTask = nil
    }

    func flushIfNeeded(
        generation: Int,
        commitChunks: ([String]) -> Void,
        onFlushDue: @escaping @MainActor @Sendable (Int) -> Void
    ) {
        let currentTime = now()
        let chunks = moduleStreamGate.commitIfOverdue(now: currentTime)
        commitChunks(chunks)

        if moduleStreamGate.hasPendingText {
            scheduleFlushIfNeeded(generation: generation, now: currentTime, onFlushDue: onFlushDue)
        } else {
            cancel()
        }
    }

    func flushRemaining() -> String {
        cancel()
        return moduleStreamGate.flushRemaining()
    }

    func reset() {
        cancel()
        moduleStreamGate.reset()
    }
}

extension BufferedStreamCommitScheduler {
    static var live: BufferedStreamCommitScheduler {
        BufferedStreamCommitScheduler(
            moduleStreamGate: .init(),
            now: { Date.timeIntervalSinceReferenceDate },
            sleep: { duration in
                try? await Task.sleep(for: duration)
            }
        )
    }
}

private extension BufferedStreamCommitScheduler {
    func scheduleFlushIfNeeded(
        generation: Int,
        now: TimeInterval,
        onFlushDue: @escaping @MainActor @Sendable (Int) -> Void
    ) {
        cancel()
        let delay = moduleStreamGate.timeUntilForcedCommit(now: now) ?? 0.12
        let effectiveDelay = max(0.05, delay)

        flushTask = Task { [sleep] in
            await sleep(.seconds(effectiveDelay))
            guard !Task.isCancelled else { return }
            onFlushDue(generation)
        }
    }
}
