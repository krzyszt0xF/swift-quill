import UIKit

@MainActor
final class HeightCoordinator {
    var onHeightChange: ((_ old: CGFloat, _ new: CGFloat) -> Void)?

    private var heightInvalidationScheduled = false
    private var heightUpdateTask: Task<Void, Never>?
    private var lastMeasuredContentRevision = 0
    private var lastMeasuredWidth: CGFloat = 0
    private var lastNotifiedHeight: CGFloat = 0
    private var pendingConfiguration = LayoutConfiguration.default
    private var pendingContentRevision = 0
    private var pendingDocumentTextView: DocumentTextView?
    private var pendingHostView: UIView?
    private var previousWidth: CGFloat = 0
    private let measureHeight: (DocumentTextView) -> CGFloat
    private let sleep: (Duration) async -> Void

    init(
        sleep: @escaping (Duration) async -> Void = { duration in
            try? await Task.sleep(for: duration)
        },
        measureHeight: @escaping (DocumentTextView) -> CGFloat = { documentTextView in
            documentTextView.invalidateIntrinsicContentSize()
            return ceil(documentTextView.intrinsicContentSize.height)
        }
    ) {
        self.measureHeight = measureHeight
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
        lastMeasuredContentRevision = 0
        lastMeasuredWidth = 0
        lastNotifiedHeight = 0
    }

    func scheduleHeightUpdate(
        hostView: UIView,
        contentRevision: Int,
        documentTextView: DocumentTextView,
        configuration: LayoutConfiguration
    ) {
        pendingConfiguration = configuration
        pendingContentRevision = contentRevision
        pendingDocumentTextView = documentTextView
        pendingHostView = hostView

        guard !heightInvalidationScheduled else { return }

        heightInvalidationScheduled = true

        let coalescingInterval = max(0, configuration.heightMeasurementCoalescingInterval)
        heightUpdateTask = Task { [sleep, weak self] in
            guard let self else { return }

            if coalescingInterval > 0 {
                await sleep(.seconds(coalescingInterval))
            }

            guard !Task.isCancelled else { return }

            self.measureAndNotify()
        }
    }
}

private extension HeightCoordinator {
    func measureAndNotify() {
        heightInvalidationScheduled = false
        heightUpdateTask = nil
        guard
            let hostView = pendingHostView,
            let documentTextView = pendingDocumentTextView
        else {
            return
        }

        let configuration = pendingConfiguration
        let contentRevision = pendingContentRevision
        pendingDocumentTextView = nil
        pendingHostView = nil
        guard hostView.bounds.width > 0 else { return }
        let currentWidth = hostView.bounds.width

        guard
            currentWidth != lastMeasuredWidth ||
                contentRevision != lastMeasuredContentRevision
        else {
            return
        }

        let signpostID = QuillSignpost.height.makeSignpostID()
        let signpostState = QuillSignpost.height.beginInterval("measureHeight", id: signpostID)
        let newHeight = measureHeight(documentTextView)
        QuillSignpost.height.endInterval("measureHeight", signpostState)
        let oldHeight = lastNotifiedHeight
        lastMeasuredContentRevision = contentRevision
        lastMeasuredWidth = currentWidth
        let minDelta = max(0.5, configuration.heightNotificationMinimumDelta)
        guard abs(newHeight - oldHeight) > minDelta else { return }

        lastNotifiedHeight = newHeight
        onHeightChange?(oldHeight, newHeight)
    }
}
