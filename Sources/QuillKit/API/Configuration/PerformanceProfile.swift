// Internal configuration; not part of public API despite the API/ path segment.
// Scheduled for relocation post-1.0.0 (see Docs/ExternalAudit.md).

enum PerformanceProfile: String, CaseIterable, Sendable {
    case balanced
    case longForm
    case snappy
}
