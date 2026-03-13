import QuillCore
@testable import QuillKit
import Testing
import UIKit

@MainActor
@Suite("BlockContainerView")
struct BlockContainerViewTests {
    @Test("Empty container has zero height")
    func emptyContainerZeroHeight() {
        let container = BlockContainerView()

        #expect(container.totalHeight(for: 320) == 0)
        #expect(container.blockViews.isEmpty)
    }

    @Test("Insert single view appears at correct position")
    func insertSingleView() {
        let container = BlockContainerView()
        let child = FixedHeightView(height: 50)

        container.insertBlock(child, at: 0)

        #expect(container.blockViews.count == 1)
        #expect(container.blockViews[0] === child)
        #expect(child.superview === container)
    }

    @Test("Insert multiple views stack vertically")
    func insertMultipleViewsStackVertically() {
        let container = BlockContainerView()
        let view1 = FixedHeightView(height: 40)
        let view2 = FixedHeightView(height: 60)
        let view3 = FixedHeightView(height: 30)

        container.insertBlock(view1, at: 0)
        container.insertBlock(view2, at: 1)
        container.insertBlock(view3, at: 2)

        container.frame = CGRect(x: 0, y: 0, width: 320, height: 200)
        container.layoutIfNeeded()

        #expect(view1.frame.origin.y == 0)
        #expect(view1.frame.height == 40)
        #expect(view2.frame.origin.y == 40)
        #expect(view2.frame.height == 60)
        #expect(view3.frame.origin.y == 100)
        #expect(view3.frame.height == 30)
    }

    @Test("Remove middle view restacks correctly")
    func removeMiddleViewRestacks() {
        let container = BlockContainerView()
        let view1 = FixedHeightView(height: 40)
        let view2 = FixedHeightView(height: 60)
        let view3 = FixedHeightView(height: 30)

        container.insertBlock(view1, at: 0)
        container.insertBlock(view2, at: 1)
        container.insertBlock(view3, at: 2)

        container.removeBlock(at: 1)

        #expect(container.blockViews.count == 2)
        #expect(container.blockViews[0] === view1)
        #expect(container.blockViews[1] === view3)
        #expect(view2.superview == nil)

        container.frame = CGRect(x: 0, y: 0, width: 320, height: 200)
        container.layoutIfNeeded()

        #expect(view3.frame.origin.y == 40)
    }

    @Test("Height cache hit avoids re-measurement")
    func heightCacheHit() {
        let container = BlockContainerView()
        let measurable = MeasurementCountingView(height: 50)

        container.insertBlock(measurable, at: 0)
        container.frame = CGRect(x: 0, y: 0, width: 320, height: 100)
        container.layoutIfNeeded()

        let initialCount = measurable.sizeThatFitsCallCount
        #expect(initialCount >= 1)

        let view2 = FixedHeightView(height: 30)
        container.insertBlock(view2, at: 1)
        container.layoutIfNeeded()

        #expect(measurable.sizeThatFitsCallCount == initialCount)
    }

    @Test("Height cache invalidated on width change")
    func heightCacheInvalidatedOnWidthChange() {
        let container = BlockContainerView()
        let measurable = MeasurementCountingView(height: 50)

        container.insertBlock(measurable, at: 0)
        container.frame = CGRect(x: 0, y: 0, width: 320, height: 100)
        container.layoutIfNeeded()

        let countAfterFirstLayout = measurable.sizeThatFitsCallCount

        container.frame = CGRect(x: 0, y: 0, width: 375, height: 100)
        container.layoutIfNeeded()

        #expect(measurable.sizeThatFitsCallCount > countAfterFirstLayout)
    }

    @Test("Structural spacing after CodeBlockView")
    func structuralSpacingAfterCodeBlock() {
        let container = BlockContainerView()
        let codeView = CodeBlockView()
        codeView.configure(language: "swift", code: "let x = 1\n")
        let nextView = FixedHeightView(height: 30)

        container.insertBlock(codeView, at: 0)
        container.insertBlock(nextView, at: 1)

        container.frame = CGRect(x: 0, y: 0, width: 320, height: 400)
        container.layoutIfNeeded()

        let expectedGap = codeView.frame.maxY + 12
        #expect(abs(nextView.frame.origin.y - expectedGap) < 1)
    }

