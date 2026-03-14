import QuillCore
@testable import QuillKit
import Testing
import UIKit

@MainActor
@Suite("BlockContainerView")
struct BlockContainerViewTests {
    private static let frameTolerance: CGFloat = 1
    private static let structuralSpacing: CGFloat = 12
    private static let testWidth: CGFloat = 320

    @Test("Empty container has zero height")
    func emptyContainerHasZeroHeight() {
        let container = BlockContainerView()

        #expect(container.totalHeight(for: Self.testWidth) == 0)
        #expect(container.blockViews.isEmpty)
    }

    @Test("Frozen prefix identity through trailing-index ops")
    func frozenPrefixIdentityPersistsThroughTrailingIndexChanges() {
        let container = BlockContainerView()
        let initialViews = (0..<5).map { _ in FixedHeightView(height: 20) }

        for (index, view) in initialViews.enumerated() {
            container.insertBlock(view, at: index)
        }

        container.removeBlock(at: 4)
        container.removeBlock(at: 3)

        let replacementViewAtIndexThree = FixedHeightView(height: 25)
        let replacementViewAtIndexFour = FixedHeightView(height: 25)
        container.insertBlock(replacementViewAtIndexThree, at: 3)
        container.insertBlock(replacementViewAtIndexFour, at: 4)

        #expect(container.blockViews[0] === initialViews[0])
        #expect(container.blockViews[1] === initialViews[1])
        #expect(container.blockViews[2] === initialViews[2])
        #expect(container.blockViews[3] === replacementViewAtIndexThree)
        #expect(container.blockViews[4] === replacementViewAtIndexFour)
    }

    @Test("Height cache invalidated on width change")
    func heightCacheInvalidatesOnWidthChange() {
        let container = BlockContainerView()
        let measuredView = MeasurementCountingView(height: 50)

        container.insertBlock(measuredView, at: 0)
        container.frame = CGRect(x: 0, y: 0, width: Self.testWidth, height: 100)
        container.layoutIfNeeded()

        let callCountAfterFirstLayout = measuredView.sizeThatFitsCallCount

        container.frame = CGRect(x: 0, y: 0, width: 375, height: 100)
        container.layoutIfNeeded()

        #expect(measuredView.sizeThatFitsCallCount > callCountAfterFirstLayout)
    }

    @Test("Height cache hit avoids re-measurement")
    func heightCacheReusesCachedMeasurements() {
        let container = BlockContainerView()
        let measuredView = MeasurementCountingView(height: 50)

        container.insertBlock(measuredView, at: 0)
        container.frame = CGRect(x: 0, y: 0, width: Self.testWidth, height: 100)
        container.layoutIfNeeded()

        let initialMeasurementCount = measuredView.sizeThatFitsCallCount
        #expect(initialMeasurementCount >= 1)

        let trailingView = FixedHeightView(height: 30)
        container.insertBlock(trailingView, at: 1)
        container.layoutIfNeeded()

        #expect(measuredView.sizeThatFitsCallCount == initialMeasurementCount)
    }

    @Test("Insert multiple views stack vertically")
    func insertingMultipleViewsStacksThemVertically() {
        let container = BlockContainerView()
        let firstView = FixedHeightView(height: 40)
        let secondView = FixedHeightView(height: 60)
        let thirdView = FixedHeightView(height: 30)

        container.insertBlock(firstView, at: 0)
        container.insertBlock(secondView, at: 1)
        container.insertBlock(thirdView, at: 2)

        container.frame = CGRect(x: 0, y: 0, width: Self.testWidth, height: 200)
        container.layoutIfNeeded()

        #expect(firstView.frame.origin.y == 0)
        #expect(firstView.frame.height == 40)
        #expect(secondView.frame.origin.y == 40)
        #expect(secondView.frame.height == 60)
        #expect(thirdView.frame.origin.y == 100)
        #expect(thirdView.frame.height == 30)
    }

    @Test("Insert single view appears at correct position")
    func insertingSingleViewPlacesItAtRequestedIndex() {
        let container = BlockContainerView()
        let childView = FixedHeightView(height: 50)

        container.insertBlock(childView, at: 0)

        #expect(container.blockViews.count == 1)
        #expect(container.blockViews[0] === childView)
        #expect(childView.superview === container)
    }

