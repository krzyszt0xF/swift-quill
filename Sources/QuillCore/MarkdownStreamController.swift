package actor MarkdownStreamController {
    private var buffer = StreamBuffer()
    private var continuation: AsyncStream<ParserEvent>.Continuation?

    package init() {}

    package func append(_ chunk: String) {
        let events = buffer.append(chunk)
        for event in events {
            continuation?.yield(event)
        }
    }

    package func events() -> AsyncStream<ParserEvent> {
        continuation?.finish()
        buffer = StreamBuffer()

        let (stream, newContinuation) = AsyncStream.makeStream(of: ParserEvent.self)
        continuation = newContinuation
        return stream
    }

    package func finish() {
        let events = buffer.finalize()
        for event in events {
            continuation?.yield(event)
        }
        continuation?.finish()
        continuation = nil
    }
}
