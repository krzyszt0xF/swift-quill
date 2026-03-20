package actor MarkdownStreamController {
    private var buffer = StreamBuffer()
    private var continuation: AsyncStream<ParserEvent>.Continuation?
    private var isFinished = false
    private var pendingEvents: [ParserEvent] = []

    package init() {}

    package func append(_ chunk: String) {
        guard !isFinished else { return }

        let events = buffer.append(chunk)
        yield(events)
    }

    package func events() -> AsyncStream<ParserEvent> {
        continuation?.finish()

        let (stream, newContinuation) = AsyncStream.makeStream(of: ParserEvent.self)
        continuation = newContinuation

        flushPendingEvents()
        if isFinished {
            newContinuation.finish()
            continuation = nil
        }

        return stream
    }

    package func finish() {
        guard !isFinished else { return }

        isFinished = true
        let events = buffer.finalize()
        yield(events)

        continuation?.finish()
        continuation = nil
    }
}

private extension MarkdownStreamController {
    func flushPendingEvents() {
        guard let continuation else { return }

        for event in pendingEvents {
            continuation.yield(event)
        }
        pendingEvents.removeAll()
    }

    func yield(_ events: [ParserEvent]) {
        guard !events.isEmpty else { return }

        guard let continuation else {
            pendingEvents.append(contentsOf: events)
            return
        }

        for event in events {
            continuation.yield(event)
        }
    }
}
