import QuillCore

extension StreamCoordinator {
    func appendBufferedChunk(
        _ chunk: String,
        to streamController: MarkdownStreamController
    ) {
        bufferedStreamCommitScheduler.append(
            chunk,
            generation: streamGeneration,
            commitChunks: { [weak self] chunks in
                guard let self else { return }
                self.bufferedVisualFeeder.enqueue(
                    bufferedModules: chunks,
                    policy: self.renderConfiguration.tailReveal,
                    to: streamController
                )
            },
            onFlushDue: { [weak self] generation in
                self?.flushBufferedChunks(generation: generation, to: streamController)
            }
        )
    }

    func flushBufferedChunks(
        generation: Int,
        to streamController: MarkdownStreamController
    ) {
        guard streamGeneration == generation else { return }

        bufferedStreamCommitScheduler.flushIfNeeded(
            generation: generation,
            commitChunks: { [weak self] chunks in
                guard let self else { return }
                self.bufferedVisualFeeder.enqueue(
                    bufferedModules: chunks,
                    policy: self.renderConfiguration.tailReveal,
                    to: streamController
                )
            },
            onFlushDue: { [weak self] nextGeneration in
                self?.flushBufferedChunks(generation: nextGeneration, to: streamController)
            }
        )
    }

    func routeIncomingChunk(
        _ chunk: String,
        to streamController: MarkdownStreamController
    ) {
        if renderConfiguration.streamingMode == .bufferedModules {
            appendBufferedChunk(chunk, to: streamController)
            return
        }

        enqueueAppendChunk(chunk, to: streamController)
    }

    func enqueueAppendChunk(
        _ chunk: String,
        to streamController: MarkdownStreamController
    ) {
        bufferedVisualFeeder.enqueue(
            immediateChunk: chunk,
            policy: renderConfiguration.tailReveal,
            to: streamController
        )
    }
}
