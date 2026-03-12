@testable import QuillKit
import Testing
import UIKit

@MainActor
@Suite("QuillView Integration")
struct QuillViewIntegrationTests {

    // MARK: - Contract Tests

    @Test("append + finish produces identical currentMarkdown to chunk concatenation")
    func appendFinishPreservesMarkdown() async {
        let streamedView = makeQuillView()
        let staticView = makeQuillView()
        let fullMarkdown = mixedMarkdownFixture
        let chunks = chunk(fullMarkdown, sizes: [3, 7, 5, 9, 4])

        for c in chunks {
            streamedView.append(c)
        }
        streamedView.finish()
        staticView.markdown = fullMarkdown

        let matched = await eventually { streamedView.currentMarkdown == fullMarkdown }
        let renderedStreamed = await eventually {
            stackView(for: streamedView)?.arrangedSubviews.isEmpty == false
        }
        let renderedStatic = await eventually {
            stackView(for: staticView)?.arrangedSubviews.isEmpty == false
        }
        let structuralMatched = await eventually(timeout: .milliseconds(1200)) {
            structuralSignatures(for: streamedView) == structuralSignatures(for: staticView)
        }
        let streamedSignatures = viewSignatures(for: streamedView)
        let staticSignatures = viewSignatures(for: staticView)
        let streamedStructural = streamedSignatures.filter { $0 != "flow" }
        let staticStructural = staticSignatures.filter { $0 != "flow" }

        #expect(matched)
        #expect(renderedStreamed)
        #expect(renderedStatic)
        #expect(structuralMatched)
        #expect(streamedView.currentMarkdown == fullMarkdown)
        #expect(streamedStructural == staticStructural)
        #expect(streamedSignatures.filter { $0 == "code" }.count == 1)
        #expect(streamedSignatures.filter { $0 == "table" }.count == 1)
        #expect(streamedSignatures.contains("code"))
        #expect(streamedSignatures.contains("table"))
    }

    @Test("finish flushes buffered tail content")
    func finishFlushesTail() async {
        let view = makeQuillView(mode: .stableBlocks)
        let input = "# Title\n\n```swift\nlet x = 1"
        let chunks = chunk(input, sizes: [5, 8, 6])

        for c in chunks {
            view.append(c)
        }

        let renderedBeforeFinish = await eventually {
            stackView(for: view)?.arrangedSubviews.isEmpty == false
        }
        let beforeSignatures = viewSignatures(for: view)

        view.finish()

        let matched = await eventually { view.currentMarkdown == input }
        let renderedAfterFinish = await eventually {
            viewSignatures(for: view).contains("code")
        }
        let afterSignatures = viewSignatures(for: view)

        #expect(renderedBeforeFinish)
        #expect(beforeSignatures.contains("code") == false)
        #expect(matched)
        #expect(view.currentMarkdown == input)
        #expect(renderedAfterFinish)
        #expect(afterSignatures.contains("code"))
    }

    @Test("cancelStreaming preserves already-appended currentMarkdown")
    func cancelPreservesContent() {
        let view = makeQuillView()

        view.append("First chunk. ")
        view.append("Second chunk.\n\n")
        view.cancelStreaming()

        #expect(view.currentMarkdown == "First chunk. Second chunk.\n\n")
    }

    @Test("append after finish auto-restarts a new stream session")
    func autoRestartAfterFinish() async {
        let view = makeQuillView()

        view.append("First paragraph\n\n")
        view.finish()

        view.append("Second paragraph\n\n")

        #expect(view.currentMarkdown == "First paragraph\n\nSecond paragraph\n\n")

        let rendered = await eventually {
            (stackView(for: view)?.arrangedSubviews.count ?? 0) >= 1
        }
        #expect(rendered)
    }

    @Test("append after cancel auto-restarts a new stream session")
    func autoRestartAfterCancel() async {
        let view = makeQuillView()

        view.append("Before cancel\n\n")
        view.cancelStreaming()

        view.append("After cancel\n\n")

        #expect(view.currentMarkdown == "Before cancel\n\nAfter cancel\n\n")

        let rendered = await eventually {
            (stackView(for: view)?.arrangedSubviews.count ?? 0) >= 1
        }
        #expect(rendered)
    }

    @Test("reset clears currentMarkdown to nil")
    func resetClearsState() {
        let view = makeQuillView()

        view.append("Some content\n\nMore content\n\n")
        #expect(view.currentMarkdown != nil)

        view.reset()

        #expect(view.currentMarkdown == nil)
        #expect(stackView(for: view)?.arrangedSubviews.isEmpty == true)
    }

    // MARK: - Equivalence Tests

    @Test("same markdown produces identical currentMarkdown across modes", arguments: StreamingMode.allCases)
    func modeEquivalence(mode: StreamingMode) async {
        let view = makeQuillView(mode: mode)
        let fullMarkdown = mixedMarkdownFixture
        let chunks = chunk(fullMarkdown, sizes: [4, 9, 6])

        for c in chunks {
            view.append(c)
        }
        view.finish()

        let matched = await eventually { view.currentMarkdown == fullMarkdown }
        #expect(matched)
        #expect(view.currentMarkdown == fullMarkdown)
    }

    @Test("same markdown produces identical currentMarkdown across presets", arguments: [QuillStreamingPreset.balanced, .snappy, .longForm])
    func presetEquivalence(preset: QuillStreamingPreset) async {
        let view = QuillView(
            frame: CGRect(x: 0, y: 0, width: 320, height: 0),
            streamingPreset: preset
        )
        view.layoutIfNeeded()

        let fullMarkdown = mixedMarkdownFixture
        let chunks = chunk(fullMarkdown, sizes: [4, 9, 6])

        for c in chunks {
            view.append(c)
        }
        view.finish()

        let matched = await eventually { view.currentMarkdown == fullMarkdown }
        #expect(matched)
        #expect(view.currentMarkdown == fullMarkdown)
    }