    @Test("removeAllBlocks clears everything")
    func removeAllBlocksClearsContainer() {
        let container = BlockContainerView()

        for index in 0..<3 {
            container.insertBlock(FixedHeightView(height: 20), at: index)
        }

        #expect(container.blockViews.count == 3)
        #expect(container.subviews.count == 3)

        container.removeAllBlocks()

        #expect(container.blockViews.isEmpty)
        #expect(container.subviews.isEmpty)
        #expect(container.totalHeight(for: Self.testWidth) == 0)
    }

    @Test("Remove middle view restacks correctly")
    func removingMiddleViewRestacksRemainingViews() {
        let container = BlockContainerView()
        let firstView = FixedHeightView(height: 40)
        let removedView = FixedHeightView(height: 60)
        let trailingView = FixedHeightView(height: 30)

        container.insertBlock(firstView, at: 0)
        container.insertBlock(removedView, at: 1)
        container.insertBlock(trailingView, at: 2)

        container.removeBlock(at: 1)

        #expect(container.blockViews.count == 2)
        #expect(container.blockViews[0] === firstView)
        #expect(container.blockViews[1] === trailingView)
        #expect(removedView.superview == nil)

        container.frame = CGRect(x: 0, y: 0, width: Self.testWidth, height: 200)
        container.layoutIfNeeded()

        #expect(trailingView.frame.origin.y == 40)
    }

    @Test("Structural spacing after CodeBlockView")
    func structuralSpacingAfterCodeBlockUsesExpectedGap() {
        let container = BlockContainerView()
        let codeBlockView = CodeBlockView()
        codeBlockView.configure(language: "swift", code: "let x = 1\n")
        let trailingView = FixedHeightView(height: 30)

        container.insertBlock(codeBlockView, at: 0)
        container.insertBlock(trailingView, at: 1)

        container.frame = CGRect(x: 0, y: 0, width: Self.testWidth, height: 400)
        container.layoutIfNeeded()

        let expectedTrailingOriginY = codeBlockView.frame.maxY + Self.structuralSpacing
        #expect(abs(trailingView.frame.origin.y - expectedTrailingOriginY) < Self.frameTolerance)
    }

    @Test("Structured views keep visible size in manual container layout")
    func structuredViewsRemainVisibleInManualLayout() {
        let container = BlockContainerView()
        let codeBlockView = CodeBlockView()
        codeBlockView.configure(language: "json", code: "{ \"stream\": true, \"chunks\": 42 }\n")

        let header = Block.TableRow(cells: [
            .init(content: [.text("Key")]),
            .init(content: [.text("Value")]),
        ])
        let tablePlaceholderView = PlaceholderBlockView.table(header: header, rowCount: 2)

        container.insertBlock(codeBlockView, at: 0)
        container.insertBlock(tablePlaceholderView, at: 1)

        container.frame = CGRect(x: 0, y: 0, width: Self.testWidth, height: 500)
        container.layoutIfNeeded()

        #expect(abs(codeBlockView.frame.width - Self.testWidth) < Self.frameTolerance)
        #expect(codeBlockView.frame.height > 36)
        #expect(abs(tablePlaceholderView.frame.width - Self.testWidth) < Self.frameTolerance)
        #expect(tablePlaceholderView.frame.height >= 110)

        let scrollView = findSubview(of: UIScrollView.self, in: codeBlockView)
        let placeholderIcon = findSubview(of: UIImageView.self, in: tablePlaceholderView)
        let placeholderLabel = findSubview(of: UILabel.self, in: tablePlaceholderView)

        #expect((scrollView?.frame.width ?? 0) > 200)
        #expect(abs((placeholderIcon?.center.x ?? 0) - tablePlaceholderView.bounds.midX) < Self.frameTolerance)
        #expect(abs((placeholderLabel?.center.x ?? 0) - tablePlaceholderView.bounds.midX) < Self.frameTolerance)
    }
}
