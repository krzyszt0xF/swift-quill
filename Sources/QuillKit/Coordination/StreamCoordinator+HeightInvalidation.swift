import Foundation

extension StreamCoordinator {
    func invalidateHeight(for reason: HeightInvalidationReason) {
        switch reason {
        case .imageAspectRatioUpdated, .rendererSnapshotApplied, .streamFinished, .streamReset:
            lastTailRevealHeightInvalidation = Date.timeIntervalSinceReferenceDate
            onHeightInvalidated?()
        case .tailRevealProgress:
            let now = Date.timeIntervalSinceReferenceDate
            let minimumInterval = max(
                0.04,
                renderConfiguration.layout.heightMeasurementCoalescingInterval * 2
            )
            guard now - lastTailRevealHeightInvalidation >= minimumInterval else { return }

            lastTailRevealHeightInvalidation = now
            onHeightInvalidated?()
        }
    }
}
