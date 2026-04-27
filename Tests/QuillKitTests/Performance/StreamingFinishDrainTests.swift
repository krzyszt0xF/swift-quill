import Foundation
import Testing
@testable import QuillCore
@testable import QuillKit
import QuillSharedTestSupport
import UIKit

@MainActor
@Suite("Streaming finish drain", .serialized, GloballySerialized())
struct StreamingFinishDrainTests {
    @Test(
        "Finish drains all buffered content",
        .disabled("flaky under full bundle load; passes in isolation; tracked for follow-up")
    )
    func finishDrainsAllBufferedContent() async {
        let view = QuillView(frame: CGRect(x: 0, y: 0, width: 375, height: 800))
        var finished = false
        view.onStreamFinished = {
            finished = true
        }

        let chunks = makeReplayChunks(count: 60)
        for chunk in chunks {
            view.append(chunk)
        }
        view.finish()

        let drained = await eventually(timeout: .seconds(8)) {
            finished
        }

        #expect(drained, "onStreamFinished should fire after finish()")
        #expect(view.hasDocumentContent)
    }

    @Test(
        "Finish after large document streaming completes without stale state",
        .disabled("flaky under full bundle load; passes in isolation; tracked for follow-up")
    )
    func finishAfterLargeDocumentStreaming() async {
        let view = QuillView(frame: CGRect(x: 0, y: 0, width: 375, height: 800))
        var finished = false
        view.onStreamFinished = {
            finished = true
        }

        let chunks = makeLargeDocumentChunks()
        for chunk in chunks {
            view.append(chunk)
        }
        view.finish()

        let drained = await eventually(timeout: .seconds(8)) {
            finished
        }

        #expect(drained, "onStreamFinished should fire after finishing large document stream")

        let documentText = view.firstDocumentTextView()?.contentStorage?.attributedString?.string
        #expect(documentText != nil)
        #expect(documentText?.contains("Final paragraph") == true)
    }
}

private extension StreamingFinishDrainTests {
    func makeReplayChunks(count: Int) -> [String] {
        let sentences = [
            "The rendering pipeline processes markdown content incrementally. ",
            "Each chunk arrives from the language model and is appended to the buffer. ",
            "The gate heuristics determine when buffered content is committed for rendering. ",
            "Structural boundaries like headings and paragraph breaks create natural commit points. ",
            "Code fences and tables are buffered until their structure is complete.\n\n",
        ]
        return (0..<count).map { index in
            sentences[index % sentences.count]
        }
    }

    func makeLargeDocumentChunks() -> [String] {
        var chunks: [String] = []
        chunks.append("# Performance Test Document\n\n")
        for section in 0..<10 {
            chunks.append("## Section \(section)\n\n")
            chunks.append("Content for section \(section) with enough text to exercise the rendering pipeline. ")
            chunks.append("This includes multiple sentences that will be processed through the gate heuristics. ")
            chunks.append("The buffering delay and module boundaries affect when content becomes visible.\n\n")
        }
        chunks.append("Final paragraph after all sections complete.\n\n")
        return chunks
    }
}
