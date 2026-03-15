import Foundation

struct BlockState: Identifiable, Equatable, Sendable {
    let id: UUID
    let isFrozen: Bool
    let node: RenderNode

    static func == (lhs: BlockState, rhs: BlockState) -> Bool {
        lhs.id == rhs.id && lhs.isFrozen == rhs.isFrozen && lhs.node == rhs.node
    }
}
