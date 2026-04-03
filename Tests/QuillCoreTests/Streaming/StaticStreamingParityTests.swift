@testable import QuillCore
import QuillCoreTestSupport
import QuillSharedTestSupport
import Testing

@Suite("Static vs Streaming Parity", .tags(.parity, .streaming))
struct StaticStreamingParityTests {
    static let parityCases: [ParityTestCase] = [
        .init(name: "Code fence with language", markdown: "```swift\nlet x = 1\nlet y = 2\n```\n\n", chunkSizes: [8, 5, 12, 7]),
        .init(name: "Flat ordered and unordered lists", markdown: """
        - alpha
        - beta

        1. one
        2. two

        """, chunkSizes: [6, 4, 9, 7, 3]),
        .init(name: "Formatted paragraph", markdown: "**bold** and *italic* with `code`\n\n", chunkSizes: [4, 5, 3, 7]),
        .init(name: "Heading levels", markdown: "# H1\n\n## H2\n\n### H3\n\nBody.\n\n", chunkSizes: [5, 3, 8, 6]),
        .init(name: "Link paragraph", markdown: "Hello [link](http://url) world\n\n", chunkSizes: [3, 6, 4, 5]),
        .init(name: "Nested blockquote with list", markdown: """
        > Level one quote
        >
        > > Nested quote level two
        > >
        > > - with a list item
        > > - and another item
        >

        """, chunkSizes: [3, 2, 5, 4, 1, 6, 3, 7]),
        .init(name: "Nested formatting", markdown: "**bold *and italic***\n\n", chunkSizes: [2, 4, 3, 5]),
        .init(name: "Nested ordered list", markdown: """
        1. first
           1. nested
           2. verification
        2. second

        """, chunkSizes: [3, 4, 5, 2, 6]),
        .init(name: "Nested task list", markdown: """
        - [x] heading
          - [x] nested requirement
          - [ ] nested follow-up
        - [ ] full verification

        """, chunkSizes: [3, 4, 6, 2, 5]),
        .init(name: "Nested unordered list", markdown: """
        - outer
          - inner
        - after

        """, chunkSizes: [2, 4, 3, 5, 2]),
        .init(name: "Nested list code fence", markdown: """
        1. Headings:
           - `#`
             ```markdown
             # Heading 1
             ```
           - `##`
             ```python
             print("Hello")
             ```

        """, chunkSizes: [3, 4, 5, 2, 7, 6]),
        .init(
            name: "Paragraph transitions",
            markdown: "First paragraph.\n\nSecond paragraph.\n\nThird paragraph.\n\n",
            chunkSizes: [4, 9, 6, 11]
        ),
        .init(name: "Prompt nested ordered list under single-character streaming", markdown: """
        1. Parse markdown into a stable block tree
           1. Preserve nested ordered numbering
           2. Keep wrapped lines aligned under the marker when they span more than one visual row in the narrow stream pane

        """, chunkSizes: [1]),
        .init(name: "Simple document", markdown: "# Hello\n\nSome text.\n\n---\n\n", chunkSizes: [3, 7, 5]),
        .init(name: "Single-character chunk splits", markdown: "# Hi\n\nWorld.\n\n", chunkSizes: [1]),
        .init(name: "Supported mixed document", markdown: """
        # Title

        Intro paragraph.

        - bullet one
        - bullet two

        1. ordered one
        2. ordered two

        > A blockquote.

        ```swift
        let x = 1
        ```

        | A | B |
        | - | - |
        | 1 | 2 |

        ---

        Closing paragraph.

        """, chunkSizes: [3, 7, 5, 9, 4, 11, 6, 8]),
        .init(name: "Table", markdown: """
        | Key | Status | Value |
        | :--- | :---: | ---: |
        | **mode** | *streaming* | `42` |
        | state | [active](https://example.com) | 1 |

        """, chunkSizes: [10, 8, 14, 6, 11]),
        .init(name: "Task list", markdown: """
        - [x] done
        - [ ] pending

        """, chunkSizes: [3, 5, 4, 2, 6]),
    ]

    @Test("Static and streaming paths stay in parity", arguments: parityCases)
    func parity(_ testCase: ParityTestCase) async {
        let staticBlocks = MarkdownParser.live.parse(testCase.markdown).normalizedBlocks()
        let streamedBlocks = await MarkdownStreamController.streamAndReduce(testCase.markdown, chunkSizes: testCase.chunkSizes)
        #expect(blocksMatch(staticBlocks, streamedBlocks))
    }
}

struct ParityTestCase: Sendable {
    let name: String
    let markdown: String
    let chunkSizes: [Int]
}

extension ParityTestCase: CustomTestStringConvertible {
    var testDescription: String { name }
}

private extension StaticStreamingParityTests {
    func blocksMatch(_ lhs: [Block], _ rhs: [Block]) -> Bool {
        lhs.canonicalBlocks() == rhs.canonicalBlocks()
    }
}
