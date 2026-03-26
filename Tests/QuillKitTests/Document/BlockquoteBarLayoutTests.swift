@testable import QuillKit
import QuillCore
import Testing

@Suite("BlockquoteBarLayout")
struct BlockquoteBarLayoutTests {
    @Test("Multi-paragraph blockquote becomes one continuous bar run")
    func continuousBarRun() {
        let blockID = BlockIdentity(rawValue: 1)
        let fragments = [
            BlockquoteBarLayout.FragmentContext(blockID: blockID, depth: 1, maxY: 24, minY: 0),
            BlockquoteBarLayout.FragmentContext(blockID: blockID, depth: 1, maxY: 72, minY: 48),
        ]

        let runs = BlockquoteBarLayout.makeRuns(from: fragments)

        #expect(runs == [
            .init(blockID: blockID, level: 1, maxY: 72, minY: 0),
        ])
    }

    @Test("Nested level closes when depth drops")
    func nestedLevelDropStartsNewRun() {
        let blockID = BlockIdentity(rawValue: 1)
        let fragments = [
            BlockquoteBarLayout.FragmentContext(blockID: blockID, depth: 2, maxY: 24, minY: 0),
            BlockquoteBarLayout.FragmentContext(blockID: blockID, depth: 1, maxY: 48, minY: 32),
            BlockquoteBarLayout.FragmentContext(blockID: blockID, depth: 2, maxY: 84, minY: 60),
        ]

        let runs = BlockquoteBarLayout.makeRuns(from: fragments)

        #expect(runs == [
            .init(blockID: blockID, level: 2, maxY: 24, minY: 0),
            .init(blockID: blockID, level: 1, maxY: 84, minY: 0),
            .init(blockID: blockID, level: 2, maxY: 84, minY: 60),
        ])
    }
}
