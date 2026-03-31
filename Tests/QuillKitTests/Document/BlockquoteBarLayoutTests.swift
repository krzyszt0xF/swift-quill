@testable import QuillKit
import QuillCore
import Testing

@Suite("BlockquoteBarLayout")
struct BlockquoteBarLayoutTests {
    @Test("Multi-paragraph blockquote becomes one continuous bar run")
    func continuousBarRun() {
        let ownerBlockID = BlockIdentity(rawValue: 1)
        let fragments = [
            BlockquoteBarLayout.FragmentContext(ownerBlockID: ownerBlockID, depth: 1, maxY: 24, minY: 0),
            BlockquoteBarLayout.FragmentContext(ownerBlockID: ownerBlockID, depth: 1, maxY: 72, minY: 48),
        ]

        let runs = BlockquoteBarLayout.makeRuns(from: fragments)

        #expect(runs == [
            .init(ownerBlockID: ownerBlockID, level: 1, maxY: 72, minY: 0),
        ])
    }

    @Test("Nested level closes when depth drops")
    func nestedLevelDropStartsNewRun() {
        let ownerBlockID = BlockIdentity(rawValue: 1)
        let fragments = [
            BlockquoteBarLayout.FragmentContext(ownerBlockID: ownerBlockID, depth: 2, maxY: 24, minY: 0),
            BlockquoteBarLayout.FragmentContext(ownerBlockID: ownerBlockID, depth: 1, maxY: 48, minY: 32),
            BlockquoteBarLayout.FragmentContext(ownerBlockID: ownerBlockID, depth: 2, maxY: 84, minY: 60),
        ]

        let runs = BlockquoteBarLayout.makeRuns(from: fragments)

        #expect(runs == [
            .init(ownerBlockID: ownerBlockID, level: 2, maxY: 24, minY: 0),
            .init(ownerBlockID: ownerBlockID, level: 1, maxY: 84, minY: 0),
            .init(ownerBlockID: ownerBlockID, level: 2, maxY: 84, minY: 60),
        ])
    }
}
