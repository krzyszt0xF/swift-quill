import QuillCore
@testable import QuillKit
import QuillSharedTestSupport
import Testing
import UIKit

@MainActor
@Suite("Tail Promotion Consistency")
struct TailPromotionConsistencyTests {
    @Test("Hybrid and stable modes converge to identical final node signatures")
    func hybridMatchesStableAfterFinish() async throws {
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

        let hybridView = makeHybridTailQuillView()
        let stableView = makeStableBlocksQuillView()

        for chunk in markdownChunks {
            hybridView.append(chunk)
            stableView.append(chunk)
            await wait(for: .milliseconds(12))
        }

        hybridView.finish()
        stableView.finish()

        let signaturesMatched = await eventually(timeout: .milliseconds(800)) {
            viewSignatures(for: hybridView) == viewSignatures(for: stableView)
        }
        #expect(signaturesMatched)

        let hybridContainer = try #require(containerView(for: hybridView))
        let hybridSignatures = hybridContainer.blockViews.map(viewSignature)

        #expect(hybridSignatures.contains("code"))
        #expect(hybridSignatures.contains("table"))
        #expect(hybridSignatures.filter { $0 == "code" }.count == 1)
        #expect(hybridSignatures.filter { $0 == "table" }.count == 1)
        #expect(hybridSignatures.filter { $0 == "flow" }.count >= 1)
    }
}
