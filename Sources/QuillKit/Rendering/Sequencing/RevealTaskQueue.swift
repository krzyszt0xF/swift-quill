import UIKit

struct RevealTaskQueue {
    enum AnimationTask {
        case block(UIView)
        case label(UILabel)
        case show(UIView)
        case text(TextFlowView)
    }

    private(set) var tasks: [AnimationTask] = []

    var isEmpty: Bool { tasks.isEmpty }
    var count: Int { tasks.count }

    mutating func append(_ task: AnimationTask) {
        tasks.append(task)
    }

    mutating func removeFirst() -> AnimationTask {
        tasks.removeFirst()
    }

    mutating func removeAll() {
        tasks.removeAll()
    }

    @MainActor
    mutating func decompose(
        view: UIView,
        isRoot: Bool,
        typewriterConfiguration: TypewriterConfiguration,
        onLayoutChange: ((UIView?) -> Void)?
    ) {
        if let textFlow = view as? TextFlowView {
            if isRoot {
                textFlow.alpha = 0
                tasks.append(.show(textFlow))
            }
            textFlow.configureRevealFade(
                initialAlpha: typewriterConfiguration.textRevealInitialAlpha,
                duration: typewriterConfiguration.textRevealFadeDuration
            )
            textFlow.prepareForReveal()
            tasks.append(.text(textFlow))
            return
        }

        if let label = view as? UILabel {
            label.alpha = 0
            tasks.append(.label(label))
            return
        }

        if view is CodeBlockView || view is PlaceholderBlockView {
            if let revealable = view as? BlockRevealAnimating {
                revealable.prepareForBlockReveal()
                onLayoutChange?(view)
            }
            view.alpha = 0
            tasks.append(.block(view))
            return
        }

        if view is UIButton || view is UIImageView {
            view.alpha = 0
            tasks.append(.block(view))
            return
        }

        if let stack = view as? UIStackView {
            if isRoot {
                view.alpha = 0
                tasks.append(.show(view))
            }
            for sub in stack.arrangedSubviews {
                decompose(view: sub, isRoot: false, typewriterConfiguration: typewriterConfiguration, onLayoutChange: onLayoutChange)
            }
            return
        }

        if !view.subviews.isEmpty {
            if isRoot {
                view.alpha = 0
                tasks.append(.show(view))
            }
            for sub in view.subviews {
                decompose(view: sub, isRoot: false, typewriterConfiguration: typewriterConfiguration, onLayoutChange: onLayoutChange)
            }
            return
        }

        view.alpha = 0
        tasks.append(.block(view))
    }
}