    // MARK: - Edge Cases

    @Test("empty chunks do not corrupt currentMarkdown")
    func emptyChunks() async {
        let view = makeQuillView()
        let parts = ["# Title", "", "\n\n", "", "Body text.\n\n", ""]

        for part in parts {
            view.append(part)
        }
        view.finish()

        let expected = "# Title\n\nBody text.\n\n"
        let matched = await eventually { view.currentMarkdown == expected }
        #expect(matched)
        #expect(view.currentMarkdown == expected)
    }

    @Test("chunk boundary inside markdown syntax produces correct result")
    func chunkBoundaryInsideSyntax() async {
        let view1 = makeQuillView()
        let codeFence = "```swift\nlet x = 1\n```\n\n"
        let codeFenceChunks = chunk(codeFence, sizes: [2, 3, 4])

        for c in codeFenceChunks {
            view1.append(c)
        }
        view1.finish()

        let codeFenceMatched = await eventually { view1.currentMarkdown == codeFence }
        #expect(codeFenceMatched)
        #expect(view1.currentMarkdown == codeFence)

        let view2 = makeQuillView()
        let boldText = "**bold text**\n\n"
        let boldChunks = chunk(boldText, sizes: [1])

        for c in boldChunks {
            view2.append(c)
        }
        view2.finish()

        let boldMatched = await eventually { view2.currentMarkdown == boldText }
        #expect(boldMatched)
        #expect(view2.currentMarkdown == boldText)
    }

    @Test("large single chunk produces correct currentMarkdown")
    func largeSingleChunk() async {
        let view = makeQuillView()
        let largeMarkdown = makeLargeMarkdown()

        view.append(largeMarkdown)
        view.finish()

        let matched = await eventually { view.currentMarkdown == largeMarkdown }
        #expect(matched)
        #expect(view.currentMarkdown == largeMarkdown)
    }

    @Test("rapid successive appends produce correct cumulative result")
    func rapidSuccessiveAppends() async {
        let view = makeQuillView()
        let fullMarkdown = mixedMarkdownFixture
        let chunks = chunk(fullMarkdown, sizes: [2, 3])

        for c in chunks {
            view.append(c)
        }
        view.finish()

        let matched = await eventually(timeout: .milliseconds(800)) {
            view.currentMarkdown == fullMarkdown
        }
        #expect(matched)
        #expect(view.currentMarkdown == fullMarkdown)
    }
}

private extension QuillViewIntegrationTests {
    var mixedMarkdownFixture: String {
        """
        # Integration Test Heading

        A paragraph with **bold** and *italic* formatting.

        - First item
        - Second item
        - Third item

        ```swift
        let code = "example"
        print(code)
        ```

        > A blockquote with some wisdom.

        ---

        | Column A | Column B |
        |----------|----------|
        | Cell 1   | Cell 2   |
        | Cell 3   | Cell 4   |

        Final paragraph to close out the fixture.

        """
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

    func eventually(
        timeout: Duration = .milliseconds(500),
        poll: Duration = .milliseconds(5),
        _ condition: () -> Bool
    ) async -> Bool {
        let clock = ContinuousClock()
        let deadline = clock.now.advanced(by: timeout)

        while clock.now < deadline {
            if condition() {
                return true
            }
            try? await Task.sleep(for: poll)
        }

        return condition()
    }

    func makeLargeMarkdown() -> String {
        var result = "# Large Document\n\n"
        for i in 1...10 {
            result += "## Section \(i)\n\n"
            result += "This is paragraph content for section \(i). It contains enough text to contribute meaningfully to the total character count of the document.\n\n"
            result += "- Item \(i)a with some detail\n- Item \(i)b with more detail\n- Item \(i)c with even more detail\n\n"
        }
        result += "```\nfinal code block content\nwith multiple lines\n```\n\n"
        return result
    }

    func makeQuillView(mode: StreamingMode = .stableBlocks) -> QuillView {
        var configuration = QuillRenderConfiguration(
            streamingMode: mode,
            performanceProfile: .balanced,
            typewriter: .balanced,
            layout: .init(heightMeasurementCoalescingInterval: 0.005),
            tail: .default
        )

        if mode == .bufferedModules {
            configuration.bufferedStream = BufferedStreamConfiguration(
                minModuleLength: 1,
                maxBufferingDelay: 0.1
            )
        }

        let view = QuillView(
            frame: CGRect(x: 0, y: 0, width: 320, height: 0),
            internalConfiguration: configuration
        )
        view.layoutIfNeeded()
        return view
    }

    func stackView(for view: QuillView) -> UIStackView? {
        view.subviews.first { $0 is UIStackView } as? UIStackView
    }

    func viewSignatures(for view: QuillView) -> [String] {
        guard let stack = stackView(for: view) else { return [] }
        return stack.arrangedSubviews.map(viewSignature)
    }

    func structuralSignatures(for view: QuillView) -> [String] {
        viewSignatures(for: view).filter { $0 != "flow" }
    }

    func viewSignature(_ view: UIView) -> String {
        if view is TextFlowView { return "flow" }
        if view is CodeBlockView { return "code" }
        if view is PlaceholderBlockView { return "table" }
        return String(describing: type(of: view))
    }
}
