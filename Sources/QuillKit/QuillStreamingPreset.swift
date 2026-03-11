import struct Foundation.TimeInterval

/// Product-facing streaming behavior preset.
public enum QuillStreamingPreset: Hashable, Sendable {
    case balanced
    case custom(speedMultiplier: Double, tailAggressiveness: TailAggressiveness, bufferingDelay: TimeInterval)
    case longForm
    case snappy
}

/// Tail reveal aggressiveness for custom presets.
public enum TailAggressiveness: String, CaseIterable, Hashable, Sendable {
    case aggressive
    case balanced
    case conservative
}
