import QuillCore
@testable import QuillKit
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

        let chunks = chunk(markdown, sizes: [3, 7, 5, 9, 4, 11, 6])

        let hybrid = makeQuillView(mode: .hybridTail)
        let stable = makeQuillView(mode: .stableBlocks)

        for chunk in chunks {
            hybrid.append(chunk)
            stable.append(chunk)
            await wait(milliseconds: 12)
        }

        hybrid.finish()
        stable.finish()
        await wait(milliseconds: 220)

        let hybridContainer = try #require(containerView(for: hybrid))
        let stableContainer = try #require(containerView(for: stable))

        let hybridSignatures = hybridContainer.blockViews.map(viewSignature)
        let stableSignatures = stableContainer.blockViews.map(viewSignature)

        #expect(hybridSignatures == stableSignatures)
        #expect(hybridSignatures.contains("code"))
        #expect(hybridSignatures.contains("table"))
        #expect(hybridSignatures.filter { $0 == "code" }.count == 1)
        #expect(hybridSignatures.filter { $0 == "table" }.count == 1)
        #expect(hybridSignatures.filter { $0 == "flow" }.count >= 1)
    }
}

private extension TailPromotionConsistencyTests {
    func makeQuillView(mode: StreamingMode) -> QuillView {
        let configuration = QuillRenderConfiguration(
            streamingMode: mode,
            performanceProfile: .balanced,
            typewriter: .balanced,
            layout: .init(heightMeasurementCoalescingInterval: 0.005),
            tail: .default
        )

        let view = QuillView(frame: CGRect(x: 0, y: 0, width: 320, height: 0), internalConfiguration: configuration)
        view.layoutIfNeeded()
        return view
    }

    func containerView(for view: QuillView) -> BlockContainerView? {
        view.subviews.first { $0 is BlockContainerView } as? BlockContainerView
    }

    func nodeSignature(_ node: RenderNode) -> String {
        switch node {
        case .flow:
            return "flow"
        case .codeBlock:
            return "code"
        case .table:
            return "table"
        case .image:
            return "image"
        }
    }

    func viewSignature(_ view: UIView) -> String {
        if view is TextFlowView { return "flow" }
        if view is CodeBlockView { return "code" }
        if view is PlaceholderBlockView { return "table" }
        return String(describing: type(of: view))
    }

    func chunk(_ text: String, sizes: [Int]) -> [String] {
        let characters = Array(text)
        var index = 0
        var sizeIndex = 0
        var chunks: [String] = []

        while index < characters.count {
            let size = sizes[sizeIndex % sizes.count]
            let end = min(index + max(1, size), characters.count)
            chunks.append(String(characters[index..<end]))
            index = end
            sizeIndex += 1
        }

        return chunks
    }

    func wait(milliseconds: UInt64) async {
        try? await Task.sleep(for: .milliseconds(milliseconds))
    }
}
