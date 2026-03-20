import struct Foundation.TimeInterval

/// Product-facing streaming behavior preset.
public enum QuillStreamingPreset: Hashable, Sendable {
    case balanced
    case custom(speedMultiplier: Double, bufferingDelay: TimeInterval)
    case longForm
    case snappy
}
