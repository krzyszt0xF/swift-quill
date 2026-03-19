@testable import QuillKit

@MainActor
func makeRevealSequencer() -> RevealSequencer {
    .live
}

@MainActor
func makeStreamingBlockRenderer() -> StreamingBlockRenderer {
    .live
}