    @Test("Structured views keep visible size in manual container layout")
    func structuredViewsKeepVisibleSize() {
        let container = BlockContainerView()
        let codeView = CodeBlockView()
        codeView.configure(language: "json", code: "{ \"stream\": true, \"chunks\": 42 }\n")

        let header = Block.TableRow(cells: [
            .init(content: [.text("Key")]),
            .init(content: [.text("Value")]),
        ])
        let tableView = PlaceholderBlockView.table(header: header, rowCount: 2)

        container.insertBlock(codeView, at: 0)
        container.insertBlock(tableView, at: 1)

        container.frame = CGRect(x: 0, y: 0, width: 320, height: 500)
        container.layoutIfNeeded()

        #expect(abs(codeView.frame.width - 320) < 1)
        #expect(codeView.frame.height > 36)
        #expect(abs(tableView.frame.width - 320) < 1)
        #expect(tableView.frame.height >= 110)

        let scrollView = findSubview(of: UIScrollView.self, in: codeView)
        let placeholderIcon = findSubview(of: UIImageView.self, in: tableView)
        let placeholderLabel = findSubview(of: UILabel.self, in: tableView)

        #expect((scrollView?.frame.width ?? 0) > 200)
        #expect(abs((placeholderIcon?.center.x ?? 0) - tableView.bounds.midX) < 1)
        #expect(abs((placeholderLabel?.center.x ?? 0) - tableView.bounds.midX) < 1)
    }

    @Test("Frozen prefix identity through trailing-index ops")
    func frozenPrefixIdentity() {
        let container = BlockContainerView()
        let views = (0..<5).map { _ in FixedHeightView(height: 20) }

        for (i, view) in views.enumerated() {
            container.insertBlock(view, at: i)
        }

        container.removeBlock(at: 4)
        container.removeBlock(at: 3)

        let newView3 = FixedHeightView(height: 25)
        let newView4 = FixedHeightView(height: 25)
        container.insertBlock(newView3, at: 3)
        container.insertBlock(newView4, at: 4)

        #expect(container.blockViews[0] === views[0])
        #expect(container.blockViews[1] === views[1])
        #expect(container.blockViews[2] === views[2])
        #expect(container.blockViews[3] === newView3)
        #expect(container.blockViews[4] === newView4)
    }

    @Test("removeAllBlocks clears everything")
    func removeAllBlocksClears() {
        let container = BlockContainerView()

        for i in 0..<3 {
            container.insertBlock(FixedHeightView(height: 20), at: i)
        }

        #expect(container.blockViews.count == 3)
        #expect(container.subviews.count == 3)

        container.removeAllBlocks()

        #expect(container.blockViews.isEmpty)
        #expect(container.subviews.isEmpty)
        #expect(container.totalHeight(for: 320) == 0)
    }
}

// MARK: - Test Helpers

private final class FixedHeightView: UIView {
    private let fixedHeight: CGFloat

    init(height: CGFloat) {
        fixedHeight = height
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var intrinsicContentSize: CGSize {
        CGSize(width: UIView.noIntrinsicMetric, height: fixedHeight)
    }

    override func sizeThatFits(_ size: CGSize) -> CGSize {
        CGSize(width: size.width, height: fixedHeight)
    }
}

private final class MeasurementCountingView: UIView {
    private let fixedHeight: CGFloat
    private(set) var sizeThatFitsCallCount = 0

    init(height: CGFloat) {
        fixedHeight = height
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var intrinsicContentSize: CGSize {
        CGSize(width: UIView.noIntrinsicMetric, height: UIView.noIntrinsicMetric)
    }

    override func sizeThatFits(_ size: CGSize) -> CGSize {
        sizeThatFitsCallCount += 1
        return CGSize(width: size.width, height: fixedHeight)
    }
}

private extension BlockContainerViewTests {
    func findSubview<T: UIView>(of type: T.Type, in view: UIView) -> T? {
        for subview in view.subviews {
            if let match = subview as? T {
                return match
            }
            if let found = findSubview(of: type, in: subview) {
                return found
            }
        }
        return nil
    }
}
