import Foundation
import QuillCore

@MainActor
final class BufferedVisualFeeder {
    private var drainContinuations: [CheckedContinuation<Void, Never>] = []
    private var drainTask: Task<Void, Never>?
    private var nextPendingChunkIndex = 0
    private var pendingChunks: [QueuedChunk] = []
    private let sleep: (Duration) async -> Void

    init(sleep: @escaping (Duration) async -> Void = { duration in
        try? await Task.sleep(for: duration)
    }) {
        self.sleep = sleep
    }

    deinit {
        drainTask?.cancel()
        executeIsolated(resumeDrainContinuations)
    }

    func cancel() {
        drainTask?.cancel()
        drainTask = nil
        clearPendingChunks()
        resumeDrainContinuations()
    }

    func enqueue(
        bufferedModules: [String],
        policy: TailRevealPolicy,
        to streamController: MarkdownStreamController
    ) {
        for module in bufferedModules where module.isEmpty == false {
            enqueue(
                visualChunks: Self.makeVisualFeedChunks(
                    from: module,
                    policy: policy
                ),
                policy: policy,
                to: streamController
            )
        }
    }

    func enqueue(
        immediateChunk: String,
        policy: TailRevealPolicy,
        to streamController: MarkdownStreamController
    ) {
        enqueue(
            visualChunks: Self.makeImmediateFeedChunks(
                from: immediateChunk,
                policy: policy
            ),
            policy: policy,
            to: streamController
        )
    }

    func waitUntilDrained() async {
        let hasPendingWork = drainTask != nil || nextPendingChunkIndex < pendingChunks.count
        guard hasPendingWork else { return }

        await withCheckedContinuation { continuation in
            drainContinuations.append(continuation)
        }
    }
}

extension BufferedVisualFeeder {
    static func makeImmediateFeedChunks(
        from text: String,
        policy: TailRevealPolicy
    ) -> [String] {
        guard text.contains("\n") else { return [text] }
        return makeVisualFeedChunks(from: text, policy: policy)
    }

    static func makeVisualFeedChunks(
        from text: String,
        policy: TailRevealPolicy
    ) -> [String] {
        enum TokenKind {
            case text
            case whitespace
        }

        let targetLength = max(2, policy.lowQueue.charsPerStep)
        var chunks: [String] = []
        var current = ""
        var token = ""
        var tokenKind: TokenKind?

        for character in text {
            let nextTokenKind: TokenKind = character.isWhitespace ? .whitespace : .text

            if tokenKind == nil || tokenKind == nextTokenKind {
                token.append(character)
            } else {
                append(
                    token: token,
                    to: &chunks,
                    currentChunk: &current,
                    targetLength: targetLength
                )
                token = String(character)
            }

            tokenKind = nextTokenKind

            if character == "\n" {
                append(
                    token: token,
                    to: &chunks,
                    currentChunk: &current,
                    targetLength: targetLength
                )
                token = ""
                tokenKind = nil
            }
        }

        if token.isEmpty == false {
            append(
                token: token,
                to: &chunks,
                currentChunk: &current,
                targetLength: targetLength
            )
        }
        if current.isEmpty == false {
            chunks.append(current)
        }

        return chunks
    }
}

private extension BufferedVisualFeeder {
    struct QueuedChunk {
        let delay: Duration?
        let text: String
    }

    enum Timing {
        static let pendingChunkCompactionThreshold = 32
        static let minimumDelay: TimeInterval = 0.015
    }

    static func append(
        token: String,
        to chunks: inout [String],
        currentChunk: inout String,
        targetLength: Int
    ) {
        if token.contains("\n") {
            if currentChunk.isEmpty == false {
                chunks.append(currentChunk)
                currentChunk = ""
            }
            chunks.append(token)
            return
        }

        if currentChunk.isEmpty == false, currentChunk.count + token.count > targetLength {
            chunks.append(currentChunk)
            currentChunk = token
            return
        }

        currentChunk += token
    }

    func clearPendingChunks() {
        nextPendingChunkIndex = 0
        pendingChunks.removeAll(keepingCapacity: true)
    }

    func compactPendingChunksIfNeeded() {
        guard
            nextPendingChunkIndex > Timing.pendingChunkCompactionThreshold,
            nextPendingChunkIndex * 2 >= pendingChunks.count
        else {
            return
        }

        pendingChunks.removeFirst(nextPendingChunkIndex)
        nextPendingChunkIndex = 0
    }

    func dequeuePendingChunk() -> QueuedChunk? {
        guard nextPendingChunkIndex < pendingChunks.count else {
            clearPendingChunks()
            return nil
        }

        let chunk = pendingChunks[nextPendingChunkIndex]
        nextPendingChunkIndex += 1
        compactPendingChunksIfNeeded()
        return chunk
    }

    func drainPendingChunks(to streamController: MarkdownStreamController) async {
        while let pendingChunk = dequeuePendingChunk() {
            if let delay = pendingChunk.delay {
                await sleep(delay)
            }

            guard !Task.isCancelled else { break }
            await streamController.append(pendingChunk.text)
        }

        drainTask = nil
        resumeDrainContinuations()
    }

    func enqueue(
        visualChunks: [String],
        policy: TailRevealPolicy,
        to streamController: MarkdownStreamController
    ) {
        for (index, chunk) in visualChunks.enumerated() {
            let delay = index == 0
                ? nil
                : Duration.seconds(
                    makeBufferedVisualFeedDelay(
                        for: chunk,
                        policy: policy
                    )
                )

            pendingChunks.append(QueuedChunk(delay: delay, text: chunk))
        }

        startDrainingIfNeeded(to: streamController)
    }

    func makeBufferedVisualFeedDelay(
        for chunk: String,
        policy: TailRevealPolicy
    ) -> TimeInterval {
        let queueTiming = policy.lowQueue
        var delay = queueTiming.baseDuration + queueTiming.elementGapDuration

        if chunk.contains("\n") {
            delay += queueTiming.elementGapDuration
        }

        if let lastCharacter = chunk.last(where: { $0.isWhitespace == false }) {
            delay += policy.punctuationDelay(after: lastCharacter)
        }

        return max(Timing.minimumDelay, delay)
    }

    func resumeDrainContinuations() {
        let continuations = drainContinuations
        drainContinuations.removeAll(keepingCapacity: true)

        for continuation in continuations {
            continuation.resume()
        }
    }

    func startDrainingIfNeeded(to streamController: MarkdownStreamController) {
        guard drainTask == nil, nextPendingChunkIndex < pendingChunks.count else { return }

        drainTask = Task { [weak self] in
            guard let self else { return }
            await self.drainPendingChunks(to: streamController)
        }
    }
}
