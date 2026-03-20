import QuillCore
@testable import QuillKit
import QuillSharedTestSupport
import Testing
import UIKit

@MainActor
@Suite("Streaming Mode Consistency")
struct StreamingModeConsistencyTests {
    @Test("Buffered and stable modes converge to identical final node signatures")
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

        let signaturesMatched = await eventually(timeout: .milliseconds(800)) {
            viewSignatures(for: bufferedView) == viewSignatures(for: stableView)
        }
        #expect(signaturesMatched)

        let bufferedContainer = try #require(containerView(for: bufferedView))
        let bufferedSignatures = bufferedContainer.blockViews.map(viewSignature)

        #expect(bufferedSignatures.contains("code"))
        #expect(bufferedSignatures.contains("table"))
        #expect(bufferedSignatures.filter { $0 == "code" }.count == 1)
        #expect(bufferedSignatures.filter { $0 == "table" }.count == 1)
        #expect(bufferedSignatures.filter { $0 == "flow" }.count >= 1)
    }
}
