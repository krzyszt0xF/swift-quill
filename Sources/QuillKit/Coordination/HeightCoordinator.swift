import UIKit

@MainActor
final class HeightCoordinator {
    var onHeightChange: ((_ old: CGFloat, _ new: CGFloat) -> Void)?

    private var heightInvalidationScheduled = false
    private var heightUpdateTask: Task<Void, Never>?
    private var lastNotifiedHeight: CGFloat = 0
    private var previousWidth: CGFloat = 0
    private let sleep: (Duration) async -> Void

    init(sleep: @escaping (Duration) async -> Void = { duration in
        try? await Task.sleep(for: duration)
    }) {
        self.sleep = sleep
    }

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
        documentTextView: DocumentTextView,
        configuration: LayoutConfiguration
    ) {
        guard !heightInvalidationScheduled else { return }

        heightInvalidationScheduled = true

        let coalescingInterval = max(0, configuration.heightMeasurementCoalescingInterval)
        heightUpdateTask?.cancel()
        heightUpdateTask = Task { [sleep, weak self, weak hostView, weak documentTextView] in
            guard
                let self,
                let hostView,
                let documentTextView
            else { return }

            if coalescingInterval > 0 {
                await sleep(.seconds(coalescingInterval))
            }

            guard !Task.isCancelled else { return }

            self.measureAndNotify(
                hostView: hostView,
                documentTextView: documentTextView,
                configuration: configuration
            )
        }
    }
}

private extension HeightCoordinator {
    func measureAndNotify(
        hostView: UIView,
        documentTextView: DocumentTextView,
        configuration: LayoutConfiguration
    ) {
        heightInvalidationScheduled = false
        heightUpdateTask = nil
        guard hostView.bounds.width > 0 else { return }

        documentTextView.invalidateIntrinsicContentSize()

        let newHeight = ceil(documentTextView.intrinsicContentSize.height)
        let oldHeight = lastNotifiedHeight
        let minDelta = max(0.5, configuration.heightNotificationMinimumDelta)
        guard abs(newHeight - oldHeight) > minDelta else { return }

        lastNotifiedHeight = newHeight
        onHeightChange?(oldHeight, newHeight)
    }
}
