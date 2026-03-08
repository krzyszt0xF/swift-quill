/// Actor-based controller that streams markdown chunks as ParserEvents.
public actor MarkdownStreamController {
    private var buffer = StreamBuffer()
    private var continuation: AsyncStream<ParserEvent>.Continuation?

    public init() {}

    public func append(_ chunk: String) {
        let events = buffer.append(chunk)
        for event in events {
            continuation?.yield(event)
        }
    }

    public func events() -> AsyncStream<ParserEvent> {
        continuation?.finish()
        buffer = StreamBuffer()

        let (stream, newContinuation) = AsyncStream.makeStream(of: ParserEvent.self)
        continuation = newContinuation
        return stream
    }

    public func finish() {
        let events = buffer.finalize()
        for event in events {
            continuation?.yield(event)
        }
        continuation?.finish()
        continuation = nil
    }
}
