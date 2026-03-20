import Foundation
import UIKit

@MainActor
struct FrozenBlockRenderer {
    private(set) var frozenViewCount: Int = 0
    private(set) var stateRegistry: [BlockState] = []
    private let generateID: () -> UUID
    private let nodeViewFactory: RenderNodeViewFactory

    init(
        generateID: @escaping () -> UUID,
        nodeViewFactory: RenderNodeViewFactory
    ) {
        self.generateID = generateID
        self.nodeViewFactory = nodeViewFactory
    }

    mutating func applyContainerUpdate(
        nodes: [RenderNode],
        frozenNodeCount: Int,
        containerView: BlockContainerView,
        linkTapHandler: ((URL) -> Void)?
    ) {
        if frozenNodeCount > frozenViewCount {
            frozenViewCount = frozenNodeCount
        }

        let newStates = buildNewStates(nodes: nodes, frozenNodeCount: frozenViewCount)
        let oldStates = stateRegistry

        let oldIDs = oldStates.map(\.id)
        let newIDs = newStates.map(\.id)
        let diff = newIDs.difference(from: oldIDs)

        var removals: [(offset: Int, id: UUID)] = []
        var insertions: [(offset: Int, id: UUID)] = []

        for change in diff {
            switch change {
            case let .insert(offset, id, _):
                insertions.append((offset: offset, id: id))
            case let .remove(offset, id, _):
                removals.append((offset: offset, id: id))
            }
        }

        for removal in removals.sorted(by: { $0.offset > $1.offset }) {
            containerView.removeBlock(at: removal.offset)
        }

        for insertion in insertions.sorted(by: { $0.offset < $1.offset }) {
            let state = newStates[insertion.offset]
            let view = nodeViewFactory.makeView(state.node)
            Self.applyLinkTapHandler(to: view, handler: linkTapHandler)
            containerView.insertBlock(view, at: min(insertion.offset, containerView.blockViews.count))
        }

        let oldNodeByID = Dictionary(oldStates.map { ($0.id, $0.node) }, uniquingKeysWith: { _, new in new })
        for (index, state) in newStates.enumerated() {
            if let oldNode = oldNodeByID[state.id], oldNode != state.node {
                let view = nodeViewFactory.makeView(state.node)
                Self.applyLinkTapHandler(to: view, handler: linkTapHandler)
                containerView.updateBlock(at: index, with: view)
            }
        }

        stateRegistry = newStates
    }

    mutating func reset() {
        frozenViewCount = 0
        stateRegistry.removeAll()
    }

    static func applyLinkTapHandler(to view: UIView, handler: ((URL) -> Void)?) {
        guard let textFlowView = view as? TextFlowView else { return }
        
        textFlowView.onLinkTap = handler
    }
}

extension FrozenBlockRenderer {
    static var live: Self {
        FrozenBlockRenderer(
            generateID: UUID.init,
            nodeViewFactory: .live
        )
    }
}

private extension FrozenBlockRenderer {
    func buildNewStates(nodes: [RenderNode], frozenNodeCount: Int) -> [BlockState] {
        var newStates: [BlockState] = []

        for (index, node) in nodes.enumerated() {
            let isFrozen = index < frozenNodeCount

            if isFrozen, index < stateRegistry.count {
                let existingState = stateRegistry[index]
                newStates.append(BlockState(
                    id: existingState.id,
                    isFrozen: true,
                    node: node
                ))
            } else {
                newStates.append(BlockState(
                    id: generateID(),
                    isFrozen: isFrozen,
                    node: node
                ))
            }
        }

        return newStates
    }
}
