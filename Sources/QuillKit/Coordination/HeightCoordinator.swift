import UIKit

@MainActor
final class HeightCoordinator {
    var onHeightChange: ((_ old: CGFloat, _ new: CGFloat) -> Void)?

    private var heightInvalidationScheduled = false
    private var heightUpdateTask: Task<Void, Never>?
    private var lastNotifiedHeight: CGFloat = 0
    private var previousWidth: CGFloat = 0

    deinit {
        heightUpdateTask?.cancel()
    }

    func handleWidthChange(newWidth: CGFloat) -> Bool {
        guard newWidth != previousWidth else { return false }
        
        previousWidth = newWidth
        return true
    }

    func resetLastNotifiedHeight() {
        lastNotifiedHeight = 0
    }

    func scheduleHeightUpdate(
        hostView: UIView,
        containerView: UIView,
        configuration: LayoutConfiguration
    ) {
        guard !heightInvalidationScheduled else { return }
        
        heightInvalidationScheduled = true

        let coalescingInterval = max(0, configuration.heightMeasurementCoalescingInterval)
        heightUpdateTask?.cancel()
        heightUpdateTask = Task { [weak self, weak hostView, weak containerView] in
            guard
                let self,
                let hostView,
                let containerView
            else { return }

            if coalescingInterval > 0 {
                try? await Task.sleep(for: .seconds(coalescingInterval))
            }

            guard !Task.isCancelled else { return }
            
            self.measureAndNotify(
                hostView: hostView,
                containerView: containerView,
                configuration: configuration
            )
        }
    }
}

private extension HeightCoordinator {
    func measureAndNotify(
        hostView: UIView,
        containerView: UIView,
        configuration: LayoutConfiguration
    ) {
        heightInvalidationScheduled = false
        heightUpdateTask = nil
        guard hostView.bounds.width > 0 else { return }

        hostView.setNeedsLayout()
        hostView.layoutIfNeeded()
        containerView.setNeedsLayout()
        containerView.layoutIfNeeded()

        let newHeight = ceil(containerView.bounds.height)
        let oldHeight = lastNotifiedHeight
        let minDelta = max(0.5, configuration.heightNotificationMinimumDelta)
        guard abs(newHeight - oldHeight) > minDelta else { return }

        lastNotifiedHeight = newHeight
        onHeightChange?(oldHeight, newHeight)
    }
}
