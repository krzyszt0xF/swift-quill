import UIKit

enum RevealAnimator {
    static let blockRevealDuration: TimeInterval = 0.2

    @MainActor
    static func completeTask(_ task: RevealTaskQueue.AnimationTask?, cancelBlockReveal: () -> Void) {
        switch task {
        case let .block(view):
            cancelBlockReveal()
            (view as? BlockRevealAnimating)?.finishBlockReveal()
            view.alpha = 1
        case let .label(label):
            label.alpha = 1
        case let .show(view):
            view.alpha = 1
        case let .text(textView):
            textView.finishReveal()
        case .none:
            break
        }
    }

    static func advanceBlockRevealProgress(
        elapsed: TimeInterval
    ) -> (easedProgress: CGFloat, isComplete: Bool) {
        let rawProgress = min(1, max(0, elapsed / blockRevealDuration))
        let easedProgress = rawProgress * rawProgress * (3 - (2 * rawProgress))
        return (easedProgress, rawProgress >= 1)
    }
}
