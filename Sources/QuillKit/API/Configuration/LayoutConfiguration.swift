// Internal configuration; not part of public API despite the API/ path segment.
// Scheduled for relocation post-1.0.0 (see Docs/ExternalAudit.md).

import Foundation

struct LayoutConfiguration: Equatable, Sendable {
    var heightMeasurementCoalescingInterval: TimeInterval
    var heightNotificationMinimumDelta: CGFloat

    init(
        heightMeasurementCoalescingInterval: TimeInterval,
        heightNotificationMinimumDelta: CGFloat = 8
    ) {
        self.heightMeasurementCoalescingInterval = max(0, heightMeasurementCoalescingInterval)
        self.heightNotificationMinimumDelta = max(0, heightNotificationMinimumDelta)
    }
}

extension LayoutConfiguration {
    static var `default`: Self {
        Self(
            heightMeasurementCoalescingInterval: 0.016,
            heightNotificationMinimumDelta: 8)
    }

    static var snappy: Self {
        Self(
            heightMeasurementCoalescingInterval: 0.010,
            heightNotificationMinimumDelta: 4)
    }

    static var longForm: Self {
        Self(
            heightMeasurementCoalescingInterval: 0.020,
            heightNotificationMinimumDelta: 10)
    }
}
