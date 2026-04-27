import Foundation
import QuillKit

struct PlaygroundConfig: Equatable, Sendable {
    var scenario: Scenario
    var preset: PresetChoice
    var theme: ThemeChoice
    var syntaxHighlightingEnabled: Bool
    var imageLoadingEnabled: Bool
    var streamingMode: StreamingMode
    var chunkDelayMs: Double

    static let `default` = PlaygroundConfig(
        scenario: .quickStart,
        preset: .balanced,
        theme: .default,
        syntaxHighlightingEnabled: true,
        imageLoadingEnabled: true,
        streamingMode: .bufferedModules,
        chunkDelayMs: 200
    )
}

enum PresetChoice: String, CaseIterable, Identifiable, Sendable {
    case balanced
    case bufferedCustom
    case custom
    case longForm
    case snappy

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .balanced: return "Balanced"
        case .bufferedCustom: return "Buffered custom"
        case .custom: return "Custom"
        case .longForm: return "Long form"
        case .snappy: return "Snappy"
        }
    }

    var preset: QuillStreamingPreset {
        switch self {
        case .balanced: return .balanced
        case .bufferedCustom:
            return .bufferedCustom(
                speedMultiplier: 1.0,
                bufferingDelay: 0.12,
                minModuleLength: 24
            )
        case .custom:
            return .custom(speedMultiplier: 1.0, bufferingDelay: 0.08)
        case .longForm: return .longForm
        case .snappy: return .snappy
        }
    }
}

enum ThemeChoice: String, CaseIterable, Identifiable, Sendable {
    case `default`
    case github

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .default: return "Default"
        case .github: return "GitHub"
        }
    }

    var theme: QuillTheme {
        switch self {
        case .default: return .default
        case .github: return .github
        }
    }
}

extension PlaygroundConfig {
    func makeQuillConfiguration() -> QuillConfiguration {
        QuillConfiguration(
            streaming: .init(mode: streamingMode, preset: preset.preset),
            images: .default,
            theme: theme.theme
        )
    }
}
