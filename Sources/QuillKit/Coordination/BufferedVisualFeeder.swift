import Foundation
import QuillCore

@MainActor
final class BufferedVisualFeeder {
    private var appendTask: Task<Void, Never>?

    init() {}

    deinit {
        appendTask?.cancel()
    }

    func cancel() {
        appendTask?.cancel()
        appendTask = nil
    }

    func enqueueBufferedModules(
        _ modules: [String],
        policy: TailRevealPolicy,
        to streamController: MarkdownStreamController
    ) {
        for module in modules where module.isEmpty == false {
            enqueueVisualChunks(
                Self.makeVisualFeedChunks(
                    from: module,
                    policy: policy
                ),
                policy: policy,
                to: streamController
            )
        }
    }

    func enqueueImmediateChunk(
        _ chunk: String,
        policy: TailRevealPolicy,
        to streamController: MarkdownStreamController
    ) {
        enqueueVisualChunks(
            Self.makeImmediateFeedChunks(
                from: chunk,
                policy: policy
            ),
            policy: policy,
            to: streamController
        )
    }

    func waitUntilDrained() async {
        let appendTask = appendTask
        await appendTask?.value
    }
}

extension BufferedVisualFeeder {
    nonisolated static func makeImmediateFeedChunks(
        from text: String,
        policy: TailRevealPolicy
    ) -> [String] {
        guard text.contains("\n") else { return [text] }
        return makeVisualFeedChunks(from: text, policy: policy)
    }

    nonisolated static func makeVisualFeedChunks(
        from text: String,
        policy: TailRevealPolicy
    ) -> [String] {
        let targetLength = max(2, policy.lowQueue.charsPerStep)
        let tokens = makeVisualFeedTokens(from: text)
        var chunks: [String] = []
        var current = ""

        for token in tokens {
            if token.contains("\n") {
                if current.isEmpty == false {
                    chunks.append(current)
                    current = ""
                }
                chunks.append(token)
                continue
            }

            if current.isEmpty == false, current.count + token.count > targetLength {
                chunks.append(current)
                current = token
                continue
            }

            current += token
        }

        if current.isEmpty == false {
            chunks.append(current)
        }

        return chunks.filter { $0.isEmpty == false }
    }
}

private extension BufferedVisualFeeder {
    enum Layout {
        static let minimumDelay: TimeInterval = 0.015
    }

    func enqueueVisualChunks(
        _ chunks: [String],
        policy: TailRevealPolicy,
        to streamController: MarkdownStreamController
    ) {
        for (index, chunk) in chunks.enumerated() {
            let delay = index == 0
                ? nil
                : Duration.seconds(
                    makeBufferedVisualFeedDelay(
                        after: chunk,
                        policy: policy
                    )
                )
            enqueueChunk(
                chunk,
                delay: delay,
                to: streamController
            )
        }
    }

    func enqueueChunk(
        _ chunk: String,
        delay: Duration?,
        to streamController: MarkdownStreamController
    ) {
        guard chunk.isEmpty == false else { return }

        let priorTask = appendTask
        appendTask = Task {
            await priorTask?.value
            guard !Task.isCancelled else { return }

            if let delay {
                try? await Task.sleep(for: delay)
                guard !Task.isCancelled else { return }
            }

            await streamController.append(chunk)
        }
    }

    func makeBufferedVisualFeedDelay(
        after chunk: String,
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

        return max(Layout.minimumDelay, delay)
    }

    nonisolated static func makeVisualFeedTokens(from text: String) -> [String] {
        enum TokenKind {
            case text
            case whitespace
        }

        var current = ""
        var currentKind: TokenKind?
        var tokens: [String] = []

        for character in text {
            let nextKind: TokenKind = character.isWhitespace ? .whitespace : .text

            if currentKind == nil || currentKind == nextKind {
                current.append(character)
            } else {
                tokens.append(current)
                current = String(character)
            }

            currentKind = nextKind

            if character == "\n" {
                tokens.append(current)
                current = ""
                currentKind = nil
            }
        }

        if current.isEmpty == false {
            tokens.append(current)
        }

        return tokens
    }
}
