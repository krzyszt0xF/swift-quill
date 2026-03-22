import QuillCore
@testable import QuillKit
import QuillSharedTestSupport
import Testing
import UIKit

@MainActor
@Suite("Streaming Mode Consistency")
struct StreamingModeConsistencyTests {
    @Test("Buffered and stable modes converge to identical final markdown")
    func bufferedMatchesStableAfterFinish() async throws {
        let markdown = """
        # Title

        Intro paragraph.

        - one
        - two

        ```swift
        let x = 1
        ```

        | Key | Value |
        | --- | --- |
        | mode | streaming |
        """

        let markdownChunks = markdown.chunked(sizes: [3, 7, 5, 9, 4, 11, 6])

        let bufferedView = makeBufferedModulesQuillView(
            minModuleLength: 1,
            maxBufferingDelay: 0.1
        )
        let stableView = makeStableBlocksQuillView()

        for chunk in markdownChunks {
            bufferedView.append(chunk)
            stableView.append(chunk)
            await wait(for: .milliseconds(12))
        }

        bufferedView.finish()
        stableView.finish()

        let markdownMatched = await eventually(timeout: .milliseconds(800)) {
            bufferedView.currentMarkdown == stableView.currentMarkdown
        }
        #expect(markdownMatched)

        let bothRendered = await eventually(timeout: .milliseconds(800)) {
            documentHasContent(bufferedView) && documentHasContent(stableView)
        }
        #expect(bothRendered)
    }
}
