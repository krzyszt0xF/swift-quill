import Foundation

/// Imperative handle for user-driven actions on a live ``QuillStreamView``.
@MainActor
public final class QuillStreamHandle {
    private var attachedOwnerID: UUID?
    private var perform: (() -> Void)?

    public init() {}

    public func cancelStreaming() {
        perform?()
    }

    package func attach(ownerID: UUID, _ action: @escaping () -> Void) {
        attachedOwnerID = ownerID
        perform = action
    }

    package func detach(ownerID: UUID) {
        guard attachedOwnerID == ownerID else { return }
        attachedOwnerID = nil
        perform = nil
    }
}
