@testable import QuillKit
import UIKit

@MainActor
func containerView(for view: QuillView) -> BlockContainerView? {
    view.subviews.first { $0 is BlockContainerView } as? BlockContainerView
}

@MainActor
func findSubview<T: UIView>(
    of type: T.Type,
    in view: UIView,
    matching predicate: ((T) -> Bool)? = nil
) -> T? {
    for subview in view.subviews {
        if let match = subview as? T, predicate?(match) ?? true {
            return match
        }

        if let nestedMatch = findSubview(of: type, in: subview, matching: predicate) {
            return nestedMatch
        }
    }

    return nil
}

func viewSignature(_ view: UIView) -> String {
    if view is TextFlowView { return "flow" }
    if view is CodeBlockView { return "code" }
    if view is PlaceholderBlockView { return "table" }
    return String(describing: type(of: view))
}

@MainActor
func viewSignatures(for view: QuillView) -> [String] {
    guard let container = containerView(for: view) else { return [] }
    return container.blockViews.map(viewSignature)
}

@MainActor
func structuralSignatures(for view: QuillView) -> [String] {
    viewSignatures(for: view).filter { $0 != "flow" }
}
